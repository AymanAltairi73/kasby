import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import 'tour_ids.dart';
import 'tour_step.dart';
import 'tour_target_keys.dart';

class InvestmentsTourConfig {
  InvestmentsTourConfig._();

  static List<TourStepDefinition> get steps => [
    TourStepDefinition(
      id: 'plans',
      tourId: TourId.investments,
      targetKey: TourTargetKeys.investPlansList,
      titleKey: 'tour_invest_plans_title',
      descriptionKey: 'tour_invest_plans_desc',
      preferredAlign: ContentAlign.bottom,
    ),
    TourStepDefinition(
      id: 'active',
      tourId: TourId.investments,
      targetKey: TourTargetKeys.investActiveTab,
      titleKey: 'tour_invest_active_title',
      descriptionKey: 'tour_invest_active_desc',
      preferredAlign: ContentAlign.bottom,
    ),
    TourStepDefinition(
      id: 'profit',
      tourId: TourId.investments,
      targetKey: TourTargetKeys.investPlansList,
      titleKey: 'tour_invest_profit_title',
      descriptionKey: 'tour_invest_profit_desc',
      preferredAlign: ContentAlign.bottom,
    ),
    TourStepDefinition(
      id: 'claim',
      tourId: TourId.investments,
      targetKey: TourTargetKeys.investClaimRewards,
      titleKey: 'tour_invest_claim_title',
      descriptionKey: 'tour_invest_claim_desc',
      preferredAlign: ContentAlign.top,
    ),
    TourStepDefinition(
      id: 'reinvest',
      tourId: TourId.investments,
      targetKey: TourTargetKeys.investPlansList,
      titleKey: 'tour_invest_reinvest_title',
      descriptionKey: 'tour_invest_reinvest_desc',
      preferredAlign: ContentAlign.top,
    ),
  ];
}
