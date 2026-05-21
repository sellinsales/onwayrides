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
    this.email,
    this.phone,
    this.avatarUrl,
  });

  final int userId;
  final String firebaseUid;
  final String fullName;
  final String role;
  final String status;
  final String betaMode;
  final int dailyRideLimit;
  final bool fullAccessRequiresDriverApproval;
  final String? email;
  final String? phone;
  final String? avatarUrl;

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

  factory OnWayAuthSession.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? const {};
    final beta = json['beta'] as Map<String, dynamic>? ?? const {};

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
      email: user['email'] as String?,
      phone: user['phone'] as String?,
      avatarUrl: user['avatar_url'] as String?,
    );
  }
}
