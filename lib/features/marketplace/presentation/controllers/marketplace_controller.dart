import 'package:get/get.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import '../../domain/models/marketplace_brand.dart';
import '../../domain/models/marketplace_category.dart';
import '../../domain/models/marketplace_catalog_listing.dart';
import '../../domain/models/marketplace_promotion.dart';
import '../../domain/models/marketplace_filter_options.dart';
import '../../domain/repositories/marketplace_repository.dart';

class MarketplaceController extends GetxController {
  static MarketplaceController get to => Get.find();

  final MarketplaceRepository _repo;

  MarketplaceController({MarketplaceRepository? repository})
      : _repo = repository ?? MarketplaceRepository();

  final categories = <MarketplaceCategory>[].obs;
  final brands = <MarketplaceBrand>[].obs;
  final featuredListings = <MarketplaceCatalogListing>[].obs;
  final popularListings = <MarketplaceCatalogListing>[].obs;
  final trendingListings = <MarketplaceCatalogListing>[].obs;
  final bestSellers = <MarketplaceCatalogListing>[].obs;
  final newArrivals = <MarketplaceCatalogListing>[].obs;
  final recommendedListings = <MarketplaceCatalogListing>[].obs;
  final recentlyViewed = <MarketplaceCatalogListing>[].obs;
  final recentlyPurchased = <MarketplaceCatalogListing>[].obs;
  final banners = <MarketplacePromotion>[].obs;
  final flashDeals = <MarketplacePromotion>[].obs;

  final isLoading = true.obs;
  final hasError = false.obs;
  final catalogUnavailable = false.obs;
  final catalogErrorMessage = RxnString();
  final filters = const MarketplaceFilterOptions().obs;

  String get _locale => Get.locale?.languageCode ?? 'en';

  @override
  void onInit() {
    SafeGetx.debugTrace(className: 'MarketplaceController', method: 'onInit', feature: 'Marketplace', status: 'INFO');
    super.onInit();
    loadHome();
  }

  Future<void> loadHome() async {
    isLoading.value = true;
    hasError.value = false;
    catalogUnavailable.value = false;
    catalogErrorMessage.value = null;
    try {
      await _repo.refreshCatalog();
      final results = await Future.wait([
        _repo.getCategories(),
        _repo.getBrands(),
        _repo.getFeaturedListings(),
        _repo.getPopularListings(),
        _repo.getTrendingListings(),
        _repo.getBestSellers(),
        _repo.getNewArrivals(),
        _repo.getRecommendedListings(),
        _repo.getRecentlyViewed(),
        _repo.getRecentlyPurchased(),
        _repo.getBanners(),
        _repo.getPromotions(type: MarketplacePromotionType.flashSale),
      ]);
      categories.value = results[0] as List<MarketplaceCategory>;
      brands.value = results[1] as List<MarketplaceBrand>;
      featuredListings.value = results[2] as List<MarketplaceCatalogListing>;
      popularListings.value = results[3] as List<MarketplaceCatalogListing>;
      trendingListings.value = results[4] as List<MarketplaceCatalogListing>;
      bestSellers.value = results[5] as List<MarketplaceCatalogListing>;
      newArrivals.value = results[6] as List<MarketplaceCatalogListing>;
      recommendedListings.value = results[7] as List<MarketplaceCatalogListing>;
      recentlyViewed.value = results[8] as List<MarketplaceCatalogListing>;
      recentlyPurchased.value = results[9] as List<MarketplaceCatalogListing>;
      banners.value = results[10] as List<MarketplacePromotion>;
      flashDeals.value = results[11] as List<MarketplacePromotion>;
      if (!_repo.isCatalogAvailable) {
        catalogUnavailable.value = true;
        catalogErrorMessage.value = _repo.catalogLoadError;
      }
    } catch (e, st) {
      hasError.value = true;
      SafeGetx.debugTrace(className: 'MarketplaceController', method: 'loadHome', feature: 'Marketplace', status: 'FAILED', error: e, stackTrace: st);
    } finally {
      isLoading.value = false;
    }
  }

  Future<List<MarketplaceCatalogListing>> getListingsForCategory(String categoryId) {
    return _repo.getCatalogListings(categoryId: categoryId, sortBy: filters.value.sortBy);
  }

  Future<List<MarketplaceBrand>> getBrandsForCategory(String categoryId) {
    return _repo.getBrands(categoryId: categoryId);
  }

  String listingName(MarketplaceCatalogListing l) => l.localizedDisplayName(_locale);
}
