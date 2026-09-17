import 'package:chess_academy/core/net/lan/lan_session.dart';
import 'package:chess_academy/core/net/lan/protocol.dart';
import 'package:chess_academy/core/net/lan/remote_opponent.dart';
import 'package:chess_academy/core/net/lan/transport.dart';
import 'package:chess_academy/core/opponent.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bağlı iki oturum: ev sahibi ve konuk, el sıkışması tamamlanmış.
Future<(LanSession host, LanSession guest, FakeTransport hostT, FakeTransport guestT)> connected({
  Side hostSide = Side.white,
  Duration ping = const Duration(seconds: 3),
  Duration timeout = const Duration(seconds: 10),
}) async {
  final (a, b) = FakeTransport.pair();
  final host = LanSession(transport: a, isHost: true, hostSide: hostSide, pingInterval: ping, peerTimeout: timeout);
  final guest = LanSession(transport: b, isHost: false, pingInterval: ping, peerTimeout: timeout);
  final sides = await Future.wait([host.handshake(), guest.handshake()]);
  expect(sides[0], hostSide);
  expect(sides[1], hostSide.opposite);
  return (host, guest, a, b);
}

Future<void> flush() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  test('el sıkışma: konuk hello gönderir, ev sahibi welcome ile rengi bildirir', () async {
    final (host, guest, hostT, guestT) = await connected(hostSide: Side.black);
    expect(guestT.sent.first, const HelloMessage().encode());
    expect(hostT.sent.first, const WelcomeMessage(hostSide: Side.black).encode());
    expect(host.state, LanSessionState.playing);
    expect(guest.state, LanSessionState.playing);
    await host.close();
    await guest.close();
  });

  test('kısa oyun (çoban matı): iki taraf da aynı son konuma varır', () async {
    final (host, guest, _, _) = await connected();
    final guestMoves = <LanEvent>[];
    final hostMoves = <LanEvent>[];
    host.events.listen(hostMoves.add);
    guest.events.listen(guestMoves.add);

    // Beyaz ev sahibi: f3, g4; siyah konuk: e5, Vh4#.
    host.sendMove(Move.parse('f2f3')!);
    await flush();
    expect(guest.position.turn, Side.black);
    guest.sendMove(Move.parse('e7e5')!);
    await flush();
    host.sendMove(Move.parse('g2g4')!);
    await flush();
    guest.sendMove(Move.parse('d8h4')!);
    await flush();

    expect(host.position.fen, guest.position.fen);
    expect(host.position.isCheckmate, isTrue);
    expect(host.ply, 4);
    expect(guest.ply, 4);
    expect(hostMoves.whereType<LanOpponentMove>().map((e) => e.move.uci), ['e7e5', 'd8h4']);
    expect(guestMoves.whereType<LanOpponentMove>().map((e) => e.move.uci), ['f2f3', 'g2g4']);
    expect(hostMoves.whereType<LanOpponentMove>().map((e) => e.ply), [1, 3]);
    await host.close();
    await guest.close();
  });

  test('sırası olmayan tarafın hamlesi kendi tarafında hata fırlatır, gönderilmez', () async {
    final (host, guest, _, guestT) = await connected();
    final before = guestT.sent.length;
    expect(() => guest.sendMove(Move.parse('e7e5')!), throwsStateError);
    expect(() => host.sendMove(Move.parse('e2e5')!), throwsStateError);
    expect(guestT.sent.length, before);
    await host.close();
    await guest.close();
  });

  test('kural dışı hamle gelirse iki taraf da protokol hatasıyla biter', () async {
    final (host, guest, hostT, guestT) = await connected();
    final hostEvents = <LanEvent>[];
    final guestEvents = <LanEvent>[];
    host.events.listen(hostEvents.add);
    guest.events.listen(guestEvents.add);
    // Konuk, sahte "hamle" enjekte eder: beyazın sırasında siyah taşla.
    hostT.inject(const MoveMessage(ply: 0, uci: 'e7e5').encode());
    await flush();
    expect(hostEvents.single, isA<LanProtocolError>().having((e) => e.code, 'code', ErrorMessage.badMove));
    expect(host.state, LanSessionState.ended);
    expect(hostT.sent.last, const ErrorMessage(ErrorMessage.badMove).encode());
    expect(guestEvents.first, isA<LanProtocolError>().having((e) => e.code, 'code', ErrorMessage.badMove));
    expect(guest.state, LanSessionState.ended);
    expect(guestT.isClosed, isTrue);
    await host.close();
    await guest.close();
  });

  test('yanlış yarı hamle numarası (sırasız hamle) hata sayılır', () async {
    final (host, guest, hostT, _) = await connected();
    final guestEvents = <LanEvent>[];
    guest.events.listen(guestEvents.add);
    host.sendMove(Move.parse('e2e4')!);
    await flush();
    // Ev sahibi aynı hamleyi tekrar gönderiyormuş gibi (ply 0 yerine 2 beklenir).
    hostT.send(const MoveMessage(ply: 0, uci: 'e2e4').encode());
    await flush();
    expect(guestEvents.whereType<LanProtocolError>().single.code, ErrorMessage.badMove);
    expect(guest.state, LanSessionState.ended);
    await host.close();
    await guest.close();
  });

  test('bozuk satır protokol hatasıdır', () async {
    final (host, guest, hostT, _) = await connected();
    final events = <LanEvent>[];
    host.events.listen(events.add);
    hostT.inject('{"t":');
    await flush();
    expect(events.single, isA<LanProtocolError>().having((e) => e.code, 'code', ErrorMessage.badMessage));
    await host.close();
    await guest.close();
  });

  test('bırakma karşı tarafa ulaşır ve iki oturum da biter', () async {
    final (host, guest, _, _) = await connected();
    final events = <LanEvent>[];
    guest.events.listen(events.add);
    host.sendMove(Move.parse('e2e4')!);
    await flush();
    host.resign();
    await flush();
    expect(events.whereType<LanOpponentResigned>().length, 1);
    expect(events.whereType<LanDisconnected>(), isEmpty, reason: 'bırakma sonrası kopuş ayrıca bildirilmez');
    expect(host.state, LanSessionState.ended);
    expect(guest.state, LanSessionState.ended);
    await host.close();
    await guest.close();
  });

  test('bağlantı kapanınca karşı taraf kopuş olayı alır', () async {
    final (host, guest, _, guestT) = await connected();
    final events = <LanEvent>[];
    host.events.listen(events.add);
    await guestT.close();
    await flush();
    expect(events.single, isA<LanDisconnected>().having((e) => e.reason, 'reason', 'closed'));
    expect(host.state, LanSessionState.ended);
    await host.close();
    await guest.close();
  });

  test('ping gider, pong döner; sessiz kalan taraf zaman aşımıyla kopmuş sayılır', () async {
    final (host, guest, hostT, guestT) = await connected(
      ping: const Duration(milliseconds: 20),
      timeout: const Duration(milliseconds: 80),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(hostT.sent.where((l) => l == const PingMessage().encode()), isNotEmpty);
    expect(guestT.sent.where((l) => l == const PongMessage().encode()), isNotEmpty);
    expect(host.state, LanSessionState.playing);

    // Konuk sustu: ev sahibinden gelenleri de yanıtlamıyor (kendi zamanlayıcısı kapatıldı).
    final events = <LanEvent>[];
    host.events.listen(events.add);
    await guest.close();
    await flush();
    // Konuk kapanınca akış kapanır -> 'closed'. Zaman aşımını sınamak için akışı
    // kapatmadan susan bir uç gerekir: enjekte edilen ayrı bir çift kullan.
    await host.close();
    expect(events.whereType<LanDisconnected>().single.reason, 'closed');

    final (a, b) = FakeTransport.pair();
    final h = LanSession(
      transport: a,
      isHost: true,
      hostSide: Side.white,
      pingInterval: const Duration(milliseconds: 20),
      peerTimeout: const Duration(milliseconds: 80),
    );
    final hEvents = <LanEvent>[];
    h.events.listen(hEvents.add);
    final hs = h.handshake();
    b.send(const HelloMessage().encode());
    await hs;
    // b hiç yanıt vermez.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(hEvents.single, isA<LanDisconnected>().having((e) => e.reason, 'reason', 'timeout'));
    expect(h.state, LanSessionState.ended);
    await h.close();
  });

  test('sürüm uyuşmazlığı: ev sahibi error{proto} gönderir, iki taraf da el sıkışmada kalır', () async {
    final (a, b) = FakeTransport.pair();
    final host = LanSession(transport: a, isHost: true, hostSide: Side.white);
    final hostResult = host.handshake();
    b.send(const HelloMessage(proto: 2).encode());
    await expectLater(hostResult, throwsA(isA<LanHandshakeException>().having((e) => e.code, 'code', 'proto')));
    expect(a.sent.single, const ErrorMessage(ErrorMessage.proto).encode());
    expect(host.state, LanSessionState.ended);
    await host.close();

    // Konuk tarafı: welcome yerine error alırsa aynı kodla başarısız olur.
    final (c, d) = FakeTransport.pair();
    final guest = LanSession(transport: c, isHost: false);
    final guestResult = guest.handshake();
    await flush();
    expect(d.sent, isEmpty);
    d.send(const ErrorMessage(ErrorMessage.proto).encode());
    await expectLater(guestResult, throwsA(isA<LanHandshakeException>().having((e) => e.code, 'code', 'proto')));
    await guest.close();
  });

  test('konuk welcome içinde farklı sürüm görürse reddeder', () async {
    final (c, d) = FakeTransport.pair();
    final guest = LanSession(transport: c, isHost: false);
    final guestResult = guest.handshake();
    d.send(const WelcomeMessage(proto: 7, hostSide: Side.white).encode());
    await expectLater(guestResult, throwsA(isA<LanHandshakeException>().having((e) => e.code, 'code', 'proto')));
    expect(c.sent.last, const ErrorMessage(ErrorMessage.proto).encode());
    await guest.close();
  });

  test('el sıkışma zaman aşımı', () async {
    final (a, _) = FakeTransport.pair();
    final host = LanSession(transport: a, isHost: true, handshakeTimeout: const Duration(milliseconds: 30));
    await expectLater(host.handshake(), throwsA(isA<LanHandshakeException>().having((e) => e.code, 'code', 'timeout')));
    await host.close();
  });

  test('el sıkışma sırasında karşı taraf kapanırsa closed', () async {
    final (a, b) = FakeTransport.pair();
    final host = LanSession(transport: a, isHost: true);
    final r = expectLater(host.handshake(), throwsA(isA<LanHandshakeException>().having((e) => e.code, 'code', 'closed')));
    await b.close();
    await r;
    await host.close();
  });

  group('RemoteOpponent', () {
    test('nextMove karşı hamleyle tamamlanır; bırakma olay olarak gelir ve bekleyen istek boş döner', () async {
      final (host, guest, _, _) = await connected();
      final me = RemoteOpponent(guest); // siyah
      final events = <OpponentEvent>[];
      me.events.listen(events.add);
      expect(me.isRemote, isTrue);

      final first = me.nextMove(guest.position);
      host.sendMove(Move.parse('e2e4')!);
      expect((await first)!.uci, 'e2e4');

      me.onLocalMove(Move.parse('e7e5')!, 1);
      await flush();
      expect(host.position.fen, guest.position.fen);

      final second = me.nextMove(guest.position);
      host.resign();
      expect(await second, isNull);
      await flush();
      expect(events.single, isA<OpponentResigned>());
      await me.dispose();
      await host.close();
    });

    test('istekten önce gelen hamle kuyruğa alınır; kopuş bildirilir', () async {
      final (host, guest, _, _) = await connected();
      final me = RemoteOpponent(guest);
      final events = <OpponentEvent>[];
      me.events.listen(events.add);
      host.sendMove(Move.parse('d2d4')!);
      await flush();
      expect((await me.nextMove(guest.position))!.uci, 'd2d4');
      await host.close();
      await flush();
      expect(events.single, isA<OpponentDisconnected>());
      expect(await me.nextMove(guest.position), isNull);
      await me.dispose();
    });

    test('resign oturumu bitirir ve karşıya ulaşır', () async {
      final (host, guest, _, _) = await connected();
      final me = RemoteOpponent(host);
      final events = <LanEvent>[];
      guest.events.listen(events.add);
      me.resign();
      await flush();
      expect(events.single, isA<LanOpponentResigned>());
      await me.dispose();
      await guest.close();
    });
  });
}
