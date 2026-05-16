import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/sessions/application/session_controller.dart';
import '../features/vendors/presentation/vendor_provider.dart';
import '../models/active_session.dart';
import '../models/session_info.dart';
import '../models/vendor.dart';
import '../shared/theme/app_theme.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/empty_state_widget.dart';
import '../utils/formatters.dart';
import 'session_screen.dart';

const _sessionsBackground = AppColors.background;
const _sessionsAccent = AppColors.primary;
const _sessionsSoftAccent = AppColors.primarySoft;
const _sessionsText = AppColors.text;
const _sessionsMuted = AppColors.muted;

class SessionsTabScreen extends ConsumerWidget {
  const SessionsTabScreen({super.key});

  Future<void> _openActiveSession(
    BuildContext context,
    WidgetRef ref,
    ActiveSession activeSession,
  ) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SessionScreen(
          vendor: activeSession.toVendor(),
          session: activeSession.toSessionInfo(),
        ),
      ),
    );

    if (changed == true) {
      ref.invalidate(activeSessionsProvider);
      ref.invalidate(vendorProvider);
    }
  }

  Future<void> _startSession(BuildContext context, WidgetRef ref) async {
    final result = await Navigator.of(context).push<_SessionStartResult>(
      MaterialPageRoute(builder: (_) => const VendorSelectionScreen()),
    );

    if (result == null || !context.mounted) {
      return;
    }

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SessionScreen(
          vendor: result.vendor,
          session: result.session,
        ),
      ),
    );

    ref.invalidate(activeSessionsProvider);
    ref.invalidate(vendorProvider);

    if (changed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session closed.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSessions = ref.watch(activeSessionsProvider);

    return Scaffold(
      backgroundColor: _sessionsBackground,
      appBar: AppBar(
        title: const Text('Sessions'),
        backgroundColor: _sessionsBackground,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(activeSessionsProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: activeSessions.when(
        loading: () => const _SessionsLoadingState(),
        error: (error, _) => _SessionsRefreshShell(
          onRefresh: () async {
            ref.invalidate(activeSessionsProvider);
            await ref.read(activeSessionsProvider.future);
          },
          child: _ErrorCard(
            message: error.toString(),
            onRetry: () => ref.invalidate(activeSessionsProvider),
          ),
        ),
        data: (sessions) {
          if (sessions.isEmpty) {
            return _SessionsRefreshShell(
              onRefresh: () async {
                ref.invalidate(activeSessionsProvider);
                await ref.read(activeSessionsProvider.future);
              },
              child: EmptyStateWidget(
                title: 'No active sessions',
                message: "Start a session to track today's activity",
                icon: Icons.energy_savings_leaf_outlined,
                actionLabel: 'Start Session',
                onAction: () => _startSession(context, ref),
              ),
            );
          }

          return SessionsList(
            sessions: sessions,
            onRefresh: () async {
              ref.invalidate(activeSessionsProvider);
              await ref.read(activeSessionsProvider.future);
            },
            onStartSession: () => _startSession(context, ref),
            onOpenSession: (session) =>
                _openActiveSession(context, ref, session),
          );
        },
      ),
    );
  }
}

class _SessionsLoadingState extends StatelessWidget {
  const _SessionsLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _SessionsRefreshShell extends StatelessWidget {
  const _SessionsRefreshShell({
    required this.child,
    required this.onRefresh,
  });

  final Widget child;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [child],
      ),
    );
  }
}

class VendorSelectionScreen extends ConsumerStatefulWidget {
  const VendorSelectionScreen({super.key});

  @override
  ConsumerState<VendorSelectionScreen> createState() =>
      _VendorSelectionScreenState();
}

class _VendorSelectionScreenState extends ConsumerState<VendorSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _startingVendorId;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(vendorProvider.notifier).fetchVendors();
      ref.invalidate(activeSessionsProvider);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _selectVendor(Vendor vendor, ActiveSession? active) async {
    if (_startingVendorId != null) {
      return;
    }

    if (active != null) {
      Navigator.of(context).pop(
        _SessionStartResult(
            vendor: active.toVendor(), session: active.toSessionInfo()),
      );
      return;
    }

    setState(() {
      _startingVendorId = vendor.id;
    });

    try {
      final session = await ref.read(createSessionProvider).create(vendor.id);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(
        _SessionStartResult(vendor: vendor, session: session),
      );
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

  @override
  Widget build(BuildContext context) {
    final vendorState = ref.watch(vendorProvider);
    final activeSessions = ref.watch(activeSessionsProvider).valueOrNull ??
        const <ActiveSession>[];
    final activeByVendor = {
      for (final session in activeSessions) session.vendorId: session,
    };
    final query = _searchController.text.trim().toLowerCase();
    final vendors = vendorState.vendors.where((vendor) {
      return query.isEmpty ||
          vendor.name.toLowerCase().contains(query) ||
          vendor.phone.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: _sessionsBackground,
      appBar: AppBar(
        title: const Text('Select Vendor'),
        backgroundColor: _sessionsBackground,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search vendor',
              ),
            ),
          ),
          Expanded(
            child: vendorState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : vendorState.errorMessage != null
                    ? _CenteredMessage(message: vendorState.errorMessage!)
                    : vendors.isEmpty
                        ? const _CenteredMessage(message: 'No vendors found.')
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: vendors.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final vendor = vendors[index];
                              final active = activeByVendor[vendor.id];
                              final isStarting = _startingVendorId == vendor.id;

                              return _VendorPickCard(
                                vendor: vendor,
                                activeSession: active,
                                isStarting: isStarting,
                                onTap: () => _selectVendor(vendor, active),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _SessionStartResult {
  const _SessionStartResult({
    required this.vendor,
    required this.session,
  });

  final Vendor vendor;
  final SessionInfo session;
}

class _TopSection extends StatelessWidget {
  const _TopSection({
    required this.count,
    required this.onStartSession,
  });

  final int count;
  final VoidCallback onStartSession;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 12,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Active Sessions',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: _sessionsText,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count in progress',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _sessionsMuted,
                      ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: onStartSession,
            icon: const Icon(Icons.add),
            label: const Text('Start'),
            style: FilledButton.styleFrom(
              backgroundColor: _sessionsAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SessionsList extends StatelessWidget {
  const SessionsList({
    super.key,
    required this.sessions,
    required this.onRefresh,
    required this.onStartSession,
    required this.onOpenSession,
  });

  final List<ActiveSession> sessions;
  final Future<void> Function() onRefresh;
  final VoidCallback onStartSession;
  final ValueChanged<ActiveSession> onOpenSession;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: sessions.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _TopSection(
              count: sessions.length,
              onStartSession: onStartSession,
            );
          }

          final session = sessions[index - 1];
          return SessionCard(
            session: session,
            onTap: () => onOpenSession(session),
          );
        },
      ),
    );
  }
}

class SessionCard extends StatefulWidget {
  const SessionCard({
    super.key,
    required this.session,
    required this.onTap,
  });

  final ActiveSession session;
  final VoidCallback onTap;

  @override
  State<SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<SessionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.98 : 1,
      duration: const Duration(milliseconds: 100),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x16000000),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: const Color(0xFFFBFEFA),
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: (value) => setState(() => _pressed = value),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _sessionsSoftAccent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.storefront_outlined,
                      color: _sessionsAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.session.vendorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: _sessionsText,
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Current balance ${formatCurrency(widget.session.totalBill)}',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: _sessionsMuted,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        const _StatusPill(label: 'In Progress'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.chevron_right, color: _sessionsMuted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VendorPickCard extends StatelessWidget {
  const _VendorPickCard({
    required this.vendor,
    required this.activeSession,
    required this.isStarting,
    required this.onTap,
  });

  final Vendor vendor;
  final ActiveSession? activeSession;
  final bool isStarting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 12,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: activeSession == null
                  ? const Color(0xFFF0F2F1)
                  : _sessionsSoftAccent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              activeSession == null
                  ? Icons.person_outline
                  : Icons.play_circle_outline,
              color: activeSession == null ? _sessionsMuted : _sessionsAccent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vendor.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: _sessionsText,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  activeSession == null
                      ? 'Pending ${formatCurrency(vendor.balance)}'
                      : 'Session already in progress',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _sessionsMuted,
                      ),
                ),
              ],
            ),
          ),
          if (isStarting)
            const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              activeSession == null ? Icons.add : Icons.chevron_right,
              color: _sessionsAccent,
            ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _sessionsSoftAccent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _sessionsAccent,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Could not load sessions.',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(message),
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

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.message});

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
                color: _sessionsMuted,
              ),
        ),
      ),
    );
  }
}
