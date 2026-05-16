import 'offline_database.dart';

class OfflineCacheRepository {
  const OfflineCacheRepository(this._database);

  final OfflineDatabase _database;

  Future<void> cacheList(String key, List<Map<String, dynamic>> items) {
    return _database.putCache(key, items);
  }

  Future<List<Map<String, dynamic>>> readList(String key) async {
    final payload = await _database.getCache(key);
    final items = payload as List<dynamic>? ?? const [];
    return items
        .map((item) => Map<String, dynamic>.from(item as Map<dynamic, dynamic>))
        .toList();
  }

  Future<void> cacheMap(String key, Map<String, dynamic> value) {
    return _database.putCache(key, value);
  }

  Future<Map<String, dynamic>?> readMap(String key) async {
    final payload = await _database.getCache(key);
    if (payload == null) {
      return null;
    }

    return Map<String, dynamic>.from(payload as Map<dynamic, dynamic>);
  }
}
