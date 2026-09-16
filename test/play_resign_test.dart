import 'package:chess_academy/core/game_store.dart';
import 'package:chess_academy/core/progress_store.dart';
import 'package:chess_academy/core/settings_store.dart';
import 'package:chess_academy/features/play/play_screen.dart';
import 'package:chess_academy/l10n/app_localizations.dart';
import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Oyun ekranını bir üst sayfanın üstüne açar (geri tuşu denenebilsin).
Future<void> _open(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('tr'),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PlayScreen(level: 1, playerSide: Side.white)),
            ),
            child: const Text('aç'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('aç'));
  await tester.pumpAndSettle();
}

/// Beyaz yönünden tahtada [from] karesinden [to] karesine dokunarak hamle yapar.
Future<void> _move(WidgetTester tester, String from, String to) async {
  final rect = tester.getRect(find.byType(Chessboard));
  final sq = rect.width / 8;
  Offset center(String s) => rect.topLeft +
      Offset((s.codeUnitAt(0) - 97 + 0.5) * sq, (8 - int.parse(s[1]) + 0.5) * sq);
  await tester.tapAt(center(from));
  await tester.pump();
  await tester.tapAt(center(to));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsStore.instance.init();
    await ProgressStore.instance.init();
    await GameStore.instance.init();
  });

  testWidgets('hamle yokken bırakma butonu yok, geri tuşu sormadan çıkar', (tester) async {
    await _open(tester);
    expect(find.byIcon(Icons.flag_outlined), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('aç'), findsOneWidget);
    expect(GameStore.instance.games, isEmpty);
  });

  testWidgets('bırak: vazgeçilirse oyun sürer, onaylanırsa kayıp kaydedilir', (tester) async {
    await _open(tester);
    await _move(tester, 'e2', 'e4');
    expect(find.byIcon(Icons.flag_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.flag_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oynamaya devam et'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
    expect(GameStore.instance.games, isEmpty);

    await tester.tap(find.byIcon(Icons.flag_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Oyunu bırak'));
    await tester.pumpAndSettle();
    expect(find.text('Oyunu bıraktın. Bir dahaki sefere!'), findsOneWidget);
    expect(find.byIcon(Icons.flag_outlined), findsNothing);
    final g = GameStore.instance.games.single;
    expect(g.result, 'loss');
    expect(g.resigned, isTrue);
    expect(ProgressStore.instance.gamesPlayed, 1);
  });

  testWidgets('oyun sürerken geri tuşu onay ister, onaylanınca kayıp kaydedip çıkar', (tester) async {
    final before = GameStore.instance.games.length;
    await _open(tester);
    await _move(tester, 'e2', 'e4');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Oyunu bırakmak istiyor musun?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Oyunu bırak'));
    await tester.pumpAndSettle();
    expect(find.text('aç'), findsOneWidget);
    expect(GameStore.instance.games.length, before + 1);
    expect(GameStore.instance.games.first.resigned, isTrue);
  });

  testWidgets('bilgisayar düşünürken bırakıp yeniden başlayınca eski hamle yeni oyuna işlenmez', (tester) async {
    await _open(tester);
    // Hamleyi yap, bilgisayarın cevabını (350 ms) beklemeden bırak ve yeniden başlat.
    final rect = tester.getRect(find.byType(Chessboard));
    final sq = rect.width / 8;
    await tester.tapAt(rect.topLeft + Offset(4.5 * sq, 6.5 * sq));
    await tester.pump();
    await tester.tapAt(rect.topLeft + Offset(4.5 * sq, 4.5 * sq));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.widgetWithText(FilledButton, 'Oyunu bırak'));
    await tester.pump(const Duration(milliseconds: 20));

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('1.'), findsNothing, reason: 'yeni oyunda hamle olmamalı');
    expect(find.byIcon(Icons.flag_outlined), findsNothing);
    expect(find.text('Sıra sende.'), findsOneWidget);
  });
}
