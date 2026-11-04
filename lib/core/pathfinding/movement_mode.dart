/// Mode gerak agen.
enum MovementMode {
  /// 4 arah, biaya langkah 1.0.
  fourDirections,

  /// 8 arah: ortogonal 1.0, diagonal sqrt(2).
  eightDirections;

  /// Parse dari nama (case-insensitive).
  static MovementMode parse(String name) => MovementMode.values.firstWhere(
    (e) => e.name.toLowerCase() == name.toLowerCase(),
    orElse: () => throw FormatException('Mode gerak tidak dikenal: $name'),
  );
}
