import 'dart:math';

/// Jenis heuristik yang tersedia.
enum HeuristicType {
  /// `dx + dy`.
  manhattan,

  /// `sqrt(dx^2 + dy^2)`.
  euclidean,

  /// `(dx + dy) + (sqrt2 - 2) * min(dx, dy)` (pembanding opsional).
  octile;

  /// Parse dari nama (case-insensitive).
  static HeuristicType parse(String name) => HeuristicType.values.firstWhere(
    (e) => e.name.toLowerCase() == name.toLowerCase(),
    orElse: () => throw FormatException('Heuristik tidak dikenal: $name'),
  );
}

/// Akar 2, biaya langkah diagonal.
final double sqrt2 = sqrt(2.0);

/// Menghitung heuristik dari selisih absolut ([dx], [dy]) ke goal.
///
/// Fungsi yang sama dipakai semua metode; tidak ada cache khusus.
double heuristicValue(HeuristicType type, int dx, int dy) {
  switch (type) {
    case HeuristicType.manhattan:
      return (dx + dy).toDouble();
    case HeuristicType.euclidean:
      return sqrt((dx * dx + dy * dy).toDouble());
    case HeuristicType.octile:
      return (dx + dy) + (sqrt2 - 2) * (dx < dy ? dx : dy);
  }
}
