import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';
import 'package:kasby/core/utils/date_helper.dart';
import 'package:kasby/core/widgets/kasby_card.dart';
import 'package:kasby/core/services/presence_service.dart';

/// Bottom sheet with detailed team member profile.
class TeamMemberProfileSheet extends StatelessWidget {
  const TeamMemberProfileSheet({super.key, required this.member});

  final Map<String, dynamic> member;

  static Future<void> show(Map<String, dynamic> member) {
    return Get.bottomSheet(
      TeamMemberProfileSheet(member: member),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final id = member['id']?.toString() ?? '';
    final isOnline =
        Get.isRegistered<PresenceService>() &&
        Get.find<PresenceService>().isUserOnline(id);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surface : Colors.white,
            borderRadius: KasbyRadius.sheetR,
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(
              KasbySpacing.lg,
              KasbySpacing.md,
              KasbySpacing.lg,
              bottom + KasbySpacing.lg,
            ),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: KasbySpacing.lg),
              _header(isDark, isOnline),
              const SizedBox(height: KasbySpacing.lg),
              _section('personal_information'.tr, [
                _row('full_name'.tr, member['full_name']?.toString() ?? '—'),
                _row('username'.tr, '@${member['referral_code'] ?? '—'}'),
                _row('referral_level'.tr, 'L${member['level'] ?? 1}'),
                if (member['created_at'] != null)
                  _row(
                    'registration_date'.tr,
                    DateHelper.dateTime(
                      DateTime.parse(member['created_at'].toString()),
                    ),
                  ),
                _row(
                  'online_status'.tr,
                  isOnline ? 'online_now'.tr : 'offline'.tr,
                ),
              ]),
              const SizedBox(height: KasbySpacing.md),
              _section('referral_statistics'.tr, [
                _row(
                  'direct_referrals'.tr,
                  '${member['direct_referrals'] ?? 0}',
                ),
                _row(
                  'referral_earnings'.tr,
                  '\$${(member['referral_earnings'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                ),
              ]),
              const SizedBox(height: KasbySpacing.md),
              _section('investment_statistics'.tr, [
                _row(
                  'investment'.tr,
                  '\$${(member['investment_amount'] as num?)?.toStringAsFixed(0) ?? '0'}',
                ),
                _row(
                  'status'.tr,
                  member['status']?.toString() == 'active'
                      ? 'active'.tr
                      : 'inactive'.tr,
                ),
              ]),
            ],
          ),
        );
      },
    ).animate().fadeIn(duration: KasbyMotion.fast);
  }

  Widget _header(bool isDark, bool isOnline) {
    return Row(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundImage: member['avatar_url'] != null
                  ? NetworkImage(member['avatar_url'].toString())
                  : null,
              child: member['avatar_url'] == null
                  ? Text(
                      (member['full_name']?.toString() ?? '?')[0],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    )
                  : null,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: isOnline ? AppColors.softGreen : Colors.grey,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: KasbySpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                member['full_name']?.toString() ?? '—',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: isDark ? Colors.white : AppColors.onSurfaceLight,
                ),
              ),
              Text(
                '@${member['referral_code'] ?? '—'}',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: KasbySpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: KasbySpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.darkGold.withValues(alpha: 0.15),
                  borderRadius: KasbyRadius.chipR,
                ),
                child: Text(
                  'L${member['level'] ?? 1}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkGold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _section(String title, List<Widget> rows) {
    return KasbyCard(
      padding: const EdgeInsets.all(KasbySpacing.md),
      borderRadius: KasbyRadius.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: KasbySpacing.sm),
          ...rows,
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: KasbySpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
