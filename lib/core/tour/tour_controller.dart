import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/shell_controller.dart';
import '../services/enterprise_operations_logger.dart';
import '../services/tour_service.dart';
import 'home_tour_config.dart';
import 'investments_tour_config.dart';
import 'lucky_wheel_tour_config.dart';
import 'marketplace_tour_config.dart';
import 'profile_tour_config.dart';
import 'qr_tour_config.dart';
import 'referral_tour_config.dart';
import 'social_tour_config.dart';
import 'tour_ids.dart';
import 'tour_manager.dart';
import 'tour_step.dart';
import 'tour_target_keys.dart';
import 'tour_target_readiness.dart';
import 'wallet_tour_config.dart';

/// GetX controller for lightweight, context-aware product tours.
class TourController extends GetxController {
  static TourController get to => Get.find<TourController>();

  final isRunning = false.obs;
  final currentStepIndex = 0.obs;
  final activeTourId = Rxn<TourId>();

  int _shellTabRequestId = 0;

  /// Enables auto tours (used by legacy guided-tour route).
  Future<void> requestHomeTour() => TourService.enableAutoToursForNewUser();

  /// Suppresses auto tours for returning users.
  Future<void> suppressAutoToursForExistingUser() =>
      TourService.disableAutoToursForExistingUser();

  /// Auto-starts the home tour for eligible new users once targets are ready.
  Future<void> tryStartAutoHomeTour(BuildContext context) async {
    if (isRunning.value) return;

    for (var attempt = 0; attempt < 5; attempt++) {
      if (!context.mounted || isRunning.value) return;

      if (!await TourTargetReadiness.waitForAuthenticatedUser()) continue;
      if (!await TourService.canAutoStartTour(TourId.home)) return;

      ShellController.to.setIndex(ShellController.tabHome);
      await ensureHomeTab();

      final ready = await TourTargetReadiness.waitFor(
        TourTargetKeys.welcome,
        maxFrames: attempt == 0 ? 120 : 180,
      );
      if (!ready || !context.mounted || isRunning.value) continue;
      if (!await TourService.canAutoStartTour(TourId.home)) return;

      await _startTour(
        context,
        tourId: TourId.home,
        steps: HomeTourConfig.steps,
      );

      if (isRunning.value) {
        EnterpriseOperationsLogger.log(
          domain: 'tutorial',
          operation: 'auto_home_tour',
          phase: 'STARTED',
          params: {'attempt': attempt + 1},
        );
        return;
      }
    }

    EnterpriseOperationsLogger.log(
      domain: 'tutorial',
      operation: 'auto_home_tour',
      phase: 'SKIPPED',
      status: 'WARN',
      params: {'reason': 'targets_not_ready'},
    );
  }

  /// Retries a pending post-signup home tour after navigation settles.
  Future<void> tryConsumePendingAutoHomeTour(BuildContext context) async {
    if (!TourService.consumePendingAutoHomeTour()) return;
    await tryStartAutoHomeTour(context);
  }

  /// Starts a shell-tab tour when a new user opens wallet / invest / profile.
  Future<void> tryStartShellTabTour(BuildContext context, int tabIndex) async {
    if (isRunning.value) return;

    final tourId = switch (tabIndex) {
      ShellController.tabWallet => TourId.wallet,
      ShellController.tabInvest => TourId.investments,
      ShellController.tabProfile => TourId.profile,
      _ => null,
    };
    if (tourId == null) return;
    if (!await TourService.canAutoStartTour(tourId)) return;

    final requestId = ++_shellTabRequestId;
    await TourTargetReadiness.waitFor(_firstTargetKey(tourId));
    if (requestId != _shellTabRequestId) return;
    if (!context.mounted || isRunning.value) return;
    if (ShellController.to.currentIndex.value != tabIndex) return;
    if (!await TourService.canAutoStartTour(tourId)) return;
    if (!context.mounted) return;

    final steps = _stepsFor(tourId);
    if (steps.isEmpty) return;
    await _startTour(context, tourId: tourId, steps: steps);
  }

  /// Context-aware tour for pushed routes (marketplace, social, QR, etc.).
  Future<void> tryStartFeatureTour(
    BuildContext context,
    TourId tourId,
  ) async {
    if (isRunning.value) return;
    if (!await TourService.canAutoStartTour(tourId)) return;

    final steps = _stepsFor(tourId);
    if (steps.isEmpty) return;

    await TourTargetReadiness.waitFor(steps.first.targetKey);
    if (!context.mounted || isRunning.value) return;
    if (!await TourService.canAutoStartTour(tourId)) return;
    if (!context.mounted) return;

    await _startTour(context, tourId: tourId, steps: steps);
  }

  Future<void> replayTour(BuildContext context, TourId tourId) async {
    if (isRunning.value) return;
    await TourService.resetTour(tourId);
    final steps = _stepsFor(tourId);
    if (steps.isEmpty) return;

    if (tourId == TourId.home ||
        tourId == TourId.wallet ||
        tourId == TourId.investments ||
        tourId == TourId.profile) {
      final tabIndex = switch (tourId) {
        TourId.home => ShellController.tabHome,
        TourId.wallet => ShellController.tabWallet,
        TourId.investments => ShellController.tabInvest,
        TourId.profile => ShellController.tabProfile,
        _ => ShellController.tabHome,
      };
      ShellController.to.setIndex(tabIndex);
      await TourTargetReadiness.waitFor(steps.first.targetKey);
    }

    if (!context.mounted) return;
    await _startTour(context, tourId: tourId, steps: steps);
  }

  Future<void> replayHomeTour(BuildContext context) =>
      replayTour(context, TourId.home);

  Future<void> resetAllTours() async {
    for (final id in TourId.values) {
      await TourService.resetTour(id);
    }
  }

  void dismissActiveTour() {
    TourManager.dismissActive();
    _resetRunningState();
  }

  GlobalKey _firstTargetKey(TourId tourId) =>
      _stepsFor(tourId).first.targetKey;

  List<TourStepDefinition> _stepsFor(TourId tourId) => switch (tourId) {
        TourId.home => HomeTourConfig.steps,
        TourId.investments => InvestmentsTourConfig.steps,
        TourId.wallet => WalletTourConfig.steps,
        TourId.marketplace => MarketplaceTourConfig.steps,
        TourId.social => SocialTourConfig.steps,
        TourId.qr => QrTourConfig.steps,
        TourId.luckyWheel => LuckyWheelTourConfig.steps,
        TourId.referral => ReferralTourConfig.steps,
        TourId.profile => ProfileTourConfig.steps,
      };

  Future<void> _startTour(
    BuildContext context, {
    required TourId tourId,
    required List<TourStepDefinition> steps,
  }) async {
    if (!context.mounted || isRunning.value) return;

    isRunning.value = true;
    activeTourId.value = tourId;

    final lastStep = await TourService.getLastStep(tourId);
    if (!context.mounted) {
      _resetRunningState();
      return;
    }

    final resumeIndex = lastStep > 0 && lastStep < steps.length ? lastStep : 0;
    currentStepIndex.value = resumeIndex;

    final started = await TourManager.startTour(
      context: context,
      steps: steps,
      tourId: tourId,
      startAtStep: resumeIndex,
      onStepChanged: (index) => currentStepIndex.value = index,
      onComplete: _resetRunningState,
    );

    if (!started) {
      _resetRunningState();
    }
  }

  void _resetRunningState() {
    isRunning.value = false;
    activeTourId.value = null;
  }

  static Future<void> scrollHomeTargetIntoView(GlobalKey key) async {
    final ctx = key.currentContext;
    if (ctx == null) return;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      alignment: 0.35,
    );
    await TourTargetReadiness.waitFor(key, maxFrames: 8);
  }

  static Future<void> ensureHomeTab() async {
    ShellController.to.setIndex(ShellController.tabHome);
    await TourTargetReadiness.waitFor(TourTargetKeys.welcome, maxFrames: 12);
    if (TourTargetKeys.homeScroll.hasClients) {
      await TourTargetKeys.homeScroll.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  static Future<void> scrollTargetIntoView(GlobalKey key) async {
    final ctx = key.currentContext;
    if (ctx == null) return;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      alignment: 0.35,
    );
    await TourTargetReadiness.waitFor(key, maxFrames: 8);
  }
}
