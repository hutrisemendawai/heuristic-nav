import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/grid/grid_map.dart';

/// Merender grid, rintangan, start dan goal. Ukuran komponen = ukuran panel.
class GridComponent extends PositionComponent {
  /// Membuat komponen untuk [grid].
  GridComponent(this.grid);

  /// Peta yang digambar.
  final GridMap grid;

  static final Paint _free = Paint()..color = const Color(0xFFF5F5F5);
  static final Paint _wall = Paint()..color = const Color(0xFF263238);
  static final Paint _start = Paint()..color = const Color(0xFF2E7D32);
  static final Paint _goal = Paint()..color = const Color(0xFFC62828);

  /// Ukuran satu sel dalam piksel.
  double get cell => size.x / grid.width;

  @override
  void render(Canvas canvas) {
    final c = cell;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, c * grid.height), _free);
    for (var y = 0; y < grid.height; y++) {
      for (var x = 0; x < grid.width; x++) {
        if (grid.isBlocked(x, y)) {
          canvas.drawRect(Rect.fromLTWH(x * c, y * c, c, c), _wall);
        }
      }
    }
    canvas.drawRect(Rect.fromLTWH(0, 0, c, c), _start);
    canvas.drawRect(
      Rect.fromLTWH((grid.width - 1) * c, (grid.height - 1) * c, c, c),
      _goal,
    );
  }
}
