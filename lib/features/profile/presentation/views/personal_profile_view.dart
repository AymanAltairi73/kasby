import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/routes/app_routes.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:kasby/core/models/profile_model.dart';
import 'package:kasby/core/services/referral_service.dart';

class PersonalProfileView extends StatefulWidget {
  const PersonalProfileView({super.key});

  @override
  State<PersonalProfileView> createState() => _PersonalProfileViewState();
}

class _PersonalProfileViewState extends State<PersonalProfileView> {
  bool get isDark => Get.isDarkMode;

  @override
  void initState() {
    super.initState();
    final profile = HomeController.to.profile.value;
    SafeGetx.debugTrace(
      className: 'PersonalProfileView',
      method: 'initState',
      feature: 'Profile',
      status: 'INFO',
      message: 'Profile data bound',
      params: {'hasProfile': profile != null, 'kycStatus': profile?.kycStatus},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'personal_profile'.tr,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Get.back(),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.darkGold.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.edit_note_rounded, color: AppColors.darkGold),
            ),
            onPressed: () {
              SafeGetx.debugTrace(
                className: 'PersonalProfileView',
                method: 'navigateEditProfile',
                feature: 'Profile',
                status: 'INFO',
              );
              Get.toNamed(Routes.editProfile);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Obx(() {
          final profile = HomeController.to.profile.value;
          if (profile == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              _buildProfileHeader(profile),
              const SizedBox(height: 32),
              _buildInfoSection(context, profile),
              const SizedBox(height: 40),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildProfileHeader(ProfileModel profile) {
    final networkUrl = profile.avatarUrl;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.darkGold, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.darkGold.withValues(alpha: 0.2),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 50,
            backgroundColor: isDark
                ? AppColors.surface
                : AppColors.surfaceLight,
            backgroundImage: networkUrl != null && networkUrl.isNotEmpty
                ? NetworkImage(networkUrl)
                : null,
            child: (networkUrl == null || networkUrl.isEmpty)
                ? Icon(Icons.person, size: 50, color: AppColors.darkGold)
                : null,
          ),
        ).animate().scale(curve: Curves.easeOutBack),
        const SizedBox(height: 16),
        Text(
          profile.fullName,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ).animate().fadeIn(delay: 200.ms),
        Text(
          profile.role.toUpperCase(),
          style: TextStyle(
            color: AppColors.darkGold,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            fontSize: 12,
          ),
        ).animate().fadeIn(delay: 300.ms),
      ],
    );
  }

  Widget _buildInfoSection(BuildContext context, ProfileModel profile) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surface.withValues(alpha: 0.3)
            : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        children: [
          _buildDetailRow(
            context,
            'full_name'.tr,
            profile.fullName,
            Icons.person_rounded,
          ),
          _buildDetailRow(
            context,
            'email_address'.tr,
            profile.email ?? '---',
            Icons.email_rounded,
          ),
          _buildDetailRow(
            context,
            'phone_number'.tr,
            profile.phone ?? '---',
            Icons.phone_rounded,
          ),
          _buildReferralRow(
            context,
            ReferralService.formatDisplayCode(profile.referralCode),
          ),
          _buildDetailRow(
            context,
            'country'.tr,
            profile.country ?? '---',
            Icons.public_rounded,
          ),
          _buildDetailRow(
            context,
            'province'.tr,
            profile.province ?? '---',
            Icons.location_city_rounded,
          ),
          _buildDetailRow(
            context,
            'city'.tr,
            profile.city ?? '---',
            Icons.location_on_rounded,
          ),
          _buildDetailRow(
            context,
            'address'.tr,
            profile.address.isNotEmpty ? profile.address : '---',
            Icons.home_rounded,
          ),
          _buildDetailRow(
            context,
            'kyc_status_label'.tr,
            profile.kycStatus.tr,
            Icons.verified_user_rounded,
          ),
          _buildDetailRow(
            context,
            'account_tier_label'.tr,
            profile.accountTier.tr,
            Icons.star_rounded,
          ),
          _buildDetailRow(
            context,
            'account_status_label'.tr,
            profile.status.tr,
            Icons.speed_rounded,
            isLast: true,
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.05);
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.darkGold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.darkGold, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.textSecondary
                        : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralRow(BuildContext context, String code) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.darkGold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.qr_code_rounded,
              color: AppColors.darkGold,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'referral_code'.tr,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.textSecondary
                        : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      code,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkGold,
                        letterSpacing: 2,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        SafeGetx.debugTrace(
                          className: 'PersonalProfileView',
                          method: 'copyReferralCode',
                          feature: 'Profile',
                          status: 'INFO',
                        );
                        Clipboard.setData(ClipboardData(text: code));
                        Get.snackbar('success'.tr, 'success_copy'.tr);
                      },
                      child: Icon(
                        Icons.copy_rounded,
                        color: AppColors.darkGold,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
