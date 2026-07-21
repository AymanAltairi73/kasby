import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart' as intl;
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_card.dart';
import 'package:kasby/core/widgets/kasby_shimmer.dart';
import 'package:kasby/routes/app_routes.dart';
import '../controllers/agent_conversations_controller.dart';

class AgentConversationsView extends GetView<AgentConversationsController> {
  const AgentConversationsView({super.key});

  bool _isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _isDarkMode(context);
    return Scaffold(
      backgroundColor: isDark ? AppColors.background : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'users_chats'.tr,
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.textBodyLight,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : AppColors.textBodyLight,
          ),
          onPressed: () => Get.back(),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(context, isDark),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value && controller.conversations.isEmpty) {
                return _buildShimmerLoading(isDark);
              }

              final filteredList = controller.filteredConversations;
              if (filteredList.isEmpty) {
                return _buildEmptyState(isDark);
              }

              return RefreshIndicator(
                onRefresh: () => controller.fetchConversations(showLoading: true),
                color: AppColors.darkGold,
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final conv = filteredList[index];
                    return _buildConversationCard(context, conv, isDark);
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surface : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.surface : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: TextField(
          onChanged: (value) => controller.searchQuery.value = value,
          decoration: InputDecoration(
            hintText: 'search_users'.tr,
            hintStyle: TextStyle(
              color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
            ),
            suffixIcon: controller.searchQuery.value.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear_rounded,
                      color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                    ),
                    onPressed: () => controller.searchQuery.value = '',
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.textBodyLight,
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerLoading(bool isDark) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => KasbyShimmer(
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: isDark ? AppColors.surface : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.darkGold.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: AppColors.darkGold,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'no_conversations'.tr,
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.textBodyLight,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'no_conversations_desc'.tr,
                style: TextStyle(
                  color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConversationCard(BuildContext context, Map<String, dynamic> conv, bool isDark) {
    final profilesData = conv['profiles'];
    final profile = profilesData is Map<String, dynamic> ? profilesData : null;
    final fullName = profile?['full_name'] as String? ?? 'user'.tr;
    final avatarUrl = profile?['avatar_url'] as String?;
    // final referralCode = profile?['referral_code'] as String?;
    final lastMessage = conv['last_message'] as String? ?? '';
    final lastMessageAtStr = conv['last_message_at'] as String?;
    final unreadCount = conv['unread_admin_count'] as int? ?? 0;
    final userId = conv['user_id'] as String?;

    String timeText = '';
    if (lastMessageAtStr != null) {
      try {
        final lastMessageAt = DateTime.parse(lastMessageAtStr).toLocal();
        final now = DateTime.now();
        if (now.difference(lastMessageAt).inDays == 0) {
          timeText = intl.DateFormat.jm().format(lastMessageAt);
        } else if (now.difference(lastMessageAt).inDays == 1) {
          timeText = 'yesterday'.tr;
        } else {
          timeText = intl.DateFormat.yMd().format(lastMessageAt);
        }
      } catch (_) {}
    }

    // Presence status
    final isOnline = userId != null && controller.isUserOnline(userId);
    final presenceText = userId != null ? controller.getLastSeen(userId) : '';
    final presenceStatus = userId != null ? controller.getPresenceStatus(userId) : 'offline';

    return KasbyCard(
      color: isDark ? AppColors.surface : AppColors.surfaceLight,
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          if (unreadCount > 0) {
            await controller.markConversationAsRead(conv['id']);
          }
          
          Get.toNamed(
            Routes.socialChat,
            arguments: {
              'is_agent_chat': true,
              'conversation_id': conv['id'],
              'user_id': conv['user_id'],
              'user_name': fullName,
              'conversation': conv,
            },
          );
        },
        child: Row(
          children: [
            _buildAvatar(fullName, avatarUrl, isOnline, isDark),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    //mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullName,
                              style: TextStyle(
                                color: isDark ? Colors.white : AppColors.textBodyLight,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              // maxLines: 1,
                              // overflow: TextOverflow.ellipsis,
                            ),
                            // if (referralCode != null && referralCode.isNotEmpty) ...[
                            //   const SizedBox(height: 2),
                            //   Text(
                            //     'referral_code'.trParams({'code': referralCode}),
                            //     style: TextStyle(
                            //       color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                            //       fontSize: 11,
                            //     ),
                            //   ),
                            // ],
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          if (timeText.isNotEmpty)
                            Text(
                              timeText,
                              style: TextStyle(
                                color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                                fontSize: 8,
                              ),
                            ),
                          const SizedBox(width: 4),
                          PopupMenuButton<String>(
                            icon: Icon(
                              Icons.more_vert_rounded,
                              color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                              size: 17,
                            ),
                            onSelected: (value) async {
                              if (value == 'delete') {
                                final confirmed = await Get.dialog<bool>(
                                  AlertDialog(
                                    title: Text('delete_conversation'.tr),
                                    content: Text('delete_conversation_confirm'.tr),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Get.back(result: false),
                                        child: Text('cancel'.tr),
                                      ),
                                      TextButton(
                                        onPressed: () => Get.back(result: true),
                                        child: Text(
                                          'delete'.tr,
                                          style: const TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  try {
                                    await controller.deleteConversation(conv['id']);
                                    Get.snackbar(
                                      'success'.tr,
                                      'conversation_deleted'.tr,
                                      snackPosition: SnackPosition.BOTTOM,
                                      backgroundColor: AppColors.softGreen,
                                      colorText: Colors.white,
                                    );
                                  } catch (e) {
                                    Get.snackbar(
                                      'error'.tr,
                                      'delete_conversation_failed'.tr,
                                      snackPosition: SnackPosition.BOTTOM,
                                      backgroundColor: Colors.red,
                                      colorText: Colors.white,
                                    );
                                  }
                                }
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    const Icon(Icons.delete_rounded, size: 18),
                                    const SizedBox(width: 8),
                                    Text('delete_conversation'.tr),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMessage,
                          style: TextStyle(
                            color: unreadCount > 0
                                ? (isDark ? Colors.white : AppColors.textBodyLight)
                                : (isDark ? AppColors.textSecondary : AppColors.textSecondaryLight),
                            fontSize: 12,
                            fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unreadCount > 0) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.darkGold,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (presenceText != null && presenceText.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _getPresenceColor(presenceStatus),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          presenceText,
                          style: TextStyle(
                            color: _getPresenceColor(presenceStatus),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String fullName, String? avatarUrl, bool isOnline, bool isDark) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (avatarUrl != null && avatarUrl.isNotEmpty)
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.transparent,
            child: ClipOval(
              child: CachedNetworkImage(
                imageUrl: avatarUrl,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: AppColors.darkGold.withValues(alpha: 0.1),
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
                errorWidget: (context, url, error) => _buildInitialsAvatar(fullName, isDark),
              ),
            ),
          )
        else
          _buildInitialsAvatar(fullName, isDark),
        if (isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.softGreen,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? AppColors.surface : Colors.white,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInitialsAvatar(String name, bool isDark) {
    final initials = name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();
    return CircleAvatar(
      radius: 28,
      backgroundColor: AppColors.darkGold.withValues(alpha: 0.15),
      child: Text(
        initials.isNotEmpty ? initials : 'U',
        style: TextStyle(
          color: AppColors.darkGold,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }

  Color _getPresenceColor(String status) {
    switch (status) {
      case 'online':
      case 'active_now':
        return AppColors.softGreen;
      case 'last_seen_just_now':
      case 'last_seen_minutes_ago':
        return Colors.orange;
      case 'last_seen_hours_ago':
        return Colors.orange.shade700;
      default:
        return AppColors.textSecondary;
    }
  }
}
