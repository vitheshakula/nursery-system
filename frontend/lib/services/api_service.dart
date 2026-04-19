import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/auth_response.dart';
import '../models/category.dart';
import '../models/dashboard_stats.dart';
import '../models/item.dart';
import '../models/payment.dart';
import '../models/session_close_result.dart';
import '../models/session_info.dart';
import '../models/session_summary.dart';
import '../models/vendor.dart';
import '../models/vendor_session.dart';

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
  bool _unauthorizedHandled = false;
  void Function()? onUnauthorized;

  set token(String? value) {
    _token = value;
    if (value != null && value.isNotEmpty) {
      _unauthorizedHandled = false;
    }
  }

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

  Future<DashboardStats> getDashboardStats() async {
    final data = await _request(method: 'GET', path: '/analytics/dashboard');
    return DashboardStats.fromJson(_map(data));
  }

  Future<List<Vendor>> getVendors() async {
    final data = await _request(method: 'GET', path: '/vendors');
    return _list(data).map(Vendor.fromJson).toList();
  }

  Future<Vendor> getVendor(String vendorId) async {
    final data = await _request(method: 'GET', path: '/vendors/$vendorId');
    return Vendor.fromJson(_map(data));
  }

  Future<Vendor> createVendor({
    required String name,
    required String phone,
  }) async {
    final data = await _request(
      method: 'POST',
      path: '/vendors',
      body: {
        'name': name,
        'phone': phone,
      },
    );
    return Vendor.fromJson(_map(data));
  }

  Future<Vendor> updateVendor({
    required String vendorId,
    required String name,
    required String phone,
  }) async {
    final data = await _request(
      method: 'PUT',
      path: '/vendors/$vendorId',
      body: {
        'name': name,
        'phone': phone,
      },
    );
    return Vendor.fromJson(_map(data));
  }

  Future<void> deleteVendor(String vendorId) async {
    await _request(method: 'DELETE', path: '/vendors/$vendorId');
  }

  Future<List<VendorSession>> getVendorSessions(String vendorId) async {
    final data = await _request(method: 'GET', path: '/vendors/$vendorId/sessions');
    return _list(data).map(VendorSession.fromJson).toList();
  }

  Future<List<Category>> getCategories() async {
    final data = await _request(method: 'GET', path: '/categories');
    return _list(data).map(Category.fromJson).toList();
  }

  Future<Category> createCategory(String name) async {
    final data = await _request(
      method: 'POST',
      path: '/categories',
      body: {'name': name},
    );
    return Category.fromJson(_map(data));
  }

  Future<List<Item>> getItems({int limit = 200}) async {
    final data = await _request(method: 'GET', path: '/plants?page=1&limit=$limit');
    return _list(data).map(Item.fromJson).toList();
  }

  Future<Item> createItem({
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
    return Item.fromJson(_map(data));
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
      body: {'items': _buildItems(quantities)},
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
        'items': _buildItems(quantities)
            .map((item) => {
                  ...item,
                  'condition': 'GOOD',
                })
            .toList(),
      },
    );
  }

  Future<SessionSummary> getSessionSummary(String sessionId) async {
    final data = await _request(method: 'GET', path: '/sessions/$sessionId/summary');
    return SessionSummary.fromJson(_map(data));
  }

  Future<SessionCloseResult> closeSession(String sessionId) async {
    final data = await _request(method: 'POST', path: '/sessions/$sessionId/close');
    return SessionCloseResult.fromJson(_map(data));
  }

  Future<List<PaymentRecord>> getVendorPayments(String vendorId) async {
    final data = await _request(method: 'GET', path: '/payments/vendor/$vendorId');
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

    final data = await _request(method: 'POST', path: '/payments', body: body);
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
      case 'PUT':
        response = await _client.put(uri, headers: headers, body: encodedBody);
        break;
      case 'DELETE':
        response = await _client.delete(uri, headers: headers);
        break;
      default:
        throw const ApiException('Request method not supported.');
    }

    final payload = _decodePayload(response);
    if ((payload['success'] as bool?) == true) {
      return payload['data'];
    }

    if (response.statusCode == 401 && attachAuth && !_unauthorizedHandled) {
      _unauthorizedHandled = true;
      _token = null;
      onUnauthorized?.call();
    }

    throw ApiException(
      _messageFor(
        method: method,
        path: path,
        statusCode: response.statusCode,
        serverError: payload['error'] as String?,
      ),
      statusCode: response.statusCode,
    );
  }

  Map<String, dynamic> _decodePayload(http.Response response) {
    if (response.body.isEmpty) {
      return {'success': false, 'error': 'empty_response'};
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } on FormatException {
      return {'success': false, 'error': 'invalid_response'};
    }

    return {'success': false, 'error': 'invalid_response'};
  }

  String _messageFor({
    required String method,
    required String path,
    required int statusCode,
    String? serverError,
  }) {
    final error = (serverError ?? '').toLowerCase();

    if (statusCode == 401) {
      return path.contains('/auth/login')
          ? 'Wrong email or password.'
          : 'Please login again.';
    }
    if (path.contains('/vendors') && statusCode == 404) {
      return 'Vendor not found.';
    }
    if (path.contains('/vendors') && path.contains('/sessions')) {
      return 'Could not load session history.';
    }
    if (path.contains('/vendors') && error.contains('cannot be deleted')) {
      return 'This vendor already has history and cannot be deleted.';
    }
    if (path.contains('/vendors')) {
      return method == 'GET' ? 'Could not load vendors right now.' : 'Could not save vendor details.';
    }
    if (path.contains('/categories')) {
      return method == 'GET' ? 'Could not load categories right now.' : 'Could not save category right now.';
    }
    if (path.contains('/plants')) {
      return method == 'GET' ? 'Could not load items right now.' : 'Could not save item right now.';
    }
    if (path.contains('/sessions/start')) {
      return 'Could not start session.';
    }
    if (path.contains('/sessions/') && path.contains('/issue')) {
      return 'Could not save issued items.';
    }
    if (path.contains('/sessions/') && path.contains('/return')) {
      if (error.contains('exceeds issued')) {
        return 'Returned quantity cannot be more than issued quantity.';
      }
      return 'Could not save returned items.';
    }
    if (path.contains('/sessions/') && path.contains('/close')) {
      return 'Could not close session.';
    }
    if (path.contains('/payments') && error.contains('exceeds vendor outstanding balance')) {
      return 'Payment is more than the vendor balance.';
    }
    if (path.contains('/payments')) {
      return 'Could not save payment.';
    }
    if (path.contains('/analytics')) {
      return 'Could not load dashboard.';
    }
    if (statusCode >= 500) {
      return 'Server issue. Please try again.';
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
