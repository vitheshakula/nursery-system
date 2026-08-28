import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/payments/data/payment_api.dart';
import '../features/sessions/application/session_controller.dart';
import '../features/vendors/presentation/vendor_provider.dart';
import '../models/payment.dart';
import '../models/vendor.dart';
import '../models/vendor_session.dart';
import '../shared/theme/app_theme.dart';
import '../shared/widgets/app_card.dart';
import '../utils/formatters.dart';
import 'session_screen.dart';
import 'summary_screen.dart';

const _backgroundColor = AppColors.background;
const _accentColor = AppColors.primary;
const _softAccentColor = AppColors.primarySoft;
const _textColor = AppColors.text;
const _mutedTextColor = AppColors.muted;

class VendorDetailScreen extends ConsumerStatefulWidget {
  const VendorDetailScreen({
    super.key,
    required this.vendor,
  });

  final Vendor vendor;

  @override
  ConsumerState<VendorDetailScreen> createState() => _VendorDetailScreenState();
}

class _VendorDetailScreenState extends ConsumerState<VendorDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late Vendor _vendor;
  bool _isLoadingVendor = false;
  bool _isStarting = false;
  bool _isSettling = false;
  String? _vendorError;

  @override
  void initState() {
    super.initState();
    _vendor = widget.vendor;
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(_refreshVendor);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshVendor() async {
    setState(() {
      _isLoadingVendor = true;
      _vendorError = null;
    });

    try {
      final vendor = await ref.read(vendorApiProvider).getVendor(_vendor.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _vendor = vendor;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _vendorError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingVendor = false;
        });
      }
    }
  }

  Future<void> _refreshAll() async {
    ref.invalidate(sessionsProvider(_vendor.id));
    ref.invalidate(paymentsProvider(_vendor.id));
    await Future.wait([
      _refreshVendor(),
      ref.read(sessionsProvider(_vendor.id).future),
      ref.read(paymentsProvider(_vendor.id).future),
    ]);
  }

  Future<void> _startSession() async {
    setState(() {
      _isStarting = true;
    });

    try {
      final session =
          await ref.read(sessionApiProvider).startSession(_vendor.id);
      if (!mounted) {
        return;
      }

      final changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => SessionScreen(
            vendor: _vendor,
            session: session,
          ),
        ),
      );

      if (changed == true) {
        await _refreshAll();
      }
    } catch (error) {
      _showMessage(error.toString());
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
        builder: (_) => SummaryScreen(sessionId: session.id),
      ),
    );
  }

  Future<void> _collectPayment({double? amount}) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CollectPaymentScreen(
          vendor: _vendor,
          initialAmount: amount ?? _vendor.balance,
        ),
      ),
    );

    if (changed == true) {
      await _refreshAll();
      if (mounted) {
        _showMessage('Payment collected.');
      }
    }
  }

  Future<void> _settleFullAmount() async {
    if (_vendor.balance <= 0) {
      _showMessage('No pending balance to settle.');
      return;
    }

    final method = await _choosePaymentMethod();
    if (method == null) {
      return;
    }

    setState(() {
      _isSettling = true;
    });

    try {
      await ref.read(paymentApiProvider).createPayment(
            vendorId: _vendor.id,
            amount: _vendor.balance,
            mode: method,
          );
      await _refreshAll();
      if (mounted) {
        _showMessage('Full pending amount settled.');
      }
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isSettling = false;
        });
      }
    }
  }

  Future<String?> _choosePaymentMethod() {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Settle full amount',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: _textColor,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose how ${formatCurrency(_vendor.balance)} was received.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _mutedTextColor,
                      ),
                ),
                const SizedBox(height: 16),
                _MethodOption(
                  label: 'Cash',
                  icon: Icons.payments_outlined,
                  onTap: () => Navigator.of(context).pop('CASH'),
                ),
                const SizedBox(height: 10),
                _MethodOption(
                  label: 'UPI',
                  icon: Icons.qr_code_2_outlined,
                  onTap: () => Navigator.of(context).pop('UPI'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final sessionsValue = ref.watch(sessionsProvider(_vendor.id));
    final paymentsValue = ref.watch(paymentsProvider(_vendor.id));

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Vendor Details'),
        backgroundColor: _backgroundColor,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refreshAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isStarting ? null : _startSession,
        backgroundColor: _accentColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.play_arrow),
        label: Text(_isStarting ? 'Starting...' : 'Start Session'),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            if (_vendorError != null) ...[
              _InlineMessage(message: _vendorError!, onRetry: _refreshVendor),
              const SizedBox(height: 12),
            ],
            _HeaderCard(vendor: _vendor, isRefreshing: _isLoadingVendor),
            const SizedBox(height: 14),
            sessionsValue.when(
              data: (sessions) => _TodayCard(
                activeSession: _activeSession(sessions),
                onOpenSession: _openSessionSummary,
              ),
              loading: () => const _LoadingCard(title: 'Today'),
              error: (error, _) => _InlineMessage(
                message: error.toString(),
                onRetry: () => ref.invalidate(sessionsProvider(_vendor.id)),
              ),
            ),
            const SizedBox(height: 14),
            _ActionButtons(
              canSettle: _vendor.balance > 0,
              isSettling: _isSettling,
              onCollectPayment: () => _collectPayment(),
              onSettleFullAmount: _settleFullAmount,
            ),
            const SizedBox(height: 22),
            Text(
              'History',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: _textColor,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            AppCard(
              radius: 12,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    labelColor: _accentColor,
                    unselectedLabelColor: _mutedTextColor,
                    indicatorColor: _accentColor,
                    tabs: const [
                      Tab(text: 'Sessions'),
                      Tab(text: 'Payments'),
                    ],
                  ),
                  SizedBox(
                    height: _historyHeight(context),
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        sessionsValue.when(
                          data: (sessions) => _SessionsTab(
                            sessions: sessions,
                            onOpenSession: _openSessionSummary,
                          ),
                          loading: () => const _CenteredProgress(),
                          error: (error, _) =>
                              _CenteredMessage(message: error.toString()),
                        ),
                        paymentsValue.when(
                          data: (payments) => _PaymentsTab(payments: payments),
                          loading: () => const _CenteredProgress(),
                          error: (error, _) =>
                              _CenteredMessage(message: error.toString()),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  VendorSession? _activeSession(List<VendorSession> sessions) {
    for (final session in sessions) {
      if (_isOpenStatus(session.status)) {
        return session;
      }
    }
    return null;
  }

  double _historyHeight(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return height < 720 ? 380 : 480;
  }
}

class CollectPaymentScreen extends ConsumerStatefulWidget {
  const CollectPaymentScreen({
    super.key,
    required this.vendor,
    required this.initialAmount,
  });

  final Vendor vendor;
  final double initialAmount;

  @override
  ConsumerState<CollectPaymentScreen> createState() =>
      _CollectPaymentScreenState();
}

class _CollectPaymentScreenState extends ConsumerState<CollectPaymentScreen> {
  late final TextEditingController _amountController;
  String _method = 'CASH';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.initialAmount.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _confirmPayment() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      _showMessage('Enter a valid payment amount.');
      return;
    }

    if (amount > widget.vendor.balance) {
      _showMessage('Payment cannot be more than pending balance.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await ref.read(paymentApiProvider).createPayment(
            vendorId: widget.vendor.id,
            amount: amount,
            mode: _method,
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
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Collect Payment'),
        backgroundColor: _backgroundColor,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppCard(
              radius: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.vendor.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: _textColor,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Current pending balance',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _mutedTextColor,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatCurrency(widget.vendor.balance),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: _accentColor,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              radius: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixIcon: Icon(Icons.currency_rupee),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Method',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: _textColor,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'CASH',
                        label: Text('Cash'),
                        icon: Icon(Icons.payments_outlined),
                      ),
                      ButtonSegment(
                        value: 'UPI',
                        label: Text('UPI'),
                        icon: Icon(Icons.qr_code_2_outlined),
                      ),
                    ],
                    selected: {_method},
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: _softAccentColor,
                      selectedForegroundColor: _accentColor,
                    ),
                    onSelectionChanged: (selection) {
                      setState(() {
                        _method = selection.first;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _confirmPayment,
                icon: _isSaving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(_isSaving ? 'Saving...' : 'Confirm Payment'),
                style: FilledButton.styleFrom(
                  backgroundColor: _accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.vendor,
    required this.isRefreshing,
  });

  final Vendor vendor;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 12,
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: _softAccentColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.storefront_outlined, color: _accentColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vendor.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: _textColor,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  vendor.phone,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _mutedTextColor,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Total Pending',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _mutedTextColor,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                formatCurrency(vendor.balance),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: _accentColor,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              if (isRefreshing)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.activeSession,
    required this.onOpenSession,
  });

  final VendorSession? activeSession;
  final ValueChanged<VendorSession> onOpenSession;

  @override
  Widget build(BuildContext context) {
    final session = activeSession;

    return AppCard(
      radius: 12,
      onTap: session == null ? null : () => onOpenSession(session),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            title: 'Today',
            trailing: session == null
                ? null
                : const Icon(Icons.chevron_right, color: _mutedTextColor),
          ),
          const SizedBox(height: 14),
          if (session == null)
            Text(
              'No active session',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: _mutedTextColor,
                    fontWeight: FontWeight.w600,
                  ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: _CompactMetric(
                    label: 'Issued',
                    value: session.totalIssued.toString(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CompactMetric(
                    label: 'Returned',
                    value: session.totalReturned.toString(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CompactMetric(
                    label: 'Balance',
                    value: session.totalSold.toString(),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.canSettle,
    required this.isSettling,
    required this.onCollectPayment,
    required this.onSettleFullAmount,
  });

  final bool canSettle;
  final bool isSettling;
  final VoidCallback onCollectPayment;
  final VoidCallback onSettleFullAmount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 420;
        final collectButton = _ActionButton(
          label: 'Collect Payment',
          icon: Icons.account_balance_wallet_outlined,
          onPressed: onCollectPayment,
          filled: true,
        );
        final settleButton = _ActionButton(
          label: isSettling ? 'Settling...' : 'Settle Full Amount',
          icon: Icons.done_all_outlined,
          onPressed: canSettle && !isSettling ? onSettleFullAmount : null,
          filled: false,
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              collectButton,
              const SizedBox(height: 10),
              settleButton,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: collectButton),
            const SizedBox(width: 12),
            Expanded(child: settleButton),
          ],
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.filled,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 19),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    return SizedBox(
      height: 48,
      child: filled
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.white,
                shape: shape,
              ),
              child: child,
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: _accentColor,
                side: const BorderSide(color: Color(0xFFB8D0B3)),
                shape: shape,
              ),
              child: child,
            ),
    );
  }
}

class _SessionsTab extends StatelessWidget {
  const _SessionsTab({
    required this.sessions,
    required this.onOpenSession,
  });

  final List<VendorSession> sessions;
  final ValueChanged<VendorSession> onOpenSession;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const _CenteredMessage(message: 'No sessions yet.');
    }

    final groups = _groupByMonth<VendorSession>(
      sessions,
      (session) => session.closedAt ?? session.createdAt,
    );

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
      itemCount: groups.length,
      itemBuilder: (context, groupIndex) {
        final group = groups[groupIndex];
        return _MonthSection(
          title: group.label,
          children: [
            for (final session in group.items)
              _HistoryItem(
                onTap: () => onOpenSession(session),
                leading: Icon(
                  _isOpenStatus(session.status)
                      ? Icons.play_circle_outline
                      : Icons.check_circle_outline,
                  color: _accentColor,
                ),
                title: formatDateOnly(session.closedAt ?? session.createdAt),
                subtitle:
                    'Issued ${session.totalIssued}  Returned ${session.totalReturned}',
                trailingTitle: formatCurrency(session.totalBill),
                trailingSubtitle: _displayStatus(session.status),
              ),
          ],
        );
      },
    );
  }
}

class _PaymentsTab extends StatelessWidget {
  const _PaymentsTab({
    required this.payments,
  });

  final List<PaymentRecord> payments;

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) {
      return const _CenteredMessage(message: 'No payments yet.');
    }

    final groups = _groupByMonth<PaymentRecord>(
      payments,
      (payment) => payment.createdAt,
    );

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
      itemCount: groups.length,
      itemBuilder: (context, groupIndex) {
        final group = groups[groupIndex];
        return _MonthSection(
          title: group.label,
          children: [
            for (final payment in group.items)
              _HistoryItem(
                leading: Icon(
                  payment.mode == 'UPI'
                      ? Icons.qr_code_2_outlined
                      : Icons.payments_outlined,
                  color: _accentColor,
                ),
                title: formatDateOnly(payment.createdAt),
                subtitle: _displayMethod(payment.mode),
                trailingTitle: formatCurrency(payment.amount),
                trailingSubtitle: 'Payment',
              ),
          ],
        );
      },
    );
  }
}

class _MonthGroup<T> {
  const _MonthGroup({
    required this.label,
    required this.items,
  });

  final String label;
  final List<T> items;
}

List<_MonthGroup<T>> _groupByMonth<T>(
  List<T> items,
  DateTime? Function(T item) getDate,
) {
  final grouped = <String, List<T>>{};
  for (final item in items) {
    final date = getDate(item)?.toLocal();
    final label =
        date == null ? 'Unknown' : '${_monthName(date.month)} ${date.year}';
    grouped.putIfAbsent(label, () => <T>[]).add(item);
  }

  return grouped.entries
      .map((entry) => _MonthGroup(label: entry.key, items: entry.value))
      .toList();
}

class _MonthSection extends StatelessWidget {
  const _MonthSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: _mutedTextColor,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  const _HistoryItem({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailingTitle,
    required this.trailingSubtitle,
    this.onTap,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final String trailingTitle;
  final String trailingSubtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _softAccentColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: leading,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: _textColor,
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: _mutedTextColor,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      trailingTitle,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: _textColor,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      trailingSubtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _mutedTextColor,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactMetric extends StatelessWidget {
  const _CompactMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: _textColor,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _mutedTextColor,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    this.trailing,
  });

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _textColor,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: title),
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
        ],
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 12,
      color: AppColors.warning.withValues(alpha: 0.12),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.warning,
                  ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }
}

class _CenteredProgress extends StatelessWidget {
  const _CenteredProgress();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: _mutedTextColor,
              ),
        ),
      ),
    );
  }
}

class _MethodOption extends StatelessWidget {
  const _MethodOption({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _backgroundColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: _accentColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: _textColor,
                      ),
                ),
              ),
              const Icon(Icons.chevron_right, color: _mutedTextColor),
            ],
          ),
        ),
      ),
    );
  }
}

String formatDateOnly(DateTime? value) {
  if (value == null) {
    return 'Unknown date';
  }

  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}

String _monthName(int month) {
  const names = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return names[(month - 1).clamp(0, 11)];
}

bool _isOpenStatus(String status) {
  final normalized = status.toUpperCase();
  return normalized == 'ACTIVE' || normalized == 'OPEN';
}

String _displayStatus(String status) {
  return _isOpenStatus(status) ? 'Open' : 'Closed';
}

String _displayMethod(String mode) {
  return mode.toUpperCase() == 'UPI' ? 'UPI' : 'Cash';
}
