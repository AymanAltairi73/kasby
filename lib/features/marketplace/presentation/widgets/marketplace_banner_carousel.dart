import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';
import '../../domain/models/marketplace_promotion.dart';

class MarketplaceBannerCarousel extends StatefulWidget {
  final List<MarketplacePromotion> banners;

  const MarketplaceBannerCarousel({super.key, required this.banners});

  @override
  State<MarketplaceBannerCarousel> createState() =>
      _MarketplaceBannerCarouselState();
}

class _MarketplaceBannerCarouselState extends State<MarketplaceBannerCarousel> {
  final _pageController = PageController();
  int _current = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();
    final locale = Get.locale?.languageCode ?? 'en';

    return Column(
      children: [
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _current = i),
            itemCount: widget.banners.length,
            itemBuilder: (_, i) {
              final banner = widget.banners[i];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: KasbySpacing.xs),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(KasbyRadius.card),
                  gradient: LinearGradient(
                    colors: [
                      AppColors.darkGold.withValues(alpha: 0.3),
                      AppColors.darkGold.withValues(alpha: 0.05),
                    ],
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (banner.imageUrl != null)
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(KasbyRadius.card),
                        child: Image.network(
                          banner.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(KasbyRadius.card),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(KasbySpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            banner.localizedTitle(locale),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (banner.localizedDescription(locale) != null)
                            Text(
                              banner.localizedDescription(locale)!,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms);
            },
          ),
        ),
        const SizedBox(height: KasbySpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.banners.length,
            (i) => AnimatedContainer(
              duration: KasbyMotion.fast,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _current == i ? 20 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: _current == i
                    ? AppColors.darkGold
                    : AppColors.darkGold.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
