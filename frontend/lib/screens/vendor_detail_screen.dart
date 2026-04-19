import 'package:flutter/material.dart';

import '../models/payment.dart';
import '../models/vendor.dart';
import '../models/vendor_session.dart';
import '../services/api_service.dart';
import '../utils/formatters.dart';
import 'session_screen.dart';
import 'summary_screen.dart';

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
  List<VendorSession> _sessions = const <VendorSession>[];
  List<PaymentRecord> _payments = const <PaymentRecord>[];
  bool _isLoading = true;
  bool _isStarting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _vendor = widget.vendor;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        widget.apiService.getVendor(_vendor.id),
        widget.apiService.getVendorSessions(_vendor.id),
        widget.apiService.getVendorPayments(_vendor.id),
      ]);

      if (!mounted) {
        return;
      }
      setState(() {
        _vendor = results[0] as Vendor;
        _sessions = results[1] as List<VendorSession>;
        _payments = results[2] as List<PaymentRecord>;
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

  Future<void> _startSession() async {
    setState(() {
      _isStarting = true;
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
        await _loadData();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isStarting = false;
        });
      }
    }
  }

  Future<void> _openSessionSummary(VendorSession session) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SummaryScreen(
          apiService: widget.apiService,
          sessionId: session.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor Details'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isStarting ? null : _startSession,
        icon: const Icon(Icons.play_arrow),
        label: Text(_isStarting ? 'Starting...' : 'Start Session'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 92),
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
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('Sessions history', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      if (_sessions.isEmpty)
                        const _SectionEmptyState(message: 'No sessions yet.')
                      else
                        ..._sessions.map(
                          (session) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Card(
                              child: ListTile(
                                onTap: () => _openSessionSummary(session),
                                title: Text(
                                  session.status == 'ACTIVE' ? 'Active session' : 'Closed session',
                                ),
                                subtitle: Text(
                                  '${formatDateTime(session.createdAt)}\nSold: ${session.totalSold}  Bill: ${formatCurrency(session.totalBill)}',
                                ),
                                trailing: const Icon(Icons.chevron_right),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      Text('Payments history', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      if (_payments.isEmpty)
                        const _SectionEmptyState(message: 'No payments yet.')
                      else
                        ..._payments.map(
                          (payment) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFFDDECCF),
                                  child: Text(payment.mode == 'UPI' ? 'U' : 'C'),
                                ),
                                title: Text(formatCurrency(payment.amount)),
                                subtitle: Text('${payment.mode} - ${formatDateTime(payment.createdAt)}'),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _SectionEmptyState extends StatelessWidget {
  const _SectionEmptyState({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message),
      ),
    );
  }
}
