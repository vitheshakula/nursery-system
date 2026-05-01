import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/presentation/auth_provider.dart';
import 'models/auth_response.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';

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

    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2E6B3D),
      primary: const Color(0xFF2E6B3D),
      secondary: const Color(0xFFAED581),
      surface: Colors.white,
      brightness: Brightness.light,
    );

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Shiv Raj Nursery',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F6F1),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(fontWeight: FontWeight.w700),
          titleLarge: TextStyle(fontWeight: FontWeight.w700),
          titleMedium: TextStyle(fontWeight: FontWeight.w600),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 3,
          shadowColor: const Color(0x14000000),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          margin: EdgeInsets.zero,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF7F6F1),
          foregroundColor: Color(0xFF183A1D),
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Color(0xFF183A1D),
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF2E6B3D), width: 1.2),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2E6B3D),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            side: const BorderSide(color: Color(0xFF2E6B3D)),
            foregroundColor: const Color(0xFF2E6B3D),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: Colors.white,
          selectedColor: const Color(0xFFDDECCF),
          side: BorderSide.none,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
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
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
