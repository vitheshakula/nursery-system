import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/offline/offline_cache_repository.dart';
import '../../../models/vendor.dart';
import '../../../models/vendor_session.dart';

class VendorApi {
  const VendorApi(this._apiClient, {this.cache});

  final ApiClient _apiClient;
  final OfflineCacheRepository? cache;

  Future<List<Vendor>> getVendors() async {
    const cacheKey = 'vendors';
    try {
    final data = await _apiClient.get('/vendors');
    final rows = _list(data);
    await cache?.cacheList(cacheKey, rows);
    return rows.map(Vendor.fromJson).toList();
    } on ApiException catch (error) {
      if (error.type != ApiExceptionType.network || cache == null) rethrow;
      return (await cache!.readList(cacheKey)).map(Vendor.fromJson).toList();
    }
  }

  Future<Vendor> getVendor(String id) async {
    final data = await _apiClient.get('/vendors/$id');
    return Vendor.fromJson(_map(data));
  }

  Future<List<VendorSession>> getVendorSessions(String id) async {
    final data = await _apiClient.get('/vendors/$id/sessions');
    return _list(data).map(VendorSession.fromJson).toList();
  }

  Future<Vendor> createVendor({
    required String name,
    required String phone,
  }) async {
    final data = await _apiClient.post(
      '/vendors',
      body: {
        'name': name,
        'phone': phone,
      },
    );

    return Vendor.fromJson(_map(data));
  }

  Future<Vendor> updateVendor({
    required String id,
    required String name,
    required String phone,
  }) async {
    final data = await _apiClient.put(
      '/vendors/$id',
      body: {
        'name': name,
        'phone': phone,
      },
    );

    return Vendor.fromJson(_map(data));
  }

  Future<void> deleteVendor(String id) async {
    await _apiClient.delete('/vendors/$id');
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
