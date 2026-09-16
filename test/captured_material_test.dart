import 'package:chess_academy/core/captured_material.dart';
import 'package:chess_academy/core/widgets/captured_pieces.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Position _play(List<String> uci) {
  Position pos = Chess.initial;
  for (final m in uci) {
    pos = pos.play(Move.parse(m)!);
  }
  return pos;
}

void main() {
  test('başlangıçta alınan taş ve fark yok', () {
    final m = CapturedMaterial.of(Chess.initial.board);
    for (final side in Side.values) {
      expect(m.capturedBy(side), isEmpty);
      expect(m.advantage(side), 0);
    }
  });

  test('alınan taşlar piyondan vezire sıralı, fark önde olana yazılır', () {
    // 1.e4 d5 2.exd5 Qxd5 3.Nc3 Qxa2 4.Rxa2 : beyaz piyon+vezir aldı, siyah iki piyon.
    final pos = _play(['e2e4', 'd7d5', 'e4d5', 'd8d5', 'b1c3', 'd5a2', 'a1a2']);
    final m = CapturedMaterial.of(pos.board);
    expect(m.capturedBy(Side.white), [Role.pawn, Role.queen]);
    expect(m.capturedBy(Side.black), [Role.pawn, Role.pawn]);
    expect(m.advantage(Side.white), 8);
    expect(m.advantage(Side.black), 0);
  });

  test('terfi eden piyon alınmış sayılmaz, puan farkına vezir olarak girer', () {
    // Beyazın e piyonu terfi edip vezir olmuş; siyahta yalnızca şah ve altı piyon kalmış.
    final pos = Chess.fromSetup(Setup.parseFen('4Q2k/pppp2pp/8/8/8/8/PPPP1PPP/RNBQKBNR b KQ - 0 1'));
    final m = CapturedMaterial.of(pos.board);
    expect(m.capturedBy(Side.black), isEmpty);
    expect(m.capturedBy(Side.white), [
      Role.pawn, Role.pawn, Role.knight, Role.knight, Role.bishop, Role.bishop, Role.rook, Role.rook, Role.queen,
    ]);
    expect(m.advantage(Side.white), 47 - 6);
  });

  testWidgets('oyuncu satırı dar ekranda saatle birlikte taşmıyor', (tester) async {
    final pos = Chess.fromSetup(Setup.parseFen('4Q2k/pppp2pp/8/8/8/8/PPPP1PPP/RNBQKBNR b KQ - 0 1'));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 280,
            child: PlayerMaterialRow(
              label: 'Bilgisayar',
              side: Side.white,
              material: CapturedMaterial.of(pos.board),
              trailing: const SizedBox(width: 110, height: 30),
            ),
          ),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(find.text('+41'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(9));
  });
}
