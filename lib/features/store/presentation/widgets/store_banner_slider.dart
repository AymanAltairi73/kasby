import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/features/store/domain/models/store_banner_model.dart';

class StoreBannerSlider extends StatefulWidget {
  final List<StoreBannerModel> banners;

  const StoreBannerSlider({super.key, required this.banners});

  @override
  State<StoreBannerSlider> createState() => _StoreBannerSliderState();
}

class _StoreBannerSliderState extends State<StoreBannerSlider> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  Timer? _autoPlayTimer;

  @override
  void initState() {
    super.initState();
    _startAutoPlay();
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    if (widget.banners.length > 1) {
      _autoPlayTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (_pageController.hasClients) {
          final nextIndex = (_currentIndex + 1) % widget.banners.length;
          _pageController.animateToPage(
            nextIndex,
            duration: const Duration(milliseconds: 500),
            curve: Curves.fastOutSlowIn,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) {
      return Container(
        height: 145,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF2C2411).withValues(alpha: 0.8),
              const Color(0xFF15141A),
            ],
          ),
          border: Border.all(
            color: AppColors.primaryGold.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  color: AppColors.primaryGold,
                  size: 28,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'مرحباً بك في متجر كاسبي الرقمي',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'اشتر بطاقاتك واشتراكاتك المفضلة فوراً',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 155,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.banners.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
              final banner = widget.banners[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      // Banner Image
                      if (banner.imageUrl.isNotEmpty)
                        Positioned.fill(
                          child: CachedNetworkImage(
                            imageUrl: banner.imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: const Color(0xFF1E1E26),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primaryGold,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: const Color(0xFF1E1E26),
                              child: const Icon(
                                Icons.broken_image,
                                color: Colors.grey,
                                size: 36,
                              ),
                            ),
                          ),
                        )
                      else
                        Positioned.fill(
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF2C2411), Color(0xFF141318)],
                              ),
                            ),
                          ),
                        ),

                      // Glassmorphic Gradient Overlay
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.85),
                                Colors.black.withValues(alpha: 0.2),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),
                      ),

                      // Text Info
                      if (banner.titleAr != null && banner.titleAr!.isNotEmpty)
                        Positioned(
                          bottom: 14,
                          right: 14,
                          left: 14,
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryGold,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  banner.titleAr!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black,
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Indicator Pills
        if (widget.banners.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.banners.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _currentIndex == index ? 22 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: _currentIndex == index
                      ? AppColors.primaryGold
                      : Colors.grey.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: _currentIndex == index
                      ? [
                          BoxShadow(
                            color: AppColors.primaryGold.withValues(alpha: 0.5),
                            blurRadius: 6,
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
  }
}
