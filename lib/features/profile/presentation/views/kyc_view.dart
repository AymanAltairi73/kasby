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
    _refreshKycState();
  }

  Future<void> _refreshKycState() async {
    await HomeController.to.fetchProfile();
    await HomeController.to.fetchDashboard();
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
      body: RefreshIndicator(
        onRefresh: _refreshKycState,
        color: AppColors.darkGold,
        child: Obx(() {
        final profile = HomeController.to.profile.value;
        final status = profile?.kycStatus ?? 'none';

        if (status == 'verified') {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [_buildVerifiedState(context)],
          );
        } else if (status == 'pending') {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [_buildPendingState(context)],
          );
        } else if (status == 'rejected') {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [_buildRejectedState(context, profile?.kycRejectionReason)],
          );
        }

        return Column(
          children: [
            const SizedBox(height: 12),
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
                  case 4:
                    return _buildReviewStep(context, controller);
                  default:
                    return const SizedBox();
                }
              }),
            ),
            _buildBottomBar(context, controller),
          ],
        );
      }),
      ),
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

  Widget _buildRejectedState(BuildContext context, String? reason) {
    final controller = Get.find<KycController>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 80,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'kyc_rejected_title'.tr,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'kyc_rejected_desc'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            if (reason != null && reason.trim().isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'rejection_reason'.tr,
                      style: TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      reason.trim(),
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 40),
            KasbyButton(
              text: 'resubmit_kyc'.tr,
              onPressed: () {
                controller.resetForResubmission();
              },
            ),
            const SizedBox(height: 12),
            KasbyButton(
              text: 'go_back'.tr,
              onPressed: () => Get.safeBack(),
              isSecondary: true,
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
          children: List.generate(5, (index) {
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
                  if (index < 4)
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
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'step_selfie'.tr,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          'kyc_selfie_liveness_desc'.tr,
          style: TextStyle(
            color: isDark
                ? AppColors.textSecondary
                : AppColors.textSecondaryLight,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        Obx(() {
          if (controller.hasCompleteSelfieSet) {
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _selfiePreview(controller.selfieFrontPath.value, 'kyc_selfie_step_front'.tr, isDark)),
                    const SizedBox(width: 8),
                    Expanded(child: _selfiePreview(controller.selfieRightPath.value, 'kyc_selfie_step_right'.tr, isDark)),
                    const SizedBox(width: 8),
                    Expanded(child: _selfiePreview(controller.selfieLeftPath.value, 'kyc_selfie_step_left'.tr, isDark)),
                  ],
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: controller.startSelfieLivenessCapture,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text('kyc_selfie_retake_all'.tr),
                ),
              ],
            );
          }

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.darkGold, width: 2),
                  color: AppColors.darkGold.withValues(alpha: 0.08),
                ),
                child: Icon(
                  Icons.face_retouching_natural_rounded,
                  size: 72,
                  color: AppColors.darkGold,
                ),
              ),
              const SizedBox(height: 24),
              KasbyButton(
                text: 'kyc_selfie_start_capture'.tr,
                isLoading: controller.isLaunchingSelfie.value,
                onPressed: controller.startSelfieLivenessCapture,
              ),
            ],
          );
        }),
      ],
    ).animate().fadeIn().slideX(begin: 0.1, end: 0);
  }

  Widget _selfiePreview(String path, String label, bool isDark) {
    return Column(
      children: [
        Container(
          height: 90,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(45),
            border: Border.all(color: AppColors.darkGold.withValues(alpha: 0.4)),
            image: path.isNotEmpty
                ? DecorationImage(
                    image: FileImage(File(path)),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildReviewStep(BuildContext context, KycController controller) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'kyc_review_title'.tr,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          'kyc_review_desc'.tr,
          style: TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 20),
        _reviewRow('select_id_type'.tr, controller.idTypeLabel),
        _reviewRow('full_name'.tr, controller.nameController.text.trim()),
        _reviewRow('id_number'.tr, controller.idNumberController.text.trim()),
        _reviewRow('dob'.tr, controller.dob.value),
        const SizedBox(height: 16),
        Text(
          'step_documents'.tr,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _reviewThumb(controller.frontImagePath.value, isDark),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _reviewThumb(controller.backImagePath.value, isDark),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'kyc_selfie_review_title'.tr,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _reviewThumb(controller.selfieFrontPath.value, isDark, round: true),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _reviewThumb(controller.selfieRightPath.value, isDark, round: true),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _reviewThumb(controller.selfieLeftPath.value, isDark, round: true),
            ),
          ],
        ),
      ],
    ).animate().fadeIn().slideX(begin: 0.1, end: 0);
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewThumb(String path, bool isDark, {bool round = false}) {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(round ? 45 : 12),
        border: Border.all(color: AppColors.darkGold.withValues(alpha: 0.4)),
        image: path.isNotEmpty
            ? DecorationImage(
                image: FileImage(File(path)),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: path.isEmpty
          ? Icon(Icons.image_not_supported_outlined, color: AppColors.textSecondary)
          : null,
    );
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
                text: controller.currentStep.value == KycController.reviewStepIndex
                    ? 'submit_kyc'.tr
                    : 'next_step'.tr,
                isLoading: controller.isLoading.value,
                onPressed: controller.nextStep,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
