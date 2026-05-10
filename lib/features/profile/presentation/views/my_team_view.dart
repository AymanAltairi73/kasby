import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:share_plus/share_plus.dart';
import 'package:kasby/core/widgets/kasby_shimmer.dart';

class MyTeamView extends StatefulWidget {
  const MyTeamView({super.key});

  @override
  State<MyTeamView> createState() => _MyTeamViewState();
}

class _MyTeamViewState extends State<MyTeamView> {
  bool _isLoading = true;
  String _myReferralCode = '';
  int _totalMembers = 0;
  List<Map<String, dynamic>> _members = [];

  @override
  void initState() {
    super.initState();
    // Pre-initialize with code from profile if available
    _myReferralCode = HomeController.to.profile.value?.referralCode ?? '';
    _fetchTeamData();
  }

  Future<void> _fetchTeamData() async {
    try {
      final result = await SupabaseService.client.rpc('get_my_team');
      
      // Handle the case where result might be null or not a map
      if (result == null || result is! Map) {
        _log('get_my_team RPC returned invalid data');
        if (mounted) {
          setState(() {
            if (_myReferralCode.isEmpty) {
              _myReferralCode = HomeController.to.profile.value?.referralCode ?? '';
            }
          });
        }
        return;
      }

      final response = Map<String, dynamic>.from(result);

      if (response['success'] == true) {
        if (mounted) {
          setState(() {
            // Priority: RPC Result > Current Value (initialized from Profile) > Default Empty
            final rpcCode = response['my_referral_code'] as String?;
            if (rpcCode != null && rpcCode.isNotEmpty) {
              _myReferralCode = rpcCode;
            } else if (_myReferralCode.isEmpty) {
              _myReferralCode = HomeController.to.profile.value?.referralCode ?? '';
            }

            _totalMembers = response['total_members'] ?? 0;
            _members = List<Map<String, dynamic>>.from(response['members'] ?? []);
          });
        }
      }
    } catch (e) {
      _log('Error fetching team: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _log(String message, {bool isError = false}) {
    debugPrint('[MY_TEAM] ${isError ? "❌" : "ℹ️"} $message');
  }


  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDark ? AppColors.background : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('my_team'.tr),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Get.back(),
        ),
      ),
      body: _isLoading
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                children: [
                  const KasbyShimmer.card(height: 140),
                  const SizedBox(height: 24),
                  Row(
                    children: const [
                      Expanded(child: KasbyShimmer.card(height: 100)),
                      SizedBox(width: 16),
                      Expanded(child: KasbyShimmer.card(height: 100)),
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
            )
          : RefreshIndicator(
              onRefresh: _fetchTeamData,
              color: AppColors.darkGold,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Column(
                  children: [
                    _buildReferralCodeCard(),
                    const SizedBox(height: 24),
                    _buildStatsDashboard(),
                    const SizedBox(height: 32),
                    _buildSectionHeader('tree_view'.tr),
                    const SizedBox(height: 20),
                    _buildTeamList(),
                    const SizedBox(height: 60),
                  ],
                ),
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
              _buildActionChip(
                Icons.copy_rounded,
                'copy'.tr,
                () {
                  Clipboard.setData(ClipboardData(text: _myReferralCode));
                  HapticFeedback.lightImpact();
                  Get.snackbar(
                    'success'.tr,
                    'تم نسخ كود الإحالة',
                    backgroundColor: AppColors.softGreen.withValues(alpha: 0.9),
                    colorText: Colors.white,
                  );
                },
              ),
              const SizedBox(width: 12),
              _buildActionChip(
                Icons.share_rounded,
                'share'.tr,
                () {
                  SharePlus.instance.share(
                    ShareParams(
                      text: 'انضم إلى كاسبي واستثمر بذكاء! استخدم كود الإحالة: $_myReferralCode\nhttps://kasby.app/join?ref=$_myReferralCode',
                    ),
                  );
                },
              ),
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
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'team_members_count'.tr,
            '$_totalMembers',
            Icons.groups_rounded,
            Colors.blueAccent,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'active_members'.tr,
            '${_members.where((m) => m['status'] == 'active').length}',
            Icons.verified_rounded,
            AppColors.softGreen,
          ),
        ),
      ],
    ).animate().fadeIn(duration: const Duration(milliseconds: 500)).slideY(begin: 0.1);
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surface.withValues(alpha: 0.5)
            : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.textBodyLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
              fontSize: 12,
            ),
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

  Widget _buildTeamList() {
    if (_members.isEmpty) {
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
            Text(
              'no_team_members'.tr,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
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
      ).animate().fadeIn();
    }

    return Column(
      children: [
        // Root Node (Me)
        _buildTreeNode(
          name: HomeController.to.profile.value?.fullName ?? 'You',
          initials: _getInitials(HomeController.to.profile.value?.fullName ?? 'Y'),
          isRoot: true,
          isActive: true,
          subCount: _totalMembers,
        ),
        _buildVerticalLine(),
        // Team Members (Level 1)
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _members.length,
          itemBuilder: (context, index) {
            final member = _members[index];
            final name = member['full_name'] ?? 'مستخدم';
            final isActive = member['status'] == 'active';
            final subReferrals = member['sub_referrals'] as int? ?? 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const SizedBox(width: 40),
                  Container(
                    width: 2,
                    height: 60,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.1),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.surface.withValues(alpha: 0.5)
                            : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: AppColors.darkGold.withValues(alpha: 0.15),
                            child: Text(
                              _getInitials(name),
                              style: TextStyle(
                                color: AppColors.darkGold,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : AppColors.textBodyLight,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isActive ? AppColors.softGreen : AppColors.error,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isActive ? 'active'.tr : 'inactive'.tr,
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (subReferrals > 0) ...[
                                      const SizedBox(width: 12),
                                      Icon(Icons.people_outline, size: 14, color: AppColors.textSecondary),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$subReferrals',
                                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: Duration(milliseconds: 100 * index)).slideX(begin: 0.1);
          },
        ),
      ],
    ).animate().fadeIn(delay: const Duration(milliseconds: 300));
  }

  Widget _buildTreeNode({
    required String name,
    required String initials,
    required bool isRoot,
    required bool isActive,
    int subCount = 0,
  }) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isRoot ? AppColors.darkGold : (isDark ? AppColors.surface : AppColors.surfaceLight),
            border: Border.all(
              color: isRoot ? AppColors.darkGold : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1)),
              width: 2,
            ),
            boxShadow: isRoot
                ? [BoxShadow(color: AppColors.darkGold.withValues(alpha: 0.3), blurRadius: 15, spreadRadius: 2)]
                : null,
          ),
          child: Center(
            child: Text(
              initials,
              style: TextStyle(
                color: isRoot ? Colors.black : (isDark ? Colors.white : AppColors.textBodyLight),
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textBodyLight,
          ),
        ),
        if (isRoot && subCount > 0)
          Text(
            '$subCount ${'team_members_count'.tr}',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
      ],
    );
  }

  Widget _buildVerticalLine() {
    return Container(
      width: 2,
      height: 30,
      color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
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
