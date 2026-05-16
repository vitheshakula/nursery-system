import 'session_info.dart';
import 'vendor.dart';

class ActiveSession {
  const ActiveSession({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    required this.vendorPhone,
    required this.vendorBalance,
    required this.status,
    required this.totalIssued,
    required this.totalReturned,
    required this.totalBill,
    this.createdAt,
  });

  final String id;
  final String vendorId;
  final String vendorName;
  final String vendorPhone;
  final double vendorBalance;
  final String status;
  final int totalIssued;
  final int totalReturned;
  final double totalBill;
  final DateTime? createdAt;

  SessionInfo toSessionInfo() {
    return SessionInfo(id: id, vendorId: vendorId, status: status);
  }

  Vendor toVendor() {
    return Vendor(
      id: vendorId,
      name: vendorName,
      phone: vendorPhone,
      balance: vendorBalance,
    );
  }

  factory ActiveSession.fromJson(Map<String, dynamic> json) {
    final vendor =
        Map<String, dynamic>.from((json['vendor'] as Map?) ?? const {});

    return ActiveSession(
      id: json['id'] as String? ?? '',
      vendorId: json['vendorId'] as String? ?? vendor['id'] as String? ?? '',
      vendorName: vendor['name'] as String? ?? 'Unknown vendor',
      vendorPhone: vendor['phone'] as String? ?? '',
      vendorBalance: (vendor['balance'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? '',
      totalIssued: json['totalIssued'] as int? ?? 0,
      totalReturned: json['totalReturned'] as int? ?? 0,
      totalBill: (json['totalBill'] as num?)?.toDouble() ?? 0,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'] as String),
    );
  }
}
