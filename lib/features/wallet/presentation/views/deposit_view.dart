import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/core/widgets/kasby_card.dart';
import 'package:kasby/core/widgets/kasby_text_field.dart';
import 'package:kasby/core/models/agent_model.dart';
import 'package:kasby/core/services/account_restriction_service.dart';
import 'package:kasby/core/services/agent_service.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:flutter/services.dart';
import 'package:kasby/core/widgets/glass_card.dart';
import 'package:kasby/core/widgets/transaction_receipt.dart';
import 'package:kasby/core/services/confetti_service.dart';
import 'package:kasby/core/services/snack_service.dart';
import 'package:kasby/core/controllers/currency_controller.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:uuid/uuid.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/core/services/fee_service.dart';
import 'package:kasby/core/widgets/fee_breakdown_card.dart';

class DepositView extends StatefulWidget {
  const DepositView({super.key});

  @override
  State<DepositView> createState() => _DepositViewState();
}

class _DepositViewState extends State<DepositView> {
  final RxList<AgentModel> agents = <AgentModel>[].obs;
  final RxBool isLoading = true.obs;
  final RxInt selectedAgent = 0.obs;
  final TextEditingController _amountController = TextEditingController();
  final RxDouble _amountPreview = 0.0.obs;
  bool _isSubmitting = false;
  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    FeeService.load();
    _fetchAgents();
    _amountController.addListener(_syncAmountPreview);
  }

  void _syncAmountPreview() {
    _amountPreview.value = double.tryParse(_amountController.text.trim()) ?? 0;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _fetchAgents() async {
    isLoading.value = true;
    try {
      agents.value = await AgentService.fetchActiveAgents(limit: 20);
      SafeGetx.debugTrace(
        className: 'DepositView',
        method: '_fetchAgents',
        feature: 'Wallet',
        status: 'SUCCESS',
        params: {'count': agents.length},
      );
    } catch (_) {
      // traceAsync already logged the failure.
    } finally {
      isLoading.value = false;
    }
  }

  void _handleDeposit() {
    if (!AccountRestrictionService.to.checkWriteAccess()) return;
    if (HomeController.to.dashboard.value?.isFrozen == true) {
      Get.snackbar('error'.tr, 'wallet_frozen'.tr);
      return;
    }

    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      AppSnack.warning(
        'validation_error_title'.tr,
        'validation_error_desc'.tr,
      );
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount < 10) {
      AppSnack.error(
        'deposit_min_title'.tr,
        'deposit_min_desc'.tr,
      );
      return;
    }

    if (agents.isEmpty) {
      AppSnack.warning(
        'no_agents_title'.tr,
        'no_agents_desc'.tr,
      );
      return;
    }

    _showConfirmationDialog(amount);
  }

  void _showConfirmationDialog(double amount) {
    final agent = agents[selectedAgent.value];
    final fee = FeeService.totalFee('deposit', amount);
    final rateLabel = FeeService.feeRateLabel('deposit');
    Get.dialog(
      AlertDialog(
        backgroundColor: isDark ? AppColors.surface : AppColors.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.softGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.verified_rounded,
                color: AppColors.softGreen,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'confirm_deposit'.tr,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildConfirmRow(
              'deposit_amount'.tr,
              '\$${amount.toStringAsFixed(2)}',
              AppColors.softGreen,
            ),
            if (fee > 0) ...[
              Divider(
                color: isDark
                    ? Colors.white10
                    : Colors.black.withValues(alpha: 0.1),
                height: 24,
              ),
              _buildConfirmRow(
                'expected_fee'.tr,
                '-\$${fee.toStringAsFixed(2)}${rateLabel.isNotEmpty ? ' ($rateLabel)' : ''}',
                AppColors.error,
              ),
              _buildConfirmRow(
                'net_amount'.tr,
                '\$${(amount - fee).toStringAsFixed(2)}',
                AppColors.softGreen,
              ),
            ],
            Divider(
              color: isDark
                  ? Colors.white10
                  : Colors.black.withValues(alpha: 0.1),
              height: 24,
            ),
            _buildConfirmRow('deposit_agent'.tr, agent.name, null),
            Divider(
              color: isDark
                  ? Colors.white10
                  : Colors.black.withValues(alpha: 0.1),
              height: 24,
            ),
            _buildConfirmRow(
              'deposit_location'.tr,
              agent.city.isNotEmpty ? agent.city : agent.country,
              null,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.darkGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.darkGold.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.darkGold,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'deposit_confirm_note'.tr,
                      style: TextStyle(
                        color: AppColors.darkGold,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'cancel'.tr,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          KasbyButton(
            width: 140,
            text: 'confirm'.tr,
            onPressed: () {
              HapticFeedback.mediumImpact();
              Get.back();
              _executeDeposit(amount);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmRow(String label, String value, Color? valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color:
                  valueColor ??
                  (isDark
                      ? Theme.of(context).colorScheme.onSurface
                      : AppColors.textBodyLight),
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Future<void> _executeDeposit(double amount) async {
    setState(() => _isSubmitting = true);

    try {
      final selectedAgentModel = agents[selectedAgent.value];
      final userId = SupabaseService.userId;
      if (userId == null) return;

      final idempotencyKey = const Uuid().v4();

      final result = await SafeGetx.traceAsync(
        className: 'DepositView',
        method: '_executeDeposit',
        feature: 'Wallet',
        params: {
          'table': 'transactions',
          'operation': 'RPC',
          'rpc': 'fn_create_deposit_request',
          'amount': amount,
          'agentId': selectedAgentModel.id,
        },
        operation: () => SupabaseService.client.rpc(
          'fn_create_deposit_request',
          params: {
            'p_amount': amount,
            'p_agent_id': selectedAgentModel.id,
            'p_idempotency_key': idempotencyKey,
          },
        ),
      );

      final response = result as Map<String, dynamic>?;
      if (response == null || response['success'] != true) {
        SafeGetx.debugTrace(
          className: 'DepositView',
          method: '_executeDeposit',
          feature: 'Wallet',
          status: 'WARNING',
          message: response?['error']?.toString(),
        );
        AppSnack.error(
          'deposit_error_title'.tr,
          (response?['error'] as String?) ?? 'deposit_error_desc'.tr,
        );
        return;
      }

      ConfettiService.to.celebrate();

      if (Get.isRegistered<HomeController>()) {
        HomeController.to.fetchDashboard();
      }
      if (Get.isRegistered<CurrencyController>()) {
        CurrencyController.to.fetchWalletBalances();
      }

      _showSuccessOverlay(
        amount,
        selectedAgentModel.name,
        response['transaction_id']?.toString() ?? '',
      );
    } catch (_) {
      AppSnack.error(
        'deposit_error_title'.tr,
        'deposit_error_desc'.tr,
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessOverlay(
    double amount,
    String agentName,
    String transactionId,
  ) {
    Get.to(
      () => TransactionReceipt(
        transactionId: transactionId,
        recipientName: agentName,
        amount: amount,
        type: 'deposit'.tr,
        date: DateTime.now(),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('deposit_funds'.tr),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Get.back(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            KasbyCard(
              color: isDark ? AppColors.surface : AppColors.surfaceLight,
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.darkGold),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'deposit_desc'.tr,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.textSecondary
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            KasbyTextField(
              label: 'deposit_amount'.tr,
              hint: 'enter_amount_usd'.tr,
              controller: _amountController,
              keyboardType: TextInputType.number,
              prefixIcon: Icon(
                Icons.attach_money_rounded,
                color: AppColors.darkGold,
              ),
            ),
            const SizedBox(height: 16),
            Obx(
              () => FeeBreakdownCard(
                category: 'deposit',
                amount: _amountPreview.value,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'select_payment_agent'.tr,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildAgentSelector(),
            const SizedBox(height: 48),
            _isSubmitting
                ? Center(
                    child: CircularProgressIndicator(color: AppColors.darkGold),
                  )
                : KasbyButton(
                    text: 'proceed_to_payment'.tr,
                    onPressed: _handleDeposit,
                  ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildAgentSelector() {
    return Obx(() {
      if (isLoading.value) {
        return Center(
          child: CircularProgressIndicator(color: AppColors.darkGold),
        );
      }

      if (agents.isEmpty) {
        return KasbyCard(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'no_agents'.tr,
               style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        );
      }

      return Obx(
        () => RadioGroup<int>(
          groupValue: selectedAgent.value,
          onChanged: (val) => selectedAgent.value = val ?? 0,
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: agents.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final agent = agents[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassCard(
                  padding: EdgeInsets.zero,
                  opacity: isDark ? 0.03 : 0.05,
                  child: RadioListTile<int>(
                    value: index,
                    activeColor: AppColors.darkGold,
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            agent.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (agent.successRate > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.softGreen.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${agent.successRate.toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: AppColors.softGreen,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text(
                      '${agent.city}, ${agent.country}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    });
  }
}
