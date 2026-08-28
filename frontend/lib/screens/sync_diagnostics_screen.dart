import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/offline/operation_queue.dart';
import '../core/sync/sync_controller.dart';
import '../shared/theme/app_theme.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/empty_state_widget.dart';
import '../shared/widgets/operational_widgets.dart';

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
          final pending = items
              .where((item) => item.status == QueuedOperationStatus.pending)
              .length;
          final failed = items
              .where((item) => item.status == QueuedOperationStatus.failed)
              .length;
          final completed = items
              .where((item) => item.status == QueuedOperationStatus.completed)
              .length;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(queuedOperationsProvider);
              await ref.read(queuedOperationsProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screen),
              children: [
                OperationalBanner(
                  title: syncStatus.isSyncing
                      ? 'Sync in progress'
                      : failed > 0
                          ? 'Sync queue needs review'
                          : pending > 0
                              ? 'Queued work is waiting'
                              : 'Sync queue healthy',
                  message: syncStatus.isSyncing
                      ? 'Operations are being sent in the background.'
                      : failed > 0
                          ? '$failed operation${failed == 1 ? '' : 's'} failed and can be retried.'
                          : pending > 0
                              ? '$pending operation${pending == 1 ? '' : 's'} will sync when connectivity is available.'
                              : 'No pending work is blocking the team.',
                  icon: syncStatus.isSyncing
                      ? Icons.sync
                      : failed > 0
                          ? Icons.error_outline
                          : Icons.cloud_done_outlined,
                  tone: syncStatus.isSyncing
                      ? OperationalStatusTone.info
                      : failed > 0
                          ? OperationalStatusTone.danger
                          : pending > 0
                              ? OperationalStatusTone.warning
                              : OperationalStatusTone.success,
                  action: TextButton(
                    onPressed: syncStatus.isSyncing
                        ? null
                        : () =>
                            ref.read(syncControllerProvider.notifier).syncNow(),
                    child: Text(syncStatus.isSyncing ? 'Syncing' : 'Sync now'),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 560;
                    final metrics = [
                      OperationalMetric(
                        label: 'Pending',
                        value: '$pending',
                        icon: Icons.schedule_outlined,
                        tone: pending > 0
                            ? OperationalStatusTone.warning
                            : OperationalStatusTone.success,
                      ),
                      OperationalMetric(
                        label: 'Failed',
                        value: '$failed',
                        icon: Icons.error_outline,
                        tone: failed > 0
                            ? OperationalStatusTone.danger
                            : OperationalStatusTone.success,
                      ),
                      OperationalMetric(
                        label: 'Completed',
                        value: '$completed',
                        icon: Icons.check_circle_outline,
                        tone: OperationalStatusTone.success,
                      ),
                    ];

                    if (isWide) {
                      return Row(
                        children: [
                          for (final metric in metrics) ...[
                            Expanded(child: metric),
                            if (metric != metrics.last)
                              const SizedBox(width: AppSpacing.sm),
                          ],
                        ],
                      );
                    }

                    return Column(
                      children: [
                        for (final metric in metrics) ...[
                          metric,
                          if (metric != metrics.last)
                            const SizedBox(height: AppSpacing.sm),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                if (items.isEmpty)
                  const EmptyStateWidget(
                    title: 'No queued operations',
                    message: 'Offline work will appear here until it syncs.',
                    icon: Icons.cloud_done_outlined,
                  )
                else
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        return _OperationTile(operation: items[index]);
                      },
                    ),
                  ),
              ],
            ),
          );
        },
        loading: () => const LoadingState(label: 'Loading sync queue'),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: OperationalBanner(
            title: 'Unable to load sync queue',
            message: error.toString(),
            icon: Icons.error_outline,
            tone: OperationalStatusTone.danger,
          ),
        ),
      ),
    );
  }
}

class _OperationTile extends StatelessWidget {
  const _OperationTile({required this.operation});

  final QueuedOperation operation;

  @override
  Widget build(BuildContext context) {
    final tone = switch (operation.status) {
      QueuedOperationStatus.completed => OperationalStatusTone.success,
      QueuedOperationStatus.syncing => OperationalStatusTone.info,
      QueuedOperationStatus.failed => OperationalStatusTone.danger,
      QueuedOperationStatus.pending => OperationalStatusTone.warning,
    };

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _operationLabel(operation.type),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusChip(
                label: operation.status.name.toUpperCase(),
                tone: tone,
                icon: operation.status == QueuedOperationStatus.failed
                    ? Icons.error_outline
                    : null,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${operation.method} ${operation.endpoint}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.monoMetric.copyWith(
              color: AppColors.muted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              Text(
                'Attempts ${operation.attemptCount}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                'Updated ${operation.updatedAt.toLocal()}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          if (operation.nextAttemptAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Next retry ${operation.nextAttemptAt!.toLocal()}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (operation.lastError != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              operation.lastError!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  String _operationLabel(QueuedOperationType type) {
    return switch (type) {
      QueuedOperationType.issueItems => 'Issue items',
      QueuedOperationType.returnItems => 'Return items',
      QueuedOperationType.createPayment => 'Create payment',
      QueuedOperationType.closeSession => 'Close session',
      QueuedOperationType.adjustStock => 'Adjust stock',
    };
  }
}
