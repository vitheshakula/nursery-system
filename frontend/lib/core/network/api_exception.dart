enum ApiExceptionType {
  network,
  auth,
  server,
}

class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.error,
    this.type = ApiExceptionType.server,
  });

  final String message;
  final int? statusCode;
  final Object? error;
  final ApiExceptionType type;

  @override
  String toString() {
    final code = statusCode == null ? '' : ' ($statusCode)';
    return 'ApiException$code: $message';
  }
}
