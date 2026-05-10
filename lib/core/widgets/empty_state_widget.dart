import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_button.dart';

class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String description;
  final String? lottiePath;
  final IconData? icon;
  final String? actionText;
  final VoidCallback? onAction;

  const EmptyStateWidget({
    super.key,
    required this.title,
    required this.description,
    this.lottiePath,
    this.icon,
    this.actionText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (lottiePath != null)
              (lottiePath!.startsWith('http')
                  ? Lottie.network(lottiePath!, width: 200, height: 200)
                  : Lottie.asset(
                      lottiePath!,
                      width: 200,
                      height: 200,
                      repeat: true,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildIcon(isDark),
                    ))
            else
              _buildIcon(isDark),
            
            const SizedBox(height: 24),
            
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 12),
            
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
            
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 32),
              KasbyButton(
                text: actionText!,
                onPressed: onAction!,
                width: 200,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.darkGold.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon ?? Icons.inbox_rounded,
        size: 64,
        color: AppColors.darkGold,
      ),
    );
  }
}
