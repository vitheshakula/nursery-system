import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/presentation/auth_provider.dart';
import 'models/auth_response.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'shared/theme/app_theme.dart';
import 'shared/widgets/brand_logo.dart';

void main() {
  runApp(const ProviderScope(child: ShivRajNurseryApp()));
}

class ShivRajNurseryApp extends ConsumerStatefulWidget {
  const ShivRajNurseryApp({super.key});

  @override
  ConsumerState<ShivRajNurseryApp> createState() => _ShivRajNurseryAppState();
}

class _ShivRajNurseryAppState extends ConsumerState<ShivRajNurseryApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  bool _loginNavigationScheduled = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(authProvider.notifier).loadTokenOnStartup(),
    );
  }

  void _handleLogin(AuthResponse auth) {
    _navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => HomeShell(
          currentUser: auth.user,
          onLogout: () => _logout(),
        ),
      ),
      (route) => false,
    );
  }

  Future<void> _logout({bool showMessage = false}) async {
    await ref.read(authProvider.notifier).logout();

    if (showMessage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = _navigatorKey.currentContext;
        if (context != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Session expired. Please login again.')),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      final wasAuthenticated = previous?.isAuthenticated ?? false;
      if (!wasAuthenticated || next.status != AuthStatus.unauthenticated) {
        return;
      }

      if (_loginNavigationScheduled) {
        return;
      }

      _loginNavigationScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => LoginScreen(
              onLoginSuccess: _handleLogin,
            ),
          ),
          (route) => false,
        );
        _loginNavigationScheduled = false;
      });
    });

    ref.listen<int>(unauthorizedEventProvider, (previous, next) {
      if (previous == null || next == previous) {
        return;
      }

      ref.read(authProvider.notifier).handleUnauthorized();
    });

    final authState = ref.watch(authProvider);
    final currentUser = authState.currentUser;

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Shivraj Nursery',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: authState.isLoading
          ? const _StartupLoadingScreen()
          : currentUser == null
              ? LoginScreen(
                  onLoginSuccess: _handleLogin,
                )
              : HomeShell(
                  currentUser: currentUser,
                  onLogout: () => _logout(),
                ),
    );
  }
}

class _StartupLoadingScreen extends StatelessWidget {
  const _StartupLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: _BrandedSplashBody(),
    );
  }
}

class _BrandedSplashBody extends StatelessWidget {
  const _BrandedSplashBody();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFEAF3E8),
            Color(0xFFF7F8FA),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 10 * (1 - value)),
                child: child,
              ),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandLogo(size: 84),
              const SizedBox(height: 22),
              Text(
                'Shivraj Nursery',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                'Track. Sell. Grow.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
