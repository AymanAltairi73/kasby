import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import 'tour_ids.dart';
import 'tour_step.dart';
import 'tour_target_keys.dart';

class MarketplaceTourConfig {
  MarketplaceTourConfig._();

  static List<TourStepDefinition> get steps => [
    TourStepDefinition(
      id: 'categories',
      tourId: TourId.marketplace,
      targetKey: TourTargetKeys.marketplaceCategories,
      titleKey: 'tour_marketplace_categories_title',
      descriptionKey: 'tour_marketplace_categories_desc',
      preferredAlign: ContentAlign.bottom,
    ),
    TourStepDefinition(
      id: 'search',
      tourId: TourId.marketplace,
      targetKey: TourTargetKeys.marketplaceSearch,
      titleKey: 'tour_marketplace_search_title',
      descriptionKey: 'tour_marketplace_search_desc',
      preferredAlign: ContentAlign.bottom,
    ),
    TourStepDefinition(
      id: 'cart',
      tourId: TourId.marketplace,
      targetKey: TourTargetKeys.marketplaceCart,
      titleKey: 'tour_marketplace_cart_title',
      descriptionKey: 'tour_marketplace_cart_desc',
      preferredAlign: ContentAlign.bottom,
    ),
    TourStepDefinition(
      id: 'checkout',
      tourId: TourId.marketplace,
      targetKey: TourTargetKeys.marketplaceCategories,
      titleKey: 'tour_marketplace_checkout_title',
      descriptionKey: 'tour_marketplace_checkout_desc',
      preferredAlign: ContentAlign.top,
    ),
    TourStepDefinition(
      id: 'payment',
      tourId: TourId.marketplace,
      targetKey: TourTargetKeys.marketplaceCart,
      titleKey: 'tour_marketplace_payment_title',
      descriptionKey: 'tour_marketplace_payment_desc',
      preferredAlign: ContentAlign.top,
    ),
  ];
}
