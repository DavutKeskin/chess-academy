import 'dart:async';
import 'dart:math';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';
import '../engine/engine_service.dart';

/// Bilgisayar rakibin ortak arayüzü.
abstract class Bot {
  /// 1 (en kolay) ile 5 (en zor) arası.
  int get level;

  /// [maxTimeMs] verilirse (süreli oyun) düşünme süresi bununla sınırlanır.
  Future<Move> bestMove(Position position, {int? maxTimeMs});

  Future<void> dispose() async {}

  /// Platform destekliyorsa Stockfish, değilse basit yerleşik bot döner.
  static Future<Bot> create(int level) async {
    if (EngineService.isSupported) {
      try {
        return await StockfishBot.start(level);
      } catch (e) {
        // Motor başlamazsa oyun yine oynanabilsin.
        debugPrint('Stockfish unavailable, using SimpleBot: $e');
      }
    }
    return SimpleBot(level);
  }
}

/// Stockfish gerektirmeyen, masaüstünde de çalışan basit rakip.
/// Seviye 1: rastgele. Seviye 2: taş alma ve şah öncelikli.
/// Seviye 3+: iki hamle derinlikli malzeme araması.
class SimpleBot extends Bot {
  SimpleBot(this.level);

  @override
  final int level;

  final _rng = Random();

  static const _values = {
    Role.pawn: 100,
    Role.knight: 320,
    Role.bishop: 330,
    Role.rook: 500,
    Role.queen: 900,
    Role.king: 0,
  };

  @override
  Future<Move> bestMove(Position position, {int? maxTimeMs}) async {
    // Küçük bir gecikme: çocuk için "düşünüyor" hissi.
    await Future<void>.delayed(Duration(milliseconds: min(350, maxTimeMs ?? 350)));
    final moves = _allMoves(position);
    if (level <= 1) return moves[_rng.nextInt(moves.length)];
    final depth = level == 2 ? 1 : 2;
    var best = <Move>[];
    var bestScore = -1 << 30;
    for (final m in moves) {
      final score = -_negamax(position.playUnchecked(m), depth - 1);
      if (score > bestScore) {
        bestScore = score;
        best = [m];
      } else if (score == bestScore) {
        best.add(m);
      }
    }
    return best[_rng.nextInt(best.length)];
  }

  int _negamax(Position pos, int depth) {
    if (pos.isCheckmate) return -100000;
    if (pos.isGameOver) return 0;
    if (depth == 0) return _evaluate(pos);
    var best = -1 << 30;
    for (final m in _allMoves(pos)) {
      final s = -_negamax(pos.playUnchecked(m), depth - 1);
      if (s > best) best = s;
    }
    return best;
  }

  /// Sırası gelen tarafın gözünden malzeme farkı.
  int _evaluate(Position pos) {
    var score = 0;
    for (final role in Role.values) {
      final v = _values[role]!;
      score += v * pos.board.piecesOf(pos.turn, role).size;
      score -= v * pos.board.piecesOf(pos.turn.opposite, role).size;
    }
    return score;
  }

  static List<Move> _allMoves(Position pos) {
    final result = <Move>[];
    for (final entry in pos.legalMoves.entries) {
      for (final to in entry.value.squares) {
        final piece = pos.board.pieceAt(entry.key);
        final promotes =
            piece?.role == Role.pawn &&
            (to.rank == Rank.first || to.rank == Rank.eighth);
        result.add(
          NormalMove(
            from: entry.key,
            to: to,
            promotion: promotes ? Role.queen : null,
          ),
        );
      }
    }
    return result;
  }
}

/// Stockfish motoru (paylaşımlı EngineService üzerinden). Seviye, "Skill Level" ve düşünme süresine eşlenir.
class StockfishBot extends Bot {
  StockfishBot._(this.level);

  @override
  final int level;

  static Future<StockfishBot> start(int level) async {
    // Motorun açılabildiğini doğrula; açılamazsa SimpleBot'a düşülür.
    await EngineService.instance.analyse(Chess.initial.fen, movetimeMs: 50, skill: _skill(level));
    return StockfishBot._(level);
  }

  static int _skill(int level) => const [0, 0, 3, 7, 12, 20][level.clamp(0, 5)];
  static int _moveTimeMs(int level) => const [100, 100, 200, 400, 700, 1200][level.clamp(0, 5)];

  @override
  Future<Move> bestMove(Position position, {int? maxTimeMs}) async {
    final budget = maxTimeMs == null ? _moveTimeMs(level) : min(_moveTimeMs(level), max(50, maxTimeMs));
    final r = await EngineService.instance.analyse(position.fen, movetimeMs: budget, skill: _skill(level));
    return NormalMove.fromUci(r.bestMove);
  }

  @override
  Future<void> dispose() async {}
}
