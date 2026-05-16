import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../auth/token_storage.dart';
import 'api_exception.dart';

typedef TokenProvider = Future<String?> Function();
typedef UnauthorizedCallback = Future<void> Function();

String createOperationId() {
  final random = Random.secure().nextInt(1 << 32);
  return '${DateTime.now().microsecondsSinceEpoch}-$random';
}

class ApiClient {
  ApiClient({
    http.Client? client,
    String? baseUrl,
    TokenStorage? tokenStorage,
    TokenProvider? tokenProvider,
    UnauthorizedCallback? onUnauthorized,
  })  : _client = client ?? http.Client(),
        _tokenStorage = tokenStorage,
        _tokenProvider = tokenProvider ?? tokenStorage?.getToken,
        _onUnauthorized = onUnauthorized,
        baseUrl = baseUrl ??
            const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: 'http://192.168.29.195:3000/api',
            );

  final http.Client _client;
  final TokenStorage? _tokenStorage;
  final TokenProvider? _tokenProvider;
  final UnauthorizedCallback? _onUnauthorized;
  final String baseUrl;
  bool _unauthorizedHandled = false;

  Future<Object?> get(String path, {bool attachAuth = true}) {
    return _request(method: 'GET', path: path, attachAuth: attachAuth);
  }

  Future<Object?> post(
    String path, {
    Map<String, dynamic>? body,
    bool attachAuth = true,
  }) {
    return _request(
      method: 'POST',
      path: path,
      body: body,
      attachAuth: attachAuth,
    );
  }

  Future<Object?> put(
    String path, {
    Map<String, dynamic>? body,
    bool attachAuth = true,
  }) {
    return _request(
      method: 'PUT',
      path: path,
      body: body,
      attachAuth: attachAuth,
    );
  }

  Future<Object?> patch(
    String path, {
    Map<String, dynamic>? body,
    bool attachAuth = true,
  }) {
    return _request(
      method: 'PATCH',
      path: path,
      body: body,
      attachAuth: attachAuth,
    );
  }

  Future<Object?> delete(String path, {bool attachAuth = true}) {
    return _request(method: 'DELETE', path: path, attachAuth: attachAuth);
  }

  Future<Object?> _request({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    required bool attachAuth,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = await _headers(attachAuth: attachAuth);
    final encodedBody = body == null ? null : jsonEncode(body);

    late final http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await _client.get(uri, headers: headers);
          break;
        case 'POST':
          response =
              await _client.post(uri, headers: headers, body: encodedBody);
          break;
        case 'PUT':
          response =
              await _client.put(uri, headers: headers, body: encodedBody);
          break;
        case 'PATCH':
          response =
              await _client.patch(uri, headers: headers, body: encodedBody);
          break;
        case 'DELETE':
          response = await _client.delete(uri, headers: headers);
          break;
        default:
          throw const ApiException(message: 'Unsupported request method.');
      }
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException(
        message: 'Network request failed.',
        error: error,
        type: ApiExceptionType.network,
      );
    }

    return _parseResponse(response, handleUnauthorized: attachAuth);
  }

  Future<Map<String, String>> _headers({required bool attachAuth}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'x-correlation-id': createOperationId(),
    };

    if (attachAuth) {
      final token = await _tokenProvider?.call();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  Future<Object?> _parseResponse(
    http.Response response, {
    required bool handleUnauthorized,
  }) async {
    if (response.statusCode == 401 && handleUnauthorized) {
      await _handleUnauthorized();
      final payload = _tryDecodePayload(response);
      throw ApiException(
        message: _errorMessage(payload),
        code: _errorCode(payload),
        statusCode: response.statusCode,
        error: payload,
        type: ApiExceptionType.auth,
      );
    }

    final payload = _decodePayload(response);
    final success = payload['success'] as bool? ?? false;

    if (success) {
      _unauthorizedHandled = false;
      return payload['data'];
    }

    throw ApiException(
      message: _errorMessage(payload),
      code: _errorCode(payload),
      statusCode: response.statusCode,
      error: payload,
    );
  }

  Map<String, dynamic> _decodePayload(http.Response response) {
    if (response.body.isEmpty) {
      return {
        'success': false,
        'code': 'EMPTY_RESPONSE',
        'message': 'Empty response from server.',
      };
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } on FormatException catch (error) {
      throw ApiException(
        message: 'Invalid JSON response from server.',
        statusCode: response.statusCode,
        error: error,
        type: response.statusCode == 401
            ? ApiExceptionType.auth
            : ApiExceptionType.server,
      );
    }

    throw ApiException(
      message: 'Unexpected response format from server.',
      statusCode: response.statusCode,
      error: response.body,
      type: response.statusCode == 401
          ? ApiExceptionType.auth
          : ApiExceptionType.server,
    );
  }

  Map<String, dynamic> _tryDecodePayload(http.Response response) {
    try {
      return _decodePayload(response);
    } on ApiException {
      return {
        'success': false,
        'code': 'UNAUTHORIZED',
        'message': 'Please login again.',
      };
    }
  }

  Future<void> _handleUnauthorized() async {
    await _tokenStorage?.clearToken();

    if (_unauthorizedHandled) {
      return;
    }

    _unauthorizedHandled = true;
    await _onUnauthorized?.call();
  }

  String _errorMessage(Map<String, dynamic> payload) {
    final message = payload['message'];
    if (message is String && message.isNotEmpty) {
      return message;
    }

    final error = payload['error'];
    if (error is String && error.isNotEmpty) {
      return error;
    }

    return 'Request failed.';
  }

  String? _errorCode(Map<String, dynamic> payload) {
    final code = payload['code'];
    return code is String && code.isNotEmpty ? code : null;
  }
}
