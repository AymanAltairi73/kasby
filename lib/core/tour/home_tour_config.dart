import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import 'tour_controller.dart';
import 'tour_ids.dart';
import 'tour_step.dart';
import 'tour_target_keys.dart';

/// Interactive home tour steps for the main dashboard.
class HomeTourConfig {
  HomeTourConfig._();

  static List<TourStepDefinition> get steps => [
        TourStepDefinition(
          id: 'welcome',
          tourId: TourId.home,
          targetKey: TourTargetKeys.welcome,
          titleKey: 'tour_home_welcome_title',
          descriptionKey: 'tour_home_welcome_desc',
          shape: ShapeLightFocus.RRect,
          focusRadius: 20,
          beforeShow: () async {
            await TourController.ensureHomeTab();
            await TourController.scrollHomeTargetIntoView(TourTargetKeys.welcome);
          },
        ),
        TourStepDefinition(
          id: 'wallet',
          tourId: TourId.home,
          targetKey: TourTargetKeys.wallet,
          titleKey: 'tour_home_wallet_title',
          descriptionKey: 'tour_home_wallet_desc',
          shape: ShapeLightFocus.RRect,
          focusRadius: 20,
          beforeShow: () =>
              TourController.scrollHomeTargetIntoView(TourTargetKeys.wallet),
        ),
        TourStepDefinition(
          id: 'ksp',
          tourId: TourId.home,
          targetKey: TourTargetKeys.kspRewards,
          titleKey: 'tour_home_ksp_title',
          descriptionKey: 'tour_home_ksp_desc',
          preferredAlign: ContentAlign.bottom,
          beforeShow: () =>
              TourController.scrollHomeTargetIntoView(TourTargetKeys.kspRewards),
        ),
        TourStepDefinition(
          id: 'quick_actions',
          tourId: TourId.home,
          targetKey: TourTargetKeys.quickActions,
          titleKey: 'tour_home_quick_actions_title',
          descriptionKey: 'tour_home_quick_actions_desc',
          shape: ShapeLightFocus.RRect,
          focusRadius: 18,
          beforeShow: () => TourController.scrollHomeTargetIntoView(
            TourTargetKeys.quickActions,
          ),
        ),
        TourStepDefinition(
          id: 'notifications',
          tourId: TourId.home,
          targetKey: TourTargetKeys.notifications,
          titleKey: 'tour_home_notifications_title',
          descriptionKey: 'tour_home_notifications_desc',
          preferredAlign: ContentAlign.bottom,
          beforeShow: TourController.ensureHomeTab,
        ),
        TourStepDefinition(
          id: 'transactions',
          tourId: TourId.home,
          targetKey: TourTargetKeys.transactions,
          titleKey: 'tour_home_transactions_title',
          descriptionKey: 'tour_home_transactions_desc',
          shape: ShapeLightFocus.RRect,
          focusRadius: 18,
          beforeShow: () => TourController.scrollHomeTargetIntoView(
            TourTargetKeys.transactions,
          ),
        ),
        TourStepDefinition(
          id: 'referral_summary',
          tourId: TourId.home,
          targetKey: TourTargetKeys.referralSummary,
          titleKey: 'tour_home_referral_title',
          descriptionKey: 'tour_home_referral_desc',
          shape: ShapeLightFocus.RRect,
          focusRadius: 18,
          beforeShow: () => TourController.scrollHomeTargetIntoView(
            TourTargetKeys.referralSummary,
          ),
        ),
        TourStepDefinition(
          id: 'investments',
          tourId: TourId.home,
          targetKey: TourTargetKeys.investNav,
          titleKey: 'tour_home_investments_title',
          descriptionKey: 'tour_home_investments_desc',
          preferredAlign: ContentAlign.top,
          beforeShow: TourController.ensureHomeTab,
        ),
        TourStepDefinition(
          id: 'profile',
          tourId: TourId.home,
          targetKey: TourTargetKeys.profileNav,
          titleKey: 'tour_home_profile_title',
          descriptionKey: 'tour_home_profile_desc',
          preferredAlign: ContentAlign.top,
          beforeShow: TourController.ensureHomeTab,
        ),
      ];
}
