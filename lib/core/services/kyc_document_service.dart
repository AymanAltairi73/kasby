import 'dart:io';
import 'package:kasby/core/services/supabase_service.dart';

class KycDocumentService {
  static const String _bucket = 'documents';

  static Future<String> upload({
    required File file,
    required String userId,
    required String documentType,
    Map<String, dynamic>? metadata,
  }) async {
    final fileName =
        '${documentType}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final storagePath = 'kyc/$userId/$fileName';

    await SupabaseService.client.storage
        .from(_bucket)
        .upload(storagePath, file);

    return SupabaseService.client.storage
        .from(_bucket)
        .getPublicUrl(storagePath);
  }

  static String readableError(Object error) {
    final msg = error.toString();
    if (msg.contains('Bucket not found')) {
      return 'Storage bucket missing. Contact support.';
    }
    if (msg.contains('403') || msg.contains('Unauthorized')) {
      return 'Upload permission denied.';
    }
    if (msg.contains('protected profile fields')) {
      return 'Profile update blocked. Please update the app and try again.';
    }
    if (msg.contains('KYC already submitted') ||
        msg.contains('Upload all required KYC documents')) {
      return msg.replaceAll('Exception: ', '');
    }
    return msg;
  }
}
