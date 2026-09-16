import 'package:dartchess/dartchess.dart';

import '../../l10n/l10n.dart';

/// Ders içerikleri. Her ders adımlardan oluşur; adım bir açıklama,
/// gösterilecek konum (FEN) ve isteğe bağlı bir görev içerir.
/// Görev: verilen konumda, [from] karesindeki taşı [targets] içinden bir kareye taşımak.
class LessonStep {
  const LessonStep({required this.text, required this.fen, this.task, this.arrows = const []});

  final String text;
  final String fen;
  final MoveTask? task;

  /// Açıklama tahtasında çizilecek oklar, "b1b3" biçiminde (çıkış + varış karesi).
  final List<String> arrows;
}

/// Derste at okları için: at sıçrayışının L köşesi: önce iki kare düz gidilen kare.
Square knightCorner(Square from, Square to) {
  final dy = (to.rank - from.rank).abs();
  return dy == 2 ? Square.fromCoords(from.file, to.rank) : Square.fromCoords(to.file, from.rank);
}

class MoveTask {
  const MoveTask({
    required this.from,
    required this.targets,
    required this.success,
    this.mates = false,
    this.givesCheck = false,
  });

  /// Doğruysa test, her hedefin şah mat ettiğini doğrular.
  final bool mates;

  /// Doğruysa test, her hedefin şah çektiğini doğrular.
  final bool givesCheck;

  /// Taşınacak taşın karesi, örn. "a1".
  final String from;

  /// Kabul edilen hedef kareler, örn. ["a8"].
  final List<String> targets;

  /// Doğru hamle sonrası gösterilecek mesaj.
  final String success;
}

/// Ders grupları; listede başlık olarak görünür, sıra korunur.
enum LessonGroup {
  temel,
  kurallar,
  taktik,
  mat;

  String title(AppLocalizations t) => switch (this) {
        LessonGroup.temel => t.groupBasics,
        LessonGroup.kurallar => t.groupRules,
        LessonGroup.taktik => t.groupTactics,
        LessonGroup.mat => t.groupMates,
      };
}

class Lesson {
  const Lesson({
    required this.id,
    required this.title,
    required this.emoji,
    required this.steps,
    this.group = LessonGroup.temel,
  });

  final String id;
  final String title;
  final String emoji;
  final List<LessonStep> steps;
  final LessonGroup group;
}

/// İlk bu kadar ders ücretsiz; gerisi "Tüm Dersler" satın alımıyla açılır.
const freeLessonCount = 8;

/// Ders ücretli mi? (listedeki sıraya göre)
bool isPremiumLesson(int index) => index >= freeLessonCount;

const _empty = '4k3/8/8/8/8/8/8/4K3 w - - 0 1';

/// Dersleri seçili dilde üretir. Kimlikler ve konumlar dilden bağımsızdır.
List<Lesson> buildLessons(AppLocalizations t) => <Lesson>[
  Lesson(
    id: 'board',
    title: t.lesson_board_title,
    emoji: '🏁',
    steps: [
      LessonStep(
        text: t.lesson_board_s1,
        fen: '8/8/8/8/8/8/8/8 w - - 0 1',
      ),
      LessonStep(
        text: t.lesson_board_s2,
        fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      ),
      LessonStep(
        text: t.lesson_board_s3,
        fen: '3qk3/8/8/8/8/8/8/3QK3 w - - 0 1',
      ),
    ],
  ),
  Lesson(
    id: 'rook',
    title: t.lesson_rook_title,
    emoji: '🏰',
    steps: [
      LessonStep(
        text: t.lesson_rook_s1,
        fen: '4k3/8/8/8/8/8/8/R3K3 w - - 0 1',
      ),
      LessonStep(
        text: t.lesson_rook_s2,
        fen: '4k3/8/8/8/8/8/8/R3K3 w - - 0 1',
        task: MoveTask(
          from: 'a1',
          targets: ['a8'],
          success: t.lesson_rook_s2_ok,
        ),
      ),
      LessonStep(
        text: t.lesson_rook_s3,
        fen: '4k3/p7/8/8/8/8/8/R3K3 w - - 0 1',
        task: MoveTask(
          from: 'a1',
          targets: ['a7'],
          success: t.lesson_rook_s3_ok,
        ),
      ),
    ],
  ),
  Lesson(
    id: 'bishop',
    title: t.lesson_bishop_title,
    emoji: '🎩',
    steps: [
      LessonStep(
        text: t.lesson_bishop_s1,
        fen: '4k3/8/8/8/8/8/8/2B1K3 w - - 0 1',
      ),
      LessonStep(
        text: t.lesson_bishop_s2,
        fen: '4k3/8/8/8/8/8/8/2B1K3 w - - 0 1',
        task: MoveTask(
          from: 'c1',
          targets: ['h6'],
          success: t.lesson_bishop_s2_ok,
        ),
      ),
    ],
  ),
  Lesson(
    id: 'queen',
    title: t.lesson_queen_title,
    emoji: '👑',
    steps: [
      LessonStep(
        text: t.lesson_queen_s1,
        fen: '4k3/8/8/8/8/8/8/3QK3 w - - 0 1',
      ),
      LessonStep(
        text: t.lesson_queen_s2,
        fen: '4k3/8/8/8/8/8/8/3QK3 w - - 0 1',
        task: MoveTask(
          from: 'd1',
          targets: ['h5'],
          success: t.lesson_queen_s2_ok,
        ),
      ),
      LessonStep(
        text: t.lesson_queen_s3,
        fen: 'k7/8/8/7Q/8/8/8/4K3 w - - 0 1',
        task: MoveTask(
          from: 'h5',
          targets: ['h8'],
          success: t.lesson_queen_s3_ok,
        ),
      ),
    ],
  ),
  Lesson(
    id: 'knight',
    title: t.lesson_knight_title,
    emoji: '🐴',
    steps: [
      LessonStep(
        text: t.lesson_knight_s1,
        fen: '4k3/8/8/8/8/8/8/1N2K3 w - - 0 1',
        arrows: ['b1b3', 'b3c3'],
      ),
      LessonStep(
        text: t.lesson_knight_s2,
        fen: '4k3/8/8/8/8/8/8/1N2K3 w - - 0 1',
        task: MoveTask(
          from: 'b1',
          targets: ['c3'],
          success: t.lesson_knight_s2_ok,
        ),
      ),
      LessonStep(
        text: t.lesson_knight_s3,
        fen: '4k3/8/8/8/8/8/PPPP4/1N2K3 w - - 0 1',
        task: MoveTask(
          from: 'b1',
          targets: ['a3', 'c3'],
          success: t.lesson_knight_s3_ok,
        ),
      ),
    ],
  ),
  Lesson(
    id: 'pawn',
    title: t.lesson_pawn_title,
    emoji: '🧱',
    steps: [
      LessonStep(
        text: t.lesson_pawn_s1,
        fen: '4k3/8/8/8/8/8/4P3/4K3 w - - 0 1',
      ),
      LessonStep(
        text: t.lesson_pawn_s2,
        fen: '4k3/8/8/8/8/8/4P3/4K3 w - - 0 1',
        task: MoveTask(
          from: 'e2',
          targets: ['e4'],
          success: t.lesson_pawn_s2_ok,
        ),
      ),
      LessonStep(
        text: t.lesson_pawn_s3,
        fen: '4k3/8/8/3p4/4P3/8/8/4K3 w - - 0 1',
        task: MoveTask(
          from: 'e4',
          targets: ['d5'],
          success: t.lesson_pawn_s3_ok,
        ),
      ),
      LessonStep(
        text: t.lesson_pawn_s4,
        fen: '2k5/4P3/8/8/8/8/8/4K3 w - - 0 1',
        task: MoveTask(
          from: 'e7',
          targets: ['e8'],
          success: t.lesson_pawn_s4_ok,
        ),
      ),
    ],
  ),
  Lesson(
    id: 'king',
    title: t.lesson_king_title,
    emoji: '🤴',
    steps: [
      LessonStep(
        text: t.lesson_king_s1,
        fen: _empty,
      ),
      LessonStep(
        text: t.lesson_king_s2,
        fen: _empty,
        task: MoveTask(
          from: 'e1',
          targets: ['d1', 'd2', 'e2', 'f2', 'f1'],
          success: t.lesson_king_s2_ok,
        ),
      ),
      LessonStep(
        text: t.lesson_king_s3,
        fen: '4k3/8/8/8/8/8/8/4K2R w K - 0 1',
        task: MoveTask(
          from: 'e1',
          targets: ['g1', 'h1'],
          success: t.lesson_king_s3_ok,
        ),
      ),
    ],
  ),
  Lesson(
    id: 'checkmate',
    title: t.lesson_checkmate_title,
    emoji: '🏆',
    group: LessonGroup.kurallar,
    steps: [
      LessonStep(
        text: t.lesson_checkmate_s1,
        fen: '6k1/5ppp/8/8/8/8/8/4R1K1 w - - 0 1',
      ),
      LessonStep(
        text: t.lesson_checkmate_s2,
        fen: '6k1/5ppp/8/8/8/8/8/4R1K1 w - - 0 1',
        task: MoveTask(
          from: 'e1',
          targets: ['e8'],
          success: t.lesson_checkmate_s2_ok,
        ),
      ),
      LessonStep(
        text: t.lesson_checkmate_s3,
        fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      ),
    ],
  ),

  Lesson(
    id: 'escape_check',
    title: t.lesson_escape_check_title,
    emoji: '🛡️',
    group: LessonGroup.kurallar,
    steps: [
      LessonStep(
        text: t.lesson_escape_check_s1,
        fen: '4k3/8/8/8/8/8/8/r3K3 w - - 0 1',
        task: MoveTask(from: 'e1', targets: ['d2', 'e2', 'f2'], success: t.lesson_escape_check_s1_ok),
      ),
      LessonStep(
        text: t.lesson_escape_check_s2,
        fen: '4k3/8/8/8/8/8/2B5/r3K3 w - - 0 1',
        task: MoveTask(from: 'c2', targets: ['b1', 'd1'], success: t.lesson_escape_check_s2_ok),
      ),
      LessonStep(
        text: t.lesson_escape_check_s3,
        fen: '4k3/8/8/8/8/2b5/2R5/4K3 w - - 0 1',
        task: MoveTask(from: 'c2', targets: ['c3'], success: t.lesson_escape_check_s3_ok),
      ),
    ],
  ),
  Lesson(
    id: 'stalemate',
    title: t.lesson_stalemate_title,
    emoji: '🤝',
    group: LessonGroup.kurallar,
    steps: [
      LessonStep(
        text: t.lesson_stalemate_s1,
        fen: '7k/5Q2/6K1/8/8/8/8/8 b - - 0 1',
      ),
      LessonStep(
        text: t.lesson_stalemate_s2,
        fen: '7k/4Q3/6K1/8/8/8/8/8 w - - 0 1',
        task: MoveTask(from: 'e7', targets: ['g7', 'f8'], success: t.lesson_stalemate_s2_ok, mates: true),
      ),
    ],
  ),
  Lesson(
    id: 'en_passant',
    title: t.lesson_en_passant_title,
    emoji: '🏃',
    group: LessonGroup.kurallar,
    steps: [
      LessonStep(
        text: t.lesson_en_passant_s1,
        fen: '4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1',
      ),
      LessonStep(
        text: t.lesson_en_passant_s2,
        fen: '4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1',
        task: MoveTask(from: 'e5', targets: ['d6'], success: t.lesson_en_passant_s2_ok),
      ),
    ],
  ),
  Lesson(
    id: 'fork',
    title: t.lesson_fork_title,
    emoji: '🍴',
    group: LessonGroup.taktik,
    steps: [
      LessonStep(
        text: t.lesson_fork_s1,
        fen: '2q1k3/8/8/8/4N3/8/8/4K3 w - - 0 1',
      ),
      LessonStep(
        text: t.lesson_fork_s2,
        fen: '2q1k3/8/8/8/4N3/8/8/4K3 w - - 0 1',
        task: MoveTask(from: 'e4', targets: ['d6'], success: t.lesson_fork_s2_ok, givesCheck: true),
      ),
      LessonStep(
        text: t.lesson_fork_s3,
        fen: '4k3/8/2r1n3/8/3P4/8/8/4K3 w - - 0 1',
        task: MoveTask(from: 'd4', targets: ['d5'], success: t.lesson_fork_s3_ok),
      ),
    ],
  ),
  Lesson(
    id: 'pin',
    title: t.lesson_pin_title,
    emoji: '📌',
    group: LessonGroup.taktik,
    steps: [
      LessonStep(
        text: t.lesson_pin_s1,
        fen: '4k3/8/2n5/8/8/8/8/4KB2 w - - 0 1',
      ),
      LessonStep(
        text: t.lesson_pin_s2,
        fen: '4k3/8/2n5/8/8/8/8/4KB2 w - - 0 1',
        task: MoveTask(from: 'f1', targets: ['b5'], success: t.lesson_pin_s2_ok),
      ),
      LessonStep(
        text: t.lesson_pin_s3,
        fen: '4k3/8/2n5/1B6/3P4/8/8/4K3 w - - 0 1',
        task: MoveTask(from: 'd4', targets: ['d5'], success: t.lesson_pin_s3_ok),
      ),
    ],
  ),
  Lesson(
    id: 'skewer',
    title: t.lesson_skewer_title,
    emoji: '🍢',
    group: LessonGroup.taktik,
    steps: [
      LessonStep(
        text: t.lesson_skewer_s1,
        fen: '4q3/8/8/4k3/8/8/8/R5K1 w - - 0 1',
      ),
      LessonStep(
        text: t.lesson_skewer_s2,
        fen: '4q3/8/8/4k3/8/8/8/R5K1 w - - 0 1',
        task: MoveTask(from: 'a1', targets: ['e1'], success: t.lesson_skewer_s2_ok, givesCheck: true),
      ),
    ],
  ),
  Lesson(
    id: 'defend',
    title: t.lesson_defend_title,
    emoji: '👀',
    group: LessonGroup.taktik,
    steps: [
      LessonStep(
        text: t.lesson_defend_s1,
        fen: '6k1/6p1/5b2/8/3Q4/8/8/6K1 w - - 0 1',
      ),
      LessonStep(
        text: t.lesson_defend_s2,
        fen: '6k1/6p1/5b2/8/3Q4/8/8/6K1 w - - 0 1',
        task: MoveTask(from: 'd4', targets: ['a4', 'b4', 'c4', 'd3', 'd2', 'd1'], success: t.lesson_defend_s2_ok),
      ),
    ],
  ),
  Lesson(
    id: 'values',
    title: t.lesson_values_title,
    emoji: '⚖️',
    group: LessonGroup.taktik,
    steps: [
      LessonStep(
        text: t.lesson_values_s1,
        fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      ),
      LessonStep(
        text: t.lesson_values_s2,
        fen: '3qk3/8/8/8/8/8/8/1n1RK3 w - - 0 1',
        task: MoveTask(from: 'd1', targets: ['d8'], success: t.lesson_values_s2_ok),
      ),
    ],
  ),
  Lesson(
    id: 'opening',
    title: t.lesson_opening_title,
    emoji: '🚀',
    group: LessonGroup.taktik,
    steps: [
      LessonStep(
        text: t.lesson_opening_s1,
        fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      ),
      LessonStep(
        text: t.lesson_opening_s2,
        fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        task: MoveTask(from: 'e2', targets: ['e4'], success: t.lesson_opening_s2_ok),
      ),
      LessonStep(
        text: t.lesson_opening_s3,
        fen: 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2',
        task: MoveTask(from: 'g1', targets: ['f3'], success: t.lesson_opening_s3_ok),
      ),
      LessonStep(
        text: t.lesson_opening_s4,
        fen: 'r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4',
        task: MoveTask(from: 'e1', targets: ['g1', 'h1'], success: t.lesson_opening_s4_ok),
      ),
    ],
  ),
  Lesson(
    id: 'luft',
    title: t.lesson_luft_title,
    emoji: '🚪',
    group: LessonGroup.mat,
    steps: [
      LessonStep(
        text: t.lesson_luft_s1,
        fen: 'r5k1/8/8/8/8/8/5PPP/6K1 w - - 0 1',
      ),
      LessonStep(
        text: t.lesson_luft_s2,
        fen: 'r5k1/8/8/8/8/8/5PPP/6K1 w - - 0 1',
        task: MoveTask(from: 'h2', targets: ['h3', 'h4'], success: t.lesson_luft_s2_ok),
      ),
    ],
  ),
  Lesson(
    id: 'mate_queen',
    title: t.lesson_mate_queen_title,
    emoji: '👑',
    group: LessonGroup.mat,
    steps: [
      LessonStep(
        text: t.lesson_mate_queen_s1,
        fen: '3k4/Q7/3K4/8/8/8/8/8 w - - 0 1',
      ),
      LessonStep(
        text: t.lesson_mate_queen_s2,
        fen: '3k4/Q7/3K4/8/8/8/8/8 w - - 0 1',
        task: MoveTask(from: 'a7', targets: ['d7'], success: t.lesson_mate_queen_s2_ok, mates: true),
      ),
    ],
  ),
  Lesson(
    id: 'mate_two_rooks',
    title: t.lesson_mate_two_rooks_title,
    emoji: '🪜',
    group: LessonGroup.mat,
    steps: [
      LessonStep(
        text: t.lesson_mate_two_rooks_s1,
        fen: '4k3/8/8/8/8/8/1R6/R5K1 w - - 0 1',
      ),
      LessonStep(
        text: t.lesson_mate_two_rooks_s2,
        fen: '4k3/8/8/8/8/8/1R6/R5K1 w - - 0 1',
        task: MoveTask(from: 'a1', targets: ['a7'], success: t.lesson_mate_two_rooks_s2_ok),
      ),
      LessonStep(
        text: t.lesson_mate_two_rooks_s3,
        fen: '4k3/R7/8/8/8/8/1R6/6K1 w - - 0 1',
        task: MoveTask(from: 'b2', targets: ['b8'], success: t.lesson_mate_two_rooks_s3_ok, mates: true),
      ),
    ],
  ),
];
