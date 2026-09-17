import 'dart:async';

import 'package:chess_academy/core/game_store.dart';
import 'package:chess_academy/core/opponent.dart';
import 'package:chess_academy/core/progress_store.dart';
import 'package:chess_academy/core/settings_store.dart';
import 'package:chess_academy/features/play/play_screen.dart';
import 'package:chess_academy/l10n/app_localizations.dart';
import 'package:chess_academy/l10n/app_localizations_tr.dart';
import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ağdaki arkadaşı taklit eden rakip: hamleler testten verilir, olaylar testten tetiklenir.
class FakeRemoteOpponent extends Opponent {
  final _events = StreamController<OpponentEvent>.broadcast();
  final List<(Move, int)> localMoves = [];
  Completer<Move?>? pending;
  bool resigned = false;
  bool disposed = false;

  @override
  Future<void> get ready => Future.value();

  @override
  bool get isRemote => true;

  @override
  Stream<OpponentEvent> get events => _events.stream;

  @override
  Future<Move?> nextMove(Position position, {int? maxTimeMs}) {
    pending = Completer<Move?>();
    return pending!.future;
  }

  /// Karşıdan hamle geldi.
  void deliver(String uci) {
    final p = pending!;
    pending = null;
    p.complete(Move.parse(uci));
  }

  void emit(OpponentEvent e) => _events.add(e);

  @override
  void onLocalMove(Move move, int ply) => localMoves.add((move, ply));

  @override
  void resign() => resigned = true;

  @override
  Future<void> dispose() async {
    disposed = true;
    await _events.close();
  }
}

Future<void> _open(WidgetTester tester, FakeRemoteOpponent opp, {Side side = Side.black}) async {
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('tr'),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => PlayScreen.remote(opponent: opp, playerSide: side)),
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

/// Oyuncunun yönünden ([side]) tahtada dokunarak hamle yapar.
Future<void> _move(WidgetTester tester, String from, String to, {Side side = Side.black}) async {
  final rect = tester.getRect(find.byType(Chessboard));
  final sq = rect.width / 8;
  Offset center(String s) {
    final file = s.codeUnitAt(0) - 97;
    final rank = int.parse(s[1]);
    final (x, y) = side == Side.white ? (file, 8 - rank) : (7 - file, rank - 1);
    return rect.topLeft + Offset((x + 0.5) * sq, (y + 0.5) * sq);
  }

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

  testWidgets('arkadaşın hamlesi gelince tahta ve hamle listesi güncellenir; kendi hamlem rakibe iletilir',
      (tester) async {
    final opp = FakeRemoteOpponent();
    await _open(tester, opp);
    expect(find.text('Arkadaşla oyna'), findsOneWidget);
    expect(find.text('Arkadaşın'), findsOneWidget);
    expect(find.text('Arkadaşın düşünüyor…'), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsNothing, reason: 'Wi‑Fi oyununda yeniden başlatma yok');

    opp.deliver('e2e4');
    await tester.pumpAndSettle();
    expect(find.text('1. e4'), findsOneWidget);
    expect(find.text('Sıra sende.'), findsOneWidget);

    await _move(tester, 'e7', 'e5');
    expect(opp.localMoves.single.$1.uci, 'e7e5');
    expect(opp.localMoves.single.$2, 1);
    expect(find.text('e5'), findsOneWidget);
    expect(find.text('Arkadaşın düşünüyor…'), findsOneWidget);
  });

  testWidgets('bırakınca rakibe resign gider, kayıp seviye 0 ile kaydedilir, ilerleme sayılmaz', (tester) async {
    final opp = FakeRemoteOpponent();
    await _open(tester, opp);
    opp.deliver('e2e4');
    await tester.pumpAndSettle();
    await _move(tester, 'e7', 'e5');

    await tester.tap(find.byIcon(Icons.flag_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Oyunu bırak'));
    await tester.pumpAndSettle();
    expect(opp.resigned, isTrue);
    expect(find.text('Oyunu bıraktın. Bir dahaki sefere!'), findsOneWidget);
    expect(find.text('Yeni oyun'), findsOneWidget);
    expect(find.text('Tekrar Oyna'), findsNothing);

    final g = GameStore.instance.games.single;
    expect(g.level, 0);
    expect(g.isVsFriend, isTrue);
    expect(g.result, 'loss');
    expect(g.resigned, isTrue);
    expect(g.uciMoves, ['e2e4', 'e7e5']);
    expect(ProgressStore.instance.gamesPlayed, 0, reason: 'arkadaşla oyun istatistiğe girmez');

    // Oyun bittikten sonra gelen eski hamle yok sayılır.
    opp.deliver('g1f3');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Nf3'), findsNothing);
    expect(GameStore.instance.games.length, 1);
  });

  testWidgets('arkadaş bırakınca kazanılır; mat olunca sonuç kaydedilir', (tester) async {
    final opp = FakeRemoteOpponent();
    await _open(tester, opp);
    opp.deliver('e2e4');
    await tester.pumpAndSettle();
    await _move(tester, 'e7', 'e5');
    opp.emit(const OpponentResigned());
    await tester.pumpAndSettle();
    expect(find.text('Arkadaşın oyunu bıraktı. Kazandın! 🎉'), findsOneWidget);
    final g = GameStore.instance.games.single;
    expect(g.result, 'win');
    expect(g.resigned, isTrue);
    expect(ProgressStore.instance.gamesPlayed, 0);
  });

  testWidgets('bağlantı kopunca oyun berabere biter ve bağlantı koptu olarak kaydedilir', (tester) async {
    final opp = FakeRemoteOpponent();
    await _open(tester, opp);
    opp.deliver('e2e4');
    await tester.pumpAndSettle();
    await _move(tester, 'e7', 'e5');
    opp.emit(const OpponentDisconnected('closed'));
    await tester.pumpAndSettle();
    expect(find.text('Bağlantı koptu. Oyun sona erdi.'), findsOneWidget);
    expect(find.byIcon(Icons.flag_outlined), findsNothing);
    final g = GameStore.instance.games.single;
    expect(g.result, 'draw');
    expect(g.disconnected, isTrue);
    expect(resultLabel(AppLocalizationsTr(), g), 'Berabere (bağlantı koptu)');
    expect(gameSummaryLabel(AppLocalizationsTr(), g), 'Arkadaş (Wi‑Fi) · Berabere (bağlantı koptu)');
  });

  testWidgets('hiç hamle yokken kopan bağlantı kayda girmez', (tester) async {
    final opp = FakeRemoteOpponent();
    await _open(tester, opp);
    opp.emit(const OpponentDisconnected('timeout'));
    await tester.pumpAndSettle();
    expect(find.text('Bağlantı koptu. Oyun sona erdi.'), findsOneWidget);
    expect(GameStore.instance.games, isEmpty);
  });

  testWidgets('oyun sürerken geri tuşu onay ister; onaylanınca resign gönderilip çıkılır', (tester) async {
    final opp = FakeRemoteOpponent();
    await _open(tester, opp, side: Side.white);
    await _move(tester, 'e2', 'e4', side: Side.white);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Oyunu bırakmak istiyor musun?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Oyunu bırak'));
    await tester.pumpAndSettle();
    expect(find.text('aç'), findsOneWidget);
    expect(opp.resigned, isTrue);
    expect(opp.disposed, isTrue);
    expect(GameStore.instance.games.single.result, 'loss');
  });
}
