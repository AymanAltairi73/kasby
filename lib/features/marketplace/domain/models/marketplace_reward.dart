enum MarketplaceRewardType {
  daily,
  promotional,
  marketplaceBonus,
  ksp,
}

class MarketplaceReward {
  final String id;
  final MarketplaceRewardType type;
  final String titleEn;
  final String titleAr;
  final String descriptionEn;
  final String descriptionAr;
  final double? kspAmount;
  final double? walletAmount;
  final bool isClaimed;
  final bool isAvailable;
  final DateTime? expiresAt;

  const MarketplaceReward({
    required this.id,
    required this.type,
    required this.titleEn,
    required this.titleAr,
    required this.descriptionEn,
    required this.descriptionAr,
    this.kspAmount,
    this.walletAmount,
    this.isClaimed = false,
    this.isAvailable = true,
    this.expiresAt,
  });

  String localizedTitle(String locale) =>
      locale.startsWith('ar') ? titleAr : titleEn;

  String localizedDescription(String locale) =>
      locale.startsWith('ar') ? descriptionAr : descriptionEn;

  factory MarketplaceReward.fromJson(Map<String, dynamic> json) {
    return MarketplaceReward(
      id: json['id'] as String,
      type: MarketplaceRewardType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => MarketplaceRewardType.daily,
      ),
      titleEn: json['title_en'] as String,
      titleAr: json['title_ar'] as String,
      descriptionEn: json['description_en'] as String? ?? '',
      descriptionAr: json['description_ar'] as String? ?? '',
      kspAmount: (json['ksp_amount'] as num?)?.toDouble(),
      walletAmount: (json['wallet_amount'] as num?)?.toDouble(),
      isClaimed: json['is_claimed'] as bool? ?? false,
      isAvailable: json['is_available'] as bool? ?? true,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title_en': titleEn,
        'title_ar': titleAr,
        'description_en': descriptionEn,
        'description_ar': descriptionAr,
        'ksp_amount': kspAmount,
        'wallet_amount': walletAmount,
        'is_claimed': isClaimed,
        'is_available': isAvailable,
        'expires_at': expiresAt?.toIso8601String(),
      };

  MarketplaceReward copyWith({
    String? id,
    MarketplaceRewardType? type,
    String? titleEn,
    String? titleAr,
    String? descriptionEn,
    String? descriptionAr,
    double? kspAmount,
    double? walletAmount,
    bool? isClaimed,
    bool? isAvailable,
    DateTime? expiresAt,
  }) {
    return MarketplaceReward(
      id: id ?? this.id,
      type: type ?? this.type,
      titleEn: titleEn ?? this.titleEn,
      titleAr: titleAr ?? this.titleAr,
      descriptionEn: descriptionEn ?? this.descriptionEn,
      descriptionAr: descriptionAr ?? this.descriptionAr,
      kspAmount: kspAmount ?? this.kspAmount,
      walletAmount: walletAmount ?? this.walletAmount,
      isClaimed: isClaimed ?? this.isClaimed,
      isAvailable: isAvailable ?? this.isAvailable,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}
