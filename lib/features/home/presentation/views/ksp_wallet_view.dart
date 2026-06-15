import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_card.dart';
import 'package:kasby/core/widgets/glass_card.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/models/transaction_model.dart';
import 'package:kasby/core/utils/ksp_converter.dart';
import 'package:kasby/core/models/ksp_category.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:kasby/routes/app_routes.dart';
import 'package:kasby/core/utils/safe_getx.dart';

class KspWalletView extends StatefulWidget {
  const KspWalletView({super.key});

  @override
  State<KspWalletView> createState() => _KspWalletViewState();
}

class _KspWalletViewState extends State<KspWalletView> {
  final RxList<TransactionModel> pointsHistory = <TransactionModel>[].obs;
  final RxBool isLoading = true.obs;

  @override
  void initState() {
    super.initState();
    SafeGetx.debugTrace(
      className: 'KspWalletView',
      method: 'initState',
      feature: 'Home',
      status: 'INFO',
    );
    _fetchPointsData();
  }

  @override
  void dispose() {
    SafeGetx.debugTrace(
      className: 'KspWalletView',
      method: 'dispose',
      feature: 'Home',
      status: 'INFO',
    );
    super.dispose();
  }

  Future<void> _fetchPointsData() async {
    if (!SupabaseService.isLoggedIn) return;
    final stopwatch = Stopwatch()..start();
    isLoading.value = true;
    try {
      // Refresh points and metrics from centralized controller
      await HomeController.to.fetchPoints();

      // Fetch points history from point_history table
      final historyResponse = await SupabaseService.client
          .from('point_history')
          .select()
          .eq('user_id', SupabaseService.userId!)
          .order('created_at', ascending: false)
          .limit(50);

      pointsHistory.value = (historyResponse as List).map((json) {
        return TransactionModel(
          id: json['id'],
          userId: json['user_id'],
          walletId: 'ksp_wallet',
          amount: (json['points'] as num).toDouble(),
          type: json['type'],
          status: 'completed',
          description: json['description'],
          createdAt: DateTime.parse(json['created_at']),
        );
      }).toList();
      SafeGetx.debugTrace(
        className: 'KspWalletView',
        method: '_fetchPointsData',
        feature: 'Home',
        status: 'SUCCESS',
        durationMs: stopwatch.elapsedMilliseconds,
        params: {'historyCount': pointsHistory.length},
      );
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'KspWalletView',
        method: '_fetchPointsData',
        feature: 'Home',
        status: 'ERROR',
        durationMs: stopwatch.elapsedMilliseconds,
        error: e,
        stackTrace: stack,
      );
    } finally {
      isLoading.value = false;
    }
  }

  int get _calculateDailyProfit {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    return pointsHistory
        .where((tx) => tx.type == 'earn' && tx.createdAt != null && tx.createdAt!.isAfter(todayStart))
        .fold(0, (sum, tx) => sum + tx.amount.toInt());
  }

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0E0E11) : Colors.grey.shade50,
      appBar: AppBar(
        title: Text('ksp_wallet'.tr),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            HapticFeedback.lightImpact();
            Get.back();
          },
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchPointsData,
        color: AppColors.darkGold,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBalanceCard(),
              const SizedBox(height: 24),
              _buildMetricsRow(),
              const SizedBox(height: 28),
              _buildQuickActions(),
              const SizedBox(height: 28),
              _buildHistorySection(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return GlassCard(
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(28),
      borderColor: AppColors.darkGold.withValues(alpha: 0.15),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/ksp_coin.png',
                width: 48,
                height: 48,
              ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2500.ms),
              const SizedBox(width: 12),
              Text(
                'ksp_balance'.tr,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Obx(
            () => Text(
              KspConverter.formatKsp(HomeController.to.userPoints.value),
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: AppColors.darkGold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Obx(() {
            final usdEquivalent = KspConverter.kspToUsd(HomeController.to.userPoints.value.toDouble());
            return Text(
              '≈ \$${usdEquivalent.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white38 : Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            );
          }),
        ],
      ),
    ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack).fadeIn();
  }

  Widget _buildMetricsRow() {
    return Obx(() {
      final dailyProfit = _calculateDailyProfit;
      final totalEarned = HomeController.to.totalEarnedKsp.value;
      final totalSpent = HomeController.to.totalSpentKsp.value;

      return Row(
        children: [
          Expanded(
            child: _buildMetricCard(
              'ksp_daily_profit'.tr,
              dailyProfit,
              Icons.trending_up_rounded,
              AppColors.softGreen,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildMetricCard(
              'ksp_total_earned'.tr,
              totalEarned,
              Icons.add_circle_outline_rounded,
              AppColors.darkGold,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildMetricCard(
              'ksp_total_spent'.tr,
              totalSpent,
              Icons.remove_circle_outline_rounded,
              AppColors.error,
            ),
          ),
        ],
      ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1, end: 0);
    });
  }

  Widget _buildMetricCard(String title, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white38 : Colors.grey.shade600,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${value > 0 ? '+' : ''}$value',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'quick_actions'.tr,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildActionItem(
              'daily_check_in'.tr,
              Icons.calendar_today_rounded,
              AppColors.darkGold,
              () => Get.toNamed(Routes.dailyCheckIn),
            ),
            _buildActionItem(
              'spin_wheel'.tr,
              Icons.casino_rounded,
              AppColors.darkGold,
              () => Get.toNamed(Routes.spinWheel),
            ),
            _buildActionItem(
              'transfer_ksp'.tr,
              Icons.send_rounded,
              AppColors.darkGold,
              () => Get.toNamed(Routes.transfer),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 250.ms);
  }

  Widget _buildActionItem(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.1 : 0.08),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.15), width: 1.5),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'ksp_history'.tr,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        Obx(() {
          if (isLoading.value) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.darkGold),
              ),
            );
          }

          if (pointsHistory.isEmpty) {
            return KasbyCard(
              padding: const EdgeInsets.all(28),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.history_toggle_off_rounded, size: 40, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text(
                      'no_transactions'.tr,
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pointsHistory.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final tx = pointsHistory[index];
              final category = KspCategoryType.fromDescription(tx.description, tx.type);

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _showTransactionDetails(tx, category);
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surface : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: category.color.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          category.icon,
                          color: category.color,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category.label,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tx.description ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDark ? Colors.white38 : Colors.grey.shade600,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${tx.type == 'earn' ? '+' : '-'}${tx.amount.toInt()}',
                            style: TextStyle(
                              color: tx.type == 'earn' ? AppColors.softGreen : AppColors.error,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          if (tx.createdAt != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${tx.createdAt!.day}/${tx.createdAt!.month}/${tx.createdAt!.year}',
                              style: TextStyle(
                                color: isDark ? Colors.white38 : Colors.grey.shade600,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }),
      ],
    ).animate().fadeIn(delay: 350.ms);
  }

  void _showTransactionDetails(TransactionModel tx, KspCategoryType category) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: category.color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(category.icon, color: category.color, size: 24),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ksp_transaction_details'.tr,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      category.label,
                      style: TextStyle(
                        color: category.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            _buildDetailRow('ksp_amount'.tr, '${tx.type == 'earn' ? '+' : '-'}${tx.amount.toInt()} KSP', color: tx.type == 'earn' ? AppColors.softGreen : AppColors.error),
            _buildDetailRow('usd_equivalent'.tr, '\$${KspConverter.kspToUsd(tx.amount).toStringAsFixed(2)}'),
            if (tx.createdAt != null)
              _buildDetailRow('date'.tr, '${tx.createdAt!.day.toString().padLeft(2, '0')}/${tx.createdAt!.month.toString().padLeft(2, '0')}/${tx.createdAt!.year} ${tx.createdAt!.hour.toString().padLeft(2, '0')}:${tx.createdAt!.minute.toString().padLeft(2, '0')}'),
            _buildDetailRow('reference_id'.tr, tx.id),
            _buildDetailRow('description'.tr, tx.description ?? 'N/A', isLast: true),
            const SizedBox(height: 20),
            KasbyButton(
              text: 'close'.tr,
              onPressed: () => Get.back(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color, bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white54 : Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color ?? (isDark ? Colors.white : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
