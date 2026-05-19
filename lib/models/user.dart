class AppUser {
  final String id;
  final String deviceId;
  final int balance;
  final bool isPremium;
  final DateTime? premiumExpiresAt;
  final DateTime? nextSurveyAvailableAt;
  final int bonusSurveysUsedToday;
  final bool consentGiven;
  final double fraudScore;
  final bool flagged;
  final DateTime createdAt;
  final DateTime? lastActiveAt;

  AppUser({
    required this.id,
    required this.deviceId,
    required this.balance,
    required this.isPremium,
    this.premiumExpiresAt,
    this.nextSurveyAvailableAt,
    required this.bonusSurveysUsedToday,
    required this.consentGiven,
    required this.fraudScore,
    required this.flagged,
    required this.createdAt,
    this.lastActiveAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'],
        deviceId: json['device_id'],
        balance: json['balance'] ?? 0,
        isPremium: json['is_premium'] ?? false,
        premiumExpiresAt: json['premium_expires_at'] != null
            ? DateTime.parse(json['premium_expires_at'])
            : null,
        nextSurveyAvailableAt: json['next_survey_available_at'] != null
            ? DateTime.parse(json['next_survey_available_at'])
            : null,
        bonusSurveysUsedToday: json['bonus_surveys_used_today'] ?? 0,
        consentGiven: json['consent_given'] ?? false,
        fraudScore: (json['fraud_score'] ?? 0).toDouble(),
        flagged: json['flagged'] ?? false,
        createdAt: DateTime.parse(json['created_at']),
        lastActiveAt: json['last_active_at'] != null
            ? DateTime.parse(json['last_active_at'])
            : null,
      );

  double get dollarBalance => balance / 1000.0;
}
