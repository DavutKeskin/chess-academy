import 'package:flutter/material.dart';

import '../../core/progress_store.dart';
import '../../core/purchase_store.dart';
import '../../core/settings_store.dart';
import '../../core/theme.dart';
import '../paywall/paywall_screen.dart';
import 'lesson_screen.dart';
import 'lessons.dart';
import '../../l10n/l10n.dart';

class LessonListScreen extends StatelessWidget {
  const LessonListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = ProgressStore.instance;
    final t = context.t;
    final lessons = buildLessons(t);
    return Scaffold(
      appBar: AppBar(title: Text(t.lessons)),
      body: ListenableBuilder(
        listenable: Listenable.merge([store, PurchaseStore.instance]),
        builder: (context, _) {
          final done = store.completedLessons.length;
          final owned = PurchaseStore.instance.hasFullAccess;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              _ProgressCard(done: done, total: lessons.length),
              const SizedBox(height: 16),
              for (var i = 0; i < lessons.length; i++) ...[
                if (i == 0 || lessons[i].group != lessons[i - 1].group)
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : 10, bottom: 8, left: 4),
                    child: Text(
                      lessons[i].group.title(t).toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ),
                _LessonTile(
                  index: i,
                  lesson: lessons[i],
                  done: store.isLessonDone(lessons[i].id),
                  premiumLocked: isPremiumLesson(i) && !owned,
                  // İlk ders ve bitmiş bir dersin ardındaki ders açık; sırayı korur.
                  unlocked:
                      SettingsStore.instance.lessonsUnlocked ||
                      i == 0 ||
                      store.isLessonDone(lessons[i - 1].id) ||
                      store.isLessonDone(lessons[i].id),
                ),
                const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.done, required this.total});
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.t.chessSchool,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text(
                  '$done / $total',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : done / total,
                minHeight: 10,
                color: AppColors.lessons,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              done == total ? context.t.allLessonsFinished : context.t.lessonsSequentialHint,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({
    required this.index,
    required this.lesson,
    required this.done,
    required this.unlocked,
    this.premiumLocked = false,
  });
  final int index;
  final Lesson lesson;
  final bool done;
  final bool unlocked;
  final bool premiumLocked;

  @override
  Widget build(BuildContext context) {
    // Premium kilidi: dokununca satın alma ekranı açılır (sıra kilidinden farklı).
    final muted = !unlocked && !premiumLocked;
    final canOpen = unlocked && !premiumLocked;
    return Card(
      child: ListTile(
        enabled: !muted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: done
                ? AppColors.successLight
                : (muted ? AppColors.surfaceContainer : AppColors.navyLight),
            borderRadius: BorderRadius.circular(14),
          ),
          child: done
              ? Icon(Icons.check_rounded, color: AppColors.success)
              : Text(lesson.emoji, style: const TextStyle(fontSize: 24)),
        ),
        title: Text(
          '${index + 1}. ${lesson.title}',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: muted ? AppColors.inkMuted : AppColors.ink,
          ),
        ),
        subtitle: Text(done ? context.t.completed : context.t.stepsCount(lesson.steps.length)),
        trailing: premiumLocked
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.goldLight,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.gold),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.workspace_premium_rounded, size: 16, color: AppColors.goldInk),
                    const SizedBox(width: 4),
                    Text(context.t.unlockBadge, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.goldOnLight)),
                  ],
                ),
              )
            : Icon(
                muted ? Icons.lock_outline_rounded : Icons.chevron_right_rounded,
                color: muted ? AppColors.inkMuted : AppColors.navy,
              ),
        onTap: premiumLocked
            ? () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const PaywallScreen()),
                )
            : canOpen
                ? () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => LessonScreen(lesson: lesson)),
                    )
                : null,
      ),
    );
  }
}
