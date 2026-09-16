import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../captured_material.dart';
import '../settings_store.dart';
import '../theme.dart';

/// Bir oyuncunun satırı: adı, aldığı taşlar (türe göre gruplu), öndeyse puan farkı
/// ve isteğe bağlı sağ öğe (saat). Yükseklik sabit; ilk taş alınınca tahta kaymaz.
class PlayerMaterialRow extends StatelessWidget {
  const PlayerMaterialRow({
    super.key,
    required this.label,
    required this.side,
    required this.material,
    this.active = false,
    this.trailing,
  });

  final String label;

  /// Satırın ait olduğu taraf; gösterilen taşlar rakibin renginde.
  final Side side;
  final CapturedMaterial material;
  final bool active;
  final Widget? trailing;

  static const double height = 36;
  static const double _piece = 20;

  @override
  Widget build(BuildContext context) {
    final assets = SettingsStore.instance.pieces.assets;
    final captured = material.capturedBy(side);
    final advantage = material.advantage(side);
    final groups = <Widget>[];
    for (var i = 0; i < captured.length;) {
      final role = captured[i];
      var n = 0;
      while (i < captured.length && captured[i] == role) {
        n++;
        i++;
      }
      final image = assets[Piece(color: side.opposite, role: role).kind]!;
      // Aynı türden taşlar yarı yarıya üst üste biner.
      groups.add(Padding(
        padding: const EdgeInsets.only(right: 4),
        child: SizedBox(
          width: _piece + (n - 1) * _piece * 0.45,
          height: _piece,
          child: Stack(
            children: [
              for (var k = 0; k < n; k++)
                Positioned(left: k * _piece * 0.45, child: Image(image: image, width: _piece, height: _piece)),
            ],
          ),
        ),
      ));
    }
    return SizedBox(
      height: height,
      child: Row(
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: active ? AppColors.ink : AppColors.inkMuted)),
          const SizedBox(width: 10),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(
                children: [
                  ...groups,
                  if (advantage > 0)
                    Text(
                      '+$advantage',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.inkMuted),
                    ),
                ],
              ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );
  }
}
