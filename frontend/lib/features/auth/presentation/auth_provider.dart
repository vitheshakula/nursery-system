import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/token_storage.dart';
import '../../../core/network/api_client.dart';
import '../../../models/app_user.dart';
import '../../../models/auth_response.dart';
import '../data/auth_api.dart';

enum AuthStatus {
  loading,
  authenticated,
  unauthenticated,
  error,
}

class AuthState {
  const AuthState({
    required this.status,
    this.currentUser,
    this.errorMessage,
  });

  const AuthState.loading() : this(status: AuthStatus.loading);

  const AuthState.unauthenticated() : this(status: AuthStatus.unauthenticated);

  const AuthState.authenticated({
    required AppUser currentUser,
  }) : this(
          status: AuthStatus.authenticated,
          currentUser: currentUser,
        );

  const AuthState.error(String message)
      : this(status: AuthStatus.error, errorMessage: message);

  final AuthStatus status;
  final AppUser? currentUser;
  final String? errorMessage;

  bool get isLoading => status == AuthStatus.loading;
  bool get isAuthenticated => status == AuthStatus.authenticated;
}

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return const TokenStorage();
});

final unauthorizedEventProvider = StateProvider<int>((ref) {
  return 0;
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  return ApiClient(
    tokenStorage: tokenStorage,
    onUnauthorized: () async {
      ref.read(unauthorizedEventProvider.notifier).state++;
    },
  );
});

final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(ref.watch(apiClientProvider));
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    authApi: ref.watch(authApiProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
  );
});

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier({
    required AuthApi authApi,
    required TokenStorage tokenStorage,
  })  : _authApi = authApi,
        _tokenStorage = tokenStorage,
        super(const AuthState.loading());

  final AuthApi _authApi;
  final TokenStorage _tokenStorage;

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    state = const AuthState.loading();

    try {
      final auth = await _authApi.login(email: email, password: password);
      await _tokenStorage.saveToken(auth.accessToken);
      state = AuthState.authenticated(
        currentUser: auth.user,
      );
      return auth;
    } catch (error) {
      state = AuthState.error(error.toString());
      rethrow;
    }
  }

  Future<void> logout() async {
    await _tokenStorage.clearToken();
    state = const AuthState.unauthenticated();
  }

  Future<void> handleUnauthorized() async {
    await _tokenStorage.clearToken();
    state = const AuthState.unauthenticated();
  }

  Future<void> loadTokenOnStartup() async {
    state = const AuthState.loading();

    final token = await _tokenStorage.getToken();
    if (token == null || token.isEmpty) {
      state = const AuthState.unauthenticated();
      return;
    }

    final user = _userFromToken(token);
    if (user == null) {
      await _tokenStorage.clearToken();
      state = const AuthState.unauthenticated();
      return;
    }

    state = AuthState.authenticated(currentUser: user);
  }

  AppUser? _userFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        return null;
      }

      final normalizedPayload = base64Url.normalize(parts[1]);
      final payloadJson = utf8.decode(base64Url.decode(normalizedPayload));
      final payload = jsonDecode(payloadJson);

      if (payload is! Map<String, dynamic>) {
        return null;
      }

      return AppUser.fromJson({
        'id': payload['sub'],
        'name': payload['name'],
        'email': payload['email'],
        'role': payload['role'],
      });
    } on FormatException {
      return null;
    }
  }
}
