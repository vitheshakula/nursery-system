class SessionInfo {
  const SessionInfo({
    required this.id,
    required this.vendorId,
    required this.status,
  });

  final String id;
  final String vendorId;
  final String status;

  factory SessionInfo.fromJson(Map<String, dynamic> json) {
    return SessionInfo(
      id: json['id'] as String? ?? '',
      vendorId: json['vendorId'] as String? ?? '',
      status: json['status'] as String? ?? '',
    );
  }
}
