import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../models/dashboard_stats.dart';
import '../../auth/presentation/auth_provider.dart';

final analyticsApiProvider = Provider<AnalyticsApi>((ref) {
  return AnalyticsApi(ref.watch(apiClientProvider));
});

class AnalyticsApi {
  const AnalyticsApi(this._apiClient);

  final ApiClient _apiClient;

  Future<DashboardStats> getDashboardStats() async {
    final data = await _apiClient.get('/analytics/dashboard');
    return DashboardStats.fromJson(
      Map<String, dynamic>.from(data as Map<dynamic, dynamic>),
    );
  }
}
