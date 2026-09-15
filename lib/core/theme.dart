import 'package:flutter/material.dart';

/// Satranç Akademi tasarım dili.
///
/// Renk kararları:
/// - Lacivert (primary): akademi, güven, odak. Çocuk uygulamalarında sık görülen
///   bağıran renkler yerine "okul" hissi veren koyu bir temel.
/// - Altın (accent): başarı, rozet, vurgu. Yalnızca kutlama ve ikincil vurguda kullanılır,
///   böylece anlamı sulanmaz.
/// - Krem yüzey: beyaz yerine sıcak bir zemin; tahta ile çatışmaz, göz yormaz.
/// - Durum renkleri (başarı/hata/bilgi) yalnızca geri bildirimde kullanılır.
abstract final class AppColors {
  static const navy = Color(0xFF1F3A5F);
  static const navyDark = Color(0xFF14273F);
  static const navyLight = Color(0xFFDCE6F5);
  static const gold = Color(0xFFE9A825);
  static const goldLight = Color(0xFFFFF0C9);
  static const cream = Color(0xFFFBF8F3);
  static const surface = Color(0xFFFFFFFF);
  static const outline = Color(0xFFE6E1D8);
  static const surfaceContainer = Color(0xFFF1EDE6);
  static const ink = Color(0xFF1B1F2A);
  static const inkMuted = Color(0xFF626B7A);
  static const success = Color(0xFF2E9E6B);
  static const successLight = Color(0xFFDFF4EA);
  static const error = Color(0xFFD64545);
  static const errorLight = Color(0xFFFBE3E3);
  static const info = Color(0xFF3B7DD8);

  /// Modül kimlik renkleri: her bölümün kendi tonu var, ikon ve etiketlerde tutarlı kullanılır.
  static const lessons = Color(0xFF3B7DD8);
  static const puzzles = Color(0xFF8E5BD6);
  static const play = Color(0xFF2E9E6B);
  static const progress = Color(0xFFE9A825);
}

ThemeData buildAppTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.navy,
    onPrimary: Colors.white,
    primaryContainer: AppColors.navyLight,
    onPrimaryContainer: AppColors.navyDark,
    secondary: AppColors.gold,
    onSecondary: AppColors.ink,
    secondaryContainer: AppColors.goldLight,
    onSecondaryContainer: Color(0xFF5C3F00),
    tertiary: AppColors.success,
    onTertiary: Colors.white,
    tertiaryContainer: AppColors.successLight,
    onTertiaryContainer: Color(0xFF0E4D30),
    error: AppColors.error,
    onError: Colors.white,
    errorContainer: AppColors.errorLight,
    onErrorContainer: Color(0xFF6E1B1B),
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.inkMuted,
    outline: AppColors.outline,
    outlineVariant: AppColors.outline,
    surfaceContainerHighest: Color(0xFFF1EDE6),
    surfaceContainerHigh: Color(0xFFF5F2EC),
    surfaceContainer: Color(0xFFF8F5F0),
    surfaceContainerLow: AppColors.cream,
    surfaceContainerLowest: Colors.white,
    inverseSurface: AppColors.ink,
    onInverseSurface: Colors.white,
    inversePrimary: AppColors.navyLight,
    shadow: Colors.black,
    scrim: Colors.black,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  final text = base.textTheme.apply(
    bodyColor: AppColors.ink,
    displayColor: AppColors.ink,
  );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.cream,
    textTheme: text.copyWith(
      headlineMedium: text.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: text.bodyLarge?.copyWith(height: 1.45),
      bodyMedium: text.bodyMedium?.copyWith(
        height: 1.4,
        color: AppColors.inkMuted,
      ),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.cream,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        color: AppColors.ink,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.outline),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        foregroundColor: AppColors.navy,
        side: const BorderSide(color: AppColors.navy, width: 1.5),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.navy),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.navy,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.gold,
      linearTrackColor: AppColors.outline,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.navyLight,
      side: const BorderSide(color: AppColors.outline),
      labelStyle: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink),
      secondaryLabelStyle: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.navyDark),
      checkmarkColor: AppColors.navyDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.outline),
  );
}
