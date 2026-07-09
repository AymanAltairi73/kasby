import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import 'tour_ids.dart';
import 'tour_step.dart';
import 'tour_target_keys.dart';

class ReferralTourConfig {
  ReferralTourConfig._();

  static List<TourStepDefinition> get steps => [
        TourStepDefinition(
          id: 'code',
          tourId: TourId.referral,
          targetKey: TourTargetKeys.referralCode,
          titleKey: 'tour_referral_code_title',
          descriptionKey: 'tour_referral_code_desc',
          preferredAlign: ContentAlign.bottom,
        ),
        TourStepDefinition(
          id: 'link',
          tourId: TourId.referral,
          targetKey: TourTargetKeys.referralLink,
          titleKey: 'tour_referral_link_title',
          descriptionKey: 'tour_referral_link_desc',
          preferredAlign: ContentAlign.bottom,
        ),
        TourStepDefinition(
          id: 'team',
          tourId: TourId.referral,
          targetKey: TourTargetKeys.referralTeam,
          titleKey: 'tour_referral_team_title',
          descriptionKey: 'tour_referral_team_desc',
          preferredAlign: ContentAlign.bottom,
        ),
        TourStepDefinition(
          id: 'rewards',
          tourId: TourId.referral,
          targetKey: TourTargetKeys.referralRewards,
          titleKey: 'tour_referral_rewards_title',
          descriptionKey: 'tour_referral_rewards_desc',
          preferredAlign: ContentAlign.top,
        ),
        TourStepDefinition(
          id: 'commission',
          tourId: TourId.referral,
          targetKey: TourTargetKeys.referralCommission,
          titleKey: 'tour_referral_commission_title',
          descriptionKey: 'tour_referral_commission_desc',
          preferredAlign: ContentAlign.top,
        ),
      ];
}
