// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:kasby/core/theme/app_colors.dart';
// import 'package:kasby/routes/app_routes.dart';
// import 'package:flutter_animate/flutter_animate.dart';

// class ServicesView extends StatelessWidget {
//   const ServicesView({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: CustomScrollView(
//         slivers: [
//           _buildSliverAppBar(),
//           SliverToBoxAdapter(child: const SizedBox(height: 24)),
//           _buildSectionHeader('financial_services'.tr),
//           _buildServiceGrid([
//             {
//               'name': 'my_wallet'.tr,
//               'icon': Icons.account_balance_wallet_rounded,
//               'route': Routes.wallet,
//               'color': const Color(0xFFFFD700),
//               'glow': Colors.amber,
//             },
//             {
//               'name': 'p2p_transfer'.tr,
//               'icon': Icons.swap_horizontal_circle_rounded,
//               'route': Routes.transfer,
//               'color': const Color(0xFF00E676),
//               'glow': Colors.greenAccent,
//             },
//             {
//               'name': 'authorized_agents'.tr,
//               'icon': Icons.groups_rounded,
//               'route': Routes.agents,
//               'color': const Color(0xFF2196F3),
//               'glow': Colors.blueAccent,
//             },
//           ]),
//           _buildSectionHeader('investment_center'.tr),
//           _buildServiceGrid([
//             {
//               'name': 'investments'.tr,
//               'icon': Icons.card_membership_rounded,
//               'route': Routes.subscription,
//               'color': const Color(0xFFFF4081),
//               'glow': Colors.pinkAccent,
//             },
//             {
//               'name': 'my_investments'.tr,
//               'icon': Icons.pie_chart_rounded,
//               'route': Routes.myInvestments,
//               'color': const Color(0xFF7C4DFF),
//               'glow': Colors.deepPurpleAccent,
//             },
//             {
//               'name': 'salefni_kasby'.tr,
//               'icon': Icons.handshake_rounded,
//               'route': Routes.loan,
//               'color': const Color(0xFFFFAB40),
//               'glow': Colors.orangeAccent,
//             },
//           ]),
//           _buildSectionHeader('account_support'.tr),
//           _buildServiceGrid([
//             {
//               'name': 'account'.tr,
//               'icon': Icons.person_rounded,
//               'route': Routes.profile,
//               'color': Colors.white70,
//               'glow': Colors.white12,
//             },
//             {
//               'name': 'support'.tr,
//               'icon': Icons.headset_mic_rounded,
//               'route': Routes.support,
//               'color': const Color(0xFF00BCD4),
//               'glow': Colors.cyanAccent,
//             },
//             {
//               'name': 'legal'.tr,
//               'icon': Icons.gavel_rounded,
//               'route': Routes.legal,
//               'color': Colors.grey,
//               'glow': Colors.grey,
//             },
//           ]),
//           SliverToBoxAdapter(child: const SizedBox(height: 100)),
//         ],
//       ),
//     );
//   }

//   Widget _buildSliverAppBar() {
//     return SliverAppBar(
//       expandedHeight: 180,
//       floating: false,
//       pinned: true,
//       backgroundColor: Colors.black,
//       leading: IconButton(
//         icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
//         onPressed: () => Get.back(),
//       ),
//       flexibleSpace: FlexibleSpaceBar(
//         centerTitle: true,
//         title: Text(
//           'all_services'.tr,
//           style: const TextStyle(
//             color: Colors.white,
//             fontWeight: FontWeight.w900,
//             fontSize: 20,
//             letterSpacing: 1.2,
//           ),
//         ),
//         background: Stack(
//           fit: StackFit.expand,
//           children: [
//             Container(
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   begin: Alignment.topCenter,
//                   end: Alignment.bottomCenter,
//                   colors: [
//                     AppColors.darkGold.withValues(alpha: 0.2),
//                     Colors.black,
//                   ],
//                 ),
//               ),
//             ),
//             Positioned(
//               top: -50,
//               right: -50,
//               child:
//                   Container(
//                         width: 200,
//                         height: 200,
//                         decoration: BoxDecoration(
//                           shape: BoxShape.circle,
//                           color: AppColors.darkGold.withValues(alpha: 0.1),
//                         ),
//                       )
//                       .animate(onPlay: (c) => c.repeat())
//                       .scale(
//                         duration: const Duration(seconds: 3),
//                         begin: const Offset(1, 1),
//                         end: const Offset(1.5, 1.5),
//                       )
//                       .blurXY(begin: 20, end: 50),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildSectionHeader(String title) {
//     return SliverToBoxAdapter(
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
//         child: Row(
//           children: [
//             Container(
//               width: 4,
//               height: 20,
//               decoration: BoxDecoration(
//                 color: AppColors.darkGold,
//                 borderRadius: BorderRadius.circular(2),
//               ),
//             ),
//             const SizedBox(width: 12),
//             Text(
//               title,
//               style: const TextStyle(
//                 fontSize: 18,
//                 fontWeight: FontWeight.w900,
//                 letterSpacing: 0.5,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildServiceGrid(List<Map<String, dynamic>> items) {
//     return SliverPadding(
//       padding: const EdgeInsets.symmetric(horizontal: 20),
//       sliver: SliverGrid(
//         gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//           crossAxisCount: 2,
//           crossAxisSpacing: 16,
//           mainAxisSpacing: 16,
//           childAspectRatio: 1.2,
//         ),
//         delegate: SliverChildBuilderDelegate((context, index) {
//           final item = items[index];
//           return _buildMagicalItem(item, index);
//         }, childCount: items.length),
//       ),
//     );
//   }

//   Widget _buildMagicalItem(Map<String, dynamic> item, int index) {
//     return Container(
//           decoration: BoxDecoration(
//             borderRadius: BorderRadius.circular(28),
//             boxShadow: [
//               BoxShadow(
//                 color: item['glow'].withValues(alpha: 0.1),
//                 blurRadius: 20,
//                 spreadRadius: -5,
//               ),
//             ],
//           ),
//           child: ClipRRect(
//             borderRadius: BorderRadius.circular(28),
//             child: Material(
//               color: Colors.transparent,
//               child: InkWell(
//                 onTap: () => Get.toNamed(item['route']),
//                 child: Container(
//                   decoration: BoxDecoration(
//                     color: AppColors.surface.withValues(alpha: 0.5),
//                     border: Border.all(
//                       color: item['glow'].withValues(alpha: 0.2),
//                       width: 1,
//                     ),
//                     gradient: LinearGradient(
//                       begin: Alignment.topLeft,
//                       end: Alignment.bottomRight,
//                       colors: [
//                         Colors.white.withValues(alpha: 0.05),
//                         Colors.white.withValues(alpha: 0.01),
//                       ],
//                     ),
//                   ),
//                   child: Stack(
//                     children: [
//                       Positioned(
//                         top: -10,
//                         right: -10,
//                         child: Icon(
//                           item['icon'],
//                           size: 80,
//                           color: item['color'].withValues(alpha: 0.05),
//                         ),
//                       ),
//                       Center(
//                         child: Column(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                             Container(
//                                   padding: const EdgeInsets.all(14),
//                                   decoration: BoxDecoration(
//                                     color: item['color'].withValues(alpha: 0.1),
//                                     shape: BoxShape.circle,
//                                     boxShadow: [
//                                       BoxShadow(
//                                         color: item['color'].withValues(
//                                           alpha: 0.2,
//                                         ),
//                                         blurRadius: 15,
//                                         spreadRadius: 1,
//                                       ),
//                                     ],
//                                   ),
//                                   child: Icon(
//                                     item['icon'],
//                                     color: item['color'],
//                                     size: 30,
//                                   ),
//                                 )
//                                 .animate(onPlay: (c) => c.repeat(reverse: true))
//                                 .shimmer(
//                                   duration: const Duration(seconds: 2),
//                                   color: Colors.white24,
//                                 )
//                                 .scale(
//                                   duration: const Duration(seconds: 2),
//                                   begin: const Offset(1, 1),
//                                   end: const Offset(1.05, 1.05),
//                                 ),
//                             const SizedBox(height: 12),
//                             Text(
//                               item['name'],
//                               textAlign: TextAlign.center,
//                               style: const TextStyle(
//                                 fontSize: 13,
//                                 fontWeight: FontWeight.bold,
//                                 letterSpacing: 0.3,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         )
//         .animate()
//         .fadeIn(delay: (50 * index).ms)
//         .slideY(begin: 0.2, end: 0, curve: Curves.easeOutBack);
//   }
// }
