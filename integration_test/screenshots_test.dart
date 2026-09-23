// Mağaza ekran görüntüleri: uygulamayı gerçek cihaz/simülatörde açar, örnek ilerlemeyle
// ekranları gezer ve her birinin görüntüsünü sürücüye verir (test_driver/integration_test.dart yazar).
//
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/screenshots_test.dart -d <cihaz> --dart-define=SHOT_LANG=tr
//
// Çıktı: build/screenshots/<dil>/NN_ad.png. CI'da iOS simülatöründe dört dil için çalışır (ios.yml).
import 'dart:async';
import 'dart:convert';

import 'package:chess_academy/core/analysis/game_analysis.dart';
import 'package:chess_academy/core/game_store.dart';
import 'package:chess_academy/core/opponent.dart';
import 'package:chess_academy/core/progress_store.dart';
import 'package:chess_academy/core/settings_store.dart';
import 'package:chess_academy/features/home/home_screen.dart';
import 'package:chess_academy/features/lessons/lesson_screen.dart';
import 'package:chess_academy/features/lessons/lessons.dart';
import 'package:chess_academy/features/play/lan_lobby_screen.dart';
import 'package:chess_academy/features/play/play_screen.dart';
import 'package:chess_academy/features/play/replay_screen.dart';
import 'package:chess_academy/features/progress/progress_screen.dart';
import 'package:chess_academy/features/puzzles/puzzle_repository.dart';
import 'package:chess_academy/features/puzzles/puzzle_screen.dart';
import 'package:chess_academy/features/puzzles/puzzles.dart';
import 'package:chess_academy/l10n/app_localizations.dart';
import 'package:chess_academy/main.dart';
import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const lang = String.fromEnvironment('SHOT_LANG', defaultValue: 'tr');

/// Karşı tarafın hamleleri testten verilen rakip; motor beklenmez, ekran "bilgisayar" gibi görünür.
class ScriptedOpponent extends Opponent {
  ScriptedOpponent(this.replies);
  final List<String> replies;
  int _i = 0;

  @override
  Future<void> get ready => Future.value();
  @override
  bool get isRemote => false;
  @override
  Future<Move?> nextMove(Position position, {int? maxTimeMs}) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return _i < replies.length ? Move.parse(replies[_i++]) : null;
  }
}

/// Légal matı: oyuncu (beyaz) 7 hamlede mat eder; analiz verisi elle, gerçekçi değerlerle.
GameRecord sampleAnalyzedGame() {
  const uci = ['e2e4', 'e7e5', 'g1f3', 'd7d6', 'f1c4', 'c8g4', 'b1c3', 'g7g6', 'f3e5', 'g4d1', 'c4f7', 'e8e7', 'c3d5'];
  Position pos = Chess.initial;
  final san = <String>[];
  for (final u in uci) {
    final (next, s) = pos.makeSan(Move.parse(u)!);
    san.add(s);
    pos = next;
  }
  MoveAnalysis m(int ply, int before, int after, MoveQuality q, {int? mate, List<String> pv = const []}) => MoveAnalysis(
        ply: ply,
        playedUci: uci[ply],
        playedSan: san[ply],
        bestUci: q == MoveQuality.best ? uci[ply] : pv.first,
        bestSan: q == MoveQuality.best ? san[ply] : san[ply],
        evalBefore: before,
        evalAfter: after,
        lossCp: (before - after).clamp(0, 9999),
        quality: q,
        opportunity: Opportunity.none,
        bestPv: pv.isEmpty ? [uci[ply]] : pv,
        mateInBefore: mate,
      );
  final analysis = GameAnalysis(
    moves: [
      m(0, 30, 30, MoveQuality.best),
      m(2, 35, 35, MoveQuality.best),
      m(4, 40, 30, MoveQuality.good, pv: ['d2d4', 'g8f6']),
      m(6, 45, 45, MoveQuality.best),
      m(8, 320, 320, MoveQuality.best),
      m(10, 9998, 9998, MoveQuality.best, mate: 2),
      m(12, 9999, 9999, MoveQuality.best, mate: 1),
    ],
    accuracy: 97.4,
  );
  return GameRecord(
    id: 'sample-legal',
    playedAt: DateTime.now().subtract(const Duration(hours: 3)),
    level: 3,
    playerIsWhite: true,
    uciMoves: uci,
    sanMoves: san,
    result: 'win',
    analysis: analysis,
  );
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester, [int ms = 800]) async {
    // Sürekli animasyonlar (bekleme göstergeleri) pumpAndSettle'ı kilitler; sabit süre bekle.
    final end = DateTime.now().add(Duration(milliseconds: ms));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await settle(tester);
    await binding.takeScreenshot('$lang/$name');
  }

  Future<void> push(WidgetTester tester, Widget screen) async {
    final nav = Navigator.of(tester.element(find.byType(HomeScreen)));
    unawaited(nav.push(MaterialPageRoute<void>(builder: (_) => screen)));
    await settle(tester, 1200);
  }

  Future<void> pop(WidgetTester tester) async {
    Navigator.of(tester.element(find.byType(HomeScreen))).pop();
    await settle(tester, 600);
  }

  /// Beyaz yönelimli tahtada kareye dokunur (dokunarak hamle: önce taş, sonra hedef).
  Future<void> tapSquare(WidgetTester tester, String sq) async {
    final rect = tester.getRect(find.byType(Chessboard));
    final s = rect.width / 8;
    final file = sq.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = int.parse(sq[1]);
    await tester.tapAt(Offset(rect.left + (file + 0.5) * s, rect.top + (8 - rank + 0.5) * s));
    await settle(tester, 250);
  }

  testWidgets('mağaza ekran görüntüleri ($lang)', (tester) async {
    final t = lookupAppLocalizations(Locale(lang));
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await prefs.setBool('onboarding_done', true);
    await prefs.setString('language', lang);
    await prefs.setString('profile_level', 'plays');
    // Örnek ilerleme: dolu ama tamamlanmamış görünsün.
    final lessonIds = buildLessons(t).map((l) => l.id).take(6).toList();
    await prefs.setStringList('lessons_done', lessonIds);
    await prefs.setInt('streak_count', 5);
    final now = DateTime.now();
    await prefs.setString('streak_last_day',
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}');
    await prefs.setInt('games_played', 9);
    await prefs.setInt('games_won', 5);
    final game = sampleAnalyzedGame();
    await prefs.setString('recent_games', jsonEncode([game.toJson()]));

    await ProgressStore.instance.init();
    await GameStore.instance.init();
    await SettingsStore.instance.init();
    await PuzzleRepository.instance.load();
    final mate1 = PuzzleRepository.instance.categories.firstWhere((c) => c.id != 'starter').puzzles;
    await prefs.setStringList('puzzles_solved', [
      for (final p in starterPuzzles) p.id,
      for (final p in mate1.take(23)) p.id,
    ]);
    await SettingsStore.instance.preloadPieceImages();

    await tester.pumpWidget(const SatrancAkademiApp());
    await settle(tester, 1500);
    await shot(tester, '01_home');

    // Ders: Kale, görev adımı (ok ve hedef kare).
    final lessons = buildLessons(t);
    await push(tester, LessonScreen(lesson: lessons[1]));
    await tester.tap(find.text(t.continueBtn));
    await settle(tester, 600);
    await shot(tester, '02_lesson');
    await pop(tester);

    // Bilgisayara karşı oyun ortası (İtalyan açılışı), rakip hamleleri betikten.
    const white = ['e2e4', 'g1f3', 'f1c4', 'c2c3', 'd2d4', 'c3d4', 'b1c3'];
    const black = ['e7e5', 'b8c6', 'f8c5', 'g8f6', 'e5d4', 'c5b4', 'f6e4'];
    await push(tester, PlayScreen(level: 3, playerSide: Side.white, opponent: ScriptedOpponent(black)));
    for (final mv in white) {
      await tapSquare(tester, mv.substring(0, 2));
      await tapSquare(tester, mv.substring(2, 4));
      await settle(tester, 900); // rakip cevabı ve animasyon
    }
    await shot(tester, '03_play');
    // Bırakma onayı çıkmasın diye ekranı doğrudan kapat.
    Navigator.of(tester.element(find.byType(PlayScreen))).pop();
    await settle(tester, 600);

    // Analiz: 5.Nxe5 sonrası (ok, değerlendirme çubuğu, hamle listesi).
    await push(tester, ReplayScreen(game: game));
    for (var i = 0; i < 9; i++) {
      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await settle(tester, 150);
    }
    await shot(tester, '04_analysis');
    await pop(tester);

    // Bulmaca: Çoban matı konumu.
    await push(tester, const PuzzleScreen(puzzles: starterPuzzles, index: 1));
    await shot(tester, '05_puzzle');
    await pop(tester);

    // Arkadaşla oyna: oda kurma (emoji kartı).
    await push(tester, const LanHostScreen());
    await settle(tester, 2500);
    await shot(tester, '06_lan');
    await pop(tester);

    await push(tester, const ProgressScreen());
    await shot(tester, '07_progress');
    await pop(tester);

    await push(tester, const PlaySetupScreen());
    await shot(tester, '08_setup');
    await pop(tester);
  });
}
