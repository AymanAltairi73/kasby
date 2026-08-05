import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kasby/core/services/referral_service.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:share_plus/share_plus.dart';
import 'package:kasby/core/widgets/kasby_shimmer.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/features/profile/presentation/controllers/team_controller.dart';
import 'package:kasby/features/profile/presentation/widgets/team_enterprise_widgets.dart';
import 'package:kasby/routes/app_routes.dart';

class MyTeamView extends StatefulWidget {
  const MyTeamView({super.key});

  @override
  State<MyTeamView> createState() => _MyTeamViewState();
}

class _MyTeamViewState extends State<MyTeamView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    SafeGetx.debugTrace(
      className: 'MyTeamView',
      method: 'initState',
      feature: 'Profile',
      status: 'INFO',
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  TeamController get _team => TeamController.to;

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDark
          ? AppColors.background
          : AppColors.backgroundLight,
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
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          tabs: [
            Tab(text: 'network'.tr),
            Tab(text: 'tree_view'.tr),
            Tab(text: 'timeline'.tr),
            Tab(text: 'statistics'.tr),
          ],
        ),
      ),
      body: Obx(() {
        if (_team.isLoading.value && _team.treeNodes.isEmpty) {
          return _buildLoadingSkeleton();
        }
        if (_team.hasError.value && _team.treeNodes.isEmpty) {
          return _buildErrorState();
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                KasbySpacing.lg,
                KasbySpacing.sm,
                KasbySpacing.lg,
                0,
              ),
              child: _buildReferralCodeCard(),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  TeamNetworkTab(),
                  TeamTreeTab(),
                  TeamTimelineTab(),
                  TeamStatsTab(),
                ],
              ),
            ),
          ],
        );
      }),
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
            Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: AppColors.error.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text('team_load_error'.tr, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _team.refreshAll,
              icon: const Icon(Icons.refresh_rounded),
              label: Text('app_error_retry'.tr),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.darkGold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferralCodeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(KasbySpacing.lg),
      decoration: BoxDecoration(
        borderRadius: KasbyRadius.heroR,
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
          Obx(() {
            final code = _team.myReferralCode.value.isNotEmpty
                ? _team.myReferralCode.value
                : ReferralService.formatDisplayCode(
                    HomeController.to.profile.value?.referralCode,
                  );
            return Text(
              code.isNotEmpty ? code : '---',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            );
          }),
          const SizedBox(height: 16),
          Obx(() {
            final code = _team.myReferralCode.value.isNotEmpty
                ? _team.myReferralCode.value
                : ReferralService.formatDisplayCode(
                    HomeController.to.profile.value?.referralCode,
                  );
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildActionChip(Icons.copy_rounded, 'copy'.tr, () {
                  Clipboard.setData(ClipboardData(text: code));
                  HapticFeedback.lightImpact();
                  Get.snackbar(
                    'success'.tr,
                    'referral_code_copied'.tr,
                    backgroundColor: AppColors.softGreen.withValues(alpha: 0.9),
                    colorText: Colors.white,
                  );
                }),
                const SizedBox(width: 12),
                _buildActionChip(Icons.share_rounded, 'share'.tr, () {
                  SharePlus.instance.share(
                    ShareParams(
                      text:
                          '${'invite_share_text'.tr} $code\nhttps://kasby.app/join?ref=$code',
                    ),
                  );
                }),
              ],
            );
          }),
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
}
