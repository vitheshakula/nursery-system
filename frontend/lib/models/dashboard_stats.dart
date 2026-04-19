class DashboardStats {
  const DashboardStats({
    required this.totalSales,
    required this.activeSessions,
    required this.vendorsWithBalance,
  });

  final double totalSales;
  final int activeSessions;
  final int vendorsWithBalance;

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalSales: (json['totalSales'] as num?)?.toDouble() ?? 0,
      activeSessions: json['activeSessions'] as int? ?? 0,
      vendorsWithBalance: json['vendorsWithBalance'] as int? ?? 0,
    );
  }
}
