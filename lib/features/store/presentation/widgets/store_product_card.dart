import 'package:flutter/material.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/features/store/domain/models/store_product_model.dart';

class StoreProductCard extends StatelessWidget {
  final StoreProductModel product;
  final VoidCallback onTap;

  const StoreProductCard({
    super.key,
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1B1B22) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: product.inStock
                ? AppColors.primaryGold.withValues(alpha: 0.3)
                : Colors.red.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image header with discount / stock badge
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  child: Container(
                    height: 110,
                    width: double.infinity,
                    color: isDark ? const Color(0xFF25252E) : Colors.grey[100],
                    child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                        ? Image.network(
                            product.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.card_giftcard,
                              color: AppColors.primaryGold,
                              size: 40,
                            ),
                          )
                        : const Icon(
                            Icons.card_giftcard,
                            color: AppColors.primaryGold,
                            size: 40,
                          ),
                  ),
                ),
                if (product.discountPercent > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '-${product.discountPercent}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: product.inStock
                          ? Colors.green.withValues(alpha: 0.85)
                          : Colors.red.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      product.inStock ? 'متوفر' : 'غير متوفر',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Content info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      product.nameAr,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // USD Price
                        Row(
                          children: [
                            Text(
                              '\$${product.walletPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: AppColors.primaryGold,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            if (product.originalPrice != null &&
                                product.originalPrice! > product.walletPrice) ...[
                              const SizedBox(width: 6),
                              Text(
                                '\$${product.originalPrice!.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 11,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ]
                          ],
                        ),

                        // KSP Price
                        if (product.kspPrice != null && product.kspPrice! > 0) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.stars, color: Colors.amber, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                '${product.kspPrice!.toStringAsFixed(0)} KSP',
                                style: TextStyle(
                                  color: Colors.amber[400],
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
