import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/controllers/currency_controller.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:kasby/routes/app_routes.dart';

/// Enforces read-only mode for blocked/suspended users and wallet freeze separately.
class AccountRestrictionService extends GetxService {
  static AccountRestrictionService get to => Get.find();

  final RxBool showRestrictionBanner = false.obs;
  bool _deletedDialogShown = false;

  /// Blocked or suspended — account-level restriction only.
  bool get isBlocked {
    final status = HomeController.to.profile.value?.status.toLowerCase();
    return status == 'blocked';
  }

  bool get isSuspended {
    final status = HomeController.to.profile.value?.status.toLowerCase();
    return status == 'suspended';
  }

  bool get isAccountRestricted => isBlocked || isSuspended;

  /// Wallet freeze — separate from account restriction; agents with active
  /// profiles must not be treated as account-restricted when only frozen.
  bool get isWalletFrozen {
    if (Get.isRegistered<CurrencyController>()) {
      return CurrencyController.to.isWalletFrozen.value;
    }
    return HomeController.to.dashboard.value?.isFrozen ?? false;
  }

  String? get walletFrozenReason {
    if (Get.isRegistered<CurrencyController>()) {
      return CurrencyController.to.walletFrozenReason.value;
    }
    return HomeController.to.dashboard.value?.frozenReason;
  }

  bool get canWrite => !isAccountRestricted && !isWalletFrozen;

  String get restrictionReason {
    final reason = HomeController.to.profile.value?.statusReason;
    if (reason != null && reason.trim().isNotEmpty) return reason.trim();
    return 'account_restriction_reason_unspecified'.tr;
  }

  String get walletFrozenMessage => 'wallet_frozen_message'.trParams({
    'reason': walletFrozenReason?.trim().isNotEmpty == true
        ? walletFrozenReason!.trim()
        : 'account_restriction_reason_unspecified'.tr,
  });

  String get restrictionTitle => 'account_restricted_title'.tr;

  String get restrictionMessage =>
      'account_restricted_message'.trParams({'reason': restrictionReason});

  void openSupportChat() {
    if (Get.currentRoute != Routes.supportChat) {
      Get.toNamed(Routes.supportChat);
    }
  }

  void onProfileUpdated() {
    showRestrictionBanner.value = isAccountRestricted;
  }

  /// Refreshes profile, dashboard, and wallet freeze state from the server.
  Future<void> syncRestrictionStateFromServer() async {
    if (!SupabaseService.isLoggedIn) return;

    await Future.wait([
      HomeController.to.fetchProfile(),
      HomeController.to.fetchDashboard(),
      if (Get.isRegistered<CurrencyController>())
        CurrencyController.to.fetchWalletBalances(),
    ]);

    try {
      final response = await SupabaseService.client.rpc(
        'fn_get_account_write_access',
      );
      if (response is! Map) return;

      final payload = Map<String, dynamic>.from(response);
      final restrictionType = payload['restriction_type']?.toString() ?? 'none';
      final reason = payload['reason']?.toString();

      if (restrictionType == 'wallet_frozen') {
        if (Get.isRegistered<CurrencyController>()) {
          CurrencyController.to.isWalletFrozen.value = true;
          if (reason != null && reason.isNotEmpty) {
            CurrencyController.to.walletFrozenReason.value = reason;
          }
        }
        HomeController.to.syncDashboardFreezeState(
          isFrozen: true,
          frozenReason: reason,
        );
      } else if (payload['can_write'] == true &&
          Get.isRegistered<CurrencyController>()) {
        CurrencyController.to.isWalletFrozen.value = false;
        CurrencyController.to.walletFrozenReason.value = null;
        HomeController.to.syncDashboardFreezeState(isFrozen: false);
      }
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'AccountRestrictionService',
        method: 'syncRestrictionStateFromServer',
        feature: 'Core',
        status: 'WARN',
        error: e,
        stackTrace: stack,
      );
    }

    onProfileUpdated();
  }

  /// Authoritative pre-flight check before financial writes.
  Future<bool> checkWriteAccessAsync({bool showDialog = true}) async {
    if (!SupabaseService.isLoggedIn) return false;

    await syncRestrictionStateFromServer();
    return checkWriteAccess(showDialog: showDialog);
  }

  bool checkWriteAccess({bool showDialog = true}) {
    if (!SupabaseService.isLoggedIn) return false;

    if (isAccountRestricted) {
      if (showDialog) showRestrictionDialog();
      return false;
    }

    if (isWalletFrozen) {
      if (showDialog) showWalletFrozenDialog();
      return false;
    }

    return true;
  }

  void showRestrictionDialog() {
    if (Get.isDialogOpen == true) return;
    Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.gpp_maybe_rounded, color: AppColors.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                restrictionTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          restrictionMessage,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('ok'.tr)),
          TextButton.icon(
            onPressed: () {
              Get.back();
              openSupportChat();
            },
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
            label: Text('kasby_support'.tr),
          ),
        ],
      ),
      barrierDismissible: true,
    );
  }

  void showWalletFrozenDialog() {
    if (Get.isDialogOpen == true) return;
    Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.ac_unit_rounded, color: AppColors.darkGold),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'wallet_frozen_title'.tr,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          walletFrozenMessage,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('ok'.tr)),
          TextButton.icon(
            onPressed: () {
              Get.back();
              openSupportChat();
            },
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
            label: Text('kasby_support'.tr),
          ),
        ],
      ),
      barrierDismissible: true,
    );
  }

  Future<void> handleDeletedAccount() async {
    if (_deletedDialogShown) return;
    _deletedDialogShown = true;

    SafeGetx.debugTrace(
      className: 'AccountRestrictionService',
      method: 'handleDeletedAccount',
      feature: 'Auth',
      status: 'WARN',
      message: 'Profile missing — account likely deleted by admin',
    );

    await Get.dialog(
      PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            'account_deleted_by_admin_title'.tr,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'account_deleted_by_admin_message'.tr,
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Get.back();
                await AuthController.to.logout();
              },
              child: Text('ok'.tr),
            ),
          ],
        ),
      ),
      barrierDismissible: false,
    );
  }

  static bool isRestrictionError(Object error) {
    final msg = error.toString();
    return msg.contains('ACCOUNT_RESTRICTED') ||
        msg.contains('PERMISSION_DENIED: Account is blocked') ||
        msg.contains('PERMISSION_DENIED: Account is suspended') ||
        msg.contains('تم تقييد حسابك');
  }

  static void handleOperationError(Object error) {
    final msg = error.toString();
    if (isRestrictionError(error)) {
      to.showRestrictionDialog();
      return;
    }
    if (msg.contains('Wallet is frozen') ||
        msg.contains('PERMISSION_DENIED: Wallet is frozen')) {
      to.showWalletFrozenDialog();
    }
  }
}
