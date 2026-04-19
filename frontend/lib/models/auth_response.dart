import 'app_user.dart';

class AuthResponse {
  const AuthResponse({
    required this.accessToken,
    required this.user,
  });

  final String accessToken;
  final AppUser user;

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final user = Map<String, dynamic>.from((json['user'] as Map?) ?? const {});
    return AuthResponse(
      accessToken: json['accessToken'] as String? ?? '',
      user: AppUser.fromJson(user),
    );
  }
}
