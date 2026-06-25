import 'dart:async';
import 'package:get/get.dart';
import '../../domain/models/marketplace_catalog_listing.dart';
import '../../domain/repositories/marketplace_repository.dart';

class MarketplaceSearchController extends GetxController {
  final MarketplaceRepository _repo;

  MarketplaceSearchController({MarketplaceRepository? repository})
      : _repo = repository ?? MarketplaceRepository();

  final query = ''.obs;
  final results = <MarketplaceCatalogListing>[].obs;
  final suggestions = <String>[].obs;
  final isSearching = false.obs;
  final hasSearched = false.obs;

  Timer? _debounce;

  @override
  void onClose() {
    _debounce?.cancel();
    super.onClose();
  }

  void onQueryChanged(String value) {
    query.value = value;
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      results.clear();
      suggestions.clear();
      hasSearched.value = false;
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      suggestions.value = await _repo.getSearchSuggestions(value);
      await search(value);
    });
  }

  Future<void> search(String q) async {
    isSearching.value = true;
    hasSearched.value = true;
    try {
      results.value = await _repo.searchCatalog(q);
    } finally {
      isSearching.value = false;
    }
  }
}
