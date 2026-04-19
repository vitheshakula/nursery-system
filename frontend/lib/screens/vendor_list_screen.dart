import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/vendor.dart';
import '../services/api_service.dart';
import '../utils/formatters.dart';
import 'plant_management_screen.dart';
import 'session_screen.dart';
import 'vendor_detail_screen.dart';

class VendorListScreen extends StatefulWidget {
  const VendorListScreen({
    super.key,
    required this.apiService,
    required this.currentUser,
    required this.onLogout,
  });

  final ApiService apiService;
  final AppUser currentUser;
  final VoidCallback onLogout;

  @override
  State<VendorListScreen> createState() => _VendorListScreenState();
}

class _VendorListScreenState extends State<VendorListScreen> {
  late Future<List<Vendor>> _vendorsFuture;
  String? _startingVendorId;

  @override
  void initState() {
    super.initState();
    _vendorsFuture = widget.apiService.getVendors();
  }

  void _reload() {
    setState(() {
      _vendorsFuture = widget.apiService.getVendors();
    });
  }

  Future<void> _startSession(Vendor vendor) async {
    setState(() {
      _startingVendorId = vendor.id;
    });

    try {
      final session = await widget.apiService.startSession(vendor.id);
      if (!mounted) {
        return;
      }

      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => SessionScreen(
            apiService: widget.apiService,
            vendor: vendor,
            session: session,
          ),
        ),
      );
      _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _startingVendorId = null;
        });
      }
    }
  }

  Future<void> _openVendorDetail(Vendor vendor) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => VendorDetailScreen(
          apiService: widget.apiService,
          vendor: vendor,
        ),
      ),
    );

    _reload();
  }

  Future<void> _openPlantManagement() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PlantManagementScreen(apiService: widget.apiService),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendors'),
        actions: [
          if (widget.currentUser.isAdmin)
            IconButton(
              tooltip: 'Plant Management',
              onPressed: _openPlantManagement,
              icon: const Icon(Icons.local_florist),
            ),
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
      body: FutureBuilder<List<Vendor>>(
        future: _vendorsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _StateMessage(
              message: snapshot.error.toString(),
              actionLabel: 'Retry',
              onAction: _reload,
            );
          }

          final vendors = snapshot.data ?? const <Vendor>[];
          if (vendors.isEmpty) {
            return const _StateMessage(message: 'No vendors available.');
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: vendors.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, ${widget.currentUser.name}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text('Tap a vendor for details or start a session right away.'),
                      ],
                    ),
                  ),
                );
              }

              final vendor = vendors[index - 1];
              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openVendorDetail(vendor),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          child: Icon(Icons.storefront_outlined),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(vendor.name, style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 4),
                              Text(vendor.phone),
                              const SizedBox(height: 4),
                              Text('Balance: ${formatCurrency(vendor.balance)}'),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: _startingVendorId == vendor.id
                              ? null
                              : () => _startSession(vendor),
                          child: Text(
                            _startingVendorId == vendor.id ? 'Starting...' : 'Start',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
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
