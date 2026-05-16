class OperationalInsights {
  const OperationalInsights({
    required this.windowDays,
    required this.dailySnapshot,
    required this.alerts,
  });

  final int windowDays;
  final OperationalSnapshot dailySnapshot;
  final List<OperationalAlert> alerts;

  factory OperationalInsights.fromJson(Map<String, dynamic> json) {
    final alerts = json['alerts'] as List<dynamic>? ?? const [];
    return OperationalInsights(
      windowDays: json['windowDays'] as int? ?? 7,
      dailySnapshot: OperationalSnapshot.fromJson(
        Map<String, dynamic>.from(
          (json['dailySnapshot'] as Map?) ?? const {},
        ),
      ),
      alerts: alerts
          .map((item) => OperationalAlert.fromJson(
                Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
              ))
          .toList(),
    );
  }
}

class OperationalSnapshot {
  const OperationalSnapshot({
    required this.activeSessions,
    required this.todayCollections,
    required this.lowStockCount,
    required this.largeBalanceCount,
    required this.reconciliationRiskCount,
  });

  final int activeSessions;
  final double todayCollections;
  final int lowStockCount;
  final int largeBalanceCount;
  final int reconciliationRiskCount;

  factory OperationalSnapshot.fromJson(Map<String, dynamic> json) {
    return OperationalSnapshot(
      activeSessions: json['activeSessions'] as int? ?? 0,
      todayCollections: (json['todayCollections'] as num?)?.toDouble() ?? 0,
      lowStockCount: json['lowStockCount'] as int? ?? 0,
      largeBalanceCount: json['largeBalanceCount'] as int? ?? 0,
      reconciliationRiskCount: json['reconciliationRiskCount'] as int? ?? 0,
    );
  }
}

class OperationalAlert {
  const OperationalAlert({
    required this.type,
    required this.severity,
    required this.message,
    this.refId,
  });

  final String type;
  final String severity;
  final String message;
  final String? refId;

  factory OperationalAlert.fromJson(Map<String, dynamic> json) {
    return OperationalAlert(
      type: json['type'] as String? ?? '',
      severity: json['severity'] as String? ?? 'LOW',
      message: json['message'] as String? ?? '',
      refId: json['refId'] as String?,
    );
  }
}
