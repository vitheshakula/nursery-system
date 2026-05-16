import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/sessions/application/session_controller.dart';
import '../models/category.dart';
import '../models/item.dart';
import '../models/session_info.dart';
import '../models/vendor.dart';
import '../shared/theme/app_theme.dart';
import '../utils/formatters.dart';
import 'summary_screen.dart';

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

      _showMessage(mode == SessionMode.issue
          ? 'Issued items saved.'
          : 'Returned items saved.');
    } catch (error) {
      _showMessage(error.toString());
    }
  }

  Future<void> _viewSummary() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SummaryScreen(
          sessionId: widget.session.id,
        ),
      ),
    );
  }

  Future<void> _closeSession() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Close Session'),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_controller);
    final query = _searchController.text.trim().toLowerCase();
    final filteredItems = state.items.where((item) {
      final categoryMatch = state.selectedCategoryId == 'all' ||
          item.categoryId == state.selectedCategoryId;
      final searchMatch =
          query.isEmpty || item.name.toLowerCase().contains(query);
      return categoryMatch && searchMatch;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.vendor.name),
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.errorMessage != null
              ? Center(child: Text(state.errorMessage!))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: Column(
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.vendor.name,
                                    style:
                                        Theme.of(context).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 6),
                                  const _SessionStatusPill(
                                    label: 'In Progress',
                                  ),
                                  const SizedBox(height: 12),
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
                                        icon: Icon(
                                            Icons.assignment_return_outlined),
                                      ),
                                    ],
                                    selected: <SessionMode>{state.mode},
                                    onSelectionChanged: (selection) {
                                      ref
                                          .read(_controller.notifier)
                                          .setMode(selection.first);
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _searchController,
                                    onChanged: (_) => setState(() {}),
                                    decoration: const InputDecoration(
                                      prefixIcon: Icon(Icons.search),
                                      hintText: 'Search items',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    height: 42,
                                    child: ListView(
                                      scrollDirection: Axis.horizontal,
                                      children: [
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(right: 8),
                                          child: ChoiceChip(
                                            label: const Text('All'),
                                            selected:
                                                state.selectedCategoryId ==
                                                    'all',
                                            onSelected: (_) {
                                              ref
                                                  .read(_controller.notifier)
                                                  .setSelectedCategory('all');
                                            },
                                          ),
                                        ),
                                        ...state.categories.map(
                                          (category) => Padding(
                                            padding:
                                                const EdgeInsets.only(right: 8),
                                            child: ChoiceChip(
                                              label: Text(category.name),
                                              selected:
                                                  state.selectedCategoryId ==
                                                      category.id,
                                              onSelected: (_) {
                                                ref
                                                    .read(_controller.notifier)
                                                    .setSelectedCategory(
                                                        category.id);
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: filteredItems.isEmpty
                          ? const Center(child: Text('No items available.'))
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: filteredItems.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final item = filteredItems[index];
                                final quantity = state.quantities[item.id] ?? 0;
                                final selected = quantity > 0;
                                final categoryName = state.categories
                                    .firstWhere(
                                      (category) =>
                                          category.id == item.categoryId,
                                      orElse: () => const Category(
                                          id: '', name: 'Others'),
                                    )
                                    .name;

                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: selected
                                        ? const [
                                            BoxShadow(
                                              color: Color(0x143C8F41),
                                              blurRadius: 14,
                                              offset: Offset(0, 8),
                                            ),
                                          ]
                                        : const [],
                                  ),
                                  child: Card(
                                    color: selected
                                        ? const Color(0xFFF0F7E9)
                                        : Colors.white,
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 50,
                                            height: 50,
                                            decoration: BoxDecoration(
                                              color: selected
                                                  ? const Color(0xFFD7EBC5)
                                                  : const Color(0xFFEFF4EA),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            child: const Icon(
                                                Icons.inventory_2_outlined),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(item.name,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleMedium),
                                                const SizedBox(height: 4),
                                                Text(categoryName),
                                                const SizedBox(height: 4),
                                                Text(
                                                    'Vendor ${formatCurrency(item.vendorPrice)}'),
                                              ],
                                            ),
                                          ),
                                          _QuantityStepper(
                                            quantity: quantity,
                                            onIncrement: () =>
                                                _changeQuantity(item, 1),
                                            onDecrement: quantity == 0
                                                ? null
                                                : () =>
                                                    _changeQuantity(item, -1),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7F3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onDecrement,
            icon: const Icon(Icons.remove),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            style: IconButton.styleFrom(backgroundColor: Colors.white),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            onPressed: onIncrement,
            icon: const Icon(Icons.add),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionStatusPill extends StatelessWidget {
  const _SessionStatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
        ),
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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child:
                      _SummaryStat(label: 'Total qty', value: '$totalQuantity'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryStat(
                      label: 'Estimated bill',
                      value: formatCurrency(estimatedBill)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: isSubmitting ? null : onSubmit,
              child: Text(isSubmitting ? 'Saving...' : submitLabel),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onViewSummary,
                    child: const Text('View Summary'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: isClosing ? null : onCloseSession,
                    child: Text(isClosing ? 'Closing...' : 'Close Session'),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F6EE),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
