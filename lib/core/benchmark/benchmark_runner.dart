import '../grid/grid_map.dart';
import '../grid/map_generator.dart';
import '../pathfinding/astar_solver.dart';
import '../pathfinding/heuristic.dart';
import '../pathfinding/movement_mode.dart';
import 'run_record.dart';
import 'scenario_config.dart';

/// Laporan progres benchmark.
class BenchmarkProgress {
  /// Membuat laporan progres.
  const BenchmarkProgress(this.completed, this.total, this.elapsed);

  /// Run selesai.
  final int completed;

  /// Total run.
  final int total;

  /// Waktu berjalan.
  final Duration elapsed;

  /// Estimasi sisa waktu (null bila belum ada data).
  Duration? get estimatedRemaining => completed == 0
      ? null
      : Duration(
          microseconds:
              (elapsed.inMicroseconds * (total - completed) / completed)
                  .round(),
        );
}

/// Hasil benchmark.
class BenchmarkResult {
  /// Membuat hasil.
  const BenchmarkResult(this.config, this.records, this.cancelled);

  /// Skenario yang dijalankan.
  final ScenarioConfig config;

  /// Data mentah.
  final List<RunRecord> records;

  /// True bila dibatalkan sebelum selesai.
  final bool cancelled;
}

/// Orkestrasi seluruh skenario (pure Dart, headless).
///
/// Peta dibangkitkan sekali per (ukuran, kepadatan, seedIndex) dan dipakai
/// oleh semua kombinasi mode gerak dan heuristik.
class BenchmarkRunner {
  /// Membuat runner.
  BenchmarkRunner(
    this.config, {
    this.isolateMode = 'mainIsolate',
    this.buildMode = 'unknown',
  });

  /// Skenario.
  final ScenarioConfig config;

  /// Nilai kolom `isolateMode`.
  final String isolateMode;

  /// Nilai kolom `buildMode`.
  final String buildMode;

  /// Seed dasar peta untuk (ukuran, kepadatan, seedIndex).
  int mapSeed(int gridSize, int densityPct, int seedIndex) =>
      config.baseSeed +
      seedIndex * 7919 +
      gridSize * 104729 +
      densityPct * 1299709;

  /// Menjalankan seluruh skenario.
  ///
  /// [onProgress] dipanggil paling banyak sekali per [progressInterval].
  /// [isCancelled] dicek di antara run. Bila [yieldToEventLoop] true, event
  /// loop diberi kesempatan di luar bagian yang diukur (untuk main isolate).
  Future<BenchmarkResult> run({
    void Function(BenchmarkProgress)? onProgress,
    bool Function()? isCancelled,
    bool yieldToEventLoop = false,
    Duration progressInterval = const Duration(milliseconds: 250),
  }) async {
    final total = config.totalRuns;
    final records = <RunRecord>[];
    final overall = Stopwatch()..start();
    final throttle = Stopwatch()..start();
    var cancelled = false;

    _warmup();

    final heuristics = config.effectiveHeuristics;
    for (final size in config.gridSizes) {
      final solver = AStarSolver(size, size);
      final repeats = config.innerRepeatsFor(size);
      for (final density in config.obstacleDensitiesPct) {
        for (
          var seedIndex = 0;
          seedIndex < config.seedsPerConfig;
          seedIndex++
        ) {
          if (cancelled || (isCancelled?.call() ?? false)) {
            cancelled = true;
            break;
          }
          final map = MapGenerator.generate(
            width: size,
            height: size,
            densityPct: density,
            seed: mapSeed(size, density, seedIndex),
          );
          final hash = map.grid.hash;
          final obstacles = map.grid.obstacleCount;
          // Counterbalancing: rotasi urutan heuristik menurut seedIndex
          // (untuk 2 heuristik = alternasi paritas).
          final rot = seedIndex % heuristics.length;
          final order = [
            ...heuristics.sublist(rot),
            ...heuristics.sublist(0, rot),
          ];
          for (final mode in config.movementModes) {
            for (var pos = 0; pos < order.length; pos++) {
              final h = order[pos];
              final r = _measure(solver, map.grid, h, mode, repeats);
              records.add(
                RunRecord(
                  runId: records.length + 1,
                  timestamp: DateTime.now().toUtc().toIso8601String(),
                  gridSize: size,
                  obstacleDensityPct: density,
                  obstacleCount: obstacles,
                  seedIndex: seedIndex,
                  seedUsed: map.seedUsed,
                  reseedAttempts: map.reseedAttempts,
                  mapRepaired: map.repaired,
                  mapHash: hash,
                  movementMode: mode.name,
                  heuristic: h.name,
                  allowCornerCutting: config.allowCornerCutting,
                  orderInPair: pos + 1,
                  warmupRuns: config.warmupRuns,
                  innerRepeats: repeats,
                  isolateMode: isolateMode,
                  buildMode: buildMode,
                  pathFound: r.pathFound,
                  executionTimeUs: r.timeUs,
                  expandedNodes: r.expanded,
                  generatedNodes: r.generated,
                  maxOpenListSize: r.maxOpen,
                  pathCost: r.cost,
                  pathLengthSteps: r.steps,
                ),
              );
            }
          }
          if (throttle.elapsed >= progressInterval) {
            throttle.reset();
            onProgress?.call(
              BenchmarkProgress(records.length, total, overall.elapsed),
            );
            if (yieldToEventLoop) await Future<void>.delayed(Duration.zero);
          }
        }
        if (cancelled) break;
      }
      if (cancelled) break;
    }
    onProgress?.call(BenchmarkProgress(records.length, total, overall.elapsed));
    return BenchmarkResult(config, records, cancelled);
  }

  void _warmup() {
    if (config.warmupRuns <= 0) return;
    final dummy = MapGenerator.generate(
      width: 50,
      height: 50,
      densityPct: 30,
      seed: config.baseSeed - 1,
    );
    final solver = AStarSolver(50, 50);
    final hs = config.effectiveHeuristics;
    final modes = config.movementModes;
    for (var i = 0; i < config.warmupRuns; i++) {
      solver.solve(
        dummy.grid,
        hs[i % hs.length],
        modes[i % modes.length],
        allowCornerCutting: config.allowCornerCutting,
      );
    }
  }

  _Measure _measure(
    AStarSolver solver,
    GridMap grid,
    HeuristicType h,
    MovementMode mode,
    int repeats,
  ) {
    var last = solver.solve(
      grid,
      h,
      mode,
      allowCornerCutting: config.allowCornerCutting,
    );
    var timeUs = last.executionTimeUs.toDouble();
    if (repeats > 1) {
      final sw = Stopwatch()..start();
      for (var i = 0; i < repeats; i++) {
        last = solver.solve(
          grid,
          h,
          mode,
          allowCornerCutting: config.allowCornerCutting,
        );
      }
      sw.stop();
      timeUs = sw.elapsedMicroseconds / repeats;
    }
    return _Measure(
      timeUs: timeUs,
      pathFound: last.pathFound,
      expanded: last.expandedNodes,
      generated: last.generatedNodes,
      maxOpen: last.maxOpenListSize,
      cost: last.pathCost,
      steps: last.pathLengthSteps,
    );
  }
}

class _Measure {
  const _Measure({
    required this.timeUs,
    required this.pathFound,
    required this.expanded,
    required this.generated,
    required this.maxOpen,
    required this.cost,
    required this.steps,
  });
  final double timeUs;
  final bool pathFound;
  final int expanded;
  final int generated;
  final int maxOpen;
  final double cost;
  final int steps;
}
