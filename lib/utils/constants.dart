class AppConstants {
  static const String apiBaseUrl = 'https://admin.harsaniq.top';
  static const int pointsPerDollar = 1000;
  static const int minimumRedemption = 5000;
  static const int cooldownHours = 8;
  static const int premiumBonusSurveysPerDay = 3;
  static const double adMultiplier = 2.0;
  static const double premiumMultiplier = 1.5;
  static const String appName = 'Survey Rewards';
  static const String appTagline = 'Share your opinion. Earn rewards.';

  // Subscription paywall legal links. Apple/Google require functional
  // Terms (EULA) + Privacy Policy links on the paywall. Both are Google
  // Docs in /preview (read-only) form — the docs must be shared publicly
  // ("Anyone with the link → Viewer") or App Review hits a sign-in wall.
  static const String termsUrl =
      'https://docs.google.com/document/d/1Bm7h3o_nCpox0RHWYNIybpk120QXik3P94bqW6ccUMY/preview';
  static const String privacyUrl =
      'https://docs.google.com/document/d/1PPM_JIpwi1JmgIbWQ-b3j46Rovm_00ITtecpN15w5x4/preview';
}
