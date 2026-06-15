import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kasby/core/utils/safe_getx.dart';

/// Centralized Supabase service for easy access throughout the app.
class SupabaseService {
  SupabaseService._();

  static bool _authListenerRegistered = false;

  /// Register auth state listener once for session tracing.
  static void registerAuthListener() {
    if (_authListenerRegistered) return;
    _authListenerRegistered = true;
    auth.onAuthStateChange.listen((state) {
      SafeGetx.debugTrace(
        className: 'SupabaseService',
        method: 'onAuthStateChange',
        feature: 'Authentication',
        status: 'INFO',
        params: {
          'event': state.event.name,
          'userId': _safeId(state.session?.user.id),
        },
      );
    });
    SafeGetx.debugTrace(
      className: 'SupabaseService',
      method: 'registerAuthListener',
      feature: 'Authentication',
      status: 'SUCCESS',
    );
  }

  static String _safeId(String? id) {
    if (id == null) return 'none';
    if (id.length <= 8) return id;
    return '${id.substring(0, 8)}...';
  }

  /// The Supabase client instance.
  static SupabaseClient get client => Supabase.instance.client;

  /// Shortcut to the auth instance.
  static GoTrueClient get auth => client.auth;

  /// Current authenticated user's ID, or null if not logged in.
  static String? get userId => auth.currentUser?.id;

  /// Whether a user is currently logged in.
  static bool get isLoggedIn => auth.currentUser != null;

  /// Current user object.
  static User? get currentUser => auth.currentUser;

  /// Listen to auth state changes.
  static Stream<AuthState> get onAuthStateChange => auth.onAuthStateChange;

  /// Centralized logging to system_logs table.
  static Future<void> logActivity({
    required String action,
    String? details,
    String? severity, // info, warning, critical
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      if (userId == null) {
        SafeGetx.debugTrace(
          className: 'SupabaseService',
          method: 'logActivity',
          feature: 'Logging',
          status: 'INFO',
          message: 'Skipped — no authenticated user',
          params: {'action': action},
        );
        return;
      }

      // Fetch role for context
      final role =
          client.auth.currentUser?.appMetadata['role'] as String? ?? 'user';

      await client.from('system_logs').insert({
        'actor_id': userId,
        'action': action,
        'details': {'message': details}, // Store details as JSON object
        'severity': severity ?? 'info',
        'actor_role': role,
        'entity_type': 'system', // Default entity type for general logs
        'created_at': DateTime.now().toIso8601String(),
      });
      stopwatch.stop();
      SafeGetx.debugTrace(
        className: 'SupabaseService',
        method: 'logActivity',
        feature: 'Logging',
        status: 'SUCCESS',
        durationMs: stopwatch.elapsedMilliseconds,
        params: {'action': action, 'severity': severity ?? 'info'},
      );
    } catch (e, st) {
      stopwatch.stop();
      SafeGetx.debugTrace(
        className: 'SupabaseService',
        method: 'logActivity',
        feature: 'Logging',
        status: 'FAILED',
        durationMs: stopwatch.elapsedMilliseconds,
        error: e,
        stackTrace: st,
        params: {'action': action},
      );
    }
  }

  /// Upload an image to a Supabase storage bucket.
  /// Returns the public URL of the uploaded image.
  static Future<String> uploadImage({
    required String bucket,
    required String filePath,
    required String fileName,
  }) async {
    final stopwatch = Stopwatch()..start();
    SafeGetx.debugTrace(
      className: 'SupabaseService',
      method: 'uploadImage',
      feature: 'Storage',
      status: 'INFO',
      params: {'bucket': bucket, 'fileName': fileName},
    );
    try {
      final file = File(filePath);
      final path = fileName;

      await client.storage
          .from(bucket)
          .upload(path, file, fileOptions: const FileOptions(upsert: true));

      final url = client.storage.from(bucket).getPublicUrl(path);
      stopwatch.stop();
      SafeGetx.debugTrace(
        className: 'SupabaseService',
        method: 'uploadImage',
        feature: 'Storage',
        status: 'SUCCESS',
        durationMs: stopwatch.elapsedMilliseconds,
        params: {'bucket': bucket},
      );
      return url;
    } catch (e, st) {
      stopwatch.stop();
      SafeGetx.debugTrace(
        className: 'SupabaseService',
        method: 'uploadImage',
        feature: 'Storage',
        status: 'FAILED',
        durationMs: stopwatch.elapsedMilliseconds,
        error: e,
        stackTrace: st,
        params: {'bucket': bucket},
      );
      rethrow;
    }
  }

  /// Force a session refresh to sync local JWT with server-side changes (like email update).
  static Future<void> hardRefreshSession() async {
    final stopwatch = Stopwatch()..start();
    SafeGetx.debugTrace(
      className: 'SupabaseService',
      method: 'hardRefreshSession',
      feature: 'Authentication',
      status: 'INFO',
    );
    try {
      await client.auth.refreshSession();
      stopwatch.stop();
      SafeGetx.debugTrace(
        className: 'SupabaseService',
        method: 'hardRefreshSession',
        feature: 'Authentication',
        status: 'SUCCESS',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e, st) {
      stopwatch.stop();
      SafeGetx.debugTrace(
        className: 'SupabaseService',
        method: 'hardRefreshSession',
        feature: 'Authentication',
        status: 'FAILED',
        durationMs: stopwatch.elapsedMilliseconds,
        error: e,
        stackTrace: st,
      );
    }
  }
}
