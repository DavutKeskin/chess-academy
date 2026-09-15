import 'package:chess_academy/core/analysis/game_analysis.dart';
import 'package:chess_academy/core/engine/engine_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hamle niteliği eşikleri', () {
    expect(MoveQuality.fromLoss(0, isBest: true), MoveQuality.best);
    expect(MoveQuality.fromLoss(20, isBest: false), MoveQuality.good);
    expect(MoveQuality.fromLoss(60, isBest: false), MoveQuality.inaccuracy);
    expect(MoveQuality.fromLoss(150, isBest: false), MoveQuality.mistake);
    expect(MoveQuality.fromLoss(400, isBest: false), MoveQuality.blunder);
  });

  test('kazanma yüzdesi ve doğruluk formülleri', () {
    expect(winPercent(0), closeTo(50, 0.01));
    expect(winPercent(300), greaterThan(70));
    expect(winPercent(-300), lessThan(30));
    expect(moveAccuracy(60, 60), closeTo(100, 0.5));
    expect(moveAccuracy(80, 40), lessThan(40));
    expect(moveAccuracy(40, 80), closeTo(100, 0.5)); // kazanç kayıp sayılmaz
  });

  test('motor çıktısı ayrıştırma: cp, mat ve pv', () {
    final r = EngineService.parseForTest([
      'info depth 10 seldepth 14 multipv 1 score cp 35 nodes 1000 pv e2e4 e7e5 g1f3',
      'info depth 12 seldepth 16 multipv 1 score mate 3 nodes 5000 pv d1h5 g7g6 h5e5',
      'bestmove d1h5 ponder g7g6',
    ]);
    expect(r.bestMove, 'd1h5');
    expect(r.mate, 3);
    expect(r.pv.first, 'd1h5');
    expect(r.score, 10000 - 3);
    expect(r.depth, 12);
  });

  test('önemli anlar: kaçırılan mat en başa, sonra en büyük kayıp', () {
    MoveAnalysis m(int ply, int loss, MoveQuality q, Opportunity o) => MoveAnalysis(
          ply: ply, playedUci: 'a1a2', playedSan: 'Ra2', bestUci: 'a1a8', bestSan: 'Ra8',
          evalBefore: 0, evalAfter: -loss, lossCp: loss, quality: q, opportunity: o, bestPv: const [],
        );
    final a = GameAnalysis(moves: [
      m(0, 60, MoveQuality.inaccuracy, Opportunity.none),
      m(2, 900, MoveQuality.blunder, Opportunity.big),
      m(4, 350, MoveQuality.blunder, Opportunity.mate),
      m(6, 10, MoveQuality.good, Opportunity.none),
    ], accuracy: 70);
    final k = a.keyMoments;
    expect(k.map((x) => x.ply), [4, 2, 0]);
    expect(a.count(MoveQuality.blunder), 2);
  });
}
