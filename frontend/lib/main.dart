import 'package:flutter/material.dart';

import 'models/auth_response.dart';
import 'models/session_info.dart';
import 'models/vendor.dart';
import 'screens/login_screen.dart';
import 'screens/session_screen.dart';
import 'screens/summary_screen.dart';
import 'screens/vendor_list_screen.dart';
import 'services/api_service.dart';

void main() {
  runApp(const NurseryApp());
}

enum AppScreen {
  login,
  vendors,
  session,
  summary,
}

class NurseryApp extends StatefulWidget {
  const NurseryApp({super.key});

  @override
  State<NurseryApp> createState() => _NurseryAppState();
}

class _NurseryAppState extends State<NurseryApp> {
  final ApiService _apiService = ApiService();

  AppScreen _screen = AppScreen.login;
  AuthResponse? _auth;
  Vendor? _selectedVendor;
  SessionInfo? _activeSession;

  void _handleLogin(AuthResponse auth) {
    _apiService.token = auth.accessToken;
    setState(() {
      _auth = auth;
      _screen = AppScreen.vendors;
    });
  }

  void _logout() {
    _apiService.token = null;
    setState(() {
      _auth = null;
      _selectedVendor = null;
      _activeSession = null;
      _screen = AppScreen.login;
    });
  }

  void _openVendorSession(Vendor vendor, SessionInfo session) {
    setState(() {
      _selectedVendor = vendor;
      _activeSession = session;
      _screen = AppScreen.session;
    });
  }

  void _openSummary(String sessionId) {
    setState(() {
      _activeSession = SessionInfo(
        id: sessionId,
        vendorId: _selectedVendor?.id ?? '',
        status: _activeSession?.status ?? 'ACTIVE',
      );
      _screen = AppScreen.summary;
    });
  }

  void _backToVendors() {
    setState(() {
      _activeSession = null;
      _screen = AppScreen.vendors;
    });
  }

  void _backToSession() {
    setState(() {
      _screen = AppScreen.session;
    });
  }

  @override
  Widget build(BuildContext context) {
    final home = switch (_screen) {
      AppScreen.login => LoginScreen(
          apiService: _apiService,
          onLoginSuccess: _handleLogin,
        ),
      AppScreen.vendors => VendorListScreen(
          apiService: _apiService,
          userName: _auth?.user.name ?? '',
          onSessionStarted: _openVendorSession,
          onLogout: _logout,
        ),
      AppScreen.session => SessionScreen(
          apiService: _apiService,
          vendor: _selectedVendor!,
          initialSession: _activeSession,
          onViewSummary: _openSummary,
          onBack: _backToVendors,
        ),
      AppScreen.summary => SummaryScreen(
          apiService: _apiService,
          sessionId: _activeSession!.id,
          onBack: _backToSession,
        ),
    };

    return MaterialApp(
      title: 'Nursery Frontend',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
        ),
      ),
      home: home,
    );
  }
}
