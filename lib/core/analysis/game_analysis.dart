import 'dart:math';

import 'package:dartchess/dartchess.dart';

import '../engine/engine_service.dart';
import '../game_store.dart';

/// Oyuncu hamlesinin niteliği; eşikler lichess'e yakın (santipiyon kaybı).
enum MoveQuality {
  best,
  good,
  inaccuracy,
  mistake,
  blunder;

  static MoveQuality fromLoss(int lossCp, {required bool isBest}) {
    if (isBest) return MoveQuality.best;
    if (lossCp >= 300) return MoveQuality.blunder;
    if (lossCp >= 100) return MoveQuality.mistake;
    if (lossCp >= 50) return MoveQuality.inaccuracy;
    return MoveQuality.good;
  }
}

/// Kaçırılan fırsat türü: en iyi hamlenin sağlayacağı şey.
enum Opportunity { none, mate, material, big }

/// Oyuncunun tek bir hamlesinin analizi. Skorlar oyuncunun gözünden, santipiyon.
class MoveAnalysis {
  const MoveAnalysis({
    required this.ply,
    required this.playedUci,
    required this.playedSan,
    required this.bestUci,
    required this.bestSan,
    required this.evalBefore,
    required this.evalAfter,
    required this.lossCp,
    required this.quality,
    required this.opportunity,
    required this.bestPv,
    this.mateInBefore,
  });

  /// Oyundaki yarım hamle sırası (0 tabanlı): hamle, kayıttaki [ply] indeksli hamledir.
  final int ply;
  final String playedUci;
  final String playedSan;
  final String bestUci;
  final String bestSan;

  /// En iyi hamleyle ulaşılacak değerlendirme (oyuncu gözünden).
  final int evalBefore;

  /// Oynanan hamleden sonraki değerlendirme (oyuncu gözünden).
  final int evalAfter;
  final int lossCp;
  final MoveQuality quality;
  final Opportunity opportunity;

  /// En iyi hamleden başlayan ana varyant (UCI), simülasyon için.
  final List<String> bestPv;

  /// En iyi hamleyle kaç hamlede mat vardı (varsa).
  final int? mateInBefore;

  Map<String, Object?> toJson() => {
        'ply': ply,
        'played': playedUci,
        'playedSan': playedSan,
        'best': bestUci,
        'bestSan': bestSan,
        'before': evalBefore,
        'after': evalAfter,
        'loss': lossCp,
        'q': quality.name,
        'opp': opportunity.name,
        'pv': bestPv,
        'mate': mateInBefore,
      };

  factory MoveAnalysis.fromJson(Map<String, dynamic> j) => MoveAnalysis(
        ply: j['ply'] as int,
        playedUci: j['played'] as String,
        playedSan: j['playedSan'] as String,
        bestUci: j['best'] as String,
        bestSan: j['bestSan'] as String,
        evalBefore: j['before'] as int,
        evalAfter: j['after'] as int,
        lossCp: j['loss'] as int,
        quality: MoveQuality.values.byName(j['q'] as String),
        opportunity: Opportunity.values.byName(j['opp'] as String),
        bestPv: (j['pv'] as List).cast<String>(),
        mateInBefore: j['mate'] as int?,
      );
}

/// Bütün oyunun analizi.
class GameAnalysis {
  const GameAnalysis({required this.moves, required this.accuracy});

  final List<MoveAnalysis> moves;

  /// 0-100, lichess'in kazanma-yüzdesi tabanlı doğruluk formülüne yakın.
  final double accuracy;

  int count(MoveQuality q) => moves.where((m) => m.quality == q).length;

  /// Ders çıkarılacak en önemli anlar: en büyük kayıplar, kaçırılan matlar başa.
  List<MoveAnalysis> get keyMoments {
    final sorted = [...moves.where((m) => m.quality.index >= MoveQuality.inaccuracy.index)]
      ..sort((a, b) {
        final ma = a.opportunity == Opportunity.mate ? 1 : 0;
        final mb = b.opportunity == Opportunity.mate ? 1 : 0;
        if (ma != mb) return mb - ma;
        return b.lossCp.compareTo(a.lossCp);
      });
    return sorted.take(3).toList();
  }

  Map<String, Object?> toJson() => {'moves': [for (final m in moves) m.toJson()], 'accuracy': accuracy};

  factory GameAnalysis.fromJson(Map<String, dynamic> j) => GameAnalysis(
        moves: [for (final m in j['moves'] as List) MoveAnalysis.fromJson(m as Map<String, dynamic>)],
        accuracy: (j['accuracy'] as num).toDouble(),
      );
}

/// Santipiyon -> kazanma yüzdesi (lichess formülü).
double winPercent(int cp) => 50 + 50 * (2 / (1 + exp(-0.00368208 * cp)) - 1);

/// Tek hamle doğruluğu (lichess formülü), 0-100.
double moveAccuracy(double winBefore, double winAfter) {
  final drop = (winBefore - winAfter).clamp(0.0, 100.0);
  return (103.1668 * exp(-0.04354 * drop) - 3.1669).clamp(0.0, 100.0);
}

/// Oyunu oyuncunun hamleleri üzerinden analiz eder.
class GameAnalyzer {
  GameAnalyzer({this.movetimeMs = 350});

  final int movetimeMs;

  /// [onProgress]: 0..1. Cihazda motor yoksa hata fırlatır.
  Future<GameAnalysis> analyse(GameRecord game, {void Function(double)? onProgress}) async {
    final engine = EngineService.instance;
    final positions = <Position>[Chess.initial];
    final moves = <Move>[];
    for (final u in game.uciMoves) {
      final m = NormalMove.fromUci(u);
      moves.add(m);
      positions.add(positions.last.playUnchecked(m));
    }
    final playerSide = game.playerIsWhite ? Side.white : Side.black;
    final playerPlies = [for (var i = 0; i < moves.length; i++) if (positions[i].turn == playerSide) i];

    // Her konum için motor sonucu (sıradaki taraf gözünden). Oyuncu hamlesinden
    // önceki ve sonraki konumlar gerekir; bitmiş konumlar motora gitmez.
    final cache = <int, EngineResult?>{};
    Future<EngineResult?> evalAt(int idx) async {
      if (cache.containsKey(idx)) return cache[idx];
      final pos = positions[idx];
      EngineResult? r;
      if (!pos.isGameOver) {
        r = await engine.analyse(pos.fen, movetimeMs: movetimeMs, skill: 20);
      }
      cache[idx] = r;
      return r;
    }

    // Bitmiş konumun skoru: mat ise kaybeden için -10000, pat/berabere 0.
    int terminalScore(Position pos) => pos.isCheckmate ? -10000 : 0;

    final out = <MoveAnalysis>[];
    var accSum = 0.0;
    for (var k = 0; k < playerPlies.length; k++) {
      final i = playerPlies[k];
      final before = await evalAt(i);
      if (before == null) break;
      final afterPos = positions[i + 1];
      final afterRes = await evalAt(i + 1);
      // Sonraki konumda sıra rakipte: skoru oyuncu gözüne çevir.
      final evalAfter = afterRes == null ? -terminalScore(afterPos) : -afterRes.score;
      final evalBefore = before.score;
      final isBest = before.bestMove == moves[i].uci || evalAfter >= evalBefore;
      final loss = isBest ? 0 : (evalBefore - evalAfter).clamp(0, 20000);
      final quality = MoveQuality.fromLoss(loss, isBest: isBest);

      var opp = Opportunity.none;
      if (!isBest) {
        if (before.mate != null && before.mate! > 0 && !(afterRes?.mate != null && afterRes!.mate! < 0)) {
          opp = Opportunity.mate;
        } else if (loss >= 300) {
          final bestMove = NormalMove.fromUci(before.bestMove);
          final capturesPiece = positions[i].board.pieceAt(bestMove.to) != null;
          opp = capturesPiece ? Opportunity.material : Opportunity.big;
        }
      }
      final bestMove = NormalMove.fromUci(before.bestMove);
      final bestSan = positions[i].isLegal(bestMove) ? positions[i].makeSan(bestMove).$2 : before.bestMove;
      out.add(MoveAnalysis(
        ply: i,
        playedUci: moves[i].uci,
        playedSan: game.sanMoves.length > i ? game.sanMoves[i] : moves[i].uci,
        bestUci: before.bestMove,
        bestSan: bestSan,
        evalBefore: evalBefore,
        evalAfter: evalAfter,
        lossCp: loss,
        quality: quality,
        opportunity: opp,
        bestPv: before.pv.take(6).toList(),
        mateInBefore: before.mate != null && before.mate! > 0 ? before.mate : null,
      ));
      accSum += moveAccuracy(winPercent(evalBefore), winPercent(evalAfter));
      onProgress?.call((k + 1) / playerPlies.length);
    }
    final accuracy = out.isEmpty ? 100.0 : accSum / out.length;
    return GameAnalysis(moves: out, accuracy: accuracy);
  }
}
