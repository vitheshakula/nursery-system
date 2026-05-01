import '../../../core/network/api_client.dart';
import '../../../models/auth_response.dart';

class AuthApi {
  const AuthApi(this._apiClient);

  final ApiClient _apiClient;

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final data = await _apiClient.post(
      '/auth/login',
      attachAuth: false,
      body: {
        'email': email,
        'password': password,
      },
    );

    return AuthResponse.fromJson(
      Map<String, dynamic>.from(data as Map<dynamic, dynamic>),
    );
  }
}
