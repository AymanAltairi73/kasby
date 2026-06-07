import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:kasby/core/widgets/kasby_text_field.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:kasby/core/services/session_service.dart';
import 'package:kasby/core/widgets/transaction_receipt.dart';
import 'package:kasby/core/controllers/currency_controller.dart';

class TransferView extends StatefulWidget {
  const TransferView({super.key});

  @override
  State<TransferView> createState() => _TransferViewState();
}

class _TransferViewState extends State<TransferView> {
  bool isPoints = true;
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  bool _isSubmitting = false;
  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    // Handle arguments from QR scan
    final args = Get.arguments;
    if (args != null && args is Map<String, dynamic>) {
      if (args.containsKey('receiver_id')) {
        _idController.text = args['receiver_id'].toString();
      }
      if (args.containsKey('amount')) {
        _amountController.text = args['amount'].toString();
      }
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('p2p_transfer'.tr),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Get.back(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.qr_code_scanner_rounded, color: AppColors.darkGold),
            onPressed: () {
              HapticFeedback.lightImpact();
              Get.toNamed('/qr-scanner');
            },
            tooltip: 'scan_qr'.tr,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTypeToggle(),
            // const SizedBox(height: 32),
            // _buildMyCodePreview(),
            const SizedBox(height: 32),
            _buildTransferForm(),
            const SizedBox(height: 16),
            _buildRecentRecipients(),
            const SizedBox(height: 40),
            _isSubmitting
                ? Center(
                    child: CircularProgressIndicator(color: AppColors.darkGold),
                  )
                : KasbyButton(text: 'transfer'.tr, onPressed: _handleTransfer),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleItem(
              true,
              'send_points'.tr,
              'assets/images/ksp_coin.png',
            ),
          ),
          Expanded(
            child: _buildToggleItem(
              false,
              'send_funds'.tr,
              Icons.account_balance_wallet_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleItem(bool active, String label, dynamic icon) {
    final bool isSelected = isPoints == active;
    return GestureDetector(
      onTap: () => setState(() => isPoints = active),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.darkGold : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon is String
                ? Image.asset(
                    icon,
                    width: 20,
                    height: 20,
                    color: isSelected
                        ? (isDark ? Colors.black : Colors.white)
                        : (isDark ? Colors.white54 : Colors.black54),
                  )
                : Icon(
                    icon as IconData,
                    color: isSelected
                        ? (isDark ? Colors.black : Colors.white)
                        : (isDark ? Colors.white54 : Colors.black54),
                    size: 20,
                  ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? (isDark ? Colors.black : Colors.white)
                    : (isDark ? Colors.white54 : Colors.black54),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget _buildMyCodePreview() {
  //   final code = _myReferralCode;
  //   return KasbyCard(
  //     child: Column(
  //       children: [
  //         Row(
  //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //           children: [
  //             Text(
  //               'my_referral_code'.tr,
  //               style: TextStyle(
  //                 color: isDark
  //                     ? AppColors.textSecondary
  //                     : AppColors.textSecondaryLight,
  //               ),
  //             ),
  //             IconButton(
  //               icon: Icon(
  //                 Icons.copy_all_rounded,
  //                 color: AppColors.darkGold,
  //               ),
  //               onPressed: () {
  //                 Clipboard.setData(ClipboardData(text: code));
  //                 Get.snackbar('copy_code'.tr, 'success_copy'.tr);
  //               },
  //             ),
  //           ],
  //         ),
  //         const SizedBox(height: 8),
  //         Container(
  //           padding: const EdgeInsets.symmetric(vertical: 16),
  //           width: double.infinity,
  //           decoration: BoxDecoration(
  //             color: isDark
  //                 ? Colors.black26
  //                 : Colors.black.withValues(alpha: 0.05),
  //             borderRadius: BorderRadius.circular(12),
  //             border: Border.all(
  //               color: AppColors.darkGold.withValues(alpha: 0.3),
  //             ),
  //           ),
  //           child: Center(
  //             child: Text(
  //               code,
  //               style: TextStyle(
  //                 fontSize: 24,
  //                 fontWeight: FontWeight.bold,
  //                 letterSpacing: 2,
  //                 color: AppColors.darkGold,
  //               ),
  //             ),
  //           ),
  //         ),
  //         const SizedBox(height: 8),
  //         Text(
  //           'encrypted_id'.tr,
  //           style: TextStyle(
  //             fontSize: 10,
  //             color: isDark ? Colors.white24 : Colors.black26,
  //           ),
  //         ),
  //       ],
  //     ),
  //   ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95));
  // }

  Widget _buildTransferForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputField(
          'enter_receiver_id'.tr,
          'k-XXXXX',
          _idController,
          Icons.person_search_rounded,
        ),
        const SizedBox(height: 20),
        KasbyTextField(
          label: 'deposit_amount'.tr,
          hint: isPoints ? 'enter_amount_point'.tr : 'enter_amount_usd'.tr,
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          prefixIcon: isPoints
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: Image.asset(
                    'assets/images/ksp_coin.png',
                    width: 20,
                    height: 20,
                  ),
                )
              : Icon(
                  Icons.attach_money_rounded,
                  color: AppColors.darkGold,
                ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AppColors.error,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'transfer_real_balance_warning'.tr,
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputField(
    String label,
    String hint,
    TextEditingController controller,
    IconData icon, {
    bool isNumber = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        TextField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: TextStyle(
            color: isDark
                ? Theme.of(context).colorScheme.onSurface
                : AppColors.textBodyLight,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppColors.darkGold),
            filled: true,
            fillColor: isDark ? AppColors.surface : AppColors.surfaceLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentRecipients() {
    return Obx(() {
      final recipients = HomeController.to.recentRecipients;
      if (recipients.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'recent_recipients'.tr,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark
                    ? AppColors.textSecondary
                    : AppColors.textSecondaryLight,
                fontSize: 13,
              ),
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: recipients.map((r) {
              final code = r['code'] ?? '';
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _idController.text = code;
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surface : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.darkGold.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person_outline_rounded,
                        color: AppColors.darkGold,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        code,
                        style: TextStyle(
                          color: isDark
                              ? Theme.of(context).colorScheme.onSurface
                              : AppColors.textBodyLight,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ).animate().fadeIn(delay: 200.ms);
    });
  }

  void _handleTransfer() async {
    if (_idController.text.isEmpty || _amountController.text.isEmpty) {
      Get.snackbar('error'.tr, 'fill_all_data'.tr);
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      Get.snackbar(
        'error'.tr,
        'transfer_invalid_amount'.tr,
        backgroundColor: AppColors.error.withValues(alpha: 0.7),
        colorText: Colors.white,
      );
      return;
    }

    final receiverCode = _idController.text.trim();
    final myProfile = HomeController.to.profile.value;
    
    // Self-transfer check
    if (myProfile != null && (myProfile.referralCode == receiverCode || myProfile.id == receiverCode)) {
      Get.snackbar(
        'error'.tr,
        'transfer_to_self_error'.tr,
        backgroundColor: AppColors.error.withValues(alpha: 0.7),
        colorText: Colors.white,
      );
      return;
    }

    // Balance check
    if (isPoints) {
      final points = HomeController.to.userPoints.value;
      if (amount > points) {
        Get.snackbar(
          'error'.tr,
          'insufficient_balance'.tr,
          backgroundColor: AppColors.error.withValues(alpha: 0.7),
          colorText: Colors.white,
        );
        return;
      }
    } else {
      final balance = CurrencyController.to.totalBalance.value;
      if (amount > balance) {
        Get.snackbar(
          'error'.tr,
          'insufficient_balance'.tr,
          backgroundColor: AppColors.error.withValues(alpha: 0.7),
          colorText: Colors.white,
        );
        return;
      }
    }

    // Biometric/PIN Authentication
    final authenticated = await SessionService.to.authenticate();
    if (!authenticated) {
      Get.snackbar(
        'security'.tr,
        'auth_failed_desc'.tr,
        backgroundColor: AppColors.error.withValues(alpha: 0.7),
        colorText: Colors.white,
      );
      return;
    }

    // Show confirmation dialog
    _showConfirmationDialog(amount);
  }

  void _showConfirmationDialog(double amount) {
    Get.dialog(
      AlertDialog(
        backgroundColor: isDark ? AppColors.surface : AppColors.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'confirm_transfer'.tr,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${'transfer_amount_label'.tr}: ${isPoints ? '${amount.toInt()} KSP' : '\$${amount.toStringAsFixed(2)}'}',
            ),
            const SizedBox(height: 8),
            Text('${'transfer_to_label'.tr}: ${_idController.text}'),
            const SizedBox(height: 8),
            Text(
              '${'transfer_type_label'.tr}: ${isPoints ? 'send_points'.tr : 'send_funds'.tr}',
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
            width: 120,
            text: 'confirm'.tr,
            onPressed: () {
              HapticFeedback.mediumImpact();
              Get.back();
              _executeTransfer(amount);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _executeTransfer(double amount) async {
    setState(() => _isSubmitting = true);

    try {
      final result = await SupabaseService.client.rpc(
        'create_transfer',
        params: {
          'p_amount': amount,
          'p_receiver_referral_code': _idController.text.trim(),
          'p_transfer_type': isPoints ? 'points' : 'funds',
        },
      );

      final response = result as Map<String, dynamic>;

      if (response['success'] == true) {
        // Refresh data after successful transfer
        HomeController.to.refreshAll();
        _showSuccessOverlay(
          response['receiver_name'] ?? '',
          response['message'] ?? '',
          response['transaction_id']?.toString() ?? 'N/A',
          amount,
        );
      } else {
        Get.snackbar(
          'error'.tr,
          response['error']?.toString() ?? 'transfer_error'.tr,
          backgroundColor: AppColors.error.withValues(alpha: 0.7),
          colorText: Colors.white,
        );
      }
    } catch (e) {
      debugPrint('Transfer error: $e');
      Get.snackbar(
        'error'.tr,
        'transfer_error'.tr,
        backgroundColor: AppColors.error.withValues(alpha: 0.7),
        colorText: Colors.white,
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessOverlay(
    String receiverName,
    String message,
    String transactionId,
    double amount,
  ) {
    Get.bottomSheet(
      TransactionReceipt(
        transactionId: transactionId,
        recipientName: receiverName,
        amount: amount,
        type: isPoints ? 'send_points'.tr : 'send_funds'.tr,
        date: DateTime.now(),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    ).then((_) {
      Get.back();
      Get.back();
    });
  }
}
