import '../../../core/network/api_client.dart';
import '../../../models/payment.dart';
import '../../auth/presentation/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final paymentApiProvider = Provider<PaymentApi>((ref) {
  return PaymentApi(ref.watch(apiClientProvider));
});

class PaymentApi {
  const PaymentApi(this._apiClient);

  final ApiClient _apiClient;

  Future<List<PaymentRecord>> getVendorPayments(String vendorId) async {
    final data = await _apiClient.get('/payments/vendor/$vendorId');
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

    final data = await _apiClient.post('/payments', body: body);
    return PaymentRecord.fromJson(_map(data));
  }

  Map<String, dynamic> _map(Object? value) {
    return Map<String, dynamic>.from(value as Map<dynamic, dynamic>);
  }

  List<Map<String, dynamic>> _list(Object? value) {
    final items = value as List<dynamic>? ?? const [];
    return items
        .map((item) => Map<String, dynamic>.from(item as Map<dynamic, dynamic>))
        .toList();
  }
}
