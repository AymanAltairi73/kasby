import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/routes/app_routes.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:kasby/core/controllers/currency_controller.dart';
import 'package:kasby/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:kasby/core/widgets/kasby_shimmer.dart';
// import 'package:kasby/core/controllers/shell_controller.dart';
import 'package:kasby/core/widgets/glass_card.dart';
import 'package:kasby/core/models/transaction_model.dart';
import 'package:intl/intl.dart';
import 'package:kasby/core/utils/safe_getx.dart';

class WalletView extends StatefulWidget {
  const WalletView({super.key});

  @override
  State<WalletView> createState() => _WalletViewState();
}

class _WalletViewState extends State<WalletView> with TickerProviderStateMixin {
  late AnimationController _gradientController;
  final currencyController = CurrencyController.to;
  final homeController = HomeController.to;
  final authController = AuthController.to;
  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    SafeGetx.debugTrace(
      className: 'WalletView',
      method: 'initState',
      feature: 'Wallet',
      status: 'INFO',
      message: 'Tab mounted in MainShell',
    );
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    SafeGetx.debugTrace(
      className: 'WalletView',
      method: 'dispose',
      feature: 'Wallet',
      status: 'INFO',
    );
    _gradientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('my_wallet'.tr),
        backgroundColor: Colors.transparent,
        elevation: 0,
        // leading: IconButton(
        //   icon: const Icon(Icons.arrow_back_ios_new_rounded),
        //   onPressed: () => ShellController.to.handleBack(),
        // ),
        actions: [
          IconButton(
            icon: Icon(Icons.qr_code_scanner_rounded, color: AppColors.darkGold),
            onPressed: () {
              HapticFeedback.lightImpact();
              Get.toNamed(Routes.qrScanner);
            },
            tooltip: 'scan_qr'.tr,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => homeController.refreshAll(),
        color: AppColors.darkGold,
        backgroundColor: isDark ? AppColors.surface : AppColors.surfaceLight,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24),
            child: Column(
              children: [
                _buildBalanceSummary(),
                const SizedBox(height: 40),
                _buildActionButtons(),
                const SizedBox(height: 40),
                _buildTransactionHistory(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceSummary() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth;
        final cardHeight = cardWidth * 0.62;

        return Material(
          type: MaterialType.transparency,
          child: Hero(
            tag: 'wallet_balance',
            child: AnimatedBuilder(
              animation: _gradientController,
              builder: (context, child) {
                return Container(
                  width: double.infinity,
                  height: cardHeight < 280 ? 280 : cardHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFFC9A24D).withValues(alpha: 0.9),
                        const Color(0xFF1A1A1F),
                        Colors.black,
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Stack(
                      children: [
                        // Dynamic Gradient Shine
                        Positioned.fill(
                          child: Transform.translate(
                            offset: Offset(
                              100 * (0.5 - _gradientController.value),
                              -100 * (0.5 - _gradientController.value),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.0),
                                    Colors.white.withValues(alpha: 0.03),
                                    Colors.white.withValues(alpha: 0.0),
                                  ],
                                  stops: const [0.2, 0.5, 0.8],
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Texture Overlay
                        Positioned.fill(
                          child: CustomPaint(
                            painter: CardTexturePainter(
                              color: Colors.white.withValues(alpha: 0.02),
                            ),
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildCardChip(),
                                        const SizedBox(height: 8),
                                        Text(
                                          '4589 **** **** 8892',
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.4,
                                            ),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            letterSpacing: 2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'KASBY CASH',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'available_balance'.tr.toUpperCase(),
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.5,
                                          ),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                      IconButton(
                                        icon: Obx(
                                          () => Icon(
                                            currencyController
                                                    .isBalanceHidden.value
                                                ? Icons.visibility_off_rounded
                                                : Icons.visibility_rounded,
                                            color: Colors.white.withValues(
                                              alpha: 0.5,
                                            ),
                                            size: 18,
                                          ),
                                        ),
                                        tooltip: 'Toggle Balance',
                                        onPressed: () =>
                                            currencyController
                                                .toggleBalancePrivacy(),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Obx(
                                    () => FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        currencyController.isBalanceHidden.value
                                            ? '**********'
                                            : currencyController.formatToUSD(
                                              currencyController
                                                  .totalBalance
                                                  .value,
                                            ),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 35,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.05),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      width: 1,
                                      height: 20,
                                      color: Colors.white.withValues(
                                        alpha: 0.1,
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Obx(
                                            () => DropdownButtonHideUnderline(
                                              child: DropdownButton<String>(
                                                value: currencyController
                                                    .selectedCurrency
                                                    .value,
                                                dropdownColor: isDark
                                                    ? AppColors.surface
                                                    : AppColors.surfaceLight,
                                                isDense: true,
                                                icon: Icon(
                                                  Icons
                                                      .keyboard_arrow_down_rounded,
                                                  color: AppColors.darkGold,
                                                  size: 16,
                                                ),
                                                style: TextStyle(
                                                  color: isDark
                                                      ? AppColors.textSecondary
                                                      : AppColors
                                                            .textSecondaryLight,
                                                  fontSize: 11,
                                                ),
                                                items: currencyController
                                                    .currencyData
                                                    .keys
                                                    .map((String key) {
                                                      return DropdownMenuItem<
                                                        String
                                                      >(
                                                        value: key,
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Text(
                                                              currencyController
                                                                  .currencyData[key]!['flag'],
                                                            ),
                                                            const SizedBox(
                                                              width: 8,
                                                            ),
                                                            Text(
                                                              key,
                                                              style: const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    })
                                                    .toList(),
                                                onChanged: (String? newValue) {
                                                  if (newValue != null) {
                                                    currencyController
                                                        .changeCurrency(
                                                          newValue,
                                                        );
                                                  }
                                                },
                                              ),
                                            ),
                                          ),
                                          Obx(
                                            () =>
                                                Text(
                                                      currencyController
                                                          .formatAmount(
                                                            currencyController
                                                                .totalBalance
                                                                .value,
                                                          ),
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w900,
                                                        fontSize: 14,
                                                        color: Colors.white,
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
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    ).animate().fadeIn(duration: 800.ms).scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1));
  }

  Widget _buildCardChip() {
    return Container(
      width: 48,
      height: 36,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFD4AF37),
            const Color(0xFFF7E7CE),
            const Color(0xFFD4AF37),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Chip Lines
          ...List.generate(
            3,
            (i) => Positioned(
              top: 12.0 * i + 6,
              left: 0,
              right: 0,
              child: Container(height: 0.5, color: Colors.black26),
            ),
          ),
          ...List.generate(
            3,
            (i) => Positioned(
              left: 16.0 * i + 8,
              top: 0,
              bottom: 0,
              child: Container(width: 0.5, color: Colors.black26),
            ),
          ),
          // Center detail
          Center(
            child: Container(
              width: 12,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: Colors.black26, width: 0.2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Obx(
                () => _buildSquareActionButton(
                  label: 'withdraw'.tr,
                  isLocked: !authController.isVerified.value,
                  icon: Icons.remove_circle_outline_rounded,
                  iconColor: AppColors.darkGold,
                  onTap: () {
                    if (authController.isVerified.value) {
                      Get.toNamed(Routes.withdraw);
                    } else {
                      _showKYCPrompt();
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSquareActionButton(
                label: 'deposit'.tr,
                icon: Icons.add_circle_outline_rounded,
                iconColor: AppColors.softGreen,
                onTap: () => Get.toNamed(Routes.deposit),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Obx(
                () => _buildTransferButton(
                  label: 'p2p_transfer'.tr,
                  isLocked: !authController.isVerified.value,
                  icon: Icons.swap_horizontal_circle_outlined,
                  iconColor: AppColors.softGreen,
                  onTap: () {
                    if (authController.isVerified.value) {
                      Get.toNamed(Routes.transfer);
                    } else {
                      _showKYCPrompt();
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Obx(
                () => _buildTransferButton(
                  label: 'receive_funds'.tr,
                  isLocked: !authController.isVerified.value,
                  icon: Icons.qr_code_scanner_rounded,
                  iconColor: AppColors.darkGold,
                  onTap: () {
                    if (authController.isVerified.value) {
                      Get.toNamed(Routes.qrScanner);
                    } else {
                      _showKYCPrompt();
                    }
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton.icon(
            onPressed: () => Get.toNamed(Routes.myQr),
            icon: Icon(Icons.qr_code_rounded, color: AppColors.darkGold, size: 18),
            label: Text(
              'my_qr'.tr,
              style: TextStyle(
                color: AppColors.darkGold,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildSquareActionButton({
    required String label,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    bool isLocked = false,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          height: 140,
        decoration: BoxDecoration(
          color: isDark ? AppColors.surface : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildActionIcon(
              icon: icon,
              iconColor: iconColor,
              isLocked: isLocked,
              size: 32,
            ),
            const SizedBox(height: 16),
            Text(
              label,
              style: TextStyle(
                color: isLocked
                    ? (isDark
                          ? AppColors.textSecondary
                          : AppColors.textSecondaryLight)
                    : Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildTransferButton({
    required String label,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    bool isLocked = false,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surface : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(40),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildActionIcon(
              icon: icon,
              iconColor: iconColor,
              isLocked: isLocked,
              size: 28,
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                color: isLocked
                    ? (isDark
                          ? AppColors.textSecondary
                          : AppColors.textSecondaryLight)
                    : Theme.of(context).colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildActionIcon({
    required IconData icon,
    required Color iconColor,
    required bool isLocked,
    double size = 28,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: EdgeInsets.all(size * 0.35),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (isLocked ? Colors.grey : iconColor).withValues(alpha: 0.05),
          ),
          child: Icon(
            icon,
            color: isLocked ? Colors.grey.withValues(alpha: 0.5) : iconColor,
            size: size,
          ),
        ),
        if (isLocked)
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surface : AppColors.surfaceLight,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.05),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.lock_outline_rounded,
                color: AppColors.darkGold,
                size: 12,
              ),
            ),
          ),
      ],
    );
  }

  void _showKYCPrompt() {
    Get.dialog(
      AlertDialog(
        backgroundColor: isDark ? AppColors.surface : AppColors.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: [
            Icon(Icons.verified_user_outlined, color: AppColors.darkGold),
            const SizedBox(width: 12),
            Text('kyc_verification'.tr),
          ],
        ),
        content: Text('kyc_warning'.tr),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'cancel'.tr,
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondary
                    : AppColors.textSecondaryLight,
              ),
            ),
          ),
          KasbyButton(
            width: 120,
            text: 'verify_now'.tr,
            onPressed: () {
              Get.back();
              Get.toNamed(Routes.kyc);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'transaction_history'.tr,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Semantics(
              button: true,
              label: 'see_all'.tr,
              child: GestureDetector(
                onTap: () => Get.toNamed(Routes.allTransactions),
                child: Row(
                children: [
                  Text(
                    'see_all'.tr,
                    style: TextStyle(
                      color: AppColors.darkGold,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: AppColors.darkGold,
                    size: 12,
                  ),
                ],
                ),
              ),
            ),
          ],
        ).animate().fadeIn(delay: 500.ms),
        const SizedBox(height: 24),
        Obx(() {
          if (homeController.isLoadingTransactions.value) {
            return Column(
              children: List.generate(
                5,
                (i) => KasbyShimmer.transactionItem(isDark: isDark),
              ),
            );
          }

          final transactions = homeController.recentTransactions
              .take(10)
              .toList();
          
          if (transactions.isEmpty) {
            return Center(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Icon(
                    Icons.history_rounded,
                    size: 64,
                    color: AppColors.textSecondary.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'no_transactions'.tr,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }

          final grouped = _groupTransactions(transactions);

          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: grouped.length,
            itemBuilder: (context, index) {
              final group = grouped[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 24, bottom: 12, left: 4),
                    child: Text(
                      group.title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkGold,
                        letterSpacing: 1.2,
                      ),
                    ).animate().fadeIn().slideX(begin: -0.1, end: 0),
                  ),
                  ...group.items.map((tx) => _buildGlassTransactionItem(tx)),
                ],
              );
            },
          );
        }),
      ],
    );
  }

  List<_TransactionGroup> _groupTransactions(List<TransactionModel> txs) {
    final groups = <_TransactionGroup>[];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (var tx in txs) {
      final date = tx.createdAt ?? DateTime.now();
      final txDate = DateTime(date.year, date.month, date.day);
      
      String title;
      if (txDate == today) {
        title = 'today'.tr.toUpperCase();
      } else if (txDate == yesterday) {
        title = 'yesterday'.tr.toUpperCase();
      } else {
        title = DateFormat('MMMM d, y').format(txDate).toUpperCase();
      }

      final existingGroup = groups.firstWhereOrNull((g) => g.title == title);
      if (existingGroup != null) {
        existingGroup.items.add(tx);
      } else {
        groups.add(_TransactionGroup(title: title, items: [tx]));
      }
    }
    return groups;
  }

  Widget _buildGlassTransactionItem(TransactionModel tx) {
    final isNegative = tx.type == 'withdrawal' || tx.type == 'transfer_out' || tx.type == 'investment';
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        opacity: isDark ? 0.03 : 0.05,
        child: InkWell(
          onTap: () => Get.toNamed(Routes.transactionDetails, arguments: tx),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _getTransactionColor(tx.type).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getTransactionIcon(tx.type),
                  color: _getTransactionColor(tx.type),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.description ?? tx.type.tr,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('hh:mm a').format(tx.createdAt ?? DateTime.now()),
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isNegative ? "-" : "+"}${currencyController.formatAmount(tx.amount)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: isNegative ? AppColors.error : AppColors.softGreen,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getStatusColor(tx.status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      tx.status.tr.toUpperCase(),
                      style: TextStyle(
                        color: _getStatusColor(tx.status),
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.2, end: 0);
  }

  Color _getTransactionColor(String type) {
    switch (type) {
      case 'deposit': return AppColors.softGreen;
      case 'withdraw': return AppColors.error;
      case 'transfer_in': return Colors.blue;
      case 'transfer_out': return AppColors.darkGold;
      case 'investment': return AppColors.darkGold;
      case 'reward': return Colors.purple;
      default: return AppColors.darkGold;
    }
  }

  IconData _getTransactionIcon(String type) {
    switch (type) {
      case 'deposit': return Icons.add_circle_outline_rounded;
      case 'withdraw': return Icons.remove_circle_outline_rounded;
      case 'transfer_in': return Icons.arrow_downward_rounded;
      case 'transfer_out': return Icons.arrow_upward_rounded;
      case 'investment': return Icons.trending_up_rounded;
      case 'reward': return Icons.stars_rounded;
      default: return Icons.swap_horiz_rounded;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed': return AppColors.softGreen;
      case 'pending': return AppColors.darkGold;
      case 'failed': return AppColors.error;
      case 'cancelled': return AppColors.textSecondary;
      default: return AppColors.darkGold;
    }
  }
}

class CardTexturePainter extends CustomPainter {
  final Color color;

  CardTexturePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;

    const spacing = 15.0;
    for (double i = 0; i < size.width + size.height; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(0, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TransactionGroup {
  final String title;
  final List<TransactionModel> items;

  _TransactionGroup({required this.title, required this.items});
}
