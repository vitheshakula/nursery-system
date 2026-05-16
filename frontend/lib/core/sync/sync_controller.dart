import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../offline/operation_queue.dart';
import 'sync_engine.dart';

final queuedOperationsProvider = FutureProvider<List<QueuedOperation>>((ref) {
  return ref.watch(operationQueueProvider).all();
});

final syncControllerProvider =
    StateNotifierProvider<SyncController, SyncStatus>((ref) {
  return SyncController(
    syncEngine: ref.watch(syncEngineProvider),
    ref: ref,
  );
});

class SyncController extends StateNotifier<SyncStatus> {
  SyncController({
    required SyncEngine syncEngine,
    required Ref ref,
  })  : _syncEngine = syncEngine,
        _ref = ref,
        super(const SyncStatus());

  final SyncEngine _syncEngine;
  final Ref _ref;

  Future<void> syncNow() async {
    state = const SyncStatus(isSyncing: true);
    final result = await _syncEngine.syncPending();
    state = result;
    _ref.invalidate(queuedOperationsProvider);
  }
}
