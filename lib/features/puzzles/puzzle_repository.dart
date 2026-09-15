import 'dart:convert';

import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import 'puzzles.dart';

/// Bir bulmaca kategorisi (ör. tek hamlede mat) ve 20'lik bölümleri.
class PuzzleCategory {
  const PuzzleCategory({required this.id, required this.puzzles});

  final String id;
  final List<Puzzle> puzzles;

  String title(AppLocalizations t) => switch (id) {
        'mateIn1' => t.mateIn1Category,
        'mateIn2' => t.mateIn2Category,
        _ => t.starterCategory,
      };

  String subtitle(AppLocalizations t) => switch (id) {
        'mateIn1' => t.mateIn1Subtitle(puzzles.length),
        'mateIn2' => t.mateIn2Subtitle(puzzles.length),
        _ => t.starterSubtitle,
      };

  static const packSize = 20;

  int get packCount => (puzzles.length + packSize - 1) ~/ packSize;

  List<Puzzle> pack(int index) {
    final start = index * packSize;
    return puzzles.sublist(start, (start + packSize).clamp(0, puzzles.length));
  }
}

/// Tüm bulmacaları yükler: elle yazılmış başlangıç seti + Lichess'ten süzülmüş
/// (CC0) tek ve iki hamlede mat setleri. Uygulama açılışında bir kez yüklenir.
class PuzzleRepository {
  PuzzleRepository._();
  static final PuzzleRepository instance = PuzzleRepository._();

  List<PuzzleCategory> _categories = const [];
  Map<String, Puzzle> _byId = const {};

  List<PuzzleCategory> get categories => _categories;
  int get totalCount => _byId.length;
  Puzzle? byId(String id) => _byId[id];

  Future<void> load() async {
    final mate1 = await _loadAsset('assets/puzzles/mate_in_1.json');
    final mate2 = await _loadAsset('assets/puzzles/mate_in_2.json');
    _categories = [
      const PuzzleCategory(id: 'starter', puzzles: starterPuzzles),
      if (mate1.isNotEmpty)
        PuzzleCategory(id: 'mateIn1', puzzles: mate1),
      if (mate2.isNotEmpty)
        PuzzleCategory(id: 'mateIn2', puzzles: mate2),
    ];
    _byId = {
      for (final c in _categories)
        for (final p in c.puzzles) p.id: p,
    };
  }

  /// Günün bulmacası: tarihe göre belirlenir, herkes için aynı gün aynı bulmaca.
  Puzzle? dailyPuzzle(DateTime day) {
    final pool = _categories.where((c) => c.id == 'mateIn1').firstOrNull?.puzzles;
    if (pool == null || pool.isEmpty) return null;
    final dayIndex = day.difference(DateTime(2026, 1, 1)).inDays;
    return pool[dayIndex % pool.length];
  }

  Future<List<Puzzle>> _loadAsset(String path) async {
    try {
      final raw = await rootBundle.loadString(path);
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return [for (final j in data['puzzles'] as List) Puzzle.fromJson(j as Map<String, dynamic>)];
    } catch (_) {
      return const [];
    }
  }
}
