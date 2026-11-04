import 'package:flutter_test/flutter_test.dart';
import 'package:heuristic_nav/core/grid/map_generator.dart';

void main() {
  test('density, free start/goal, solvable', () {
    for (final size in [20, 50]) {
      for (final d in [10, 30, 50]) {
        final m = MapGenerator.generate(
          width: size,
          height: size,
          densityPct: d,
          seed: 42,
        );
        expect(m.grid.obstacleCount, (d / 100 * size * size).round());
        expect(m.grid.cells[m.grid.startIndex], 0);
        expect(m.grid.cells[m.grid.goalIndex], 0);
        expect(MapGenerator.isSolvable(m.grid), isTrue);
        expect(m.seedUsed, 42 + 1000 * m.reseedAttempts);
      }
    }
  });

  test('same seed gives identical map', () {
    final a = MapGenerator.generate(
      width: 50,
      height: 50,
      densityPct: 30,
      seed: 7,
    );
    final b = MapGenerator.generate(
      width: 50,
      height: 50,
      densityPct: 30,
      seed: 7,
    );
    expect(a.grid.cells, b.grid.cells);
    expect(a.grid.hash, b.grid.hash);
    final c = MapGenerator.generate(
      width: 50,
      height: 50,
      densityPct: 30,
      seed: 8,
    );
    expect(c.grid.hash, isNot(a.grid.hash));
  });

  test('100x100 at 50% is solvable with exact density (repair fallback)', () {
    final m = MapGenerator.generate(
      width: 100,
      height: 100,
      densityPct: 50,
      seed: 1,
    );
    expect(m.grid.obstacleCount, 5000);
    expect(MapGenerator.isSolvable(m.grid), isTrue);
  });
}
