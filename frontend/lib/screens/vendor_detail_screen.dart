import 'package:flutter/material.dart';

import '../models/payment.dart';
import '../models/vendor.dart';
import '../services/api_service.dart';
import '../utils/formatters.dart';
import 'payment_screen.dart';
import 'session_screen.dart';

class VendorDetailScreen extends StatefulWidget {
  const VendorDetailScreen({
    super.key,
    required this.apiService,
    required this.vendor,
  });

  final ApiService apiService;
  final Vendor vendor;

  @override
  State<VendorDetailScreen> createState() => _VendorDetailScreenState();
}

class _VendorDetailScreenState extends State<VendorDetailScreen> {
  late Vendor _vendor;
  late Future<List<PaymentRecord>> _paymentsFuture;
  bool _isStartingSession = false;

  @override
  void initState() {
    super.initState();
    _vendor = widget.vendor;
    _paymentsFuture = widget.apiService.getVendorPayments(widget.vendor.id);
  }

  void _reloadPayments() {
    setState(() {
      _paymentsFuture = widget.apiService.getVendorPayments(_vendor.id);
    });
  }

  Future<void> _refreshVendor() async {
    try {
      final refreshed = await widget.apiService.getVendor(_vendor.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _vendor = refreshed;
      });
    } catch (_) {
      // Keep current vendor snapshot if refresh fails.
    }
  }

  Future<void> _startSession() async {
    setState(() {
      _isStartingSession = true;
    });

    try {
      final session = await widget.apiService.startSession(_vendor.id);
      if (!mounted) {
        return;
      }

      final changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => SessionScreen(
            apiService: widget.apiService,
            vendor: _vendor,
            session: session,
          ),
        ),
      );

      if (changed == true) {
        await _refreshVendor();
        _reloadPayments();
      }
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isStartingSession = false;
        });
      }
    }
  }

  Future<void> _openPayment() async {
    final payment = await Navigator.of(context).push<PaymentRecord>(
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          apiService: widget.apiService,
          vendor: _vendor,
        ),
      ),
    );

    if (payment != null) {
      setState(() {
        _vendor = _vendor.copyWith(balance: payment.vendorBalance ?? _vendor.balance);
      });
      _reloadPayments();
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
        title: const Text('Vendor Details'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openPayment,
        icon: const Icon(Icons.payments_outlined),
        label: const Text('Add Payment'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _refreshVendor();
          _reloadPayments();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_vendor.name, style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text('Phone: ${_vendor.phone}'),
                    const SizedBox(height: 4),
                    Text('Balance: ${formatCurrency(_vendor.balance)}'),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _isStartingSession ? null : _startSession,
                      icon: const Icon(Icons.play_arrow),
                      label: Text(_isStartingSession ? 'Starting...' : 'Start Session'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Sessions History', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No sessions yet.\nSession history list is not available from the current backend API.',
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Payments History', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            FutureBuilder<List<PaymentRecord>>(
              future: _paymentsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(snapshot.error.toString()),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _reloadPayments,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final payments = snapshot.data ?? const <PaymentRecord>[];
                if (payments.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No payments yet.'),
                    ),
                  );
                }

                return Column(
                  children: payments
                      .map(
                        (payment) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.payments),
                              ),
                              title: Text(formatCurrency(payment.amount)),
                              subtitle: Text(
                                '${payment.mode} - ${formatDateTime(payment.createdAt)}',
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
