import 'dart:typed_data';

/// Hasil satu pemanggilan solver A*.
class PathfindingResult {
  /// Membuat hasil.
  const PathfindingResult({
    required this.pathFound,
    required this.expandedNodes,
    required this.generatedNodes,
    required this.maxOpenListSize,
    required this.pathCost,
    required this.pathLengthSteps,
    required this.executionTimeUs,
    required this.path,
    this.exploredOrder,
  });

  /// Apakah jalur ditemukan.
  final bool pathFound;

  /// Node unik yang di-pop dan masuk closed (entry stale diabaikan).
  final int expandedNodes;

  /// Jumlah operasi push ke open list.
  final int generatedNodes;

  /// Ukuran maksimum open list (termasuk entry stale).
  final int maxOpenListSize;

  /// Akumulasi biaya langkah sepanjang jalur (NaN bila tidak ditemukan).
  final double pathCost;

  /// Jumlah langkah (jumlah sel jalur - 1); 0 bila tidak ditemukan.
  final int pathLengthSteps;

  /// Waktu eksekusi dalam mikrodetik (satu run).
  final int executionTimeUs;

  /// Index sel jalur dari start ke goal (kosong bila tidak ditemukan).
  final Int32List path;

  /// Urutan node yang di-expand (hanya jika `collectExploredOrder`).
  final Int32List? exploredOrder;
}
