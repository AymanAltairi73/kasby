import '../models/marketplace_brand.dart';
import '../models/marketplace_category.dart';
import '../models/marketplace_product.dart';
import '../models/marketplace_product_variant.dart';
import '../models/marketplace_catalog_listing.dart';
import '../models/marketplace_promotion.dart';
import '../models/marketplace_reward.dart';
import '../models/marketplace_notification.dart';
import '../models/marketplace_order.dart';
import '../models/marketplace_settings.dart';
import '../models/marketplace_coupon.dart';
import '../models/marketplace_provider_mapping.dart';
import 'marketplace_catalog_builder.dart';

/// Enterprise mock catalog: Category → Brand → Product → Variant.
/// TODO: Replace this mock data with the production Marketplace Provider API.
class MockMarketplaceData {
  MockMarketplaceData._();

  static MarketplaceSettings settings = const MarketplaceSettings();

  static final List<MarketplaceCategory> categories = [
    const MarketplaceCategory(id: 'cat_games', nameEn: 'Games', nameAr: 'الألعاب', iconName: 'sports_esports', sortOrder: 1),
    const MarketplaceCategory(id: 'cat_gift_cards', nameEn: 'Gift Cards', nameAr: 'بطاقات الهدايا', iconName: 'card_giftcard', sortOrder: 2),
    const MarketplaceCategory(id: 'cat_subscriptions', nameEn: 'Subscriptions', nameAr: 'الاشتراكات', iconName: 'subscriptions', sortOrder: 3),
    const MarketplaceCategory(id: 'cat_digital_services', nameEn: 'Digital Services', nameAr: 'الخدمات الرقمية', iconName: 'wifi', sortOrder: 4),
    const MarketplaceCategory(id: 'cat_ksp_exclusive', nameEn: 'KSP Exclusive', nameAr: 'حصري KSP', iconName: 'diamond', sortOrder: 5),
    const MarketplaceCategory(id: 'cat_new_arrivals', nameEn: 'New Arrivals', nameAr: 'وصل حديثاً', iconName: 'new_releases', sortOrder: 6),
  ];

  static final List<MarketplaceBrand> brands = [
    const MarketplaceBrand(id: 'brand_pubg', categoryId: 'cat_games', nameEn: 'PUBG Mobile', nameAr: 'PUBG Mobile', sortOrder: 1),
    const MarketplaceBrand(id: 'brand_ff', categoryId: 'cat_games', nameEn: 'Free Fire', nameAr: 'Free Fire', sortOrder: 2),
    const MarketplaceBrand(id: 'brand_ml', categoryId: 'cat_games', nameEn: 'Mobile Legends', nameAr: 'Mobile Legends', sortOrder: 3),
    const MarketplaceBrand(id: 'brand_roblox', categoryId: 'cat_games', nameEn: 'Roblox', nameAr: 'Roblox', sortOrder: 4),
    const MarketplaceBrand(id: 'brand_google', categoryId: 'cat_gift_cards', nameEn: 'Google Play', nameAr: 'Google Play', sortOrder: 1),
    const MarketplaceBrand(id: 'brand_apple', categoryId: 'cat_gift_cards', nameEn: 'Apple', nameAr: 'Apple', sortOrder: 2),
    const MarketplaceBrand(id: 'brand_steam', categoryId: 'cat_gift_cards', nameEn: 'Steam', nameAr: 'Steam', sortOrder: 3),
    const MarketplaceBrand(id: 'brand_netflix', categoryId: 'cat_subscriptions', nameEn: 'Netflix', nameAr: 'Netflix', sortOrder: 1),
    const MarketplaceBrand(id: 'brand_spotify', categoryId: 'cat_subscriptions', nameEn: 'Spotify', nameAr: 'Spotify', sortOrder: 2),
    const MarketplaceBrand(id: 'brand_chatgpt', categoryId: 'cat_subscriptions', nameEn: 'ChatGPT', nameAr: 'ChatGPT', sortOrder: 3),
    const MarketplaceBrand(id: 'brand_ksp', categoryId: 'cat_ksp_exclusive', nameEn: 'Kasby KSP', nameAr: 'Kasby KSP', sortOrder: 1),
    const MarketplaceBrand(id: 'brand_valorant', categoryId: 'cat_new_arrivals', nameEn: 'Valorant', nameAr: 'Valorant', sortOrder: 1),
  ];

  static List<MarketplaceProduct> products = _buildProducts();
  static List<MarketplaceProductVariant> variants = _buildVariants();

  static List<MarketplaceCatalogListing> get catalogListings =>
      MarketplaceCatalogBuilder.buildListings(
        categories: categories,
        brands: brands,
        products: products,
        variants: variants,
      );

  static List<MarketplacePromotion> promotions = _buildPromotions();
  static List<MarketplaceCoupon> coupons = _buildCoupons();
  static List<MarketplaceReward> rewards = _buildRewards();
  static List<MarketplaceNotification> notifications = _buildNotifications();
  static List<MarketplaceOrder> orders = _buildOrders();
  static List<MarketplaceProviderMapping> providerMappings = _buildProviderMappings();

  static List<String> recentlyPurchasedVariantIds = ['var_pubg_300', 'var_google_10'];

  static MarketplaceProduct _product({
    required String id,
    required String brandId,
    required String categoryId,
    required String nameEn,
    required String nameAr,
    bool popular = false,
    double rating = 4.7,
    int reviews = 500,
  }) {
    return MarketplaceProduct(
      id: id,
      brandId: brandId,
      categoryId: categoryId,
      nameEn: nameEn,
      nameAr: nameAr,
      descriptionEn: 'Digital delivery for $nameEn under $brandId.',
      descriptionAr: 'تسليم رقمي لـ $nameAr.',
      imageUrl: 'https://picsum.photos/seed/$id/400/400',
      galleryUrls: ['https://picsum.photos/seed/${id}a/400/400'],
      rating: rating,
      reviewCount: reviews,
      isPopular: popular,
      instructionsEn: '1. Complete purchase\n2. Receive code via notification\n3. Redeem in app',
      instructionsAr: '1. أكمل الشراء\n2. استلم الرمز\n3. استخدمه',
      termsEn: 'Non-refundable once delivered.',
      termsAr: 'غير قابل للاسترداد بعد التسليم.',
      deliveryInfoEn: 'Instant digital delivery to your Kasby account.',
      deliveryInfoAr: 'تسليم رقمي فوري.',
    );
  }

  static MarketplaceProductVariant _variant({
    required String id,
    required String productId,
    required String nameEn,
    required String nameAr,
    required double price,
    double? ksp,
    double? original,
    bool featured = false,
    int sort = 0,
    String sku = '',
  }) {
    return MarketplaceProductVariant(
      id: id,
      productId: productId,
      nameEn: nameEn,
      nameAr: nameAr,
      walletPrice: price,
      kspPrice: ksp,
      originalPrice: original,
      sortOrder: sort,
      isFeatured: featured,
      providerSku: sku.isEmpty ? 'MOCK-$id' : sku,
    );
  }

  static List<MarketplaceProduct> _buildProducts() => [
        _product(id: 'prod_pubg_uc', brandId: 'brand_pubg', categoryId: 'cat_games', nameEn: 'UC', nameAr: 'UC', popular: true, rating: 4.9, reviews: 3200),
        _product(id: 'prod_ff_diamonds', brandId: 'brand_ff', categoryId: 'cat_games', nameEn: 'Diamonds', nameAr: 'الماس', popular: true),
        _product(id: 'prod_ml_diamonds', brandId: 'brand_ml', categoryId: 'cat_games', nameEn: 'Diamonds', nameAr: 'الماس'),
        _product(id: 'prod_roblox_robux', brandId: 'brand_roblox', categoryId: 'cat_games', nameEn: 'Robux', nameAr: 'Robux', popular: true),
        _product(id: 'prod_google_gc', brandId: 'brand_google', categoryId: 'cat_gift_cards', nameEn: 'Gift Card', nameAr: 'بطاقة هدايا', popular: true, rating: 4.8),
        _product(id: 'prod_apple_gc', brandId: 'brand_apple', categoryId: 'cat_gift_cards', nameEn: 'Gift Card', nameAr: 'بطاقة هدايا', popular: true),
        _product(id: 'prod_steam_gc', brandId: 'brand_steam', categoryId: 'cat_gift_cards', nameEn: 'Wallet Code', nameAr: 'رمز المحفظة'),
        _product(id: 'prod_netflix_sub', brandId: 'brand_netflix', categoryId: 'cat_subscriptions', nameEn: 'Premium', nameAr: 'Premium', popular: true),
        _product(id: 'prod_spotify_sub', brandId: 'brand_spotify', categoryId: 'cat_subscriptions', nameEn: 'Premium', nameAr: 'Premium', popular: true),
        _product(id: 'prod_chatgpt_sub', brandId: 'brand_chatgpt', categoryId: 'cat_subscriptions', nameEn: 'Plus', nameAr: 'Plus'),
        _product(id: 'prod_ksp_bundle', brandId: 'brand_ksp', categoryId: 'cat_ksp_exclusive', nameEn: 'Gaming Bundle', nameAr: 'حزمة الألعاب', popular: true),
        _product(id: 'prod_valorant_vp', brandId: 'brand_valorant', categoryId: 'cat_new_arrivals', nameEn: 'VP', nameAr: 'VP'),
      ];

  static List<MarketplaceProductVariant> _buildVariants() => [
        _variant(id: 'var_pubg_60', productId: 'prod_pubg_uc', nameEn: '60 UC', nameAr: '60 UC', price: 0.99, ksp: 50, sort: 1),
        _variant(id: 'var_pubg_300', productId: 'prod_pubg_uc', nameEn: '300 UC', nameAr: '300 UC', price: 4.49, ksp: 220, original: 4.99, featured: true, sort: 2),
        _variant(id: 'var_pubg_600', productId: 'prod_pubg_uc', nameEn: '600 UC', nameAr: '600 UC', price: 8.99, ksp: 450, original: 9.99, sort: 3),
        _variant(id: 'var_pubg_1500', productId: 'prod_pubg_uc', nameEn: '1500 UC', nameAr: '1500 UC', price: 19.99, ksp: 1000, sort: 4),
        _variant(id: 'var_pubg_3000', productId: 'prod_pubg_uc', nameEn: '3000 UC', nameAr: '3000 UC', price: 34.99, ksp: 1750, sort: 5),
        _variant(id: 'var_ff_100', productId: 'prod_ff_diamonds', nameEn: '100 Diamonds', nameAr: '100 ماسة', price: 0.89, ksp: 45, sort: 1),
        _variant(id: 'var_ff_500', productId: 'prod_ff_diamonds', nameEn: '500 Diamonds', nameAr: '500 ماسة', price: 3.99, ksp: 200, original: 4.49, sort: 2),
        _variant(id: 'var_ml_86', productId: 'prod_ml_diamonds', nameEn: '86 Diamonds', nameAr: '86 ماسة', price: 1.49, ksp: 75, sort: 1),
        _variant(id: 'var_ml_172', productId: 'prod_ml_diamonds', nameEn: '172 Diamonds', nameAr: '172 ماسة', price: 2.99, ksp: 150, featured: true, sort: 2),
        _variant(id: 'var_roblox_400', productId: 'prod_roblox_robux', nameEn: '400 Robux', nameAr: '400 Robux', price: 4.99, ksp: 250, sort: 1),
        _variant(id: 'var_roblox_800', productId: 'prod_roblox_robux', nameEn: '800 Robux', nameAr: '800 Robux', price: 9.99, ksp: 500, sort: 2),
        _variant(id: 'var_google_10', productId: 'prod_google_gc', nameEn: '\$10', nameAr: '10\$', price: 10, ksp: 500, featured: true, sort: 1),
        _variant(id: 'var_google_25', productId: 'prod_google_gc', nameEn: '\$25', nameAr: '25\$', price: 25, ksp: 1250, sort: 2),
        _variant(id: 'var_apple_10', productId: 'prod_apple_gc', nameEn: '\$10', nameAr: '10\$', price: 10, ksp: 520, sort: 1),
        _variant(id: 'var_apple_25', productId: 'prod_apple_gc', nameEn: '\$25', nameAr: '25\$', price: 25, ksp: 1300, sort: 2),
        _variant(id: 'var_steam_20', productId: 'prod_steam_gc', nameEn: '\$20', nameAr: '20\$', price: 20, ksp: 1000, featured: true, sort: 1),
        _variant(id: 'var_netflix_1m', productId: 'prod_netflix_sub', nameEn: '1 Month', nameAr: 'شهر', price: 12.99, ksp: 650, featured: true, sort: 1),
        _variant(id: 'var_spotify_1m', productId: 'prod_spotify_sub', nameEn: '1 Month', nameAr: 'شهر', price: 9.99, ksp: 500, sort: 1),
        _variant(id: 'var_chatgpt_1m', productId: 'prod_chatgpt_sub', nameEn: '1 Month', nameAr: 'شهر', price: 20, ksp: 1000, sort: 1),
        _variant(id: 'var_ksp_gaming', productId: 'prod_ksp_bundle', nameEn: 'Gaming Bundle', nameAr: 'حزمة الألعاب', price: 14.99, ksp: 750, original: 19.99, featured: true, sort: 1),
        _variant(id: 'var_valorant_1000', productId: 'prod_valorant_vp', nameEn: '1000 VP', nameAr: '1000 VP', price: 9.99, ksp: 500, featured: true, sort: 1),
      ];

  static List<MarketplaceProviderMapping> _buildProviderMappings() {
    return variants.map((v) {
      return MarketplaceProviderMapping(
        id: 'map_${v.id}',
        variantId: v.id,
        providerName: MarketplaceProviderName.mock,
        providerProductId: 'MOCK-PROD-${v.id}',
        providerSku: v.providerSku,
        providerCategory: 'digital_goods',
        providerMetadata: {'mock': true, 'variant': v.nameEn},
      );
    }).toList();
  }

  static List<MarketplacePromotion> _buildPromotions() => [
        const MarketplacePromotion(id: 'promo_banner_1', type: MarketplacePromotionType.banner, titleEn: 'Summer Gaming Sale', titleAr: 'تخفيضات الألعاب', imageUrl: 'https://picsum.photos/seed/b1/800/300', sortOrder: 1),
        const MarketplacePromotion(id: 'promo_flash_1', type: MarketplacePromotionType.flashSale, titleEn: 'Flash Sale — 20% Off UC', titleAr: 'تخفيض سريع — 20% على UC', discountPercent: 20, isActive: true),
        const MarketplacePromotion(id: 'promo_daily_1', type: MarketplacePromotionType.dailyDeal, titleEn: 'Daily Deal: PUBG 300 UC', titleAr: 'عرض اليوم: PUBG 300 UC', isActive: true),
        const MarketplacePromotion(id: 'promo_weekend_1', type: MarketplacePromotionType.weekendDeal, titleEn: 'Weekend Gift Card Deals', titleAr: 'عروض بطاقات نهاية الأسبوع', isActive: true),
        const MarketplacePromotion(id: 'promo_limited_1', type: MarketplacePromotionType.limitedTimeOffer, titleEn: 'Limited: KSP Bundle', titleAr: 'محدود: حزمة KSP', endsAt: null, isActive: true),
        const MarketplacePromotion(id: 'promo_featured_1', type: MarketplacePromotionType.featuredOffer, titleEn: 'Featured: Google Play', titleAr: 'مميز: Google Play', isActive: true),
        const MarketplacePromotion(id: 'promo_campaign_1', type: MarketplacePromotionType.campaign, titleEn: 'KSP Double Rewards', titleAr: 'مكافآت KSP مضاعفة', isActive: true),
      ];

  static List<MarketplaceCoupon> _buildCoupons() => [
        const MarketplaceCoupon(id: 'coup_kasby10', code: 'KASBY10', type: MarketplaceCouponType.percentage, value: 10, minOrderAmount: 5),
        const MarketplaceCoupon(id: 'coup_save5', code: 'SAVE5', type: MarketplaceCouponType.fixedAmount, value: 5, minOrderAmount: 20),
        const MarketplaceCoupon(id: 'coup_welcome', code: 'WELCOME', type: MarketplaceCouponType.percentage, value: 15, maxDiscount: 10, usageLimit: 1000),
      ];

  static List<MarketplaceReward> _buildRewards() => [
        const MarketplaceReward(id: 'reward_daily_1', type: MarketplaceRewardType.daily, titleEn: 'Daily Login Bonus', titleAr: 'مكافأة يومية', descriptionEn: '25 KSP daily', descriptionAr: '25 KSP يومياً', kspAmount: 25),
        const MarketplaceReward(id: 'reward_bonus_1', type: MarketplaceRewardType.marketplaceBonus, titleEn: 'Marketplace Streak', titleAr: 'سلسلة السوق', descriptionEn: '50 KSP for 3 purchases', descriptionAr: '50 KSP', kspAmount: 50),
      ];

  static List<MarketplaceNotification> _buildNotifications() => [
        MarketplaceNotification(id: 'n1', type: MarketplaceNotificationType.orderCompleted, titleEn: 'Order Completed', titleAr: 'اكتمل الطلب', bodyEn: 'PUBG 300 UC delivered.', bodyAr: 'تم تسليم PUBG 300 UC.', createdAt: DateTime.now().subtract(const Duration(hours: 2))),
        MarketplaceNotification(id: 'n2', type: MarketplaceNotificationType.discountAvailable, titleEn: 'Flash Sale Live', titleAr: 'تخفيض سريع', bodyEn: '20% off game credits today.', bodyAr: 'خصم 20% على الألعاب.', createdAt: DateTime.now().subtract(const Duration(hours: 5))),
      ];

  static List<MarketplaceOrder> _buildOrders() {
    final listing = catalogListings.firstWhere((l) => l.variantId == 'var_pubg_300');
    final now = DateTime.now();
    return [
      MarketplaceOrder(
        id: 'ord_001',
        userId: 'mock_user',
        items: [
          MarketplaceOrderItem(
            variantId: listing.variantId,
            productId: listing.productId,
            brandId: listing.brandId,
            variantNameEn: listing.variantNameEn,
            variantNameAr: listing.variantNameAr,
            productNameEn: listing.productNameEn,
            productNameAr: listing.productNameAr,
            brandNameEn: listing.brandNameEn,
            brandNameAr: listing.brandNameAr,
            imageUrl: listing.imageUrl,
            quantity: 1,
            unitPrice: listing.walletPrice,
            totalPrice: listing.walletPrice,
          ),
        ],
        subtotalAmount: listing.walletPrice,
        totalAmount: listing.walletPrice,
        paymentMethod: MarketplacePaymentMethod.wallet,
        status: MarketplaceOrderStatus.completed,
        createdAt: now.subtract(const Duration(days: 3)),
        deliveryCode: 'PUBG-XXXX-1234',
        deliveryInfo: 'Redeem in PUBG Mobile app',
        timeline: [
          MarketplaceOrderTimelineEntry(status: MarketplaceOrderStatus.pending, timestamp: now.subtract(const Duration(days: 3))),
          MarketplaceOrderTimelineEntry(status: MarketplaceOrderStatus.processing, timestamp: now.subtract(const Duration(days: 3, hours: -1))),
          MarketplaceOrderTimelineEntry(status: MarketplaceOrderStatus.providerAccepted, timestamp: now.subtract(const Duration(days: 3, hours: -2))),
          MarketplaceOrderTimelineEntry(status: MarketplaceOrderStatus.delivered, timestamp: now.subtract(const Duration(days: 3, hours: -3))),
          MarketplaceOrderTimelineEntry(status: MarketplaceOrderStatus.completed, timestamp: now.subtract(const Duration(days: 3, hours: -4))),
        ],
      ),
      MarketplaceOrder(
        id: 'ord_002',
        userId: 'mock_user',
        items: [],
        subtotalAmount: 20,
        totalAmount: 20,
        paymentMethod: MarketplacePaymentMethod.ksp,
        status: MarketplaceOrderStatus.processing,
        createdAt: now.subtract(const Duration(hours: 6)),
        timeline: [
          MarketplaceOrderTimelineEntry(status: MarketplaceOrderStatus.pending, timestamp: now.subtract(const Duration(hours: 6))),
          MarketplaceOrderTimelineEntry(status: MarketplaceOrderStatus.processing, timestamp: now.subtract(const Duration(hours: 5))),
        ],
      ),
    ];
  }

  static MarketplaceProduct? productWithVariants(String productId) {
    final product = products.where((p) => p.id == productId).firstOrNull;
    if (product == null) return null;
    final pVariants = variants.where((v) => v.productId == productId).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return product.copyWith(variants: pVariants);
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
