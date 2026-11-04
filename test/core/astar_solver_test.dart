import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:heuristic_nav/core/grid/grid_map.dart';
import 'package:heuristic_nav/core/grid/map_generator.dart';
import 'package:heuristic_nav/core/pathfinding/astar_solver.dart';
import 'package:heuristic_nav/core/pathfinding/heuristic.dart';
import 'package:heuristic_nav/core/pathfinding/movement_mode.dart';

const four = MovementMode.fourDirections;
const eight = MovementMode.eightDirections;

void main() {
  test('4-dir empty 5x5 cost 8 for Manhattan and Euclidean', () {
    final g = GridMap.empty(5, 5);
    final s = AStarSolver(5, 5);
    final m = s.solve(g, HeuristicType.manhattan, four);
    final e = s.solve(g, HeuristicType.euclidean, four);
    expect(m.pathCost, 8.0);
    expect(e.pathCost, 8.0);
    expect(m.pathLengthSteps, 8);
  });

  test('8-dir Euclidean empty NxN cost (N-1)*sqrt2', () {
    for (final n in [5, 20]) {
      final r = AStarSolver(
        n,
        n,
      ).solve(GridMap.empty(n, n), HeuristicType.euclidean, eight);
      expect(r.pathCost, closeTo((n - 1) * sqrt(2), 1e-9));
    }
  });

  test('A* (Euclidean, 8 dir) matches Dijkstra (h=0) on 200 random maps', () {
    for (var i = 0; i < 200; i++) {
      final map = MapGenerator.generate(
        width: 10,
        height: 10,
        densityPct: 30,
        seed: 1000 + i,
      );
      final solver = AStarSolver(10, 10);
      final a = solver.solve(map.grid, HeuristicType.euclidean, eight);
      expect(a.pathFound, isTrue);
      expect(a.pathCost, closeTo(_dijkstra(map.grid, eight), 1e-9));
      final a4 = solver.solve(map.grid, HeuristicType.manhattan, four);
      expect(a4.pathCost, closeTo(_dijkstra(map.grid, four), 1e-9));
    }
  });

  test('corner cutting is forbidden', () {
    // Diagonal (0,0)->(1,1) diapit rintangan di (1,0) dan (0,1).
    final g = GridMap.empty(2, 2)
      ..setBlocked(1, 0, true)
      ..setBlocked(0, 1, true);
    final solver = AStarSolver(2, 2);
    expect(solver.solve(g, HeuristicType.euclidean, eight).pathFound, isFalse);
    expect(
      solver
          .solve(g, HeuristicType.euclidean, eight, allowCornerCutting: true)
          .pathCost,
      closeTo(sqrt(2), 1e-12),
    );
    // Satu sisi terblokir juga dilarang.
    final g2 = GridMap.empty(3, 3)..setBlocked(1, 0, true);
    final r = solver.solve(GridMap.empty(2, 2), HeuristicType.euclidean, eight);
    expect(r.pathCost, closeTo(sqrt(2), 1e-12));
    final r2 = AStarSolver(3, 3).solve(g2, HeuristicType.euclidean, eight);
    expect(r2.pathFound, isTrue);
    for (var i = 1; i < r2.path.length; i++) {
      final a = r2.path[i - 1], b = r2.path[i];
      final dx = (a % 3 - b % 3).abs(), dy = (a ~/ 3 - b ~/ 3).abs();
      if (dx == 1 && dy == 1) {
        expect(g2.cells[(a ~/ 3) * 3 + b % 3], 0);
        expect(g2.cells[(b ~/ 3) * 3 + a % 3], 0);
      }
    }
  });

  test('expanded count excludes stale entries; unreachable goal', () {
    final map = MapGenerator.generate(
      width: 30,
      height: 30,
      densityPct: 30,
      seed: 5,
    );
    final r = AStarSolver(
      30,
      30,
    ).solve(map.grid, HeuristicType.manhattan, eight);
    expect(r.expandedNodes, lessThanOrEqualTo(map.grid.size));
    expect(r.generatedNodes, greaterThanOrEqualTo(r.expandedNodes));
    expect(r.exploredOrder, isNull);
    final c = AStarSolver(30, 30).solve(
      map.grid,
      HeuristicType.manhattan,
      eight,
      collectExploredOrder: true,
    );
    expect(c.exploredOrder!.length, c.expandedNodes);
    expect(c.exploredOrder!.toSet().length, c.expandedNodes);

    final blocked = GridMap.empty(3, 3)
      ..setBlocked(1, 0, true)
      ..setBlocked(1, 1, true)
      ..setBlocked(1, 2, true);
    final u = AStarSolver(3, 3).solve(blocked, HeuristicType.euclidean, four);
    expect(u.pathFound, isFalse);
    expect(u.expandedNodes, 3);
  });
}

/// Dijkstra referensi (A* dengan h=0) sederhana, O(n^2).
double _dijkstra(GridMap g, MovementMode mode) {
  final n = g.size;
  final dist = List<double>.filled(n, double.infinity)..[0] = 0;
  final done = List<bool>.filled(n, false);
  while (true) {
    var u = -1;
    for (var i = 0; i < n; i++) {
      if (!done[i] && dist[i].isFinite && (u == -1 || dist[i] < dist[u])) u = i;
    }
    if (u == -1) break;
    done[u] = true;
    final x = u % g.width, y = u ~/ g.width;
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        if (dx == 0 && dy == 0) continue;
        final diag = dx != 0 && dy != 0;
        if (diag && mode == MovementMode.fourDirections) continue;
        final nx = x + dx, ny = y + dy;
        if (nx < 0 || ny < 0 || nx >= g.width || ny >= g.height) continue;
        if (g.isBlocked(nx, ny)) continue;
        if (diag && (g.isBlocked(nx, y) || g.isBlocked(x, ny))) continue;
        final v = ny * g.width + nx;
        final nd = dist[u] + (diag ? sqrt(2) : 1.0);
        if (nd < dist[v]) dist[v] = nd;
      }
    }
  }
  return dist[n - 1];
}
