import 'package:chess_academy/core/settings_store.dart';
import 'package:chess_academy/features/lessons/lesson_screen.dart';
import 'package:chess_academy/features/lessons/lessons.dart';
import 'package:chess_academy/l10n/app_localizations.dart';
import 'package:chessground/chessground.dart';
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

  testWidgets('çözülmüş göreve geri dönünce başarı mesajı ve Devam açık', (tester) async {
    final t = lookupAppLocalizations(const Locale('tr'));
    final lesson = buildLessons(t).firstWhere((l) => l.id == 'knight');
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('tr'),
      home: LessonScreen(lesson: lesson),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.continueBtn));
    await tester.pumpAndSettle();

    // Adım 2: atı b1'den c3'e oyna.
    final rect = tester.getRect(find.byType(Chessboard));
    final sq = rect.width / 8;
    await tester.tapAt(rect.topLeft + Offset(1.5 * sq, 7.5 * sq));
    await tester.pump();
    await tester.tapAt(rect.topLeft + Offset(2.5 * sq, 5.5 * sq));
    await tester.pumpAndSettle();
    final success = lesson.steps[1].task!.success;
    expect(find.text(success), findsOneWidget);

    await tester.tap(find.text(t.continueBtn));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.backBtn));
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
    expect(find.text(success), findsOneWidget);
    final cont = tester.widget<FilledButton>(find.ancestor(of: find.text(t.continueBtn), matching: find.byWidgetPredicate((w) => w is FilledButton)));
    expect(cont.onPressed, isNotNull);
  });
}
