import 'package:flutter/material.dart';

import '../models/payment.dart';
import '../models/vendor.dart';
import '../services/api_service.dart';
import '../utils/formatters.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    super.key,
    required this.apiService,
    required this.vendor,
  });

  final ApiService apiService;
  final Vendor vendor;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final TextEditingController _amountController = TextEditingController();
  bool _isSaving = false;
  String _mode = 'CASH';

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      _showMessage('Enter a valid payment amount.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final payment = await widget.apiService.createPayment(
        vendorId: widget.vendor.id,
        amount: amount,
        mode: _mode,
      );

      if (!mounted) {
        return;
      }

      _showMessage('Payment added successfully.');
      Navigator.of(context).pop(payment);
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Payment'),
      ),
      body: Padding(
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
                    Text('Current balance: ${formatCurrency(widget.vendor.balance)}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount',
                hintText: 'Enter payment amount',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _mode,
              decoration: const InputDecoration(labelText: 'Mode'),
              items: const [
                DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                DropdownMenuItem(value: 'UPI', child: Text('UPI')),
              ],
              onChanged: _isSaving
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() {
                          _mode = value;
                        });
                      }
                    },
            ),
            const Spacer(),
            FilledButton(
              onPressed: _isSaving ? null : _submit,
              child: Text(_isSaving ? 'Saving...' : 'Save Payment'),
            ),
          ],
        ),
      ),
    );
  }
}
