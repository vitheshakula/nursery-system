class VendorSession {
  const VendorSession({
    required this.id,
    required this.status,
    required this.totalIssued,
    required this.totalReturned,
    required this.totalSold,
    required this.totalBill,
    this.createdAt,
    this.closedAt,
  });

  final String id;
  final String status;
  final int totalIssued;
  final int totalReturned;
  final int totalSold;
  final double totalBill;
  final DateTime? createdAt;
  final DateTime? closedAt;

  factory VendorSession.fromJson(Map<String, dynamic> json) {
    return VendorSession(
      id: json['id'] as String? ?? '',
      status: json['status'] as String? ?? '',
      totalIssued: json['totalIssued'] as int? ?? 0,
      totalReturned: json['totalReturned'] as int? ?? 0,
      totalSold: json['totalSold'] as int? ?? 0,
      totalBill: (json['totalBill'] as num?)?.toDouble() ?? 0,
      createdAt: json['createdAt'] == null ? null : DateTime.tryParse(json['createdAt'] as String),
      closedAt: json['closedAt'] == null ? null : DateTime.tryParse(json['closedAt'] as String),
    );
  }
}
