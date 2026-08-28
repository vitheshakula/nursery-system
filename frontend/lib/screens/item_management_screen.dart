import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/inventory/data/inventory_api.dart';
import '../models/app_user.dart';
import '../models/category.dart';
import '../models/item.dart';
import '../shared/theme/app_theme.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/empty_state_widget.dart';
import '../shared/widgets/operational_widgets.dart';
import '../utils/formatters.dart';
import 'category_management_screen.dart';

class ItemManagementScreen extends ConsumerStatefulWidget {
  const ItemManagementScreen({
    super.key,
    required this.currentUser,
  });

  final AppUser currentUser;

  @override
  ConsumerState<ItemManagementScreen> createState() =>
      ItemManagementScreenState();
}

class ItemManagementScreenState extends ConsumerState<ItemManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Item> _items = const <Item>[];
  List<Category> _categories = const <Category>[];
  String _selectedCategoryId = 'all';
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final inventoryApi = ref.read(inventoryApiProvider);
      final results = await Future.wait([
        inventoryApi.getItems(),
        inventoryApi.getCategories(),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _items = results[0] as List<Item>;
        _categories = results[1] as List<Category>;
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

  void openAddItemSheet() {
    _showItemSheet();
  }

  Future<void> _showItemSheet() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ItemFormSheet(
        categories: _categories,
      ),
    );

    if (added == true) {
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item saved successfully.')),
        );
      }
    }
  }

  Future<void> _openCategoryManagement() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CategoryManagementScreen(),
      ),
    );
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final search = _searchController.text.trim().toLowerCase();
    final filtered = _items.where((item) {
      final categoryMatch = _selectedCategoryId == 'all' ||
          item.categoryId == _selectedCategoryId;
      final searchMatch =
          search.isEmpty || item.name.toLowerCase().contains(search);
      return categoryMatch && searchMatch;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Items'),
        actions: [
          if (widget.currentUser.isAdmin)
            IconButton(
              onPressed: _openCategoryManagement,
              icon: const Icon(Icons.category_outlined),
              tooltip: 'Categories',
            ),
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: widget.currentUser.isAdmin
          ? FloatingActionButton.extended(
              onPressed: _showItemSheet,
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
            )
          : null,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search items',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('All'),
                      selected: _selectedCategoryId == 'all',
                      labelStyle: TextStyle(
                        color: _selectedCategoryId == 'all'
                            ? AppColors.primary
                            : AppColors.muted,
                        fontWeight: FontWeight.w800,
                      ),
                      onSelected: (_) {
                        setState(() {
                          _selectedCategoryId = 'all';
                        });
                      },
                    ),
                  ),
                  ..._categories.map((category) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(category.name),
                        selected: _selectedCategoryId == category.id,
                        labelStyle: TextStyle(
                          color: _selectedCategoryId == category.id
                              ? AppColors.primary
                              : AppColors.muted,
                          fontWeight: FontWeight.w800,
                        ),
                        onSelected: (_) {
                          setState(() {
                            _selectedCategoryId = category.id;
                          });
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: _isLoading
                  ? const LoadingState(label: 'Loading inventory')
                  : _error != null
                      ? _StateMessage(message: _error!, onRetry: _loadData)
                      : filtered.isEmpty
                          ? EmptyStateWidget(
                              title: 'No items available',
                              message:
                                  'Add plants and prices so sessions stay fast.',
                              icon: Icons.inventory_2_outlined,
                              actionLabel: widget.currentUser.isAdmin
                                  ? 'Add Item'
                                  : null,
                              onAction: widget.currentUser.isAdmin
                                  ? _showItemSheet
                                  : null,
                            )
                          : AppCard(
                              padding: EdgeInsets.zero,
                              child: ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final item = filtered[index];
                                  final categoryName = _categories
                                      .firstWhere(
                                        (category) =>
                                            category.id == item.categoryId,
                                        orElse: () => const Category(
                                            id: '', name: 'Others'),
                                      )
                                      .name;
                                  final lowStock = item.currentStock <= 10;

                                  return Padding(
                                    padding:
                                        const EdgeInsets.all(AppSpacing.md),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceHigh,
                                            borderRadius: BorderRadius.circular(
                                                AppRadii.md),
                                            border: Border.all(
                                                color: AppColors.line),
                                          ),
                                          child: Icon(
                                            lowStock
                                                ? Icons.warning_amber_outlined
                                                : Icons.inventory_2_outlined,
                                            color: lowStock
                                                ? AppColors.warning
                                                : AppColors.primary,
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.sm),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      item.name,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .titleSmall,
                                                    ),
                                                  ),
                                                  if (lowStock) ...[
                                                    const SizedBox(
                                                        width: AppSpacing.xs),
                                                    const StatusChip(
                                                      label: 'Low stock',
                                                      tone:
                                                          OperationalStatusTone
                                                              .warning,
                                                      icon: Icons
                                                          .warning_amber_outlined,
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Wrap(
                                                spacing: AppSpacing.xs,
                                                runSpacing: AppSpacing.xs,
                                                children: [
                                                  _InfoPill(
                                                      label: categoryName),
                                                  _InfoPill(
                                                    label:
                                                        'Stock ${item.currentStock}',
                                                  ),
                                                  _InfoPill(
                                                    label:
                                                        'Vendor ${formatCurrency(item.vendorPrice)}',
                                                  ),
                                                  if (item.retailPrice != null)
                                                    _InfoPill(
                                                      label:
                                                          'Retail ${formatCurrency(item.retailPrice!)}',
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemFormSheet extends ConsumerStatefulWidget {
  const _ItemFormSheet({
    required this.categories,
  });

  final List<Category> categories;

  @override
  ConsumerState<_ItemFormSheet> createState() => _ItemFormSheetState();
}

class _ItemFormSheetState extends ConsumerState<_ItemFormSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _vendorPriceController = TextEditingController();
  final TextEditingController _retailPriceController = TextEditingController();
  String? _selectedCategoryId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId =
        widget.categories.isEmpty ? null : widget.categories.first.id;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _vendorPriceController.dispose();
    _retailPriceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final vendorPrice = double.tryParse(_vendorPriceController.text.trim());
    final retailPriceText = _retailPriceController.text.trim();
    final retailPrice =
        retailPriceText.isEmpty ? null : double.tryParse(retailPriceText);

    if (name.isEmpty ||
        _selectedCategoryId == null ||
        vendorPrice == null ||
        vendorPrice <= 0) {
      _showMessage('Enter item name, category and valid price.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await ref.read(inventoryApiProvider).createItem(
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
            Text('Add Item', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            if (widget.categories.isEmpty)
              const Text('Add categories first to create items.')
            else ...[
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Item name'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategoryId,
                decoration: const InputDecoration(labelText: 'Category'),
                items: widget.categories
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
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Vendor price'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _retailPriceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const InputDecoration(labelText: 'Retail price (optional)'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: Text(_isSaving ? 'Saving...' : 'Save Item'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.muted,
        ),
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: OperationalBanner(
        title: 'Inventory unavailable',
        message: message,
        icon: Icons.error_outline,
        tone: OperationalStatusTone.danger,
        action: onRetry == null
            ? null
            : TextButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
      ),
    );
  }
}
