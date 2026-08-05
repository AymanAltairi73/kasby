import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.primaryGold,
          ),
          onPressed: () => Get.back(),
        ),
        title: Text(
          product.nameAr,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Product Hero Banner ──
                  Container(
                    height: 230,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1B1B22) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppColors.primaryGold.withValues(alpha: 0.3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child:
                          product.imageUrl != null &&
                              product.imageUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: product.imageUrl!,
                              fit: BoxFit.contain,
                              placeholder: (_, __) => const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primaryGold,
                                ),
                              ),
                              errorWidget: (_, __, ___) => const Center(
                                child: Icon(
                                  Icons.card_giftcard_rounded,
                                  color: AppColors.primaryGold,
                                  size: 70,
                                ),
                              ),
                            )
                          : const Center(
                              child: Icon(
                                Icons.card_giftcard_rounded,
                                color: AppColors.primaryGold,
                                size: 70,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Stock Status & Discount Badges ──
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: product.inStock
                              ? Colors.green.withValues(alpha: 0.15)
                              : Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: product.inStock ? Colors.green : Colors.red,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              product.inStock
                                  ? Icons.check_circle_rounded
                                  : Icons.cancel_rounded,
                              color: product.inStock
                                  ? Colors.green
                                  : Colors.red,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              product.inStock
                                  ? 'متوفر للتسليم الفوري'
                                  : 'نفد المخزون حالياً',
                              style: TextStyle(
                                color: product.inStock
                                    ? Colors.green
                                    : Colors.red,
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withValues(alpha: 0.4),
                                blurRadius: 6,
                              ),
                            ],
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

                  // ── Title ──
                  Text(
                    product.nameAr,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Glassmorphic Price Container ──
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1B1B22) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primaryGold.withValues(alpha: 0.3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'السعر بالدولار (USD)',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  '\$${product.walletPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: AppColors.primaryGold,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (product.originalPrice != null &&
                                    product.originalPrice! >
                                        product.walletPrice) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '\$${product.originalPrice!.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 14,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        if (product.kspPrice != null &&
                            product.kspPrice! > 0) ...[
                          Container(
                            height: 40,
                            width: 1,
                            color: Colors.white12,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'السعر بعملة KSP',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.stars_rounded,
                                    color: Colors.amber,
                                    size: 18,
                                  ),
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

                  // ── Description Section ──
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 18,
                        decoration: BoxDecoration(
                          color: AppColors.primaryGold,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'تفاصيل ووصف المنتج',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF16161D)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Text(
                      product.descriptionAr.isNotEmpty
                          ? product.descriptionAr
                          : 'احصل على هذا المنتج كود رقمي فوري ومضمون 100%، يمكنك استخدامه مباشرة عبر المنصة المحددة.',
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Features summary chips
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1B1B22) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildFeatureChip(Icons.flash_on_rounded, 'تسليم فوري'),
                        _buildFeatureChip(
                          Icons.verified_user_rounded,
                          'كود مضمون 100%',
                        ),
                        _buildFeatureChip(
                          Icons.support_agent_rounded,
                          'دعم 24/7',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom Purchase Bar ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF16161D) : Colors.white,
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: product.inStock
                      ? AppColors.primaryGold
                      : Colors.grey[700],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: product.inStock ? 4 : 0,
                ),
                onPressed: product.inStock
                    ? () {
                        Get.bottomSheet(
                          StoreCheckoutSheet(product: product),
                          isScrollControlled: true,
                        );
                      }
                    : null,
                icon: const Icon(
                  Icons.shopping_bag_rounded,
                  color: Colors.black,
                ),
                label: Text(
                  product.inStock
                      ? 'شراء المنتج الآن'
                      : 'غير متوفر بالمخزون حالياً',
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

  Widget _buildFeatureChip(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryGold, size: 18),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
