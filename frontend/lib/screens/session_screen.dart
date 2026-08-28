import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/offline/operation_queue.dart';
import '../core/sync/sync_controller.dart';
import '../features/sessions/application/session_controller.dart';
import '../models/category.dart';
import '../models/item.dart';
import '../models/session_info.dart';
import '../models/vendor.dart';
import '../shared/theme/app_theme.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/empty_state_widget.dart';
import '../shared/widgets/operational_widgets.dart';
import '../utils/formatters.dart';
import 'summary_screen.dart';
import 'sync_diagnostics_screen.dart';

class SessionScreen extends ConsumerStatefulWidget {
  const SessionScreen({
    super.key,
    required this.vendor,
    required this.session,
  });

  final Vendor vendor;
  final SessionInfo session;

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  final TextEditingController _searchController = TextEditingController();
  late final AutoDisposeStateNotifierProvider<SessionController, SessionState>
      _controller;

  @override
  void initState() {
    super.initState();
    _controller = sessionControllerProvider(widget.session);
    Future.microtask(_loadData);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await ref.read(_controller.notifier).loadData();
  }

  void _changeQuantity(Item item, int delta) {
    ref.read(_controller.notifier).changeQuantity(item, delta);
  }

  Future<void> _submit() async {
    final controller = ref.read(_controller.notifier);
    final mode = ref.read(_controller).mode;

    if (ref
        .read(_controller)
        .quantities
        .values
        .every((quantity) => quantity <= 0)) {
      _showMessage('Select items first.');
      return;
    }

    try {
      if (mode == SessionMode.issue) {
        await controller.issueItems();
      } else {
        await controller.returnItems();
      }

      if (!mounted) {
        return;
      }

      _showMessage(
        mode == SessionMode.issue
            ? 'Issued items saved.'
            : 'Returned items saved.',
      );
    } catch (error) {
      _showMessage(error.toString());
    }
  }

  Future<void> _viewSummary() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SummaryScreen(sessionId: widget.session.id),
      ),
    );
  }

  Future<void> _closeSession() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Close session'),
            content: const Text(
              'This will add the session balance to the vendor pending balance.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Continue'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    try {
      final closeResult = await ref.read(_controller.notifier).closeSession();
      if (!mounted) {
        return;
      }

      ref.invalidate(activeSessionsProvider);
      ref.invalidate(sessionDetailProvider(widget.session.id));

      _showMessage(
        'Session closed. ${formatCurrency(closeResult.totalBill)} added to pending.',
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      _showMessage(error.toString());
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_controller);
    final queue = ref.watch(queuedOperationsProvider);
    final syncStatus = ref.watch(syncControllerProvider);
    final query = _searchController.text.trim().toLowerCase();
    final filteredItems = state.items.where((item) {
      final categoryMatch = state.selectedCategoryId == 'all' ||
          item.categoryId == state.selectedCategoryId;
      final searchMatch =
          query.isEmpty || item.name.toLowerCase().contains(query);
      return categoryMatch && searchMatch;
    }).toList();
    final categoriesById = {
      for (final category in state.categories) category.id: category,
    };
    final pendingCount = queue.maybeWhen(
      data: (items) => items
          .where(
            (operation) =>
                operation.status == QueuedOperationStatus.pending ||
                operation.status == QueuedOperationStatus.failed,
          )
          .length,
      orElse: () => 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session workspace'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Sync diagnostics',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SyncDiagnosticsScreen(),
                ),
              );
            },
            icon: const Icon(Icons.manage_search),
          ),
        ],
      ),
      body: state.isLoading
          ? const LoadingState(label: 'Loading session workspace')
          : state.errorMessage != null
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.screen),
                  child: OperationalBanner(
                    title: 'Session data unavailable',
                    message: state.errorMessage!,
                    icon: Icons.error_outline,
                    tone: OperationalStatusTone.danger,
                    action: TextButton(
                      onPressed: _loadData,
                      child: const Text('Retry'),
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.screen,
                            AppSpacing.sm,
                            AppSpacing.screen,
                            AppSpacing.xl,
                          ),
                          children: [
                            _ControlCenterHeader(
                              vendorName: widget.vendor.name,
                              mode: state.mode,
                              totalQuantity: state.totalQuantity,
                              estimatedBill: state.estimatedBill,
                              pendingQueueCount: pendingCount,
                              isSyncing: syncStatus.isSyncing,
                              lastSyncFailed: syncStatus.failedCount > 0,
                              onSyncNow: syncStatus.isSyncing
                                  ? null
                                  : () => ref
                                      .read(syncControllerProvider.notifier)
                                      .syncNow(),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _WorkspaceControls(
                              controller: _searchController,
                              mode: state.mode,
                              categories: state.categories,
                              selectedCategoryId: state.selectedCategoryId,
                              onModeChanged: (mode) {
                                ref.read(_controller.notifier).setMode(mode);
                              },
                              onCategoryChanged: (categoryId) {
                                ref
                                    .read(_controller.notifier)
                                    .setSelectedCategory(categoryId);
                              },
                              onSearchChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _ItemsList(
                              items: filteredItems,
                              categoriesById: categoriesById,
                              quantities: state.quantities,
                              onIncrement: (item) => _changeQuantity(item, 1),
                              onDecrement: (item) => _changeQuantity(item, -1),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _SummaryBar(
                      totalQuantity: state.totalQuantity,
                      estimatedBill: state.estimatedBill,
                      isSubmitting: state.isSubmitting,
                      isClosing: state.isClosing,
                      submitLabel: state.mode == SessionMode.issue
                          ? 'Submit Issue'
                          : 'Submit Return',
                      onSubmit: _submit,
                      onViewSummary: _viewSummary,
                      onCloseSession: _closeSession,
                    ),
                  ],
                ),
    );
  }
}

class _ControlCenterHeader extends StatelessWidget {
  const _ControlCenterHeader({
    required this.vendorName,
    required this.mode,
    required this.totalQuantity,
    required this.estimatedBill,
    required this.pendingQueueCount,
    required this.isSyncing,
    required this.lastSyncFailed,
    required this.onSyncNow,
  });

  final String vendorName;
  final SessionMode mode;
  final int totalQuantity;
  final double estimatedBill;
  final int pendingQueueCount;
  final bool isSyncing;
  final bool lastSyncFailed;
  final VoidCallback? onSyncNow;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.surfaceLow,
      borderColor: AppColors.lineStrong,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LIVE OPERATION',
                      style: AppTypography.labelCaps,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      vendorName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusChip(
                label: mode == SessionMode.issue ? 'Issuing' : 'Returns',
                tone: OperationalStatusTone.success,
                icon: mode == SessionMode.issue
                    ? Icons.outbox_outlined
                    : Icons.assignment_return_outlined,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 560;
              final cards = [
                OperationalMetric(
                  label: 'Selected qty',
                  value: '$totalQuantity',
                  icon: Icons.inventory_2_outlined,
                  tone: totalQuantity > 0
                      ? OperationalStatusTone.success
                      : OperationalStatusTone.neutral,
                ),
                OperationalMetric(
                  label: 'Est. bill',
                  value: formatCurrency(estimatedBill),
                  icon: Icons.receipt_long_outlined,
                  tone: OperationalStatusTone.info,
                ),
                OperationalMetric(
                  label: 'Queue',
                  value: '$pendingQueueCount',
                  caption: pendingQueueCount == 0
                      ? 'No pending work'
                      : 'Waiting for sync',
                  icon: Icons.cloud_queue_outlined,
                  tone: pendingQueueCount == 0
                      ? OperationalStatusTone.success
                      : OperationalStatusTone.warning,
                ),
              ];

              if (isWide) {
                return Row(
                  children: [
                    for (final card in cards) ...[
                      Expanded(child: card),
                      if (card != cards.last)
                        const SizedBox(width: AppSpacing.sm),
                    ],
                  ],
                );
              }

              return Column(
                children: [
                  for (final card in cards) ...[
                    card,
                    if (card != cards.last)
                      const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          OperationalBanner(
            title: lastSyncFailed
                ? 'Sync needs attention'
                : isSyncing
                    ? 'Sync in progress'
                    : 'Offline-first session',
            message: lastSyncFailed
                ? 'Some queued work failed. Review diagnostics before closing shift.'
                : isSyncing
                    ? 'Queued session changes are being sent to the server.'
                    : 'Work is saved locally first and synced when connectivity is healthy.',
            icon: lastSyncFailed
                ? Icons.error_outline
                : isSyncing
                    ? Icons.sync
                    : Icons.verified_user_outlined,
            tone: lastSyncFailed
                ? OperationalStatusTone.danger
                : isSyncing
                    ? OperationalStatusTone.info
                    : OperationalStatusTone.success,
            action: TextButton(
              onPressed: onSyncNow,
              child: Text(isSyncing ? 'Syncing' : 'Sync'),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceControls extends StatelessWidget {
  const _WorkspaceControls({
    required this.controller,
    required this.mode,
    required this.categories,
    required this.selectedCategoryId,
    required this.onModeChanged,
    required this.onCategoryChanged,
    required this.onSearchChanged,
  });

  final TextEditingController controller;
  final SessionMode mode;
  final List<Category> categories;
  final String selectedCategoryId;
  final ValueChanged<SessionMode> onModeChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<SessionMode>(
            segments: const [
              ButtonSegment(
                value: SessionMode.issue,
                label: Text('Issue'),
                icon: Icon(Icons.outbox_outlined),
              ),
              ButtonSegment(
                value: SessionMode.returnItems,
                label: Text('Return'),
                icon: Icon(Icons.assignment_return_outlined),
              ),
            ],
            selected: <SessionMode>{mode},
            onSelectionChanged: (selection) => onModeChanged(selection.first),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: controller,
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search items',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: ChoiceChip(
                    label: const Text('All'),
                    selected: selectedCategoryId == 'all',
                    onSelected: (_) => onCategoryChanged('all'),
                  ),
                ),
                ...categories.map(
                  (category) => Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: ChoiceChip(
                      label: Text(category.name),
                      selected: selectedCategoryId == category.id,
                      onSelected: (_) => onCategoryChanged(category.id),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemsList extends StatelessWidget {
  const _ItemsList({
    required this.items,
    required this.categoriesById,
    required this.quantities,
    required this.onIncrement,
    required this.onDecrement,
  });

  final List<Item> items;
  final Map<String, Category> categoriesById;
  final Map<String, int> quantities;
  final ValueChanged<Item> onIncrement;
  final ValueChanged<Item> onDecrement;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const EmptyStateWidget(
        title: 'No matching items',
        message:
            'Adjust the search or category filter to continue this session.',
        icon: Icons.inventory_2_outlined,
      );
    }

    return AppCard(
      padding: EdgeInsets.zero,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = items[index];
          final quantity = quantities[item.id] ?? 0;
          final categoryName =
              categoriesById[item.categoryId]?.name ?? 'Others';
          final isLowStock = item.currentStock <= 10;

          return _ItemRow(
            item: item,
            categoryName: categoryName,
            quantity: quantity,
            isLowStock: isLowStock,
            onIncrement: () => onIncrement(item),
            onDecrement: quantity == 0 ? null : () => onDecrement(item),
          );
        },
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.categoryName,
    required this.quantity,
    required this.isLowStock,
    required this.onIncrement,
    required this.onDecrement,
  });

  final Item item;
  final String categoryName;
  final int quantity;
  final bool isLowStock;
  final VoidCallback onIncrement;
  final VoidCallback? onDecrement;

  @override
  Widget build(BuildContext context) {
    final selected = quantity > 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      color: selected
          ? AppColors.primarySoft.withValues(alpha: 0.45)
          : Colors.transparent,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.line,
              ),
            ),
            child: Icon(
              selected
                  ? Icons.check_circle_outline
                  : Icons.inventory_2_outlined,
              color: selected ? AppColors.primary : AppColors.subtle,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    if (isLowStock) ...[
                      const SizedBox(width: AppSpacing.xs),
                      const StatusChip(
                        label: 'Low stock',
                        tone: OperationalStatusTone.warning,
                        icon: Icons.warning_amber_outlined,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: 4,
                  children: [
                    Text(categoryName,
                        style: Theme.of(context).textTheme.bodySmall),
                    Text('Stock ${item.currentStock}',
                        style: AppTypography.monoMetric),
                    Text(
                      formatCurrency(item.vendorPrice),
                      style: AppTypography.monoMetric
                          .copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _QuantityStepper(
            quantity: quantity,
            onIncrement: onIncrement,
            onDecrement: onDecrement,
          ),
        ],
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
  });

  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback? onDecrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLowest,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove,
            onPressed: onDecrement,
            filled: false,
          ),
          SizedBox(
            width: 32,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: AppTypography.monoMetric,
            ),
          ),
          _StepButton(
            icon: Icons.add,
            onPressed: onIncrement,
            filled: true,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.onPressed,
    required this.filled,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        backgroundColor: filled ? AppColors.primaryDark : AppColors.surfaceHigh,
        foregroundColor: filled ? Colors.white : AppColors.muted,
        disabledForegroundColor: AppColors.subtle.withValues(alpha: 0.45),
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({
    required this.totalQuantity,
    required this.estimatedBill,
    required this.isSubmitting,
    required this.isClosing,
    required this.submitLabel,
    required this.onSubmit,
    required this.onViewSummary,
    required this.onCloseSession,
  });

  final int totalQuantity;
  final double estimatedBill;
  final bool isSubmitting;
  final bool isClosing;
  final String submitLabel;
  final VoidCallback onSubmit;
  final VoidCallback onViewSummary;
  final VoidCallback onCloseSession;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.surfaceLow,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child:
                      _SummaryStat(label: 'Total qty', value: '$totalQuantity'),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _SummaryStat(
                    label: 'Estimated bill',
                    value: formatCurrency(estimatedBill),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              onPressed: isSubmitting ? null : onSubmit,
              icon: const Icon(Icons.save_outlined),
              label: Text(isSubmitting ? 'Saving...' : submitLabel),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onViewSummary,
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Summary'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isClosing ? null : onCloseSession,
                    icon: const Icon(Icons.lock_outline),
                    label: Text(isClosing ? 'Closing...' : 'Close'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppTypography.labelCaps),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.monoMetric.copyWith(fontSize: 15),
          ),
        ],
      ),
    );
  }
}
