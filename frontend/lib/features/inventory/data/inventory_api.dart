import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../models/category.dart';
import '../../../models/item.dart';
import '../../auth/presentation/auth_provider.dart';

final inventoryApiProvider = Provider<InventoryApi>((ref) {
  return InventoryApi(ref.watch(apiClientProvider));
});

class InventoryApi {
  const InventoryApi(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Category>> getCategories() async {
    final data = await _apiClient.get('/categories');
    return _list(data).map(Category.fromJson).toList();
  }

  Future<Category> createCategory(String name) async {
    final data = await _apiClient.post('/categories', body: {'name': name});
    return Category.fromJson(_map(data));
  }

  Future<List<Item>> getItems({int limit = 200}) async {
    final data = await _apiClient.get('/plants?page=1&limit=$limit');
    return _list(data).map(Item.fromJson).toList();
  }

  Future<Item> createItem({
    required String name,
    required String categoryId,
    required double vendorPrice,
    double? retailPrice,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'categoryId': categoryId,
      'vendorPrice': vendorPrice,
    };
    if (retailPrice != null) {
      body['retailPrice'] = retailPrice;
    }

    final data = await _apiClient.post('/plants', body: body);
    return Item.fromJson(_map(data));
  }

  Map<String, dynamic> _map(Object? value) {
    return Map<String, dynamic>.from(value as Map<dynamic, dynamic>);
  }

  List<Map<String, dynamic>> _list(Object? value) {
    final items = value as List<dynamic>? ?? const [];
    return items
        .map((item) => Map<String, dynamic>.from(item as Map<dynamic, dynamic>))
        .toList();
  }
}
