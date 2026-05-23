import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'onway_auth_session.dart';

class OnWayAuthException implements Exception {
  const OnWayAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class OnWayPhoneVerificationChallenge {
  const OnWayPhoneVerificationChallenge({
    required this.phoneNumber,
    this.verificationId,
    this.resendToken,
    this.confirmationResult,
    this.instantlyVerified = false,
  });

  final String phoneNumber;
  final String? verificationId;
  final int? resendToken;
  final ConfirmationResult? confirmationResult;
  final bool instantlyVerified;
}

class OnWayAuthService {
  OnWayAuthService({
    FirebaseAuth? firebaseAuth,
    http.Client? httpClient,
    String? apiBaseUrl,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _httpClient = httpClient ?? http.Client(),
       _apiBaseUrl = apiBaseUrl;

  final FirebaseAuth _firebaseAuth;
  final http.Client _httpClient;
  final String? _apiBaseUrl;

  Stream<User?> authStateChanges() => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  String get apiBaseUrl {
    final dartDefine = const String.fromEnvironment('ONWAYRIDES_API_BASE_URL');
    if (dartDefine.trim().isNotEmpty) {
      return dartDefine.trim().replaceAll(RegExp(r'/$'), '');
    }

    if (_apiBaseUrl != null && _apiBaseUrl.trim().isNotEmpty) {
      return _apiBaseUrl.trim().replaceAll(RegExp(r'/$'), '');
    }

    if (kIsWeb) {
      return Uri.base.resolve('/api').toString().replaceAll(RegExp(r'/$'), '');
    }

    return 'http://10.0.2.2:8000/api';
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw OnWayAuthException(
        error.message ?? 'Unable to sign in with Firebase.',
      );
    }
  }

  Future<void> registerRider({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      await credential.user?.updateDisplayName(fullName.trim());
      await credential.user?.reload();
    } on FirebaseAuthException catch (error) {
      throw OnWayAuthException(
        error.message ?? 'Unable to create Firebase account.',
      );
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      final provider = GoogleAuthProvider();

      if (kIsWeb) {
        await _firebaseAuth.signInWithPopup(provider);
        return;
      }

      await _firebaseAuth.signInWithProvider(provider);
    } on FirebaseAuthException catch (error) {
      throw OnWayAuthException(
        error.message ?? 'Unable to sign in with Google right now.',
      );
    }
  }

  Future<OnWayAuthSession> syncCurrentUser({
    String role = 'rider',
    String? platform,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const OnWayAuthException('No signed-in Firebase user was found.');
    }

    final idToken = await user.getIdToken(true);
    final response = await _httpClient.post(
      Uri.parse('$apiBaseUrl/auth/login'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({
        'role': role,
        'platform': platform ?? _defaultPlatformLabel(),
        'full_name': user.displayName,
      }),
    );

    final responseBody = _decodeJsonBody(response.body);
    if (response.statusCode != 200) {
      throw OnWayAuthException(
        (responseBody['message'] as String?) ??
            'Unable to sync Firebase user with backend.',
      );
    }

    return OnWayAuthSession.fromJson(responseBody);
  }

  Future<OnWayAuthSession> completeProfile({
    required String fullName,
    required String countryCode,
    required String phone,
    required bool acceptPrivacyPolicy,
    required bool acceptTerms,
    required bool smsMarketingOptIn,
    required bool whatsappMarketingOptIn,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const OnWayAuthException('No signed-in Firebase user was found.');
    }

    final idToken = await user.getIdToken(true);
    final response = await _httpClient.patch(
      Uri.parse('$apiBaseUrl/auth/onboarding'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({
        'full_name': fullName.trim(),
        'country_code': countryCode.trim(),
        'phone': phone.trim(),
        'accept_privacy_policy': acceptPrivacyPolicy,
        'accept_terms': acceptTerms,
        'sms_marketing_opt_in': smsMarketingOptIn,
        'whatsapp_marketing_opt_in': whatsappMarketingOptIn,
      }),
    );

    final responseBody = _decodeJsonBody(response.body);
    if (response.statusCode != 200) {
      final errors = responseBody['errors'];
      if (errors is Map<String, dynamic>) {
        final firstError = errors.values
            .whereType<List>()
            .expand((messages) => messages.whereType<String>())
            .cast<String?>()
            .firstWhere(
              (message) => message != null && message.isNotEmpty,
              orElse: () => null,
            );

        if (firstError != null) {
          throw OnWayAuthException(firstError);
        }
      }

      throw OnWayAuthException(
        (responseBody['message'] as String?) ??
            'Unable to save your phone number and consent preferences.',
      );
    }

    return OnWayAuthSession.fromJson(responseBody);
  }

  Future<OnWayPhoneVerificationChallenge> startPhoneVerification({
    required String countryCode,
    required String phone,
    int? resendToken,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const OnWayAuthException('No signed-in Firebase user was found.');
    }

    final normalizedPhone = normalizePhoneNumber(
      countryCode: countryCode,
      phone: phone,
    );

    if (user.phoneNumber == normalizedPhone) {
      await user.reload();

      return OnWayPhoneVerificationChallenge(
        phoneNumber: normalizedPhone,
        instantlyVerified: true,
      );
    }

    if (kIsWeb) {
      try {
        final confirmationResult = await user.linkWithPhoneNumber(
          normalizedPhone,
        );

        return OnWayPhoneVerificationChallenge(
          phoneNumber: normalizedPhone,
          confirmationResult: confirmationResult,
        );
      } on FirebaseAuthException catch (error) {
        throw OnWayAuthException(
          _mapPhoneVerificationError(
            error,
            fallback: 'Unable to start web phone verification.',
          ),
        );
      }
    }

    final completer = Completer<OnWayPhoneVerificationChallenge>();

    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: normalizedPhone,
      timeout: const Duration(seconds: 90),
      forceResendingToken: resendToken,
      verificationCompleted: (credential) async {
        try {
          await _linkOrUpdatePhoneCredential(
            credential,
            expectedPhoneNumber: normalizedPhone,
          );

          if (!completer.isCompleted) {
            completer.complete(
              OnWayPhoneVerificationChallenge(
                phoneNumber: normalizedPhone,
                instantlyVerified: true,
              ),
            );
          }
        } on OnWayAuthException catch (error) {
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        }
      },
      verificationFailed: (error) {
        if (!completer.isCompleted) {
          completer.completeError(
            OnWayAuthException(
              _mapPhoneVerificationError(
                error,
                fallback: 'Unable to send the phone verification code.',
              ),
            ),
          );
        }
      },
      codeSent: (verificationId, nextResendToken) {
        if (!completer.isCompleted) {
          completer.complete(
            OnWayPhoneVerificationChallenge(
              phoneNumber: normalizedPhone,
              verificationId: verificationId,
              resendToken: nextResendToken,
            ),
          );
        }
      },
      codeAutoRetrievalTimeout: (verificationId) {
        if (!completer.isCompleted) {
          completer.complete(
            OnWayPhoneVerificationChallenge(
              phoneNumber: normalizedPhone,
              verificationId: verificationId,
              resendToken: resendToken,
            ),
          );
        }
      },
    );

    return completer.future;
  }

  Future<void> confirmPhoneVerification({
    required OnWayPhoneVerificationChallenge challenge,
    required String smsCode,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const OnWayAuthException('No signed-in Firebase user was found.');
    }

    if (challenge.instantlyVerified) {
      await user.reload();
      return;
    }

    try {
      if (kIsWeb) {
        final confirmationResult = challenge.confirmationResult;
        if (confirmationResult == null) {
          throw const OnWayAuthException(
            'The web phone verification session is missing. Request a new code.',
          );
        }

        await confirmationResult.confirm(smsCode.trim());
      } else {
        final verificationId = challenge.verificationId;
        if (verificationId == null || verificationId.isEmpty) {
          throw const OnWayAuthException(
            'The verification session expired. Request a new code.',
          );
        }

        final credential = PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: smsCode.trim(),
        );

        await _linkOrUpdatePhoneCredential(
          credential,
          expectedPhoneNumber: challenge.phoneNumber,
        );
      }

      await user.reload();
    } on FirebaseAuthException catch (error) {
      throw OnWayAuthException(
        _mapPhoneVerificationError(
          error,
          fallback: 'Unable to confirm the verification code.',
        ),
      );
    }
  }

  Future<void> signOut() => _firebaseAuth.signOut();

  String normalizePhoneNumber({
    required String countryCode,
    required String phone,
  }) {
    final countryDigits = (countryCode).replaceAll(RegExp(r'\D+'), '');
    final phoneDigits = phone.replaceAll(RegExp(r'\D+'), '');
    final normalizedPhoneDigits = phoneDigits.replaceFirst(RegExp(r'^0+'), '');
    final normalizedCountryDigits = countryDigits.replaceFirst(
      RegExp(r'^0+'),
      '',
    );

    if (normalizedCountryDigits.isNotEmpty &&
        normalizedPhoneDigits.startsWith(normalizedCountryDigits)) {
      return '+$normalizedPhoneDigits';
    }

    return '+$normalizedCountryDigits$normalizedPhoneDigits';
  }

  Map<String, dynamic> _decodeJsonBody(String body) {
    final decoded = jsonDecode(body);

    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }

  String _defaultPlatformLabel() {
    if (kIsWeb) {
      return 'web';
    }

    return defaultTargetPlatform.name;
  }

  Future<void> _linkOrUpdatePhoneCredential(
    PhoneAuthCredential credential, {
    required String expectedPhoneNumber,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const OnWayAuthException('No signed-in Firebase user was found.');
    }

    if (user.phoneNumber == expectedPhoneNumber) {
      return;
    }

    try {
      await user.linkWithCredential(credential);
      return;
    } on FirebaseAuthException catch (error) {
      if (error.code == 'provider-already-linked') {
        try {
          await user.updatePhoneNumber(credential);
          return;
        } on FirebaseAuthException catch (updateError) {
          throw OnWayAuthException(
            _mapPhoneVerificationError(
              updateError,
              fallback: 'Unable to update the linked phone number.',
            ),
          );
        }
      }

      throw OnWayAuthException(
        _mapPhoneVerificationError(
          error,
          fallback: 'Unable to link that phone number to this account.',
        ),
      );
    }
  }

  String _mapPhoneVerificationError(
    FirebaseAuthException error, {
    required String fallback,
  }) {
    switch (error.code) {
      case 'invalid-phone-number':
        return 'The phone number format is invalid.';
      case 'too-many-requests':
        return 'Too many verification attempts were made. Please try again later.';
      case 'quota-exceeded':
        return 'Firebase phone verification quota has been exceeded for now.';
      case 'session-expired':
        return 'The verification session expired. Request a new code.';
      case 'invalid-verification-code':
        return 'The verification code is incorrect.';
      case 'credential-already-in-use':
      case 'phone-number-already-in-use':
        return 'This phone number is already linked to another account.';
      case 'provider-already-linked':
        return 'A phone number is already linked to this account.';
      case 'operation-not-allowed':
        return 'Phone authentication is not enabled in Firebase yet.';
      default:
        return error.message ?? fallback;
    }
  }
}
