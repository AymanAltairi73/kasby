import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import 'tour_ids.dart';
import 'tour_step.dart';
import 'tour_target_keys.dart';

class SocialTourConfig {
  SocialTourConfig._();

  static List<TourStepDefinition> get steps => [
    TourStepDefinition(
      id: 'dashboard',
      tourId: TourId.social,
      targetKey: TourTargetKeys.socialDashboard,
      titleKey: 'tour_social_dashboard_title',
      descriptionKey: 'tour_social_dashboard_desc',
      preferredAlign: ContentAlign.bottom,
    ),
    TourStepDefinition(
      id: 'requests',
      tourId: TourId.social,
      targetKey: TourTargetKeys.socialRequests,
      titleKey: 'tour_social_requests_title',
      descriptionKey: 'tour_social_requests_desc',
      preferredAlign: ContentAlign.bottom,
    ),
    TourStepDefinition(
      id: 'friends',
      tourId: TourId.social,
      targetKey: TourTargetKeys.socialFriends,
      titleKey: 'tour_social_friends_title',
      descriptionKey: 'tour_social_friends_desc',
      preferredAlign: ContentAlign.bottom,
    ),
    TourStepDefinition(
      id: 'chat',
      tourId: TourId.social,
      targetKey: TourTargetKeys.socialFriends,
      titleKey: 'tour_social_chat_title',
      descriptionKey: 'tour_social_chat_desc',
      preferredAlign: ContentAlign.top,
    ),
    TourStepDefinition(
      id: 'invite',
      tourId: TourId.social,
      targetKey: TourTargetKeys.socialInvite,
      titleKey: 'tour_social_invite_title',
      descriptionKey: 'tour_social_invite_desc',
      preferredAlign: ContentAlign.top,
    ),
  ];
}
