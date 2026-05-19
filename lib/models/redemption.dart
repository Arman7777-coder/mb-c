class Redemption {
  final String id;
  final int amount;
  final double dollarValue;
  final String payoutMethod;
  final Map<String, dynamic>? payoutDetails;
  final String status;
  final String? adminNotes;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime? reviewedAt;

  Redemption({
    required this.id,
    required this.amount,
    required this.dollarValue,
    required this.payoutMethod,
    this.payoutDetails,
    required this.status,
    this.adminNotes,
    this.rejectionReason,
    required this.createdAt,
    this.reviewedAt,
  });

  factory Redemption.fromJson(Map<String, dynamic> json) => Redemption(
        id: json['id'],
        amount: json['amount'],
        dollarValue: (json['dollar_value'] as num).toDouble(),
        payoutMethod: json['payout_method'],
        payoutDetails: json['payout_details'],
        status: json['status'],
        adminNotes: json['admin_notes'],
        rejectionReason: json['rejection_reason'],
        createdAt: DateTime.parse(json['created_at']),
        reviewedAt: json['reviewed_at'] != null
            ? DateTime.parse(json['reviewed_at'])
            : null,
      );

  String get methodLabel {
    switch (payoutMethod) {
      case 'paypal':
        return 'PayPal';
      case 'amazon_gift_card':
        return 'Amazon Gift Card';
      case 'crypto':
        return 'Crypto';
      default:
        return payoutMethod;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Pending Review';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }
}
