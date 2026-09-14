import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/models/agent_model.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';
import 'package:kasby/core/theme/kasby_typography.dart';
import 'package:kasby/core/widgets/agent_status_badge.dart';
import 'package:kasby/core/widgets/directional_chevron.dart';
import 'package:kasby/core/widgets/kasby_card.dart';
import 'package:kasby/core/widgets/kasby_profile_avatar.dart';

class AgentCard extends StatelessWidget {
  const AgentCard({
    super.key,
    required this.agent,
    required this.isDark,
    required this.onTap,
    required this.onChat,
    this.unreadCount = 0,
  });

  final AgentModel agent;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onChat;
  final int unreadCount;

  bool get _isVerified =>
      agent.kycStatus == 'verified' || agent.status == 'active';

  Color _statusColor(String status) {
    switch (status) {
      case 'available':
        return AppColors.softGreen;
      case 'busy':
        return Colors.orange;
      case 'unavailable':
        return AppColors.textSecondary;
      default:
        return AppColors.textSecondary;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'available':
        return 'status_available'.tr;
      case 'busy':
        return 'status_busy'.tr;
      case 'unavailable':
        return 'status_unavailable'.tr;
      default:
        return 'status_unavailable'.tr;
    }
  }

  Widget _metaChip({
    BuildContext? context,
    required String label,
    required Color color,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: KasbyTypography.badge(context),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final location = [
      agent.city,
      agent.country,
    ].where((part) => part.trim().isNotEmpty).join(', ');

    return Semantics(
      button: true,
      label: agent.name,
      child: KasbyCard(
        padding: const EdgeInsets.all(KasbySpacing.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: KasbyRadius.cardR,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KasbyProfileAvatar(
                name: agent.name,
                imageUrl: agent.avatarUrl,
                radius: 28,
                isOnline: agent.isAvailableNow,
                showOnlineIndicator: true,
              ),
              const SizedBox(width: KasbySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            agent.name,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: KasbyTypography.sp(
                                ar: 16.0,
                                en: 14.5,
                                context: context,
                              ),
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : AppColors.textBodyLight,
                            ),
                          ),
                        ),
                        if (_isVerified) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.verified_rounded,
                            color: Colors.blueAccent.shade400,
                            size: 16,
                            semanticLabel: 'verified_agent'.tr,
                          ),
                        ],
                      ],
                    ),
                    if (agent.username != null &&
                        agent.username!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '@${agent.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    AgentStatusBadge(
                      isOnline: agent.isAvailableNow,
                      compact: true,
                    ),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 12,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _metaChip(
                          context: context,
                          label: 'agent'.tr,
                          color: AppColors.darkGold,
                          icon: Icons.badge_outlined,
                        ),
                        _metaChip(
                          context: context,
                          label: _statusText(agent.availabilityStatus),
                          color: _statusColor(agent.availabilityStatus),
                        ),
                        if (agent.successRate > 0)
                          _metaChip(
                            context: context,
                            label: 'success_rate'.trParams({
                              'rate':
                                  '${agent.successRate.toStringAsFixed(0)}%',
                            }),
                            color: AppColors.softGreen,
                            icon: Icons.star_rounded,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: AppColors.darkGold,
                          size: 22,
                        ),
                        tooltip: 'send_message'.tr,
                        onPressed: onChat,
                        style: IconButton.styleFrom(
                          minimumSize: const Size(40, 40),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.darkGold,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.surface
                                    : AppColors.surfaceLight,
                                width: 2,
                              ),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : '$unreadCount',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  DirectionalChevron(size: 18, color: AppColors.textSecondary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
