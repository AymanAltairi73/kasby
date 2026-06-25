enum MarketplaceProviderName {
  mock,
  likeCard,
  reloadly,
  dtOne,
  mtcGame,
}

enum MarketplaceProviderStatus { active, inactive, deprecated, pending }

/// Maps a variant to an external provider product without exposing provider logic to UI.
class MarketplaceProviderMapping {
  final String id;
  final String variantId;
  final MarketplaceProviderName providerName;
  final String providerProductId;
  final String providerSku;
  final String? providerCategory;
  final MarketplaceProviderStatus providerStatus;
  final Map<String, dynamic> providerMetadata;

  const MarketplaceProviderMapping({
    required this.id,
    required this.variantId,
    required this.providerName,
    required this.providerProductId,
    required this.providerSku,
    this.providerCategory,
    this.providerStatus = MarketplaceProviderStatus.active,
    this.providerMetadata = const {},
  });

  factory MarketplaceProviderMapping.fromJson(Map<String, dynamic> json) {
    return MarketplaceProviderMapping(
      id: json['id'] as String,
      variantId: json['variant_id'] as String,
      providerName: MarketplaceProviderName.values.firstWhere(
        (p) => p.name == json['provider_name'],
        orElse: () => MarketplaceProviderName.mock,
      ),
      providerProductId: json['provider_product_id'] as String,
      providerSku: json['provider_sku'] as String,
      providerCategory: json['provider_category'] as String?,
      providerStatus: MarketplaceProviderStatus.values.firstWhere(
        (s) => s.name == json['provider_status'],
        orElse: () => MarketplaceProviderStatus.active,
      ),
      providerMetadata: Map<String, dynamic>.from(
        json['provider_metadata'] as Map? ?? {},
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'variant_id': variantId,
        'provider_name': providerName.name,
        'provider_product_id': providerProductId,
        'provider_sku': providerSku,
        'provider_category': providerCategory,
        'provider_status': providerStatus.name,
        'provider_metadata': providerMetadata,
      };
}
