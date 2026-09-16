import 'package:chess_academy/core/settings_store.dart';
import 'package:chess_academy/features/lessons/lesson_screen.dart';
import 'package:chess_academy/features/lessons/lessons.dart';
import 'package:chess_academy/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsStore.instance.init();
  });

  for (final lang in ['tr', 'de']) {
    testWidgets('derste geri ve ileri adım ($lang, dar ekran)', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final t = lookupAppLocalizations(Locale(lang));
      // İlk adımı açıklama (görevsiz) olan ilk ders.
      final lesson = buildLessons(t).firstWhere((l) => l.steps.length > 1 && l.steps.first.task == null);
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale(lang),
        home: LessonScreen(lesson: lesson),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      OutlinedButton back() => tester.widget(find.widgetWithText(OutlinedButton, t.backBtn));
      expect(back().onPressed, isNull);
      expect(find.text('1'), findsOneWidget);

      await tester.tap(find.text(t.continueBtn));
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);
      expect(back().onPressed, isNotNull);

      await tester.tap(find.text(t.backBtn));
      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);
      expect(find.text(lesson.steps.first.text), findsOneWidget);
    });
  }
}
