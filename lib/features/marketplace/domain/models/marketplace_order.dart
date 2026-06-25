enum MarketplaceOrderStatus {
  pending,
  processing,
  providerAccepted,
  delivered,
  completed,
  failed,
  cancelled,
  refundRequested,
  refunded,
}

enum MarketplacePaymentMethod { wallet, ksp }

class MarketplaceOrderTimelineEntry {
  final MarketplaceOrderStatus status;
  final DateTime timestamp;
  final String? note;

  const MarketplaceOrderTimelineEntry({
    required this.status,
    required this.timestamp,
    this.note,
  });

  factory MarketplaceOrderTimelineEntry.fromJson(Map<String, dynamic> json) {
    return MarketplaceOrderTimelineEntry(
      status: MarketplaceOrderStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => MarketplaceOrderStatus.pending,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status.name,
        'timestamp': timestamp.toIso8601String(),
        'note': note,
      };
}

class MarketplaceOrderItem {
  final String variantId;
  final String productId;
  final String brandId;
  final String variantNameEn;
  final String variantNameAr;
  final String productNameEn;
  final String productNameAr;
  final String brandNameEn;
  final String brandNameAr;
  final String imageUrl;
  final int quantity;
  final double unitPrice;
  final double discountAmount;
  final double totalPrice;

  const MarketplaceOrderItem({
    required this.variantId,
    required this.productId,
    required this.brandId,
    required this.variantNameEn,
    required this.variantNameAr,
    required this.productNameEn,
    required this.productNameAr,
    required this.brandNameEn,
    required this.brandNameAr,
    required this.imageUrl,
    required this.quantity,
    required this.unitPrice,
    this.discountAmount = 0,
    required this.totalPrice,
  });

  String localizedDisplayName(String locale) {
    final brand = locale.startsWith('ar') ? brandNameAr : brandNameEn;
    final variant = locale.startsWith('ar') ? variantNameAr : variantNameEn;
    return '$brand — $variant';
  }

  factory MarketplaceOrderItem.fromJson(Map<String, dynamic> json) {
    return MarketplaceOrderItem(
      variantId: json['variant_id'] as String,
      productId: json['product_id'] as String,
      brandId: json['brand_id'] as String,
      variantNameEn: json['variant_name_en'] as String,
      variantNameAr: json['variant_name_ar'] as String,
      productNameEn: json['product_name_en'] as String,
      productNameAr: json['product_name_ar'] as String,
      brandNameEn: json['brand_name_en'] as String,
      brandNameAr: json['brand_name_ar'] as String,
      imageUrl: json['image_url'] as String? ?? '',
      quantity: json['quantity'] as int,
      unitPrice: (json['unit_price'] as num).toDouble(),
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0,
      totalPrice: (json['total_price'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'variant_id': variantId,
        'product_id': productId,
        'brand_id': brandId,
        'variant_name_en': variantNameEn,
        'variant_name_ar': variantNameAr,
        'product_name_en': productNameEn,
        'product_name_ar': productNameAr,
        'brand_name_en': brandNameEn,
        'brand_name_ar': brandNameAr,
        'image_url': imageUrl,
        'quantity': quantity,
        'unit_price': unitPrice,
        'discount_amount': discountAmount,
        'total_price': totalPrice,
      };
}

class MarketplaceOrder {
  final String id;
  final String userId;
  final List<MarketplaceOrderItem> items;
  final double subtotalAmount;
  final double discountAmount;
  final double totalAmount;
  final String? couponCode;
  final MarketplacePaymentMethod paymentMethod;
  final MarketplaceOrderStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? deliveryCode;
  final String? deliveryInfo;
  final String? notes;
  final List<MarketplaceOrderTimelineEntry> timeline;
  final String? providerTransactionId;
  final String? providerName;
  final String? paymentStatus;
  final String? deliveryStatus;
  final String? walletTransactionId;

  const MarketplaceOrder({
    required this.id,
    required this.userId,
    required this.items,
    required this.subtotalAmount,
    this.discountAmount = 0,
    required this.totalAmount,
    this.couponCode,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.deliveryCode,
    this.deliveryInfo,
    this.notes,
    this.timeline = const [],
    this.providerTransactionId,
    this.providerName,
    this.paymentStatus,
    this.deliveryStatus,
    this.walletTransactionId,
  });

  factory MarketplaceOrder.fromJson(Map<String, dynamic> json) {
    return MarketplaceOrder(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      items: (json['items'] as List<dynamic>)
          .map((e) => MarketplaceOrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      subtotalAmount: (json['subtotal_amount'] as num?)?.toDouble() ??
          (json['total_amount'] as num).toDouble(),
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0,
      totalAmount: (json['total_amount'] as num).toDouble(),
      couponCode: json['coupon_code'] as String?,
      paymentMethod: MarketplacePaymentMethod.values.firstWhere(
        (m) => m.name == json['payment_method'],
        orElse: () => MarketplacePaymentMethod.wallet,
      ),
      status: MarketplaceOrderStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => MarketplaceOrderStatus.pending,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      deliveryCode: json['delivery_code'] as String?,
      deliveryInfo: json['delivery_info'] as String?,
      notes: json['notes'] as String?,
      timeline: (json['timeline'] as List<dynamic>?)
              ?.map(
                (e) => MarketplaceOrderTimelineEntry.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList() ??
          [],
      providerTransactionId: json['provider_transaction_id']?.toString(),
      providerName: json['provider_name'] as String?,
      paymentStatus: json['payment_status'] as String?,
      deliveryStatus: json['delivery_status'] as String?,
      walletTransactionId: json['wallet_transaction_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'items': items.map((e) => e.toJson()).toList(),
        'subtotal_amount': subtotalAmount,
        'discount_amount': discountAmount,
        'total_amount': totalAmount,
        'coupon_code': couponCode,
        'payment_method': paymentMethod.name,
        'status': status.name,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
        'delivery_code': deliveryCode,
        'delivery_info': deliveryInfo,
        'notes': notes,
        'timeline': timeline.map((e) => e.toJson()).toList(),
        if (providerTransactionId != null)
          'provider_transaction_id': providerTransactionId,
        if (providerName != null) 'provider_name': providerName,
        if (paymentStatus != null) 'payment_status': paymentStatus,
        if (deliveryStatus != null) 'delivery_status': deliveryStatus,
        if (walletTransactionId != null)
          'wallet_transaction_id': walletTransactionId,
      };

  MarketplaceOrder copyWith({
    String? id,
    String? userId,
    List<MarketplaceOrderItem>? items,
    double? subtotalAmount,
    double? discountAmount,
    double? totalAmount,
    String? couponCode,
    MarketplacePaymentMethod? paymentMethod,
    MarketplaceOrderStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? deliveryCode,
    String? deliveryInfo,
    String? notes,
    List<MarketplaceOrderTimelineEntry>? timeline,
    String? providerTransactionId,
    String? providerName,
    String? paymentStatus,
    String? deliveryStatus,
    String? walletTransactionId,
  }) {
    return MarketplaceOrder(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      items: items ?? this.items,
      subtotalAmount: subtotalAmount ?? this.subtotalAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      couponCode: couponCode ?? this.couponCode,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deliveryCode: deliveryCode ?? this.deliveryCode,
      deliveryInfo: deliveryInfo ?? this.deliveryInfo,
      notes: notes ?? this.notes,
      timeline: timeline ?? this.timeline,
      providerTransactionId:
          providerTransactionId ?? this.providerTransactionId,
      providerName: providerName ?? this.providerName,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      walletTransactionId:
          walletTransactionId ?? this.walletTransactionId,
    );
  }
}

class MarketplaceCheckoutResult {
  final MarketplaceOrder order;
  final bool success;
  final String? message;

  const MarketplaceCheckoutResult({
    required this.order,
    this.success = true,
    this.message,
  });
}
