import 'topup_required_field.dart';

class TopupDeliveryOption {
  final String delivery; // 'direct' or 'voucher'
  final int priceCents;
  final String mechanism;
  final String billingMode; // 'managed' or 'byo'
  final List<TopupRequiredField> requiredFields;

  TopupDeliveryOption({
    required this.delivery,
    required this.priceCents,
    required this.mechanism,
    required this.billingMode,
    required this.requiredFields,
  });

  factory TopupDeliveryOption.fromJson(Map<String, dynamic> json) {
    return TopupDeliveryOption(
      delivery: json['delivery'] as String? ?? 'direct',
      priceCents: json['price_cents'] as int? ?? 0,
      mechanism: json['mechanism'] as String? ?? '',
      billingMode: json['billing_mode'] as String? ?? '',
      requiredFields: (json['required_fields'] as List?)
              ?.map((e) => TopupRequiredField.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'delivery': delivery,
      'price_cents': priceCents,
      'mechanism': mechanism,
      'billing_mode': billingMode,
      'required_fields': requiredFields.map((e) => e.toJson()).toList(),
    };
  }

  TopupDeliveryOption copyWith({
    String? delivery,
    int? priceCents,
    String? mechanism,
    String? billingMode,
    List<TopupRequiredField>? requiredFields,
  }) {
    return TopupDeliveryOption(
      delivery: delivery ?? this.delivery,
      priceCents: priceCents ?? this.priceCents,
      mechanism: mechanism ?? this.mechanism,
      billingMode: billingMode ?? this.billingMode,
      requiredFields: requiredFields ?? this.requiredFields,
    );
  }
}
