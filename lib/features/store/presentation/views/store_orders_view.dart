import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/features/store/presentation/controllers/store_controller.dart';
import 'package:kasby/features/store/presentation/widgets/store_order_card.dart';

class StoreOrdersView extends StatelessWidget {
  const StoreOrdersView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = StoreController.to;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0E0E11) : const Color(0xFFF7F8FA);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('سجل الطلبات والأكواد'),
      ),
      body: RefreshIndicator(
        onRefresh: () => controller.fetchOrders(),
        color: AppColors.primaryGold,
        child: Obx(() {
          if (controller.orders.isEmpty) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 70,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'لا توجد طلبات سابقة في المتجر',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'جميع مشترياتك وأكوادك المشتراة تظهر هنا فوراً',
                        style: TextStyle(color: Colors.grey[400], fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: controller.orders.length,
            itemBuilder: (context, index) {
              final order = controller.orders[index];
              return StoreOrderCard(order: order);
            },
          );
        }),
      ),
    );
  }
}
