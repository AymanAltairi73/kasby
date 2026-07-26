import 'topup_delivery_option.dart';

class TopupProduct {
  final String sku;
  final String game;
  final String productLabel;
  final String region;
  final List<TopupDeliveryOption> deliveryOptions;

  TopupProduct({
    required this.sku,
    required this.game,
    required this.productLabel,
    required this.region,
    required this.deliveryOptions,
  });

  factory TopupProduct.fromJson(Map<String, dynamic> json) {
    return TopupProduct(
      sku: json['sku'] as String? ?? '',
      game: json['game'] as String? ?? '',
      productLabel: json['product_label'] as String? ?? '',
      region: json['region'] as String? ?? '',
      deliveryOptions: (json['delivery_options'] as List?)
              ?.map((e) => TopupDeliveryOption.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sku': sku,
      'game': game,
      'product_label': productLabel,
      'region': region,
      'delivery_options': deliveryOptions.map((e) => e.toJson()).toList(),
    };
  }

  TopupProduct copyWith({
    String? sku,
    String? game,
    String? productLabel,
    String? region,
    List<TopupDeliveryOption>? deliveryOptions,
  }) {
    return TopupProduct(
      sku: sku ?? this.sku,
      game: game ?? this.game,
      productLabel: productLabel ?? this.productLabel,
      region: region ?? this.region,
      deliveryOptions: deliveryOptions ?? this.deliveryOptions,
    );
  }
}
