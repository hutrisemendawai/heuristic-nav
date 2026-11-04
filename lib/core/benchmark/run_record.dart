/// Satu baris data mentah (satu run).
class RunRecord {
  /// Membuat record.
  const RunRecord({
    required this.runId,
    required this.timestamp,
    required this.gridSize,
    required this.obstacleDensityPct,
    required this.obstacleCount,
    required this.seedIndex,
    required this.seedUsed,
    required this.reseedAttempts,
    required this.mapRepaired,
    required this.mapHash,
    required this.movementMode,
    required this.heuristic,
    required this.allowCornerCutting,
    required this.orderInPair,
    required this.warmupRuns,
    required this.innerRepeats,
    required this.isolateMode,
    required this.buildMode,
    required this.pathFound,
    required this.executionTimeUs,
    required this.expandedNodes,
    required this.generatedNodes,
    required this.maxOpenListSize,
    required this.pathCost,
    required this.pathLengthSteps,
  });

  /// Nomor urut run (mulai 1).
  final int runId;

  /// Waktu run (ISO 8601 UTC).
  final String timestamp;

  /// Sisi grid.
  final int gridSize;

  /// Kepadatan (persen).
  final int obstacleDensityPct;

  /// Jumlah rintangan aktual.
  final int obstacleCount;

  /// Index seed (0..N-1).
  final int seedIndex;

  /// Seed efektif setelah re-seed.
  final int seedUsed;

  /// Jumlah re-seed.
  final int reseedAttempts;

  /// Apakah peta diperbaiki lewat koridor (fallback).
  final bool mapRepaired;

  /// Hash peta.
  final String mapHash;

  /// Nama mode gerak.
  final String movementMode;

  /// Nama heuristik.
  final String heuristic;

  /// Kebijakan corner-cutting.
  final bool allowCornerCutting;

  /// Urutan eksekusi dalam pasangan (1-based).
  final int orderInPair;

  /// Jumlah warm-up.
  final int warmupRuns;

  /// Inner repeats.
  final int innerRepeats;

  /// `mainIsolate` atau `separateIsolate`.
  final String isolateMode;

  /// Build mode (debug/profile/release/...).
  final String buildMode;

  /// Jalur ditemukan.
  final bool pathFound;

  /// Waktu eksekusi rata-rata per solve (mikrodetik).
  final double executionTimeUs;

  /// Node ter-expand.
  final int expandedNodes;

  /// Node ter-generate.
  final int generatedNodes;

  /// Ukuran maksimum open list.
  final int maxOpenListSize;

  /// Biaya jalur (NaN bila tidak ditemukan).
  final double pathCost;

  /// Jumlah langkah jalur.
  final int pathLengthSteps;
}
