import 'package:flutter/material.dart';

import '../models/session_info.dart';
import '../models/vendor.dart';
import '../services/api_service.dart';

class VendorListScreen extends StatefulWidget {
  const VendorListScreen({
    super.key,
    required this.apiService,
    required this.onSessionStarted,
    required this.onLogout,
    required this.userName,
  });

  final ApiService apiService;
  final void Function(Vendor vendor, SessionInfo session) onSessionStarted;
  final VoidCallback onLogout;
  final String userName;

  @override
  State<VendorListScreen> createState() => _VendorListScreenState();
}

class _VendorListScreenState extends State<VendorListScreen> {
  late Future<List<Vendor>> _vendorsFuture;
  String? _startingVendorId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _vendorsFuture = widget.apiService.getVendors();
  }

  void _reload() {
    setState(() {
      _error = null;
      _vendorsFuture = widget.apiService.getVendors();
    });
  }

  Future<void> _startSession(Vendor vendor) async {
    setState(() {
      _startingVendorId = vendor.id;
      _error = null;
    });

    try {
      final session = await widget.apiService.startSession(vendor.id);
      widget.onSessionStarted(vendor, session);
    } catch (error) {
      setState(() {
        _error = error is ApiException ? error.message : 'Unable to start session';
      });
    } finally {
      if (mounted) {
        setState(() {
          _startingVendorId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendors'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Signed in as ${widget.userName}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (_error != null) ...[
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 12),
            ],
            Expanded(
              child: FutureBuilder<List<Vendor>>(
                future: _vendorsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(snapshot.error.toString()),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _reload,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  final vendors = snapshot.data ?? const <Vendor>[];
                  if (vendors.isEmpty) {
                    return const Center(child: Text('No vendors found'));
                  }

                  return ListView.separated(
                    itemCount: vendors.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final vendor = vendors[index];
                      return Card(
                        child: ListTile(
                          title: Text(vendor.name),
                          subtitle: Text('Balance: ${vendor.balance.toStringAsFixed(2)}'),
                          trailing: FilledButton(
                            onPressed: _startingVendorId == vendor.id
                                ? null
                                : () => _startSession(vendor),
                            child: Text(
                              _startingVendorId == vendor.id
                                  ? 'Starting...'
                                  : 'Start Session',
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
