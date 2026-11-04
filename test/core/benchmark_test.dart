import 'package:flutter_test/flutter_test.dart';
import 'package:heuristic_nav/core/benchmark/benchmark_runner.dart';
import 'package:heuristic_nav/core/benchmark/csv_exporter.dart';
import 'package:heuristic_nav/core/benchmark/scenario_config.dart';
import 'package:heuristic_nav/core/benchmark/summary_calculator.dart';

ScenarioConfig smoke({int seeds = 3, bool octile = false}) =>
    ScenarioConfig.fromJsonString('''
{
  "name": "t", "gridSizes": [20], "obstacleDensitiesPct": [10, 30],
  "movementModes": ["fourDirections", "eightDirections"],
  "heuristics": ["manhattan", "euclidean"],
  "seedsPerConfig": $seeds, "warmupRuns": 2,
  "innerRepeatsByGridSize": {"20": 2}, "includeOctile": $octile
}''');

void main() {
  test('config round trip and counts', () {
    final c = smoke();
    expect(c.configurationCount, 8);
    expect(c.totalRuns, 24);
    expect(ScenarioConfig.fromJson(c.toJson()).totalRuns, 24);
    expect(smoke(octile: true).configurationCount, 12);
  });

  test('raw CSV rows = configurations x N; header order', () async {
    final c = smoke();
    final res = await BenchmarkRunner(c).run();
    final lines = CsvExporter.rawCsv(res.records).trim().split('\n');
    expect(lines.length, 1 + c.configurationCount * c.seedsPerConfig);
    expect(
      lines.first.startsWith('runId,timestamp,gridSize,width,height'),
      isTrue,
    );
    expect(lines.first.split(',').length, lines[1].split(',').length);
    expect(
      CsvExporter.summaryCsv(res.records).trim().split('\n').length,
      1 + c.configurationCount,
    );
    final paired = SummaryCalculator.pair(res.records);
    expect(paired.length, c.configurationCount ~/ 2 * c.seedsPerConfig);
  });

  test(
    'identical map hash for both heuristics; order counterbalanced',
    () async {
      final res = await BenchmarkRunner(smoke(octile: true)).run();
      for (final p in SummaryCalculator.pair(res.records)) {
        expect(p.manhattan.mapHash, p.euclidean.mapHash);
        expect(p.manhattan.obstacleCount, p.euclidean.obstacleCount);
      }
      final firsts = {
        for (final r in res.records)
          if (r.orderInPair == 1 && r.movementMode == 'fourDirections')
            r.heuristic,
      };
      expect(firsts.length, greaterThan(1));
      final p2 = await BenchmarkRunner(smoke()).run();
      for (final r in p2.records.where((r) => r.seedIndex.isEven)) {
        if (r.heuristic == 'manhattan') expect(r.orderInPair, 1);
      }
      for (final r in p2.records.where((r) => r.seedIndex.isOdd)) {
        if (r.heuristic == 'manhattan') expect(r.orderInPair, 2);
      }
    },
  );

  test('reproducible expanded/cost with same seed', () async {
    final a = await BenchmarkRunner(smoke()).run();
    final b = await BenchmarkRunner(smoke()).run();
    expect(a.records.length, b.records.length);
    for (var i = 0; i < a.records.length; i++) {
      expect(a.records[i].expandedNodes, b.records[i].expandedNodes);
      expect(a.records[i].generatedNodes, b.records[i].generatedNodes);
      expect(a.records[i].pathCost, b.records[i].pathCost);
      expect(a.records[i].mapHash, b.records[i].mapHash);
    }
  });

  test('cancel stops early', () async {
    final res = await BenchmarkRunner(smoke(seeds: 5))
        .run(isCancelled: () => true);
    expect(res.cancelled, isTrue);
    expect(res.records, isEmpty);
  });

  test('stats', () {
    final s = Stats.of([1, 2, 3, 4]);
    expect(s.mean, 2.5);
    expect(s.median, 2.5);
    expect(s.std, closeTo(1.2909944, 1e-6));
    expect(s.min, 1);
    expect(s.max, 4);
  });
}
