import 'dart:async';

import 'package:dartchess/dartchess.dart';

import '../../opponent.dart';
import 'lan_session.dart';

/// Yerel ağdaki arkadaş: [LanSession] üstünden hamle alıp verir.
class RemoteOpponent extends Opponent {
  RemoteOpponent(this.session) {
    _sub = session.events.listen(_onEvent);
  }

  final LanSession session;
  late final StreamSubscription<LanEvent> _sub;
  final _events = StreamController<OpponentEvent>.broadcast();

  /// Ekran henüz istemeden gelen hamleler (kuramsal yarış durumu için).
  final _queue = <Move>[];
  Completer<Move?>? _pending;

  @override
  Future<void> get ready => Future.value();

  @override
  bool get isRemote => true;

  @override
  Stream<OpponentEvent> get events => _events.stream;

  @override
  Future<Move?> nextMove(Position position, {int? maxTimeMs}) {
    if (_queue.isNotEmpty) return Future.value(_queue.removeAt(0));
    if (session.state != LanSessionState.playing) return Future.value(null);
    final c = _pending = Completer<Move?>();
    return c.future;
  }

  @override
  void onLocalMove(Move move, int ply) => session.sendMove(move);

  @override
  void resign() => session.resign();

  void _onEvent(LanEvent e) {
    switch (e) {
      case LanOpponentMove():
        final p = _pending;
        if (p != null && !p.isCompleted) {
          _pending = null;
          p.complete(e.move);
        } else {
          _queue.add(e.move);
        }
      case LanOpponentResigned():
        _settle();
        _events.add(const OpponentResigned());
      case LanDisconnected():
        _settle();
        _events.add(OpponentDisconnected(e.reason));
      case LanProtocolError():
        _settle();
        _events.add(OpponentDisconnected(e.code));
    }
  }

  /// Bekleyen hamle isteği varsa boş döner: oyun başka yoldan bitti.
  void _settle() {
    final p = _pending;
    _pending = null;
    if (p != null && !p.isCompleted) p.complete(null);
  }

  @override
  Future<void> dispose() async {
    await _sub.cancel();
    _settle();
    await session.close();
    await _events.close();
  }
}
