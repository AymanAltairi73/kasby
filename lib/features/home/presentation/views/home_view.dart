import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_card.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/routes/app_routes.dart';
import 'package:kasby/core/controllers/currency_controller.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:kasby/features/home/presentation/controllers/ad_controller.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:kasby/core/widgets/kasby_shimmer.dart';
import 'package:kasby/core/utils/ksp_converter.dart';



class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final currencyController = CurrencyController.to;
  final homeController = HomeController.to;

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.darkGold,
        backgroundColor: isDark ? AppColors.surface : AppColors.surfaceLight,
        onRefresh: () => homeController.refreshAll(),
        child: CustomScrollView(
          physics:
              const AlwaysScrollableScrollPhysics(), // Important for RefreshIndicator in CustomScrollView
          slivers: [
            _buildAppBar(context),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _HomeSlider()
                        .animate()
                        .fadeIn(duration: const Duration(milliseconds: 600))
                        .slideY(begin: 0.1, end: 0),
                    const SizedBox(height: 24),
                    Obx(() {
                      final profile = homeController.profile.value;
                      if (profile != null && profile.kycStatus != 'verified') {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: _buildKYCBanner(),
                        );
                      }
                      return const SizedBox.shrink();
                    }),
                    _buildBalanceCard()
                        .animate()
                        .fadeIn(delay: const Duration(milliseconds: 400))
                        .scale(begin: const Offset(0.95, 0.95)),
                    const SizedBox(height: 24),

                    _buildQuickActions().animate().fadeIn(
                      delay: const Duration(milliseconds: 800),
                    ),
                    const SizedBox(height: 32),
                    _buildSectionHeader(
                      'recent_transactions'.tr,
                      onSeeAll: () => Get.toNamed(Routes.allTransactions),
                    ).animate().fadeIn(
                      delay: const Duration(milliseconds: 1000),
                    ),
                    const SizedBox(height: 16),
                    _buildRecentTransactions()
                        .animate()
                        .fadeIn(delay: const Duration(milliseconds: 1100))
                        .slideY(begin: 0.1, end: 0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _FloatingActionMasterpiece(),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 100,
      backgroundColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.darkGold.withValues(alpha: isDark ? 0.1 : 0.05),
                Theme.of(context).scaffoldBackgroundColor,
              ],
            ),
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 0.5,
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      title: Row(
        children: [
          GestureDetector(
            onTap: () => Get.toNamed(Routes.profile),
            child: Hero(
              tag: 'profile_avatar',
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.darkGold.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: isDark
                      ? AppColors.surface
                      : AppColors.surfaceLight,

                  child: Obx(() {
                    final profile = homeController.profile.value;
                    final imageUrl = profile?.avatarUrl;
                    if (imageUrl != null && imageUrl.isNotEmpty) {
                      return ClipOval(
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          width: 36,
                          height: 36,
                          errorBuilder: (context, error, stackTrace) =>
                              Icon(
                                Icons.person_rounded,
                                color: AppColors.darkGold,
                              ),
                        ),
                      );
                    }
                    return Icon(
                      Icons.person_rounded,
                      color: AppColors.darkGold,
                    );
                  }),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Obx(
                () => Text(
                  'hi_name'.trParams({
                    'name': homeController.profileName.isEmpty
                        ? ''
                        : homeController.profileName,
                  }),
                  style: Get.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.softGreen,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Obx(
                    () => Text(
                      'enum_tier_${homeController.accountTier}'.tr,
                      style: TextStyle(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: [
        Stack(
          children: [
            IconButton(
              icon: Icon(
                Icons.notifications_none_rounded,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.9),
              ),
              onPressed: () => Get.toNamed(Routes.notifications),
            ),
            Obx(
              () => homeController.unreadNotificationCount.value > 0
                  ? Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          homeController.unreadNotificationCount.value > 9
                              ? '9+'
                              : homeController.unreadNotificationCount.value
                                    .toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildKYCBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.darkGold.withValues(alpha: 0.15),
            isDark ? AppColors.surface : AppColors.surfaceLight,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.darkGold.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.darkGold.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.verified_user_outlined,
              color: AppColors.darkGold,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'complete_kyc_title'.tr,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'complete_kyc_desc'.tr,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textSecondary
                        : AppColors.textSecondaryLight,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Get.toNamed(Routes.kyc);
            },
            style: TextButton.styleFrom(
              backgroundColor: AppColors.darkGold,
              foregroundColor: Colors.black, // Dark gold always looks better with black text
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(
              'verify_now'.tr,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Stack(
      children: [
        // Background Glow Orbs
        Positioned(
          top: -20,
          right: -20,
          child:
              Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.darkGold.withValues(alpha: 0.15),
                    ),
                  )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(
                    duration: const Duration(seconds: 3),
                    begin: const Offset(1, 1),
                    end: const Offset(1.4, 1.4),
                  )
                  .blurXY(begin: 40, end: 80),
        ),
        Positioned(
          bottom: -30,
          left: -10,
          child:
              Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.softGreen.withValues(alpha: 0.1),
                    ),
                  )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(
                    duration: const Duration(seconds: 4),
                    begin: const Offset(1, 1),
                    end: const Offset(1.3, 1.3),
                  )
                  .blurXY(begin: 30, end: 60),
        ),

        // Glass Card
        // Balance Card
        Hero(
          tag: 'home_balance',
          child: KasbyCard(
            color: isDark
                ? Colors.white.withValues(alpha: 0.03)
                : AppColors.surfaceLight,
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : AppColors.darkGold.withValues(alpha: 0.2),
              width: 1.5,
            ),
            hasShadow: true,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                children: [
                  // ─── TOP: KSP Coin Header ───
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            'assets/images/ksp_coin.png',
                            width: 28,
                            height: 28,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Kasby',
                            style: TextStyle(
                              color: AppColors.darkGold,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                      // Percentage Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.softGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.softGreen.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Obx(
                          () => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.trending_up_rounded,
                                color: AppColors.softGreen,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '+${homeController.profitPercentage}%',
                                style: TextStyle(
                                  color: AppColors.softGreen,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn().slideX(),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // ─── TOTAL BALANCE ───
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            color: AppColors.textSecondary,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'total_balance'.tr,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Obx(
                        () => Text(
                          currencyController.formatToUSD(
                            currencyController.totalBalance.value,
                          ),
                          style: Get.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: Theme.of(context).colorScheme.onSurface,
                            letterSpacing: -1,
                          ),
                        ).animate().shimmer(
                          duration: const Duration(seconds: 3),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // ─── KSP BALANCE CARD ───
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      Get.toNamed(Routes.kspWallet);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.darkGold.withValues(alpha: 0.15),
                            AppColors.darkGold.withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.darkGold.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Image.asset(
                            'assets/images/ksp_coin.png',
                            width: 32,
                            height: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'KSP',
                                  style: TextStyle(
                                    color: AppColors.darkGold,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                    letterSpacing: 1,
                                  ),
                                ),
                                Obx(
                                  () => Text(
                                    KspConverter.formatKsp(homeController.pointsBalance),
                                    style: TextStyle(
                                      color: AppColors.darkGold,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // USD Equivalent
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'USD',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  letterSpacing: 1,
                                ),
                              ),
                              Obx(
                                () => Text(
                                  currencyController.formatToUSD(
                                    KspConverter.kspToUsd(homeController.pointsBalance.toDouble()),
                                  ),
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 12,
                            color: AppColors.darkGold,
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn().slideY(begin: 0.1),
                  const SizedBox(height: 24),
                  // ─── DUAL METRICS: Daily Profit + Currency ───
                  Row(
                    children: [
                      // Daily Profit
                      Expanded(
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.show_chart_rounded,
                                  color: AppColors.textSecondary,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'daily_profit'.tr,
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Obx(
                              () => Text(
                                currencyController.formatToUSD(
                                  homeController.dailyProfit,
                                ),
                                style: TextStyle(
                                  color: AppColors.softGreen,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: 30,
                        width: 1,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.1),
                      ),
                      // Currency Converter
                      Expanded(
                        child: Column(
                          children: [
                            Obx(
                              () => DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value:
                                      currencyController.selectedCurrency.value,
                                  dropdownColor: isDark
                                      ? AppColors.surface
                                      : AppColors.surfaceLight,
                                  icon: Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: AppColors.darkGold,
                                    size: 18,
                                  ),
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                  items: currencyController.currencyData.keys
                                      .map((String key) {
                                        return DropdownMenuItem<String>(
                                          value: key,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                currencyController
                                                    .currencyData[key]!['flag'],
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                key,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      })
                                      .toList(),
                                  onChanged: (String? newValue) {
                                    if (newValue != null) {
                                      currencyController.changeCurrency(
                                        newValue,
                                      );
                                    }
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Obx(
                              () =>
                                  Text(
                                        currencyController.formatAmount(
                                          currencyController.totalBalance.value,
                                        ),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 18,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                        ),
                                      )
                                      .animate(
                                        key: ValueKey(
                                          currencyController
                                              .selectedCurrency
                                              .value,
                                        ),
                                      )
                                      .scale(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Portfolio Distribution
                  Obx(() {
                    final investments = homeController.myInvestments;
                    if (investments.isEmpty) return const SizedBox.shrink();

                    // Simple calculation for sectors (this logic should ideally be in controller)
                    double gold = 0;
                    double silver = 0;
                    double realEstate = 0;
                    double total = 0;

                    for (var inv in investments) {
                      final planName =
                          inv.investment?.nameEn?.toLowerCase() ?? '';
                      if (planName.contains('gold')) {
                        gold += inv.amount;
                      } else if (planName.contains('silver')) {
                        silver += inv.amount;
                      } else {
                        realEstate += inv.amount;
                      }
                      total += inv.amount;
                    }

                    if (total == 0) return const SizedBox.shrink();

                    final goldPct = (gold / total * 100).round();
                    final silverPct = (silver / total * 100).round();
                    final realEstatePct = (100 - goldPct - silverPct).clamp(
                      0,
                      100,
                    );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 12),
                        Text(
                          'portfolio_distribution'.tr,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Multi-colored Progress Bar
                        Container(
                          height: 8,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.05),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Row(
                              children: [
                                if (gold > 0)
                                  Expanded(
                                    flex: goldPct,
                                    child: Container(color: AppColors.darkGold),
                                  ),
                                if (silver > 0)
                                  Expanded(
                                    flex: silverPct,
                                    child: Container(
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                    ),
                                  ),
                                if (realEstate > 0)
                                  Expanded(
                                    flex: realEstatePct,
                                    child: Container(
                                      color: AppColors.softGreen,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Legend
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (gold > 0)
                              _buildLegendItem(
                                'gold_sector'.trParams({'percent': '$goldPct'}),
                                AppColors.darkGold,
                              ),
                            if (silver > 0 && gold > 0)
                              const SizedBox(width: 16),
                            if (silver > 0)
                              _buildLegendItem(
                                'silver_sector'.trParams({
                                  'percent': '$silverPct',
                                }),
                                isDark ? Colors.grey[400]! : Colors.grey[600]!,
                              ),
                            if (realEstate > 0 && (gold > 0 || silver > 0))
                              const SizedBox(width: 16),
                            if (realEstate > 0)
                              _buildLegendItem(
                                'real_estate_sector'.trParams({
                                  'percent': '$realEstatePct',
                                }),
                                AppColors.softGreen,
                              ),
                          ],
                        ),
                      ],
                    );
                  }),

                  // --- PENDING REWARDS SECTION ---
                  Obx(() {
                    final canClaim = homeController.canClaimRewards.value;
                    final countdown = homeController.rewardCountdownText.value;
                    
                    if (!canClaim && countdown.isEmpty && homeController.pendingRewards.isEmpty) {
                       return const SizedBox.shrink();
                    }

                    return Column(
                      children: [
                        const SizedBox(height: 24),
                        Divider(
                          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
                          height: 1,
                        ),
                        const SizedBox(height: 20),
                        if (!canClaim)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Obx(() => homeController.isProcessingUI.value
                                  ? Icon(Icons.sync_rounded,
                                          color: AppColors.softGreen,
                                          size: 16)
                                      .animate(onPlay: (c) => c.repeat())
                                      .rotate(duration: const Duration(seconds: 2))
                                  : Icon(Icons.hourglass_bottom_rounded,
                                          color: AppColors.darkGold,
                                          size: 16)
                                      .animate(onPlay: (c) => c.repeat())
                                      .rotate(
                                        duration: const Duration(seconds: 2),
                                      )),
                              const SizedBox(width: 8),
                              Obx(
                                () => homeController.isProcessingUI.value
                                    ? const SizedBox.shrink()
                                    : Text(
                                      'release_countdown'.tr,
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                              ),
                              Obx(
                                () => Text(
                                  countdown,
                                  style: TextStyle(
                                    color: homeController.isProcessingUI.value
                                        ? AppColors.softGreen
                                        : AppColors.darkGold,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    fontFamily:
                                        'Courier', // Monospaced look for timer
                                  ),
                                ),
                              ),
                            ],
                          ).animate().fadeIn(),
                        if (canClaim)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: KasbyButton(
                              text: 'claim_rewards'.tr,
                              onPressed: () => homeController.claimRewards(),
                              isLoading: homeController.isClaimingLoading.value,
                              color: AppColors.softGreen,
                              icon: Icons.auto_awesome_rounded,
                            ),
                          ).animate(onPlay: (c) => c.repeat()).shimmer(duration: const Duration(seconds: 2)).scale(
                                begin: const Offset(1, 1),
                                end: const Offset(1.05, 1.05),
                                duration: const Duration(seconds: 1),
                                curve: Curves.easeInOut,
                              ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }



  Widget _buildQuickActions() {
    final List<Map<String, dynamic>> actions = [
      {
        'icon': Icons.people_outline_rounded,
        'label': 'social_network'.tr,
        'onTap': () => Get.toNamed(Routes.friendRequests),
      },
      {
        'icon': Icons.swap_horizontal_circle_rounded,
        'label': 'p2p_transfer'.tr,
        'onTap': () => Get.toNamed(Routes.transfer),
      },
      {
        'icon': Icons.groups_rounded,
        'label': 'authorized_agents'.tr,
        'onTap': () => Get.toNamed(Routes.agents),
      },
      {
        'icon': Icons.card_membership_rounded,
        'label': 'investments'.tr,
        'onTap': () => Get.toNamed(Routes.subscription),
      },
      {
        'icon': Icons.pie_chart_rounded,
        'label': 'my_investments'.tr,
        'onTap': () => Get.toNamed(Routes.myInvestments),
      },
      {
        'icon': Icons.handshake_rounded,
        'label': 'salefni_kasby'.tr,
        'onTap': () => Get.toNamed(Routes.loan),
      },
      {
        'icon': Icons.casino_rounded,
        'label': 'spin_wheel'.tr,
        'onTap': () => Get.toNamed(Routes.spinWheel),
      },
      {
        'icon': Icons.calendar_today_rounded,
        'label': 'check_in'.tr,
        'onTap': () => Get.toNamed(Routes.dailyCheckIn),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 20,
        crossAxisSpacing: 10,
        mainAxisExtent: 125,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        return _buildActionItem(
          actions[index]['icon'] as IconData,
          actions[index]['label'] as String,
          actions[index]['onTap'] as VoidCallback,
        );
      },
    );
  }

  Widget _buildActionItem(IconData icon, String label, VoidCallback onPressed) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onPressed();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isDark ? AppColors.surface : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.05),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: AppColors.darkGold, size: 28),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {required VoidCallback onSeeAll}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        TextButton(
          onPressed: onSeeAll,
          child: Text(
            'see_all'.tr,
            style: TextStyle(color: AppColors.darkGold),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentTransactions() {
    return Obx(() {
      final transactions = homeController.recentTransactions.take(3).toList();

      if (homeController.isLoadingTransactions.value) {
        return Column(
          children: List.generate(
            3,
            (i) => const KasbyShimmer.listItem(
              margin: EdgeInsets.only(bottom: 12),
            ),
          ),
        );
      }

      if (transactions.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surface : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(
              'no_transactions'.tr,
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondary
                    : AppColors.textSecondaryLight,
              ),
            ),
          ),
        );
      }

      return Column(
        children: transactions.map((tx) {
          final isOut = tx.isDebit;
          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Get.toNamed(
                Routes.transactionDetails,
                arguments: {'transaction': tx, 'heroTag': 'home_tx_${tx.id}'},
              );
            },
            child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surface : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: (isOut ? AppColors.error : AppColors.softGreen)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          isOut
                              ? Icons.arrow_outward_rounded
                              : Icons.arrow_downward_rounded,
                          color: isOut ? AppColors.error : AppColors.softGreen,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (tx.description != null && tx.description!.isNotEmpty)
                                  ? tx.description!.tr
                                  : 'enum_txn_${tx.type}'.tr,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tx.createdAt != null
                                  ? '${tx.createdAt!.day}/${tx.createdAt!.month}, ${tx.createdAt!.hour}:${tx.createdAt!.minute.toString().padLeft(2, '0')}'
                                  : '',
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.textSecondary
                                    : AppColors.textSecondaryLight,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 100),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${isOut ? '-' : '+'}${currencyController.formatAmount(tx.amount)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: isOut ? AppColors.error : AppColors.softGreen,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.3)
                            : Colors.black.withValues(alpha: 0.3),
                      ),
                    ],
                  ),
                ),
          );
        }).toList(),
      );
    });
  }

  /*
  Widget _buildProofOfTrust() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'proof_of_trust_label'.tr,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.softGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.sync_rounded,
                    size: 10,
                    color: AppColors.softGreen,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'auto_updated'.tr,
                    style: const TextStyle(
                      color: AppColors.softGreen,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        KasbyCard(
          child: IntrinsicHeight(
            child: Row(
              children: [
                _buildProofItem('distributed_profits_label'.tr, '1,245,000\$'),
                const VerticalDivider(color: Colors.white10),
                _buildProofItem('successful_withdrawals_label'.tr, '8,320'),
                const VerticalDivider(color: Colors.white10),
                _buildProofItem('active_users_label'.tr, '42,000'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProofItem(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppColors.darkGold,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
  */


  Widget _buildLegendItem(String label, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: isDark
                ? AppColors.textSecondary
                : AppColors.textSecondaryLight,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _HomeSlider extends StatefulWidget {
  const _HomeSlider();

  @override
  State<_HomeSlider> createState() => _HomeSliderState();
}

class _HomeSliderState extends State<_HomeSlider> {
  final PageController _pageController = PageController();
  final adController = Get.put(AdController());
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      final adCount = adController.ads.length;
      if (adCount <= 1) return;

      if (_currentPage < adCount - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeInOutQuart,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Obx(() {
      final ads = adController.ads;
      if (ads.isEmpty && !adController.isLoading.value) {
        return const SizedBox.shrink();
      }

      if (adController.isLoading.value && ads.isEmpty) {
        return Container(
          height: 190,
          margin: const EdgeInsets.symmetric(vertical: 5),
          child: const KasbyShimmer(
            width: double.infinity,
            height: 180,
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
        );
      }

      return Column(
        children: [
          Container(
            height: 190,
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemCount: ads.length,
              itemBuilder: (context, index) {
                final ad = ads[index];
                return AnimatedBuilder(
                  animation: _pageController,
                  builder: (context, child) {
                    double value = 1.0;
                    if (_pageController.position.haveDimensions) {
                      value = (_pageController.page! - index).abs();
                      value = (1 - (value * 0.15)).clamp(0.0, 1.0);
                    }
                    return Center(
                      child: SizedBox(
                        height: Curves.easeOut.transform(value) * 180,
                        width: Curves.easeOut.transform(value) * 450,
                        child: child,
                      ),
                    );
                  },
                  child:
                      GestureDetector(
                            onTap: () {
                              if (ad.actionUrl != null &&
                                  ad.actionUrl!.isNotEmpty) {
                                HapticFeedback.lightImpact();
                                Get.toNamed(ad.actionUrl!);
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 5),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.darkGold.withValues(
                                      alpha: 0.2,
                                    ),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    // Background Image with Caching and Fallback
                                    CachedNetworkImage(
                                      imageUrl: ad.imageUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => const KasbyShimmer.card(),
                                      errorWidget: (context, url, error) =>
                                          Image.asset(
                                            _getFallbackAsset(ad.imageUrl),
                                            fit: BoxFit.cover,
                                          ),
                                    ),
                                    // Gradient Overlay
                                    Positioned.fill(
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.transparent,
                                              Colors.black.withValues(
                                                alpha: 0.25,
                                              ),
                                              Colors.black.withValues(
                                                alpha: 0.75,
                                              ),
                                            ],
                                            stops: const [0.3, 0.6, 1.0],
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Title & Description
                                    Positioned(
                                      bottom: 14,
                                      left: 16,
                                      right: 16,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Title
                                          Text(
                                                Get.locale?.languageCode == 'en'
                                                    ? (ad.titleEn ?? ad.titleAr)
                                                    : ad.titleAr,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 16,
                                                  shadows: [
                                                    Shadow(
                                                      blurRadius: 8,
                                                      color: Colors.black54,
                                                    ),
                                                  ],
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              )
                                              .animate(
                                                key: ValueKey(
                                                  'title_${ad.id}_$_currentPage',
                                                ),
                                              )
                                              .fadeIn(
                                                duration: 600.ms,
                                                curve: Curves.easeOut,
                                              ),
                                          if ((Get.locale?.languageCode == 'en'
                                                      ? ad.descriptionEn
                                                      : ad.descriptionAr) !=
                                                  null &&
                                              (Get.locale?.languageCode == 'en'
                                                      ? ad.descriptionEn
                                                      : ad.descriptionAr)!
                                                  .isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            // Animated Description (slides left to right)
                                            Text(
                                                  Get.locale?.languageCode ==
                                                          'en'
                                                      ? ad.descriptionEn!
                                                      : ad.descriptionAr!,
                                                  style: TextStyle(
                                                    color: Colors.white
                                                        .withValues(alpha: 0.9),
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                    shadows: const [
                                                      Shadow(
                                                        blurRadius: 6,
                                                        color: Colors.black45,
                                                      ),
                                                    ],
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                )
                                                .animate(
                                                  key: ValueKey(
                                                    'desc_${ad.id}_$_currentPage',
                                                  ),
                                                )
                                                .fadeIn(
                                                  delay: 300.ms,
                                                  duration: 500.ms,
                                                  curve: Curves.easeOut,
                                                )
                                                .slideX(
                                                  begin: -0.15,
                                                  end: 0,
                                                  delay: 300.ms,
                                                  duration: 700.ms,
                                                  curve: Curves.easeOutCubic,
                                                ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                          .animate(onPlay: (c) => c.repeat())
                          .shimmer(
                            duration: 3000.ms,
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.1),
                          ),
                );
              },
            ),
          ),
          if (ads.length > 1) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                ads.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 6,
                  width: _currentPage == index ? 24 : 6,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? AppColors.darkGold
                        : (isDark ? Colors.white24 : Colors.black12),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: _currentPage == index
                        ? [
                            BoxShadow(
                              color: AppColors.darkGold.withValues(alpha: 0.5),
                              blurRadius: 8,
                              offset: const Offset(0, 0),
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ),
          ],
        ],
      );
    });
  }

  String _getFallbackAsset(String url) {
    if (url.contains('slider_growth')) return 'assets/images/slider_growth.png';
    if (url.contains('slider_secure')) return 'assets/images/slider_secure.png';
    if (url.contains('slider_diversified')) {
      return 'assets/images/slider_diversified.png';
    }
    return 'assets/images/slider_growth.png'; // Default fallback
  }
}

class _FloatingActionMasterpiece extends StatefulWidget {
  const _FloatingActionMasterpiece();

  @override
  State<_FloatingActionMasterpiece> createState() =>
      _FloatingActionMasterpieceState();
}

class _FloatingActionMasterpieceState extends State<_FloatingActionMasterpiece>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.darkGold.withValues(alpha: 0.3),
                    blurRadius:
                        20 + (5 * math.sin(_controller.value * 2 * math.pi)),
                    spreadRadius:
                        2 + (2 * math.sin(_controller.value * 2 * math.pi)),
                  ),
                ],
              ),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Get.toNamed(Routes.investmentPlans);
                },
                child: Container(
                  width: 65,
                  height: 65,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.darkGold,
                        Color.lerp(AppColors.darkGold, Colors.white, 0.3)!,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: (isDark ? Colors.white : Colors.black).withValues(
                        alpha: 0.2,
                      ),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: RotationTransition(
                      turns: Tween(begin: 0.0, end: 1.0).animate(
                        CurvedAnimation(
                          parent: _controller,
                          curve: const Interval(
                            0.0,
                            0.5,
                            curve: Curves.easeInOut,
                          ),
                        ),
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        color: isDark ? Colors.black : Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                ),
              ),
            )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(
              begin: const Offset(1, 1),
              end: const Offset(1.08, 1.08),
              duration: const Duration(seconds: 2),
              curve: Curves.easeInOutSine,
            );
      },
    );
  }
}
