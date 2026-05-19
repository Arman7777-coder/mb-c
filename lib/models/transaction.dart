class AppTransaction {
  final String id;
  final String type;
  final int amount;
  final int balanceAfter;
  final String? description;
  final DateTime createdAt;

  AppTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    this.description,
    required this.createdAt,
  });

  factory AppTransaction.fromJson(Map<String, dynamic> json) => AppTransaction(
        id: json['id'],
        type: json['type'],
        amount: json['amount'],
        balanceAfter: json['balance_after'],
        description: json['description'],
        createdAt: DateTime.parse(json['created_at']),
      );

  bool get isEarning => amount > 0;

  String get typeLabel {
    switch (type) {
      case 'survey_reward':
        return 'Survey Completed';
      case 'ad_bonus':
        return 'Ad Bonus';
      case 'premium_bonus':
        return 'Premium Bonus';
      case 'redemption':
        return 'Redemption';
      case 'adjustment':
        return 'Adjustment';
      default:
        return type;
    }
  }

  String get typeIcon {
    switch (type) {
      case 'survey_reward':
        return '📋';
      case 'ad_bonus':
        return '🎬';
      case 'premium_bonus':
        return '⭐';
      case 'redemption':
        return '💸';
      case 'adjustment':
        return '🔧';
      default:
        return '📌';
    }
  }
}
