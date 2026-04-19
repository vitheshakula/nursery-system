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

  Vendor copyWith({
    String? id,
    String? name,
    String? phone,
    double? balance,
  }) {
    return Vendor(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      balance: balance ?? this.balance,
    );
  }

  factory Vendor.fromJson(Map<String, dynamic> json) {
    return Vendor(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
    );
  }
}
