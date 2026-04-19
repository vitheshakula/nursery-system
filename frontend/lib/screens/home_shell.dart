import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/dashboard_stats.dart';
import '../services/api_service.dart';
import '../utils/formatters.dart';
import 'item_management_screen.dart';
import 'vendor_list_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.apiService,
    required this.currentUser,
    required this.onLogout,
  });

  final ApiService apiService;
  final AppUser currentUser;
  final VoidCallback onLogout;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;
  final GlobalKey<VendorListScreenState> _vendorKey = GlobalKey<VendorListScreenState>();
  final GlobalKey<ItemManagementScreenState> _itemKey = GlobalKey<ItemManagementScreenState>();

  void _goToVendors() {
    setState(() {
      _currentIndex = 1;
    });
  }

  void _goToItems() {
    setState(() {
      _currentIndex = 2;
    });
  }

  void _openAddVendor() {
    _goToVendors();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _vendorKey.currentState?.openVendorForm();
    });
  }

  void _openAddItem() {
    _goToItems();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _itemKey.currentState?.openAddItemSheet();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      _DashboardScreen(
        apiService: widget.apiService,
        currentUser: widget.currentUser,
        onStartSession: _goToVendors,
        onAddVendor: _openAddVendor,
        onAddItem: _openAddItem,
      ),
      VendorListScreen(
        key: _vendorKey,
        apiService: widget.apiService,
        currentUser: widget.currentUser,
      ),
      ItemManagementScreen(
        key: _itemKey,
        apiService: widget.apiService,
        currentUser: widget.currentUser,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Vendors',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Items',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.small(
              onPressed: widget.onLogout,
              child: const Icon(Icons.logout),
            )
          : null,
    );
  }
}

class _DashboardScreen extends StatefulWidget {
  const _DashboardScreen({
    required this.apiService,
    required this.currentUser,
    required this.onStartSession,
    required this.onAddVendor,
    required this.onAddItem,
  });

  final ApiService apiService;
  final AppUser currentUser;
  final VoidCallback onStartSession;
  final VoidCallback onAddVendor;
  final VoidCallback onAddItem;

  @override
  State<_DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<_DashboardScreen> {
  late Future<DashboardStats> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = widget.apiService.getDashboardStats();
  }

  void _reload() {
    setState(() {
      _statsFuture = widget.apiService.getDashboardStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shiv Raj Nursery'),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<DashboardStats>(
        future: _statsFuture,
        builder: (context, snapshot) {
          final hasError = snapshot.hasError;
          final stats = snapshot.data;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF2E6B3D),
                      Color(0xFF6BA368),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.currentUser.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Fast daily work for items, vendors, sessions and settlement.',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text('Today\'s summary', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (hasError)
                _StateCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Could not load dashboard right now.'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _reload,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        title: 'Total sales',
                        value: formatCurrency(stats?.totalSales ?? 0),
                        icon: Icons.currency_rupee,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
                        title: 'Active sessions',
                        value: '${stats?.activeSessions ?? 0}',
                        icon: Icons.play_circle_outline,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              if (!hasError && stats != null)
                _StateCard(
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${stats.vendorsWithBalance} vendors currently have outstanding balance.',
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              Text('Quick actions', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              _ActionTile(
                icon: Icons.play_arrow,
                title: 'Start session',
                subtitle: 'Open vendors and begin today\'s work',
                onTap: widget.onStartSession,
              ),
              const SizedBox(height: 12),
              _ActionTile(
                icon: Icons.person_add_alt_1,
                title: 'Add vendor',
                subtitle: 'Create a new vendor in seconds',
                onTap: widget.onAddVendor,
              ),
              const SizedBox(height: 12),
              _ActionTile(
                icon: Icons.inventory_2_outlined,
                title: 'Add item',
                subtitle: 'Create a new sale item',
                onTap: widget.onAddItem,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _StateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(title),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _StateCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFFDDECCF),
              child: Icon(icon, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(subtitle),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}
