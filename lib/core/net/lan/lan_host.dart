import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:dartchess/dartchess.dart';

import 'lan_discovery.dart';
import 'lan_session.dart';
import 'protocol.dart';
import 'transport.dart';

/// Oda: dinleyen TCP soketi + mDNS duyurusu. İlk uyumlu konukla oturum kurar,
/// sonrakileri `busy` ile reddeder.
class LanHost {
  LanHost({
    Side? sideChoice,
    required this.emoji,
    RoomAdvertiser? advertiser,
    Random? rng,
  })  : _rng = rng ?? Random(),
        _advertiser = advertiser ?? RoomAdvertiser.platform(),
        sideCode = sideChoice == null ? 'r' : (sideChoice == Side.white ? 'w' : 'b') {
    hostSide = sideChoice ?? (_rng.nextBool() ? Side.white : Side.black);
  }

  final List<int> emoji;
  final Random _rng;
  final RoomAdvertiser _advertiser;

  /// Duyuruda görünen seçim: 'w' | 'b' | 'r'.
  final String sideCode;

  /// Kesinleşmiş renk (rastgele seçildiyse burada çözülmüştür).
  late final Side hostSide;

  ServerSocket? _server;
  StreamSubscription<Socket>? _accept;
  LanSession? _session;
  final _guest = Completer<LanSession>();
  bool _closed = false;

  int get port => _server?.port ?? 0;

  /// Konuk bağlanıp el sıkışma bitince tamamlanır. [close] çağrılırsa hata verir.
  Future<LanSession> get guest => _guest.future;

  /// Soketi açar ve odayı duyurur.
  Future<void> start() async {
    final server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    _server = server;
    _accept = server.listen(_onConnection, onError: (Object _) {});
    await _advertiser.start(
      name: LanRoom.randomName(_rng),
      port: server.port,
      txt: LanRoom.txtFor(emoji: emoji, hostSide: sideCode),
    );
  }

  Future<void> _onConnection(Socket socket) async {
    final transport = SocketTransport(socket);
    if (_session != null || _closed) {
      transport.send(const ErrorMessage(ErrorMessage.busy).encode());
      await transport.close();
      return;
    }
    final session = LanSession(transport: transport, isHost: true, hostSide: hostSide);
    _session = session;
    try {
      await session.handshake();
    } catch (_) {
      // Uyumsuz konuk: oda açık kalır, sıradaki bağlantı denenir.
      _session = null;
      await session.close();
      return;
    }
    if (_closed) {
      await session.close();
      return;
    }
    await _stopListening();
    if (!_guest.isCompleted) _guest.complete(session);
  }

  Future<void> _stopListening() async {
    await _advertiser.stop();
    await _accept?.cancel();
    _accept = null;
    await _server?.close();
    _server = null;
  }

  /// Odayı kapatır. Kurulmuş oturum varsa ona dokunmaz (oyun ekranı sahiplenir).
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _stopListening();
    if (!_guest.isCompleted) {
      _guest.completeError(const LanHandshakeException('closed'));
      // Sahipsiz hata olarak düşmesin.
      _guest.future.ignore();
      await _session?.close();
    }
  }
}

/// Konuk tarafı: verilen adrese bağlanıp el sıkışmayı tamamlar.
class LanGuest {
  static Future<LanSession> connect(
    String address,
    int port, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final socket = await Socket.connect(address, port, timeout: timeout);
    final session = LanSession(transport: SocketTransport(socket), isHost: false);
    try {
      await session.handshake();
    } catch (_) {
      await session.close();
      rethrow;
    }
    return session;
  }
}
