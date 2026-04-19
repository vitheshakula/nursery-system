class SessionCloseResult {
  const SessionCloseResult({
    required this.sessionId,
    required this.status,
    required this.totalBill,
    required this.totalSold,
    required this.vendorBalance,
  });

  final String sessionId;
  final String status;
  final double totalBill;
  final int totalSold;
  final double vendorBalance;

  factory SessionCloseResult.fromJson(Map<String, dynamic> json) {
    return SessionCloseResult(
      sessionId: json['sessionId'] as String? ?? '',
      status: json['status'] as String? ?? '',
      totalBill: (json['totalBill'] as num?)?.toDouble() ?? 0,
      totalSold: json['totalSold'] as int? ?? 0,
      vendorBalance: (json['vendorBalance'] as num?)?.toDouble() ?? 0,
    );
  }
}
