import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:kasby/routes/app_routes.dart';

/// Enforces read-only mode for blocked/suspended users across the consumer app.
class AccountRestrictionService extends GetxService {
  static AccountRestrictionService get to => Get.find();

  final RxBool showRestrictionBanner = false.obs;
  bool _deletedDialogShown = false;

  bool get isBlocked {
    final status = HomeController.to.profile.value?.status.toLowerCase();
    return status == 'blocked';
  }

  bool get isSuspended {
    final status = HomeController.to.profile.value?.status.toLowerCase();
    return status == 'suspended';
  }

  bool get isRestricted => isBlocked || isSuspended;

  bool get isWalletFrozen =>
      HomeController.to.dashboard.value?.isFrozen ?? false;

  bool get canWrite => !isRestricted && !isWalletFrozen;

  String get restrictionReason {
    final reason = HomeController.to.profile.value?.statusReason;
    if (reason != null && reason.trim().isNotEmpty) return reason.trim();
    return 'غير محدد';
  }

  String get restrictionTitle => 'تم تقييد حسابك';

  String get restrictionMessage =>
      'تم تقييد حسابك بواسطة إدارة النظام.\n'
      'السبب: $restrictionReason\n\n'
      'إذا كنت تعتقد أن هذا الإجراء تم بالخطأ، يرجى التواصل مع الدعم.';

  void onProfileUpdated() {
    showRestrictionBanner.value = isRestricted;
  }

  bool checkWriteAccess({bool showDialog = true}) {
    if (!SupabaseService.isLoggedIn) return false;
    if (canWrite) return true;
    if (showDialog) showRestrictionDialog();
    return false;
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
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('حسناً'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              if (Get.currentRoute != Routes.support) {
                Get.toNamed(Routes.support);
              }
            },
            child: const Text('التواصل مع الدعم'),
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
          title: const Text(
            'تم حذف الحساب',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'تم حذف حسابك بواسطة إدارة النظام.\n'
            'إذا كنت تعتقد أن هذا الإجراء تم بالخطأ، يرجى التواصل مع الدعم.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Get.back();
                await AuthController.to.logout();
              },
              child: const Text('حسناً'),
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
        msg.contains('تم تقييد حسابك');
  }

  static void handleOperationError(Object error) {
    if (isRestrictionError(error)) {
      to.showRestrictionDialog();
    }
  }
}
