import 'dart:convert';
import 'dart:io' as io;

import 'package:chess_academy/features/puzzles/puzzles.dart';
import 'package:chess_academy/l10n/l10n.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';

/// Her bulmacanın çözüm hattı legal olmalı ve mat ile bitmeli.
/// Başlangıç setinde ek olarak: tek hamle olan çözüm, konumdaki matlardan biri olmalı.
void main() {
  final all = <String, List<Puzzle>>{'starter': starterPuzzles};
  for (final name in ['mate_in_1', 'mate_in_2']) {
    final f = io.File('assets/puzzles/$name.json');
    if (!f.existsSync()) continue;
    final data = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    all[name] = [for (final j in data['puzzles'] as List) Puzzle.fromJson(j as Map<String, dynamic>)];
  }

  test('bulmaca id\'leri benzersiz (tüm setler)', () {
    final ids = all.values.expand((l) => l.map((p) => p.id)).toList();
    expect(ids.toSet().length, ids.length);
  });

  for (final entry in all.entries) {
    test('${entry.key}: ${entry.value.length} bulmacanın çözümü legal ve mat ile bitiyor', () {
      expect(entry.value, isNotEmpty);
      for (final p in entry.value) {
        Position pos = Chess.fromSetup(Setup.parseFen(p.fen));
        expect(pos.isGameOver, isFalse, reason: '${p.id}: oyun zaten bitmiş');
        expect(p.moves.length.isOdd, isTrue, reason: '${p.id}: çözüm oyuncu hamlesiyle bitmeli');
        if (p.lastMove != null) {
          // Son rakip hamlesi yalnızca vurgu içindir; kare adları geçerli olmalı.
          expect(() => NormalMove.fromUci(p.lastMove!), returnsNormally);
        }
        for (final uci in p.moves) {
          final m = NormalMove.fromUci(uci);
          expect(pos.isLegal(m), isTrue, reason: '${p.id}: $uci legal değil');
          pos = pos.playUnchecked(m);
        }
        expect(pos.isCheckmate, isTrue, reason: '${p.id}: mat ile bitmiyor');
      }
    });
  }

  test('starter: her dilde başlık ve ipucu var', () {
    for (final loc in AppLocalizations.supportedLocales) {
      final t = lookupAppLocalizations(loc);
      for (final p in starterPuzzles) {
        expect(starterTitle(t, p.id), isNotNull, reason: '${loc.languageCode} ${p.id}');
        expect(starterHint(t, p.id), isNotNull, reason: '${loc.languageCode} ${p.id}');
      }
    }
  });

  test('starter: her bulmaca tek hamlede mat ve çözüm bu matlardan biri', () {
    for (final p in starterPuzzles) {
      final pos = Chess.fromSetup(Setup.parseFen(p.fen));
      final mates = <String>{};
      for (final e in pos.legalMoves.entries) {
        for (final to in e.value.squares) {
          final piece = pos.board.pieceAt(e.key);
          final promo = piece?.role == Role.pawn && (to.rank == Rank.first || to.rank == Rank.eighth);
          for (final r in promo ? [Role.queen, Role.rook, Role.bishop, Role.knight] : <Role?>[null]) {
            final m = NormalMove(from: e.key, to: to, promotion: r);
            if (pos.playUnchecked(m).isCheckmate) mates.add(m.uci);
          }
        }
      }
      expect(p.moves.length, 1, reason: '${p.id}: başlangıç seti tek hamle');
      expect(mates, contains(p.moves.first), reason: p.id);
    }
  });
}
