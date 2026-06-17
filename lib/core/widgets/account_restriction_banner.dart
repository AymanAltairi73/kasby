import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/services/account_restriction_service.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/routes/app_routes.dart';

/// Persistent banner shown when the user's account is restricted (read-only).
class AccountRestrictionBanner extends StatelessWidget {
  final Widget child;

  const AccountRestrictionBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final service = AccountRestrictionService.to;
      final show = service.showRestrictionBanner.value && service.isRestricted;

      return Stack(
        children: [
          child,
          if (show)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 4,
              left: 12,
              right: 12,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: service.showRestrictionDialog,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lock_outline_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'account_restricted_readonly'.trParams({
                              'reason': service.restrictionReason,
                            }),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Get.toNamed(Routes.support),
                          child: Text(
                            'support'.tr,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }
}
