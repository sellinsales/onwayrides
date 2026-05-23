class OnWayAuthSession {
  const OnWayAuthSession({
    required this.userId,
    required this.firebaseUid,
    required this.fullName,
    required this.role,
    required this.status,
    required this.betaMode,
    required this.dailyRideLimit,
    required this.fullAccessRequiresDriverApproval,
    required this.phoneVerificationRequired,
    required this.profileComplete,
    required this.needsPhoneNumber,
    required this.needsPhoneVerification,
    required this.needsPrivacyAcceptance,
    required this.needsTermsAcceptance,
    required this.smsMarketingOptIn,
    required this.whatsappMarketingOptIn,
    this.email,
    this.phone,
    this.countryCode,
    this.avatarUrl,
    this.phoneVerifiedAt,
    this.privacyPolicyAcceptedAt,
    this.termsOfServiceAcceptedAt,
  });

  final int userId;
  final String firebaseUid;
  final String fullName;
  final String role;
  final String status;
  final String betaMode;
  final int dailyRideLimit;
  final bool fullAccessRequiresDriverApproval;
  final bool phoneVerificationRequired;
  final bool profileComplete;
  final bool needsPhoneNumber;
  final bool needsPhoneVerification;
  final bool needsPrivacyAcceptance;
  final bool needsTermsAcceptance;
  final bool smsMarketingOptIn;
  final bool whatsappMarketingOptIn;
  final String? email;
  final String? phone;
  final String? countryCode;
  final String? avatarUrl;
  final String? phoneVerifiedAt;
  final String? privacyPolicyAcceptedAt;
  final String? termsOfServiceAcceptedAt;

  String get roleLabel => switch (role) {
    'driver' => 'Driver',
    'fleet_owner' => 'Fleet Owner',
    'merchant' => 'Merchant',
    _ => 'Rider',
  };

  String get primaryModeLabel => role == 'driver' ? 'Driver' : 'Rider';

  String get statusLabel {
    if (status.isEmpty) {
      return 'Pending';
    }

    final normalized = status.replaceAll('_', ' ');

    return normalized[0].toUpperCase() + normalized.substring(1);
  }

  String get betaModeLabel => betaMode == 'free-beta' ? 'Free beta' : betaMode;

  String get dailyRideLimitLabel => 'Max $dailyRideLimit rides/day';

  bool get phoneVerified =>
      phoneVerifiedAt != null && phoneVerifiedAt!.isNotEmpty;

  factory OnWayAuthSession.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? const {};
    final beta = json['beta'] as Map<String, dynamic>? ?? const {};
    final requirements =
        json['requirements'] as Map<String, dynamic>? ?? const {};
    final consents = json['consents'] as Map<String, dynamic>? ?? const {};

    return OnWayAuthSession(
      userId: (user['id'] as num?)?.toInt() ?? 0,
      firebaseUid: (user['firebase_uid'] as String?) ?? '',
      fullName: (user['full_name'] as String?) ?? 'OnWay User',
      role: (user['role'] as String?) ?? 'rider',
      status: (user['status'] as String?) ?? 'pending',
      betaMode: (beta['mode'] as String?) ?? 'free-beta',
      dailyRideLimit: (beta['daily_rides_limit'] as num?)?.toInt() ?? 3,
      fullAccessRequiresDriverApproval:
          (beta['full_access_requires_driver_approval'] as bool?) ?? true,
      phoneVerificationRequired:
          (beta['phone_verification_required'] as bool?) ?? false,
      profileComplete: (requirements['profile_complete'] as bool?) ?? false,
      needsPhoneNumber: (requirements['needs_phone_number'] as bool?) ?? true,
      needsPhoneVerification:
          (requirements['needs_phone_verification'] as bool?) ?? true,
      needsPrivacyAcceptance:
          (requirements['needs_privacy_acceptance'] as bool?) ?? true,
      needsTermsAcceptance:
          (requirements['needs_terms_acceptance'] as bool?) ?? true,
      smsMarketingOptIn: (consents['sms_marketing_opt_in'] as bool?) ?? false,
      whatsappMarketingOptIn:
          (consents['whatsapp_marketing_opt_in'] as bool?) ?? false,
      email: user['email'] as String?,
      phone: user['phone'] as String?,
      countryCode: user['country_code'] as String?,
      avatarUrl: user['avatar_url'] as String?,
      phoneVerifiedAt: user['phone_verified_at'] as String?,
      privacyPolicyAcceptedAt:
          consents['privacy_policy_accepted_at'] as String?,
      termsOfServiceAcceptedAt:
          consents['terms_of_service_accepted_at'] as String?,
    );
  }
}
