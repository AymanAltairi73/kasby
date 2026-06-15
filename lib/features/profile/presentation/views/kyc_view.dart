import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/core/widgets/kasby_text_field.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:kasby/features/profile/presentation/controllers/kyc_controller.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:io';

class KycView extends StatefulWidget {
  const KycView({super.key});

  @override
  State<KycView> createState() => _KycViewState();
}

class _KycViewState extends State<KycView> {
  @override
  void initState() {
    super.initState();
    SafeGetx.debugTrace(
      className: 'KycView',
      method: 'initState',
      feature: 'Profile',
      status: 'INFO',
    );
  }

  @override
  void dispose() {
    SafeGetx.debugTrace(
      className: 'KycView',
      method: 'dispose',
      feature: 'Profile',
      status: 'INFO',
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(KycController());
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.background
          : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('kyc_verification'.tr),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Get.safeBack(),
        ),
      ),
      body: Obx(() {
        final profile = HomeController.to.profile.value;
        final status = profile?.kycStatus ?? 'none';

        if (status == 'verified') {
          return _buildVerifiedState(context);
        } else if (status == 'pending') {
          return _buildPendingState(context);
        }

        return Column(
          children: [
            const SizedBox(height: 20),
            _buildStepper(context, controller),
            Expanded(
              child: Obx(() {
                switch (controller.currentStep.value) {
                  case 0:
                    return _buildIdTypeStep(context, controller);
                  case 1:
                    return _buildPersonalInfoStep(context, controller);
                  case 2:
                    return _buildDocumentsStep(context, controller);
                  case 3:
                    return _buildSelfieStep(context, controller);
                  default:
                    return const SizedBox();
                }
              }),
            ),
            _buildBottomBar(context, controller),
          ],
        );
      }),
    );
  }

  Widget _buildVerifiedState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.softGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.verified_user_rounded,
                size: 80,
                color: AppColors.softGreen,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'account_verified'.tr,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'kyc_verified_desc'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 40),
            KasbyButton(
              text: 'go_back'.tr,
              onPressed: () => Get.safeBack(),
            ),
          ],
        ),
      ),
    ).animate().fadeIn().scale();
  }

  Widget _buildPendingState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.darkGold.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.pending_actions_rounded,
                size: 80,
                color: AppColors.darkGold,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'kyc_pending_title'.tr,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'kyc_pending_desc'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 40),
            KasbyButton(
              text: 'go_back'.tr,
              onPressed: () => Get.safeBack(),
            ),
          ],
        ),
      ),
    ).animate().fadeIn().scale();
  }

  Widget _buildStepper(BuildContext context, KycController controller) {
    return Obx(() {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: List.generate(4, (index) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            bool isActive = controller.currentStep.value >= index;
            bool isCurrent = controller.currentStep.value == index;
            return Expanded(
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? AppColors.darkGold
                          : (isDark ? Colors.white12 : Colors.black12),
                      border: Border.all(
                        color: isCurrent
                            ? (isDark ? Colors.white : AppColors.textBodyLight)
                            : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: AppColors.darkGold.withValues(
                                  alpha: 0.3,
                                ),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: isActive && !isCurrent
                          ? const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.black,
                            )
                          : Text(
                              (index + 1).toString(),
                              style: TextStyle(
                                color: isActive
                                    ? Colors.black
                                    : (isDark
                                          ? Colors.white54
                                          : Colors.black54),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  if (index < 3)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: controller.currentStep.value > index
                            ? AppColors.darkGold
                            : (isDark ? Colors.white12 : Colors.black12),
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
      );
    });
  }

  Widget _buildIdTypeStep(BuildContext context, KycController controller) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'select_id_type'.tr,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 24),
        _buildIdTypeCard(
          context,
          controller,
          'id_card'.tr,
          'id_card',
          Icons.badge_outlined,
        ),
        const SizedBox(height: 16),
        _buildIdTypeCard(
          context,
          controller,
          'passport'.tr,
          'passport',
          Icons.public_outlined,
        ),
        const SizedBox(height: 16),
        _buildIdTypeCard(
          context,
          controller,
          'drivers_license'.tr,
          'drivers_license',
          Icons.directions_car_outlined,
        ),
      ],
    ).animate().fadeIn().slideX(begin: 0.1, end: 0);
  }

  Widget _buildIdTypeCard(
    BuildContext context,
    KycController controller,
    String title,
    String type,
    IconData icon,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Obx(() {
      bool isSelected = controller.selectedIdType.value == type;
      return InkWell(
        onTap: () => controller.selectedIdType.value = type,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.darkGold.withValues(alpha: 0.1)
                : (isDark ? AppColors.surface : AppColors.surfaceLight),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? AppColors.darkGold
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.1)),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.darkGold.withValues(alpha: 0.2)
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.05)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isSelected
                      ? AppColors.darkGold
                      : (isDark ? Colors.white54 : AppColors.iconLight),
                ),
              ),
              const SizedBox(width: 20),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isDark ? Colors.white : AppColors.textBodyLight,
                ),
              ),
              const Spacer(),
              if (isSelected)
                Icon(Icons.check_circle, color: AppColors.darkGold),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildPersonalInfoStep(
    BuildContext context,
    KycController controller,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'step_personal_info'.tr,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 24),
          KasbyTextField(
            label: 'full_name'.tr,
            hint: 'enter_full_name'.tr,
            controller: controller.nameController,
          ),
          const SizedBox(height: 20),
          KasbyTextField(
            label: 'id_number'.tr,
            hint: 'enter_id_number'.tr,
            controller: controller.idNumberController,
          ),
          const SizedBox(height: 20),
          KasbyTextField(
            label: 'dob'.tr,
            hint: 'YYYY-MM-DD',
            controller: controller.dobController,
            readOnly: true,
            onTap: () => controller.selectDate(context),
            suffixIcon: Icon(
              Icons.calendar_today_rounded,
              color: AppColors.darkGold,
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.1, end: 0);
  }

  Widget _buildDocumentsStep(BuildContext context, KycController controller) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'step_documents'.tr,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 24),
        Obx(
          () => _buildUploadPlaceholder(
            'upload_front'.tr,
            controller.frontImagePath.value,
            () => controller.pickImage('front'),
            context,
          ),
        ),
        const SizedBox(height: 20),
        Obx(
          () => _buildUploadPlaceholder(
            'upload_back'.tr,
            controller.backImagePath.value,
            () => controller.pickImage('back'),
            context,
          ),
        ),
      ],
    ).animate().fadeIn().slideX(begin: 0.1, end: 0);
  }

  Widget _buildUploadPlaceholder(
    String title,
    String imagePath,
    VoidCallback onTap,
    BuildContext context,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: isDark ? AppColors.surface : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: imagePath.isNotEmpty
                ? AppColors.darkGold
                : (isDark ? Colors.white10 : Colors.black12),
            style: BorderStyle.solid,
          ),
          image: imagePath.isNotEmpty
              ? DecorationImage(
                  image: FileImage(File(imagePath)),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: imagePath.isNotEmpty
            ? Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.black38,
                ),
                child: const Center(
                  child: Icon(
                    Icons.edit_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_a_photo_outlined,
                    size: 40,
                    color: AppColors.darkGold,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: TextStyle(
                      color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSelfieStep(BuildContext context, KycController controller) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            'step_selfie'.tr,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 40),
          Obx(
            () =>
                InkWell(
                      onTap: () => controller.pickImage('selfie'),
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.darkGold,
                            width: 2,
                          ),
                          image: controller.selfiePath.value.isNotEmpty
                              ? DecorationImage(
                                  image: FileImage(
                                    File(controller.selfiePath.value),
                                  ),
                                  fit: BoxFit.cover,
                                )
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.darkGold.withValues(alpha: 0.1),
                              blurRadius: 30,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: controller.selfiePath.value.isEmpty
                            ? Center(
                                child: Icon(
                                  Icons.face_retouching_natural_rounded,
                                  size: 80,
                                  color: AppColors.darkGold,
                                ),
                              )
                            : Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black26,
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.camera_alt_rounded,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                ),
                              ),
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat())
                    .shimmer(duration: const Duration(seconds: 3)),
          ),
          const SizedBox(height: 40),
          Text(
            'selfie_instruction'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark
                  ? AppColors.textSecondary
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.1, end: 0);
  }

  Widget _buildBottomBar(BuildContext context, KycController controller) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.surface : AppColors.surfaceLight).withValues(
          alpha: 0.8,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Row(
        children: [
          Obx(
            () => controller.currentStep.value > 0
                ? Expanded(
                    child: TextButton(
                      onPressed: controller.previousStep,
                      child: Text(
                        'previous'.tr,
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  )
                : const SizedBox(),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Obx(
              () => KasbyButton(
                text: controller.currentStep.value == 3
                    ? 'submit_kyc'.tr
                    : 'next_step'.tr,
                isLoading: controller.isLoading.value,
                onPressed: () {
                  if (controller.currentStep.value == 0 &&
                      controller.selectedIdType.isEmpty) {
                    Get.snackbar('Error', 'Please select an ID type');
                    return;
                  }
                  controller.nextStep();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
