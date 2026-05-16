import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/offline/operation_queue.dart';
import '../core/sync/sync_controller.dart';
import '../shared/theme/app_theme.dart';

class SyncDiagnosticsScreen extends ConsumerWidget {
  const SyncDiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final operations = ref.watch(queuedOperationsProvider);
    final syncStatus = ref.watch(syncControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync diagnostics'),
        actions: [
          IconButton(
            tooltip: 'Retry sync',
            onPressed: syncStatus.isSyncing
                ? null
                : () => ref.read(syncControllerProvider.notifier).syncNow(),
            icon: const Icon(Icons.sync),
          ),
        ],
      ),
      body: operations.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No queued operations'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              return _OperationTile(operation: items[index]);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
      ),
    );
  }
}

class _OperationTile extends StatelessWidget {
  const _OperationTile({required this.operation});

  final QueuedOperation operation;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (operation.status) {
      QueuedOperationStatus.completed => AppColors.primary,
      QueuedOperationStatus.syncing => AppColors.warning,
      QueuedOperationStatus.failed => Theme.of(context).colorScheme.error,
      QueuedOperationStatus.pending => AppColors.muted,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    operation.type.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  operation.status.name.toUpperCase(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('${operation.method} ${operation.endpoint}'),
            const SizedBox(height: 6),
            Text('Attempts: ${operation.attemptCount}'),
            if (operation.nextAttemptAt != null)
              Text('Next retry: ${operation.nextAttemptAt}'),
            if (operation.lastError != null) ...[
              const SizedBox(height: 8),
              Text(
                operation.lastError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
