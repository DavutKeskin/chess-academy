import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Satranç Akademi tasarım dili.
///
/// Renk kararları:
/// - Lacivert (primary): akademi, güven, odak. Çocuk uygulamalarında sık görülen
///   bağıran renkler yerine "okul" hissi veren koyu bir temel.
/// - Altın (accent): başarı, rozet, vurgu. Yalnızca kutlama ve ikincil vurguda kullanılır,
///   böylece anlamı sulanmaz.
/// - Krem yüzey: beyaz yerine sıcak bir zemin; tahta ile çatışmaz, göz yormaz.
/// - Durum renkleri (başarı/hata/bilgi) yalnızca geri bildirimde kullanılır.
/// - Koyu tema: aynı roller koyu gri-lacivert zeminde; vurgular açılır, kaplar koyulaşır.
/// Renk paleti; açık ve koyu tema aynı adları taşır.
class AppPalette {
  const AppPalette({
    required this.navy,
    required this.navyDark,
    required this.navyLight,
    required this.hero,
    required this.gold,
    required this.goldLight,
    required this.goldInk,
    required this.goldOnLight,
    required this.cream,
    required this.surface,
    required this.outline,
    required this.surfaceContainer,
    required this.ink,
    required this.inkMuted,
    required this.success,
    required this.successLight,
    required this.successInk,
    required this.error,
    required this.errorLight,
    required this.errorInk,
    required this.info,
    required this.lessons,
    required this.puzzles,
    required this.puzzlesStrong,
    required this.puzzlesInk,
    required this.heroAccent,
    required this.play,
    required this.progress,
  });

  /// Lacivert vurgu: ikon, kenarlık, metin düğmesi.
  final Color navy;
  /// navyLight zemin üstündeki metin.
  final Color navyDark;
  /// Seçili/bilgi kabı zemini.
  final Color navyLight;
  /// Beyaz yazılı koyu lacivert kart zemini (her iki temada koyu).
  final Color hero;
  final Color gold;
  /// Altın kap zemini.
  final Color goldLight;
  /// Altın kap üstündeki ikon.
  final Color goldInk;
  /// Altın kap üstündeki metin.
  final Color goldOnLight;
  /// Sayfa zemini.
  final Color cream;
  final Color surface;
  final Color outline;
  final Color surfaceContainer;
  final Color ink;
  final Color inkMuted;
  final Color success;
  final Color successLight;
  /// successLight üstündeki metin.
  final Color successInk;
  final Color error;
  final Color errorLight;
  /// errorLight üstündeki metin.
  final Color errorInk;
  final Color info;
  final Color lessons;
  final Color puzzles;
  /// Beyaz yazılı mor kart zemini.
  final Color puzzlesStrong;

  /// Açık mor zemin (etiket) üstündeki mor metin.
  final Color puzzlesInk;

  /// hero zemin üstündeki altın etiket.
  final Color heroAccent;
  final Color play;
  final Color progress;

  static const light = AppPalette(
    navy: Color(0xFF1F3A5F),
    navyDark: Color(0xFF14273F),
    navyLight: Color(0xFFDCE6F5),
    hero: Color(0xFF1F3A5F),
    gold: Color(0xFFE9A825),
    goldLight: Color(0xFFFFF0C9),
    goldInk: Color(0xFFB7791F),
    goldOnLight: Color(0xFF5C3F00),
    cream: Color(0xFFFBF8F3),
    surface: Color(0xFFFFFFFF),
    outline: Color(0xFFE6E1D8),
    surfaceContainer: Color(0xFFF1EDE6),
    ink: Color(0xFF1B1F2A),
    inkMuted: Color(0xFF626B7A),
    success: Color(0xFF2E9E6B),
    successLight: Color(0xFFDFF4EA),
    successInk: Color(0xFF0E4D30),
    error: Color(0xFFD64545),
    errorLight: Color(0xFFFBE3E3),
    errorInk: Color(0xFF6E1B1B),
    info: Color(0xFF3B7DD8),
    lessons: Color(0xFF3B7DD8),
    puzzles: Color(0xFF8E5BD6),
    puzzlesStrong: Color(0xFF8E5BD6),
    puzzlesInk: Color(0xFF6A3FB5),
    heroAccent: Color(0xFFE9A825),
    play: Color(0xFF2E9E6B),
    progress: Color(0xFFE9A825),
  );

  static const dark = AppPalette(
    navy: Color(0xFF8FB3E8),
    navyDark: Color(0xFFDCE6F5),
    navyLight: Color(0xFF243A57),
    hero: Color(0xFF2A4A75),
    gold: Color(0xFFE9A825),
    goldLight: Color(0xFF3A2F17),
    goldInk: Color(0xFFE9B949),
    goldOnLight: Color(0xFFFFE3A3),
    cream: Color(0xFF14171D),
    surface: Color(0xFF1E222A),
    outline: Color(0xFF363C47),
    surfaceContainer: Color(0xFF2A2F38),
    ink: Color(0xFFE8EAF0),
    inkMuted: Color(0xFFA0A8B6),
    success: Color(0xFF4CC38A),
    successLight: Color(0xFF1B3A2C),
    successInk: Color(0xFFBFEBD5),
    error: Color(0xFFEF6B6B),
    errorLight: Color(0xFF402326),
    errorInk: Color(0xFFF6C9C9),
    info: Color(0xFF6FA3EC),
    lessons: Color(0xFF6FA3EC),
    puzzles: Color(0xFFB08BEA),
    puzzlesStrong: Color(0xFF6A3FB5),
    puzzlesInk: Color(0xFFB08BEA),
    heroAccent: Color(0xFFF2C75C),
    play: Color(0xFF4CC38A),
    progress: Color(0xFFE9A825),
  );
}

/// Ekranların kullandığı renkler; etkin temanın paletinden okunur.
/// Tema değişince [SatrancAkademiApp] paleti değiştirip ağacı yeniden çizer.
abstract final class AppColors {
  static AppPalette _p = AppPalette.light;

  static AppPalette get palette => _p;
  static void use(Brightness brightness) =>
      _p = brightness == Brightness.dark ? AppPalette.dark : AppPalette.light;

  static Color get navy => _p.navy;
  static Color get navyDark => _p.navyDark;
  static Color get navyLight => _p.navyLight;
  static Color get hero => _p.hero;
  static Color get gold => _p.gold;
  static Color get goldLight => _p.goldLight;
  static Color get goldInk => _p.goldInk;
  static Color get goldOnLight => _p.goldOnLight;
  static Color get cream => _p.cream;
  static Color get surface => _p.surface;
  static Color get outline => _p.outline;
  static Color get surfaceContainer => _p.surfaceContainer;
  static Color get ink => _p.ink;
  static Color get inkMuted => _p.inkMuted;
  static Color get success => _p.success;
  static Color get successLight => _p.successLight;
  static Color get successInk => _p.successInk;
  static Color get error => _p.error;
  static Color get errorLight => _p.errorLight;
  static Color get errorInk => _p.errorInk;
  static Color get info => _p.info;

  /// Modül kimlik renkleri: her bölümün kendi tonu var, ikon ve etiketlerde tutarlı kullanılır.
  static Color get lessons => _p.lessons;
  static Color get puzzles => _p.puzzles;
  static Color get puzzlesStrong => _p.puzzlesStrong;
  static Color get puzzlesInk => _p.puzzlesInk;
  static Color get heroAccent => _p.heroAccent;
  static Color get play => _p.play;
  static Color get progress => _p.progress;
}

ThemeData buildAppTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? AppPalette.dark : AppPalette.light;
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.navy,
    onPrimary: dark ? const Color(0xFF0E1B2C) : Colors.white,
    primaryContainer: c.navyLight,
    onPrimaryContainer: c.navyDark,
    secondary: c.gold,
    onSecondary: c.ink,
    secondaryContainer: c.goldLight,
    onSecondaryContainer: c.goldOnLight,
    tertiary: c.success,
    onTertiary: Colors.white,
    tertiaryContainer: c.successLight,
    onTertiaryContainer: c.successInk,
    error: c.error,
    onError: dark ? const Color(0xFF2A0D0D) : Colors.white,
    errorContainer: c.errorLight,
    onErrorContainer: c.errorInk,
    surface: c.surface,
    onSurface: c.ink,
    onSurfaceVariant: c.inkMuted,
    outline: c.outline,
    outlineVariant: c.outline,
    surfaceContainerHighest: c.surfaceContainer,
    surfaceContainerHigh: dark ? const Color(0xFF252A32) : const Color(0xFFF5F2EC),
    surfaceContainer: dark ? const Color(0xFF21252D) : const Color(0xFFF8F5F0),
    surfaceContainerLow: c.cream,
    surfaceContainerLowest: dark ? const Color(0xFF101318) : Colors.white,
    inverseSurface: c.ink,
    onInverseSurface: c.cream,
    inversePrimary: c.navyLight,
    shadow: Colors.black,
    scrim: Colors.black,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  final text = base.textTheme.apply(
    bodyColor: c.ink,
    displayColor: c.ink,
  );

  return base.copyWith(
    scaffoldBackgroundColor: c.cream,
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
        color: c.inkMuted,
      ),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: c.cream,
      foregroundColor: c.ink,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        color: c.ink,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: c.surface,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: c.outline),
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
        foregroundColor: c.navy,
        side: BorderSide(color: c.navy, width: 1.5),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: c.navy),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: c.navy,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.gold,
      linearTrackColor: c.outline,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.surface,
      selectedColor: c.navyLight,
      side: BorderSide(color: c.outline),
      labelStyle: TextStyle(fontWeight: FontWeight.w600, color: c.ink),
      secondaryLabelStyle: TextStyle(fontWeight: FontWeight.w700, color: c.navyDark),
      checkmarkColor: c.navyDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: DividerThemeData(color: c.outline),
  );
}
