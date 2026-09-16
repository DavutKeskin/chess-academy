import 'package:flutter/material.dart';

import '../../core/progress_store.dart';
import '../../core/settings_store.dart';
import '../../core/theme.dart';
import '../../l10n/l10n.dart';
import 'puzzle_repository.dart';
import 'puzzle_screen.dart';
import 'puzzles.dart';

/// Kategoriler: Başlangıç, Tek Hamlede Mat, İki Hamlede Mat.
class PuzzleListScreen extends StatelessWidget {
  const PuzzleListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = ProgressStore.instance;
    final repo = PuzzleRepository.instance;
    final t = context.t;
    final level = SettingsStore.instance.level;
    return Scaffold(
      appBar: AppBar(title: Text(t.puzzles)),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final sequence = repo.levelSequence(level);
          final next = sequence.indexWhere((p) => !store.isPuzzleSolved(p.id));
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              if (next >= 0) ...[
                _LevelCard(
                  level: level,
                  puzzle: sequence[next],
                  category: repo.categoryOf(sequence[next]),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => PuzzleScreen(puzzles: sequence, index: next)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              for (final c in repo.categories) ...[
                _CategoryCard(
                  category: c,
                  forLevel: c.id == repo.levelCategoryId(level),
                  solved: c.puzzles.where((p) => store.isPuzzleSolved(p.id)).length,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => PuzzlePackScreen(category: c)),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 8),
              Text(t.lichessCredit, style: Theme.of(context).textTheme.bodyMedium),
            ],
          );
        },
      ),
    );
  }
}

/// Seviyeye göre sıradaki bulmaca: seviye adı, kategori ve zorluk.
class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.level, required this.puzzle, required this.category, required this.onTap});
  final SkillLevel level;
  final Puzzle puzzle;
  final PuzzleCategory? category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final rating = puzzle.rating;
    final title = category?.title(t) ?? '';
    return Material(
      color: AppColors.puzzles,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.levelPuzzle,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      '${t.levelLabel(level.label(t))} · ${rating == null ? title : t.dailySubtitle(title, rating)}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 36),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.solved, required this.onTap, this.forLevel = false});
  final PuzzleCategory category;
  final bool forLevel;
  final int solved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final total = category.puzzles.length;
    final done = solved >= total;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.puzzles.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(done ? Icons.check_rounded : Icons.extension_rounded, color: AppColors.puzzles),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(category.title(t), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                            if (forLevel)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.puzzles.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  t.forYourLevel,
                                  style: const TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.puzzles),
                                ),
                              ),
                          ],
                        ),
                        Text(category.subtitle(t), style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.navy),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : solved / total,
                        minHeight: 6,
                        color: AppColors.puzzles,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('$solved / $total', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bir kategorinin 20'lik bölümleri. Bölüme dokununca ilk çözülmemiş bulmaca açılır.
class PuzzlePackScreen extends StatelessWidget {
  const PuzzlePackScreen({super.key, required this.category});
  final PuzzleCategory category;

  @override
  Widget build(BuildContext context) {
    final store = ProgressStore.instance;
    final t = context.t;
    return Scaffold(
      appBar: AppBar(title: Text(category.title(t))),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final firstUnsolved = category.puzzles.indexWhere((p) => !store.isPuzzleSolved(p.id));
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              if (firstUnsolved >= 0)
                FilledButton.icon(
                  onPressed: () => _open(context, category.puzzles, firstUnsolved),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(firstUnsolved == 0 ? t.startBtn : t.continueFromPuzzle(firstUnsolved + 1)),
                )
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(t.categoryAllSolved, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              const SizedBox(height: 16),
              for (var i = 0; i < category.packCount; i++) ...[
                _PackTile(
                  index: i,
                  puzzles: category.pack(i),
                  onTap: (puzzleIndexInPack) =>
                      _open(context, category.puzzles, i * PuzzleCategory.packSize + puzzleIndexInPack),
                ),
                const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }

  void _open(BuildContext context, List<Puzzle> list, int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PuzzleScreen(puzzles: list, index: index)),
    );
  }
}

class _PackTile extends StatelessWidget {
  const _PackTile({required this.index, required this.puzzles, required this.onTap});
  final int index;
  final List<Puzzle> puzzles;
  final void Function(int puzzleIndexInPack) onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final store = ProgressStore.instance;
    final solved = puzzles.where((p) => store.isPuzzleSolved(p.id)).length;
    final ratings = puzzles.map((p) => p.rating).whereType<int>();
    final range = ratings.isEmpty
        ? null
        : '${ratings.reduce((a, b) => a < b ? a : b)}–${ratings.reduce((a, b) => a > b ? a : b)}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(t.packTitle(index + 1), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                if (range != null) Text(t.difficultyRange(range), style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(width: 10),
                Text('$solved / ${puzzles.length}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < puzzles.length; i++)
                  _Dot(
                    label: '${i + 1}',
                    solved: store.isPuzzleSolved(puzzles[i].id),
                    onTap: () => onTap(i),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.label, required this.solved, required this.onTap});
  final String label;
  final bool solved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: solved ? AppColors.success : AppColors.navyLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: solved
            ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
            : Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.navyDark)),
      ),
    );
  }
}
