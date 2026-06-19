import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/core/controllers/currency_controller.dart';
import 'package:kasby/core/widgets/kasby_card.dart';
import 'package:kasby/core/widgets/kasby_text_field.dart';
import 'package:kasby/core/models/agent_model.dart';
import 'package:kasby/core/services/account_restriction_service.dart';
import 'package:kasby/core/services/agent_service.dart';
import 'package:kasby/core/services/sensitive_operation_guard.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/widgets/glass_card.dart';
import 'package:kasby/core/widgets/transaction_receipt.dart';
import 'package:kasby/core/services/confetti_service.dart';
import 'package:kasby/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';
import 'package:kasby/routes/app_routes.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/core/services/fee_service.dart';

class WithdrawView extends StatefulWidget {
  const WithdrawView({super.key});

  @override
  State<WithdrawView> createState() => _WithdrawViewState();
}

class _WithdrawViewState extends State<WithdrawView> {
  final RxList<AgentModel> agents = <AgentModel>[].obs;
  final RxBool isLoadingAgents = true.obs;
  final RxInt selectedAgentIndex = 0.obs;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _isSubmitting = false;
  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    FeeService.load();
    _fetchAgents();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _fetchAgents() async {
    isLoadingAgents.value = true;
    try {
      agents.value = await AgentService.fetchActiveAgents(limit: 20);
      SafeGetx.debugTrace(
        className: 'WithdrawView',
        method: '_fetchAgents',
        feature: 'Wallet',
        status: 'SUCCESS',
        params: {'count': agents.length},
      );
    } catch (_) {
      // Logged by AgentService caller if needed.
    } finally {
      isLoadingAgents.value = false;
    }
  }

  Future<void> _handleWithdraw() async {
    if (!AccountRestrictionService.to.checkWriteAccess()) return;
    if (HomeController.to.dashboard.value?.isFrozen == true) {
      Get.snackbar('error'.tr, 'wallet_frozen'.tr);
      return;
    }

    final amountText = _amountController.text.trim();
    
    // Check KYC Status
    if (!AuthController.to.isVerified.value) {
      Get.snackbar(
        'kyc_verification'.tr,
        'verified_account_required'.tr,
        backgroundColor: AppColors.darkGold.withValues(alpha: 0.8),
        colorText: Colors.black,
        mainButton: TextButton(
          onPressed: () {
            Get.back(); // close snackbar
            Get.toNamed(Routes.kyc);
          },
          child: Text('verify_now'.tr, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        ),
      );
      return;
    }

    if (amountText.isEmpty) {
      Get.snackbar(
        'error'.tr,
        'fill_all_data'.tr,
        backgroundColor: AppColors.error.withValues(alpha: 0.7),
        colorText: Colors.white,
      );
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount < 10) {
      Get.snackbar(
        'error'.tr,
        'withdraw_min_error'.tr,
        backgroundColor: AppColors.error.withValues(alpha: 0.7),
        colorText: Colors.white,
      );
      return;
    }

    final limitError = FeeService.validateAmount(amount, 'withdraw');
    if (limitError != null) {
      Get.snackbar(
        'error'.tr,
        limitError,
        backgroundColor: AppColors.error.withValues(alpha: 0.7),
        colorText: Colors.white,
      );
      return;
    }

    final fee = FeeService.totalFee('withdraw', amount);
    final totalDeducted = amount + fee;
    final totalBalance = CurrencyController.to.totalBalance.value;
    if (totalDeducted > totalBalance) {
      Get.snackbar(
        'error'.tr,
        'insufficient_balance'.tr,
        backgroundColor: AppColors.error.withValues(alpha: 0.7),
        colorText: Colors.white,
      );
      return;
    }

    if (agents.isEmpty) {
      Get.snackbar(
        'error'.tr,
        'no_agents'.tr,
        backgroundColor: AppColors.error.withValues(alpha: 0.7),
        colorText: Colors.white,
      );
      return;
    }

    final otpVerified = await SensitiveOperationGuard.requirePhoneOtp(
      purpose: 'wallet_withdraw',
    );
    if (!otpVerified) return;

    _showConfirmationDialog(amount);
  }

  void _showConfirmationDialog(double amount) {
    final agent = agents[selectedAgentIndex.value];
    final fee = FeeService.totalFee('withdraw', amount);
    final netAmount = amount - fee;
    Get.dialog(
      AlertDialog(
        backgroundColor: isDark ? AppColors.surface : AppColors.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.darkGold.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.outbox_rounded,
                color: AppColors.darkGold,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'confirm_withdrawal'.tr,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildConfirmRow(
              'withdrawal_amount'.tr,
              '\$${amount.toStringAsFixed(2)}',
              AppColors.darkGold,
            ),
            Divider(
              color: isDark
                  ? Colors.white10
                  : Colors.black.withValues(alpha: 0.1),
              height: 24,
            ),
            _buildConfirmRow(
              'expected_fee'.tr,
              fee > 0 ? '-\$${fee.toStringAsFixed(2)}' : '\$0.00',
              fee > 0 ? AppColors.error : null,
            ),
            Divider(
              color: isDark
                  ? Colors.white10
                  : Colors.black.withValues(alpha: 0.1),
              height: 24,
            ),
            _buildConfirmRow(
              'net_amount'.tr,
              '\$${netAmount.toStringAsFixed(2)}',
              AppColors.softGreen,
            ),
            Divider(
              color: isDark
                  ? Colors.white10
                  : Colors.black.withValues(alpha: 0.1),
              height: 24,
            ),
            _buildConfirmRow('deposit_agent'.tr, agent.name, null),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.darkGold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.darkGold.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    color: AppColors.darkGold,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'processing_time'.tr,
                    style: TextStyle(
                      color: AppColors.darkGold,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondary
                    : AppColors.textSecondaryLight,
              ),
            ),
          ),
          KasbyButton(
            width: 140,
            text: 'confirm'.tr,
            onPressed: () {
              HapticFeedback.mediumImpact();
              Get.back();
              _executeWithdrawal(amount);
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
        Text(
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
        ),
      ],
    );
  }

  Future<void> _executeWithdrawal(double amount) async {
    setState(() => _isSubmitting = true);

    try {
      final selectedAgent = agents[selectedAgentIndex.value];
      final result = await SafeGetx.traceAsync(
        className: 'WithdrawView',
        method: '_executeWithdrawal',
        feature: 'Wallet',
        params: {
          'table': 'transactions',
          'operation': 'RPC',
          'rpc': 'create_withdrawal',
          'amount': amount,
          'agentId': selectedAgent.id,
        },
        operation: () => SupabaseService.client.rpc(
          'create_withdrawal',
          params: {
            'p_amount': amount,
            'p_agent_id': selectedAgent.id,
            'p_idempotency_key': const Uuid().v4(),
            'p_currency': 'USD',
          },
        ),
      );

      final response = result as Map<String, dynamic>;

      if (response['success'] == true) {
        ConfettiService.to.celebrate();

        _showSuccessOverlay(
          amount,
          selectedAgent.name,
          response['transaction_id']?.toString() ?? '',
        );
      } else {
        SafeGetx.debugTrace(
          className: 'WithdrawView',
          method: '_executeWithdrawal',
          feature: 'Wallet',
          status: 'WARNING',
          message: response['error']?.toString(),
        );
        Get.snackbar(
          'error'.tr,
          response['error']?.toString() ?? 'withdraw_error'.tr,
          backgroundColor: AppColors.error.withValues(alpha: 0.7),
          colorText: Colors.white,
        );
      }
    } catch (_) {
      Get.snackbar(
        'error'.tr,
        'withdraw_error'.tr,
        backgroundColor: AppColors.error.withValues(alpha: 0.7),
        colorText: Colors.white,
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessOverlay(double amount, String agentName, String transactionId) {
    Get.to(
      () => TransactionReceipt(
        transactionId: transactionId,
        recipientName: agentName,
        amount: amount,
        type: 'withdraw'.tr,
        date: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('withdraw_funds'.tr),
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
              child: Column(
                children: [
                  Text(
                    'withdrawable_balance'.tr,
                    style: TextStyle(
                      color: isDark
                          ? AppColors.textSecondary
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  Obx(
                    () => Text(
                      CurrencyController.to.formatToUSD(
                        CurrencyController.to.totalBalance.value,
                      ),
                      style: TextStyle(
                        color: isDark ? Colors.white : AppColors.textBodyLight,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Divider(
                    color: isDark
                        ? Colors.white10
                        : Colors.black.withValues(alpha: 0.1),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'minimum_withdrawal'.tr,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const Text(
                        '\$10.00',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            KasbyTextField(
              label: 'withdrawal_amount'.tr,
              hint: 'enter_amount_usd'.tr,
              controller: _amountController,
              keyboardType: TextInputType.number,
              prefixIcon: Icon(
                Icons.outbox_rounded,
                color: AppColors.darkGold,
              ),
            ),
            const SizedBox(height: 24),
            // Estimated fee preview
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.surface : AppColors.surfaceLight)
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.05),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'expected_fee'.tr,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '\$0.00',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.softGreen,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Optional notes field
            KasbyTextField(
              label: 'withdraw_notes'.tr,
              hint: 'withdraw_notes_hint'.tr,
              controller: _notesController,
              prefixIcon: Icon(
                Icons.note_alt_outlined,
                color: AppColors.darkGold,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'select_withdrawal_agent'.tr,
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
                    text: 'request_withdrawal'.tr,
                    onPressed: _handleWithdraw,
                  ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildAgentSelector() {
    return Obx(() {
      if (isLoadingAgents.value) {
        return Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(color: AppColors.darkGold),
          ),
        );
      }

      if (agents.isEmpty) {
        return KasbyCard(
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
          groupValue: selectedAgentIndex.value,
          onChanged: (val) => selectedAgentIndex.value = val ?? 0,
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
                              'success_rate'.trParams({
                                'rate':
                                    '${agent.successRate.toStringAsFixed(0)}%',
                              }),
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
