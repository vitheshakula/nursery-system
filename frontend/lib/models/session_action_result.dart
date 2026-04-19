class SessionActionResult {
  const SessionActionResult({
    required this.sessionId,
    required this.itemCount,
    required this.totalQuantity,
  });

  final String sessionId;
  final int itemCount;
  final int totalQuantity;

  factory SessionActionResult.fromIssueJson(Map<String, dynamic> json) {
    return SessionActionResult(
      sessionId: json['sessionId'] as String? ?? '',
      itemCount: json['issuedItemsCount'] as int? ?? 0,
      totalQuantity: json['totalIssuedQuantity'] as int? ?? 0,
    );
  }

  factory SessionActionResult.fromReturnJson(Map<String, dynamic> json) {
    return SessionActionResult(
      sessionId: json['sessionId'] as String? ?? '',
      itemCount: json['returnedItemsCount'] as int? ?? 0,
      totalQuantity: json['totalReturnedQuantity'] as int? ?? 0,
    );
  }
}
