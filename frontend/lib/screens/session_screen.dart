import 'package:flutter/material.dart';

import '../models/session_info.dart';
import '../models/vendor.dart';
import '../services/api_service.dart';

class SessionScreen extends StatefulWidget {
  const SessionScreen({
    super.key,
    required this.apiService,
    required this.vendor,
    required this.initialSession,
    required this.onViewSummary,
    required this.onBack,
  });

  final ApiService apiService;
  final Vendor vendor;
  final SessionInfo? initialSession;
  final ValueChanged<String> onViewSummary;
  final VoidCallback onBack;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  final _issuePlantIdController = TextEditingController();
  final _issueQuantityController = TextEditingController();
  final _returnPlantIdController = TextEditingController();
  final _returnQuantityController = TextEditingController();

  SessionInfo? _session;
  bool _isStartingSession = false;
  bool _isSubmittingIssue = false;
  bool _isSubmittingReturn = false;
  String? _message;
  String? _error;
  String _returnCondition = 'GOOD';

  @override
  void initState() {
    super.initState();
    _session = widget.initialSession;
  }

  @override
  void dispose() {
    _issuePlantIdController.dispose();
    _issueQuantityController.dispose();
    _returnPlantIdController.dispose();
    _returnQuantityController.dispose();
    super.dispose();
  }

  Future<void> _startSession() async {
    setState(() {
      _isStartingSession = true;
      _message = null;
      _error = null;
    });

    try {
      final session = await widget.apiService.startSession(widget.vendor.id);
      setState(() {
        _session = session;
        _message = 'Session ready: ${session.id}';
      });
    } catch (error) {
      setState(() {
        _error = error is ApiException ? error.message : 'Unable to start session';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isStartingSession = false;
        });
      }
    }
  }

  Future<void> _issueItems() async {
    final sessionId = _session?.id;
    final quantity = int.tryParse(_issueQuantityController.text.trim());

    if (sessionId == null ||
        _issuePlantIdController.text.trim().isEmpty ||
        quantity == null ||
        quantity <= 0) {
      setState(() {
        _error = 'Start a session and enter a valid plant id and quantity';
      });
      return;
    }

    setState(() {
      _isSubmittingIssue = true;
      _message = null;
      _error = null;
    });

    try {
      final result = await widget.apiService.issueItems(
        sessionId: sessionId,
        plantId: _issuePlantIdController.text.trim(),
        quantity: quantity,
      );
      setState(() {
        _message = 'Issued ${result.totalQuantity} items';
        _issuePlantIdController.clear();
        _issueQuantityController.clear();
      });
    } catch (error) {
      setState(() {
        _error = error is ApiException ? error.message : 'Unable to issue items';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingIssue = false;
        });
      }
    }
  }

  Future<void> _returnItems() async {
    final sessionId = _session?.id;
    final quantity = int.tryParse(_returnQuantityController.text.trim());

    if (sessionId == null ||
        _returnPlantIdController.text.trim().isEmpty ||
        quantity == null ||
        quantity <= 0) {
      setState(() {
        _error = 'Start a session and enter a valid return item';
      });
      return;
    }

    setState(() {
      _isSubmittingReturn = true;
      _message = null;
      _error = null;
    });

    try {
      final result = await widget.apiService.returnItems(
        sessionId: sessionId,
        plantId: _returnPlantIdController.text.trim(),
        quantity: quantity,
        condition: _returnCondition,
      );
      setState(() {
        _message = 'Returned ${result.totalQuantity} items';
        _returnPlantIdController.clear();
        _returnQuantityController.clear();
      });
    } catch (error) {
      setState(() {
        _error = error is ApiException ? error.message : 'Unable to return items';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingReturn = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionId = _session?.id;

    return Scaffold(
      appBar: AppBar(
        title: Text('Session: ${widget.vendor.name}'),
        leading: IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.vendor.name, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text('Balance: ${widget.vendor.balance.toStringAsFixed(2)}'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _session != null || _isStartingSession ? null : _startSession,
                      child: Text(
                        _session != null
                            ? 'Session Started'
                            : _isStartingSession
                                ? 'Starting...'
                                : 'Start Session',
                      ),
                    ),
                    if (sessionId != null) ...[
                      const SizedBox(height: 8),
                      Text('Active session id: $sessionId'),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _ActionCard(
              title: 'Issue items',
              loading: _isSubmittingIssue,
              plantIdController: _issuePlantIdController,
              quantityController: _issueQuantityController,
              buttonLabel: 'Issue',
              onSubmit: _issueItems,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Return items', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _returnPlantIdController,
                      decoration: const InputDecoration(
                        labelText: 'Plant ID',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _returnQuantityController,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _returnCondition,
                      decoration: const InputDecoration(
                        labelText: 'Condition',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'GOOD', child: Text('GOOD')),
                        DropdownMenuItem(value: 'DAMAGED', child: Text('DAMAGED')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _returnCondition = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _isSubmittingReturn ? null : _returnItems,
                      child: Text(_isSubmittingReturn ? 'Submitting...' : 'Return'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_message != null)
              Text(_message!, style: const TextStyle(color: Colors.green)),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: sessionId == null ? null : () => widget.onViewSummary(sessionId),
              child: const Text('Open summary'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.loading,
    required this.plantIdController,
    required this.quantityController,
    required this.buttonLabel,
    required this.onSubmit,
  });

  final String title;
  final bool loading;
  final TextEditingController plantIdController;
  final TextEditingController quantityController;
  final String buttonLabel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: plantIdController,
              decoration: const InputDecoration(
                labelText: 'Plant ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: quantityController,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: loading ? null : onSubmit,
              child: Text(loading ? 'Submitting...' : buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}
