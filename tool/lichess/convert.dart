// Süzülmüş Lichess CSV'lerini uygulama JSON varlıklarına çevirir ve her bulmacayı
// dartchess ile doğrular (rakip hamlesi uygulanır, çözüm legal olmalı, mat ile bitmeli).
//
// Çalıştırma (proje kökünden): dart run tool/lichess/convert.dart
import 'dart:convert';
import 'dart:io' as io;

import 'package:dartchess/dartchess.dart';

void main() {
  final specs = {
    'selected_mate_in_1.csv': ('mate_in_1.json', 'mateIn1'),
    'selected_mate_in_2.csv': ('mate_in_2.json', 'mateIn2'),
  };
  for (final entry in specs.entries) {
    final input = io.File('tool/lichess/${entry.key}');
    if (!input.existsSync()) {
      io.stderr.writeln('yok: ${input.path}');
      continue;
    }
    final lines = input.readAsLinesSync();
    final out = <Map<String, Object>>[];
    var rejected = 0;
    for (final line in lines.skip(1)) {
      final cols = _parseCsv(line);
      if (cols.length < 5) continue;
      final id = cols[0];
      final moves = cols[2].split(' ');
      final rating = int.tryParse(cols[3]) ?? 0;
      final themes = cols[4].split(' ');
      try {
        Position pos = Chess.fromSetup(Setup.parseFen(cols[1]));
        final opp = NormalMove.fromUci(moves.first);
        if (!pos.isLegal(opp)) throw StateError('rakip hamlesi legal değil');
        pos = pos.play(opp);
        final startFen = pos.fen;
        final solution = moves.sublist(1);
        Position p = pos;
        for (final uci in solution) {
          final m = NormalMove.fromUci(uci);
          if (!p.isLegal(m)) throw StateError('çözüm hamlesi legal değil: $uci');
          p = p.play(m);
        }
        if (!p.isCheckmate) throw StateError('mat ile bitmiyor');
        if (solution.length.isEven) throw StateError('çözüm oyuncu hamlesiyle bitmeli');
        out.add({
          'id': id,
          'fen': startFen,
          'last': moves.first,
          'moves': solution,
          'rating': rating,
          'themes': themes,
        });
      } catch (e) {
        rejected++;
        io.stderr.writeln('$id atlandı: $e');
      }
    }
    final target = io.File('assets/puzzles/${entry.value.$1}');
    target.createSync(recursive: true);
    target.writeAsStringSync(const JsonEncoder.withIndent(' ').convert({
      'category': entry.value.$2,
      'source': 'lichess.org açık bulmaca veritabanı (CC0)',
      'puzzles': out,
    }));
    io.stdout.writeln('${entry.value.$1}: ${out.length} bulmaca yazıldı, $rejected atlandı');
  }
}

List<String> _parseCsv(String line) {
  final result = <String>[];
  final buf = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (c == '"') {
      inQuotes = !inQuotes;
    } else if (c == ',' && !inQuotes) {
      result.add(buf.toString());
      buf.clear();
    } else {
      buf.write(c);
    }
  }
  result.add(buf.toString());
  return result;
}
