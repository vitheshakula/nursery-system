class SessionSummary {
  const SessionSummary({
    required this.sessionId,
    required this.vendorName,
    required this.status,
    required this.totalIssued,
    required this.totalReturned,
    required this.totalSold,
    required this.totalBill,
    required this.items,
  });

  final String sessionId;
  final String vendorName;
  final String status;
  final int totalIssued;
  final int totalReturned;
  final int totalSold;
  final double totalBill;
  final List<SessionSummaryItem> items;

  factory SessionSummary.fromJson(Map<String, dynamic> json) {
    final vendor = Map<String, dynamic>.from((json['vendor'] as Map?) ?? const {});
    final rawItems = json['plants'] as List<dynamic>? ?? const [];

    return SessionSummary(
      sessionId: json['sessionId'] as String? ?? '',
      vendorName: vendor['name'] as String? ?? 'Unknown vendor',
      status: json['status'] as String? ?? '',
      totalIssued: json['totalIssued'] as int? ?? 0,
      totalReturned: json['totalReturned'] as int? ?? 0,
      totalSold: json['totalSold'] as int? ?? 0,
      totalBill: (json['totalBill'] as num?)?.toDouble() ?? 0,
      items: rawItems
          .map((item) => SessionSummaryItem.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
    );
  }
}

class SessionSummaryItem {
  const SessionSummaryItem({
    required this.plantId,
    required this.name,
    required this.issued,
    required this.returned,
    required this.sold,
    required this.unitPrice,
    required this.total,
  });

  final String plantId;
  final String name;
  final int issued;
  final int returned;
  final int sold;
  final double unitPrice;
  final double total;

  factory SessionSummaryItem.fromJson(Map<String, dynamic> json) {
    return SessionSummaryItem(
      plantId: json['plantId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      issued: json['issued'] as int? ?? 0,
      returned: json['returned'] as int? ?? 0,
      sold: json['sold'] as int? ?? 0,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
    );
  }
}
