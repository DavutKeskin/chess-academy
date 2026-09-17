import 'package:flutter/material.dart';

import '../../core/progress_store.dart';
import '../../core/purchase_store.dart';
import '../../core/settings_store.dart';
import '../../core/theme.dart';
import '../../l10n/l10n.dart';
import '../lessons/lesson_list_screen.dart';
import '../lessons/lesson_screen.dart';
import '../lessons/lessons.dart';
import '../paywall/paywall_screen.dart';
import '../play/play_screen.dart';
import '../progress/progress_screen.dart';
import '../puzzles/puzzle_list_screen.dart';
import '../puzzles/puzzle_repository.dart';
import '../puzzles/puzzle_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = ProgressStore.instance;
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([store, PurchaseStore.instance, SettingsStore.instance]),
          builder: (context, _) {
            final t = context.t;
            final lessons = buildLessons(t);
            final nextLesson = lessons.where((l) => !store.isLessonDone(l.id)).firstOrNull;
            final nextLocked = nextLesson != null &&
                isPremiumLesson(lessons.indexOf(nextLesson)) &&
                !PurchaseStore.instance.hasFullAccess;
            final lessonsDone = store.completedLessons.length;
            final puzzlesDone = store.solvedPuzzles.length;
            final repo = PuzzleRepository.instance;
            final level = SettingsStore.instance.level;
            final daily = repo.dailyPuzzle(DateTime.now(), level);
            final dailyCategory = daily == null ? null : repo.categoryOf(daily);
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                _Header(streak: store.streak, onSettings: () => _open(context, const SettingsScreen())),
                const SizedBox(height: 20),
                _TodayCard(
                  lesson: nextLesson,
                  locked: nextLocked,
                  onTap: () => _open(
                    context,
                    nextLocked
                        ? const PaywallScreen()
                        : nextLesson != null
                            ? LessonScreen(lesson: nextLesson)
                            : _levelPuzzleScreen(level),
                  ),
                ),
                if (daily != null) ...[
                  const SizedBox(height: 12),
                  _DailyCard(
                    solved: store.isPuzzleSolved(daily.id),
                    subtitle: t.dailySubtitle(dailyCategory?.title(t) ?? '', daily.rating ?? 0),
                    onTap: () => _open(context, PuzzleScreen(puzzles: [daily], index: 0)),
                  ),
                ],
                const SizedBox(height: 20),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.12,
                  children: [
                    _ModuleTile(
                      icon: Icons.school_rounded,
                      color: AppColors.lessons,
                      title: t.lessons,
                      subtitle: t.lessonsDoneOf(lessonsDone, lessons.length),
                      progress: lessonsDone / lessons.length,
                      onTap: () => _open(context, const LessonListScreen()),
                    ),
                    _ModuleTile(
                      icon: Icons.extension_rounded,
                      color: AppColors.puzzles,
                      title: t.puzzles,
                      subtitle: t.puzzlesSolvedOf(puzzlesDone, repo.totalCount),
                      progress: repo.totalCount == 0 ? 0 : puzzlesDone / repo.totalCount,
                      onTap: () => _open(context, const PuzzleListScreen()),
                    ),
                    _ModuleTile(
                      icon: Icons.sports_esports_rounded,
                      color: AppColors.play,
                      title: t.play,
                      subtitle: store.gamesPlayed == 0 ? t.vsComputer : t.winsCount(store.gamesWon),
                      onTap: () => _open(context, const PlaySetupScreen()),
                    ),
                    _ModuleTile(
                      icon: Icons.emoji_events_rounded,
                      color: AppColors.progress,
                      title: t.progress,
                      subtitle: t.badgesAndStreak,
                      onTap: () => _open(context, const ProgressScreen()),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Tüm dersler bitince: seviyeye göre sıradaki çözülmemiş bulmaca.
  Widget _levelPuzzleScreen(SkillLevel level) {
    final sequence = PuzzleRepository.instance.levelSequence(level);
    final next = sequence.indexWhere((p) => !ProgressStore.instance.isPuzzleSolved(p.id));
    return next < 0 ? const PuzzleListScreen() : PuzzleScreen(puzzles: sequence, index: next);
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.streak, required this.onSettings});
  final int streak;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Uygulama adı yerine logo; ad ekran okuyucu için etiket olarak kalır.
        Semantics(
          label: context.t.appName,
          header: true,
          image: true,
          child: const Image(image: AssetImage('assets/logo/logo.png'), width: 44, height: 44),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Align(alignment: Alignment.centerLeft, child: _StreakPill(streak: streak)),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: context.t.settings,
          onPressed: onSettings,
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surfaceContainer,
            foregroundColor: AppColors.ink,
            fixedSize: const Size(44, 44),
          ),
          icon: const Icon(Icons.settings_outlined, size: 22),
        ),
      ],
    );
  }
}

class _StreakPill extends StatelessWidget {
  const _StreakPill({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) {
    final active = streak > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active ? AppColors.goldLight : AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: active ? AppColors.gold : AppColors.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department_rounded,
              size: 18, color: active ? AppColors.goldInk : AppColors.inkMuted),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              active ? context.t.streakDays(streak) : context.t.streakEmpty,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: active ? AppColors.goldOnLight : AppColors.inkMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.lesson, required this.onTap, this.locked = false});
  final Lesson? lesson;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final l = lesson;
    return Material(
      color: AppColors.hero,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l != null ? t.todaysLesson : t.allLessonsDoneLabel,
                      style: TextStyle(
                        color: AppColors.heroAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l != null ? '${l.emoji} ${l.title}' : t.practiceWithPuzzles,
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      locked
                          ? t.unlockedWithPack
                          : l != null
                              ? t.stepsApprox(l.steps.length)
                              : t.mateInOneShort,
                      style: const TextStyle(color: Color(0xFFBFD0EA), fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                child: Icon(locked ? Icons.lock_rounded : Icons.play_arrow_rounded, color: AppPalette.light.navyDark, size: 28),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyCard extends StatelessWidget {
  const _DailyCard({required this.solved, required this.subtitle, required this.onTap});
  final bool solved;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Card(
      color: solved ? AppColors.successLight : AppColors.goldLight,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(solved ? Icons.check_circle_rounded : Icons.today_rounded,
                  color: solved ? AppColors.success : AppColors.goldInk),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.dailyPuzzle, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    Text(
                      solved
                          ? t.dailySolved
                          : subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.navy),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.progress,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final double? progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const Spacer(),
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.2)),
              const SizedBox(height: 2),
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.2)),
              if (progress != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: progress, minHeight: 6, color: color),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
