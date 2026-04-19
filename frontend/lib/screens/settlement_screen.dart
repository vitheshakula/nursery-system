import 'package:flutter/material.dart';

import '../models/vendor.dart';
import '../services/api_service.dart';
import '../utils/formatters.dart';

class SettlementScreen extends StatefulWidget {
  const SettlementScreen({
    super.key,
    required this.apiService,
    required this.vendor,
    required this.sessionId,
    required this.totalBill,
    required this.previousBalance,
    required this.newBalance,
  });

  final ApiService apiService;
  final Vendor vendor;
  final String sessionId;
  final double totalBill;
  final double previousBalance;
  final double newBalance;

  @override
  State<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends State<SettlementScreen> {
  final TextEditingController _cashController = TextEditingController();
  final TextEditingController _onlineController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _cashController.dispose();
    _onlineController.dispose();
    super.dispose();
  }

  double get _cashPaid => double.tryParse(_cashController.text.trim()) ?? 0;
  double get _onlinePaid => double.tryParse(_onlineController.text.trim()) ?? 0;
  double get _totalPaid => _cashPaid + _onlinePaid;
  double get _remainingCredit => (widget.totalBill - _totalPaid).clamp(0, double.infinity);
  double get _updatedOutstanding => (widget.newBalance - _totalPaid).clamp(0, double.infinity);

  Future<void> _submitSettlement() async {
    if (_cashPaid < 0 || _onlinePaid < 0) {
      _showMessage('Enter valid payment amounts.');
      return;
    }

    if (_totalPaid <= 0) {
      _showMessage('Enter cash or online amount.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (_cashPaid > 0) {
        await widget.apiService.createPayment(
          vendorId: widget.vendor.id,
          amount: _cashPaid,
          mode: 'CASH',
          sessionId: widget.sessionId,
        );
      }

      if (_onlinePaid > 0) {
        await widget.apiService.createPayment(
          vendorId: widget.vendor.id,
          amount: _onlinePaid,
          mode: 'UPI',
          sessionId: widget.sessionId,
        );
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settlement saved successfully.')),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settlement'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.vendor.name, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  _SettlementRow(label: 'Total bill', value: formatCurrency(widget.totalBill)),
                  _SettlementRow(label: 'Previous balance', value: formatCurrency(widget.previousBalance)),
                  _SettlementRow(label: 'New balance', value: formatCurrency(widget.newBalance)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _cashController,
            onChanged: (_) => setState(() {}),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Cash paid',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _onlineController,
            onChanged: (_) => setState(() {}),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Online paid',
              prefixIcon: Icon(Icons.qr_code_scanner_outlined),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: const Color(0xFFF2F6EE),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SettlementRow(label: 'Total received', value: formatCurrency(_totalPaid)),
                  _SettlementRow(label: 'Remaining credit', value: formatCurrency(_remainingCredit)),
                  _SettlementRow(label: 'Outstanding balance after payment', value: formatCurrency(_updatedOutstanding)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _isSaving ? null : _submitSettlement,
            child: Text(_isSaving ? 'Saving...' : 'Finish Settlement'),
          ),
        ],
      ),
    );
  }
}

class _SettlementRow extends StatelessWidget {
  const _SettlementRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
