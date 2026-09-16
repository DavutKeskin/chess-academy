import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chess_academy/features/lessons/lessons.dart';
import 'package:chess_academy/l10n/l10n.dart';
import 'package:flutter/widgets.dart';

/// Ders adımlarındaki FEN'ler geçerli, görevlerdeki hamleler legal olmalı.
void main() {
  final lessons = buildLessons(lookupAppLocalizations(const Locale('tr')));

  test('tüm diller dersleri üretebiliyor', () {
    for (final loc in AppLocalizations.supportedLocales) {
      final l = buildLessons(lookupAppLocalizations(loc));
      expect(l.length, 20, reason: loc.toString());
      for (final lesson in l) {
        expect(lesson.title.trim(), isNotEmpty, reason: '${loc.languageCode} ${lesson.id}');
        for (final s in lesson.steps) {
          expect(s.text.trim(), isNotEmpty, reason: '${loc.languageCode} ${lesson.id}');
        }
      }
    }
  });

  test('ders id\'leri benzersiz', () {
    expect(lessons.map((l) => l.id).toSet().length, lessons.length);
  });

  test('20 ders var', () => expect(lessons.length, 20));

  test('ilk 8 ders ücretsiz, gerisi ücretli', () {
    expect(freeLessonCount, 8);
    expect(isPremiumLesson(7), isFalse);
    expect(isPremiumLesson(8), isTrue);
  });

  test('pat dersi: vezir f7 gerçekten pat eder', () {
    final pos = Chess.fromSetup(Setup.parseFen('7k/4Q3/6K1/8/8/8/8/8 w - - 0 1'));
    final after = pos.play(NormalMove.fromUci('e7f7'));
    expect(after.isStalemate, isTrue);
  });

  test('şahtan kurtulma dersi: başlangıç konumlarında beyaz şah tehdit altında', () {
    final lesson = lessons.firstWhere((l) => l.id == 'escape_check');
    for (final step in lesson.steps) {
      expect(Chess.fromSetup(Setup.parseFen(step.fen)).isCheck, isTrue, reason: step.fen);
    }
  });

  test('çatal dersi: Nd6 sonrası vezir at tarafından tehdit altında', () {
    final pos = Chess.fromSetup(Setup.parseFen('2q1k3/8/8/8/4N3/8/8/4K3 w - - 0 1'));
    final after = pos.play(NormalMove.fromUci('e4d6'));
    final knightAttacks = after.board.attacksTo(Square.fromName('c8'), Side.white);
    expect(knightAttacks.has(Square.fromName('d6')), isTrue);
  });

  for (final l in lessons) {
    for (var i = 0; i < l.steps.length; i++) {
      final step = l.steps[i];
      test('${l.id} adım ${i + 1}: FEN geçerli ve görev oynanabilir', () {
        final setup = Setup.parseFen(step.fen);
        final task = step.task;
        if (task == null) return;
        final pos = Chess.fromSetup(setup);
        final from = Square.fromName(task.from);
        expect(pos.board.pieceAt(from), isNotNull, reason: '${task.from} boş');
        final legal = makeLegalMoves(pos)[from] ?? const <Square>{};
        for (final t in task.targets) {
          expect(
            legal.contains(Square.fromName(t)),
            isTrue,
            reason: '${task.from}->$t legal değil',
          );
        }
      });
    }
  }

  test('at L köşesi: önce iki kare düz', () {
    Square sq(String n) => Square.fromName(n);
    expect(knightCorner(sq('b1'), sq('c3')), sq('b3'));
    expect(knightCorner(sq('b1'), sq('a3')), sq('b3'));
    expect(knightCorner(sq('b1'), sq('d2')), sq('d1'));
    expect(knightCorner(sq('e4'), sq('d6')), sq('e6'));
    expect(knightCorner(sq('e4'), sq('c3')), sq('c4'));
  });

  test('açıklama okları geçerli karelerde', () {
    for (final lesson in lessons) {
      for (final step in lesson.steps) {
        for (final a in step.arrows) {
          expect(a.length, 4, reason: '${lesson.id}: $a');
          expect(Square.fromName(a.substring(0, 2)) != Square.fromName(a.substring(2)), isTrue);
        }
      }
    }
  });
}
