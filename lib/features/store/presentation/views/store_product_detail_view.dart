import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/features/store/domain/models/store_product_model.dart';
import 'package:kasby/features/store/presentation/widgets/store_checkout_sheet.dart';

class StoreProductDetailView extends StatelessWidget {
  const StoreProductDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> args = Get.arguments ?? {};
    final StoreProductModel? product = args['product'] as StoreProductModel?;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0E0E11) : const Color(0xFFF7F8FA);
    final textColor = isDark ? Colors.white : Colors.black87;

    if (product == null) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(title: const Text('تفاصيل المنتج')),
        body: const Center(child: Text('عذراً، تعذر تحميل بيانات المنتج')),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(product.nameAr),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Banner / Image Container
                  Container(
                    height: 220,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1B1B22) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppColors.primaryGold.withValues(alpha: 0.3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                          ? Image.network(product.imageUrl!, fit: BoxFit.contain)
                          : const Icon(Icons.card_giftcard,
                              color: AppColors.primaryGold, size: 70),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Stock Status & Discount Badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: product.inStock
                              ? Colors.green.withValues(alpha: 0.15)
                              : Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: product.inStock ? Colors.green : Colors.red,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              product.inStock ? Icons.check_circle : Icons.cancel,
                              color: product.inStock ? Colors.green : Colors.red,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              product.inStock ? 'متوفر للتسليم الفوري' : 'نفد المخزون حالياً',
                              style: TextStyle(
                                color: product.inStock ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (product.discountPercent > 0) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'خصم ${product.discountPercent}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Title
                  Text(
                    product.nameAr,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Price Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1B1B22) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'السعر بالدولار (USD)',
                              style: TextStyle(color: Colors.grey[500], fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '\$${product.walletPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: AppColors.primaryGold,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (product.kspPrice != null && product.kspPrice! > 0) ...[
                          Container(height: 40, width: 1, color: Colors.white12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'السعر بعملة KSP',
                                style: TextStyle(color: Colors.grey[500], fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.stars, color: Colors.amber, size: 18),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${product.kspPrice!.toStringAsFixed(0)} KSP',
                                    style: const TextStyle(
                                      color: Colors.amber,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Description
                  Text(
                    'تفاصيل ووصف المنتج',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.descriptionAr.isNotEmpty
                        ? product.descriptionAr
                        : 'احصل على هذا المنتج كود رقمي فوري ومضمون 100%، يمكنك استخدامه مباشرة عبر المنصة المحددة.',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Purchase Bar
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF16161D) : Colors.white,
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: product.inStock ? AppColors.primaryGold : Colors.grey,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: product.inStock
                    ? () {
                        Get.bottomSheet(
                          StoreCheckoutSheet(product: product),
                          isScrollControlled: true,
                        );
                      }
                    : null,
                icon: const Icon(Icons.shopping_bag_outlined, color: Colors.black),
                label: Text(
                  product.inStock ? 'شراء المنتج الآن' : 'غير متوفر بالمخزون حالياً',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
