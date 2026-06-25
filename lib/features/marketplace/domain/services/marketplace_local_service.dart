import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/marketplace_cart_item.dart';
import '../models/marketplace_catalog_listing.dart';

/// Persists cart, wishlist, and recently viewed variant IDs locally.
class MarketplaceLocalService {
  static const _cartKey = 'marketplace_cart_v2';
  static const _wishlistKey = 'marketplace_wishlist_v2';
  static const _recentKey = 'marketplace_recent_v2';
  static const _maxRecent = 12;

  Future<List<Map<String, dynamic>>> loadCartRaw() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cartKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> saveCart(List<MarketplaceCartItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cartKey, jsonEncode(items.map((i) => i.toJson()).toList()));
  }

  Future<List<String>> loadWishlist() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_wishlistKey) ?? [];
  }

  Future<void> saveWishlist(List<String> variantIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_wishlistKey, variantIds);
  }

  Future<List<String>> loadRecentlyViewed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_recentKey) ?? [];
  }

  Future<void> addRecentlyViewed(String variantId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_recentKey) ?? [];
    list.remove(variantId);
    list.insert(0, variantId);
    if (list.length > _maxRecent) list.removeLast();
    await prefs.setStringList(_recentKey, list);
  }

  List<MarketplaceCartItem> resolveCartItems(
    List<Map<String, dynamic>> raw,
    List<MarketplaceCatalogListing> catalog,
  ) {
    final items = <MarketplaceCartItem>[];
    for (final entry in raw) {
      final id = entry['variant_id'] as String;
      final qty = entry['quantity'] as int? ?? 1;
      final listing = catalog.where((l) => l.variantId == id).firstOrNull;
      if (listing != null) {
        items.add(MarketplaceCartItem(listing: listing, quantity: qty));
      }
    }
    return items;
  }

  List<MarketplaceCatalogListing> resolveListings(
    List<String> variantIds,
    List<MarketplaceCatalogListing> catalog,
  ) {
    return variantIds
        .map((id) => catalog.where((l) => l.variantId == id).firstOrNull)
        .whereType<MarketplaceCatalogListing>()
        .toList();
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
