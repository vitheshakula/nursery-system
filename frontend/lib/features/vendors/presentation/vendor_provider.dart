import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/payment.dart';
import '../../../models/vendor.dart';
import '../../../models/vendor_session.dart';
import '../../payments/data/payment_api.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../../core/sync/sync_engine.dart';
import '../data/vendor_api.dart';

class VendorState {
  const VendorState({
    this.vendors = const <Vendor>[],
    this.isLoading = false,
    this.errorMessage,
  });

  final List<Vendor> vendors;
  final bool isLoading;
  final String? errorMessage;

  VendorState copyWith({
    List<Vendor>? vendors,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return VendorState(
      vendors: vendors ?? this.vendors,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

final vendorApiProvider = Provider<VendorApi>((ref) {
  return VendorApi(
    ref.watch(apiClientProvider),
    cache: ref.watch(offlineCacheProvider),
  );
});

final vendorProvider =
    StateNotifierProvider<VendorNotifier, VendorState>((ref) {
  return VendorNotifier(ref.watch(vendorApiProvider));
});

final sessionsProvider =
    FutureProvider.family<List<VendorSession>, String>((ref, vendorId) {
  return ref.watch(vendorApiProvider).getVendorSessions(vendorId);
});

final paymentsProvider =
    FutureProvider.family<List<PaymentRecord>, String>((ref, vendorId) {
  return ref.watch(paymentApiProvider).getVendorPayments(vendorId);
});

class VendorNotifier extends StateNotifier<VendorState> {
  VendorNotifier(this._vendorApi) : super(const VendorState());

  final VendorApi _vendorApi;

  Future<void> fetchVendors() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final vendors = await _vendorApi.getVendors();
      state = state.copyWith(
        vendors: vendors,
        isLoading: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<Vendor> addVendor({
    required String name,
    required String phone,
  }) async {
    final vendor = await _vendorApi.createVendor(name: name, phone: phone);
    state = state.copyWith(
      vendors: [...state.vendors, vendor],
      clearError: true,
    );
    return vendor;
  }

  Future<Vendor> updateVendor({
    required String id,
    required String name,
    required String phone,
  }) async {
    final vendor = await _vendorApi.updateVendor(
      id: id,
      name: name,
      phone: phone,
    );
    state = state.copyWith(
      vendors: [
        for (final existing in state.vendors)
          if (existing.id == vendor.id) vendor else existing,
      ],
      clearError: true,
    );
    return vendor;
  }

  Future<void> deleteVendor(String id) async {
    await _vendorApi.deleteVendor(id);
    state = state.copyWith(
      vendors: [
        for (final vendor in state.vendors)
          if (vendor.id != id) vendor,
      ],
      clearError: true,
    );
  }
}
