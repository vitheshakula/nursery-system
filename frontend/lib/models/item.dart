class Item {
  const Item({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.vendorPrice,
    required this.currentStock,
    this.retailPrice,
  });

  final String id;
  final String name;
  final String categoryId;
  final double vendorPrice;
  final int currentStock;
  final double? retailPrice;

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      categoryId: json['categoryId'] as String? ?? '',
      vendorPrice: (json['vendorPrice'] as num?)?.toDouble() ?? 0,
      currentStock: (json['currentStock'] as num?)?.toInt() ?? 0,
      retailPrice: (json['retailPrice'] as num?)?.toDouble(),
    );
  }
}
