import 'topup_product.dart';

class TopupService {
  final String slug;
  final String name;
  final String description;
  final String iconKey;
  final String flow; // 'bundle', 'account_links', 'quote_links'
  final bool enabled;
  final int position;
  final List<TopupProduct> products;

  TopupService({
    required this.slug,
    required this.name,
    required this.description,
    required this.iconKey,
    required this.flow,
    required this.enabled,
    required this.position,
    required this.products,
  });

  factory TopupService.fromJson(Map<String, dynamic> json) {
    return TopupService(
      slug: json['slug'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      iconKey: json['icon_key'] as String? ?? '',
      flow: json['flow'] as String? ?? 'bundle',
      enabled: json['enabled'] as bool? ?? true,
      position: json['position'] as int? ?? 0,
      products: (json['products'] as List?)
              ?.map((e) => TopupProduct.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'slug': slug,
      'name': name,
      'description': description,
      'icon_key': iconKey,
      'flow': flow,
      'enabled': enabled,
      'position': position,
      'products': products.map((e) => e.toJson()).toList(),
    };
  }

  TopupService copyWith({
    String? slug,
    String? name,
    String? description,
    String? iconKey,
    String? flow,
    bool? enabled,
    int? position,
    List<TopupProduct>? products,
  }) {
    return TopupService(
      slug: slug ?? this.slug,
      name: name ?? this.name,
      description: description ?? this.description,
      iconKey: iconKey ?? this.iconKey,
      flow: flow ?? this.flow,
      enabled: enabled ?? this.enabled,
      position: position ?? this.position,
      products: products ?? this.products,
    );
  }
}
