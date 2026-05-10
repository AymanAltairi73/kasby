import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized Supabase service for easy access throughout the app.
class SupabaseService {
  SupabaseService._();

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
    try {
      if (userId == null) return;

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
    } catch (e) {
      debugPrint('Error logging activity: $e');
    }
  }

  /// Upload an image to a Supabase storage bucket.
  /// Returns the public URL of the uploaded image.
  static Future<String> uploadImage({
    required String bucket,
    required String filePath,
    required String fileName,
  }) async {
    final file = File(filePath);
    final path = fileName;

    await client.storage
        .from(bucket)
        .upload(path, file, fileOptions: const FileOptions(upsert: true));

    return client.storage.from(bucket).getPublicUrl(path);
  }

  /// Force a session refresh to sync local JWT with server-side changes (like email update).
  static Future<void> hardRefreshSession() async {
    try {
      await client.auth.refreshSession();
      debugPrint('[SUPABASE_SERVICE] 🔄 Session refreshed successfully');
    } catch (e) {
      debugPrint('[SUPABASE_SERVICE] ❌ Failed to refresh session: $e');
    }
  }
}
