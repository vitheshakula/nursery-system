import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/analytics/data/analytics_api.dart';
import '../core/offline/operation_queue.dart';
import '../core/sync/sync_controller.dart';
import '../features/sessions/application/session_controller.dart';
import '../models/active_session.dart';
import '../models/app_user.dart';
import '../models/dashboard_stats.dart';
import '../models/operational_insights.dart';
import '../shared/theme/app_theme.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/brand_logo.dart';
import '../utils/formatters.dart';
import 'item_management_screen.dart';
import 'session_screen.dart';
import 'sessions_tab_screen.dart';
import 'sync_diagnostics_screen.dart';
import 'vendor_list_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({
    super.key,
    required this.currentUser,
    required this.onLogout,
  });

  final AppUser currentUser;
  final VoidCallback onLogout;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _currentIndex = 0;
  final GlobalKey<VendorListScreenState> _vendorKey =
      GlobalKey<VendorListScreenState>();
  final GlobalKey<ItemManagementScreenState> _itemKey =
      GlobalKey<ItemManagementScreenState>();

  void _goToVendors() {
    setState(() => _currentIndex = 2);
  }

  void _goToItems() {
    setState(() => _currentIndex = 3);
  }

  void _goToSessions() {
    setState(() => _currentIndex = 1);
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
        onStartSession: _goToSessions,
        onViewVendors: _goToVendors,
        onAddVendor: _openAddVendor,
        onAddItem: _openAddItem,
      ),
      const SessionsTabScreen(),
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
      body: Column(
        children: [
          const _SyncStatusStrip(),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: screens,
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.play_circle_outline),
            selectedIcon: Icon(Icons.play_circle),
            label: 'Sessions',
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

class _SyncStatusStrip extends ConsumerWidget {
  const _SyncStatusStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(queuedOperationsProvider);
    final syncStatus = ref.watch(syncControllerProvider);

    return queue.maybeWhen(
      data: (operations) {
        final pending = operations
            .where((operation) =>
                operation.status == QueuedOperationStatus.pending ||
                operation.status == QueuedOperationStatus.failed)
            .length;

        if (pending == 0 && !syncStatus.isSyncing) {
          return const SizedBox.shrink();
        }

        return SafeArea(
          bottom: false,
          child: Material(
            color: AppColors.primarySoft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    syncStatus.isSyncing
                        ? Icons.sync
                        : Icons.cloud_queue_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      syncStatus.isSyncing
                          ? 'Syncing queued work'
                          : '$pending queued operation${pending == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  TextButton(
                    onPressed: syncStatus.isSyncing
                        ? null
                        : () => ref
                            .read(syncControllerProvider.notifier)
                            .syncNow(),
                    child: const Text('Sync'),
                  ),
                  IconButton(
                    tooltip: 'Sync diagnostics',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SyncDiagnosticsScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.manage_search),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _DashboardScreen extends ConsumerStatefulWidget {
  const _DashboardScreen({
    required this.currentUser,
    required this.onLogout,
    required this.onStartSession,
    required this.onViewVendors,
    required this.onAddVendor,
    required this.onAddItem,
  });

  final AppUser currentUser;
  final VoidCallback onLogout;
  final VoidCallback onStartSession;
  final VoidCallback onViewVendors;
  final VoidCallback onAddVendor;
  final VoidCallback onAddItem;

  @override
  ConsumerState<_DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<_DashboardScreen> {
  late Future<DashboardStats> _statsFuture;
  late Future<OperationalInsights> _insightsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = ref.read(analyticsApiProvider).getDashboardStats();
    _insightsFuture = ref.read(analyticsApiProvider).getOperationalInsights();
  }

  Future<void> _reload() async {
    setState(() {
      _statsFuture = ref.read(analyticsApiProvider).getDashboardStats();
      _insightsFuture = ref.read(analyticsApiProvider).getOperationalInsights();
    });
    ref.invalidate(activeSessionsProvider);
    await Future.wait([
      _statsFuture,
      _insightsFuture,
      ref.read(activeSessionsProvider.future),
    ]);
  }

  Future<void> _openActiveSession(ActiveSession session) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SessionScreen(
          vendor: session.toVendor(),
          session: session.toSessionInfo(),
        ),
      ),
    );

    if (changed == true) {
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeSessionsValue = ref.watch(activeSessionsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<DashboardStats>(
        future: _statsFuture,
        builder: (context, snapshot) {
          final stats = snapshot.data;
          final isLoading = snapshot.connectionState == ConnectionState.waiting;

          return RefreshIndicator(
            onRefresh: _reload,
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                children: [
                  _ControlHeader(
                    userName: widget.currentUser.name,
                    onLogout: widget.onLogout,
                    onRefresh: _reload,
                  ),
                  const SizedBox(height: 20),
                  if (snapshot.hasError)
                    _DashboardErrorCard(onRetry: _reload)
                  else
                    _HeroControlCard(
                      stats: stats,
                      isLoading: isLoading,
                      primaryLabel: activeSessionsValue.maybeWhen(
                        data: (sessions) => sessions.isNotEmpty
                            ? 'Continue Session'
                            : 'Start Session',
                        orElse: () => 'Start Session',
                      ),
                      onPrimaryAction: activeSessionsValue.maybeWhen(
                        data: (sessions) => sessions.isNotEmpty
                            ? () => _openActiveSession(sessions.first)
                            : widget.onStartSession,
                        orElse: () => widget.onStartSession,
                      ),
                    ),
                  const SizedBox(height: 20),
                  _SmartSummaryCard(stats: stats, isLoading: isLoading),
                  const SizedBox(height: 16),
                  FutureBuilder<OperationalInsights>(
                    future: _insightsFuture,
                    builder: (context, insightsSnapshot) {
                      final insights = insightsSnapshot.data;
                      if (insightsSnapshot.hasError || insights == null) {
                        return const SizedBox.shrink();
                      }

                      return _OperationalAlertsCard(insights: insights);
                    },
                  ),
                  const SizedBox(height: 24),
                  _ActiveSessionsControl(
                    sessionsValue: activeSessionsValue,
                    onStartSession: widget.onStartSession,
                    onOpenSession: _openActiveSession,
                  ),
                  const SizedBox(height: 24),
                  _NextActionCard(
                    pendingVendors: stats?.vendorsWithBalance ?? 0,
                    onCollectPayment: widget.onViewVendors,
                    onAddVendor: widget.onAddVendor,
                    onAddItem: widget.onAddItem,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ControlHeader extends StatelessWidget {
  const _ControlHeader({
    required this.userName,
    required this.onLogout,
    required this.onRefresh,
  });

  final String userName;
  final VoidCallback onLogout;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const BrandLogo(size: 50),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Shivraj Nursery',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                userName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                    ),
              ),
            ],
          ),
        ),
        _HeaderIconButton(icon: Icons.refresh, onPressed: onRefresh),
        const SizedBox(width: 8),
        _HeaderIconButton(icon: Icons.person_outline, onPressed: onLogout),
      ],
    );
  }
}

class _HeroControlCard extends StatelessWidget {
  const _HeroControlCard({
    required this.stats,
    required this.isLoading,
    required this.primaryLabel,
    required this.onPrimaryAction,
  });

  final DashboardStats? stats;
  final bool isLoading;
  final String primaryLabel;
  final VoidCallback onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x28245533),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Today collected',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.trending_up, color: Colors.white),
            ],
          ),
          const SizedBox(height: 22),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: isLoading
                ? const SizedBox(
                    key: ValueKey('loading'),
                    height: 44,
                    width: 44,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                : Text(
                    formatCurrency(stats?.totalSales ?? 0),
                    key: const ValueKey('value'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
          const SizedBox(height: 10),
          Text(
            '${stats?.activeSessions ?? 0} live sessions | ${stats?.vendorsWithBalance ?? 0} pending vendors',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onPrimaryAction,
              icon: const Icon(Icons.arrow_forward),
              label: Text(primaryLabel),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmartSummaryCard extends StatelessWidget {
  const _SmartSummaryCard({
    required this.stats,
    required this.isLoading,
  });

  final DashboardStats? stats;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final text = isLoading
        ? 'Reading todays nursery activity...'
        : 'Today: ${stats?.activeSessions ?? 0} sessions | ${formatCurrency(stats?.totalSales ?? 0)} collected | ${stats?.vendorsWithBalance ?? 0} pending vendors';

    return AppCard(
      color: AppColors.primarySoft,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.auto_awesome, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OperationalAlertsCard extends StatelessWidget {
  const _OperationalAlertsCard({required this.insights});

  final OperationalInsights insights;

  @override
  Widget build(BuildContext context) {
    final alerts = insights.alerts.take(3).toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Operational signals',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                '${insights.windowDays}d',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SignalChip(
                label: '${insights.dailySnapshot.lowStockCount} low stock',
                icon: Icons.inventory_2_outlined,
              ),
              _SignalChip(
                label:
                    '${insights.dailySnapshot.largeBalanceCount} large balances',
                icon: Icons.account_balance_wallet_outlined,
              ),
              _SignalChip(
                label:
                    '${insights.dailySnapshot.reconciliationRiskCount} drift risks',
                icon: Icons.rule_folder_outlined,
              ),
            ],
          ),
          if (alerts.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (final alert in alerts) _AlertLine(alert: alert),
          ],
        ],
      ),
    );
  }
}

class _SignalChip extends StatelessWidget {
  const _SignalChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _AlertLine extends StatelessWidget {
  const _AlertLine({required this.alert});

  final OperationalAlert alert;

  @override
  Widget build(BuildContext context) {
    final color = alert.severity == 'HIGH'
        ? Theme.of(context).colorScheme.error
        : AppColors.warning;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              alert.message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveSessionsControl extends StatelessWidget {
  const _ActiveSessionsControl({
    required this.sessionsValue,
    required this.onStartSession,
    required this.onOpenSession,
  });

  final AsyncValue<List<ActiveSession>> sessionsValue;
  final VoidCallback onStartSession;
  final ValueChanged<ActiveSession> onOpenSession;

  @override
  Widget build(BuildContext context) {
    return sessionsValue.when(
      loading: () => const AppCard(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => AppCard(
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Active sessions could not load.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
      data: (sessions) {
        if (sessions.isEmpty) {
          return _NoLiveSessionsCard(onStartSession: onStartSession);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel(
              title: 'Live Sessions',
              actionLabel: 'View all',
              onAction: onStartSession,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 154,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: sessions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final session = sessions[index];
                  return SizedBox(
                    width: 292,
                    child: _LiveSessionCard(
                      session: session,
                      onTap: () => onOpenSession(session),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LiveSessionCard extends StatefulWidget {
  const _LiveSessionCard({
    required this.session,
    required this.onTap,
  });

  final ActiveSession session;
  final VoidCallback onTap;

  @override
  State<_LiveSessionCard> createState() => _LiveSessionCardState();
}

class _LiveSessionCardState extends State<_LiveSessionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.08, end: 0.22).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: const Duration(milliseconds: 110),
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: _pulse.value),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: child,
          );
        },
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: (value) => setState(() => _pressed = value),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const _LiveDot(),
                      const SizedBox(width: 8),
                      Text(
                        'In Progress',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_forward, color: AppColors.primary),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    widget.session.vendorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Balance ${formatCurrency(widget.session.totalBill)}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.session.totalIssued} issued | ${widget.session.totalReturned} returned',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _NoLiveSessionsCard extends StatelessWidget {
  const _NoLiveSessionsCard({required this.onStartSession});

  final VoidCallback onStartSession;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                const Icon(Icons.play_circle_outline, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No live sessions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                const Text('Start issuing plants for today.'),
              ],
            ),
          ),
          FilledButton(
            onPressed: onStartSession,
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }
}

class _NextActionCard extends StatelessWidget {
  const _NextActionCard({
    required this.pendingVendors,
    required this.onCollectPayment,
    required this.onAddVendor,
    required this.onAddItem,
  });

  final int pendingVendors;
  final VoidCallback onCollectPayment;
  final VoidCallback onAddVendor;
  final VoidCallback onAddItem;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(title: 'Next Best Action'),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pendingVendors > 0
                              ? '$pendingVendors vendors need collection'
                              : 'Ready for the next sale',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          pendingVendors > 0
                              ? 'Open pending vendors and collect payment.'
                              : 'Start a session or add new inventory.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    pendingVendors > 0
                        ? Icons.account_balance_wallet_outlined
                        : Icons.eco_outlined,
                    color: AppColors.primary,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: pendingVendors > 0 ? onCollectPayment : onAddItem,
                  icon: Icon(
                    pendingVendors > 0
                        ? Icons.currency_rupee
                        : Icons.inventory_2_outlined,
                  ),
                  label: Text(
                    pendingVendors > 0 ? 'Collect Payment' : 'Add Item',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onAddVendor,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Add Vendor'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

class _DashboardErrorCard extends StatelessWidget {
  const _DashboardErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Could not load the control center.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Check the connection and try again.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatefulWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  State<_HeaderIconButton> createState() => _HeaderIconButtonState();
}

class _HeaderIconButtonState extends State<_HeaderIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.92 : 1,
      duration: const Duration(milliseconds: 100),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.control),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.control),
          onTap: widget.onPressed,
          onHighlightChanged: (value) => setState(() => _pressed = value),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(widget.icon, color: AppColors.text),
          ),
        ),
      ),
    );
  }
}
