import 'package:chess_academy/core/game_clock.dart';
import 'package:chess_academy/core/game_store.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('süre kontrolü kodu ve çözümleme', () {
    expect(const TimeControl(5, 0).code, '5+0');
    expect(const TimeControl(3, 2).code, '3+2');
    expect(TimeControl.unlimited.code, 'none');
    expect(TimeControl.parse('3+2'), const TimeControl(3, 2));
    expect(TimeControl.parse('10'), const TimeControl(10, 0));
    expect(TimeControl.parse(null), TimeControl.unlimited);
    expect(TimeControl.parse('bozuk'), TimeControl.unlimited);
    expect(TimeControl.presets.first.isUnlimited, isTrue);
  });

  test('saat: hamlede taraf değişir, ek saniye eklenir', () {
    var now = DateTime(2026, 1, 1, 12, 0, 0);
    final clock = GameClock(const TimeControl(3, 2), now: () => now, withTimer: false);
    expect(clock.started, isFalse);
    expect(clock.remaining(Side.white), const Duration(minutes: 3));

    // Beyaz ilk hamleyi yaptı: saat henüz sayılmıyordu, ek süre yok; siyah sayar.
    clock.press(Side.white);
    expect(clock.running, Side.black);
    expect(clock.remaining(Side.white), const Duration(minutes: 3));

    now = now.add(const Duration(seconds: 10));
    expect(clock.remaining(Side.black), const Duration(minutes: 2, seconds: 50));
    expect(clock.remaining(Side.white), const Duration(minutes: 3));

    // Siyah oynadı: 10 sn harcadı, 2 sn ek aldı; beyaz sayar.
    clock.press(Side.black);
    expect(clock.running, Side.white);
    expect(clock.remaining(Side.black), const Duration(minutes: 2, seconds: 52));

    now = now.add(const Duration(seconds: 4));
    expect(clock.remaining(Side.white), const Duration(minutes: 2, seconds: 56));
  });

  test('saat: duraklat ve sürdür arada geçen süreyi saymaz', () {
    var now = DateTime(2026, 1, 1);
    final clock = GameClock(const TimeControl(5, 0), now: () => now, withTimer: false);
    clock.press(Side.black); // beyaz sayar
    now = now.add(const Duration(seconds: 30));
    clock.pause();
    expect(clock.isRunning, isFalse);
    expect(clock.started, isTrue);
    now = now.add(const Duration(minutes: 10)); // arka planda geçen süre
    expect(clock.remaining(Side.white), const Duration(minutes: 4, seconds: 30));
    clock.resume();
    expect(clock.running, Side.white);
    now = now.add(const Duration(seconds: 5));
    expect(clock.remaining(Side.white), const Duration(minutes: 4, seconds: 25));
  });

  test('saat: süre bitince bayrak bir kez düşer ve saat durur', () {
    var now = DateTime(2026, 1, 1);
    final flags = <Side>[];
    final clock = GameClock(const TimeControl(1, 0), onFlag: flags.add, now: () => now, withTimer: false);
    clock.press(Side.white); // siyah sayar
    now = now.add(const Duration(seconds: 59));
    clock.tick();
    expect(flags, isEmpty);
    now = now.add(const Duration(seconds: 2));
    clock.tick();
    expect(flags, [Side.black]);
    expect(clock.flagged, isTrue);
    expect(clock.isRunning, isFalse);
    expect(clock.remaining(Side.black), Duration.zero);
    expect(clock.remaining(Side.white), const Duration(minutes: 1));
    clock.tick();
    clock.press(Side.black); // bayrak düştükten sonra hamle saati başlatmaz
    expect(flags.length, 1);
    expect(clock.isRunning, isFalse);

    clock.reset();
    expect(clock.flagged, isFalse);
    expect(clock.remaining(Side.black), const Duration(minutes: 1));
  });

  test('saat metni', () {
    expect(formatClock(const Duration(minutes: 5)), '5:00');
    expect(formatClock(const Duration(minutes: 2, seconds: 5)), '2:05');
    expect(formatClock(const Duration(seconds: 59, milliseconds: 400)), '1:00');
    expect(formatClock(const Duration(seconds: 10)), '0:10');
    expect(formatClock(const Duration(seconds: 9, milliseconds: 950)), '0:10');
    expect(formatClock(const Duration(seconds: 9, milliseconds: 900)), '0:09.9');
    expect(formatClock(const Duration(seconds: 3, milliseconds: 20)), '0:03.1');
    expect(formatClock(Duration.zero), '0:00.0');
  });

  test('oyun kaydı süre bilgisiyle gidip gelir; eski kayıtlar da okunur', () {
    final g = GameRecord(
      id: '1',
      playedAt: DateTime(2026, 9, 11),
      level: 3,
      playerIsWhite: true,
      uciMoves: const ['e2e4'],
      sanMoves: const ['e4'],
      result: 'loss',
      timeControl: '5+0',
      endedBy: 'timeout',
    );
    final back = GameRecord.fromJson(g.toJson() as Map<String, dynamic>);
    expect(back.timeControl, '5+0');
    expect(back.isTimed, isTrue);
    expect(back.endedOnTime, isTrue);

    final old = GameRecord.fromJson({
      'id': '2',
      'at': '2026-09-01T10:00:00.000',
      'level': 1,
      'white': false,
      'uci': <String>[],
      'san': <String>[],
      'result': 'draw',
    });
    expect(old.isTimed, isFalse);
    expect(old.endedOnTime, isFalse);
  });
}
