import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:kasby/routes/app_routes.dart';
import '../../domain/models/marketplace_order.dart';
import '../controllers/marketplace_orders_controller.dart';

class MarketplaceOrdersView extends StatelessWidget {
  const MarketplaceOrdersView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(MarketplaceOrdersController());
    final dateFmt = DateFormat.yMMMd().add_Hm();

    return Scaffold(
      appBar: AppBar(title: Text('marketplace_orders'.tr)),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Obx(() => Row(
                  children: [
                    _chip(controller, null, 'marketplace_all'.tr),
                    _chip(controller, MarketplaceOrderStatus.pending, 'marketplace_pending'.tr),
                    _chip(controller, MarketplaceOrderStatus.processing, 'marketplace_processing'.tr),
                    _chip(controller, MarketplaceOrderStatus.delivered, 'marketplace_delivered'.tr),
                    _chip(controller, MarketplaceOrderStatus.completed, 'marketplace_completed'.tr),
                    _chip(controller, MarketplaceOrderStatus.cancelled, 'marketplace_cancelled'.tr),
                  ],
                )),
          ),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              if (controller.orders.isEmpty) {
                return Center(child: Text('marketplace_no_orders'.tr));
              }
              return ListView.builder(
                itemCount: controller.orders.length,
                itemBuilder: (_, i) {
                  final o = controller.orders[i];
                  return ListTile(
                    onTap: () => Get.toNamed(Routes.marketplaceOrderDetail, arguments: o.id),
                    title: Text('#${o.id}'),
                    subtitle: Text(dateFmt.format(o.createdAt)),
                    trailing: Text('\$${o.totalAmount.toStringAsFixed(2)}\n${o.status.name}', textAlign: TextAlign.end),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _chip(MarketplaceOrdersController c, MarketplaceOrderStatus? status, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: c.filterStatus.value == status,
        onSelected: (_) => c.setFilter(status),
      ),
    );
  }
}
