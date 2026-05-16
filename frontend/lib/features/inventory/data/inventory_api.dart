import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/offline/offline_cache_repository.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../models/category.dart';
import '../../../models/item.dart';
import '../../auth/presentation/auth_provider.dart';

final inventoryApiProvider = Provider<InventoryApi>((ref) {
  return InventoryApi(
    ref.watch(apiClientProvider),
    cache: ref.watch(offlineCacheProvider),
  );
});

class InventoryApi {
  const InventoryApi(this._apiClient, {this.cache});

  final ApiClient _apiClient;
  final OfflineCacheRepository? cache;

  Future<List<Category>> getCategories() async {
    const cacheKey = 'categories';
    try {
    final data = await _apiClient.get('/categories');
    final rows = _list(data);
    await cache?.cacheList(cacheKey, rows);
    return rows.map(Category.fromJson).toList();
    } on ApiException catch (error) {
      if (error.type != ApiExceptionType.network || cache == null) rethrow;
      return (await cache!.readList(cacheKey)).map(Category.fromJson).toList();
    }
  }

  Future<Category> createCategory(String name) async {
    final data = await _apiClient.post('/categories', body: {'name': name});
    return Category.fromJson(_map(data));
  }

  Future<List<Item>> getItems({int limit = 200}) async {
    final cacheKey = 'plants:$limit';
    try {
    final data = await _apiClient.get('/plants?page=1&limit=$limit');
    final rows = _list(data);
    await cache?.cacheList(cacheKey, rows);
    return rows.map(Item.fromJson).toList();
    } on ApiException catch (error) {
      if (error.type != ApiExceptionType.network || cache == null) rethrow;
      return (await cache!.readList(cacheKey)).map(Item.fromJson).toList();
    }
  }

  Future<Item> createItem({
    required String name,
    required String categoryId,
    required double vendorPrice,
    double? retailPrice,
    int initialStock = 0,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'categoryId': categoryId,
      'vendorPrice': vendorPrice,
      'initialStock': initialStock,
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
