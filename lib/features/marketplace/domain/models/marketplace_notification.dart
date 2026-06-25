enum MarketplaceNotificationType {
  orderCompleted,
  newProduct,
  discountAvailable,
  rewardEarned,
}

class MarketplaceNotification {
  final String id;
  final MarketplaceNotificationType type;
  final String titleEn;
  final String titleAr;
  final String bodyEn;
  final String bodyAr;
  final DateTime createdAt;
  final bool isRead;
  final String? relatedId;

  const MarketplaceNotification({
    required this.id,
    required this.type,
    required this.titleEn,
    required this.titleAr,
    required this.bodyEn,
    required this.bodyAr,
    required this.createdAt,
    this.isRead = false,
    this.relatedId,
  });

  String localizedTitle(String locale) =>
      locale.startsWith('ar') ? titleAr : titleEn;

  String localizedBody(String locale) =>
      locale.startsWith('ar') ? bodyAr : bodyEn;

  factory MarketplaceNotification.fromJson(Map<String, dynamic> json) {
    return MarketplaceNotification(
      id: json['id'] as String,
      type: MarketplaceNotificationType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => MarketplaceNotificationType.newProduct,
      ),
      titleEn: json['title_en'] as String,
      titleAr: json['title_ar'] as String,
      bodyEn: json['body_en'] as String,
      bodyAr: json['body_ar'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      isRead: json['is_read'] as bool? ?? false,
      relatedId: json['related_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title_en': titleEn,
        'title_ar': titleAr,
        'body_en': bodyEn,
        'body_ar': bodyAr,
        'created_at': createdAt.toIso8601String(),
        'is_read': isRead,
        'related_id': relatedId,
      };

  MarketplaceNotification copyWith({
    String? id,
    MarketplaceNotificationType? type,
    String? titleEn,
    String? titleAr,
    String? bodyEn,
    String? bodyAr,
    DateTime? createdAt,
    bool? isRead,
    String? relatedId,
  }) {
    return MarketplaceNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      titleEn: titleEn ?? this.titleEn,
      titleAr: titleAr ?? this.titleAr,
      bodyEn: bodyEn ?? this.bodyEn,
      bodyAr: bodyAr ?? this.bodyAr,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      relatedId: relatedId ?? this.relatedId,
    );
  }
}
