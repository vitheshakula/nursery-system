class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.vendorId,
    required this.amount,
    required this.mode,
    required this.createdAt,
    this.sessionId,
    this.vendorBalance,
  });

  final String id;
  final String vendorId;
  final String? sessionId;
  final double amount;
  final String mode;
  final DateTime? createdAt;
  final double? vendorBalance;

  factory PaymentRecord.fromJson(Map<String, dynamic> json) {
    return PaymentRecord(
      id: json['id'] as String? ?? '',
      vendorId: json['vendorId'] as String? ?? '',
      sessionId: json['sessionId'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      mode: json['mode'] as String? ?? '',
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'] as String),
      vendorBalance: (json['vendorBalance'] as num?)?.toDouble(),
    );
  }
}
