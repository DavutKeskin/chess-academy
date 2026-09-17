import 'package:flutter/material.dart';

import '../../core/progress_store.dart';
import '../../core/theme.dart';
import '../../core/widgets/section_header.dart';
import '../../l10n/l10n.dart';
import '../lessons/lessons.dart';
import '../puzzles/puzzle_repository.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = ProgressStore.instance;
    final t = context.t;
    final lessonCount = buildLessons(t).length;
    return Scaffold(
      appBar: AppBar(title: Text(t.progress)),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final badges = _badges(t, store, lessonCount);
          final earned = badges.where((b) => b.earned).length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.75,
                children: [
                  _StatCard(icon: Icons.local_fire_department_rounded, color: AppColors.progress, value: '${store.streak}', label: t.statStreak),
                  _StatCard(icon: Icons.school_rounded, color: AppColors.lessons, value: '${store.completedLessons.length}/$lessonCount', label: t.statLessons),
                  _StatCard(icon: Icons.extension_rounded, color: AppColors.puzzles, value: '${store.solvedPuzzles.length}/${PuzzleRepository.instance.totalCount}', label: t.statPuzzles),
                  _StatCard(icon: Icons.sports_esports_rounded, color: AppColors.play, value: '${store.gamesWon}/${store.gamesPlayed}', label: t.statGames),
                ],
              ),
              const SizedBox(height: 24),
              SectionHeader(t.badges, trailing: Text('$earned / ${badges.length}', style: const TextStyle(fontWeight: FontWeight.w700))),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.7,
                children: [for (final b in badges) _Badge(b)],
              ),
            ],
          );
        },
      ),
    );
  }

  List<_BadgeInfo> _badges(AppLocalizations t, ProgressStore s, int lessonCount) => [
        _BadgeInfo(t.badgeFirstStep, t.badgeFirstStepHint, Icons.flag_rounded, s.completedLessons.isNotEmpty),
        _BadgeInfo(t.badgePieceMaster, t.badgePieceMasterHint, Icons.workspace_premium_rounded, s.completedLessons.length >= lessonCount),
        _BadgeInfo(t.badgePuzzleHunter, t.badgePuzzleHunterHint, Icons.search_rounded, s.solvedPuzzles.length >= 5),
        _BadgeInfo(t.badgeMateMachine, t.badgeMateMachineHint, Icons.bolt_rounded, s.solvedPuzzles.length >= 100),
        _BadgeInfo(t.badgeFirstWin, t.badgeFirstWinHint, Icons.emoji_events_rounded, s.gamesWon >= 1),
        _BadgeInfo(t.badgeSteady, t.badgeSteadyHint, Icons.local_fire_department_rounded, s.streak >= 3),
      ];
}

class _BadgeInfo {
  const _BadgeInfo(this.title, this.hint, this.icon, this.earned);
  final String title;
  final String hint;
  final IconData icon;
  final bool earned;
}

class _Badge extends StatelessWidget {
  const _Badge(this.info);
  final _BadgeInfo info;

  @override
  Widget build(BuildContext context) {
    final earned = info.earned;
    return Card(
      color: earned ? AppColors.goldLight : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: earned ? AppColors.gold : AppColors.surfaceContainer, shape: BoxShape.circle),
              child: Icon(earned ? info.icon : Icons.lock_outline_rounded, color: earned ? AppPalette.light.navyDark : AppColors.inkMuted),
            ),
            const SizedBox(height: 8),
            Text(info.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, height: 1.2, fontWeight: FontWeight.w700, color: earned ? AppColors.ink : AppColors.inkMuted)),
            const SizedBox(height: 2),
            Expanded(
              child: Text(info.hint,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: AppColors.inkMuted, height: 1.2)),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.color, required this.value, required this.label});
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.1)),
                  ),
                  Text(label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13, height: 1.2)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
