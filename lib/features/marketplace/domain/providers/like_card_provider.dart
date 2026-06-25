import 'mock_marketplace_provider.dart';

/// Reserved for a future second provider — NOT used in Kasby Marketplace v1.
/// Kasby launches with [ReloadlyProvider] only via [MarketplaceApiService].
///
/// When adding a provider later: implement [MarketplaceProvider] directly
/// (do not extend mock) and register via [MarketplaceApiService.setProvider].
class LikeCardProvider extends MockMarketplaceProvider {}

/// Reserved for future use — not implemented.
class DToneProvider extends MockMarketplaceProvider {}

/// Reserved for future use — not implemented.
class MtcGameProvider extends MockMarketplaceProvider {}
