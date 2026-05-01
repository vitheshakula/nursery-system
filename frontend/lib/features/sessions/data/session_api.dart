import '../../../core/network/api_client.dart';
import '../../../models/category.dart';
import '../../../models/item.dart';
import '../../../models/session_close_result.dart';
import '../../../models/session_info.dart';
import '../../../models/session_summary.dart';

class SessionApi {
  const SessionApi(this._apiClient);

  final ApiClient _apiClient;

  Future<SessionInfo> startSession(String vendorId) async {
    final data = await _apiClient.post(
      '/sessions/start',
      body: {'vendorId': vendorId},
    );
    return SessionInfo.fromJson(_map(data));
  }

  Future<void> submitIssueItems({
    required String sessionId,
    required Map<String, int> quantities,
  }) async {
    await _apiClient.post(
      '/sessions/$sessionId/issue',
      body: {'items': _buildItems(quantities)},
    );
  }

  Future<void> submitReturnItems({
    required String sessionId,
    required Map<String, int> quantities,
  }) async {
    await _apiClient.post(
      '/sessions/$sessionId/return',
      body: {
        'items': _buildItems(quantities)
            .map((item) => {
                  ...item,
                  'condition': 'GOOD',
                })
            .toList(),
      },
    );
  }

  Future<SessionSummary> getSessionSummary(String sessionId) async {
    final data = await _apiClient.get('/sessions/$sessionId/summary');
    return SessionSummary.fromJson(_map(data));
  }

  Future<SessionCloseResult> closeSession(String sessionId) async {
    final data = await _apiClient.post('/sessions/$sessionId/close');
    return SessionCloseResult.fromJson(_map(data));
  }

  Future<List<Item>> getItems({int limit = 200}) async {
    final data = await _apiClient.get('/plants?page=1&limit=$limit');
    return _list(data).map(Item.fromJson).toList();
  }

  Future<List<Category>> getCategories() async {
    final data = await _apiClient.get('/categories');
    return _list(data).map(Category.fromJson).toList();
  }

  List<Map<String, dynamic>> _buildItems(Map<String, int> quantities) {
    return quantities.entries
        .where((entry) => entry.value > 0)
        .map((entry) => {
              'plantId': entry.key,
              'quantity': entry.value,
            })
        .toList();
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
