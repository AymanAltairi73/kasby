class MarketplaceSettings {
  final bool isEnabled;
  final bool walletPaymentEnabled;
  final bool kspPaymentEnabled;
  final bool maintenanceMode;
  final String? maintenanceMessageEn;
  final String? maintenanceMessageAr;

  const MarketplaceSettings({
    this.isEnabled = true,
    this.walletPaymentEnabled = true,
    this.kspPaymentEnabled = true,
    this.maintenanceMode = false,
    this.maintenanceMessageEn,
    this.maintenanceMessageAr,
  });

  factory MarketplaceSettings.fromJson(Map<String, dynamic> json) {
    return MarketplaceSettings(
      isEnabled: json['is_enabled'] as bool? ?? true,
      walletPaymentEnabled: json['wallet_payment_enabled'] as bool? ?? true,
      kspPaymentEnabled: json['ksp_payment_enabled'] as bool? ?? true,
      maintenanceMode: json['maintenance_mode'] as bool? ?? false,
      maintenanceMessageEn: json['maintenance_message_en'] as String?,
      maintenanceMessageAr: json['maintenance_message_ar'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'is_enabled': isEnabled,
        'wallet_payment_enabled': walletPaymentEnabled,
        'ksp_payment_enabled': kspPaymentEnabled,
        'maintenance_mode': maintenanceMode,
        'maintenance_message_en': maintenanceMessageEn,
        'maintenance_message_ar': maintenanceMessageAr,
      };

  MarketplaceSettings copyWith({
    bool? isEnabled,
    bool? walletPaymentEnabled,
    bool? kspPaymentEnabled,
    bool? maintenanceMode,
    String? maintenanceMessageEn,
    String? maintenanceMessageAr,
  }) {
    return MarketplaceSettings(
      isEnabled: isEnabled ?? this.isEnabled,
      walletPaymentEnabled: walletPaymentEnabled ?? this.walletPaymentEnabled,
      kspPaymentEnabled: kspPaymentEnabled ?? this.kspPaymentEnabled,
      maintenanceMode: maintenanceMode ?? this.maintenanceMode,
      maintenanceMessageEn:
          maintenanceMessageEn ?? this.maintenanceMessageEn,
      maintenanceMessageAr:
          maintenanceMessageAr ?? this.maintenanceMessageAr,
    );
  }
}

class MarketplaceDashboardStats {
  final int totalProducts;
  final int totalBrands;
  final int totalVariants;
  final int totalCategories;
  final int totalOrders;
  final double totalRevenue;
  final int pendingOrders;
  final List<Map<String, dynamic>> bestSellingProducts;
  final List<Map<String, dynamic>> topCategories;

  const MarketplaceDashboardStats({
    required this.totalProducts,
    this.totalBrands = 0,
    this.totalVariants = 0,
    required this.totalCategories,
    required this.totalOrders,
    required this.totalRevenue,
    required this.pendingOrders,
    this.bestSellingProducts = const [],
    this.topCategories = const [],
  });

  factory MarketplaceDashboardStats.fromJson(Map<String, dynamic> json) {
    return MarketplaceDashboardStats(
      totalProducts: json['total_products'] as int? ?? 0,
      totalBrands: json['total_brands'] as int? ?? 0,
      totalVariants: json['total_variants'] as int? ?? 0,
      totalCategories: json['total_categories'] as int? ?? 0,
      totalOrders: json['total_orders'] as int? ?? 0,
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0,
      pendingOrders: json['pending_orders'] as int? ?? 0,
      bestSellingProducts:
          (json['best_selling_products'] as List<dynamic>?)
                  ?.map((e) => Map<String, dynamic>.from(e as Map))
                  .toList() ??
              [],
      topCategories: (json['top_categories'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
    );
  }
}
