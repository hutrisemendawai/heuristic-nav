import 'dart:typed_data';
import 'dart:ui';

import 'package:flame/components.dart';

/// Merender closed set (warna redup).
class ExploredComponent extends PositionComponent {
  /// Membuat komponen untuk sel [order] pada grid selebar [gridWidth].
  ExploredComponent(this.order, this.gridWidth);

  /// Index sel yang di-expand.
  final Int32List order;

  /// Lebar grid.
  final int gridWidth;

  static final Paint _paint = Paint()..color = const Color(0x6690CAF9);

  @override
  void render(Canvas canvas) {
    final c = size.x / gridWidth;
    for (final i in order) {
      canvas.drawRect(
        Rect.fromLTWH((i % gridWidth) * c, (i ~/ gridWidth) * c, c, c),
        _paint,
      );
    }
  }
}
