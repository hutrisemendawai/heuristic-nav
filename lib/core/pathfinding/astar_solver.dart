import 'dart:typed_data';

import '../grid/grid_map.dart';
import 'binary_min_heap.dart';
import 'heuristic.dart';
import 'movement_mode.dart';
import 'pathfinding_result.dart';

/// Solver A* berbasis array flat; buffer dialokasikan sekali per solver.
///
/// Kebijakan: closed node tidak pernah dibuka kembali (standar A*), sehingga
/// heuristik inadmissible (mis. Manhattan 8 arah) dapat menghasilkan jalur
/// suboptimal. Corner-cutting default dilarang.
class AStarSolver {
  /// Membuat solver untuk grid berukuran `width x height`.
  AStarSolver(this.width, this.height)
    : _g = Float64List(width * height),
      _parent = Int32List(width * height),
      _closed = Uint8List(width * height),
      _order = Int32List(width * height),
      _heap = BinaryMinHeap(1024);

  /// Lebar grid yang didukung.
  final int width;

  /// Tinggi grid yang didukung.
  final int height;

  final Float64List _g;
  final Int32List _parent;
  final Uint8List _closed;
  final Int32List _order;
  final BinaryMinHeap _heap;

  static const List<int> _dxs = [0, 0, -1, 1, -1, 1, -1, 1];
  static const List<int> _dys = [-1, 1, 0, 0, -1, -1, 1, 1];

  /// Menjalankan A* dari (0,0) ke (W-1,H-1).
  ///
  /// Urutan expand selalu ditulis ke buffer yang sudah dialokasikan (satu
  /// store, tanpa callback/alokasi); salinannya hanya dibuat di luar loop
  /// pencarian jika [collectExploredOrder] true.
  PathfindingResult solve(
    GridMap grid,
    HeuristicType heuristic,
    MovementMode mode, {
    bool allowCornerCutting = false,
    bool collectExploredOrder = false,
  }) {
    if (grid.width != width || grid.height != height) {
      throw ArgumentError('Ukuran grid tidak sama dengan ukuran solver');
    }
    final sw = Stopwatch()..start();
    return _run(
      grid,
      heuristic,
      mode,
      allowCornerCutting,
      collectExploredOrder,
      sw,
    );
  }

  PathfindingResult _run(
    GridMap grid,
    HeuristicType heuristic,
    MovementMode mode,
    bool cornerCut,
    bool collect,
    Stopwatch sw,
  ) {
    final n = width * height;
    final cells = grid.cells;
    final g = _g, parent = _parent, closed = _closed, heap = _heap;
    g.fillRange(0, n, double.infinity);
    parent.fillRange(0, n, -1);
    closed.fillRange(0, n, 0);
    heap.clear();

    final start = grid.startIndex, goal = grid.goalIndex;
    final gx = width - 1, gy = height - 1;
    final dirCount = mode == MovementMode.fourDirections ? 4 : 8;
    final order = _order;

    var expanded = 0, generated = 0, maxOpen = 0;
    var found = false;

    g[start] = 0;
    final h0 = heuristicValue(heuristic, gx, gy);
    heap.push(start, h0, h0);
    generated++;
    maxOpen = 1;

    while (!heap.isEmpty) {
      heap.pop();
      final cur = heap.poppedNode;
      if (closed[cur] == 1) continue; // entry stale
      closed[cur] = 1;
      order[expanded++] = cur;
      if (cur == goal) {
        found = true;
        break;
      }
      final cx = cur % width, cy = cur ~/ width;
      final gc = g[cur];
      for (var d = 0; d < dirCount; d++) {
        final dx = _dxs[d], dy = _dys[d];
        final nx = cx + dx, ny = cy + dy;
        if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
        final ni = ny * width + nx;
        if (cells[ni] != 0 || closed[ni] == 1) continue;
        double step = 1.0;
        if (d >= 4) {
          if (!cornerCut &&
              (cells[cy * width + nx] != 0 || cells[ny * width + cx] != 0)) {
            continue;
          }
          step = sqrt2;
        }
        final ng = gc + step;
        if (ng < g[ni]) {
          g[ni] = ng;
          parent[ni] = cur;
          final h = heuristicValue(heuristic, (gx - nx).abs(), (gy - ny).abs());
          heap.push(ni, ng + h, h);
          generated++;
          if (heap.length > maxOpen) maxOpen = heap.length;
        }
      }
    }

    var path = Int32List(0);
    var cost = double.nan;
    var steps = 0;
    if (found) {
      var len = 1;
      for (var c = goal; c != start; c = parent[c]) {
        len++;
      }
      path = Int32List(len);
      var i = len - 1;
      cost = 0;
      for (var c = goal; ; c = parent[c]) {
        path[i--] = c;
        if (c == start) break;
        final p = parent[c];
        final diag = (c % width != p % width) && (c ~/ width != p ~/ width);
        cost += diag ? sqrt2 : 1.0;
      }
      steps = len - 1;
    }
    sw.stop();
    return PathfindingResult(
      pathFound: found,
      expandedNodes: expanded,
      generatedNodes: generated,
      maxOpenListSize: maxOpen,
      pathCost: cost,
      pathLengthSteps: steps,
      executionTimeUs: sw.elapsedMicroseconds,
      path: path,
      exploredOrder: collect
          ? Int32List.fromList(order.sublist(0, expanded))
          : null,
    );
  }
}
