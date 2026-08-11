import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/core/widgets/kasby_text_field.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kasby/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/services/referral_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kasby/features/profile/presentation/controllers/profile_update_controller.dart';
import 'package:kasby/features/profile/presentation/views/profile_update_view.dart';
import 'package:kasby/core/services/snack_service.dart';
import 'dart:io';

class EditProfileView extends StatefulWidget {
  const EditProfileView({super.key});

  @override
  State<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<EditProfileView> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _provinceController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  bool _isSaving = false;

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  String get _referralCode {
    return ReferralService.formatDisplayCode(
      HomeController.to.profile.value?.referralCode,
    );
  }

  @override
  void initState() {
    super.initState();
    SafeGetx.debugTrace(
      className: 'EditProfileView',
      method: 'initState',
      feature: 'Profile',
      status: 'INFO',
    );
    Get.put(ProfileUpdateController(), permanent: false);
    _loadProfileData();
  }

  void _loadProfileData() {
    final profile = HomeController.to.profile.value;
    if (profile != null) {
      _nameController.text = profile.fullName;
      _emailController.text = profile.email ?? '';
      _phoneController.text = profile.phone ?? '';
      _provinceController.text = profile.province ?? '';
      _cityController.text = profile.city ?? '';
      _addressController.text = profile.address;
      _countryController.text = profile.country ?? '';
    }
  }

  @override
  void dispose() {
    SafeGetx.debugTrace(
      className: 'EditProfileView',
      method: 'dispose',
      feature: 'Profile',
      status: 'INFO',
    );
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _provinceController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      AppSnack.error('error'.tr, 'fill_all_data'.tr);
      return;
    }

    setState(() => _isSaving = true);
    final stopwatch = Stopwatch()..start();

    try {
      final userId = SupabaseService.userId;
      if (userId == null) throw Exception('Not authenticated');

      String? uploadedImageUrl;
      final localImagePath = AuthController.to.profileImagePath.value;

      // 1. Upload new image if selected
      if (localImagePath != null) {
        final fileName = '$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
        uploadedImageUrl = await SupabaseService.uploadImage(
          bucket: 'avatars',
          filePath: localImagePath,
          fileName: fileName,
        );
      }

      // 2. Prepare update data
      final Map<String, dynamic> updateData = {
        'full_name': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'province': _provinceController.text.trim(),
        'city': _cityController.text.trim(),
        'country': _countryController.text.trim(),
      };

      if (uploadedImageUrl != null) {
        updateData['avatar_url'] = uploadedImageUrl;
      }

      // 3. Perform database update
      await SupabaseService.client
          .from('profiles')
          .update(updateData)
          .eq('id', userId);

      // 4. Refresh the profile in HomeController
      await HomeController.to.fetchProfile();

      // 5. Clear local preview path
      AuthController.to.profileImagePath.value = null;

      SafeGetx.debugTrace(
        className: 'EditProfileView',
        method: '_saveProfile',
        feature: 'Profile',
        status: 'SUCCESS',
        durationMs: stopwatch.elapsedMilliseconds,
        params: {'hasNewAvatar': uploadedImageUrl != null},
      );
      if (mounted) {
        Get.safeBack();
        AppSnack.success('success'.tr, 'save_changes'.tr);
      }
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'EditProfileView',
        method: '_saveProfile',
        feature: 'Profile',
        status: 'ERROR',
        durationMs: stopwatch.elapsedMilliseconds,
        error: e,
        stackTrace: stack,
      );
      if (mounted) {
        String errorMessage = 'profile_update_error'.tr;

        if (e is PostgrestException && e.code == '23505') {
          errorMessage = 'phone_already_used'.tr;
        }

        AppSnack.error('error'.tr, errorMessage);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'edit_profile'.tr,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Get.safeBack(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 10),
            _buildAvatarPicker(),
            const SizedBox(height: 40),
            _buildGlowingInputSection(context),
            const SizedBox(height: 40),
            _isSaving
                ? Center(
                    child: CircularProgressIndicator(color: AppColors.darkGold),
                  )
                : KasbyButton(
                    text: 'save_changes'.tr,
                    onPressed: _saveProfile,
                  ).animate().fadeIn(delay: 800.ms).scale(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarPicker() {
    return Center(
      child: Stack(
        children: [
          Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.darkGold.withValues(alpha: 0.2),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
              )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(0.95, 0.95),
                end: const Offset(1.05, 1.05),
                duration: const Duration(seconds: 2),
              ),

          InkWell(
            onTap: _pickImage,
            borderRadius: BorderRadius.circular(60),
            child: Obx(() {
              final imagePath = AuthController.to.profileImagePath.value;
              final profile = HomeController.to.profile.value;
              final networkUrl = profile?.avatarUrl;

              ImageProvider? imageProvider;
              if (imagePath != null) {
                imageProvider = FileImage(File(imagePath));
              } else if (networkUrl != null && networkUrl.isNotEmpty) {
                imageProvider = NetworkImage(networkUrl);
              }

              return Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.darkGold, width: 2),
                ),
                child: CircleAvatar(
                  radius: 55,
                  backgroundColor: isDark
                      ? AppColors.surface
                      : AppColors.surfaceLight,
                  backgroundImage: imageProvider,
                  child: imageProvider == null
                      ? Icon(Icons.person, size: 55, color: AppColors.darkGold)
                      : null,
                ),
              );
            }),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.darkGold,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.black,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().scale();
  }

  void _pickImage() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surface : AppColors.surfaceLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'update_profile_pic'.tr,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            _buildPickerOption(
              context: context,
              icon: Icons.photo_library_rounded,
              title: 'select_image'.tr,
              onTap: () async {
                final ImagePicker picker = ImagePicker();
                final XFile? image = await picker.pickImage(
                  source: ImageSource.gallery,
                );
                if (image != null) {
                  AuthController.to.profileImagePath.value = image.path;
                  Get.safeBack();
                }
              },
            ),
            const SizedBox(height: 12),
            _buildPickerOption(
              context: context,
              icon: Icons.camera_alt_rounded,
              title: 'take_selfie'.tr,
              onTap: () async {
                final ImagePicker picker = ImagePicker();
                final XFile? image = await picker.pickImage(
                  source: ImageSource.camera,
                );
                if (image != null) {
                  AuthController.to.profileImagePath.value = image.path;
                  Get.safeBack();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: AppColors.darkGold),
        title: Text(title),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        tileColor: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
      ),
    );
  }

  Widget _buildGlowingInputSection(BuildContext context) {
    return Obx(() {
      final profile = HomeController.to.profile.value;
      if (profile == null) return const SizedBox();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInputField(
            context,
            'full_name'.tr,
            _nameController,
            Icons.person_outline_rounded,
          ),
          const SizedBox(height: 24),
          _buildInfoRow(
            context,
            'email_address'.tr,
            profile.email ?? '---',
            Icons.email_outlined,
            onEdit: () => _showSecureChangeSheet(
              type: 'email_change',
              currentValue: profile.email ?? '',
            ),
          ),
          const SizedBox(height: 24),
          _buildInfoRow(
            context,
            'phone_number'.tr,
            profile.phone ?? '---',
            Icons.phone_android_rounded,
            onEdit: () => _showSecureChangeSheet(
              type: 'phone_change',
              currentValue: profile.phone ?? '',
            ),
          ),
          const SizedBox(height: 24),
          _buildReferralRow(context),
          const SizedBox(height: 24),
          _buildInputField(
            context,
            'country'.tr,
            _countryController,
            Icons.public_rounded,
          ),
          const SizedBox(height: 24),
          _buildInputField(
            context,
            'province'.tr,
            _provinceController,
            Icons.location_city_rounded,
          ),
          const SizedBox(height: 24),
          _buildInputField(
            context,
            'city'.tr,
            _cityController,
            Icons.location_on_rounded,
          ),
          const SizedBox(height: 24),
          _buildInputField(
            context,
            'address'.tr,
            _addressController,
            Icons.home_rounded,
          ),
        ],
      );
    }).animate().fadeIn(delay: 400.ms).slideY(begin: 0.05);
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    VoidCallback? onEdit,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark
                ? AppColors.textSecondary
                : AppColors.textSecondaryLight,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.surface.withValues(alpha: 0.5)
                  : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: onEdit != null
                    ? AppColors.darkGold.withValues(alpha: 0.3)
                    : AppColors.darkGold.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppColors.darkGold, size: 22),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                if (onEdit != null)
                  Text(
                    'edit'.tr,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.darkGold,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                else
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 14,
                    color: AppColors.darkGold.withValues(alpha: 0.3),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReferralRow(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'referral_code'.tr,
          style: TextStyle(
            color: isDark
                ? AppColors.textSecondary
                : AppColors.textSecondaryLight,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.surface.withValues(alpha: 0.5)
                : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.darkGold.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.qr_code_rounded,
                    color: AppColors.darkGold,
                    size: 22,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    _referralCode,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: AppColors.darkGold,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.copy_rounded, color: AppColors.darkGold),
                tooltip: 'copy_referral'.tr,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _referralCode));
                  AppSnack.success('success'.tr, 'success_copy'.tr);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showSecureChangeSheet({
    required String type,
    required String currentValue,
  }) {
    ProfileUpdateController.to.resetFlow();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.background : AppColors.backgroundLight,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ProfileUpdateView(
            embeddedArguments: {'type': type, 'current_value': currentValue},
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(
    BuildContext context,
    String label,
    TextEditingController controller,
    IconData icon, {
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark
                ? AppColors.textSecondary
                : AppColors.textSecondaryLight,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: isDark
                ? [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: KasbyTextField(
            controller: controller,
            hint: label,
            enabled: enabled,
            prefixIcon: Icon(icon, color: AppColors.darkGold, size: 22),
          ),
        ),
      ],
    );
  }
}
