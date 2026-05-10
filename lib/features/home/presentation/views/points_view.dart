import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_card.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/models/transaction_model.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';

class PointsView extends StatefulWidget {
  const PointsView({super.key});

  @override
  State<PointsView> createState() => _PointsViewState();
}

class _PointsViewState extends State<PointsView> {
  final RxList<TransactionModel> pointsHistory = <TransactionModel>[].obs;
  final RxBool isLoading = true.obs;

  @override
  void initState() {
    super.initState();
    _fetchPointsData();
  }

  Future<void> _fetchPointsData() async {
    if (!SupabaseService.isLoggedIn) return;
    isLoading.value = true;
    try {
      // Refresh points from centralized controller
      await HomeController.to.fetchPoints();

      // Fetch points history from point_history table
      final historyResponse = await SupabaseService.client
          .from('point_history')
          .select()
          .eq('user_id', SupabaseService.userId!)
          .order('created_at', ascending: false)
          .limit(20);

      pointsHistory.value = (historyResponse as List).map((json) {
        return TransactionModel(
          id: json['id'],
          userId: json['user_id'],
          walletId: '', // Not relevant for points
          amount: (json['points'] as num).toDouble(),
          type: json['type'],
          status: 'completed',
          description: json['description'],
          createdAt: DateTime.parse(json['created_at']),
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching points: $e');
    } finally {
      isLoading.value = false;
    }
  }

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('points'.tr),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildPointsCard(),
            const SizedBox(height: 32),
            _buildHowToUse(),
            const SizedBox(height: 32),
            _buildHistory(),
          ],
        ),
      ),
    );
  }

  Widget _buildPointsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: AppColors.goldGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.darkGold.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.stars_rounded, size: 64, color: Colors.black),
          const SizedBox(height: 16),
          Obx(
            () => Text(
              '${HomeController.to.userPoints.value}',
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          Text(
            'points'.tr,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.black54,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack).fadeIn();
  }

  Widget _buildHowToUse() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'how_to_use_points'.tr,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        KasbyCard(
          child: Text(
            'points_guide'.tr,
            style: TextStyle(color: AppColors.textSecondary, height: 1.6),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'points_history'.tr,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Obx(() {
          if (isLoading.value) {
            return Center(
              child: CircularProgressIndicator(color: AppColors.darkGold),
            );
          }

          if (pointsHistory.isEmpty) {
            return KasbyCard(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'no_transactions'.tr,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            );
          }

          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pointsHistory.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final tx = pointsHistory[index];
              return KasbyCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      tx.type == 'earn'
                          ? Icons.add_circle_outline
                          : Icons.remove_circle_outline,
                      color: tx.type == 'earn'
                          ? AppColors.softGreen
                          : AppColors.error,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx.description ?? tx.type,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : AppColors.onSurfaceLight,
                            ),
                          ),
                          if (tx.createdAt != null)
                            Text(
                              '${tx.createdAt!.day}/${tx.createdAt!.month}/${tx.createdAt!.year}',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      '${tx.type == 'earn' ? '+' : '-'}${tx.amount.toInt()}',
                      style: TextStyle(
                        color: tx.type == 'earn'
                            ? AppColors.softGreen
                            : AppColors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        }),
      ],
    ).animate().fadeIn(delay: 500.ms);
  }
}
