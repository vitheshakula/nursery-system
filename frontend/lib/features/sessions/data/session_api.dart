import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/offline/offline_cache_repository.dart';
import '../../../core/offline/operation_queue.dart';
import '../../../core/offline/operation_queue_repository.dart';
import '../../../models/active_session.dart';
import '../../../models/category.dart';
import '../../../models/item.dart';
import '../../../models/session_close_result.dart';
import '../../../models/session_info.dart';
import '../../../models/session_summary.dart';

class SessionApi {
  const SessionApi(this._apiClient, {this.queue, this.cache});

  final ApiClient _apiClient;
  final OperationQueueRepository? queue;
  final OfflineCacheRepository? cache;

  Future<List<ActiveSession>> getActiveSessions() async {
    const cacheKey = 'activeSessions';
    try {
    final data = await _apiClient.get('/sessions/active');
    final rows = _list(data);
    await cache?.cacheList(cacheKey, rows);
    return rows.map(ActiveSession.fromJson).toList();
    } on ApiException catch (error) {
      if (error.type != ApiExceptionType.network || cache == null) rethrow;
      return (await cache!.readList(cacheKey)).map(ActiveSession.fromJson).toList();
    }
  }

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
    await submitIssueItemsWithPayload(
      sessionId: sessionId,
      payload: buildIssuePayload(quantities),
    );
  }

  Future<void> submitIssueItemsWithPayload({
    required String sessionId,
    required Map<String, dynamic> payload,
  }) async {
    await _apiClient.post(
      '/sessions/$sessionId/issue',
      body: payload,
    );
  }

  Future<void> submitReturnItems({
    required String sessionId,
    required Map<String, int> quantities,
  }) async {
    await submitReturnItemsWithPayload(
      sessionId: sessionId,
      payload: buildReturnPayload(quantities),
    );
  }

  Future<void> submitReturnItemsWithPayload({
    required String sessionId,
    required Map<String, dynamic> payload,
  }) async {
    await _apiClient.post(
      '/sessions/$sessionId/return',
      body: payload,
    );
  }

  Future<SessionSummary> getSessionSummary(String sessionId) async {
    final data = await _apiClient.get('/sessions/$sessionId/summary');
    return SessionSummary.fromJson(_map(data));
  }

  Future<SessionCloseResult> closeSession(String sessionId) async {
    final requestId = createOperationId();
    final payload = {'requestId': requestId};
    
    try {
    final data = await _apiClient.post(
      '/sessions/$sessionId/close',
      body: payload,
    );
    return SessionCloseResult.fromJson(_map(data));
    } on ApiException catch (error) {
      if (error.type != ApiExceptionType.network || queue == null) {
        rethrow;
      }

      await queue!.enqueue(
        type: QueuedOperationType.closeSession,
        endpoint: '/sessions/$sessionId/close',
        method: 'POST',
        payload: payload,
      );

      return SessionCloseResult(
        sessionId: sessionId,
        status: 'QUEUED',
        totalBill: 0,
        totalSold: 0,
        vendorBalance: 0,
      );
    }
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

  List<Map<String, dynamic>> _buildItems(Map<String, int> quantities) {
    return quantities.entries
        .where((entry) => entry.value > 0)
        .map((entry) => {
              'plantId': entry.key,
              'quantity': entry.value,
            })
        .toList();
  }

  Map<String, dynamic> buildIssuePayload(Map<String, int> quantities) {
    return {
      'requestId': createOperationId(),
      'items': _buildItems(quantities),
    };
  }

  Map<String, dynamic> buildReturnPayload(Map<String, int> quantities) {
    return {
      'requestId': createOperationId(),
      'items': _buildItems(quantities)
          .map((item) => {
                ...item,
                'condition': 'GOOD',
              })
          .toList(),
    };
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
