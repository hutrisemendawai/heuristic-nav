import 'dart:typed_data';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';

import '../core/grid/grid_map.dart';
import '../core/pathfinding/pathfinding_result.dart';
import 'components/agent_component.dart';
import 'components/explored_component.dart';
import 'components/grid_component.dart';
import 'components/path_component.dart';

/// Satu panel visualisasi (satu peta + satu hasil solver).
class _Panel extends PositionComponent {
  _Panel(GridMap grid, PathfindingResult result) {
    final w = grid.width;
    add(GridComponent(grid));
    add(ExploredComponent(result.exploredOrder ?? Int32List(0), w));
    add(PathComponent(result.path, w));
    add(AgentComponent(result.path, w));
  }

  /// Mengatur posisi dan ukuran panel dan semua anaknya.
  void layout(Vector2 pos, double side) {
    position = pos;
    size = Vector2.all(side);
    for (final c in children.whereType<PositionComponent>()) {
      c.size = Vector2(side, side);
    }
  }
}

/// Game Flame untuk visualisasi A*; satu atau dua panel berdampingan.
///
/// Tidak dipakai saat benchmark; pengukuran memakai solver murni tanpa render.
class PathfindingGame extends FlameGame {
  final List<_Panel> _panels = [];

  /// Mengganti isi dengan satu panel.
  void showSingle(GridMap grid, PathfindingResult result) =>
      _setPanels([_Panel(grid, result)]);

  /// Menampilkan dua panel berdampingan (peta yang sama).
  void showCompare(
    GridMap grid,
    PathfindingResult left,
    PathfindingResult right,
  ) => _setPanels([_Panel(grid, left), _Panel(grid, right)]);

  /// Menghapus semua panel.
  void clearPanels() => _setPanels([]);

  void _setPanels(List<_Panel> panels) {
    for (final p in _panels) {
      p.removeFromParent();
    }
    _panels
      ..clear()
      ..addAll(panels);
    for (final p in panels) {
      add(p);
    }
    if (hasLayout) _layout(size);
  }

  void _layout(Vector2 gameSize) {
    if (_panels.isEmpty) return;
    const gap = 8.0;
    final n = _panels.length;
    final side = ((gameSize.x - gap * (n - 1)) / n).clamp(0.0, gameSize.y);
    for (var i = 0; i < n; i++) {
      _panels[i].layout(Vector2(i * (side + gap), 0), side);
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _layout(size);
  }

  @override
  Color backgroundColor() => const Color(0xFFECEFF1);
}
