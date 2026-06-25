/// Kasby required catalog matrix validated against Reloadly Gift Cards API.
/// Products not found in Reloadly are marked "Not Supported by Reloadly".
class ReloadlyCatalogValidation {
  ReloadlyCatalogValidation._();

  static const statusAvailable = 'Available';
  static const statusNotSupported = 'Not Supported by Reloadly';
  static const statusPending = 'Catalog Validation Pending';

  static const requiredProducts = {
    'giftCards': [
      _RequiredProduct('Google Play', ['google play', 'google']),
      _RequiredProduct('Apple', ['apple', 'itunes', 'app store']),
      _RequiredProduct('Steam', ['steam']),
      _RequiredProduct('PlayStation', ['playstation', 'psn']),
      _RequiredProduct('Xbox', ['xbox']),
      _RequiredProduct('Amazon', ['amazon']),
    ],
    'gaming': [
      _RequiredProduct('PUBG Mobile UC', ['pubg']),
      _RequiredProduct('Free Fire Diamonds', ['free fire', 'garena']),
      _RequiredProduct('Mobile Legends', ['mobile legends', 'mlbb']),
      _RequiredProduct('Call of Duty CP', ['call of duty', 'cod']),
    ],
    'subscriptions': [
      _RequiredProduct('Netflix', ['netflix']),
      _RequiredProduct('Spotify', ['spotify']),
      _RequiredProduct('ChatGPT', ['chatgpt', 'openai']),
      _RequiredProduct('Canva', ['canva']),
      _RequiredProduct('YouTube Premium', ['youtube']),
    ],
  };

  static String haystack(Map<String, dynamic> product) {
    final brand = product['brand']?['brandName'] ?? '';
    return '${product['productName'] ?? ''} $brand'.toLowerCase();
  }

  static List<Map<String, dynamic>> matchProducts(
    List<Map<String, dynamic>> products,
    List<String> keywords,
  ) {
    return products.where((p) {
      final h = haystack(p);
      return keywords.any((k) => h.contains(k));
    }).toList();
  }

  static List<ReloadlyValidationResult> buildReport(
    List<Map<String, dynamic>> products, {
    required bool catalogAccessible,
    String source = 'reloadly-proxy',
  }) {
    final results = <ReloadlyValidationResult>[];

    for (final entry in requiredProducts.entries) {
      for (final item in entry.value) {
        final matches = catalogAccessible
            ? matchProducts(products, item.keywords)
            : <Map<String, dynamic>>[];

        final status = !catalogAccessible
            ? statusPending
            : matches.isNotEmpty
                ? statusAvailable
                : statusNotSupported;

        results.add(
          ReloadlyValidationResult(
            section: entry.key,
            productName: item.name,
            status: status,
            matchCount: matches.length,
            sampleMatches: matches
                .take(3)
                .map(
                  (m) => {
                    'productId': m['productId'],
                    'productName': m['productName'],
                    'brandName': m['brand']?['brandName'],
                    'country': m['country']?['isoName'] ??
                        (m['global'] == true ? 'GLOBAL' : null),
                  },
                )
                .toList(),
            catalogAccessible: catalogAccessible,
            source: source,
          ),
        );
      }
    }
    return results;
  }
}

class _RequiredProduct {
  final String name;
  final List<String> keywords;
  const _RequiredProduct(this.name, this.keywords);
}

class ReloadlyValidationResult {
  final String section;
  final String productName;
  final String status;
  final int matchCount;
  final List<Map<String, dynamic>> sampleMatches;
  final bool catalogAccessible;
  final String source;

  const ReloadlyValidationResult({
    required this.section,
    required this.productName,
    required this.status,
    this.matchCount = 0,
    this.sampleMatches = const [],
    this.catalogAccessible = false,
    this.source = 'reloadly-proxy',
  });
}
