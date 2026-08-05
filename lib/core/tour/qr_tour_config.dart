import 'package:get/get.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../../routes/app_routes.dart';
import 'tour_ids.dart';
import 'tour_step.dart';
import 'tour_target_keys.dart';

class QrTourConfig {
  QrTourConfig._();

  static Future<void> _openMyQrIfNeeded() async {
    if (Get.currentRoute != Routes.myQr) {
      await Get.toNamed(Routes.myQr);
      await Future.delayed(const Duration(milliseconds: 450));
    }
  }

  static List<TourStepDefinition> get steps => [
    TourStepDefinition(
      id: 'scan',
      tourId: TourId.qr,
      targetKey: TourTargetKeys.qrScanner,
      titleKey: 'tour_qr_scan_title',
      descriptionKey: 'tour_qr_scan_desc',
      preferredAlign: ContentAlign.bottom,
    ),
    TourStepDefinition(
      id: 'receive',
      tourId: TourId.qr,
      targetKey: TourTargetKeys.qrReceive,
      titleKey: 'tour_qr_receive_title',
      descriptionKey: 'tour_qr_receive_desc',
      preferredAlign: ContentAlign.bottom,
      beforeShow: _openMyQrIfNeeded,
    ),
    TourStepDefinition(
      id: 'share',
      tourId: TourId.qr,
      targetKey: TourTargetKeys.qrShare,
      titleKey: 'tour_qr_share_title',
      descriptionKey: 'tour_qr_share_desc',
      preferredAlign: ContentAlign.top,
      beforeShow: _openMyQrIfNeeded,
    ),
  ];
}
