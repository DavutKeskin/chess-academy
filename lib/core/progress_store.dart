import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kullanıcının ilerlemesini cihazda saklar: biten dersler, çözülen
/// bulmacalar, günlük seri ve oyun istatistikleri.
class ProgressStore extends ChangeNotifier {
  ProgressStore._();
  static final ProgressStore instance = ProgressStore._();

  late SharedPreferences _prefs;

  static const _kLessons = 'lessons_done';
  static const _kPuzzles = 'puzzles_solved';
  static const _kStreak = 'streak_count';
  static const _kLastDay = 'streak_last_day';
  static const _kGames = 'games_played';
  static const _kWins = 'games_won';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Set<String> get completedLessons =>
      (_prefs.getStringList(_kLessons) ?? const []).toSet();

  Set<String> get solvedPuzzles =>
      (_prefs.getStringList(_kPuzzles) ?? const []).toSet();

  int get streak => _prefs.getInt(_kStreak) ?? 0;
  int get gamesPlayed => _prefs.getInt(_kGames) ?? 0;
  int get gamesWon => _prefs.getInt(_kWins) ?? 0;

  bool isLessonDone(String id) => completedLessons.contains(id);
  bool isPuzzleSolved(String id) => solvedPuzzles.contains(id);

  Future<void> markLessonDone(String id) async {
    final set = completedLessons..add(id);
    await _prefs.setStringList(_kLessons, set.toList());
    await _touchStreak();
    notifyListeners();
  }

  Future<void> markPuzzleSolved(String id) async {
    final set = solvedPuzzles..add(id);
    await _prefs.setStringList(_kPuzzles, set.toList());
    await _touchStreak();
    notifyListeners();
  }

  Future<void> recordGame({required bool won}) async {
    await _prefs.setInt(_kGames, gamesPlayed + 1);
    if (won) await _prefs.setInt(_kWins, gamesWon + 1);
    await _touchStreak();
    notifyListeners();
  }

  /// Bugün ilk kez bir şey yapıldıysa seriyi günceller.
  /// Dün de çalışıldıysa seri artar, aradan gün geçtiyse 1'e döner.
  Future<void> _touchStreak() async {
    final today = _dayKey(DateTime.now());
    final last = _prefs.getString(_kLastDay);
    if (last == today) return;
    final yesterday = _dayKey(DateTime.now().subtract(const Duration(days: 1)));
    final next = last == yesterday ? streak + 1 : 1;
    await _prefs.setInt(_kStreak, next);
    await _prefs.setString(_kLastDay, today);
  }

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @visibleForTesting
  Future<void> resetAll() async {
    await _prefs.clear();
    notifyListeners();
  }
}
