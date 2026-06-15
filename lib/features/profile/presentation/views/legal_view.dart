import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/utils/safe_getx.dart';

class LegalView extends StatefulWidget {
  const LegalView({super.key});

  @override
  State<LegalView> createState() => _LegalViewState();
}

class _LegalViewState extends State<LegalView> {
  @override
  void initState() {
    super.initState();
    SafeGetx.debugTrace(
      className: 'LegalView',
      method: 'initState',
      feature: 'Profile',
      status: 'INFO',
      message: 'Legal content ready',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('legal_terms'.tr),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'legal_intro'.tr,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                height: 1.5,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'legal_body'.tr,
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondary
                    : AppColors.textSecondaryLight,
                height: 1.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
