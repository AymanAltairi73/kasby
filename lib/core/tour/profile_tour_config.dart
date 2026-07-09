import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import 'tour_ids.dart';
import 'tour_step.dart';
import 'tour_target_keys.dart';

class ProfileTourConfig {
  ProfileTourConfig._();

  static List<TourStepDefinition> get steps => [
        TourStepDefinition(
          id: 'kyc',
          tourId: TourId.profile,
          targetKey: TourTargetKeys.profileKyc,
          titleKey: 'tour_profile_kyc_title',
          descriptionKey: 'tour_profile_kyc_desc',
          preferredAlign: ContentAlign.bottom,
        ),
        TourStepDefinition(
          id: 'security',
          tourId: TourId.profile,
          targetKey: TourTargetKeys.profileSecurity,
          titleKey: 'tour_profile_security_title',
          descriptionKey: 'tour_profile_security_desc',
          preferredAlign: ContentAlign.bottom,
        ),
        TourStepDefinition(
          id: 'pin',
          tourId: TourId.profile,
          targetKey: TourTargetKeys.profilePin,
          titleKey: 'tour_profile_pin_title',
          descriptionKey: 'tour_profile_pin_desc',
          preferredAlign: ContentAlign.bottom,
        ),
        TourStepDefinition(
          id: 'biometrics',
          tourId: TourId.profile,
          targetKey: TourTargetKeys.profileSecurity,
          titleKey: 'tour_profile_biometrics_title',
          descriptionKey: 'tour_profile_biometrics_desc',
          preferredAlign: ContentAlign.top,
        ),
        TourStepDefinition(
          id: 'language',
          tourId: TourId.profile,
          targetKey: TourTargetKeys.profileLanguage,
          titleKey: 'tour_profile_language_title',
          descriptionKey: 'tour_profile_language_desc',
          preferredAlign: ContentAlign.top,
        ),
      ];
}
