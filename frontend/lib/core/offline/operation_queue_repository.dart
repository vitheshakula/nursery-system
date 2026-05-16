import '../network/api_client.dart';
import 'offline_database.dart';
import 'operation_queue.dart';

class OperationQueueRepository {
  const OperationQueueRepository(this._database);

  final OfflineDatabase _database;

  Future<QueuedOperation> enqueue({
    required QueuedOperationType type,
    required String endpoint,
    required String method,
    required Map<String, dynamic> payload,
  }) async {
    final now = DateTime.now();
    final operation = QueuedOperation(
      id: payload['requestId'] as String? ?? createOperationId(),
      type: type,
      endpoint: endpoint,
      method: method,
      payload: payload,
      status: QueuedOperationStatus.pending,
      createdAt: now,
      updatedAt: now,
    );

    await _database.enqueue(operation);
    return operation;
  }

  Future<List<QueuedOperation>> pending() {
    return _database.listPendingOperations();
  }

  Future<List<QueuedOperation>> all() {
    return _database.listQueuedOperations();
  }

  Future<void> markSyncing(QueuedOperation operation) {
    return _database.updateOperation(
      operation.copyWith(
        status: QueuedOperationStatus.syncing,
        clearError: true,
      ),
    );
  }

  Future<void> markCompleted(QueuedOperation operation) {
    return _database.updateOperation(
      operation.copyWith(
        status: QueuedOperationStatus.completed,
        clearError: true,
      ),
    );
  }

  Future<void> markFailed(QueuedOperation operation, Object error) {
    final nextAttempt = DateTime.now().add(
      Duration(seconds: _backoffSeconds(operation.attemptCount + 1)),
    );

    return _database.updateOperation(
      operation.copyWith(
        status: QueuedOperationStatus.pending,
        attemptCount: operation.attemptCount + 1,
        nextAttemptAt: nextAttempt,
        lastError: error.toString(),
      ),
    );
  }

  int _backoffSeconds(int attempt) {
    final boundedAttempt = attempt.clamp(1, 6);
    return 2 << (boundedAttempt - 1);
  }
}
