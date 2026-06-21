import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/core/widgets/kasby_text_field.dart';
import 'package:kasby/core/widgets/kasby_card.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../controllers/agency_apply_controller.dart';
import 'package:kasby/core/utils/safe_getx.dart';

class AgencyApplyView extends StatefulWidget {
  const AgencyApplyView({super.key});

  @override
  State<AgencyApplyView> createState() => _AgencyApplyViewState();
}

class _AgencyApplyViewState extends State<AgencyApplyView> {
  final controller = Get.put(AgencyApplyController());
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  String _hasOffice = 'no';

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    SafeGetx.debugTrace(
      className: 'AgencyApplyView',
      method: 'initState',
      feature: 'Wallet',
      status: 'INFO',
    );
  }

  @override
  void dispose() {
    SafeGetx.debugTrace(
      className: 'AgencyApplyView',
      method: 'dispose',
      feature: 'Wallet',
      status: 'INFO',
    );
    _nameController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('agency_form_title'.tr),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Get.back(),
        ),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.hasApplied.value && controller.applicationStatus.value == 'pending') {
          return _buildPendingUI();
        }

        if (controller.hasApplied.value && controller.applicationStatus.value == 'approved') {
          return _buildApprovedUI();
        }

        return _buildFormUI();
      }),
    );
  }

  Widget _buildPendingUI() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.darkGold.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.pending_actions_rounded, size: 80, color: AppColors.darkGold),
            ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 32),
            Text(
              'application_pending_title'.tr,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 16),
            Text(
              'application_pending_desc'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ).animate().fadeIn(delay: 400.ms),
            const SizedBox(height: 40),
            KasbyButton(
              text: 'back'.tr,
              onPressed: () => Get.back(),
            ).animate().fadeIn(delay: 600.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovedUI() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.softGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.verified_rounded, size: 80, color: AppColors.softGreen),
            ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 32),
            Text(
              'application_approved_title'.tr,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 40),
            KasbyButton(
              text: 'back'.tr,
              onPressed: () => Get.back(),
            ).animate().fadeIn(delay: 400.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildFormUI() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroSection(),
            const SizedBox(height: 24),
            _buildBenefitsRow(),
            const SizedBox(height: 28),
            KasbyCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('personal_info'.tr),
                  const SizedBox(height: 16),
                  KasbyTextField(
                    controller: _nameController,
                    label: 'full_name'.tr,
                    hint: 'enter_full_name'.tr,
                    prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.darkGold),
                  ),
                  const SizedBox(height: 16),
                  KasbyTextField(
                    controller: _phoneController,
                    label: 'phone_number'.tr,
                    hint: 'enter_phone_hint'.tr,
                    prefixIcon: Icon(Icons.phone_outlined, color: AppColors.darkGold),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  KasbyTextField(
                    controller: _whatsappController,
                    label: 'whatsapp_number'.tr,
                    hint: 'enter_phone_hint'.tr,
                    prefixIcon: Icon(Icons.chat_outlined, color: AppColors.darkGold),
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            KasbyCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('location'.tr),
                  const SizedBox(height: 16),
                  KasbyTextField(
                    controller: _countryController,
                    label: 'country'.tr,
                    hint: 'select_country'.tr,
                    prefixIcon: Icon(Icons.public_rounded, color: AppColors.darkGold),
                  ),
                  const SizedBox(height: 16),
                  KasbyTextField(
                    controller: _cityController,
                    label: 'prov_city'.tr,
                    hint: 'enter_city'.tr,
                    prefixIcon: Icon(Icons.location_city_rounded, color: AppColors.darkGold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            KasbyCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('has_office'.tr),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildRadioOption('yes'.tr, 'yes')),
                      const SizedBox(width: 16),
                      Expanded(child: _buildRadioOption('no'.tr, 'no')),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: KasbyButton(
                text: 'submit_application'.tr,
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    controller.submitApplication(
                      fullName: _nameController.text.trim(),
                      phone: _phoneController.text.trim(),
                      whatsapp: _whatsappController.text.trim(),
                      city: _cityController.text.trim(),
                      country: _countryController.text.trim(),
                      hasOffice: _hasOffice,
                    );
                  }
                },
              ),
            ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.9, 0.9)),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.darkGold.withValues(alpha: 0.22),
            AppColors.darkGold.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(color: AppColors.darkGold.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.darkGold.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.workspace_premium_rounded,
              color: AppColors.darkGold,
              size: 36,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'agency_form_title'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.textBodyLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'agency_form_desc'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08);
  }

  Widget _buildBenefitsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildBenefitChip(Icons.payments_rounded, 'deposit_funds'.tr),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildBenefitChip(Icons.outbox_rounded, 'withdraw_funds'.tr),
        ),
      ],
    );
  }

  Widget _buildBenefitChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.darkGold.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.darkGold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : AppColors.textBodyLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: AppColors.darkGold,
        fontSize: 16,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildRadioOption(String label, String value) {
    bool isSelected = _hasOffice == value;
    return GestureDetector(
      onTap: () => setState(() => _hasOffice = value),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.darkGold.withValues(alpha: 0.1)
              : (isDark ? AppColors.surface : AppColors.surfaceLight),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.darkGold
                : (isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.1)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: isSelected ? AppColors.darkGold : AppColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.darkGold : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
