import '../../l10n/l10n.dart';

/// Bulmaca modeli ve elle hazırlanmış başlangıç bulmacaları.
///
/// Bir bulmaca: başlangıç konumu [fen] (sıra çözen oyuncuda), rakibin son hamlesi
/// [lastMove] (tahtada vurgulanır) ve çözüm hamleleri [moves]. Çözüm oyuncu hamlesiyle
/// başlar, rakip cevaplarıyla dönüşümlü ilerler ve oyuncu hamlesiyle biter.
/// Son hamlede herhangi bir mat kabul edilir; ara hamleler birebir eşleşmelidir.
class Puzzle {
  const Puzzle({
    required this.id,
    required this.fen,
    required this.moves,
    this.lastMove,
    this.title,
    this.hint,
    this.rating,
    this.themes = const [],
  });

  final String id;
  final String fen;
  final List<String> moves;
  final String? lastMove;
  final String? title;
  final String? hint;
  final int? rating;
  final List<String> themes;

  bool get whiteToMove => fen.split(' ')[1] == 'w';

  /// Oyuncunun kaç hamle yapacağı (1 = tek hamlede mat, 2 = iki hamlede mat).
  int get playerMoveCount => (moves.length + 1) ~/ 2;

  factory Puzzle.fromJson(Map<String, dynamic> j) => Puzzle(
        id: j['id'] as String,
        fen: j['fen'] as String,
        moves: (j['moves'] as List).cast<String>(),
        lastMove: j['last'] as String?,
        rating: j['rating'] as int?,
        themes: (j['themes'] as List?)?.cast<String>() ?? const [],
      );
}

/// Elle hazırlanmış, isimli başlangıç bulmacaları. Testler her birinin
/// konumdaki TÜM tek hamle matlarını `moves` listesinde... değil; tek çözümü
/// listeler, alternatif matlar ekranda yine kabul edilir (son hamle kuralı).
const starterPuzzles = <Puzzle>[
  Puzzle(id: 'p01', fen: '6k1/5ppp/8/8/8/8/8/4R1K1 w - - 0 1', moves: ['e1e8']),
  Puzzle(id: 'p02', fen: 'r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4', moves: ['h5f7']),
  Puzzle(id: 'p03', fen: 'rnbqkbnr/pppp1ppp/8/4p3/6P1/5P2/PPPPP2P/RNBQKBNR b KQkq g3 0 2', moves: ['d8h4']),
  Puzzle(id: 'p04', fen: '6rk/6pp/8/6N1/8/8/8/6K1 w - - 0 1', moves: ['g5f7']),
  Puzzle(id: 'p05', fen: '7k/5Q2/6K1/8/8/8/8/8 w - - 0 1', moves: ['f7g7']),
  Puzzle(id: 'p06', fen: 'k7/6R1/8/8/8/8/8/6KR w - - 0 1', moves: ['h1h8']),
  Puzzle(id: 'p07', fen: '6k1/5ppp/8/8/8/8/5PPP/3Q2K1 w - - 0 1', moves: ['d1d8']),
  Puzzle(id: 'p08', fen: '6k1/1r6/8/8/8/8/r7/7K b - - 0 1', moves: ['b7b1']),
  Puzzle(id: 'p09', fen: 'r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5Q2/PPPP1PPP/RNB1K1NR w KQkq - 2 3', moves: ['f3f7']),
  Puzzle(id: 'p10', fen: '7k/6pp/8/8/8/8/8/R6K w - - 0 1', moves: ['a1a8']),
  Puzzle(id: 'p11', fen: '6k1/8/8/8/4n3/8/6PP/6RK b - - 0 1', moves: ['e4f2']),
];

/// Başlangıç bulmacalarının dile göre başlığı.
String? starterTitle(AppLocalizations t, String id) => switch (id) {
      'p01' => t.puzzle_p01_title,
      'p02' => t.puzzle_p02_title,
      'p03' => t.puzzle_p03_title,
      'p04' => t.puzzle_p04_title,
      'p05' => t.puzzle_p05_title,
      'p06' => t.puzzle_p06_title,
      'p07' => t.puzzle_p07_title,
      'p08' => t.puzzle_p08_title,
      'p09' => t.puzzle_p09_title,
      'p10' => t.puzzle_p10_title,
      'p11' => t.puzzle_p11_title,
      _ => null,
    };

/// Başlangıç bulmacalarının dile göre ipucu.
String? starterHint(AppLocalizations t, String id) => switch (id) {
      'p01' => t.puzzle_p01_hint,
      'p02' => t.puzzle_p02_hint,
      'p03' => t.puzzle_p03_hint,
      'p04' => t.puzzle_p04_hint,
      'p05' => t.puzzle_p05_hint,
      'p06' => t.puzzle_p06_hint,
      'p07' => t.puzzle_p07_hint,
      'p08' => t.puzzle_p08_hint,
      'p09' => t.puzzle_p09_hint,
      'p10' => t.puzzle_p10_hint,
      'p11' => t.puzzle_p11_hint,
      _ => null,
    };
