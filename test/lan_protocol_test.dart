import 'package:chess_academy/core/net/lan/protocol.dart';
import 'package:chess_academy/core/net/lan/room_emoji.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LanMessage', () {
    test('her mesaj türü kodlanıp geri çözülür', () {
      final msgs = <LanMessage>[
        const HelloMessage(),
        const WelcomeMessage(hostSide: Side.black),
        const MoveMessage(ply: 4, uci: 'e7e8q'),
        const ResignMessage(),
        const PingMessage(),
        const PongMessage(),
        const ErrorMessage(ErrorMessage.busy),
      ];
      for (final m in msgs) {
        final back = LanMessage.decode(m.encode());
        expect(back, isNotNull, reason: m.encode());
        expect(back.runtimeType, m.runtimeType);
        expect(back!.encode(), m.encode());
      }
      expect((LanMessage.decode(const WelcomeMessage(hostSide: Side.black).encode()) as WelcomeMessage).hostSide,
          Side.black);
      expect((LanMessage.decode(const MoveMessage(ply: 4, uci: 'e7e8q').encode()) as MoveMessage).ply, 4);
    });

    test('bozuk ya da tanınmayan satırlar null döner', () {
      expect(LanMessage.decode('bu json değil'), isNull);
      expect(LanMessage.decode('[1,2]'), isNull);
      expect(LanMessage.decode('{"t":"dans"}'), isNull);
      expect(LanMessage.decode('{"t":"move","ply":"iki","uci":"e2e4"}'), isNull);
      expect(LanMessage.decode('{"t":"welcome","proto":1,"hostSide":"x"}'), isNull);
      expect(LanMessage.decode('{"t":"hello","proto":1}'), isNull);
    });

    test('hello uyumluluğu sürüm ve uygulama kimliğine bakar', () {
      expect(const HelloMessage().isCompatible, isTrue);
      expect(const HelloMessage(proto: 99).isCompatible, isFalse);
      expect(const HelloMessage(app: 'dama').isCompatible, isFalse);
    });
  });

  group('oda emojisi', () {
    test('rastgele üç farklı indeks üretilir ve metne çevrilir', () {
      for (var i = 0; i < 50; i++) {
        final e = randomRoomEmoji();
        expect(e.length, 3);
        expect(e.toSet().length, 3);
        expect(roomEmojiText(e).split(' ').length, 3);
      }
    });

    test('TXT kodlaması gidiş dönüş; geçersiz indeksler atlanır', () {
      expect(decodeRoomEmoji(encodeRoomEmoji([3, 17, 21])), [3, 17, 21]);
      expect(decodeRoomEmoji('1,abc,999,-1,2'), [1, 2]);
      expect(decodeRoomEmoji(null), isEmpty);
      expect(decodeRoomEmoji(''), isEmpty);
      expect(roomEmojiText([0, 500]), roomEmoji[0]);
    });
  });
}
