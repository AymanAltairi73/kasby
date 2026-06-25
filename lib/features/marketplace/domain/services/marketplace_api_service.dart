import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';

import '../providers/marketplace_provider.dart';
import '../providers/mock_marketplace_provider.dart';
import '../providers/reloadly_provider.dart';
import '../reloadly/reloadly_config.dart';

/// Runtime gateway to the active [MarketplaceProvider].
///
/// Kasby Marketplace v1 uses **Reloadly only**. [MockMarketplaceProvider] is
/// retained for local development when `MARKETPLACE_PROVIDER=mock`.
/// Additional providers can be registered later via [setProvider] without UI changes.
class MarketplaceApiService extends GetxService {
  static MarketplaceApiService get to => Get.find();

  late MarketplaceProvider _provider;

  MarketplaceProvider get provider => _provider;

  bool get isReloadly => _provider is ReloadlyProvider;

  /// Non-null when Reloadly catalog failed to load (credentials, proxy, network).
  String? get catalogLoadError =>
      _provider is ReloadlyProvider
          ? (_provider as ReloadlyProvider).catalogLoadError
          : null;

  bool get isCatalogAvailable =>
      _provider is ReloadlyProvider
          ? (_provider as ReloadlyProvider).isCatalogAvailable
          : true;

  Future<MarketplaceApiService> init({MarketplaceProvider? provider}) async {
    if (provider != null) {
      _provider = provider;
      return this;
    }

    final envProvider = dotenv.isInitialized
        ? dotenv.env['MARKETPLACE_PROVIDER']?.trim().toLowerCase()
        : null;

    // Reloadly-only launch: default to Reloadly unless explicitly set to mock.
    final useReloadly =
        envProvider != 'mock' && (ReloadlyConfig.isConfigured || envProvider == 'reloadly');

    if (useReloadly) {
      final reloadly = ReloadlyProvider();
      await reloadly.warmUp();
      _provider = reloadly;
    } else {
      _provider = MockMarketplaceProvider();
    }
    return this;
  }

  void setProvider(MarketplaceProvider provider) {
    _provider = provider;
  }
}
