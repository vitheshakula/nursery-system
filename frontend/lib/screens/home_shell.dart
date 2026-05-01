import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/analytics/data/analytics_api.dart';
import '../models/app_user.dart';
import '../models/dashboard_stats.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/metric_tile.dart';
import '../shared/widgets/primary_button.dart';
import '../shared/widgets/section_header.dart';
import '../utils/formatters.dart';
import 'item_management_screen.dart';
import 'vendor_list_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.currentUser,
    required this.onLogout,
  });

  final AppUser currentUser;
  final VoidCallback onLogout;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;
  final GlobalKey<VendorListScreenState> _vendorKey =
      GlobalKey<VendorListScreenState>();
  final GlobalKey<ItemManagementScreenState> _itemKey =
      GlobalKey<ItemManagementScreenState>();

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
        currentUser: widget.currentUser,
        onLogout: widget.onLogout,
        onStartSession: _goToVendors,
        onAddVendor: _openAddVendor,
        onAddItem: _openAddItem,
      ),
      VendorListScreen(
        key: _vendorKey,
        currentUser: widget.currentUser,
      ),
      ItemManagementScreen(
        key: _itemKey,
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
    );
  }
}

class _DashboardScreen extends ConsumerStatefulWidget {
  const _DashboardScreen({
    required this.currentUser,
    required this.onLogout,
    required this.onStartSession,
    required this.onAddVendor,
    required this.onAddItem,
  });

  final AppUser currentUser;
  final VoidCallback onLogout;
  final VoidCallback onStartSession;
  final VoidCallback onAddVendor;
  final VoidCallback onAddItem;

  @override
  ConsumerState<_DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<_DashboardScreen> {
  late Future<DashboardStats> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = ref.read(analyticsApiProvider).getDashboardStats();
  }

  void _reload() {
    setState(() {
      _statsFuture = ref.read(analyticsApiProvider).getDashboardStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      body: FutureBuilder<DashboardStats>(
        future: _statsFuture,
        builder: (context, snapshot) {
          final hasError = snapshot.hasError;
          final stats = snapshot.data;

          return Stack(
            children: [
              _DashboardHeader(
                userName: widget.currentUser.name,
                onLogout: widget.onLogout,
                onRefresh: _reload,
              ),
              SafeArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 152, 16, 24),
                  children: [
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const AppCard(
                        padding: EdgeInsets.all(28),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (hasError)
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Could not load dashboard right now.',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            PrimaryButton(
                              label: 'Retry',
                              icon: Icons.refresh,
                              onPressed: _reload,
                            ),
                          ],
                        ),
                      )
                    else ...[
                      _FeaturedSummaryCard(stats: stats),
                      const SizedBox(height: 18),
                      _MetricGrid(stats: stats),
                    ],
                    const SizedBox(height: 24),
                    const SectionHeader(
                      title: 'Quick Actions',
                      subtitle: 'Move quickly through daily nursery work.',
                    ),
                    const SizedBox(height: 12),
                    _QuickActions(
                      onAddVendor: widget.onAddVendor,
                      onStartSession: widget.onStartSession,
                      onViewReports: _reload,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.userName,
    required this.onLogout,
    required this.onRefresh,
  });

  final String userName;
  final VoidCallback onLogout;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFE8F3E3),
            Color(0xFFD7EBCB),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF5E6B63),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: const Color(0xFF17351F),
                                fontWeight: FontWeight.w900,
                                height: 1,
                              ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Here is what is happening at Shiv Raj Nursery today.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF5E6B63),
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Row(
              children: [
                _HeaderIconButton(
                  icon: Icons.refresh,
                  onPressed: onRefresh,
                ),
                const SizedBox(width: 8),
                _HeaderIconButton(
                  icon: Icons.person_outline,
                  onPressed: onLogout,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({
    required this.stats,
  });

  final DashboardStats? stats;

  @override
  Widget build(BuildContext context) {
    final pendingVendors = stats?.vendorsWithBalance ?? 0;
    final tiles = [
      MetricTile(
        label: 'Total Sales',
        value: formatCurrency(stats?.totalSales ?? 0),
        icon: Icons.currency_rupee,
        caption: 'Closed today',
      ),
      MetricTile(
        label: 'Active Sessions',
        value: '${stats?.activeSessions ?? 0}',
        icon: Icons.play_circle_outline,
        accentColor: const Color(0xFF078C96),
        caption: 'In progress',
      ),
      MetricTile(
        label: 'Vendors',
        value: '$pendingVendors',
        icon: Icons.storefront_outlined,
        accentColor: const Color(0xFF5866B2),
        caption: 'With balance',
      ),
      MetricTile(
        label: 'Pending Balance',
        value: '$pendingVendors',
        icon: Icons.account_balance_wallet_outlined,
        accentColor: const Color(0xFFC27A2C),
        caption: 'Vendor count',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final width = (constraints.maxWidth - spacing) / 2;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final tile in tiles)
              SizedBox(
                width: width,
                child: tile,
              ),
          ],
        );
      },
    );
  }
}

class _FeaturedSummaryCard extends StatelessWidget {
  const _FeaturedSummaryCard({
    required this.stats,
  });

  final DashboardStats? stats;

  @override
  Widget build(BuildContext context) {
    final activeSessions = stats?.activeSessions ?? 0;
    final pendingVendors = stats?.vendorsWithBalance ?? 0;
    final progress = ((activeSessions + pendingVendors) / 20).clamp(0.08, 1.0);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF078C96),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22078C96),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.insights, color: Colors.white),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B5960),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Today',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'Total Sales',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formatCurrency(stats?.totalSales ?? 0),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$activeSessions active sessions',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$pendingVendors pending',
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onAddVendor,
    required this.onStartSession,
    required this.onViewReports,
  });

  final VoidCallback onAddVendor;
  final VoidCallback onStartSession;
  final VoidCallback onViewReports;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionTile(
        icon: Icons.person_add_alt_1,
        title: 'Add Vendor',
        subtitle: 'Create a vendor profile',
        onTap: onAddVendor,
      ),
      _ActionTile(
        icon: Icons.play_arrow,
        title: 'Start Session',
        subtitle: 'Begin daily issue work',
        onTap: onStartSession,
      ),
      _ActionTile(
        icon: Icons.bar_chart_outlined,
        title: 'View Reports',
        subtitle: 'Refresh dashboard totals',
        onTap: onViewReports,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 540) {
          return Column(
            children: [
              for (var index = 0; index < actions.length; index++) ...[
                actions[index],
                if (index != actions.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final action in actions)
              SizedBox(
                width: (constraints.maxWidth - 12) / 2,
                child: action,
              ),
          ],
        );
      },
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
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFDDECCF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.78),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPressed,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, color: const Color(0xFF17351F)),
        ),
      ),
    );
  }
}
