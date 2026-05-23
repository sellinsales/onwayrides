final class OnWayLinks {
  static final Uri privacyPolicy = Uri.parse(
    'https://onwayrides.com/pages/privacy.html',
  );

  static final Uri termsOfService = Uri.parse(
    'https://onwayrides.com/pages/terms.html',
  );

  static final Uri deleteAccount = Uri.parse(
    'https://onwayrides.com/pages/delete-account.html',
  );

  static final Uri supportCenter = Uri.parse(
    'https://onwayrides.com/pages/help.html',
  );

  static final Uri supportEmail = Uri(
    scheme: 'mailto',
    path: 'support@onwayrides.com',
    query: 'subject=OnWay%20Rides%20Support',
  );

  static final Uri deleteAccountEmail = Uri(
    scheme: 'mailto',
    path: 'support@onwayrides.com',
    query: 'subject=Account%20Deletion%20Request',
  );

  const OnWayLinks._();
}
