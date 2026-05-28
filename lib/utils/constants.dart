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
  // Terms (EULA) + Privacy Policy links on the paywall. TODO: confirm
  // these resolve to the real published pages before App Review.
  static const String termsUrl = 'https://admin.harsaniq.top/terms';
  static const String privacyUrl = 'https://admin.harsaniq.top/privacy';
}
