import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/core/widgets/agent_status_badge.dart';
import 'package:kasby/core/controllers/currency_controller.dart';
import 'package:kasby/core/widgets/kasby_card.dart';
import 'package:kasby/core/widgets/kasby_text_field.dart';
import 'package:kasby/core/models/agent_model.dart';
import 'package:kasby/core/services/account_restriction_service.dart';
import 'package:kasby/core/services/agent_service.dart';
import 'package:kasby/core/services/transaction_auth_service.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/widgets/glass_card.dart';
import 'package:kasby/core/models/kasby_receipt_data.dart';
import 'package:kasby/core/services/receipt_export_service.dart';
import 'package:kasby/core/services/confetti_service.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:kasby/core/services/financial_repository.dart';
import 'package:kasby/routes/app_routes.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:flutter/services.dart';
import 'package:kasby/core/services/fee_service.dart';
import 'package:kasby/core/widgets/fee_breakdown_card.dart';
import 'package:kasby/core/widgets/error_state_widget.dart';

class WithdrawView extends StatefulWidget {
  const WithdrawView({super.key});

  @override
  State<WithdrawView> createState() => _WithdrawViewState();
}

class _WithdrawViewState extends State<WithdrawView> {
  final RxList<AgentModel> agents = <AgentModel>[].obs;
  final RxBool isLoadingAgents = true.obs;
  final RxBool hasAgentError = false.obs;
  final RxInt selectedAgentIndex = 0.obs;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
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
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _fetchAgents() async {
    isLoadingAgents.value = true;
    hasAgentError.value = false;
    try {
      agents.value = await AgentService.fetchActiveAgents(limit: 20);
      SafeGetx.debugTrace(
        className: 'WithdrawView',
        method: '_fetchAgents',
        feature: 'Wallet',
        status: 'SUCCESS',
        params: {'count': agents.length},
      );
    } catch (e, stack) {
      hasAgentError.value = true;
      SafeGetx.debugTrace(
        className: 'WithdrawView',
        method: '_fetchAgents',
        feature: 'Wallet',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
    } finally {
      isLoadingAgents.value = false;
    }
  }

  Future<void> _handleWithdraw() async {
    if (!await AccountRestrictionService.to.checkWriteAccessAsync()) return;

    final amountText = _amountController.text.trim();
    
    // Check KYC Status
    if (HomeController.to.kycStatus != 'verified') {
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

    final totalBalance = CurrencyController.to.totalBalance.value;
    if (amount > totalBalance) {
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

    final confirmed = await TransactionAuthService.to.requireConfirmation(
      purpose: 'wallet_withdraw',
    );
    if (!confirmed) return;

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
              fee > 0
                  ? '-\$${fee.toStringAsFixed(2)} (${FeeService.feeRateLabel('withdraw')})'
                  : '\$0.00',
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
        Flexible(
          child: Text(
            label,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
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
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Future<void> _executeWithdrawal(double amount) async {
    setState(() => _isSubmitting = true);

    try {
      final selectedAgent = agents[selectedAgentIndex.value];
      final response = await FinancialRepository.createWithdrawal(
        amount: amount,
        agentId: selectedAgent.id,
      );

      if (response['success'] == true) {
        if (Get.isRegistered<HomeController>()) {
          HomeController.to.refreshAll();
        }
        if (Get.isRegistered<CurrencyController>()) {
          CurrencyController.to.fetchWalletBalances();
        }

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
          FinancialRepository.mapErrorMessage(response, 'withdraw_error'.tr),
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
    final profile = Get.isRegistered<HomeController>()
        ? HomeController.to.profile.value
        : null;
    ReceiptExportService.showReceiptSheet(
      KasbyReceiptData(
        transactionId: transactionId,
        operationType: 'withdrawal',
        referenceNumber: transactionId,
        date: DateTime.now(),
        userName: profile?.fullName,
        userId: profile?.id,
        invitationCode: profile?.referralCode,
        amount: amount,
        status: 'pending',
        recipientName: agentName,
        qrPayload: transactionId,
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
            Obx(
              () => FeeBreakdownCard(
                category: 'withdraw',
                amount: _amountPreview.value,
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

      // if (hasAgentError.value) {
      //   return ErrorStateWidget(
      //     message: 'agents_load_error'.tr,
      //     onRetry: _fetchAgents,
      //   );
      // }

      if (agents.isEmpty) {
        return ErrorStateWidget(
          message: 'no_online_agents_desc'.tr,
          onRetry: _fetchAgents,
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
                        AgentStatusBadge(isOnline: agent.isAvailableNow, compact: true),
                        if (agent.successRate > 0) ...[
                          const SizedBox(width: 6),
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
