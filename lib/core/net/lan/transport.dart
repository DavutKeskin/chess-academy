import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Satır tabanlı, iki yönlü bağlantı. Oturum bunun üstünde JSON satırları taşır;
/// TCP soket dışında (testte bellek içi, ileride bir WebSocket aktarıcı) da uygulanabilir.
abstract class Transport {
  /// Karşı taraftan gelen satırlar (satır sonu olmadan). Bağlantı kopunca kapanır.
  Stream<String> get lines;

  /// Tek bir satır gönderir; satır sonu eklenir.
  void send(String line);

  /// Bağlantıyı kapatır; birden fazla çağrılabilir.
  Future<void> close();
}

/// Ham TCP soket üstünde UTF-8, satır sonuyla ayrılmış aktarım.
class SocketTransport implements Transport {
  SocketTransport(this._socket) {
    _socket.setOption(SocketOption.tcpNoDelay, true);
    _lines = _socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .handleError((Object _) {}) // kopan bağlantı hata değil, akışın kapanması
        .asBroadcastStream();
  }

  final Socket _socket;
  late final Stream<String> _lines;
  bool _closed = false;

  @override
  Stream<String> get lines => _lines;

  @override
  void send(String line) {
    if (_closed) return;
    try {
      _socket.write('$line\n');
    } catch (_) {
      // Soket kapanmışsa gönderim sessizce düşer; kopuş akış kapanınca fark edilir.
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      await _socket.close();
    } catch (_) {}
    _socket.destroy();
  }
}

/// Bellek içi çift: [FakeTransport.pair] ile iki uç birbirine bağlı üretilir (testler için).
class FakeTransport implements Transport {
  FakeTransport._();

  static (FakeTransport, FakeTransport) pair() {
    final a = FakeTransport._();
    final b = FakeTransport._();
    a._peer = b;
    b._peer = a;
    return (a, b);
  }

  late FakeTransport _peer;
  final _incoming = StreamController<String>.broadcast();
  bool _closed = false;

  /// Gönderilen satırlar (doğrulama için).
  final List<String> sent = [];

  bool get isClosed => _closed;

  @override
  Stream<String> get lines => _incoming.stream;

  @override
  void send(String line) {
    if (_closed) return;
    sent.add(line);
    // Gerçek soket gibi asenkron teslim.
    scheduleMicrotask(() {
      if (!_peer._closed) _peer._incoming.add(line);
    });
  }

  /// Karşı tarafa gönderilmeden yalnızca bu uca satır enjekte eder (bozuk mesaj testleri).
  void inject(String line) {
    if (!_closed) _incoming.add(line);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _incoming.close();
    // Karşı taraf da kopuşu görür.
    await _peer.close();
  }
}
