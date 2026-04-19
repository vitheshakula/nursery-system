import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/item.dart';
import '../models/session_info.dart';
import '../models/vendor.dart';
import '../services/api_service.dart';
import '../utils/formatters.dart';
import 'settlement_screen.dart';
import 'summary_screen.dart';

enum SessionMode {
  issue,
  returnItems,
}

class SessionScreen extends StatefulWidget {
  const SessionScreen({
    super.key,
    required this.apiService,
    required this.vendor,
    required this.session,
  });

  final ApiService apiService;
  final Vendor vendor;
  final SessionInfo session;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Map<String, int> _quantities = <String, int>{};
  List<Item> _items = const <Item>[];
  List<Category> _categories = const <Category>[];
  String _selectedCategoryId = 'all';
  SessionMode _mode = SessionMode.issue;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isClosing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        widget.apiService.getItems(),
        widget.apiService.getCategories(),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _items = results[0] as List<Item>;
        _categories = results[1] as List<Category>;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _changeQuantity(Item item, int delta) {
    final current = _quantities[item.id] ?? 0;
    final next = current + delta;
    setState(() {
      if (next <= 0) {
        _quantities.remove(item.id);
      } else {
        _quantities[item.id] = next;
      }
    });
  }

  int get _totalQuantity => _quantities.values.fold<int>(0, (sum, quantity) => sum + quantity);

  double get _estimatedBill {
    return _items.fold<double>(0, (sum, item) {
      return sum + ((_quantities[item.id] ?? 0) * item.vendorPrice);
    });
  }

  Future<void> _submit() async {
    final selected = Map<String, int>.fromEntries(
      _quantities.entries.where((entry) => entry.value > 0),
    );

    if (selected.isEmpty) {
      _showMessage('Select items first.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      if (_mode == SessionMode.issue) {
        await widget.apiService.submitIssueItems(
          sessionId: widget.session.id,
          quantities: selected,
        );
      } else {
        await widget.apiService.submitReturnItems(
          sessionId: widget.session.id,
          quantities: selected,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _quantities.clear();
      });
      _showMessage(_mode == SessionMode.issue ? 'Issued items saved.' : 'Returned items saved.');
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _viewSummary() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SummaryScreen(
          apiService: widget.apiService,
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
            content: const Text('Move to settlement for this vendor?'),
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

    setState(() {
      _isClosing = true;
    });

    try {
      final closeResult = await widget.apiService.closeSession(widget.session.id);
      if (!mounted) {
        return;
      }

      final settled = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => SettlementScreen(
            apiService: widget.apiService,
            vendor: widget.vendor,
            sessionId: widget.session.id,
            totalBill: closeResult.totalBill,
            previousBalance: widget.vendor.balance,
            newBalance: closeResult.vendorBalance,
          ),
        ),
      );

      if (!mounted) {
        return;
      }

      if (settled == true) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isClosing = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filteredItems = _items.where((item) {
      final categoryMatch = _selectedCategoryId == 'all' || item.categoryId == _selectedCategoryId;
      final searchMatch = query.isEmpty || item.name.toLowerCase().contains(query);
      return categoryMatch && searchMatch;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.vendor.name),
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
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
                                    'Session active for ${widget.vendor.name}',
                                    style: Theme.of(context).textTheme.titleLarge,
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
                                        icon: Icon(Icons.assignment_return_outlined),
                                      ),
                                    ],
                                    selected: <SessionMode>{_mode},
                                    onSelectionChanged: (selection) {
                                      setState(() {
                                        _mode = selection.first;
                                      });
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
                                          padding: const EdgeInsets.only(right: 8),
                                          child: ChoiceChip(
                                            label: const Text('All'),
                                            selected: _selectedCategoryId == 'all',
                                            onSelected: (_) {
                                              setState(() {
                                                _selectedCategoryId = 'all';
                                              });
                                            },
                                          ),
                                        ),
                                        ..._categories.map(
                                          (category) => Padding(
                                            padding: const EdgeInsets.only(right: 8),
                                            child: ChoiceChip(
                                              label: Text(category.name),
                                              selected: _selectedCategoryId == category.id,
                                              onSelected: (_) {
                                                setState(() {
                                                  _selectedCategoryId = category.id;
                                                });
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
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final item = filteredItems[index];
                                final quantity = _quantities[item.id] ?? 0;
                                final selected = quantity > 0;
                                final categoryName = _categories
                                    .firstWhere(
                                      (category) => category.id == item.categoryId,
                                      orElse: () => const Category(id: '', name: 'Others'),
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
                                    color: selected ? const Color(0xFFF0F7E9) : Colors.white,
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 50,
                                            height: 50,
                                            decoration: BoxDecoration(
                                              color: selected ? const Color(0xFFD7EBC5) : const Color(0xFFEFF4EA),
                                              borderRadius: BorderRadius.circular(14),
                                            ),
                                            child: const Icon(Icons.inventory_2_outlined),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(item.name, style: Theme.of(context).textTheme.titleMedium),
                                                const SizedBox(height: 4),
                                                Text(categoryName),
                                                const SizedBox(height: 4),
                                                Text('Vendor ${formatCurrency(item.vendorPrice)}'),
                                              ],
                                            ),
                                          ),
                                          _QuantityStepper(
                                            quantity: quantity,
                                            onIncrement: () => _changeQuantity(item, 1),
                                            onDecrement: quantity == 0 ? null : () => _changeQuantity(item, -1),
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
                      totalQuantity: _totalQuantity,
                      estimatedBill: _estimatedBill,
                      isSubmitting: _isSubmitting,
                      isClosing: _isClosing,
                      submitLabel: _mode == SessionMode.issue ? 'Submit Issue' : 'Submit Return',
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
                  child: _SummaryStat(label: 'Total qty', value: '$totalQuantity'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryStat(label: 'Estimated bill', value: formatCurrency(estimatedBill)),
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
