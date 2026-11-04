import 'dart:typed_data';
import 'dart:ui';

import 'package:flame/components.dart';

/// NPC 1x1 sel yang berjalan menyusuri jalur (hanya demonstrasi visual).
class AgentComponent extends PositionComponent {
  /// Membuat agen untuk [path] pada grid selebar [gridWidth].
  AgentComponent(this.path, this.gridWidth, {this.cellsPerSecond = 15});

  /// Index sel jalur.
  final Int32List path;

  /// Lebar grid.
  final int gridWidth;

  /// Kecepatan dalam sel per detik.
  final double cellsPerSecond;

  double _progress = 0;

  static final Paint _paint = Paint()..color = const Color(0xFF6A1B9A);

  @override
  void update(double dt) {
    if (path.length < 2) return;
    _progress += dt * cellsPerSecond;
    final max = (path.length - 1).toDouble();
    if (_progress > max) _progress = 0;
  }

  @override
  void render(Canvas canvas) {
    if (path.isEmpty) return;
    final c = size.x / gridWidth;
    final i = _progress.floor().clamp(0, path.length - 1);
    final j = (i + 1).clamp(0, path.length - 1);
    final t = _progress - i;
    final x0 = (path[i] % gridWidth).toDouble(),
        y0 = (path[i] ~/ gridWidth).toDouble();
    final x1 = (path[j] % gridWidth).toDouble(),
        y1 = (path[j] ~/ gridWidth).toDouble();
    final x = x0 + (x1 - x0) * t, y = y0 + (y1 - y0) * t;
    canvas.drawRect(Rect.fromLTWH(x * c, y * c, c, c), _paint);
  }
}
