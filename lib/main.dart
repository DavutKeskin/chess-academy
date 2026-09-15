import 'dart:async';

import 'package:flutter/material.dart';
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
      theme: buildAppTheme(),
      locale: settings.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: settings.onboardingDone ? const HomeScreen() : const OnboardingScreen(),
      ),
    );
  }
}
