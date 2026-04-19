import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/auth_response.dart';
import '../models/session_action_result.dart';
import '../models/session_info.dart';
import '../models/session_summary.dart';
import '../models/vendor.dart';

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ApiService {
  ApiService({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        baseUrl = baseUrl ??
            const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: 'http://10.0.2.2:3000/api',
            );

  final http.Client _client;
  final String baseUrl;
  String? _token;

  set token(String? value) => _token = value;
  String? get token => _token;

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final data = await _request(
      method: 'POST',
      path: '/auth/login',
      body: {
        'email': email,
        'password': password,
      },
      attachAuth: false,
    );

    return AuthResponse.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<List<Vendor>> getVendors() async {
    final data = await _request(method: 'GET', path: '/vendors');
    return (data as List<dynamic>)
        .map((item) => Vendor.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<SessionInfo> startSession(String vendorId) async {
    final data = await _request(
      method: 'POST',
      path: '/sessions/start',
      body: {'vendorId': vendorId},
    );
    return SessionInfo.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<SessionActionResult> issueItems({
    required String sessionId,
    required String plantId,
    required int quantity,
  }) async {
    final data = await _request(
      method: 'POST',
      path: '/sessions/$sessionId/issue',
      body: {
        'items': [
          {
            'plantId': plantId,
            'quantity': quantity,
          }
        ],
      },
    );
    return SessionActionResult.fromIssueJson(Map<String, dynamic>.from(data as Map));
  }

  Future<SessionActionResult> returnItems({
    required String sessionId,
    required String plantId,
    required int quantity,
    String condition = 'GOOD',
  }) async {
    final data = await _request(
      method: 'POST',
      path: '/sessions/$sessionId/return',
      body: {
        'items': [
          {
            'plantId': plantId,
            'quantity': quantity,
            'condition': condition,
          }
        ],
      },
    );
    return SessionActionResult.fromReturnJson(Map<String, dynamic>.from(data as Map));
  }

  Future<SessionSummary> getSessionSummary(String sessionId) async {
    final data = await _request(
      method: 'GET',
      path: '/sessions/$sessionId/summary',
    );
    return SessionSummary.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<Object?> _request({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    bool attachAuth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (attachAuth && _token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }

    late final http.Response response;
    final encodedBody = body == null ? null : jsonEncode(body);

    switch (method) {
      case 'GET':
        response = await _client.get(uri, headers: headers);
        break;
      case 'POST':
        response = await _client.post(uri, headers: headers, body: encodedBody);
        break;
      default:
        throw ApiException('Unsupported HTTP method: $method');
    }

    if (response.body.isEmpty) {
      throw const ApiException('Empty response from server');
    }

    late final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw ApiException(
        response.statusCode >= 500
            ? 'Server error. Please try again.'
            : 'Invalid response from server',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('Invalid response from server');
    }

    final payload = decoded;
    final success = payload['success'] as bool? ?? false;

    if (!success) {
      throw ApiException(payload['error'] as String? ?? 'Request failed');
    }

    return payload['data'];
  }
}
