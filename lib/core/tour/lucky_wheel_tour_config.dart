import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import 'tour_ids.dart';
import 'tour_step.dart';
import 'tour_target_keys.dart';

class LuckyWheelTourConfig {
  LuckyWheelTourConfig._();

  static List<TourStepDefinition> get steps => [
    TourStepDefinition(
      id: 'wheel',
      tourId: TourId.luckyWheel,
      targetKey: TourTargetKeys.spinWheel,
      titleKey: 'tour_wheel_spin_title',
      descriptionKey: 'tour_wheel_spin_desc',
      preferredAlign: ContentAlign.bottom,
    ),
    TourStepDefinition(
      id: 'free',
      tourId: TourId.luckyWheel,
      targetKey: TourTargetKeys.spinFreeSpin,
      titleKey: 'tour_wheel_free_title',
      descriptionKey: 'tour_wheel_free_desc',
      preferredAlign: ContentAlign.bottom,
    ),
    TourStepDefinition(
      id: 'buy',
      tourId: TourId.luckyWheel,
      targetKey: TourTargetKeys.spinBuy,
      titleKey: 'tour_wheel_buy_title',
      descriptionKey: 'tour_wheel_buy_desc',
      preferredAlign: ContentAlign.top,
    ),
    TourStepDefinition(
      id: 'history',
      tourId: TourId.luckyWheel,
      targetKey: TourTargetKeys.spinHistory,
      titleKey: 'tour_wheel_history_title',
      descriptionKey: 'tour_wheel_history_desc',
      preferredAlign: ContentAlign.top,
    ),
  ];
}
