import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../onway_models.dart';
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

class OnWayRealtimeEvent {
  const OnWayRealtimeEvent({
    required this.channel,
    required this.type,
    this.bookingId,
    this.status,
    this.data = const <String, String>{},
  });

  final String channel;
  final String type;
  final int? bookingId;
  final String? status;
  final Map<String, String> data;
}

class OnWayAuthService {
  static const _requestTimeout = Duration(seconds: 20);
  static const _productionApiBaseUrl = 'https://api.onwayrides.com/api';

  OnWayAuthService({
    FirebaseAuth? firebaseAuth,
    http.Client? httpClient,
    String? apiBaseUrl,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _httpClient = httpClient ?? http.Client(),
       _firebaseMessaging = FirebaseMessaging.instance,
       _apiBaseUrl = apiBaseUrl;

  final FirebaseAuth _firebaseAuth;
  final http.Client _httpClient;
  final FirebaseMessaging _firebaseMessaging;
  final String? _apiBaseUrl;
  final StreamController<OnWayRealtimeEvent> _realtimeEventsController =
      StreamController<OnWayRealtimeEvent>.broadcast();
  bool _realtimeInitialized = false;

  Stream<OnWayRealtimeEvent> get realtimeEvents =>
      _realtimeEventsController.stream;

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

    return _productionApiBaseUrl;
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
    final response = await _performJsonRequest(
      () => _httpClient.post(
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
      ),
      fallback: 'Unable to reach the OnWay Rides backend for sign-in sync.',
    );

    final responseBody = _decodeJsonBody(response.body);
    if (response.statusCode != 200) {
      throw OnWayAuthException(
        (responseBody['message'] as String?) ??
            'Unable to sync Firebase user with backend.',
      );
    }

    unawaited(_initializeRealtime());

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
    final response = await _performJsonRequest(
      () => _httpClient.patch(
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
      ),
      fallback:
          'Unable to reach the OnWay Rides backend while saving your profile.',
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

  Future<OnWayTripFeed> fetchTrips() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const OnWayAuthException('No signed-in Firebase user was found.');
    }

    final idToken = await user.getIdToken(true);
    final response = await _performJsonRequest(
      () => _httpClient.get(
        Uri.parse('$apiBaseUrl/bookings'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      ),
      fallback: 'Unable to load your OnWay trips right now.',
    );

    final responseBody = _decodeJsonBody(response.body);
    if (response.statusCode != 200) {
      throw OnWayAuthException(
        (responseBody['message'] as String?) ??
            'Unable to load your bookings right now.',
      );
    }

    final activeBooking = responseBody['active_booking'];
    final history = responseBody['history'];

    return OnWayTripFeed(
      activeTrip: activeBooking is Map<String, dynamic>
          ? _tripFromBookingJson(activeBooking)
          : null,
      history: history is List
          ? history
                .whereType<Map<String, dynamic>>()
                .map(_historyItemFromBookingJson)
                .toList(growable: false)
          : const [],
    );
  }

  Future<OnWayDriverWorkspaceBundle> fetchDriverWorkspace() async {
    final referencesPayload = await _authorizedJsonRequest(
      method: 'GET',
      path: '/onboarding/reference-data',
      fallback: 'Unable to load driver onboarding reference data.',
    );
    final workspacePayload = await _authorizedJsonRequest(
      method: 'GET',
      path: '/onboarding/workspace',
      fallback: 'Unable to load your driver workspace.',
    );

    final workspace =
        workspacePayload['workspace'] as Map<String, dynamic>? ?? const {};
    final user = workspace['user'] as Map<String, dynamic>? ?? const {};
    final driver = workspace['driver_application'] as Map<String, dynamic>?;
    final vehicle = driver?['vehicle'] as Map<String, dynamic>?;

    return OnWayDriverWorkspaceBundle(
      user: OnWayDriverWorkspaceUser(
        id: (user['id'] as num?)?.toInt() ?? 0,
        fullName: (user['full_name'] as String?) ?? 'OnWay User',
        role: (user['role'] as String?) ?? 'rider',
        email: user['email'] as String?,
        phone: user['phone'] as String?,
        countryCode: user['country_code'] as String?,
        nationalIdNumber: user['national_id_number'] as String?,
      ),
      cities: ((referencesPayload['cities'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(
            (item) => OnWaySelectOption(
              id: (item['id'] as num?)?.toInt() ?? 0,
              label: (item['name'] as String?) ?? 'City',
              slug: item['slug'] as String?,
            ),
          )
          .toList(growable: false),
      serviceTypes: ((referencesPayload['service_types'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(
            (item) => OnWaySelectOption(
              id: (item['id'] as num?)?.toInt() ?? 0,
              label: (item['name'] as String?) ?? 'Service',
              slug: item['slug'] as String?,
            ),
          )
          .toList(growable: false),
      vehicleCategories:
          ((referencesPayload['vehicle_categories'] as List?) ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(
                (item) => OnWaySelectOption(
                  id: (item['id'] as num?)?.toInt() ?? 0,
                  label: (item['name'] as String?) ?? 'Category',
                  slug: item['slug'] as String?,
                ),
              )
              .toList(growable: false),
      vehicleTypes: ((referencesPayload['vehicle_types'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(
            (item) => OnWayVehicleTypeOption(
              id: (item['id'] as num?)?.toInt() ?? 0,
              vehicleCategoryId:
                  (item['vehicle_category_id'] as num?)?.toInt() ?? 0,
              label: (item['name'] as String?) ?? 'Vehicle type',
              seats: (item['seats'] as num?)?.toInt(),
            ),
          )
          .toList(growable: false),
      vehicleMakes: ((referencesPayload['vehicle_makes'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(
            (item) => OnWaySelectOption(
              id: (item['id'] as num?)?.toInt() ?? 0,
              label: (item['name'] as String?) ?? 'Make',
            ),
          )
          .toList(growable: false),
      vehicleModels:
          ((referencesPayload['vehicle_models'] as List?) ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(
                (item) => OnWayVehicleModelOption(
                  id: (item['id'] as num?)?.toInt() ?? 0,
                  vehicleMakeId:
                      (item['vehicle_make_id'] as num?)?.toInt() ?? 0,
                  label: (item['name'] as String?) ?? 'Model',
                ),
              )
              .toList(growable: false),
      documentTypes:
          ((referencesPayload['driver_document_types'] as List?) ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(
                (item) => OnWayDriverDocumentTypeOption(
                  value: (item['value'] as String?) ?? 'other',
                  label: (item['label'] as String?) ?? 'Document',
                ),
              )
              .toList(growable: false),
      driverSamples: ((referencesPayload['driver_samples'] as Map?) ?? const {})
          .map(
            (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
          ),
      driverApplication: driver == null
          ? null
          : OnWayDriverApplication(
              driverProfileId:
                  (driver['driver_profile_id'] as num?)?.toInt() ?? 0,
              driverCode: (driver['driver_code'] as String?) ?? '',
              status: (driver['status'] as String?) ?? 'pending',
              onboardingStatus:
                  (driver['onboarding_status'] as String?) ?? 'draft',
              cityId: (driver['city_id'] as num?)?.toInt(),
              isOnline: (driver['is_online'] as bool?) ?? false,
              isBusy: (driver['is_busy'] as bool?) ?? false,
              acceptsCash: (driver['accepts_cash'] as bool?) ?? true,
              acceptsWallet: (driver['accepts_wallet'] as bool?) ?? false,
              acceptsCard: (driver['accepts_card'] as bool?) ?? false,
              ratingAverage:
                  (driver['rating_average'] as num?)?.toDouble() ?? 5,
              ratingCount: (driver['rating_count'] as num?)?.toInt() ?? 0,
              tripsCompleted: (driver['trips_completed'] as num?)?.toInt() ?? 0,
              licenseNumber: driver['license_number'] as String?,
              notes: driver['notes'] as String?,
              serviceTypeIds:
                  ((driver['service_type_ids'] as List?) ?? const [])
                      .map((item) => (item as num).toInt())
                      .toList(growable: false),
              documents: ((driver['documents'] as List?) ?? const [])
                  .whereType<Map<String, dynamic>>()
                  .map(
                    (item) => OnWayDriverDocumentSummary(
                      id: (item['id'] as num?)?.toInt() ?? 0,
                      documentType:
                          (item['document_type'] as String?) ?? 'other',
                      status: (item['status'] as String?) ?? 'pending',
                      expiryDate: item['expiry_date'] as String?,
                      updatedAt: item['updated_at'] as String?,
                    ),
                  )
                  .toList(growable: false),
              vehicle: vehicle == null
                  ? null
                  : OnWayVehicleDraft(
                      id: (vehicle['id'] as num?)?.toInt() ?? 0,
                      plateNumber: vehicle['plate_number'] as String?,
                      vehicleCategoryId:
                          (vehicle['vehicle_category_id'] as num?)?.toInt(),
                      vehicleTypeId: (vehicle['vehicle_type_id'] as num?)
                          ?.toInt(),
                      vehicleMakeId: (vehicle['vehicle_make_id'] as num?)
                          ?.toInt(),
                      vehicleModelId: (vehicle['vehicle_model_id'] as num?)
                          ?.toInt(),
                      yearOfManufacture:
                          (vehicle['year_of_manufacture'] as num?)?.toInt(),
                      seats: (vehicle['seats'] as num?)?.toInt(),
                      fuelType: vehicle['fuel_type'] as String?,
                      status: vehicle['status'] as String?,
                    ),
            ),
    );
  }

  Future<void> saveDriverApplicationDraft({
    required int cityId,
    required String licenseNumber,
    required String nationalIdNumber,
    required List<int> serviceTypeIds,
    int? vehicleCategoryId,
    int? vehicleTypeId,
    int? vehicleMakeId,
    int? vehicleModelId,
    String? vehicleMakeOther,
    String? vehicleModelOther,
    String? plateNumber,
    int? yearOfManufacture,
    int? seats,
    String? fuelType,
    String? availability,
    String? licenseStatus,
    String? notes,
  }) async {
    await _authorizedJsonRequest(
      method: 'PATCH',
      path: '/onboarding/driver',
      body: {
        'city_id': cityId,
        'license_number': licenseNumber.trim(),
        'national_id_number': nationalIdNumber.trim(),
        'vehicle_category_id': vehicleCategoryId,
        'vehicle_type_id': vehicleTypeId,
        'vehicle_make_id': vehicleMakeId,
        'vehicle_model_id': vehicleModelId,
        'vehicle_make_other': _nullableText(vehicleMakeOther),
        'vehicle_model_other': _nullableText(vehicleModelOther),
        'plate_number': _nullableText(plateNumber),
        'year_of_manufacture': yearOfManufacture,
        'seats': seats,
        'fuel_type': fuelType,
        'availability': availability,
        'license_status': licenseStatus,
        'notes': _nullableText(notes),
        'service_type_ids': serviceTypeIds,
      },
      fallback: 'Unable to save your driver application right now.',
    );
  }

  Future<void> updateDriverMode({
    required bool isOnline,
    required List<int> serviceTypeIds,
  }) async {
    await _authorizedJsonRequest(
      method: 'PATCH',
      path: '/driver/mode',
      body: {'is_online': isOnline, 'service_type_ids': serviceTypeIds},
      fallback: 'Unable to update driver mode right now.',
    );
  }

  Future<OnWayDriverDocumentSummary> uploadDriverDocument({
    required String documentType,
    required PlatformFile file,
    String? documentNumber,
    DateTime? expiryDate,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const OnWayAuthException('No signed-in Firebase user was found.');
    }

    final idToken = await user.getIdToken(true);
    final uri = Uri.parse('$apiBaseUrl/onboarding/driver-documents');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $idToken'
      ..fields['document_type'] = documentType;

    final normalizedDocumentNumber = _nullableText(documentNumber);
    if (normalizedDocumentNumber != null) {
      request.fields['document_number'] = normalizedDocumentNumber;
    }
    if (expiryDate != null) {
      request.fields['expiry_date'] = expiryDate.toIso8601String();
    }

    final bytes = file.bytes;
    if (bytes != null && bytes.isNotEmpty) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'document',
          bytes,
          filename: file.name,
          contentType: _mediaTypeForName(file.name),
        ),
      );
    } else if (file.path != null && file.path!.trim().isNotEmpty) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'document',
          file.path!,
          filename: file.name,
          contentType: _mediaTypeForName(file.name),
        ),
      );
    } else {
      throw const OnWayAuthException(
        'The selected document file could not be read from this device.',
      );
    }

    final response = await _performMultipartRequest(
      request,
      fallback: 'Unable to upload the driver document right now.',
    );

    final responseBody = _decodeJsonBody(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
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
            'Unable to upload the driver document right now.',
      );
    }

    final document = responseBody['document'];
    if (document is! Map<String, dynamic>) {
      throw const OnWayAuthException(
        'The uploaded document response was incomplete.',
      );
    }

    return OnWayDriverDocumentSummary(
      id: (document['id'] as num?)?.toInt() ?? 0,
      documentType: (document['document_type'] as String?) ?? documentType,
      status: (document['status'] as String?) ?? 'pending',
      expiryDate: document['expiry_date'] as String?,
      updatedAt: document['updated_at'] as String?,
    );
  }

  Future<OnWayDriverDispatchFeed> fetchDriverRequests() async {
    final payload = await _authorizedJsonRequest(
      method: 'GET',
      path: '/driver/requests',
      fallback: 'Unable to load live driver requests right now.',
    );

    final driverMode =
        payload['driver_mode'] as Map<String, dynamic>? ?? const {};
    final currentBooking = payload['current_booking'];
    final requests = payload['requests'];

    return OnWayDriverDispatchFeed(
      isOnline: (driverMode['is_online'] as bool?) ?? false,
      isBusy: (driverMode['is_busy'] as bool?) ?? false,
      currentTrip: currentBooking is Map<String, dynamic>
          ? OnWayDriverCurrentTrip(
              id: (currentBooking['id'] as num?)?.toInt() ?? 0,
              reference: (currentBooking['reference'] as String?) ?? '',
              serviceTitle:
                  (currentBooking['service_title'] as String?) ??
                  'OnWay Request',
              riderName: (currentBooking['rider_name'] as String?) ?? 'Rider',
              pickup: (currentBooking['pickup'] as String?) ?? 'Pickup pending',
              dropoff:
                  (currentBooking['dropoff'] as String?) ?? 'Dropoff pending',
              status: (currentBooking['status'] as String?) ?? 'accepted',
              statusLabel:
                  (currentBooking['status_label'] as String?) ?? 'Accepted',
              fareLabel:
                  (currentBooking['fare_label'] as String?) ??
                  'Fare to confirm',
              paymentLabel:
                  (currentBooking['payment_label'] as String?) ?? 'Cash',
              riderPhone: currentBooking['rider_phone'] as String?,
            )
          : null,
      requests: requests is List
          ? requests
                .whereType<Map<String, dynamic>>()
                .map(
                  (item) => DriverRequest(
                    id: (item['id'] as num?)?.toInt(),
                    reference: item['reference'] as String?,
                    serviceTitle:
                        (item['service_title'] as String?) ?? 'OnWay Request',
                    riderName: (item['rider_name'] as String?) ?? 'Rider',
                    pickup: (item['pickup'] as String?) ?? 'Pickup pending',
                    dropoff: (item['dropoff'] as String?) ?? 'Dropoff pending',
                    fareLabel:
                        (item['fare_label'] as String?) ?? 'Fare to confirm',
                    distanceLabel:
                        (item['distance_label'] as String?) ?? 'Nearby request',
                    paymentLabel: (item['payment_label'] as String?) ?? 'Cash',
                    canCounter: (item['can_counter'] as bool?) ?? false,
                    status: (item['status'] as String?) ?? 'pending',
                    statusLine:
                        (item['status_line'] as String?) ??
                        'Request ready for driver action.',
                  ),
                )
                .toList(growable: false)
          : const [],
    );
  }

  Future<void> acceptDriverRequest(int bookingId) async {
    await _authorizedJsonRequest(
      method: 'POST',
      path: '/driver/requests/$bookingId/accept',
      fallback: 'Unable to accept this request right now.',
    );
  }

  Future<void> rejectDriverRequest(int bookingId) async {
    await _authorizedJsonRequest(
      method: 'POST',
      path: '/driver/requests/$bookingId/reject',
      fallback: 'Unable to reject this request right now.',
    );
  }

  Future<void> sendDriverCounterOffer({
    required int bookingId,
    required double amount,
    String? note,
  }) async {
    await _authorizedJsonRequest(
      method: 'POST',
      path: '/driver/requests/$bookingId/counter-offer',
      body: {'amount': amount, 'note': _nullableText(note)},
      fallback: 'Unable to send a counter-offer right now.',
    );
  }

  Future<ActiveTrip> updateBookingStatus({
    required int bookingId,
    required String status,
    String? note,
    String? cancellationReason,
  }) async {
    final responseBody = await _authorizedJsonRequest(
      method: 'PATCH',
      path: '/bookings/$bookingId/status',
      body: {
        'status': status,
        'note': _nullableText(note),
        'cancellation_reason': _nullableText(cancellationReason),
      },
      fallback: 'Unable to update this booking right now.',
    );

    final booking = responseBody['booking'];
    if (booking is! Map<String, dynamic>) {
      throw const OnWayAuthException(
        'The updated booking response was incomplete.',
      );
    }

    return _tripFromBookingJson(booking);
  }

  Future<void> sendTrackingPoint({
    required int bookingId,
    required double latitude,
    required double longitude,
    double? heading,
    double? speedKmh,
    DateTime? recordedAt,
  }) async {
    await _authorizedJsonRequest(
      method: 'POST',
      path: '/bookings/$bookingId/tracking-points',
      body: {
        'latitude': latitude,
        'longitude': longitude,
        'heading': heading,
        'speed_kmh': speedKmh,
        'recorded_at': recordedAt?.toIso8601String(),
      },
      fallback: 'Unable to send live tracking right now.',
    );
  }

  Future<ActiveTrip> createBooking({
    required OnWayService service,
    required String pickupAddress,
    required String destinationAddress,
    required FareOption fare,
    required String paymentMethod,
    required bool negotiated,
    required String offeredFare,
    DateTime? scheduledFor,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const OnWayAuthException('No signed-in Firebase user was found.');
    }

    final idToken = await user.getIdToken(true);
    final response = await _performJsonRequest(
      () => _httpClient.post(
        Uri.parse('$apiBaseUrl/bookings'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'service_slug': _serviceSlugForType(service.type),
          'pickup_address': pickupAddress.trim(),
          'destination_address': destinationAddress.trim(),
          'payment_method': paymentMethod.toLowerCase(),
          'estimated_fare': _parseCurrencyLabel(fare.priceLabel),
          'offered_fare': negotiated ? _parseLooseAmount(offeredFare) : null,
          'scheduled_for': scheduledFor?.toIso8601String(),
          'metadata': {
            'mobile_service_title': service.title,
            'mobile_service_subtitle': service.subtitle,
            'mobile_fare_title': fare.title,
            'negotiated': negotiated,
          },
        }),
      ),
      fallback: 'Unable to create your booking right now.',
    );

    final responseBody = _decodeJsonBody(response.body);
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw OnWayAuthException(
        (responseBody['message'] as String?) ??
            'Unable to create your booking right now.',
      );
    }

    final booking = responseBody['booking'];
    if (booking is! Map<String, dynamic>) {
      throw const OnWayAuthException(
        'The booking response from the backend was incomplete.',
      );
    }

    return _tripFromBookingJson(booking);
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

  Future<void> signOut() async {
    await _removeCurrentDeviceToken();
    await _firebaseAuth.signOut();
  }

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

  Future<http.Response> _performJsonRequest(
    Future<http.Response> Function() request, {
    required String fallback,
  }) async {
    try {
      return await request().timeout(_requestTimeout);
    } on TimeoutException {
      throw OnWayAuthException(
        '$fallback Request timed out after ${_requestTimeout.inSeconds} seconds.',
      );
    } on SocketException catch (error) {
      throw OnWayAuthException('$fallback ${error.message}');
    } on http.ClientException catch (error) {
      throw OnWayAuthException('$fallback ${error.message}');
    } on FormatException catch (error) {
      throw OnWayAuthException('$fallback ${error.message}');
    }
  }

  Future<http.Response> _performMultipartRequest(
    http.MultipartRequest request, {
    required String fallback,
  }) async {
    try {
      final streamed = await request.send().timeout(_requestTimeout);
      return http.Response.fromStream(streamed);
    } on TimeoutException {
      throw OnWayAuthException(
        '$fallback Request timed out after ${_requestTimeout.inSeconds} seconds.',
      );
    } on SocketException catch (error) {
      throw OnWayAuthException('$fallback ${error.message}');
    } on http.ClientException catch (error) {
      throw OnWayAuthException('$fallback ${error.message}');
    } on FormatException catch (error) {
      throw OnWayAuthException('$fallback ${error.message}');
    }
  }

  Future<Map<String, dynamic>> _authorizedJsonRequest({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    required String fallback,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const OnWayAuthException('No signed-in Firebase user was found.');
    }

    final idToken = await user.getIdToken(true);
    final response = await _performJsonRequest(() {
      final uri = Uri.parse('$apiBaseUrl$path');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      };

      switch (method) {
        case 'GET':
          return _httpClient.get(uri, headers: headers);
        case 'POST':
          return _httpClient.post(
            uri,
            headers: headers,
            body: jsonEncode(body ?? const {}),
          );
        case 'PATCH':
          return _httpClient.patch(
            uri,
            headers: headers,
            body: jsonEncode(body ?? const {}),
          );
        case 'DELETE':
          return _httpClient.delete(
            uri,
            headers: headers,
            body: jsonEncode(body ?? const {}),
          );
        default:
          throw UnsupportedError('Unsupported HTTP method: $method');
      }
    }, fallback: fallback);

    final responseBody = _decodeJsonBody(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
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
        (responseBody['message'] as String?) ?? fallback,
      );
    }

    return responseBody;
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

  Future<void> _initializeRealtime() async {
    if (_realtimeInitialized) {
      await _syncCurrentDeviceToken();
      return;
    }

    _realtimeInitialized = true;

    try {
      await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {
      // Ignore permission failures on unsupported platforms.
    }

    try {
      await _firebaseMessaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {
      // Only supported on Apple platforms.
    }

    FirebaseMessaging.onMessage.listen(_handleRealtimeMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleRealtimeMessage);
    _firebaseMessaging.onTokenRefresh.listen((_) {
      unawaited(_syncCurrentDeviceToken());
    });

    await _syncCurrentDeviceToken();
  }

  Future<void> _syncCurrentDeviceToken() async {
    final user = _firebaseAuth.currentUser;
    if (user == null || !(kIsWeb || Platform.isAndroid || Platform.isIOS)) {
      return;
    }

    try {
      final token = await _firebaseMessaging.getToken();
      if (token == null || token.trim().isEmpty) {
        return;
      }

      await _authorizedJsonRequest(
        method: 'POST',
        path: '/devices/token',
        body: {
          'token': token.trim(),
          'platform': _pushPlatformLabel(),
          'device_name': _defaultPlatformLabel(),
        },
        fallback: 'Unable to register this device for live dispatch.',
      );
    } catch (_) {
      // Push registration should not block sign-in or trip usage.
    }
  }

  Future<void> _removeCurrentDeviceToken() async {
    final user = _firebaseAuth.currentUser;
    if (user == null || !(kIsWeb || Platform.isAndroid || Platform.isIOS)) {
      return;
    }

    try {
      final token = await _firebaseMessaging.getToken();
      if (token == null || token.trim().isEmpty) {
        return;
      }

      await _authorizedJsonRequest(
        method: 'DELETE',
        path: '/devices/token',
        body: {'token': token.trim()},
        fallback: 'Unable to unregister this device from live dispatch.',
      );
    } catch (_) {
      // Signing out should still complete even if token cleanup fails.
    }
  }

  void _handleRealtimeMessage(RemoteMessage message) {
    final data = message.data.map(
      (key, value) => MapEntry(key, value.toString()),
    );
    final channel = data['channel']?.trim();
    final type = data['type']?.trim();

    if (channel == null || channel.isEmpty || type == null || type.isEmpty) {
      return;
    }

    _realtimeEventsController.add(
      OnWayRealtimeEvent(
        channel: channel,
        type: type,
        bookingId: int.tryParse(data['booking_id'] ?? ''),
        status: data['status'],
        data: data,
      ),
    );
  }

  String _pushPlatformLabel() {
    if (kIsWeb) {
      return 'web';
    }
    if (Platform.isIOS) {
      return 'ios';
    }
    return 'android';
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

  ActiveTrip _tripFromBookingJson(Map<String, dynamic> json) {
    final service = json['service'] as Map<String, dynamic>? ?? const {};

    return ActiveTrip(
      bookingId: (json['id'] as num?)?.toInt(),
      bookingReference: json['reference'] as String?,
      status: json['status'] as String?,
      serviceTitle: (service['name'] as String?) ?? 'OnWay Booking',
      pickup: (json['pickup_address'] as String?) ?? 'Pickup pending',
      destination:
          (json['destination_address'] as String?) ?? 'Destination pending',
      statusLine:
          (json['status_line'] as String?) ?? 'Booking created successfully',
      routeLine: (json['route_line'] as String?) ?? '',
      paymentLabel: (json['payment_label'] as String?) ?? 'Cash payment',
      fareLabel: (json['fare_label'] as String?) ?? 'Fare to confirm',
      driver: _driverFromBookingJson(json['driver']),
    );
  }

  TripHistoryItem _historyItemFromBookingJson(Map<String, dynamic> json) {
    final service = json['service'] as Map<String, dynamic>? ?? const {};

    return TripHistoryItem(
      reference: json['reference'] as String?,
      title: (service['name'] as String?) ?? 'OnWay Booking',
      dateLabel: _bookingDateLabel(
        json['scheduled_for'] as String?,
        json['requested_at'] as String?,
      ),
      route: (json['route_line'] as String?) ?? '',
      amount: (json['fare_label'] as String?) ?? 'Fare to confirm',
      status: (json['status_label'] as String?) ?? 'Pending',
    );
  }

  DriverProfile? _driverFromBookingJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      return null;
    }

    final name = json['name'] as String?;
    if (name == null || name.trim().isEmpty) {
      return null;
    }

    return DriverProfile(
      name: name,
      rating: (json['rating'] as String?) ?? '--',
      vehicle: (json['vehicle'] as String?) ?? 'Vehicle pending',
      plate: (json['plate'] as String?) ?? 'Plate pending',
      phone: (json['phone'] as String?) ?? 'Phone pending',
      distanceAway: (json['distance_away'] as String?) ?? 'Dispatch pending',
      eta: (json['eta'] as String?) ?? 'Assigning driver',
      avatarAsset: 'assets/showcase/driver_profile.png',
    );
  }

  String _bookingDateLabel(String? scheduledFor, String? requestedAt) {
    final source = scheduledFor?.trim().isNotEmpty == true
        ? scheduledFor!.trim()
        : requestedAt?.trim();

    if (source == null || source.isEmpty) {
      return 'Just now';
    }

    final parsed = DateTime.tryParse(source)?.toLocal();
    if (parsed == null) {
      return source;
    }

    final month = _monthLabel(parsed.month);
    final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
    final meridiem = parsed.hour >= 12 ? 'PM' : 'AM';

    return '${parsed.day} $month, $hour:${parsed.minute.toString().padLeft(2, '0')} $meridiem';
  }

  String _monthLabel(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final safeIndex = month < 1
        ? 0
        : month > months.length
        ? months.length - 1
        : month - 1;

    return months[safeIndex];
  }

  String _serviceSlugForType(ServiceType type) {
    switch (type) {
      case ServiceType.courier:
        return 'courier';
      case ServiceType.rentCar:
        return 'rental';
      case ServiceType.foodDelivery:
        return 'food';
      case ServiceType.schoolOffice:
        return 'school';
      case ServiceType.airport:
        return 'airport';
      case ServiceType.prebooking:
        return 'prebooking';
      case ServiceType.rideShare:
      case ServiceType.taxi:
      case ServiceType.bikeTaxi:
      case ServiceType.rickshawTaxi:
      case ServiceType.cityToCity:
        return 'ride';
    }
  }

  double? _parseCurrencyLabel(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9.]'), '');
    if (digits.isEmpty) {
      return null;
    }

    return double.tryParse(digits);
  }

  double? _parseLooseAmount(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9.]'), '');
    if (digits.isEmpty) {
      return null;
    }

    return double.tryParse(digits);
  }

  String? _nullableText(String? value) {
    if (value == null) {
      return null;
    }

    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  MediaType _mediaTypeForName(String fileName) {
    final lowerName = fileName.toLowerCase();
    if (lowerName.endsWith('.png')) {
      return MediaType('image', 'png');
    }
    if (lowerName.endsWith('.webp')) {
      return MediaType('image', 'webp');
    }
    if (lowerName.endsWith('.pdf')) {
      return MediaType('application', 'pdf');
    }

    return MediaType('image', 'jpeg');
  }
}
