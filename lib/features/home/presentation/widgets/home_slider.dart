import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_design.dart';
import 'package:kasby/core/widgets/kasby_shimmer.dart';
import 'package:kasby/features/home/presentation/controllers/ad_controller.dart';

class HomeSlider extends StatefulWidget {
  const HomeSlider({super.key});

  @override
  State<HomeSlider> createState() => _HomeSliderState();
}

class _HomeSliderState extends State<HomeSlider> {
  final PageController _pageController = PageController();
  final adController = Get.put(AdController());
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      final adCount = adController.ads.length;
      if (adCount <= 1) return;

      if (_currentPage < adCount - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeInOutQuart,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Obx(() {
      final ads = adController.ads;
      if (ads.isEmpty && !adController.isLoading.value) {
        return const SizedBox.shrink();
      }

      if (adController.isLoading.value && ads.isEmpty) {
        return Container(
          height: 190,
          margin: const EdgeInsets.symmetric(vertical: 5),
          child: const KasbyShimmer(
            width: double.infinity,
            height: 180,
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
        );
      }

      return Column(
        children: [
          Container(
            height: 190,
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemCount: ads.length,
              itemBuilder: (context, index) {
                final ad = ads[index];
                return AnimatedBuilder(
                  animation: _pageController,
                  builder: (context, child) {
                    double value = 1.0;
                    if (_pageController.position.haveDimensions) {
                      value = (_pageController.page! - index).abs();
                      value = (1 - (value * 0.15)).clamp(0.0, 1.0);
                    }
                    return Center(
                      child: SizedBox(
                        height: Curves.easeOut.transform(value) * 180,
                        width: Curves.easeOut.transform(value) * 450,
                        child: child,
                      ),
                    );
                  },
                  child:
                      GestureDetector(
                            onTap: () {
                              if (ad.actionUrl != null &&
                                  ad.actionUrl!.isNotEmpty) {
                                HapticFeedback.lightImpact();
                                Get.toNamed(ad.actionUrl!);
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 5),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.darkGold.withValues(
                                      alpha: 0.2,
                                    ),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    CachedNetworkImage(
                                      imageUrl: ad.imageUrl,
                                      fit: BoxFit.cover,
                                      memCacheWidth: 800,
                                      maxHeightDiskCache: 600,
                                      placeholder: (context, url) =>
                                          const KasbyShimmer.card(),
                                      errorWidget: (context, url, error) =>
                                          Image.asset(
                                            _getFallbackAsset(ad.imageUrl),
                                            fit: BoxFit.cover,
                                          ),
                                    ),
                                    Positioned.fill(
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.transparent,
                                              Colors.black.withValues(
                                                alpha: 0.25,
                                              ),
                                              Colors.black.withValues(
                                                alpha: 0.75,
                                              ),
                                            ],
                                            stops: const [0.3, 0.6, 1.0],
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 14,
                                      left: 16,
                                      right: 16,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                                Get.locale?.languageCode == 'en'
                                                    ? (ad.titleEn ?? ad.titleAr)
                                                    : ad.titleAr,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 16,
                                                  shadows: [
                                                    Shadow(
                                                      blurRadius: 8,
                                                      color: Colors.black54,
                                                    ),
                                                  ],
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              )
                                              .animate(
                                                autoPlay: KasbyMotion.enabled(
                                                  context,
                                                ),
                                                key: ValueKey(
                                                  'title_${ad.id}_$_currentPage',
                                                ),
                                              )
                                              .fadeIn(
                                                duration: KasbyMotion.duration(
                                                  context,
                                                  600.ms,
                                                ),
                                                curve: Curves.easeOut,
                                              ),
                                          if ((Get.locale?.languageCode == 'en'
                                                      ? ad.descriptionEn
                                                      : ad.descriptionAr) !=
                                                  null &&
                                              (Get.locale?.languageCode == 'en'
                                                      ? ad.descriptionEn
                                                      : ad.descriptionAr)!
                                                  .isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                                  Get.locale?.languageCode ==
                                                          'en'
                                                      ? ad.descriptionEn!
                                                      : ad.descriptionAr!,
                                                  style: TextStyle(
                                                    color: Colors.white
                                                        .withValues(alpha: 0.9),
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                    shadows: const [
                                                      Shadow(
                                                        blurRadius: 6,
                                                        color: Colors.black45,
                                                      ),
                                                    ],
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                )
                                                .animate(
                                                  autoPlay: KasbyMotion.enabled(
                                                    context,
                                                  ),
                                                  key: ValueKey(
                                                    'desc_${ad.id}_$_currentPage',
                                                  ),
                                                )
                                                .fadeIn(
                                                  delay: KasbyMotion.duration(
                                                    context,
                                                    300.ms,
                                                  ),
                                                  duration:
                                                      KasbyMotion.duration(
                                                        context,
                                                        500.ms,
                                                      ),
                                                  curve: Curves.easeOut,
                                                )
                                                .slideX(
                                                  begin: -0.15,
                                                  end: 0,
                                                  delay: KasbyMotion.duration(
                                                    context,
                                                    300.ms,
                                                  ),
                                                  duration:
                                                      KasbyMotion.duration(
                                                        context,
                                                        700.ms,
                                                      ),
                                                  curve: Curves.easeOutCubic,
                                                ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                          .animate(
                            autoPlay: KasbyMotion.enabled(context),
                            onPlay: (c) => c.repeat(),
                          )
                          .shimmer(
                            duration: KasbyMotion.duration(context, 3000.ms),
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.1),
                          ),
                );
              },
            ),
          ),
          if (ads.length > 1) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                ads.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 6,
                  width: _currentPage == index ? 24 : 6,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? AppColors.darkGold
                        : (isDark ? Colors.white24 : Colors.black12),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: _currentPage == index
                        ? [
                            BoxShadow(
                              color: AppColors.darkGold.withValues(alpha: 0.5),
                              blurRadius: 8,
                              offset: const Offset(0, 0),
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ),
          ],
        ],
      );
    });
  }

  String _getFallbackAsset(String url) {
    if (url.contains('slider_growth')) {
      return 'assets/images/slider_growth.png';
    }
    if (url.contains('slider_secure')) {
      return 'assets/images/slider_secure.png';
    }
    if (url.contains('slider_diversified')) {
      return 'assets/images/slider_diversified.png';
    }
    return 'assets/images/slider_growth.png';
  }
}
