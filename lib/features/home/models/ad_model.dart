import 'package:kasby/core/utils/safe_getx.dart';

class Ad {
  final String id;
  final String titleAr;
  final String? titleEn;
  final String? descriptionAr;
  final String? descriptionEn;
  final String imageUrl;
  final String? actionUrl;
  final int priority;
  final bool isActive;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Ad({
    required this.id,
    required this.titleAr,
    this.titleEn,
    this.descriptionAr,
    this.descriptionEn,
    required this.imageUrl,
    this.actionUrl,
    this.priority = 0,
    this.isActive = true,
    this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Ad.fromSupabase(Map<String, dynamic> json) {
    try {
      return Ad(
        id: json['id'],
        titleAr: json['title_ar'] ?? '',
        titleEn: json['title_en'],
        descriptionAr: json['description_ar'],
        descriptionEn: json['description_en'],
        imageUrl: json['image_url'] ?? '',
        actionUrl: json['action_url'],
        priority: json['priority'] ?? 0,
        isActive: json['is_active'] ?? true,
        expiresAt: json['expires_at'] != null
            ? DateTime.parse(json['expires_at'])
            : null,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'])
            : DateTime.now(),
      );
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'Ad',
        method: 'fromSupabase',
        feature: 'Home',
        status: 'ERROR',
        params: {'id': json['id']?.toString()},
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }
}
