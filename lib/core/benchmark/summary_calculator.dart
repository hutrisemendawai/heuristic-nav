import 'dart:math';

import 'run_record.dart';

/// Statistik deskriptif satu metrik.
class Stats {
  /// Membuat statistik.
  const Stats(this.n, this.mean, this.std, this.min, this.max, this.median);

  /// Menghitung statistik dari [values] (std = sampel, n-1).
  factory Stats.of(List<double> values) {
    if (values.isEmpty) {
      return const Stats(
        0,
        double.nan,
        double.nan,
        double.nan,
        double.nan,
        double.nan,
      );
    }
    final sorted = [...values]..sort();
    final n = sorted.length;
    final mean = sorted.reduce((a, b) => a + b) / n;
    var ss = 0.0;
    for (final v in sorted) {
      ss += (v - mean) * (v - mean);
    }
    final std = n > 1 ? sqrt(ss / (n - 1)) : 0.0;
    final median = n.isOdd
        ? sorted[n ~/ 2]
        : (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2;
    return Stats(n, mean, std, sorted.first, sorted.last, median);
  }

  /// Jumlah data.
  final int n;

  /// Rata-rata.
  final double mean;

  /// Simpangan baku sampel.
  final double std;

  /// Minimum.
  final double min;

  /// Maksimum.
  final double max;

  /// Median.
  final double median;
}

/// Ringkasan satu konfigurasi (ukuran, kepadatan, mode, heuristik).
class ConfigSummary {
  /// Membuat ringkasan.
  const ConfigSummary({
    required this.gridSize,
    required this.obstacleDensityPct,
    required this.movementMode,
    required this.heuristic,
    required this.n,
    required this.time,
    required this.expanded,
    required this.cost,
    required this.successRate,
  });

  /// Sisi grid.
  final int gridSize;

  /// Kepadatan (persen).
  final int obstacleDensityPct;

  /// Mode gerak.
  final String movementMode;

  /// Heuristik.
  final String heuristic;

  /// Jumlah run.
  final int n;

  /// Statistik waktu (µs).
  final Stats time;

  /// Statistik node ter-expand.
  final Stats expanded;

  /// Statistik biaya jalur (hanya run yang menemukan jalur).
  final Stats cost;

  /// Proporsi run yang menemukan jalur (0..1).
  final double successRate;
}

/// Satu baris pasangan Manhattan vs Euclidean.
class PairedRow {
  /// Membuat baris pasangan.
  const PairedRow(this.manhattan, this.euclidean);

  /// Record Manhattan.
  final RunRecord manhattan;

  /// Record Euclidean.
  final RunRecord euclidean;

  /// `(cost_manhattan - cost_euclidean) / cost_euclidean * 100` (NaN bila tak terdefinisi).
  double get costGapPct {
    final e = euclidean.pathCost;
    if (e.isNaN || manhattan.pathCost.isNaN || e == 0) return double.nan;
    return (manhattan.pathCost - e) / e * 100;
  }
}

/// Menghitung ringkasan dan pasangan dari data mentah.
class SummaryCalculator {
  /// Ringkasan per konfigurasi (urut sesuai kemunculan pertama).
  static List<ConfigSummary> summarize(List<RunRecord> records) {
    final groups = <String, List<RunRecord>>{};
    for (final r in records) {
      groups
          .putIfAbsent(
            '${r.gridSize}|${r.obstacleDensityPct}|${r.movementMode}|${r.heuristic}',
            () => [],
          )
          .add(r);
    }
    return [
      for (final g in groups.values)
        ConfigSummary(
          gridSize: g.first.gridSize,
          obstacleDensityPct: g.first.obstacleDensityPct,
          movementMode: g.first.movementMode,
          heuristic: g.first.heuristic,
          n: g.length,
          time: Stats.of([for (final r in g) r.executionTimeUs]),
          expanded: Stats.of([for (final r in g) r.expandedNodes.toDouble()]),
          cost: Stats.of([
            for (final r in g)
              if (r.pathFound) r.pathCost,
          ]),
          successRate: g.where((r) => r.pathFound).length / g.length,
        ),
    ];
  }

  /// Pasangan Manhattan/Euclidean per (ukuran, kepadatan, mode, seedIndex).
  static List<PairedRow> pair(List<RunRecord> records) {
    final man = <String, RunRecord>{};
    final euc = <String, RunRecord>{};
    final keys = <String>[];
    for (final r in records) {
      final k =
          '${r.gridSize}|${r.obstacleDensityPct}|${r.movementMode}|${r.seedIndex}';
      if (r.heuristic == 'manhattan') {
        if (!man.containsKey(k)) keys.add(k);
        man[k] = r;
      } else if (r.heuristic == 'euclidean') {
        euc[k] = r;
      }
    }
    return [
      for (final k in keys)
        if (euc.containsKey(k)) PairedRow(man[k]!, euc[k]!),
    ];
  }
}
