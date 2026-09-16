import 'package:dartchess/dartchess.dart';

/// Taş puanları (şah sayılmaz).
const Map<Role, int> pieceValues = {
  Role.pawn: 1,
  Role.knight: 3,
  Role.bishop: 3,
  Role.rook: 5,
  Role.queen: 9,
};

const Map<Role, int> _startCount = {
  Role.pawn: 8,
  Role.knight: 2,
  Role.bishop: 2,
  Role.rook: 2,
  Role.queen: 1,
};

/// Tahtadan hesaplanan alınmış taşlar ve puan farkı.
///
/// Hamle geçmişi tutulmaz: taşlar başlangıç dizilişiyle karşılaştırılır, böylece
/// yeniden başlatma ve tekrar oynatmada ek iş gerekmez. Terfi eden piyon alınmış
/// sayılmaz (başlangıçtan fazla olan taş kadar piyon terfi etmiş kabul edilir).
class CapturedMaterial {
  CapturedMaterial._(this._lost, this._points);

  factory CapturedMaterial.of(Board board) {
    final lost = <Side, Map<Role, int>>{};
    final points = <Side, int>{};
    for (final side in Side.values) {
      final count = board.materialCount(side);
      var promoted = 0;
      var sum = 0;
      final missing = <Role, int>{};
      for (final role in pieceValues.keys) {
        final n = count[role] ?? 0;
        sum += n * pieceValues[role]!;
        if (role == Role.pawn) continue;
        final start = _startCount[role]!;
        if (n > start) promoted += n - start;
        missing[role] = start > n ? start - n : 0;
      }
      final pawnsLeft = (count[Role.pawn] ?? 0) + promoted;
      missing[Role.pawn] = pawnsLeft < 8 ? 8 - pawnsLeft : 0;
      lost[side] = missing;
      points[side] = sum;
    }
    return CapturedMaterial._(lost, points);
  }

  final Map<Side, Map<Role, int>> _lost;
  final Map<Side, int> _points;

  /// [side] tarafının aldığı rakip taşları, piyondan vezire sıralı.
  List<Role> capturedBy(Side side) => [
        for (final role in pieceValues.keys)
          for (var i = 0; i < _lost[side.opposite]![role]!; i++) role,
      ];

  /// [side] öndeyse kaç puan önde; değilse 0.
  int advantage(Side side) {
    final diff = _points[side]! - _points[side.opposite]!;
    return diff > 0 ? diff : 0;
  }
}
