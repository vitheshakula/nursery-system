import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../network/api_client.dart';
import '../offline/offline_database.dart';
import '../offline/offline_cache_repository.dart';
import '../offline/operation_queue.dart';
import '../offline/operation_queue_repository.dart';
import '../../features/auth/presentation/auth_provider.dart';

final offlineDatabaseProvider = Provider<OfflineDatabase>((ref) {
  return OfflineDatabase.instance;
});

final operationQueueProvider = Provider<OperationQueueRepository>((ref) {
  return OperationQueueRepository(ref.watch(offlineDatabaseProvider));
});

final offlineCacheProvider = Provider<OfflineCacheRepository>((ref) {
  return OfflineCacheRepository(ref.watch(offlineDatabaseProvider));
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  return SyncEngine(
    apiClient: ref.watch(apiClientProvider),
    queue: ref.watch(operationQueueProvider),
  );
});

class SyncStatus {
  const SyncStatus({
    this.isSyncing = false,
    this.completedCount = 0,
    this.failedCount = 0,
    this.lastError,
  });

  final bool isSyncing;
  final int completedCount;
  final int failedCount;
  final String? lastError;
}

class SyncEngine {
  const SyncEngine({
    required ApiClient apiClient,
    required OperationQueueRepository queue,
  })  : _apiClient = apiClient,
        _queue = queue;

  final ApiClient _apiClient;
  final OperationQueueRepository _queue;

  Future<SyncStatus> syncPending() async {
    final operations = await _queue.pending();
    var completed = 0;
    var failed = 0;
    String? lastError;

    for (final operation in operations) {
      try {
        await _queue.markSyncing(operation);
        await _send(operation);
        await _queue.markCompleted(operation);
        completed += 1;
      } catch (error) {
        debugPrint('Sync failed for ${operation.id}: $error');
        await _queue.markFailed(operation, error);
        failed += 1;
        lastError = error.toString();
      }
    }

    return SyncStatus(
      completedCount: completed,
      failedCount: failed,
      lastError: lastError,
    );
  }

  Future<void> _send(QueuedOperation operation) async {
    switch (operation.method.toUpperCase()) {
      case 'POST':
        await _apiClient.post(operation.endpoint, body: operation.payload);
        return;
      case 'PATCH':
        await _apiClient.patch(operation.endpoint, body: operation.payload);
        return;
      default:
        throw StateError('Unsupported queued method: ${operation.method}');
    }
  }
}
