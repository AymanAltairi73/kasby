import 'package:get/get.dart';
import 'package:flutter/material.dart';

class ShellController extends GetxController {
  static ShellController get to => Get.find();

  final RxInt currentIndex = 0.obs;

  void setIndex(int index) {
    currentIndex.value = index;
  }

  /// Handles smart back navigation.
  /// If the current navigator can pop, it pops (back to previous screen).
  /// Otherwise, if we are in a tab that is NOT home, we return to the Home tab.
  void handleBack() {
    if (Navigator.canPop(Get.context!)) {
      Get.back();
    } else if (currentIndex.value != 0) {
      setIndex(0);
    }
  }
}
