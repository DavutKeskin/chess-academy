import 'dart:convert';

import 'package:flutter/services.dart';

import '../../core/settings_store.dart';
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
    setCategories([
      const PuzzleCategory(id: 'starter', puzzles: starterPuzzles),
      if (mate1.isNotEmpty)
        PuzzleCategory(id: 'mateIn1', puzzles: mate1),
      if (mate2.isNotEmpty)
        PuzzleCategory(id: 'mateIn2', puzzles: mate2),
    ]);
  }

  /// Kategorileri doğrudan verir (açılışta [load], testte elle).
  void setCategories(List<PuzzleCategory> categories) {
    _categories = categories;
    _byId = {
      for (final c in _categories)
        for (final p in c.puzzles) p.id: p,
    };
  }

  /// Seviyenin önerilen dilimleri, öncelik sırasıyla: (kategori, en düşük puan, en yüksek puan hariç).
  /// Başlangıç bulmacalarının puanı yok; yalnızca "Hiç bilmiyorum" seviyesinde öne alınır.
  static List<(String, int, int)> _bands(SkillLevel level) => switch (level) {
        SkillLevel.beginner => [('starter', 0, 1 << 30), ('mateIn1', 0, 950)],
        SkillLevel.knowsRules => [('mateIn1', 950, 1 << 30), ('mateIn2', 0, 1150)],
        SkillLevel.plays => [('mateIn2', 1150, 1 << 30), ('mateIn1', 1050, 1 << 30)],
      };

  static bool _inBand(Puzzle p, (String, int, int) band) {
    final r = p.rating;
    return r == null || (r >= band.$2 && r < band.$3);
  }

  /// Seviyeye uygun bulmacalar (günün bulmacası bunlardan seçilir).
  List<Puzzle> levelPool(SkillLevel level) => [
        for (final band in _bands(level))
          ...?_categories.where((c) => c.id == band.$1).firstOrNull?.puzzles.where((p) => _inBand(p, band)),
      ];

  /// Seviyeye göre çözüm sırası: önce seviyeye uygun dilimler, sonra kalan bulmacalar kolaydan zora.
  List<Puzzle> levelSequence(SkillLevel level) {
    final first = levelPool(level);
    final seen = {for (final p in first) p.id};
    return [
      ...first,
      for (final c in _categories)
        for (final p in c.puzzles)
          if (!seen.contains(p.id)) p,
    ];
  }

  /// Seviye kategorisi: listede "seviyene uygun" diye işaretlenen kategori.
  String levelCategoryId(SkillLevel level) => _bands(level).first.$1;

  /// Günün bulmacası: tarihe ve seviyeye göre; aynı gün aynı seviyede herkese aynı bulmaca.
  Puzzle? dailyPuzzle(DateTime day, SkillLevel level) {
    final pool = levelPool(level).where((p) => p.rating != null).toList();
    if (pool.isEmpty) return null;
    final dayIndex = day.difference(DateTime(2026, 1, 1)).inDays;
    return pool[dayIndex % pool.length];
  }

  /// Bulmacanın kategorisi (günün bulmacası kartındaki ad için).
  PuzzleCategory? categoryOf(Puzzle puzzle) =>
      _categories.where((c) => c.puzzles.any((p) => p.id == puzzle.id)).firstOrNull;

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
