import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

import 'core/feedback.dart';
import 'core/game_store.dart';
import 'core/progress_store.dart';
import 'core/purchase_store.dart';
import 'core/settings_store.dart';
import 'core/theme.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'l10n/l10n.dart';
import 'features/puzzles/puzzle_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Stockfish paketi hatalarını `logging` ile bildirir; konsola aktar.
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen(
    (r) => debugPrint('[${r.loggerName}] ${r.level.name}: ${r.message}'),
  );
  await ProgressStore.instance.init();
  await GameStore.instance.init();
  await SettingsStore.instance.init();
  await PuzzleRepository.instance.load();
  await AppFeedback.instance.init();
  // Mağaza sorgusu ağa bağlı; açılışı bekletmesin.
  unawaited(PurchaseStore.instance.init());
  // Taş görsellerini önceden yükle; ilk tahtada taşlar boş görünmesin.
  await SettingsStore.instance.preloadPieceImages();
  runApp(const SatrancAkademiApp());
}

class SatrancAkademiApp extends StatelessWidget {
  const SatrancAkademiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsStore.instance;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
      onGenerateTitle: (context) => context.t.appName,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: settings.themeMode,
      // Palet tema animasyonunun ortasında değişirdi; geçiş anlık olsun, renkler tutarlı kalsın.
      themeAnimationDuration: Duration.zero,
      // Ekranlar AppColors'ı doğrudan okur: etkin temanın paletini seç, değişince ağacı yeniden çiz.
      builder: (context, child) => _PaletteScope(brightness: Theme.of(context).brightness, child: child!),
      locale: settings.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: settings.onboardingDone ? const HomeScreen() : const OnboardingScreen(),
      ),
    );
  }
}

class _PaletteScope extends StatefulWidget {
  const _PaletteScope({required this.brightness, required this.child});
  final Brightness brightness;
  final Widget child;

  @override
  State<_PaletteScope> createState() => _PaletteScopeState();
}

class _PaletteScopeState extends State<_PaletteScope> {
  @override
  void initState() {
    super.initState();
    AppColors.use(widget.brightness);
  }

  @override
  void didUpdateWidget(_PaletteScope old) {
    super.didUpdateWidget(old);
    if (old.brightness == widget.brightness) return;
    AppColors.use(widget.brightness);
    // const olmayan ama paleti okuyan tüm alt widget'lar (açık sayfalar dahil) yeni renkle çizilsin.
    void rebuild(Element e) {
      e.markNeedsBuild();
      e.visitChildren(rebuild);
    }
    (context as Element).visitChildren(rebuild);
  }

  @override
  // AppBar'sız sayfalarda (ana sayfa, ilk açılış) durum çubuğu ikonları da temaya uysun.
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: widget.brightness == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: widget.child,
      );
}
