import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';

import 'grid_map.dart';

/// Hasil pembangkitan peta.
class GeneratedMap {
  /// Membuat hasil pembangkitan.
  const GeneratedMap({
    required this.grid,
    required this.seedUsed,
    required this.reseedAttempts,
    required this.repaired,
  });

  /// Peta yang solvable.
  final GridMap grid;

  /// Seed yang akhirnya dipakai (`seed + 1000 * reseedAttempts`).
  final int seedUsed;

  /// Jumlah re-seed yang dilakukan.
  final int reseedAttempts;

  /// True bila peta diperbaiki lewat koridor (lihat [MapGenerator.generate]).
  final bool repaired;
}

/// Generator peta rintangan statis berbasis seed + pengecekan solvability.
class MapGenerator {
  /// Batas default re-seed sebelum fallback perbaikan koridor.
  static const int defaultMaxReseedAttempts = 100;

  /// Jumlah rintangan untuk kepadatan [densityPct] (persen).
  static int obstacleCountFor(int width, int height, num densityPct) =>
      (densityPct / 100 * width * height).round();

  /// Membangkitkan peta `width x height` dengan kepadatan [densityPct].
  ///
  /// Jumlah rintangan tepat `round(density * W * H)`; start (0,0) dan goal
  /// (W-1,H-1) selalu bebas. Bila tidak solvable (BFS 4 arah), re-seed dengan
  /// `seed + 1000 * attempt`.
  ///
  /// Keputusan desain: pada kepadatan 50% di grid besar, peta acak hampir
  /// tidak pernah solvable (di bawah ambang perkolasi ~59% sel bebas). Setelah
  /// [maxReseedAttempts] gagal, peta seed terakhir diperbaiki dengan membuka
  /// koridor minimal-rintangan dari start ke goal, lalu jumlah rintangan
  /// dipulihkan secara acak (seeded) di luar koridor sehingga kepadatan tetap
  /// tepat. Kasus ini ditandai `repaired = true`.
  static GeneratedMap generate({
    required int width,
    required int height,
    required num densityPct,
    required int seed,
    int maxReseedAttempts = defaultMaxReseedAttempts,
  }) {
    final count = obstacleCountFor(width, height, densityPct);
    if (count > width * height - 2) {
      throw ArgumentError('Kepadatan terlalu tinggi: $densityPct%');
    }
    for (var attempt = 0; attempt <= maxReseedAttempts; attempt++) {
      final s = seed + 1000 * attempt;
      final grid = _random(width, height, count, s);
      if (isSolvable(grid)) {
        return GeneratedMap(
          grid: grid,
          seedUsed: s,
          reseedAttempts: attempt,
          repaired: false,
        );
      }
    }
    final s = seed + 1000 * maxReseedAttempts;
    final grid = _repair(_random(width, height, count, s), count, s);
    return GeneratedMap(
      grid: grid,
      seedUsed: s,
      reseedAttempts: maxReseedAttempts,
      repaired: true,
    );
  }

  static GridMap _random(int width, int height, int count, int seed) {
    final rng = Random(seed);
    final n = width * height;
    // Kandidat: semua sel selain start (0) dan goal (n-1).
    final candidates = Int32List(n - 2);
    for (var i = 0; i < candidates.length; i++) {
      candidates[i] = i + 1;
    }
    final grid = GridMap.empty(width, height);
    for (var i = 0; i < count; i++) {
      final j = i + rng.nextInt(candidates.length - i);
      final t = candidates[i];
      candidates[i] = candidates[j];
      candidates[j] = t;
      grid.cells[candidates[i]] = 1;
    }
    return grid;
  }

  /// Cek solvability dengan BFS 4 arah (start -> goal).
  static bool isSolvable(GridMap grid) {
    final w = grid.width, h = grid.height;
    if (grid.cells[grid.startIndex] != 0 || grid.cells[grid.goalIndex] != 0) {
      return false;
    }
    final seen = Uint8List(w * h);
    final queue = Queue<int>()..add(0);
    seen[0] = 1;
    while (queue.isNotEmpty) {
      final cur = queue.removeFirst();
      if (cur == grid.goalIndex) return true;
      final x = cur % w, y = cur ~/ w;
      void visit(int nx, int ny) {
        if (nx < 0 || ny < 0 || nx >= w || ny >= h) return;
        final ni = ny * w + nx;
        if (seen[ni] == 1 || grid.cells[ni] != 0) return;
        seen[ni] = 1;
        queue.add(ni);
      }

      visit(x + 1, y);
      visit(x - 1, y);
      visit(x, y + 1);
      visit(x, y - 1);
    }
    return false;
  }

  static GridMap _repair(GridMap grid, int count, int seed) {
    final w = grid.width, h = grid.height, n = w * h;
    // 0-1 BFS: biaya 1 untuk melewati rintangan, 0 untuk sel bebas.
    final dist = Int32List(n)..fillRange(0, n, 1 << 30);
    final parent = Int32List(n)..fillRange(0, n, -1);
    final dq = Queue<int>()..add(0);
    dist[0] = 0;
    while (dq.isNotEmpty) {
      final cur = dq.removeFirst();
      final x = cur % w, y = cur ~/ w;
      void relax(int nx, int ny) {
        if (nx < 0 || ny < 0 || nx >= w || ny >= h) return;
        final ni = ny * w + nx;
        final c = grid.cells[ni];
        if (dist[cur] + c < dist[ni]) {
          dist[ni] = dist[cur] + c;
          parent[ni] = cur;
          if (c == 0) {
            dq.addFirst(ni);
          } else {
            dq.addLast(ni);
          }
        }
      }

      relax(x + 1, y);
      relax(x - 1, y);
      relax(x, y + 1);
      relax(x, y - 1);
    }
    final protected = Uint8List(n);
    for (var c = n - 1; c != -1; c = parent[c]) {
      protected[c] = 1;
      grid.cells[c] = 0;
    }
    var missing = count - grid.obstacleCount;
    if (missing > 0) {
      final rng = Random(seed ^ 0x5bd1e995);
      final free = <int>[
        for (var i = 0; i < n; i++)
          if (grid.cells[i] == 0 && protected[i] == 0) i,
      ];
      for (var i = 0; i < missing; i++) {
        final j = i + rng.nextInt(free.length - i);
        final t = free[i];
        free[i] = free[j];
        free[j] = t;
        grid.cells[free[i]] = 1;
      }
    }
    return grid;
  }
}
