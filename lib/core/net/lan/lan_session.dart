import 'dart:async';

import 'package:dartchess/dartchess.dart';

import 'protocol.dart';
import 'transport.dart';

/// Oturumdan arayüze giden olaylar.
sealed class LanEvent {
  const LanEvent();
}

/// Karşı taraf kurallara uygun bir hamle yaptı; oturumun konumu güncellendi.
class LanOpponentMove extends LanEvent {
  const LanOpponentMove(this.move, this.ply);
  final Move move;
  final int ply;
}

class LanOpponentResigned extends LanEvent {
  const LanOpponentResigned();
}

/// Bağlantı koptu ya da karşı taraf yanıt vermez oldu. Oyun biter.
class LanDisconnected extends LanEvent {
  const LanDisconnected(this.reason);

  /// 'closed' (akış kapandı), 'timeout' (ping yanıtı yok), 'error' (soket hatası).
  final String reason;
}

/// Protokol hatası: sürüm uyuşmazlığı, sırasız/kural dışı hamle, bozuk mesaj. Oyun biter.
class LanProtocolError extends LanEvent {
  const LanProtocolError(this.code);
  final String code;
}

enum LanSessionState { handshake, playing, ended }

/// Handshake çağrılmadan ya da tamamlanmadan oyun yapılırsa.
class LanHandshakeException implements Exception {
  const LanHandshakeException(this.code);

  /// 'proto', 'busy', 'closed', 'timeout', 'badMessage'
  final String code;

  @override
  String toString() => 'LanHandshakeException($code)';
}

/// İki cihaz arasındaki oyun oturumu: el sıkışma, hamle alışverişi, bırakma, ping.
/// Saf Dart; arayüzden bağımsız, sahte aktarımla test edilir.
///
/// Konum burada da tutulur: gelen hamle doğru yarı hamle numarasında ve konumda
/// kurallara uygun değilse oturum hata verip kapanır (MVP'de yeniden eşitleme yok).
class LanSession {
  LanSession({
    required Transport transport,
    required this.isHost,
    Side? hostSide,
    this.pingInterval = const Duration(seconds: 3),
    this.peerTimeout = const Duration(seconds: 10),
    this.handshakeTimeout = const Duration(seconds: 8),
  })  : _transport = transport, // ignore: prefer_initializing_formals
        _hostSide = hostSide; // ignore: prefer_initializing_formals

  final Transport _transport;
  final bool isHost;
  final Side? _hostSide;
  final Duration pingInterval;
  final Duration peerTimeout;
  final Duration handshakeTimeout;

  final _events = StreamController<LanEvent>.broadcast();
  StreamSubscription<String>? _sub;
  Timer? _pingTimer;
  DateTime _lastSeen = DateTime.now();

  Position _position = Chess.initial;
  int _ply = 0;
  Side? _localSide;
  LanSessionState _state = LanSessionState.handshake;
  bool _closed = false;

  Completer<LanMessage>? _handshakeCompleter;

  Stream<LanEvent> get events => _events.stream;
  Position get position => _position;
  int get ply => _ply;
  LanSessionState get state => _state;

  /// El sıkışma sonrası yerel taraf.
  Side get localSide => _localSide!;

  /// El sıkışmayı yapar ve yerel tarafı döner. Ev sahibi `hello` bekleyip `welcome`
  /// gönderir; konuk `hello` gönderip `welcome` bekler.
  Future<Side> handshake() async {
    if (_state != LanSessionState.handshake || _sub != null) {
      throw StateError('handshake already done');
    }
    final completer = _handshakeCompleter = Completer<LanMessage>();
    _sub = _transport.lines.listen(_onLine, onDone: _onClosed, onError: (Object _) => _onClosed());
    if (!isHost) _send(const HelloMessage());
    try {
      final first = await completer.future.timeout(handshakeTimeout);
      if (first is ErrorMessage) {
        // Karşı taraf reddetti (ya da bozuk mesajımıza yanıt olarak hata bildirildi).
        _end();
        throw LanHandshakeException(first.code);
      }
      if (isHost) {
        if (first is! HelloMessage || !first.isCompatible) {
          _failHandshake(ErrorMessage.proto);
        }
        final side = _hostSide ?? Side.white;
        _localSide = side;
        _send(WelcomeMessage(hostSide: side));
      } else {
        if (first is! WelcomeMessage) _failHandshake(ErrorMessage.badMessage);
        if (first.proto != lanProtocolVersion) _failHandshake(ErrorMessage.proto);
        _localSide = first.hostSide.opposite;
      }
    } on TimeoutException {
      _failHandshake('timeout');
    } finally {
      _handshakeCompleter = null;
    }
    _state = LanSessionState.playing;
    _lastSeen = DateTime.now();
    _pingTimer = Timer.periodic(pingInterval, (_) => _tick());
    return _localSide!;
  }

  Never _failHandshake(String code) {
    if (code == ErrorMessage.proto || code == ErrorMessage.badMessage) _send(ErrorMessage(code));
    _end();
    throw LanHandshakeException(code);
  }

  /// Yerel oyuncunun hamlesi: konuma işlenir ve karşıya gönderilir.
  void sendMove(Move move) {
    if (_state != LanSessionState.playing) return;
    if (_position.turn != _localSide || !_position.isLegal(move)) {
      throw StateError('illegal local move ${move.uci}');
    }
    final ply = _ply;
    _apply(move);
    _send(MoveMessage(ply: ply, uci: move.uci));
  }

  /// Yerel oyuncu bıraktı; karşıya bildirilir, oturum biter.
  void resign() {
    if (_state != LanSessionState.playing) return;
    _send(const ResignMessage());
    _end();
  }

  Future<void> close() async {
    _end();
    await _events.close();
  }

  void _apply(Move move) {
    _position = _position.play(move);
    _ply++;
  }

  void _onLine(String line) {
    _lastSeen = DateTime.now();
    final msg = LanMessage.decode(line);
    if (msg == null) {
      _protocolError(ErrorMessage.badMessage);
      return;
    }
    final handshake = _handshakeCompleter;
    if (handshake != null) {
      // El sıkışma sırasında ping/pong gelirse yok sayılır; ilk anlamlı mesaj değerlendirilir.
      if (msg is PingMessage || msg is PongMessage) return;
      if (!handshake.isCompleted) handshake.complete(msg);
      return;
    }
    if (_state != LanSessionState.playing) return;
    switch (msg) {
      case PingMessage():
        _send(const PongMessage());
      case PongMessage():
        break;
      case MoveMessage():
        _onMove(msg);
      case ResignMessage():
        _end();
        _emit(const LanOpponentResigned());
      case ErrorMessage():
        _end();
        _emit(LanProtocolError(msg.code));
      case HelloMessage():
      case WelcomeMessage():
        _protocolError(ErrorMessage.badMessage);
    }
  }

  void _onMove(MoveMessage msg) {
    final move = Move.parse(msg.uci);
    if (msg.ply != _ply || _position.turn == _localSide || move == null || !_position.isLegal(move)) {
      _protocolError(ErrorMessage.badMove);
      return;
    }
    final ply = _ply;
    _apply(move);
    _emit(LanOpponentMove(move, ply));
  }

  void _protocolError(String code) {
    if (_state == LanSessionState.ended) return;
    _send(ErrorMessage(code));
    final handshake = _handshakeCompleter;
    if (handshake != null && !handshake.isCompleted) {
      handshake.complete(ErrorMessage(code));
      return;
    }
    _end();
    _emit(LanProtocolError(code));
  }

  void _onClosed() {
    final handshake = _handshakeCompleter;
    if (handshake != null && !handshake.isCompleted) {
      handshake.completeError(const LanHandshakeException('closed'));
      return;
    }
    if (_state == LanSessionState.ended) return;
    _end();
    _emit(const LanDisconnected('closed'));
  }

  void _tick() {
    if (_state != LanSessionState.playing) return;
    if (DateTime.now().difference(_lastSeen) > peerTimeout) {
      _end();
      _emit(const LanDisconnected('timeout'));
      return;
    }
    _send(const PingMessage());
  }

  void _send(LanMessage msg) {
    if (_closed) return;
    _transport.send(msg.encode());
  }

  void _emit(LanEvent e) {
    if (!_events.isClosed) _events.add(e);
  }

  /// Oturumu sonlandırır: zamanlayıcı ve aktarım kapanır. Olay akışı açık kalır ki
  /// son olay iletilebilsin; [close] onu da kapatır.
  void _end() {
    if (_closed) return;
    _closed = true;
    _state = LanSessionState.ended;
    _pingTimer?.cancel();
    _sub?.cancel();
    // Kapanış asenkron; kapanış sırasında gelen kopuş olayı [_closed] ile ayıklanır.
    _transport.close();
  }
}
