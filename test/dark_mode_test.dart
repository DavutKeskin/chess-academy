import 'package:chess_academy/core/game_store.dart';
import 'package:chess_academy/core/progress_store.dart';
import 'package:chess_academy/core/settings_store.dart';
import 'package:chess_academy/core/theme.dart';
import 'package:chess_academy/features/puzzles/puzzle_repository.dart';
import 'package:chess_academy/features/settings/settings_screen.dart';
import 'package:chess_academy/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'onboarding_done': true, 'language': 'tr'});
    await SettingsStore.instance.init();
    await ProgressStore.instance.init();
    await GameStore.instance.init();
    await PuzzleRepository.instance.load();
  });

  Color scaffoldColor(WidgetTester tester) =>
      tester.widget<Scaffold>(find.byType(Scaffold).last).backgroundColor ??
      Theme.of(tester.element(find.byType(Scaffold).last)).scaffoldBackgroundColor;

  testWidgets('tema ayarı değişince açık sayfalar da yeni paletle çizilir', (tester) async {
    await tester.pumpWidget(const SatrancAkademiApp());
    await tester.pumpAndSettle();
    expect(AppColors.palette, same(AppPalette.light));
    expect(scaffoldColor(tester), AppPalette.light.cream);

    // Ayarlar açıkken koyu temaya geç: alttaki ana sayfa da güncellenmeli.
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    await SettingsStore.instance.setThemeMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    expect(AppColors.palette, same(AppPalette.dark));
    expect(scaffoldColor(tester), AppPalette.dark.cream);

    // Paleti doğrudan okuyan kart (bugünün dersi) koyu tonda.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate((w) => w is Material && w.color == AppPalette.dark.hero),
      findsOneWidget,
    );

    await SettingsStore.instance.setThemeMode(ThemeMode.light);
    await tester.pumpAndSettle();
    expect(AppColors.palette, same(AppPalette.light));
    expect(
      find.byWidgetPredicate((w) => w is Material && w.color == AppPalette.light.hero),
      findsOneWidget,
    );
  });
}
