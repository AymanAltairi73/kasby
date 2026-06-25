import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';
import '../../domain/repositories/marketplace_repository.dart';
import '../widgets/marketplace_order_timeline_widget.dart';

class MarketplaceOrderDetailView extends StatefulWidget {
  const MarketplaceOrderDetailView({super.key});

  @override
  State<MarketplaceOrderDetailView> createState() => _MarketplaceOrderDetailViewState();
}

class _MarketplaceOrderDetailViewState extends State<MarketplaceOrderDetailView> {
  dynamic order;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    order = await MarketplaceRepository().getOrderById(Get.arguments as String);
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (order == null) {
      return Scaffold(appBar: AppBar(), body: Center(child: Text('marketplace_order_not_found'.tr)));
    }
    final locale = Get.locale?.languageCode ?? 'en';
    return Scaffold(
      appBar: AppBar(title: Text('marketplace_order_detail'.tr)),
      body: ListView(
        padding: const EdgeInsets.all(KasbySpacing.lg),
        children: [
          Text('#${order.id}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: KasbySpacing.sm),
          Text('${'marketplace_total'.tr}: \$${order.totalAmount.toStringAsFixed(2)}', style: TextStyle(color: AppColors.darkGold, fontWeight: FontWeight.bold)),
          if (order.deliveryCode != null) Text('${'marketplace_delivery_code'.tr}: ${order.deliveryCode}'),
          const SizedBox(height: KasbySpacing.lg),
          Text('marketplace_order_timeline'.tr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: KasbySpacing.md),
          MarketplaceOrderTimelineWidget(order: order),
          const Divider(),
          ...order.items.map<Widget>((item) => ListTile(
                title: Text(item.localizedDisplayName(locale)),
                trailing: Text('\$${item.totalPrice.toStringAsFixed(2)}'),
              )),
        ],
      ),
    );
  }
}
