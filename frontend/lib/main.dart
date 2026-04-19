import 'package:flutter/material.dart';

import 'models/app_user.dart';
import 'models/auth_response.dart';
import 'screens/login_screen.dart';
import 'screens/vendor_list_screen.dart';
import 'services/api_service.dart';

void main() {
  runApp(const NurseryApp());
}

class NurseryApp extends StatefulWidget {
  const NurseryApp({super.key});

  @override
  State<NurseryApp> createState() => _NurseryAppState();
}

class _NurseryAppState extends State<NurseryApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final ApiService _apiService;
  AppUser? _currentUser;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();
    _apiService.onUnauthorized = _handleUnauthorized;
  }

  void _handleLogin(AuthResponse auth) {
    _apiService.token = auth.accessToken;
    setState(() {
      _currentUser = auth.user;
    });

    _navigatorKey.currentState?.pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => VendorListScreen(
          apiService: _apiService,
          currentUser: auth.user,
          onLogout: () => _logout(),
        ),
      ),
    );
  }

  void _handleUnauthorized() {
    _logout(showMessage: true);
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
              content: Text('Your session expired. Please sign in again.'),
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Nursery System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        scaffoldBackgroundColor: const Color(0xFFF6F7F3),
        useMaterial3: true,
        cardTheme: const CardTheme(
          margin: EdgeInsets.zero,
          elevation: 0,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
        ),
      ),
      home: _currentUser == null
          ? LoginScreen(
              apiService: _apiService,
              onLoginSuccess: _handleLogin,
            )
          : VendorListScreen(
              apiService: _apiService,
              currentUser: _currentUser!,
              onLogout: () => _logout(),
            ),
    );
  }
}
