import 'dart:convert';
import 'dart:io';

import 'benchmark_runner.dart';
import 'run_record.dart';
import 'summary_calculator.dart';

/// Penulis CSV/JSON hasil benchmark.
class CsvExporter {
  /// Header CSV mentah (urutan tetap). `mapHash` dan `mapRepaired` ditambahkan
  /// setelah `reseedAttempts`.
  static const List<String> rawHeader = [
    'runId',
    'timestamp',
    'gridSize',
    'width',
    'height',
    'obstacleDensityPct',
    'obstacleCount',
    'seedIndex',
    'seedUsed',
    'reseedAttempts',
    'mapRepaired',
    'mapHash',
    'movementMode',
    'heuristic',
    'allowCornerCutting',
    'orderInPair',
    'warmupRuns',
    'innerRepeats',
    'isolateMode',
    'buildMode',
    'pathFound',
    'executionTimeUs',
    'expandedNodes',
    'generatedNodes',
    'maxOpenListSize',
    'pathCost',
    'pathLengthSteps',
  ];

  /// Header CSV ringkasan.
  static final List<String> summaryHeader = [
    'gridSize',
    'obstacleDensityPct',
    'movementMode',
    'heuristic',
    'n',
    'successRate',
    ..._statCols('executionTimeUs'),
    ..._statCols('expandedNodes'),
    ..._statCols('pathCost'),
  ];

  /// Header CSV pasangan.
  static const List<String> pairedHeader = [
    'gridSize',
    'obstacleDensityPct',
    'movementMode',
    'seedIndex',
    'mapHash',
    'pathFound_manhattan',
    'pathFound_euclidean',
    'timeUs_manhattan',
    'timeUs_euclidean',
    'expanded_manhattan',
    'expanded_euclidean',
    'cost_manhattan',
    'cost_euclidean',
    'costGapPct',
  ];

  static const List<String> _suffix = ['mean', 'std', 'min', 'max', 'median'];

  static String _f(double v) => v.isNaN ? '' : v.toString();

  static String _esc(String s) =>
      s.contains(RegExp(r'[",\n]')) ? '"${s.replaceAll('"', '""')}"' : s;

  static String _line(List<Object> cells) =>
      cells.map((c) => _esc('$c')).join(',');

  /// CSV mentah, satu baris per run.
  static String rawCsv(List<RunRecord> records) {
    final b = StringBuffer()..writeln(rawHeader.join(','));
    for (final r in records) {
      b.writeln(
        _line([
          r.runId,
          r.timestamp,
          r.gridSize,
          r.gridSize,
          r.gridSize,
          r.obstacleDensityPct,
          r.obstacleCount,
          r.seedIndex,
          r.seedUsed,
          r.reseedAttempts,
          r.mapRepaired,
          r.mapHash,
          r.movementMode,
          r.heuristic,
          r.allowCornerCutting,
          r.orderInPair,
          r.warmupRuns,
          r.innerRepeats,
          r.isolateMode,
          r.buildMode,
          r.pathFound,
          r.executionTimeUs.toStringAsFixed(3),
          r.expandedNodes,
          r.generatedNodes,
          r.maxOpenListSize,
          _f(r.pathCost),
          r.pathLengthSteps,
        ]),
      );
    }
    return b.toString();
  }

  /// CSV ringkasan per konfigurasi.
  static String summaryCsv(List<RunRecord> records) {
    final b = StringBuffer()..writeln(summaryHeader.join(','));
    for (final s in SummaryCalculator.summarize(records)) {
      List<String> st(Stats x) =>
          [x.mean, x.std, x.min, x.max, x.median].map(_f).toList();
      b.writeln(
        _line([
          s.gridSize,
          s.obstacleDensityPct,
          s.movementMode,
          s.heuristic,
          s.n,
          s.successRate,
          ...st(s.time),
          ...st(s.expanded),
          ...st(s.cost),
        ]),
      );
    }
    return b.toString();
  }

  /// CSV pasangan Manhattan vs Euclidean.
  static String pairedCsv(List<RunRecord> records) {
    final b = StringBuffer()..writeln(pairedHeader.join(','));
    for (final p in SummaryCalculator.pair(records)) {
      final m = p.manhattan, e = p.euclidean;
      b.writeln(
        _line([
          m.gridSize,
          m.obstacleDensityPct,
          m.movementMode,
          m.seedIndex,
          m.mapHash == e.mapHash ? m.mapHash : 'MISMATCH',
          m.pathFound,
          e.pathFound,
          m.executionTimeUs.toStringAsFixed(3),
          e.executionTimeUs.toStringAsFixed(3),
          m.expandedNodes,
          e.expandedNodes,
          _f(m.pathCost),
          _f(e.pathCost),
          _f(p.costGapPct),
        ]),
      );
    }
    return b.toString();
  }

  /// Metadata JSON (untuk Tabel 3 paper).
  static String metadataJson(
    BenchmarkResult result, {
    Map<String, Object?> environment = const {},
  }) {
    final cfg = result.config;
    return const JsonEncoder.withIndent('  ').convert({
      'date': DateTime.now().toUtc().toIso8601String(),
      'cancelled': result.cancelled,
      'totalRows': result.records.length,
      'allowCornerCutting': cfg.allowCornerCutting,
      'tieBreakingRule': 'f asc, then h asc, then node index asc',
      'closedPolicy': 'closed nodes are never reopened',
      'environment': environment,
      'scenario': cfg.toJson(),
    });
  }

  /// Timestamp untuk nama file, mis. `20260101T120000`.
  static String fileTimestamp([DateTime? now]) {
    final t = (now ?? DateTime.now()).toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}${two(t.month)}${two(t.day)}T'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}';
  }

  /// Menulis 3 CSV + 1 JSON ke [dir]; mengembalikan daftar path file.
  static Future<List<String>> writeAll(
    Directory dir,
    BenchmarkResult result, {
    Map<String, Object?> environment = const {},
    String? timestamp,
  }) async {
    await dir.create(recursive: true);
    final ts = timestamp ?? fileTimestamp();
    final files = <String, String>{
      'results_raw_$ts.csv': rawCsv(result.records),
      'results_summary_$ts.csv': summaryCsv(result.records),
      'results_paired_$ts.csv': pairedCsv(result.records),
      'run_metadata_$ts.json': metadataJson(result, environment: environment),
    };
    final paths = <String>[];
    for (final e in files.entries) {
      final f = File('${dir.path}${Platform.pathSeparator}${e.key}');
      await f.writeAsString(e.value);
      paths.add(f.path);
    }
    return paths;
  }
}

List<String> _statCols(String metric) => [
  for (final s in CsvExporter._suffix) '${metric}_$s',
];
