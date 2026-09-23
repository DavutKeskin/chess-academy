import 'package:chess_academy/core/game_store.dart';
import 'package:chess_academy/core/progress_store.dart';
import 'package:chess_academy/core/settings_store.dart';
import 'package:chess_academy/core/theme.dart';
import 'package:chess_academy/features/lessons/lesson_list_screen.dart';
import 'package:chess_academy/features/lessons/lesson_screen.dart';
import 'package:chess_academy/features/lessons/lessons.dart';
import 'package:chess_academy/features/onboarding/onboarding_screen.dart';
import 'package:chess_academy/features/paywall/paywall_screen.dart';
import 'package:chess_academy/features/play/lan_lobby_screen.dart';
import 'package:chess_academy/features/play/play_screen.dart';
import 'package:chess_academy/features/progress/progress_screen.dart';
import 'package:chess_academy/features/puzzles/puzzle_list_screen.dart';
import 'package:chess_academy/features/puzzles/puzzle_repository.dart';
import 'package:chess_academy/features/puzzles/puzzle_screen.dart';
import 'package:chess_academy/features/puzzles/puzzles.dart';
import 'package:chess_academy/features/settings/settings_screen.dart';
import 'package:chess_academy/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ekranlar gerçek uygulama temasıyla iPhone ve Android boyutunda yerleşim hatası vermeden çizilmeli.
/// Sürüm derlemesinde yerleşim hatası veren alt ağaç sessizce boş çizilir (iOS'ta ders düğmeleri kaybolmuştu).
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'onboarding_done': true, 'language': 'tr'});
    await SettingsStore.instance.init();
    await ProgressStore.instance.init();
    await GameStore.instance.init();
    await PuzzleRepository.instance.load();
  });

  final t = lookupAppLocalizations(const Locale('tr'));
  final screens = <String, Widget Function()>{
    'lesson': () => LessonScreen(lesson: buildLessons(t).first),
    'lesson list': () => const LessonListScreen(),
    'onboarding': () => const OnboardingScreen(),
    'paywall': () => const PaywallScreen(),
    'progress': () => const ProgressScreen(),
    'settings': () => const SettingsScreen(),
    'play setup': () => const PlaySetupScreen(),
    'lan lobby': () => const LanLobbyScreen(),
    'lan join': () => const LanJoinScreen(),
    'puzzle list': () => const PuzzleListScreen(),
    'puzzle pack': () => PuzzlePackScreen(category: PuzzleRepository.instance.categories.first),
    'puzzle': () => const PuzzleScreen(puzzles: starterPuzzles, index: 0),
    'dialog': () => Builder(
          builder: (context) => Scaffold(
            body: AlertDialog(
              title: const Text('Soru'),
              content: const Text('Metin'),
              actions: [
                TextButton(onPressed: () {}, child: const Text('Hayır')),
                FilledButton(onPressed: () {}, child: const Text('Evet')),
              ],
            ),
          ),
        ),
  };

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final e in screens.entries) {
      testWidgets('${e.key} yerleşim hatasız ($platform)', (tester) async {
        // Görsel dosyaları testte yüklenemez; yalnızca yerleşim/çizim hataları sayılır.
        final errors = <String>[];
        final prev = FlutterError.onError;
        FlutterError.onError = (d) {
          final msg = d.exceptionAsString();
          if (!msg.contains('Unable to load asset')) errors.add(msg.split('\n').first);
        };
        debugDefaultTargetPlatformOverride = platform;
        tester.view.physicalSize = const Size(828, 1792); // iPhone 11
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
          theme: buildAppTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('tr'),
          home: e.value(),
        ));
        await tester.pump(const Duration(seconds: 1));
        // Test çatısı, onError ve platform değişkeninin test bitmeden geri alınmasını ister.
        FlutterError.onError = prev;
        debugDefaultTargetPlatformOverride = null;
        expect(errors, isEmpty, reason: '${e.key}: ${errors.take(2).join(' | ')}');
      });
    }
  }
}
