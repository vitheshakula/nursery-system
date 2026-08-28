import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/payments/data/payment_api.dart';
import '../models/vendor.dart';
import '../shared/theme/app_theme.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/operational_widgets.dart';
import '../utils/formatters.dart';

class SettlementScreen extends ConsumerStatefulWidget {
  const SettlementScreen({
    super.key,
    required this.vendor,
    required this.totalBill,
    required this.previousBalance,
    required this.newBalance,
  });

  final Vendor vendor;
  final double totalBill;
  final double previousBalance;
  final double newBalance;

  @override
  ConsumerState<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends ConsumerState<SettlementScreen> {
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
  double get _remainingCredit =>
      (widget.totalBill - _totalPaid).clamp(0, double.infinity).toDouble();
  double get _updatedOutstanding =>
      (widget.newBalance - _totalPaid).clamp(0, double.infinity).toDouble();

  Future<void> _submitSettlement() async {
    if (_cashPaid < 0 || _onlinePaid < 0) {
      _showMessage('Enter valid payment amounts.');
      return;
    }

    if (_totalPaid > widget.newBalance) {
      _showMessage('Payment is more than the outstanding balance.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final paymentApi = ref.read(paymentApiProvider);
      if (_cashPaid > 0) {
        await paymentApi.createPayment(
          vendorId: widget.vendor.id,
          amount: _cashPaid,
          mode: 'CASH',
        );
      }

      if (_onlinePaid > 0) {
        await paymentApi.createPayment(
          vendorId: widget.vendor.id,
          amount: _onlinePaid,
          mode: 'UPI',
        );
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _totalPaid > 0
                ? 'Settlement saved successfully.'
                : 'Session closed with remaining credit.',
          ),
        ),
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final settlementTone = _updatedOutstanding > 0
        ? OperationalStatusTone.warning
        : OperationalStatusTone.success;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settlement'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: [
          AppCard(
            color: AppColors.surfaceLow,
            borderColor: AppColors.lineStrong,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'VENDOR SETTLEMENT',
                  style: AppTypography.labelCaps,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  widget.vendor.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.md),
                OperationalDataRow(
                  label: 'Total bill',
                  value: formatCurrency(widget.totalBill),
                ),
                OperationalDataRow(
                  label: 'Previous balance',
                  value: formatCurrency(widget.previousBalance),
                ),
                OperationalDataRow(
                  label: 'New balance',
                  value: formatCurrency(widget.newBalance),
                  valueColor: widget.newBalance > 0
                      ? AppColors.warning
                      : AppColors.success,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PAYMENT CAPTURE',
                  style: AppTypography.labelCaps,
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _cashController,
                  onChanged: (_) => setState(() {}),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Cash paid',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _onlineController,
                  onChanged: (_) => setState(() {}),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'UPI / online paid',
                    prefixIcon: Icon(Icons.qr_code_scanner_outlined),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          OperationalBanner(
            title: _updatedOutstanding > 0
                ? 'Settlement will leave pending balance'
                : 'Settlement clears outstanding balance',
            message: _updatedOutstanding > 0
                ? '${formatCurrency(_updatedOutstanding)} remains payable after this entry.'
                : 'This vendor will have no pending balance after saving.',
            icon: _updatedOutstanding > 0
                ? Icons.pending_actions_outlined
                : Icons.verified_outlined,
            tone: settlementTone,
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            color: AppColors.surfaceLow,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                OperationalDataRow(
                  label: 'Total received',
                  value: formatCurrency(_totalPaid),
                  valueColor: _totalPaid > 0 ? AppColors.success : null,
                ),
                OperationalDataRow(
                  label: 'Remaining credit',
                  value: formatCurrency(_remainingCredit),
                ),
                OperationalDataRow(
                  label: 'Outstanding after payment',
                  value: formatCurrency(_updatedOutstanding),
                  valueColor: _updatedOutstanding > 0
                      ? AppColors.warning
                      : AppColors.success,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: _isSaving ? null : _submitSettlement,
            icon: const Icon(Icons.check_circle_outline),
            label: Text(_isSaving ? 'Saving...' : 'Finish Settlement'),
          ),
        ],
      ),
    );
  }
}
