import 'dart:async';
import 'package:get/get.dart';
import 'package:kasby/core/models/search_result_model.dart';
import 'package:kasby/core/services/search_service.dart';
import 'package:kasby/core/utils/safe_getx.dart';

class GlobalSearchController extends GetxController {
  static GlobalSearchController get to => Get.find();

  final RxString query = ''.obs;
  final Rx<SearchResults> results = Rx<SearchResults>(SearchResults.empty);
  final RxBool isSearching = false.obs;
  final RxList<String> recentSearches = <String>[].obs;
  final RxString selectedCategory = 'all'.obs;

  Timer? _debounce;

  List<SearchResultItem> get filteredResults {
    if (selectedCategory.value == 'all') return results.value.items;
    return results.value.items
        .where((item) => item.category == selectedCategory.value)
        .toList();
  }

  @override
  void onInit() {
    super.onInit();
    _loadRecentSearches();
  }

  @override
  void onClose() {
    _debounce?.cancel();
    super.onClose();
  }

  Future<void> _loadRecentSearches() async {
    recentSearches.value = await SearchService.loadRecentSearches();
  }

  void onQueryChanged(String value) {
    query.value = value;
    _debounce?.cancel();

    if (value.trim().isEmpty) {
      results.value = SearchResults.empty;
      isSearching.value = false;
      return;
    }

    isSearching.value = true;
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(value);
    });
  }

  Future<void> _performSearch(String searchQuery) async {
    if (searchQuery.trim().isEmpty) {
      results.value = SearchResults.empty;
      isSearching.value = false;
      return;
    }

    try {
      final searchResults = await SearchService.search(searchQuery);
      results.value = searchResults;

      if (searchResults.totalCount > 0) {
        await SearchService.saveRecentSearch(searchQuery.trim());
        await _loadRecentSearches();
      }
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'GlobalSearchController',
        method: '_performSearch',
        feature: 'Search',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
    } finally {
      isSearching.value = false;
    }
  }

  void selectCategory(String category) {
    selectedCategory.value = category;
  }

  Future<void> removeRecentSearch(String search) async {
    await SearchService.removeRecentSearch(search);
    await _loadRecentSearches();
  }

  Future<void> clearRecentSearches() async {
    await SearchService.clearRecentSearches();
    recentSearches.clear();
  }

  void clearSearch() {
    query.value = '';
    results.value = SearchResults.empty;
    isSearching.value = false;
    selectedCategory.value = 'all';
  }

  void searchFromRecent(String search) {
    query.value = search;
    onQueryChanged(search);
  }
}
