import '../../../core/network/api_exception.dart';
import '../../../core/offline/operation_queue.dart';
import '../../../core/offline/operation_queue_repository.dart';
import '../data/session_api.dart';

class SessionRepository {
  const SessionRepository({
    required SessionApi remote,
    required OperationQueueRepository queue,
  })  : _remote = remote,
        _queue = queue;

  final SessionApi _remote;
  final OperationQueueRepository _queue;

  Future<void> issueItems({
    required String sessionId,
    required Map<String, int> quantities,
  }) async {
    final payload = _remote.buildIssuePayload(quantities);
    try {
      await _remote.submitIssueItemsWithPayload(
        sessionId: sessionId,
        payload: payload,
      );
    } on ApiException catch (error) {
      if (error.type != ApiExceptionType.network) rethrow;
      await _queue.enqueue(
        type: QueuedOperationType.issueItems,
        endpoint: '/sessions/$sessionId/issue',
        method: 'POST',
        payload: payload,
      );
    }
  }

  Future<void> returnItems({
    required String sessionId,
    required Map<String, int> quantities,
  }) async {
    final payload = _remote.buildReturnPayload(quantities);
    try {
      await _remote.submitReturnItemsWithPayload(
        sessionId: sessionId,
        payload: payload,
      );
    } on ApiException catch (error) {
      if (error.type != ApiExceptionType.network) rethrow;
      await _queue.enqueue(
        type: QueuedOperationType.returnItems,
        endpoint: '/sessions/$sessionId/return',
        method: 'POST',
        payload: payload,
      );
    }
  }
}
