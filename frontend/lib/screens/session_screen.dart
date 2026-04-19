import 'package:flutter/material.dart';

import '../models/plant.dart';
import '../models/session_info.dart';
import '../models/vendor.dart';
import '../services/api_service.dart';
import '../utils/formatters.dart';
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
  late Future<List<Plant>> _plantsFuture;
  final Map<String, int> _quantities = <String, int>{};
  SessionMode _mode = SessionMode.issue;
  bool _isSubmitting = false;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _plantsFuture = widget.apiService.getPlants();
  }

  int get _totalQuantity =>
      _quantities.values.fold<int>(0, (sum, quantity) => sum + quantity);

  void _reloadPlants() {
    setState(() {
      _plantsFuture = widget.apiService.getPlants();
    });
  }

  void _updateQuantity(Plant plant, int change) {
    final current = _quantities[plant.id] ?? 0;
    final next = current + change;

    setState(() {
      if (next <= 0) {
        _quantities.remove(plant.id);
      } else {
        _quantities[plant.id] = next;
      }
    });
  }

  double _estimatedBill(List<Plant> plants) {
    return plants.fold<double>(0, (sum, plant) {
      final quantity = _quantities[plant.id] ?? 0;
      return sum + (quantity * plant.vendorPrice);
    });
  }

  Future<void> _submitSelection() async {
    final selectedItems = Map<String, int>.fromEntries(
      _quantities.entries.where((entry) => entry.value > 0),
    );

    if (selectedItems.isEmpty) {
      _showMessage('Select at least one plant first.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      if (_mode == SessionMode.issue) {
        await widget.apiService.submitIssueItems(
          sessionId: widget.session.id,
          quantities: selectedItems,
        );
      } else {
        await widget.apiService.submitReturnItems(
          sessionId: widget.session.id,
          quantities: selectedItems,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _quantities.clear();
      });
      _showMessage(
        _mode == SessionMode.issue
            ? 'Issue saved successfully.'
            : 'Return saved successfully.',
      );
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

  Future<void> _openSummary() async {
    await Navigator.of(context).push<void>(
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
          builder: (context) => AlertDialog(
            title: const Text('Close Session'),
            content: const Text('Close this session and move to the final summary?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Close'),
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
      final result = await widget.apiService.closeSession(widget.session.id);
      if (!mounted) {
        return;
      }

      _showMessage(
        'Session closed. Bill: ${formatCurrency(result.totalBill)}',
      );

      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => SummaryScreen(
            apiService: widget.apiService,
            sessionId: widget.session.id,
            closeResult: result,
          ),
        ),
      );

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.vendor.name),
      ),
      body: FutureBuilder<List<Plant>>(
        future: _plantsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _SessionMessageState(
              message: snapshot.error.toString(),
              actionLabel: 'Retry',
              onAction: _reloadPlants,
            );
          }

          final plants = snapshot.data ?? const <Plant>[];
          if (plants.isEmpty) {
            return const _SessionMessageState(message: 'No plants available.');
          }

          final estimatedBill = _estimatedBill(plants);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Session is active for ${widget.vendor.name}.',
                          style: Theme.of(context).textTheme.titleMedium,
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
                        FilledButton(
                          onPressed: _isSubmitting ? null : _submitSelection,
                          child: Text(
                            _isSubmitting
                                ? 'Saving...'
                                : _mode == SessionMode.issue
                                    ? 'Submit Issue'
                                    : 'Submit Return',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: plants.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final plant = plants[index];
                    final quantity = _quantities[plant.id] ?? 0;

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const CircleAvatar(child: Icon(Icons.local_florist)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(plant.name, style: Theme.of(context).textTheme.titleMedium),
                                  const SizedBox(height: 4),
                                  Text('Price: ${formatCurrency(plant.vendorPrice)}'),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            _QuantityStepper(
                              quantity: quantity,
                              onAdd: () => _updateQuantity(plant, 1),
                              onRemove: quantity == 0 ? null : () => _updateQuantity(plant, -1),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              _LiveSummaryBar(
                totalQuantity: _totalQuantity,
                estimatedBill: estimatedBill,
                isClosing: _isClosing,
                onViewSummary: _openSummary,
                onCloseSession: _closeSession,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });

  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          onPressed: onRemove,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 28,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton.filled(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

class _LiveSummaryBar extends StatelessWidget {
  const _LiveSummaryBar({
    required this.totalQuantity,
    required this.estimatedBill,
    required this.isClosing,
    required this.onViewSummary,
    required this.onCloseSession,
  });

  final int totalQuantity;
  final double estimatedBill;
  final bool isClosing;
  final VoidCallback onViewSummary;
  final VoidCallback onCloseSession;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            color: Color(0x14000000),
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _SummaryMetric(
                    label: 'Total quantity',
                    value: '$totalQuantity',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryMetric(
                    label: 'Estimated bill',
                    value: formatCurrency(estimatedBill),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
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

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
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

class _SessionMessageState extends StatelessWidget {
  const _SessionMessageState({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
