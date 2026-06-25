import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Reloadly runtime configuration (no secrets in the Flutter app).
///
/// Client credentials MUST live in the Supabase Edge Function `reloadly-proxy`.
/// The app only reads non-secret routing flags from `.env`.
class ReloadlyConfig {
  ReloadlyConfig._();

  static bool get isConfigured {
    if (!dotenv.isInitialized) return false;
    final provider = dotenv.env['MARKETPLACE_PROVIDER']?.trim().toLowerCase();
    // Reloadly-only v1: active unless explicitly set to mock.
    return provider != 'mock';
  }

  /// When true, catalog/order calls go through Supabase `reloadly-proxy`.
  static bool get useEdgeProxy =>
      _boolFromEnv('RELOADLY_USE_EDGE_PROXY', defaultValue: true);

  /// ISO country filter for catalog (e.g. US, SA, YE). Empty = all.
  static String get defaultCountryCode =>
      dotenv.env['RELOADLY_DEFAULT_COUNTRY_CODE']?.trim() ?? '';

  /// Sandbox vs production — edge function reads matching Reloadly credentials.
  static String get environment =>
      dotenv.env['RELOADLY_ENVIRONMENT']?.trim().toLowerCase() ?? 'sandbox';

  static bool get isSandbox =>
      environment == 'sandbox' || environment == 'test';

  // TODO: Add Reloadly Client ID — set RELOADLY_CLIENT_ID in Supabase Edge Function secrets (not in Flutter).
  // TODO: Add Reloadly Client Secret — set RELOADLY_CLIENT_SECRET in Supabase Edge Function secrets.
  // TODO: Configure OAuth Token — handled by reloadly-proxy via POST https://auth.reloadly.com/oauth/token
  // TODO: Configure Production Environment — set RELOADLY_ENVIRONMENT=production when going live.

  static bool _boolFromEnv(String key, {required bool defaultValue}) {
    if (!dotenv.isInitialized) return defaultValue;
    final raw = dotenv.env[key]?.trim().toLowerCase();
    if (raw == null || raw.isEmpty) return defaultValue;
    return raw == 'true' || raw == '1' || raw == 'yes';
  }
}
