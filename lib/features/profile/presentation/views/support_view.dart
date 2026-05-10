import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_card.dart';
import 'package:flutter/services.dart';
// import 'package:url_launcher/url_launcher.dart';

class SupportView extends StatefulWidget {
  const SupportView({super.key});

  @override
  State<SupportView> createState() => _SupportViewState();
}

class _SupportViewState extends State<SupportView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _selectedCategory = "all";

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  final List<Map<String, String>> _allFaqs = [
    {'question': 'faq_q1'.tr, 'answer': 'faq_a1'.tr, 'category': 'account'},
    {'question': 'faq_q2'.tr, 'answer': 'faq_a2'.tr, 'category': 'wallet'},
    {'question': 'faq_q3'.tr, 'answer': 'faq_a3'.tr, 'category': 'investment'},
    {
      'question': 'كيف يمكنني سحب أرباحي؟'.tr,
      'answer':
          'يمكنك سحب أرباحك من خلال قسم المحفظة واختيار سحب، ثم اختيار الوكيل المناسب لك.'
              .tr,
      'category': 'wallet',
    },
    {
      'question': 'ما هي شروط الانضمام للوكلاء؟'.tr,
      'answer':
          'يجب أن يكون حسابك موثقاً (KYC) ولديك رصيد لا يقل عن مبلغ معين يحدده النظام.'
              .tr,
      'category': 'account',
    },
  ];

  List<Map<String, String>> get _filteredFaqs {
    return _allFaqs.where((faq) {
      final matchesSearch =
          faq['question']!.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          faq['answer']!.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory =
          _selectedCategory == "all" || faq['category'] == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDark
          ? AppColors.background
          : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('help_support'.tr),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Get.back(),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearchBar(),
                  const SizedBox(height: 24),
                  _buildCategories(),
                  const SizedBox(height: 32),
                  Text(
                    'common_questions'.tr,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final faq = _filteredFaqs[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildFaqItem(faq['question']!, faq['answer']!),
                );
              }, childCount: _filteredFaqs.length),
            ),
          ),
          if (_filteredFaqs.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 64,
                      color: AppColors.textSecondary.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'no_results_found'.tr,
                      style: TextStyle(
                        color: isDark
                            ? AppColors.textSecondary
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // SliverToBoxAdapter(
          //   child: Padding(
          //     padding: const EdgeInsets.all(20),
          //     child: Column(
          //       crossAxisAlignment: CrossAxisAlignment.start,
          //       children: [
          //         const SizedBox(height: 32),
          //         Text(
          //           'still_need_help'.tr,
          //           style: const TextStyle(
          //             fontSize: 18,
          //             fontWeight: FontWeight.bold,
          //           ),
          //         ),
          //         const SizedBox(height: 16),
          //         KasbyCard(
          //           color: isDark ? AppColors.surface : AppColors.surfaceLight,
          //           child: Column(
          //             children: [
          //               _buildContactItem(
          //                 Icons.chat_bubble_outline_rounded,
          //                 'chat_support'.tr,
          //                 'start_conversation'.tr,
          //                 () => Get.toNamed('/support-chat'),
          //               ),
          //               Divider(
          //                 color: isDark
          //                     ? Colors.white10
          //                     : Colors.black.withValues(alpha: 0.1),
          //               ),
          //               _buildContactItem(
          //                 Icons.email_outlined,
          //                 'email_us'.tr,
          //                 'support@kasby.com',
          //                 () => _launchEmail('support@kasby.com'),
          //               ),
          //             ],
          //           ),
          //         ),
          //         const SizedBox(height: 48),
          //         // KasbyButton(
          //         //   text: 'open_ticket'.tr,
          //         //   onPressed: () {
          //         //     HapticFeedback.lightImpact();
          //         //   },
          //         // ),
          //         // const SizedBox(height: 40),
          //       ],
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }

  // Future<void> _launchEmail(String email) async {
  //   final Uri params = Uri(
  //     scheme: 'mailto',
  //     path: email,
  //     query: 'subject=Support Request&body=Hello Kasby Support,',
  //   );
  //   if (await canLaunchUrl(params)) {
  //     await launchUrl(params, mode: LaunchMode.externalApplication);
  //   } else {
  //     Get.snackbar(
  //       'error'.tr,
  //       'Could not launch email app',
  //       backgroundColor: Colors.red.withValues(alpha: 0.7),
  //       colorText: Colors.white,
  //     );
  //   }
  // }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        style: TextStyle(
          color: isDark ? Colors.white : AppColors.textBodyLight,
        ),
        decoration: InputDecoration(
          hintText: 'search_faq'.tr,
          hintStyle: TextStyle(
            color: isDark
                ? AppColors.textSecondary
                : AppColors.textSecondaryLight,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: AppColors.darkGold,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildCategories() {
    final categories = [
      {'id': 'all', 'label': 'all'.tr, 'icon': Icons.grid_view_rounded},
      {
        'id': 'wallet',
        'label': 'wallet'.tr,
        'icon': Icons.account_balance_wallet_rounded,
      },
      {
        'id': 'investment',
        'label': 'investment'.tr,
        'icon': Icons.trending_up_rounded,
      },
      {'id': 'account', 'label': 'account'.tr, 'icon': Icons.person_rounded},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((cat) {
          final isSelected = _selectedCategory == cat['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedCategory = cat['id'] as String);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
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
                              : Colors.black.withValues(alpha: 0.05)),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      cat['icon'] as IconData,
                      size: 16,
                      color: isSelected
                          ? AppColors.darkGold
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      cat['label'] as String,
                      style: TextStyle(
                        color: isSelected
                            ? AppColors.darkGold
                            : AppColors.textSecondary,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return KasbyCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(
            question,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          iconColor: AppColors.darkGold,
          collapsedIconColor: AppColors.textSecondary,
          childrenPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                answer,
                style: TextStyle(
                  color: isDark
                      ? AppColors.textSecondary
                      : AppColors.textSecondaryLight,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactItem(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.darkGold.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.darkGold, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: isDark
              ? AppColors.textSecondary
              : AppColors.textSecondaryLight,
          fontSize: 12,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 12,
        color: isDark ? Colors.white24 : Colors.black26,
      ),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
