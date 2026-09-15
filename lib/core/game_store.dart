import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analysis/game_analysis.dart';

/// Oynanmış bir oyunun kaydı. Hamleler UCI olarak tutulur; böylece ileride
/// Stockfish ile hamle hamle analiz (hata ve kaçırılan fırsat) yapılabilir.
class GameRecord {
  const GameRecord({
    required this.id,
    required this.playedAt,
    required this.level,
    required this.playerIsWhite,
    required this.uciMoves,
    required this.sanMoves,
    required this.result,
    this.timeControl,
    this.endedBy,
    this.analysis,
  });

  final String id;
  final DateTime playedAt;
  final int level;
  final bool playerIsWhite;
  final List<String> uciMoves;
  final List<String> sanMoves;

  /// 'win' | 'loss' | 'draw'
  final String result;

  /// Süre kontrolü kodu ("5+0"); süresiz oyunda null.
  final String? timeControl;

  /// Oyun tahta dışında bittiyse nedeni: 'timeout'. Mat/pat/berabere için null.
  final String? endedBy;

  bool get isTimed => timeControl != null;
  bool get endedOnTime => endedBy == 'timeout';

  /// Motor analizi (yapıldıysa).
  final GameAnalysis? analysis;

  GameRecord withAnalysis(GameAnalysis a) => GameRecord(
        id: id,
        playedAt: playedAt,
        level: level,
        playerIsWhite: playerIsWhite,
        uciMoves: uciMoves,
        sanMoves: sanMoves,
        result: result,
        timeControl: timeControl,
        endedBy: endedBy,
        analysis: a,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'at': playedAt.toIso8601String(),
        'level': level,
        'white': playerIsWhite,
        'uci': uciMoves,
        'san': sanMoves,
        'result': result,
        if (timeControl != null) 'tc': timeControl,
        if (endedBy != null) 'endedBy': endedBy,
        if (analysis != null) 'analysis': analysis!.toJson(),
      };

  factory GameRecord.fromJson(Map<String, dynamic> j) => GameRecord(
        id: j['id'] as String,
        playedAt: DateTime.parse(j['at'] as String),
        level: j['level'] as int,
        playerIsWhite: j['white'] as bool,
        uciMoves: (j['uci'] as List).cast<String>(),
        sanMoves: (j['san'] as List).cast<String>(),
        result: j['result'] as String,
        timeControl: j['tc'] as String?,
        endedBy: j['endedBy'] as String?,
        analysis: j['analysis'] == null ? null : GameAnalysis.fromJson(j['analysis'] as Map<String, dynamic>),
      );
}

/// Son oyunları cihazda saklar (en yeni başta, en çok [maxGames]).
class GameStore extends ChangeNotifier {
  GameStore._();
  static final GameStore instance = GameStore._();

  static const _key = 'recent_games';
  static const maxGames = 20;

  late SharedPreferences _prefs;
  List<GameRecord> _games = const [];

  List<GameRecord> get games => _games;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    try {
      final raw = _prefs.getString(_key);
      if (raw != null) {
        _games = [for (final j in jsonDecode(raw) as List) GameRecord.fromJson(j as Map<String, dynamic>)];
      }
    } catch (_) {
      _games = const [];
    }
  }

  Future<void> saveAnalysis(String id, GameAnalysis a) async {
    _games = [for (final g in _games) g.id == id ? g.withAnalysis(a) : g];
    await _prefs.setString(_key, jsonEncode([for (final x in _games) x.toJson()]));
    notifyListeners();
  }

  Future<void> add(GameRecord g) async {
    _games = [g, ..._games].take(maxGames).toList();
    await _prefs.setString(_key, jsonEncode([for (final x in _games) x.toJson()]));
    notifyListeners();
  }
}
