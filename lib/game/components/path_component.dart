import 'dart:typed_data';
import 'dart:ui';

import 'package:flame/components.dart';

/// Merender jalur akhir.
class PathComponent extends PositionComponent {
  /// Membuat komponen untuk [path] pada grid selebar [gridWidth].
  PathComponent(this.path, this.gridWidth);

  /// Index sel jalur dari start ke goal.
  final Int32List path;

  /// Lebar grid.
  final int gridWidth;

  static final Paint _paint = Paint()
    ..color = const Color(0xFFFFA000)
    ..style = PaintingStyle.stroke;

  @override
  void render(Canvas canvas) {
    if (path.length < 2) return;
    final c = size.x / gridWidth;
    _paint.strokeWidth = (c * 0.4).clamp(1.0, 4.0);
    final p = Path();
    for (var k = 0; k < path.length; k++) {
      final x = (path[k] % gridWidth + 0.5) * c;
      final y = (path[k] ~/ gridWidth + 0.5) * c;
      k == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
    }
    canvas.drawPath(p, _paint);
  }
}
