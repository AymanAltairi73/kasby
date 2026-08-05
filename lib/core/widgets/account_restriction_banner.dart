import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/services/account_restriction_service.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/routes/app_routes.dart';

/// Persistent banner shown when the user's account is restricted (read-only).
class AccountRestrictionBanner extends StatelessWidget {
  final Widget child;

  const AccountRestrictionBanner({super.key, required this.child});

  void _openSupportChat() {
    if (Get.currentRoute != Routes.supportChat) {
      Get.toNamed(Routes.supportChat);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final service = AccountRestrictionService.to;
      final show =
          service.showRestrictionBanner.value && service.isAccountRestricted;

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
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.94),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'account_restricted_title'.tr,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'account_restricted_readonly'.trParams({
                                'reason': service.restrictionReason,
                              }),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          onTap: _openSupportChat,
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'kasby_support'.tr,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }
}
