import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_card.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/features/profile/presentation/controllers/agent_controller.dart';
import 'package:kasby/core/controllers/currency_controller.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AgentDashboardView extends StatelessWidget {
  const AgentDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(AgentController());
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('agent_dashboard'.tr),
        actions: [
          Obx(() => Row(
                children: [
                  Text(
                    (controller.agentProfile.value?.isAvailableNow ?? false)
                        ? 'online'.tr
                        : 'offline'.tr,
                    style: TextStyle(
                      fontSize: 12,
                      color: (controller.agentProfile.value?.isAvailableNow ?? false)
                          ? AppColors.softGreen
                          : AppColors.textSecondary,
                    ),
                  ),
                  Opacity(
                    opacity: controller.isLoading.value ? 0.5 : 1.0,
                    child: Switch.adaptive(
                      value: controller.agentProfile.value?.isAvailableNow ?? false,
                      activeColor: AppColors.softGreen,
                      onChanged: controller.isLoading.value 
                        ? null 
                        : (val) => controller.toggleAvailability(),
                    ),
                  ),
                ],
              )),
          IconButton(
            onPressed: () => controller.refreshData(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.pendingOperations.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: () => controller.refreshData(),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatsGrid(context, controller),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Text(
                            'pending_operations'.tr,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildLiveIndicator(),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (controller.pendingOperations.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assignment_turned_in_rounded,
                          size: 60,
                          color: AppColors.textSecondary.withValues(alpha: 0.2),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'no_pending_operations'.tr,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final tx = controller.pendingOperations[index];
                        return _buildOperationCard(context, tx, controller, isDark);
                      },
                      childCount: controller.pendingOperations.length,
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildStatsGrid(BuildContext context, AgentController controller) {
    final profile = controller.agentProfile.value;
    if (profile == null) return const SizedBox();

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'escrow_balance'.tr,
          CurrencyController.to.formatToUSD(profile.escrowBalance),
          Icons.account_balance_wallet_rounded,
          AppColors.darkGold,
        ),
        _buildStatCard(
          'total_earnings'.tr,
          CurrencyController.to.formatToUSD(profile.totalCommissionEarned),
          Icons.payments_rounded,
          AppColors.softGreen,
        ),
        _buildStatCard(
          'available_cash'.tr,
          CurrencyController.to.formatToUSD(profile.availableCash),
          Icons.money_rounded,
          Colors.blue,
        ),
        _buildStatCard(
          'success_rate'.tr,
          '${profile.successRate.toStringAsFixed(1)}%',
          Icons.star_rounded,
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return KasbyCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOperationCard(BuildContext context, dynamic tx, AgentController controller, bool isDark) {
    final isDeposit = tx.type == 'deposit';
    final color = isDeposit ? AppColors.softGreen : AppColors.darkGold;

    return KasbyCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tx.type.tr.toUpperCase(),
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ),
              Text(
                DateFormat('MMM dd, HH:mm').format(tx.createdAt!),
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${'amount'.tr}: ${CurrencyController.to.formatToUSD(tx.amount)}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '${'user_id'.tr}: ${tx.userId.substring(0, 8)}...',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          if (tx.description != null && tx.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              tx.description!,
              style: const TextStyle(fontSize: 13),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: KasbyButton(
                  text: isDeposit ? 'approve_deposit'.tr : 'confirm_payout'.tr,
                  onPressed: () => _showConfirmDialog(context, tx, controller),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.softGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppColors.softGreen,
              shape: BoxShape.circle,
            ),
          ).animate(onPlay: (controller) => controller.repeat()).scaleXY(
                begin: 0.8,
                end: 1.2,
                duration: 1000.ms,
                curve: Curves.easeInOut,
              ).then().scaleXY(
                begin: 1.2,
                end: 0.8,
                duration: 1000.ms,
                curve: Curves.easeInOut,
              ),
          const SizedBox(width: 4),
          Text(
            'LIVE',
            style: TextStyle(
              color: AppColors.softGreen,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showConfirmDialog(BuildContext context, dynamic tx, AgentController controller) {
    final isDeposit = tx.type == 'deposit';
    Get.dialog(
      AlertDialog(
        title: Text(isDeposit ? 'confirm_deposit_approval'.tr : 'confirm_withdrawal_payout'.tr),
        content: Text(isDeposit ? 'confirm_deposit_msg'.tr : 'confirm_payout_msg'.tr),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('cancel'.tr)),
          TextButton(
            onPressed: () {
              Get.back();
              if (isDeposit) {
                controller.approveDeposit(tx.id);
              } else {
                controller.confirmWithdrawal(tx.id);
              }
            },
            child: Text('confirm'.tr, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
