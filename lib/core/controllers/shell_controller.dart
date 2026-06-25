import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:kasby/core/utils/safe_getx.dart';

class ShellController extends GetxController {
  static ShellController get to => Get.find();

  final RxInt currentIndex = 0.obs;

  @override
  void onInit() {
    SafeGetx.debugTrace(
      className: 'ShellController',
      method: 'onInit',
      feature: 'Navigation',
      status: 'INFO',
      message: 'Shell controller created',
    );
    super.onInit();
  }

  @override
  void onReady() {
    SafeGetx.debugTrace(
      className: 'ShellController',
      method: 'onReady',
      feature: 'Navigation',
      status: 'INFO',
      params: {'currentTab': currentIndex.value},
    );
    super.onReady();
  }

  @override
  void onClose() {
    SafeGetx.debugTrace(
      className: 'ShellController',
      method: 'onClose',
      feature: 'Navigation',
      status: 'INFO',
      message: 'Shell controller disposed',
    );
    super.onClose();
  }

  /// Whether the given shell tab index is currently visible.
  bool isTabActive(int index) => currentIndex.value == index;

  /// Tab indices for [MainShellView].
  static const int tabHome = 0;
  static const int tabWallet = 1;
  static const int tabInvest = 2;
  static const int tabTransactions = 3;
  static const int tabProfile = 4;

  void setIndex(int index) {
    SafeGetx.debugTrace(
      className: 'ShellController',
      method: 'setIndex',
      feature: 'Navigation',
      status: 'INFO',
      params: {'fromTab': currentIndex.value, 'toTab': index},
    );
    currentIndex.value = index;
  }

  /// Handles smart back navigation.
  /// If the current navigator can pop, it pops (back to previous screen).
  /// Otherwise, if we are in a tab that is NOT home, we return to the Home tab.
  void handleBack() {
    SafeGetx.debugTrace(
      className: 'ShellController',
      method: 'handleBack',
      feature: 'Navigation',
      status: 'INFO',
      params: {'currentTab': currentIndex.value},
    );
    if (Navigator.canPop(Get.context!)) {
      Get.back();
    } else if (currentIndex.value != 0) {
      setIndex(0);
    }
  }
}
