import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/offline/offline_cache_repository.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../models/dashboard_stats.dart';
import '../../../models/operational_insights.dart';
import '../../auth/presentation/auth_provider.dart';

final analyticsApiProvider = Provider<AnalyticsApi>((ref) {
  return AnalyticsApi(
    ref.watch(apiClientProvider),
    cache: ref.watch(offlineCacheProvider),
  );
});

class AnalyticsApi {
  const AnalyticsApi(this._apiClient, {this.cache});

  final ApiClient _apiClient;
  final OfflineCacheRepository? cache;

  Future<DashboardStats> getDashboardStats() async {
    const cacheKey = 'analytics:dashboard';
    try {
    final data = await _apiClient.get('/analytics/dashboard');
    final row = Map<String, dynamic>.from(data as Map<dynamic, dynamic>);
    await cache?.cacheMap(cacheKey, row);
    return DashboardStats.fromJson(row);
    } on ApiException catch (error) {
      if (error.type != ApiExceptionType.network || cache == null) rethrow;
      final cached = await cache!.readMap(cacheKey);
      if (cached == null) rethrow;
      return DashboardStats.fromJson(cached);
    }
  }

  Future<OperationalInsights> getOperationalInsights({
    int days = 7,
    int lowStockThreshold = 5,
    int largeBalanceThreshold = 1000,
  }) async {
    final cacheKey =
        'analytics:insights:$days:$lowStockThreshold:$largeBalanceThreshold';
    final path =
        '/analytics/insights?days=$days&lowStockThreshold=$lowStockThreshold&largeBalanceThreshold=$largeBalanceThreshold';

    try {
      final data = await _apiClient.get(path);
      final row = Map<String, dynamic>.from(data as Map<dynamic, dynamic>);
      await cache?.cacheMap(cacheKey, row);
      return OperationalInsights.fromJson(row);
    } on ApiException catch (error) {
      if (error.type != ApiExceptionType.network || cache == null) rethrow;
      final cached = await cache!.readMap(cacheKey);
      if (cached == null) rethrow;
      return OperationalInsights.fromJson(cached);
    }
  }
}
