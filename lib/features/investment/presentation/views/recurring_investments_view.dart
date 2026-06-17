import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:kasby/core/models/recurring_investment_model.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';
import 'package:kasby/core/widgets/empty_state_widget.dart';
import 'package:kasby/core/widgets/error_state_widget.dart';
import 'package:kasby/core/widgets/kasby_card.dart';
import 'package:kasby/core/widgets/kasby_shimmer.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/features/investment/presentation/controllers/recurring_investment_controller.dart';
import 'package:kasby/routes/app_routes.dart';

class RecurringInvestmentsView extends StatelessWidget {
  const RecurringInvestmentsView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(RecurringInvestmentController());
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('recurring_investments'.tr),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Get.back(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Get.toNamed(Routes.createRecurringInvestment);
          if (result == true) controller.fetchAll();
        },
        backgroundColor: AppColors.darkGold,
        foregroundColor: isDark ? Colors.black : Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text('create_recurring'.tr),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return ListView.separated(
            padding: const EdgeInsets.all(KasbySpacing.xl),
            itemCount: 4,
            separatorBuilder: (_, __) =>
                const SizedBox(height: KasbySpacing.lg),
            itemBuilder: (_, __) => const KasbyShimmer.card(height: 140),
          );
        }

        if (controller.hasError.value) {
          return ErrorStateWidget(onRetry: controller.fetchAll);
        }

        if (controller.recurringInvestments.isEmpty) {
          return EmptyStateWidget(
            title: 'no_recurring'.tr,
            description: 'no_recurring_desc'.tr,
            icon: Icons.repeat_rounded,
            actionText: 'create_recurring'.tr,
            onAction: () async {
              final result =
                  await Get.toNamed(Routes.createRecurringInvestment);
              if (result == true) controller.fetchAll();
            },
          );
        }

        return RefreshIndicator(
          onRefresh: controller.fetchAll,
          color: AppColors.darkGold,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              KasbySpacing.lg,
              KasbySpacing.lg,
              KasbySpacing.lg,
              100,
            ),
            itemCount: controller.recurringInvestments.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: KasbySpacing.md),
            itemBuilder: (context, index) {
              final item = controller.recurringInvestments[index];
              return _RecurringInvestmentTile(
                item: item,
                controller: controller,
              )
                  .animate()
                  .fadeIn(delay: Duration(milliseconds: index * 60))
                  .slideY(begin: 0.05, end: 0);
            },
          ),
        );
      }),
    );
  }
}

class _RecurringInvestmentTile extends StatelessWidget {
  final RecurringInvestmentModel item;
  final RecurringInvestmentController controller;

  const _RecurringInvestmentTile({
    required this.item,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateFormat = DateFormat.yMMMd(Get.locale?.toString());

    return KasbyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(KasbySpacing.sm),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.12),
                  borderRadius: KasbyRadius.chipR,
                ),
                child: Icon(
                  Icons.repeat_rounded,
                  color: _statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: KasbySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.planName ?? item.planId,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\$${item.amount.toStringAsFixed(0)} · ${item.frequencyLabel.tr}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(status: item.status),
            ],
          ),

          const SizedBox(height: KasbySpacing.lg),

          _InfoRow(
            label: 'next_execution'.tr,
            value: item.nextExecutionDate != null
                ? dateFormat.format(item.nextExecutionDate!)
                : '—',
          ),
          const SizedBox(height: KasbySpacing.sm),
          _InfoRow(
            label: 'total_executions'.tr,
            value: '${item.totalExecutions}',
          ),
          const SizedBox(height: KasbySpacing.sm),
          _InfoRow(
            label: 'successful_executions'.tr,
            value: '${item.successfulExecutions}',
            valueColor: AppColors.softGreen,
          ),
          if (item.failedExecutions > 0) ...[
            const SizedBox(height: KasbySpacing.sm),
            _InfoRow(
              label: 'failed_executions'.tr,
              value: '${item.failedExecutions}',
              valueColor: AppColors.error,
            ),
          ],

          const SizedBox(height: KasbySpacing.lg),

          Row(
            children: [
              if (item.isActive)
                _ActionChip(
                  label: 'pause_recurring'.tr,
                  icon: Icons.pause_rounded,
                  color: Colors.orange,
                  onTap: () => _confirmAction(
                    context,
                    title: 'pause_recurring'.tr,
                    onConfirm: () => controller.pause(item.id),
                    isDark: isDark,
                  ),
                ),
              if (item.isPaused)
                _ActionChip(
                  label: 'resume_recurring'.tr,
                  icon: Icons.play_arrow_rounded,
                  color: AppColors.softGreen,
                  onTap: () => _confirmAction(
                    context,
                    title: 'resume_recurring'.tr,
                    onConfirm: () => controller.resume(item.id),
                    isDark: isDark,
                  ),
                ),
              if (!item.isCancelled) ...[
                const SizedBox(width: KasbySpacing.sm),
                _ActionChip(
                  label: 'edit'.tr,
                  icon: Icons.edit_rounded,
                  color: AppColors.darkGold,
                  onTap: () => _showEditSheet(context, isDark),
                ),
                const SizedBox(width: KasbySpacing.sm),
                _ActionChip(
                  label: 'cancel_recurring'.tr,
                  icon: Icons.cancel_outlined,
                  color: AppColors.error,
                  onTap: () => _confirmAction(
                    context,
                    title: 'cancel_recurring'.tr,
                    onConfirm: () => controller.cancel(item.id),
                    isDark: isDark,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext context, bool isDark) {
    final amountController = TextEditingController(
      text: item.amount.toStringAsFixed(0),
    );
    final selectedFrequency = item.frequency.obs;
    final customDaysController = TextEditingController(
      text: item.customDays?.toString() ?? '',
    );

    // Build amount options from the plan if available
    final plan = controller.availablePlans.firstWhereOrNull(
      (p) => p.id == item.planId,
    );
    final amounts = plan?.availableAmounts != null &&
            plan!.availableAmounts!.isNotEmpty
        ? plan.availableAmounts!.map((e) => e.toString()).toList()
        : <String>[item.amount.toStringAsFixed(0)];

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surface : AppColors.surfaceLight,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
        child: SingleChildScrollView(
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
              const SizedBox(height: 20),
              Text(
                'edit_recurring'.tr,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              // Amount dropdown
              Text(
                'investment_amount'.tr,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: KasbyRadius.chipR,
                  border: Border.all(
                    color: AppColors.darkGold.withValues(alpha: 0.3),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: amountController.text,
                    isExpanded: true,
                    dropdownColor: isDark
                        ? AppColors.surface
                        : AppColors.surfaceLight,
                    items: amounts.map((a) {
                      final cleaned = a.replaceAll(RegExp(r'[^\d.]'), '');
                      return DropdownMenuItem(
                        value: cleaned,
                        child: Text('\$$cleaned'),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) amountController.text = v;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Frequency
              Text(
                'frequency'.tr,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Obx(() => Wrap(
                spacing: KasbySpacing.sm,
                children: ['daily', 'weekly', 'monthly', 'custom']
                    .map((f) => ChoiceChip(
                          label: Text(f.tr),
                          selected: selectedFrequency.value == f,
                          selectedColor:
                              AppColors.darkGold.withValues(alpha: 0.2),
                          onSelected: (_) => selectedFrequency.value = f,
                        ))
                    .toList(),
              )),
              const SizedBox(height: 12),
              // Custom days (only if custom)
              Obx(() {
                if (selectedFrequency.value != 'custom') {
                  return const SizedBox.shrink();
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'custom_days'.tr,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: customDaysController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'enter_days'.tr,
                        border: OutlineInputBorder(
                          borderRadius: KasbyRadius.chipR,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              }),
              const SizedBox(height: 20),
              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.darkGold,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: KasbyRadius.chipR,
                    ),
                  ),
                  onPressed: () async {
                    final amount =
                        double.tryParse(amountController.text);
                    final frequency = selectedFrequency.value;
                    final customDays =
                        int.tryParse(customDaysController.text);

                    final success = await controller.edit(
                      item.id,
                      amount: amount,
                      frequency: frequency,
                      customDays:
                          frequency == 'custom' ? customDays : null,
                    );
                    if (success) {
                      Get.back();
                      HapticFeedback.mediumImpact();
                    }
                  },
                  child: Text(
                    'save'.tr,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Color get _statusColor {
    switch (item.status) {
      case 'active':
        return AppColors.softGreen;
      case 'paused':
        return Colors.orange;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  Future<void> _confirmAction(
    BuildContext context, {
    required String title,
    required Future<bool> Function() onConfirm,
    required bool isDark,
  }) async {
    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.surface : AppColors.surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: KasbyRadius.cardR,
        ),
        title: Text(title),
        content: Text('confirm_recurring'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'cancel'.tr,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'confirm'.tr,
              style: TextStyle(color: AppColors.darkGold),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final success = await onConfirm();
      if (success && context.mounted) {
        SafeGetx.snackbar(
          title: 'success'.tr,
          message: title,
          backgroundColor:
              isDark ? AppColors.surface : AppColors.surfaceLight,
          colorText: AppColors.onSurface,
        );
      }
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color color, String label) = switch (status) {
      'active' => (AppColors.softGreen, 'active'.tr),
      'paused' => (Colors.orange, 'paused'.tr),
      'cancelled' => (AppColors.error, 'cancelled'.tr),
      _ => (AppColors.textSecondary, status),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KasbySpacing.sm,
        vertical: KasbySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: KasbyRadius.chipR,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppColors.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: KasbyRadius.chipR,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: KasbySpacing.sm,
          vertical: KasbySpacing.xs,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: KasbyRadius.chipR,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
