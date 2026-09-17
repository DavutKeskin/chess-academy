import 'dart:async';

import 'package:dartchess/dartchess.dart';

import 'bot/bot.dart';

/// Rakipten gelen, hamle dışı olaylar.
sealed class OpponentEvent {
  const OpponentEvent();
}

/// Rakip oyunu bıraktı: yerel oyuncu kazanır.
class OpponentResigned extends OpponentEvent {
  const OpponentResigned();
}

/// Rakiple bağlantı koptu ya da protokol hatası: oyun sonuçsuz biter.
class OpponentDisconnected extends OpponentEvent {
  const OpponentDisconnected(this.reason);
  final String reason;
}

/// Oyun ekranının rakibi: bilgisayar ya da ağ üstündeki arkadaş. Ekran hamle ister
/// ([nextMove]), kendi hamlesini bildirir ([onLocalMove]) ve olayları dinler.
abstract class Opponent {
  /// Rakip oynamaya hazır olunca tamamlanır (motor açıldı / bağlantı kuruldu).
  Future<void> get ready;

  /// İnsan rakip (ağ): ilerleme ve rozetler sayılmaz, yeniden başlatma yok.
  bool get isRemote;

  /// Rakibin [position] konumundaki hamlesi. Oyun bu arada başka yoldan bittiyse
  /// (bırakma, kopuş) null döner; ekran bunu görmezden gelir.
  Future<Move?> nextMove(Position position, {int? maxTimeMs});

  /// Yerel oyuncunun hamlesi işlendi ([ply] 0'dan başlar).
  void onLocalMove(Move move, int ply) {}

  /// Yerel oyuncu bıraktı.
  void resign() {}

  Stream<OpponentEvent> get events => const Stream.empty();

  Future<void> dispose() async {}
}

/// Bilgisayar rakip: Stockfish (telefon) ya da SimpleBot (masaüstü).
class BotOpponent extends Opponent {
  BotOpponent(this.level);

  final int level;
  late final Future<Bot> _bot = Bot.create(level);

  @override
  Future<void> get ready => _bot.then((_) {});

  @override
  bool get isRemote => false;

  @override
  Future<Move?> nextMove(Position position, {int? maxTimeMs}) async {
    final bot = await _bot;
    return bot.bestMove(position, maxTimeMs: maxTimeMs);
  }

  @override
  Future<void> dispose() async {
    final bot = await _bot;
    await bot.dispose();
  }
}
