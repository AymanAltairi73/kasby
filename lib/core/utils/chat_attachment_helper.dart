import 'package:kasby/core/services/supabase_service.dart';

/// Resolves chat attachment paths/URLs to loadable image URLs.
///
/// The `chat_attachments` bucket is private; [getPublicUrl] alone returns 403
/// in [CachedNetworkImage]. Use [createSignedUrl] with the user's session instead.
class ChatAttachmentHelper {
  ChatAttachmentHelper._();

  static const String bucket = 'chat_attachments';
  static const int signedUrlTtlSeconds = 60 * 60 * 24;

  /// Extracts the storage object path from a full Supabase URL or returns [content]
  /// when it is already a relative path.
  static String extractStoragePath(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return trimmed;

    if (!trimmed.startsWith('http')) {
      return trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return trimmed;

    final segments = uri.pathSegments;
    final bucketIndex = segments.indexOf(bucket);
    if (bucketIndex >= 0 && bucketIndex + 1 < segments.length) {
      return segments.sublist(bucketIndex + 1).join('/');
    }

    // Legacy: .../object/public/chat_attachments/path
    const publicMarker = '/object/public/$bucket/';
    final full = uri.toString();
    final publicIdx = full.indexOf(publicMarker);
    if (publicIdx >= 0) {
      return full.substring(publicIdx + publicMarker.length);
    }

    const signMarker = '/object/sign/$bucket/';
    final signIdx = full.indexOf(signMarker);
    if (signIdx >= 0) {
      final rest = full.substring(signIdx + signMarker.length);
      return rest.split('?').first;
    }

    return trimmed;
  }

  /// Returns a URL that can be loaded by [CachedNetworkImage] / [Image.network].
  static Future<String> resolveDisplayUrl(String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return trimmed;

    if (trimmed.startsWith('http') &&
        !trimmed.contains('/storage/v1/object/')) {
      return trimmed;
    }

    final path = extractStoragePath(trimmed);
    if (path.isEmpty) return trimmed;

    try {
      return await SupabaseService.client.storage
          .from(bucket)
          .createSignedUrl(path, signedUrlTtlSeconds);
    } catch (_) {
      return SupabaseService.client.storage.from(bucket).getPublicUrl(path);
    }
  }
}
