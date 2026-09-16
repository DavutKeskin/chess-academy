import 'dart:convert';
import 'dart:io' as io;

import 'package:chess_academy/core/settings_store.dart';
import 'package:chess_academy/features/puzzles/puzzle_repository.dart';
import 'package:chess_academy/features/puzzles/puzzles.dart';
import 'package:flutter_test/flutter_test.dart';

List<Puzzle> _load(String name) {
  final data = jsonDecode(io.File('assets/puzzles/$name.json').readAsStringSync()) as Map<String, dynamic>;
  return [for (final j in data['puzzles'] as List) Puzzle.fromJson(j as Map<String, dynamic>)];
}

/// Seviyeye göre bulmaca: her seviyenin havuzu dolu, farklı ve zorluğu seviyeyle artıyor.
void main() {
  final repo = PuzzleRepository.instance;
  final total = starterPuzzles.length + _load('mate_in_1').length + _load('mate_in_2').length;

  setUpAll(() {
    repo.setCategories([
      const PuzzleCategory(id: 'starter', puzzles: starterPuzzles),
      PuzzleCategory(id: 'mateIn1', puzzles: _load('mate_in_1')),
      PuzzleCategory(id: 'mateIn2', puzzles: _load('mate_in_2')),
    ]);
  });

  double avgRating(List<Puzzle> l) {
    final r = l.map((p) => p.rating).whereType<int>();
    return r.reduce((a, b) => a + b) / r.length;
  }

  test('her seviyenin havuzu yeterince büyük ve zorluk seviyeyle artıyor', () {
    final pools = {for (final l in SkillLevel.values) l: repo.levelPool(l)};
    for (final e in pools.entries) {
      expect(e.value.where((p) => p.rating != null).length, greaterThanOrEqualTo(60), reason: '${e.key}');
    }
    expect(avgRating(pools[SkillLevel.beginner]!), lessThan(avgRating(pools[SkillLevel.knowsRules]!)));
    expect(avgRating(pools[SkillLevel.knowsRules]!), lessThan(avgRating(pools[SkillLevel.plays]!)));
  });

  test('yeni başlayan başlangıç bulmacalarıyla, oynayan iki hamlede matla başlar', () {
    expect(repo.levelSequence(SkillLevel.beginner).first.id, starterPuzzles.first.id);
    expect(repo.levelSequence(SkillLevel.plays).first.playerMoveCount, 2);
    expect(repo.levelCategoryId(SkillLevel.beginner), 'starter');
    expect(repo.levelCategoryId(SkillLevel.knowsRules), 'mateIn1');
    expect(repo.levelCategoryId(SkillLevel.plays), 'mateIn2');
  });

  test('sıra tüm bulmacaları bir kez içerir', () {
    for (final l in SkillLevel.values) {
      final ids = repo.levelSequence(l).map((p) => p.id).toList();
      expect(ids.length, total, reason: '$l');
      expect(ids.toSet().length, total, reason: '$l');
    }
  });

  test('günün bulmacası seviyeye göre farklı, gün içinde sabit', () {
    final day = DateTime(2026, 9, 17);
    final ids = {for (final l in SkillLevel.values) repo.dailyPuzzle(day, l)!.id};
    expect(ids.length, SkillLevel.values.length);
    for (final l in SkillLevel.values) {
      expect(repo.dailyPuzzle(DateTime(2026, 9, 17, 23), l)!.id, repo.dailyPuzzle(day, l)!.id);
      expect(repo.levelPool(l).map((p) => p.id), contains(repo.dailyPuzzle(day, l)!.id));
    }
  });
}
