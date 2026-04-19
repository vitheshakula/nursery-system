import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/auth_response.dart';
import '../models/category.dart';
import '../models/payment.dart';
import '../models/plant.dart';
import '../models/session_close_result.dart';
import '../models/session_info.dart';
import '../models/session_summary.dart';
import '../models/vendor.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

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
  bool _hasTriggeredUnauthorized = false;
  void Function()? onUnauthorized;

  set token(String? value) {
    _token = value;
    if (value != null && value.isNotEmpty) {
      _hasTriggeredUnauthorized = false;
    }
  }

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

    return AuthResponse.fromJson(_map(data));
  }

  Future<List<Vendor>> getVendors() async {
    final data = await _request(method: 'GET', path: '/vendors');
    return _list(data).map(Vendor.fromJson).toList();
  }

  Future<Vendor> getVendor(String vendorId) async {
    final data = await _request(method: 'GET', path: '/vendors/$vendorId');
    return Vendor.fromJson(_map(data));
  }

  Future<List<Plant>> getPlants({int limit = 100}) async {
    final data = await _request(method: 'GET', path: '/plants?page=1&limit=$limit');
    return _list(data).map(Plant.fromJson).toList();
  }

  Future<List<Category>> getCategories() async {
    final data = await _request(method: 'GET', path: '/categories');
    return _list(data).map(Category.fromJson).toList();
  }

  Future<Plant> createPlant({
    required String name,
    required String categoryId,
    required double vendorPrice,
    double? retailPrice,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'categoryId': categoryId,
      'vendorPrice': vendorPrice,
    };

    if (retailPrice != null) {
      body['retailPrice'] = retailPrice;
    }

    final data = await _request(
      method: 'POST',
      path: '/plants',
      body: body,
    );

    return Plant.fromJson(_map(data));
  }

  Future<SessionInfo> startSession(String vendorId) async {
    final data = await _request(
      method: 'POST',
      path: '/sessions/start',
      body: {'vendorId': vendorId},
    );
    return SessionInfo.fromJson(_map(data));
  }

  Future<void> submitIssueItems({
    required String sessionId,
    required Map<String, int> quantities,
  }) async {
    await _request(
      method: 'POST',
      path: '/sessions/$sessionId/issue',
      body: {
        'items': _buildItems(quantities),
      },
    );
  }

  Future<void> submitReturnItems({
    required String sessionId,
    required Map<String, int> quantities,
  }) async {
    await _request(
      method: 'POST',
      path: '/sessions/$sessionId/return',
      body: {
        'items': _buildItems(quantities).map((item) {
          return {
            ...item,
            'condition': 'GOOD',
          };
        }).toList(),
      },
    );
  }

  Future<SessionSummary> getSessionSummary(String sessionId) async {
    final data = await _request(
      method: 'GET',
      path: '/sessions/$sessionId/summary',
    );
    return SessionSummary.fromJson(_map(data));
  }

  Future<SessionCloseResult> closeSession(String sessionId) async {
    final data = await _request(
      method: 'POST',
      path: '/sessions/$sessionId/close',
    );
    return SessionCloseResult.fromJson(_map(data));
  }

  Future<List<PaymentRecord>> getVendorPayments(String vendorId) async {
    final data = await _request(
      method: 'GET',
      path: '/payments/vendor/$vendorId',
    );
    return _list(data).map(PaymentRecord.fromJson).toList();
  }

  Future<PaymentRecord> createPayment({
    required String vendorId,
    required double amount,
    required String mode,
    String? sessionId,
  }) async {
    final body = <String, dynamic>{
      'vendorId': vendorId,
      'amount': amount,
      'mode': mode,
    };

    if (sessionId != null && sessionId.isNotEmpty) {
      body['sessionId'] = sessionId;
    }

    final data = await _request(
      method: 'POST',
      path: '/payments',
      body: body,
    );
    return PaymentRecord.fromJson(_map(data));
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
        throw ApiException('Unsupported request method');
    }

    final payload = _decodePayload(response);
    final success = payload['success'] as bool? ?? false;
    if (success) {
      return payload['data'];
    }

    if (response.statusCode == 401 && attachAuth) {
      _token = null;
      if (!_hasTriggeredUnauthorized) {
        _hasTriggeredUnauthorized = true;
        onUnauthorized?.call();
      }
    }

    throw ApiException(
      _friendlyMessage(
        statusCode: response.statusCode,
        path: path,
        serverError: payload['error'] as String?,
      ),
      statusCode: response.statusCode,
    );
  }

  Map<String, dynamic> _decodePayload(http.Response response) {
    if (response.body.isEmpty) {
      return {
        'success': false,
        'error': 'empty_response',
      };
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } on FormatException {
      return {
        'success': false,
        'error': 'invalid_response',
      };
    }

    return {
      'success': false,
      'error': 'invalid_response',
    };
  }

  String _friendlyMessage({
    required int statusCode,
    required String path,
    String? serverError,
  }) {
    final error = (serverError ?? '').toLowerCase();

    if (statusCode == 401) {
      return path.contains('/auth/login')
          ? 'Email or password is incorrect.'
          : 'Please sign in again.';
    }

    if (path.contains('/auth/login')) {
      return 'Unable to sign in right now. Please check your details and try again.';
    }

    if (path.contains('/sessions/') && path.contains('/return')) {
      if (error.contains('exceeds issued')) {
        return 'Return quantity is higher than issued stock.';
      }
      if (error.contains('no issued quantity')) {
        return 'This plant was not issued in the current session.';
      }
      return 'Could not save the return. Please try again.';
    }

    if (path.contains('/sessions/') && path.contains('/issue')) {
      return 'Could not save the issue. Please try again.';
    }

    if (path.contains('/sessions/start')) {
      return 'Could not start the session. Please try again.';
    }

    if (path.contains('/payments')) {
      if (error.contains('exceeds vendor outstanding balance')) {
        return 'Payment amount is higher than the current balance.';
      }
      return 'Could not save the payment. Please try again.';
    }

    if (path.contains('/plants') && statusCode >= 400) {
      return 'Could not load plant data right now.';
    }

    if (path.contains('/vendors')) {
      return 'Could not load vendor information right now.';
    }

    if (statusCode >= 500) {
      return 'Server error. Please try again in a moment.';
    }

    return 'Something went wrong. Please try again.';
  }

  List<Map<String, dynamic>> _buildItems(Map<String, int> quantities) {
    return quantities.entries
        .where((entry) => entry.value > 0)
        .map((entry) => {
              'plantId': entry.key,
              'quantity': entry.value,
            })
        .toList();
  }

  Map<String, dynamic> _map(Object? value) =>
      Map<String, dynamic>.from(value as Map<dynamic, dynamic>);

  List<Map<String, dynamic>> _list(Object? value) {
    final items = value as List<dynamic>? ?? const [];
    return items
        .map((item) => Map<String, dynamic>.from(item as Map<dynamic, dynamic>))
        .toList();
  }
}
