import 'package:supabase_flutter/supabase_flutter.dart';

import '../reloadly/reloadly_api_client.dart';
import '../reloadly/reloadly_config.dart';

/// Records Reloadly health snapshots to Supabase.
class MarketplaceHealthService {
  MarketplaceHealthService({
    ReloadlyApiClient? client,
    SupabaseClient? supabase,
  })  : _client = client ?? ReloadlyApiClient(),
        _supabase = supabase ?? Supabase.instance.client;

  final ReloadlyApiClient _client;
  final SupabaseClient _supabase;

  Future<Map<String, dynamic>> fetchAndRecordHealth() async {
    final live = await _client.getHealthStatus();

    try {
      await _supabase.rpc('fn_marketplace_record_health', params: {
        'p_provider_name': 'reloadly',
        'p_environment': ReloadlyConfig.environment,
        'p_oauth_status': live['oauthStatus']?.toString() ?? 'unknown',
        'p_api_latency_ms': live['apiLatencyMs'] as int?,
        'p_catalog_count': live['catalogCount'] as int?,
        'p_balance_amount': live['balanceAmount'],
        'p_balance_currency': live['balanceCurrency']?.toString(),
        'p_failed_requests': live['apiError'] != null ? 1 : 0,
        'p_metadata': live,
      });
    } catch (_) {
      // Health table may not exist until migration is applied.
    }

    return live;
  }

  Future<Map<String, dynamic>> getDashboardData() async {
    final live = await fetchAndRecordHealth();

    List<dynamic> dbSummary = [];
    List<dynamic> failedLog = [];
    try {
      dbSummary = await _supabase
          .from('marketplace_provider_health')
          .select()
          .order('checked_at', ascending: false)
          .limit(5);
    } catch (_) {}

    try {
      failedLog = await _supabase
          .from('marketplace_api_request_log')
          .select()
          .eq('success', false)
          .order('created_at', ascending: false)
          .limit(10);
    } catch (_) {}

    return {
      'live': live,
      'history': dbSummary,
      'recentFailures': failedLog,
    };
  }
}
