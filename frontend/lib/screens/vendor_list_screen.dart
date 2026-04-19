import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/vendor.dart';
import '../services/api_service.dart';
import '../utils/formatters.dart';
import 'vendor_detail_screen.dart';

class VendorListScreen extends StatefulWidget {
  const VendorListScreen({
    super.key,
    required this.apiService,
    required this.currentUser,
  });

  final ApiService apiService;
  final AppUser currentUser;

  @override
  State<VendorListScreen> createState() => VendorListScreenState();
}

class VendorListScreenState extends State<VendorListScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Vendor> _vendors = const <Vendor>[];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVendors();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadVendors() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final vendors = await widget.apiService.getVendors();
      if (!mounted) {
        return;
      }
      setState(() {
        _vendors = vendors;
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

  void openVendorForm([Vendor? vendor]) {
    _showVendorForm(vendor: vendor);
  }

  Future<void> _showVendorForm({Vendor? vendor}) async {
    final result = await showModalBottomSheet<Vendor>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _VendorFormSheet(
        apiService: widget.apiService,
        vendor: vendor,
      ),
    );

    if (result != null) {
      await _loadVendors();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(vendor == null ? 'Vendor added.' : 'Vendor updated.')),
        );
      }
    }
  }

  Future<void> _deleteVendor(Vendor vendor) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete Vendor'),
            content: Text('Delete ${vendor.name}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    try {
      await widget.apiService.deleteVendor(vendor.id);
      await _loadVendors();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vendor deleted.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  Future<void> _openVendorDetail(Vendor vendor) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VendorDetailScreen(
          apiService: widget.apiService,
          vendor: vendor,
        ),
      ),
    );
    await _loadVendors();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _vendors.where((vendor) {
      return query.isEmpty ||
          vendor.name.toLowerCase().contains(query) ||
          vendor.phone.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendors'),
        actions: [
          IconButton(
            onPressed: _loadVendors,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showVendorForm(),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add Vendor'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search vendor by name or phone',
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _VendorStateMessage(message: _error!, onRetry: _loadVendors)
                      : filtered.isEmpty
                          ? const _VendorStateMessage(message: 'No vendors yet.')
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final vendor = filtered[index];
                                return Card(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () => _openVendorDetail(vendor),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 52,
                                            height: 52,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFDDECCF),
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            child: const Icon(Icons.storefront_outlined),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  vendor.name,
                                                  style: Theme.of(context).textTheme.titleMedium,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(vendor.phone),
                                                const SizedBox(height: 4),
                                                Text('Balance: ${formatCurrency(vendor.balance)}'),
                                              ],
                                            ),
                                          ),
                                          PopupMenuButton<String>(
                                            onSelected: (value) {
                                              if (value == 'edit') {
                                                _showVendorForm(vendor: vendor);
                                              } else if (value == 'delete') {
                                                _deleteVendor(vendor);
                                              }
                                            },
                                            itemBuilder: (context) => const [
                                              PopupMenuItem(
                                                value: 'edit',
                                                child: Text('Edit'),
                                              ),
                                              PopupMenuItem(
                                                value: 'delete',
                                                child: Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
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

class _VendorFormSheet extends StatefulWidget {
  const _VendorFormSheet({
    required this.apiService,
    this.vendor,
  });

  final ApiService apiService;
  final Vendor? vendor;

  @override
  State<_VendorFormSheet> createState() => _VendorFormSheetState();
}

class _VendorFormSheetState extends State<_VendorFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.vendor?.name ?? '');
    _phoneController = TextEditingController(text: widget.vendor?.phone ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      _showMessage('Enter vendor name and phone.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final vendor = widget.vendor == null
          ? await widget.apiService.createVendor(name: name, phone: phone)
          : await widget.apiService.updateVendor(
              vendorId: widget.vendor!.id,
              name: name,
              phone: phone,
            );

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(vendor);
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.vendor == null ? 'Add Vendor' : 'Edit Vendor',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Vendor name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: Text(_isSaving ? 'Saving...' : 'Save Vendor'),
            ),
          ],
        ),
      ),
    );
  }
}

class _VendorStateMessage extends StatelessWidget {
  const _VendorStateMessage({
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }
}
