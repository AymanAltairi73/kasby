import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/core/widgets/glass_card.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:kasby/features/qr_payment/presentation/controllers/qr_payment_controller.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kasby/core/widgets/kasby_text_field.dart';

class MyQrView extends StatefulWidget {
  const MyQrView({super.key});

  @override
  State<MyQrView> createState() => _MyQrViewState();
}

class _MyQrViewState extends State<MyQrView> {
  final TextEditingController _amountController = TextEditingController();
  double? _customAmount;
  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<QrPaymentController>()) {
      Get.put(QrPaymentController());
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = HomeController.to.profile.value;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('my_qr'.tr),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            // 1. User Profile Info
            Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.darkGold.withValues(alpha: 0.1),
                  child: Icon(Icons.person_rounded, size: 40, color: AppColors.darkGold),
                ),
                const SizedBox(height: 12),
                Text(
                  profile?.fullName ?? '...',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  profile?.referralCode ?? '...',
                  style: TextStyle(
                    color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ).animate().fadeIn().slideY(begin: -0.1),

            const SizedBox(height: 40),

            // 2. QR Card
            GlassCard(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.darkGold.withValues(alpha: 0.2),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: QrPaymentController.to.generateUserQrData(amount: _customAmount),
                      version: QrVersions.auto,
                      size: 200.0,
                      gapless: false,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Colors.black,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  if (_customAmount != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.darkGold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '\$${_customAmount!.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkGold,
                        ),
                      ),
                    ).animate().scale(),
                  ],
                ],
              ),
            ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.9, 0.9)),

            const SizedBox(height: 40),

            // 3. Amount Generator
            KasbyTextField(
              label: 'generate_amount_qr'.tr,
              hint: 'enter_amount'.tr,
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              prefixIcon: Icon(Icons.attach_money_rounded, color: AppColors.darkGold),
              onChanged: (val) {
                setState(() {
                  _customAmount = double.tryParse(val);
                });
              },
            ).animate().fadeIn(delay: 400.ms),

            const SizedBox(height: 32),

            // 4. Actions
            Row(
              children: [
                Expanded(
                  child: KasbyButton(
                    text: 'share_qr'.tr,
                    onPressed: () {
                      // Logic for sharing would go here
                    },
                    isSecondary: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: KasbyButton(
                    text: 'save_qr'.tr,
                    onPressed: () {
                      // Logic for saving to gallery would go here
                    },
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 600.ms),
          ],
        ),
      ),
    );
  }
}
