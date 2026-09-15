import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import 'settings_store.dart';

/// Ses ve titreşim geri bildirimi. Sesler `assets/sounds/` altında kısa WAV'lar;
/// açılışta önbelleğe alınır. Ayarlardan kapatılabilir.
class AppFeedback {
  AppFeedback._();
  static final AppFeedback instance = AppFeedback._();

  static const _names = ['move', 'capture', 'correct', 'wrong', 'win', 'lose'];
  final Map<String, AudioPlayer> _players = {};
  bool _ready = false;

  Future<void> init() async {
    try {
      await AudioCache.instance.loadAll([for (final n in _names) 'sounds/$n.wav']);
      for (final n in _names) {
        final p = AudioPlayer();
        await p.setPlayerMode(PlayerMode.lowLatency);
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setSource(AssetSource('sounds/$n.wav'));
        _players[n] = p;
      }
      _ready = true;
    } catch (_) {
      // Ses yoksa uygulama sessiz çalışır.
    }
  }

  Future<void> _play(String name) async {
    if (!_ready || !SettingsStore.instance.soundOn) return;
    final p = _players[name];
    if (p == null) return;
    try {
      await p.stop();
      await p.resume();
    } catch (_) {}
  }

  Future<void> _haptic(Future<void> Function() fn) async {
    if (!SettingsStore.instance.hapticsOn) return;
    try {
      await fn();
    } catch (_) {}
  }

  void move({bool capture = false}) {
    _play(capture ? 'capture' : 'move');
    _haptic(HapticFeedback.selectionClick);
  }

  void correct() {
    _play('correct');
    _haptic(HapticFeedback.lightImpact);
  }

  void wrong() {
    _play('wrong');
    _haptic(HapticFeedback.mediumImpact);
  }

  void win() {
    _play('win');
    _haptic(HapticFeedback.heavyImpact);
  }

  void lose() {
    _play('lose');
    _haptic(HapticFeedback.mediumImpact);
  }
}
