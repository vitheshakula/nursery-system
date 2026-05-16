import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/offline/operation_queue.dart';
import '../../../core/offline/operation_queue_repository.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../models/payment.dart';
import '../../auth/presentation/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final paymentApiProvider = Provider<PaymentApi>((ref) {
  return PaymentApi(
    ref.watch(apiClientProvider),
    queue: ref.watch(operationQueueProvider),
  );
});

class PaymentApi {
  const PaymentApi(this._apiClient, {this.queue});

  final ApiClient _apiClient;
  final OperationQueueRepository? queue;

  Future<List<PaymentRecord>> getVendorPayments(String vendorId) async {
    final data = await _apiClient.get('/payments/vendor/$vendorId');
    return _list(data).map(PaymentRecord.fromJson).toList();
  }

  Future<PaymentRecord> createPayment({
    required String vendorId,
    required double amount,
    required String mode,
  }) async {
    final requestId = createOperationId();
    final body = <String, dynamic>{
      'vendorId': vendorId,
      'amount': amount,
      'mode': mode,
      'requestId': requestId,
    };

    try {
      final data = await _apiClient.post('/payments', body: body);
      return PaymentRecord.fromJson(_map(data));
    } on ApiException catch (error) {
      if (error.type != ApiExceptionType.network || queue == null) {
        rethrow;
      }

      await queue!.enqueue(
        type: QueuedOperationType.createPayment,
        endpoint: '/payments',
        method: 'POST',
        payload: body,
      );

      return PaymentRecord(
        id: requestId,
        vendorId: vendorId,
        amount: amount,
        mode: mode,
        createdAt: DateTime.now(),
      );
    }
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
