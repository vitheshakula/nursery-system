class Vendor {
  const Vendor({
    required this.id,
    required this.name,
    required this.phone,
    required this.balance,
  });

  final String id;
  final String name;
  final String phone;
  final double balance;

  factory Vendor.fromJson(Map<String, dynamic> json) {
    return Vendor(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
    );
  }
}
