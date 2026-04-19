import 'package:flutter/material.dart';

import 'models/app_user.dart';
import 'models/auth_response.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';

void main() {
  runApp(const ShivRajNurseryApp());
}

class ShivRajNurseryApp extends StatefulWidget {
  const ShivRajNurseryApp({super.key});

  @override
  State<ShivRajNurseryApp> createState() => _ShivRajNurseryAppState();
}

class _ShivRajNurseryAppState extends State<ShivRajNurseryApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final ApiService _apiService;
  AppUser? _currentUser;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();
    _apiService.onUnauthorized = () => _logout(showMessage: true);
  }

  void _handleLogin(AuthResponse auth) {
    _apiService.token = auth.accessToken;
    setState(() {
      _currentUser = auth.user;
    });

    _navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => HomeShell(
          apiService: _apiService,
          currentUser: auth.user,
          onLogout: () => _logout(),
        ),
      ),
      (route) => false,
    );
  }

  void _logout({bool showMessage = false}) {
    _apiService.token = null;
    setState(() {
      _currentUser = null;
    });

    _navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(
          apiService: _apiService,
          onLoginSuccess: _handleLogin,
        ),
      ),
      (route) => false,
    );

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
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFFF7F6F1),
          foregroundColor: const Color(0xFF183A1D),
          elevation: 0,
          centerTitle: false,
          titleTextStyle: const TextStyle(
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
      home: _currentUser == null
          ? LoginScreen(
              apiService: _apiService,
              onLoginSuccess: _handleLogin,
            )
          : HomeShell(
              apiService: _apiService,
              currentUser: _currentUser!,
              onLogout: () => _logout(),
            ),
    );
  }
}
