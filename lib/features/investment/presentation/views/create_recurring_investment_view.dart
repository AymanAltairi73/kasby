import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:kasby/core/models/investment_plan_model.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/core/widgets/kasby_card.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/features/investment/presentation/controllers/recurring_investment_controller.dart';

class CreateRecurringInvestmentView extends StatefulWidget {
  const CreateRecurringInvestmentView({super.key});

  @override
  State<CreateRecurringInvestmentView> createState() =>
      _CreateRecurringInvestmentViewState();
}

class _CreateRecurringInvestmentViewState
    extends State<CreateRecurringInvestmentView> {
  late final RecurringInvestmentController _controller;

  final _selectedPlan = Rxn<InvestmentPlanModel>();
  final _selectedAmount = Rxn<double>();
  final _selectedFrequency = 'monthly'.obs;
  final _customDays = Rxn<int>();
  final _termsAccepted = false.obs;
  final _customDaysController = TextEditingController();

  static const _frequencies = ['daily', 'weekly', 'monthly', 'custom'];

  @override
  void initState() {
    super.initState();
    _controller = Get.find<RecurringInvestmentController>();
  }

  @override
  void dispose() {
    _customDaysController.dispose();
    super.dispose();
  }

  bool get _canCreate =>
      _selectedPlan.value != null &&
      _selectedAmount.value != null &&
      _termsAccepted.value &&
      (_selectedFrequency.value != 'custom' || (_customDays.value ?? 0) > 0);

  double? get _estimatedYearlyProfit {
    final plan = _selectedPlan.value;
    final amount = _selectedAmount.value;
    if (plan == null || amount == null) return null;
    final executionsPerYear = _executionsPerYear;
    return amount * (plan.profitPercentage / 100) * executionsPerYear;
  }

  double get _executionsPerYear {
    switch (_selectedFrequency.value) {
      case 'daily':
        return 365;
      case 'weekly':
        return 52;
      case 'monthly':
        return 12;
      case 'custom':
        final days = _customDays.value ?? 30;
        return days > 0 ? 365 / days : 12;
      default:
        return 12;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('create_recurring'.tr),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Get.back(),
        ),
      ),
      body: Obx(() {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(KasbySpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionLabel('select_plan'.tr),
              const SizedBox(height: KasbySpacing.sm),
              _buildPlanSelector(isDark),

              const SizedBox(height: KasbySpacing.xxl),
              _buildSectionLabel('amount'.tr),
              const SizedBox(height: KasbySpacing.sm),
              _buildAmountSelector(isDark),

              const SizedBox(height: KasbySpacing.xxl),
              _buildSectionLabel('select_frequency'.tr),
              const SizedBox(height: KasbySpacing.sm),
              _buildFrequencySelector(isDark),

              if (_selectedFrequency.value == 'custom') ...[
                const SizedBox(height: KasbySpacing.lg),
                _buildCustomDaysInput(isDark),
              ],

              const SizedBox(height: KasbySpacing.xxl),
              _buildSummaryCard(isDark),

              const SizedBox(height: KasbySpacing.lg),
              _buildRiskDisclosure(isDark),

              const SizedBox(height: KasbySpacing.lg),
              _buildTermsCheckbox(isDark),

              const SizedBox(height: KasbySpacing.xxl),
              KasbyButton(
                text: 'create_recurring'.tr,
                isLoading: _controller.isCreating.value,
                onPressed: _canCreate ? _onCreatePressed : null,
              ),
              const SizedBox(height: KasbySpacing.xxxl),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildPlanSelector(bool isDark) {
    final plans = _controller.availablePlans;

    if (plans.isEmpty) {
      return KasbyCard(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(KasbySpacing.lg),
            child: Text(
              'no_plans'.tr,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: KasbySpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : AppColors.surfaceLight,
        borderRadius: KasbyRadius.inputR,
        border: Border.all(
          color: isDark
              ? AppColors.onSurface.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<InvestmentPlanModel>(
          value: _selectedPlan.value,
          hint: Text(
            'select_plan'.tr,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          isExpanded: true,
          dropdownColor: isDark ? AppColors.surface : AppColors.surfaceLight,
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.darkGold),
          items: plans.map((plan) {
            final name = Get.locale?.languageCode == 'ar'
                ? plan.nameAr
                : (plan.nameEn ?? plan.nameAr);
            return DropdownMenuItem(
              value: plan,
              child: Text(
                '$name  •  ${plan.profitPercentage.toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 14),
              ),
            );
          }).toList(),
          onChanged: (plan) {
            _selectedPlan.value = plan;
            _selectedAmount.value = null;
          },
        ),
      ),
    );
  }

  Widget _buildAmountSelector(bool isDark) {
    final plan = _selectedPlan.value;
    if (plan == null) {
      return Text(
        'select_plan'.tr,
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      );
    }

    final amounts = plan.availableAmounts
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        [plan.minAmount];

    return Wrap(
      spacing: KasbySpacing.sm,
      runSpacing: KasbySpacing.sm,
      children: amounts.map((amount) {
        final isSelected = _selectedAmount.value == amount;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            _selectedAmount.value = amount;
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
              horizontal: KasbySpacing.lg,
              vertical: KasbySpacing.md,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.darkGold
                  : (isDark
                      ? AppColors.surface
                      : AppColors.surfaceLight),
              borderRadius: KasbyRadius.inputR,
              border: Border.all(
                color: isSelected
                    ? AppColors.darkGold
                    : (isDark
                        ? AppColors.onSurface.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.08)),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Text(
              '\$${amount.toInt()}',
              style: TextStyle(
                color: isSelected
                    ? (isDark ? Colors.black : Colors.white)
                    : AppColors.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 15,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFrequencySelector(bool isDark) {
    return Wrap(
      spacing: KasbySpacing.sm,
      runSpacing: KasbySpacing.sm,
      children: _frequencies.map((freq) {
        final isSelected = _selectedFrequency.value == freq;
        final label = freq == 'custom' ? 'custom_schedule'.tr : freq.tr;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            _selectedFrequency.value = freq;
            if (freq != 'custom') _customDays.value = null;
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
              horizontal: KasbySpacing.lg,
              vertical: KasbySpacing.md,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.darkGold
                  : (isDark
                      ? AppColors.surface
                      : AppColors.surfaceLight),
              borderRadius: KasbyRadius.inputR,
              border: Border.all(
                color: isSelected
                    ? AppColors.darkGold
                    : (isDark
                        ? AppColors.onSurface.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.08)),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? (isDark ? Colors.black : Colors.white)
                    : AppColors.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCustomDaysInput(bool isDark) {
    return Row(
      children: [
        Text(
          'custom_days'.tr,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(width: KasbySpacing.lg),
        SizedBox(
          width: 100,
          child: TextField(
            controller: _customDaysController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (val) {
              _customDays.value = int.tryParse(val);
            },
            style: TextStyle(color: AppColors.onSurface),
            decoration: InputDecoration(
              hintText: '30',
              hintStyle: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.5)),
              filled: true,
              fillColor: isDark ? AppColors.surface : AppColors.surfaceLight,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: KasbySpacing.md,
                vertical: KasbySpacing.sm,
              ),
              border: OutlineInputBorder(
                borderRadius: KasbyRadius.inputR,
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: KasbyRadius.inputR,
                borderSide: BorderSide(color: AppColors.darkGold),
              ),
            ),
          ),
        ),
        const SizedBox(width: KasbySpacing.sm),
        Text(
          'days'.tr,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ],
    ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildSummaryCard(bool isDark) {
    final plan = _selectedPlan.value;
    final amount = _selectedAmount.value;
    final yearlyProfit = _estimatedYearlyProfit;

    return KasbyCard(
      hasShadow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.summarize_rounded,
                  color: AppColors.darkGold, size: 20),
              const SizedBox(width: KasbySpacing.sm),
              Text(
                'recurring_summary'.tr,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.darkGold,
                ),
              ),
            ],
          ),
          const SizedBox(height: KasbySpacing.lg),
          _summaryRow(
            'investment_plan'.tr,
            plan != null
                ? (Get.locale?.languageCode == 'ar'
                    ? plan.nameAr
                    : (plan.nameEn ?? plan.nameAr))
                : '—',
          ),
          const SizedBox(height: KasbySpacing.sm),
          _summaryRow(
            'amount'.tr,
            amount != null ? '\$${amount.toInt()}' : '—',
          ),
          const SizedBox(height: KasbySpacing.sm),
          _summaryRow(
            'frequency'.tr,
            _selectedFrequency.value == 'custom'
                ? '${'custom_schedule'.tr} (${_customDays.value ?? '—'} ${'days'.tr})'
                : _selectedFrequency.value.tr,
          ),
          if (yearlyProfit != null) ...[
            const Divider(height: KasbySpacing.xxl),
            _summaryRow(
              'estimated_yearly_profit'.tr,
              '+\$${yearlyProfit.toStringAsFixed(2)}',
              valueColor: AppColors.softGreen,
              isBold: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    Color? valueColor,
    bool isBold = false,
  }) {
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
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildRiskDisclosure(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(KasbySpacing.md),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: KasbyRadius.inputR,
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
          const SizedBox(width: KasbySpacing.sm),
          Expanded(
            child: Text(
              'investment_disclaimer'.tr,
              style: TextStyle(
                color: isDark
                    ? Colors.orange.shade200
                    : Colors.orange.shade800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsCheckbox(bool isDark) {
    return Row(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: _termsAccepted.value,
            onChanged: (v) => _termsAccepted.value = v ?? false,
            activeColor: AppColors.darkGold,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(width: KasbySpacing.sm),
        Expanded(
          child: GestureDetector(
            onTap: () =>
                _termsAccepted.value = !_termsAccepted.value,
            child: Text(
              'accept_plan_terms'.tr,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _onCreatePressed() async {
    HapticFeedback.mediumImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.surface : AppColors.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: KasbyRadius.cardR),
        title: Text('confirm_recurring'.tr),
        content: Text(
          '${'recurring_summary'.tr}\n\n'
          '${_selectedPlan.value?.nameAr ?? ''}\n'
          '\$${_selectedAmount.value?.toInt() ?? 0} · ${_selectedFrequency.value.tr}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr,
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('confirm'.tr,
                style: TextStyle(color: AppColors.darkGold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final plan = _selectedPlan.value!;
    final planName = Get.locale?.languageCode == 'ar'
        ? plan.nameAr
        : (plan.nameEn ?? plan.nameAr);

    final success = await _controller.create(
      planId: plan.id,
      amount: _selectedAmount.value!,
      frequency: _selectedFrequency.value,
      customDays:
          _selectedFrequency.value == 'custom' ? _customDays.value : null,
      planName: planName,
    );

    if (success && mounted) {
      await _showSuccessOverlay();
      Get.back(result: true);
    } else if (mounted) {
      SafeGetx.snackbar(
        title: 'error'.tr,
        message: 'something_went_wrong'.tr,
        backgroundColor: AppColors.error.withValues(alpha: 0.9),
        colorText: Colors.white,
      );
    }
  }

  Future<void> _showSuccessOverlay() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          margin: const EdgeInsets.all(KasbySpacing.xxxl),
          padding: const EdgeInsets.all(KasbySpacing.xxxl),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surface : AppColors.surfaceLight,
            borderRadius: KasbyRadius.heroR,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(KasbySpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.softGreen.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.softGreen,
                  size: 56,
                ),
              ),
              const SizedBox(height: KasbySpacing.xxl),
              Text(
                'recurring_created'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: KasbySpacing.xxl),
              KasbyButton(
                text: 'done'.tr,
                onPressed: () => Navigator.pop(ctx),
                width: 160,
              ),
            ],
          ),
        )
            .animate()
            .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1))
            .fadeIn(),
      ),
    );
  }
}
