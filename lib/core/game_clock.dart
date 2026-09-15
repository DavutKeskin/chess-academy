import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';

/// Oyun süresi: her oyuncuya [minutes] dakika, her hamleden sonra
/// [incrementSeconds] saniye eklenir. [unlimited] saat kullanılmaz.
class TimeControl {
  const TimeControl(this.minutes, this.incrementSeconds);

  final int minutes;
  final int incrementSeconds;

  static const unlimited = TimeControl(0, 0);

  /// Kurulum ekranında sunulan seçenekler (çocuklar için kısa ve anlaşılır).
  static const presets = [
    unlimited,
    TimeControl(3, 2),
    TimeControl(5, 0),
    TimeControl(10, 0),
    TimeControl(15, 10),
  ];

  bool get isUnlimited => minutes == 0;
  Duration get initial => Duration(minutes: minutes);
  Duration get increment => Duration(seconds: incrementSeconds);

  /// Kayıt ve ayarlarda saklanan kısa biçim: "5+0", süresizde "none".
  String get code => isUnlimited ? 'none' : '$minutes+$incrementSeconds';

  static TimeControl parse(String? code) {
    if (code == null || code == 'none') return unlimited;
    final parts = code.split('+');
    final m = int.tryParse(parts[0]) ?? 0;
    final s = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return m <= 0 ? unlimited : TimeControl(m, s);
  }

  @override
  bool operator ==(Object other) =>
      other is TimeControl && other.minutes == minutes && other.incrementSeconds == incrementSeconds;

  @override
  int get hashCode => Object.hash(minutes, incrementSeconds);

  @override
  String toString() => code;
}

/// İki taraflı satranç saati. Kalan süreler yalnızca [press]/[pause] anlarında
/// hesaba yazılır; arada geçen zaman [remaining] içinde canlı hesaplanır.
/// Süre biterse [onFlag] bir kez çağrılır ve saat durur.
class GameClock extends ChangeNotifier {
  GameClock(
    this.control, {
    this.onFlag,
    DateTime Function()? now,
    this.withTimer = true,
  })  : _now = now ?? DateTime.now,
        _white = control.initial,
        _black = control.initial;

  final TimeControl control;
  final void Function(Side side)? onFlag;
  final DateTime Function() _now;
  final bool withTimer;

  Duration _white;
  Duration _black;
  Side? _running;
  Side? _paused;
  DateTime? _since;
  Timer? _timer;
  bool _flagged = false;

  /// Şu an sayan taraf; durmuşsa null.
  Side? get running => _running;
  bool get isRunning => _running != null;
  bool get flagged => _flagged;

  /// Oyun başladı mı (ilk hamle yapıldı mı)?
  bool get started => _running != null || _paused != null || _flagged;

  Duration remaining(Side side) {
    var base = side == Side.white ? _white : _black;
    if (_running == side && _since != null) base -= _now().difference(_since!);
    return base.isNegative ? Duration.zero : base;
  }

  /// [side] tarafının saatini başlatır (diğeri duruyorsa olduğu yerde kalır).
  void start(Side side) {
    if (_flagged) return;
    _settle();
    _running = side;
    _paused = null;
    _since = _now();
    _ensureTimer();
    notifyListeners();
  }

  /// [moved] tarafı hamlesini yaptı: süresi sayıyorduysa ek saniye alır,
  /// saat karşı tarafa geçer. İlk hamlede saati başlatır.
  void press(Side moved) {
    if (_flagged) return;
    _settle();
    if (_running == moved) {
      if (moved == Side.white) {
        _white += control.increment;
      } else {
        _black += control.increment;
      }
    }
    _running = moved.opposite;
    _paused = null;
    _since = _now();
    _ensureTimer();
    notifyListeners();
  }

  /// Uygulama arka plana gidince: sayan tarafı hatırlayıp durur.
  void pause() {
    if (_running == null) return;
    _settle();
    _paused = _running;
    _running = null;
    _since = null;
    _stopTimer();
    notifyListeners();
  }

  void resume() {
    final side = _paused;
    if (side == null || _flagged) return;
    start(side);
  }

  /// Oyun bitti: saat durur, kalan süreler korunur.
  void stop() {
    _settle();
    _running = null;
    _paused = null;
    _since = null;
    _stopTimer();
    notifyListeners();
  }

  /// Yeni oyun için başa döner.
  void reset() {
    _stopTimer();
    _white = control.initial;
    _black = control.initial;
    _running = null;
    _paused = null;
    _since = null;
    _flagged = false;
    notifyListeners();
  }

  /// Zaman kontrolü: süre bittiyse bayrağı düşürür. Zamanlayıcı bunu
  /// düzenli çağırır; testler doğrudan çağırabilir.
  @visibleForTesting
  void tick() {
    final side = _running;
    if (side == null) return;
    if (remaining(side) == Duration.zero) {
      _settle();
      _running = null;
      _since = null;
      _flagged = true;
      _stopTimer();
      notifyListeners();
      onFlag?.call(side);
      return;
    }
    notifyListeners();
  }

  void _settle() {
    final side = _running;
    final since = _since;
    if (side == null || since == null) return;
    final elapsed = _now().difference(since);
    if (side == Side.white) {
      _white -= elapsed;
      if (_white.isNegative) _white = Duration.zero;
    } else {
      _black -= elapsed;
      if (_black.isNegative) _black = Duration.zero;
    }
    _since = _now();
  }

  void _ensureTimer() {
    if (!withTimer || _timer != null) return;
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => tick());
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }
}

/// Saat üzerinde gösterilecek metin: 10 saniyenin altında onda saniye görünür.
String formatClock(Duration d) {
  final tenths = (d.inMilliseconds / 100).ceil();
  if (tenths < 100) return '0:0${tenths ~/ 10}.${tenths % 10}';
  final totalSeconds = (d.inMilliseconds / 1000).ceil();
  final m = totalSeconds ~/ 60;
  final s = totalSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}
