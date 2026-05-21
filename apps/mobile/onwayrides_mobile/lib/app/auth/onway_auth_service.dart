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

  Future<void> signOut() => _firebaseAuth.signOut();

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
}
