import 'package:flutter/material.dart';

import '../theme.dart';

enum BannerTone { neutral, info, success, error }

/// Oyun ve ders ekranlarının üstünde durum mesajı.
/// Renk yalnızca anlam taşıdığında değişir: başarı yeşil, hata kırmızı, bekleme mavi.
class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.text,
    this.tone = BannerTone.neutral,
    this.icon,
  });

  final String text;
  final BannerTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, defaultIcon) = switch (tone) {
      BannerTone.neutral => (
        AppColors.navyLight,
        AppColors.navyDark,
        Icons.touch_app_outlined,
      ),
      BannerTone.info => (
        AppColors.navyLight,
        AppColors.navyDark,
        Icons.hourglass_top_rounded,
      ),
      BannerTone.success => (
        AppColors.successLight,
        AppColors.successInk,
        Icons.celebration_rounded,
      ),
      BannerTone.error => (
        AppColors.errorLight,
        AppColors.errorInk,
        Icons.replay_rounded,
      ),
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon ?? defaultIcon, color: fg, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: fg,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
