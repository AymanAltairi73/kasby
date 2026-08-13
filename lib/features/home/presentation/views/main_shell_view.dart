import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/tour/tour_controller.dart';
import 'package:kasby/core/tour/tour_target_keys.dart';
import 'package:kasby/features/home/presentation/views/home_view.dart';
import 'package:kasby/features/wallet/presentation/views/wallet_view.dart';
import 'package:kasby/features/wallet/presentation/views/all_transactions_view.dart';
import 'package:kasby/features/investment/presentation/views/investment_plans_view.dart';
import 'package:kasby/features/profile/presentation/views/profile_view.dart';
import 'package:kasby/core/controllers/shell_controller.dart';
import 'package:kasby/core/utils/safe_getx.dart';

class MainShellView extends StatefulWidget {
  const MainShellView({super.key});

  @override
  State<MainShellView> createState() => _MainShellViewState();
}

class _MainShellViewState extends State<MainShellView> {
  final shellController = ShellController.to;
  Worker? _tabTourWorker;

  List<Widget> get _pages {
    return [
      const HomeView(),
      const WalletView(),
      const InvestmentPlansView(),
      const AllTransactionsView(),
      const ProfileView(),
    ];
  }

  @override
  void initState() {
    TourTargetKeys.recreateKeys();
    super.initState();
    SafeGetx.debugTrace(
      className: 'MainShellView',
      method: 'initState',
      feature: 'Home',
      status: 'INFO',
      params: {'tabCount': 5},
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await TourController.to.tryConsumePendingAutoHomeTour(context);
      if (!mounted) return;
      await TourController.to.tryStartAutoHomeTour(context);
    });
    _tabTourWorker = ever<int>(shellController.currentIndex, (index) {
      if (!mounted) return;
      TourController.to.tryStartShellTabTour(context, index);
    });
  }

  @override
  void dispose() {
    _tabTourWorker?.dispose();
    TourController.to.dismissActiveTour();
    SafeGetx.debugTrace(
      className: 'MainShellView',
      method: 'dispose',
      feature: 'Home',
      status: 'INFO',
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;
        return Obx(
          () => Scaffold(
            body: Row(
              children: [
                if (isWide) _buildNavigationRail(isDark),
                Expanded(
                  child: IndexedStack(
                    index: shellController.currentIndex.value,
                    children: _pages,
                  ),
                ),
              ],
            ),
            bottomNavigationBar: isWide ? null : _buildBottomNav(isDark),
          ),
        );
      },
    );
  }

  Widget _buildNavigationRail(bool isDark) {
    final index = shellController.currentIndex.value;

    return Semantics(
      label: 'Main navigation',
      child: NavigationRail(
        selectedIndex: index,
        onDestinationSelected: shellController.setIndex,
        labelType: NavigationRailLabelType.all,
        backgroundColor: isDark ? AppColors.surface : Colors.white,
        selectedIconTheme: IconThemeData(color: AppColors.darkGold),
        selectedLabelTextStyle: TextStyle(
          color: AppColors.darkGold,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        unselectedIconTheme: IconThemeData(
          color: isDark ? Colors.white38 : Colors.grey.shade400,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: isDark ? Colors.white38 : Colors.grey.shade400,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        indicatorColor: AppColors.darkGold.withValues(alpha: 0.12),
        destinations: [
          NavigationRailDestination(
            icon: Tooltip(
              message: 'nav_home'.tr,
              child: const Icon(Icons.home_outlined),
            ),
            selectedIcon: Tooltip(
              message: 'nav_home'.tr,
              child: const Icon(Icons.home_rounded),
            ),
            label: Text('nav_home'.tr),
          ),
          NavigationRailDestination(
            icon: Tooltip(
              message: 'nav_wallet'.tr,
              child: const Icon(Icons.account_balance_wallet_outlined),
            ),
            selectedIcon: Tooltip(
              message: 'nav_wallet'.tr,
              child: const Icon(Icons.account_balance_wallet_rounded),
            ),
            label: Text('nav_wallet'.tr),
          ),
          NavigationRailDestination(
            icon: Tooltip(
              message: 'nav_invest'.tr,
              child: const Icon(Icons.trending_up_outlined),
            ),
            selectedIcon: Tooltip(
              message: 'nav_invest'.tr,
              child: const Icon(Icons.trending_up_rounded),
            ),
            label: Text('nav_invest'.tr),
          ),
          NavigationRailDestination(
            icon: Tooltip(
              message: 'nav_transactions'.tr,
              child: const Icon(Icons.receipt_long_outlined),
            ),
            selectedIcon: Tooltip(
              message: 'nav_transactions'.tr,
              child: const Icon(Icons.receipt_long_rounded),
            ),
            label: Text('nav_transactions'.tr),
          ),
          NavigationRailDestination(
            icon: Tooltip(
              message: 'nav_profile'.tr,
              child: const Icon(Icons.person_outline_rounded),
            ),
            selectedIcon: Tooltip(
              message: 'nav_profile'.tr,
              child: const Icon(Icons.person_rounded),
            ),
            label: Text('nav_profile'.tr),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(bool isDark) {
    return Semantics(
      label: 'Main navigation',
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surface : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.06),
              width: 0.5,
            ),
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: _buildNavItem(
                    0,
                    Icons.home_rounded,
                    Icons.home_outlined,
                    'nav_home'.tr,
                  ),
                ),
                Expanded(
                  child: _buildNavItem(
                    1,
                    Icons.account_balance_wallet_rounded,
                    Icons.account_balance_wallet_outlined,
                    'nav_wallet'.tr,
                  ),
                ),
                Expanded(child: _buildCenterNavItem()),
                Expanded(
                  child: _buildNavItem(
                    3,
                    Icons.receipt_long_rounded,
                    Icons.receipt_long_outlined,
                    'nav_transactions'.tr,
                  ),
                ),
                Expanded(
                  child: KeyedSubtree(
                    key: TourTargetKeys.profileNav,
                    child: _buildNavItem(
                      4,
                      Icons.person_rounded,
                      Icons.person_outline_rounded,
                      'nav_profile'.tr,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData activeIcon,
    IconData inactiveIcon,
    String label,
  ) {
    final isActive = shellController.currentIndex.value == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      button: true,
      label: label,
      selected: isActive,
      child: GestureDetector(
        onTap: () {
          if (shellController.currentIndex.value != index) {
            HapticFeedback.selectionClick();
            shellController.setIndex(index);
          }
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.darkGold.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Icon(
                  isActive ? activeIcon : inactiveIcon,
                  key: ValueKey(isActive),
                  size: 24,
                  color: isActive
                      ? AppColors.darkGold
                      : (isDark ? Colors.white38 : const Color(0xFF64748B)),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: isActive
                      ? AppColors.darkGold
                      : (isDark ? Colors.white38 : const Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterNavItem() {
    final isActive = shellController.currentIndex.value == 2;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      button: true,
      label: 'nav_invest'.tr,
      selected: isActive,
      child: GestureDetector(
        onTap: () {
          if (shellController.currentIndex.value != 2) {
            HapticFeedback.selectionClick();
            shellController.setIndex(2);
          }
        },
        child: KeyedSubtree(
          key: TourTargetKeys.investNav,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isActive
                    ? [
                        AppColors.darkGold,
                        Color.lerp(AppColors.darkGold, Colors.white, 0.3)!,
                      ]
                    : [
                        AppColors.darkGold.withValues(
                          alpha: isDark ? 0.2 : 0.1,
                        ),
                        AppColors.darkGold.withValues(
                          alpha: isDark ? 0.1 : 0.05,
                        ),
                      ],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: AppColors.darkGold.withValues(alpha: 0.3),
                        blurRadius: 12,
                        spreadRadius: 1,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.trending_up_rounded,
                  size: 24,
                  color: isActive ? Colors.black : AppColors.darkGold,
                ),
                const SizedBox(height: 2),
                Text(
                  'nav_invest'.tr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.black : AppColors.darkGold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
