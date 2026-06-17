import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/services/referral_service.dart';
import 'package:kasby/core/services/presence_service.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:share_plus/share_plus.dart';
import 'package:kasby/core/widgets/kasby_shimmer.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/routes/app_routes.dart';

class MyTeamView extends StatefulWidget {
  const MyTeamView({super.key});

  @override
  State<MyTeamView> createState() => _MyTeamViewState();
}

class _MyTeamViewState extends State<MyTeamView> {
  bool _isLoading = true;
  String? _errorMessage;
  String _myReferralCode = '';
  int _totalMembers = 0;
  int _activeMembers = 0;
  int _inactiveMembers = 0;
  int _newToday = 0;
  List<Map<String, dynamic>> _treeNodes = [];
  List<Map<String, dynamic>> _friends = [];

  @override
  void initState() {
    super.initState();
    SafeGetx.debugTrace(
      className: 'MyTeamView',
      method: 'initState',
      feature: 'Profile',
      status: 'INFO',
    );
    _myReferralCode = ReferralService.formatDisplayCode(
      HomeController.to.profile.value?.referralCode,
    );
    _fetchTeamData();
  }

  List<Map<String, dynamic>> get _allTreeNodes {
    if (_treeNodes.isNotEmpty) return _treeNodes;

    final userId = SupabaseService.userId ?? '';
    return _friends.map((friend) {
      return {
        'id': friend['id'],
        'full_name': friend['full_name'],
        'avatar_url': friend['avatar_url'],
        'created_at': friend['created_at'],
        'status': friend['status'],
        'referral_code': friend['referral_code'],
        'parent_id': userId,
        'level': 1,
        'member_type': 'friend',
        'direct_referrals': 0,
        'sub_referrals': 0,
      };
    }).toList();
  }

  bool get _hasTeamContent => _allTreeNodes.isNotEmpty || _friends.isNotEmpty;

  int get _onlineCount {
    if (!Get.isRegistered<PresenceService>()) return 0;
    final presence = Get.find<PresenceService>();
    final ids = <String>{
      ..._allTreeNodes.map((n) => n['id']?.toString()).whereType<String>(),
      ..._friends.map((f) => f['id']?.toString()).whereType<String>(),
    };
    return ids.where(presence.isUserOnline).length;
  }

  Future<void> _fetchTeamData() async {
    final stopwatch = Stopwatch()..start();
    setState(() => _errorMessage = null);
    try {
      final result = await SupabaseService.client.rpc('get_my_team');

      if (result == null || result is! Map) {
        throw Exception('get_my_team returned invalid data');
      }

      final response = Map<String, dynamic>.from(result);

      if (response['success'] == true) {
        if (mounted) {
          setState(() {
            final rpcCode = response['my_referral_code'] as String?;
            if (rpcCode != null && rpcCode.isNotEmpty) {
              _myReferralCode = ReferralService.formatDisplayCode(rpcCode);
            } else if (_myReferralCode.isEmpty) {
              _myReferralCode = ReferralService.formatDisplayCode(
                HomeController.to.profile.value?.referralCode,
              );
            }

            _totalMembers = response['total_members'] as int? ?? 0;
            _activeMembers = response['active_members'] as int? ?? 0;
            _inactiveMembers = response['inactive_members'] as int? ?? 0;
            _newToday = response['new_today'] as int? ?? 0;
            _treeNodes = List<Map<String, dynamic>>.from(
              response['tree'] ?? response['members'] ?? [],
            );
            _friends = List<Map<String, dynamic>>.from(
              response['friends'] ?? [],
            );
          });
        }
        SafeGetx.debugTrace(
          className: 'MyTeamView',
          method: '_fetchTeamData',
          feature: 'Profile',
          status: 'SUCCESS',
          durationMs: stopwatch.elapsedMilliseconds,
          params: {
            'totalMembers': _totalMembers,
            'treeNodes': _treeNodes.length,
            'displayNodes': _allTreeNodes.length,
            'friends': _friends.length,
          },
        );
      } else {
        throw Exception(response['error']?.toString() ?? 'Unknown error');
      }
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'MyTeamView',
        method: '_fetchTeamData',
        feature: 'Profile',
        status: 'ERROR',
        durationMs: stopwatch.elapsedMilliseconds,
        error: e,
        stackTrace: stack,
      );
      if (mounted) {
        setState(() {
          _errorMessage = 'unknown_error'.tr;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          isDark ? AppColors.background : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('my_team'.tr),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Get.back(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard_rounded),
            tooltip: 'referral_analytics'.tr,
            onPressed: () => Get.toNamed(Routes.referralAnalytics),
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingSkeleton()
          : _errorMessage != null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _fetchTeamData,
                  color: AppColors.darkGold,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    child: Column(
                      children: [
                        _buildReferralCodeCard(),
                        const SizedBox(height: 24),
                        Obx(() => _buildStatsDashboard()),
                        const SizedBox(height: 32),
                        _buildSectionHeader('tree_view'.tr),
                        const SizedBox(height: 16),
                        _buildUnifiedTeamTree(),
                        const SizedBox(height: 60),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: [
          const KasbyShimmer.card(height: 140),
          const SizedBox(height: 24),
          Row(
            children: const [
              Expanded(child: KasbyShimmer.card(height: 90)),
              SizedBox(width: 12),
              Expanded(child: KasbyShimmer.card(height: 90)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              Expanded(child: KasbyShimmer.card(height: 90)),
              SizedBox(width: 12),
              Expanded(child: KasbyShimmer.card(height: 90)),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: ListView.separated(
              itemCount: 5,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (_, __) => const KasbyShimmer.listItem(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 56, color: AppColors.error.withValues(alpha: 0.7)),
            const SizedBox(height: 16),
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                setState(() => _isLoading = true);
                _fetchTeamData();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: Text('app_error_retry'.tr),
              style: FilledButton.styleFrom(backgroundColor: AppColors.darkGold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferralCodeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: AppColors.goldGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.darkGold.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.share_rounded, size: 32, color: Colors.black),
          const SizedBox(height: 12),
          Text(
            'my_referral_code'.tr,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _myReferralCode.isNotEmpty ? _myReferralCode : '---',
            style: const TextStyle(
              color: Colors.black,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildActionChip(Icons.copy_rounded, 'copy'.tr, () {
                Clipboard.setData(ClipboardData(text: _myReferralCode));
                HapticFeedback.lightImpact();
                Get.snackbar(
                  'success'.tr,
                  'referral_code_copied'.tr,
                  backgroundColor:
                      AppColors.softGreen.withValues(alpha: 0.9),
                  colorText: Colors.white,
                );
              }),
              const SizedBox(width: 12),
              _buildActionChip(Icons.share_rounded, 'share'.tr, () {
                SharePlus.instance.share(
                  ShareParams(
                    text:
                        '${'invite_share_text'.tr} $_myReferralCode\nhttps://kasby.app/join?ref=$_myReferralCode',
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildActionChip(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.black),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsDashboard() {
    final online = _onlineCount;
    final stats = [
      ('team_members_count'.tr, '$_totalMembers', Icons.groups_rounded,
          Colors.blueAccent),
      ('active_members'.tr, '$_activeMembers', Icons.verified_rounded,
          AppColors.softGreen),
      ('inactive_members'.tr, '$_inactiveMembers', Icons.person_off_rounded,
          AppColors.error),
      ('new_today'.tr, '$_newToday', Icons.person_add_alt_1_rounded,
          AppColors.darkGold),
      ('online_members'.tr, '$online', Icons.circle, AppColors.softGreen),
    ];

    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width >= 900 ? 3 : 2;
    final aspectRatio = width >= 600 ? 1.85 : 1.65;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: aspectRatio,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        return _buildStatCard(stat.$1, stat.$2, stat.$3, stat.$4)
            .animate()
            .fadeIn(
              duration: const Duration(milliseconds: 400),
              delay: Duration(milliseconds: 60 * index),
            );
      },
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surface.withValues(alpha: 0.5)
            : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.textBodyLight,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark
                      ? AppColors.textSecondary
                      : AppColors.textSecondaryLight,
                  fontSize: 11,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.darkGold,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textBodyLight,
          ),
        ),
      ],
    );
  }

  Widget _buildUnifiedTeamTree() {
    if (!_hasTeamContent) {
      return _buildEmptyTeamState();
    }

    final nodes = _allTreeNodes;
    final childrenByParent = <String, List<Map<String, dynamic>>>{};
    final userId = SupabaseService.userId ?? '';
    for (final node in nodes) {
      final parentId = node['parent_id']?.toString() ?? userId;
      childrenByParent.putIfAbsent(parentId, () => []).add(node);
    }

    return Column(
      children: [
        _buildTreeNodeCard(
          name: HomeController.to.profile.value?.fullName ?? 'You',
          initials: _getInitials(
            HomeController.to.profile.value?.fullName ?? 'Y',
          ),
          isRoot: true,
          isActive: true,
          isOnline: true,
          isFriend: false,
          subCount: _totalMembers,
          level: 0,
        ),
        if (nodes.isNotEmpty) _buildVerticalLine(),
        ..._buildTreeLevel(childrenByParent, userId, 0),
      ],
    ).animate().fadeIn(delay: const Duration(milliseconds: 200));
  }

  List<Widget> _buildTreeLevel(
    Map<String, List<Map<String, dynamic>>> childrenByParent,
    String parentId,
    int depth,
  ) {
    final children = childrenByParent[parentId] ?? [];
    if (children.isEmpty || depth > 4) return [];

    return children.asMap().entries.expand((entry) {
      final index = entry.key;
      final member = entry.value;
      final id = member['id']?.toString() ?? '';
      final name = member['full_name']?.toString() ?? 'user'.tr;
      final isActive = member['status']?.toString() == 'active';
      final level = member['level'] as int? ?? 1;
      final directRefs = member['direct_referrals'] as int? ??
          member['sub_referrals'] as int? ??
          0;
      final isOnline = Get.isRegistered<PresenceService>() &&
          Get.find<PresenceService>().isUserOnline(id);
      final isFriend = member['member_type']?.toString() == 'friend';

      return [
        Padding(
          padding: EdgeInsets.only(left: (level - 1) * 20.0, bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                child: Column(
                  children: [
                    Container(
                      width: 2,
                      height: 24,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.08),
                    ),
                    Container(
                      width: 10,
                      height: 2,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.08),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTreeNodeCard(
                      name: name,
                      initials: _getInitials(name),
                      isRoot: false,
                      isActive: isActive,
                      isOnline: isOnline,
                      isFriend: isFriend,
                      subCount: directRefs,
                      level: level,
                    ),
                    ..._buildTreeLevel(childrenByParent, id, depth + 1),
                  ],
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: Duration(milliseconds: 80 * index)),
      ];
    }).toList();
  }

  Widget _buildTreeNodeCard({
    required String name,
    required String initials,
    required bool isRoot,
    required bool isActive,
    required bool isOnline,
    required bool isFriend,
    required int subCount,
    required int level,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surface.withValues(alpha: isRoot ? 0.7 : 0.45)
            : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRoot
              ? AppColors.darkGold.withValues(alpha: 0.35)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.05)),
        ),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: isRoot ? 26 : 22,
                backgroundColor: isRoot
                    ? AppColors.darkGold
                    : AppColors.darkGold.withValues(alpha: 0.15),
                child: Text(
                  initials,
                  style: TextStyle(
                    color: isRoot ? Colors.black : AppColors.darkGold,
                    fontWeight: FontWeight.bold,
                    fontSize: isRoot ? 16 : 14,
                  ),
                ),
              ),
              if (isOnline)
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.softGreen,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? AppColors.background : Colors.white,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isRoot ? 15 : 14,
                    color: isDark ? Colors.white : AppColors.textBodyLight,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildStatusDot(isActive),
                    const SizedBox(width: 6),
                    Text(
                      isActive ? 'active'.tr : 'inactive'.tr,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    if (level > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        'L$level',
                        style: TextStyle(
                          color: AppColors.darkGold.withValues(alpha: 0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (subCount > 0) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.people_outline,
                          size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 2),
                      Text(
                        '$subCount',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (isFriend) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.handshake_outlined,
                          size: 13, color: AppColors.darkGold),
                      const SizedBox(width: 2),
                      Text(
                        'friend'.tr,
                        style: TextStyle(
                          color: AppColors.darkGold,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDot(bool isActive) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? AppColors.softGreen : AppColors.error,
      ),
    );
  }

  Widget _buildEmptyTeamState() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(
            Icons.group_add_rounded,
            size: 64,
            color: AppColors.textSecondary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text('no_team_members'.tr,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            'invite_friends_desc'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalLine() {
    return Container(
      width: 2,
      height: 24,
      color: isDark
          ? Colors.white.withValues(alpha: 0.1)
          : Colors.black.withValues(alpha: 0.1),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
