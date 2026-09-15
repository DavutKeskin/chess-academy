import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:stockfish/stockfish.dart';

/// Motor sonucu: en iyi hamle, skor (sıradaki tarafın gözünden) ve ana varyant.
class EngineResult {
  const EngineResult({required this.bestMove, required this.cp, required this.mate, required this.pv, required this.depth});

  final String bestMove;

  /// Santipiyon skoru (sıradaki taraf için). Mat varsa [mate] dolu, bu 0.
  final int cp;

  /// Mat mesafesi (hamle); pozitif = sıradaki taraf mat eder, negatif = mat olur.
  final int? mate;
  final List<String> pv;
  final int depth;

  /// Karşılaştırma için tek sayı: mat skorları ±(10000 - mesafe) olarak.
  int get score => mate == null ? cp : (mate! > 0 ? 10000 - mate! : -10000 - mate!);
}

/// Uygulama genelinde tek Stockfish süreci. İstekler sırayla işlenir;
/// boşta kalınca bellek için kapatılır, gerekince yeniden açılır.
class EngineService {
  EngineService._();
  static final EngineService instance = EngineService._();

  static bool get isSupported => Platform.isAndroid || Platform.isIOS;

  Stockfish? _engine;
  StreamSubscription<String>? _sub;
  final _lines = StreamController<String>.broadcast();
  Future<void> _queue = Future.value();
  Timer? _idleTimer;
  int _skill = 20;

  Future<Stockfish> _ensure() async {
    _idleTimer?.cancel();
    final e = _engine;
    if (e != null && e.state.value == StockfishState.ready) return e;
    await _shutdown();
    final engine = await stockfishAsync().timeout(const Duration(seconds: 30));
    _sub = engine.stdout.listen(_lines.add);
    engine.stdin = 'uci';
    engine.stdin = 'setoption name Skill Level value $_skill';
    engine.stdin = 'isready';
    await _waitFor((l) => l.startsWith('readyok'), const Duration(seconds: 10));
    _engine = engine;
    return engine;
  }

  Future<String> _waitFor(bool Function(String) test, Duration timeout) {
    return _lines.stream.firstWhere(test).timeout(timeout);
  }

  void _touchIdle() {
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(seconds: 90), _shutdown);
  }

  Future<void> _shutdown() async {
    _idleTimer?.cancel();
    await _sub?.cancel();
    _sub = null;
    try {
      _engine?.dispose();
    } catch (_) {}
    _engine = null;
  }

  /// Sıraya alınmış, tek seferde bir analiz.
  Future<EngineResult> analyse(String fen, {int movetimeMs = 350, int skill = 20}) {
    final completer = Completer<EngineResult>();
    _queue = _queue.then((_) async {
      try {
        completer.complete(await _run(fen, movetimeMs, skill));
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<EngineResult> _run(String fen, int movetimeMs, int skill) async {
    final engine = await _ensure();
    if (skill != _skill) {
      _skill = skill;
      engine.stdin = 'setoption name Skill Level value $skill';
    }
    int cp = 0;
    int? mate;
    List<String> pv = const [];
    int depth = 0;
    final done = Completer<String>();
    final sub = _lines.stream.listen((line) {
      if (line.startsWith('info ') && line.contains(' pv ') && !line.contains('multipv 2')) {
        final parts = line.split(' ');
        final d = parts.indexOf('depth');
        if (d > 0) depth = int.tryParse(parts[d + 1]) ?? depth;
        final s = parts.indexOf('score');
        if (s > 0) {
          if (parts[s + 1] == 'cp') {
            cp = int.tryParse(parts[s + 2]) ?? 0;
            mate = null;
          } else if (parts[s + 1] == 'mate') {
            mate = int.tryParse(parts[s + 2]);
            cp = 0;
          }
        }
        final p = parts.indexOf('pv');
        if (p > 0) pv = parts.sublist(p + 1);
      } else if (line.startsWith('bestmove') && !done.isCompleted) {
        done.complete(line.split(' ').length > 1 ? line.split(' ')[1] : '(none)');
      }
    });
    try {
      engine.stdin = 'position fen $fen';
      engine.stdin = 'go movetime $movetimeMs';
      final best = await done.future.timeout(Duration(milliseconds: movetimeMs + 15000));
      return EngineResult(bestMove: best, cp: cp, mate: mate, pv: pv, depth: depth);
    } finally {
      await sub.cancel();
      _touchIdle();
    }
  }

  /// Uygulama kapanırken.
  Future<void> dispose() => _shutdown();

  @visibleForTesting
  static EngineResult parseForTest(List<String> lines) {
    int cp = 0;
    int? mate;
    List<String> pv = const [];
    int depth = 0;
    var best = '';
    for (final line in lines) {
      if (line.startsWith('info ') && line.contains(' pv ')) {
        final parts = line.split(' ');
        depth = int.tryParse(parts[parts.indexOf('depth') + 1]) ?? depth;
        final s = parts.indexOf('score');
        if (parts[s + 1] == 'cp') {
          cp = int.parse(parts[s + 2]);
          mate = null;
        } else {
          mate = int.parse(parts[s + 2]);
          cp = 0;
        }
        pv = parts.sublist(parts.indexOf('pv') + 1);
      } else if (line.startsWith('bestmove')) {
        best = line.split(' ')[1];
      }
    }
    return EngineResult(bestMove: best, cp: cp, mate: mate, pv: pv, depth: depth);
  }
}
