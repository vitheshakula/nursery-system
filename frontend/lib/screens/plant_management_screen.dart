import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/plant.dart';
import '../services/api_service.dart';
import '../utils/formatters.dart';

class PlantManagementScreen extends StatefulWidget {
  const PlantManagementScreen({
    super.key,
    required this.apiService,
  });

  final ApiService apiService;

  @override
  State<PlantManagementScreen> createState() => _PlantManagementScreenState();
}

class _PlantManagementScreenState extends State<PlantManagementScreen> {
  late Future<List<Plant>> _plantsFuture;

  @override
  void initState() {
    super.initState();
    _plantsFuture = widget.apiService.getPlants();
  }

  void _reload() {
    setState(() {
      _plantsFuture = widget.apiService.getPlants();
    });
  }

  Future<void> _openAddPlantSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddPlantSheet(apiService: widget.apiService),
    );

    if (created == true) {
      _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plant added successfully.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plant Management'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddPlantSheet,
        icon: const Icon(Icons.add),
        label: const Text('Add Plant'),
      ),
      body: FutureBuilder<List<Plant>>(
        future: _plantsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _MessageState(
              message: snapshot.error.toString(),
              actionLabel: 'Retry',
              onAction: _reload,
            );
          }

          final plants = snapshot.data ?? const <Plant>[];
          if (plants.isEmpty) {
            return const _MessageState(message: 'No plants available.');
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: plants.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final plant = plants[index];
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
                            Text('Vendor price: ${formatCurrency(plant.vendorPrice)}'),
                            if (plant.retailPrice != null)
                              Text('Retail price: ${formatCurrency(plant.retailPrice!)}'),
                          ],
                        ),
                      ),
                    ],
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

class _AddPlantSheet extends StatefulWidget {
  const _AddPlantSheet({
    required this.apiService,
  });

  final ApiService apiService;

  @override
  State<_AddPlantSheet> createState() => _AddPlantSheetState();
}

class _AddPlantSheetState extends State<_AddPlantSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _vendorPriceController = TextEditingController();
  final TextEditingController _retailPriceController = TextEditingController();

  bool _isLoadingCategories = true;
  bool _isSaving = false;
  List<Category> _categories = const <Category>[];
  String? _selectedCategoryId;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _vendorPriceController.dispose();
    _retailPriceController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoadingCategories = true;
      _loadError = null;
    });

    try {
      final categories = await widget.apiService.getCategories();
      setState(() {
        _categories = categories;
        _selectedCategoryId = categories.isNotEmpty ? categories.first.id : null;
      });
    } catch (error) {
      setState(() {
        _loadError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
        });
      }
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final vendorPrice = double.tryParse(_vendorPriceController.text.trim());
    final retailPriceText = _retailPriceController.text.trim();
    final retailPrice = retailPriceText.isEmpty ? null : double.tryParse(retailPriceText);

    if (name.isEmpty || _selectedCategoryId == null || vendorPrice == null || vendorPrice <= 0) {
      _showMessage('Enter plant name, category, and a valid vendor price.');
      return;
    }

    if (retailPriceText.isNotEmpty && (retailPrice == null || retailPrice <= 0)) {
      _showMessage('Enter a valid retail price or leave it empty.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.apiService.createPlant(
        name: name,
        categoryId: _selectedCategoryId!,
        vendorPrice: vendorPrice,
        retailPrice: retailPrice,
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
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add Plant', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            if (_isLoadingCategories)
              const Center(child: CircularProgressIndicator())
            else if (_loadError != null)
              _MessageState(
                message: _loadError!,
                actionLabel: 'Retry',
                onAction: _loadCategories,
              )
            else if (_categories.isEmpty)
              const _MessageState(
                message: 'No categories available. Add categories in the backend first.',
              )
            else ...[
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Plant name'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedCategoryId,
                decoration: const InputDecoration(labelText: 'Category'),
                items: _categories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category.id,
                        child: Text(category.name),
                      ),
                    )
                    .toList(),
                onChanged: _isSaving
                    ? null
                    : (value) {
                        setState(() {
                          _selectedCategoryId = value;
                        });
                      },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _vendorPriceController,
                decoration: const InputDecoration(labelText: 'Vendor price'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _retailPriceController,
                decoration: const InputDecoration(
                  labelText: 'Retail price (optional)',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: Text(_isSaving ? 'Saving...' : 'Save Plant'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
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
