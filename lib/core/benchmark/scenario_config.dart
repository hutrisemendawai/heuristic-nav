import 'dart:convert';

import '../pathfinding/heuristic.dart';
import '../pathfinding/movement_mode.dart';

/// Konfigurasi skenario benchmark (full factorial).
class ScenarioConfig {
  /// Membuat konfigurasi.
  const ScenarioConfig({
    required this.name,
    required this.gridSizes,
    required this.obstacleDensitiesPct,
    required this.movementModes,
    required this.heuristics,
    this.seedsPerConfig = 30,
    this.baseSeed = 20260101,
    this.warmupRuns = 20,
    this.innerRepeatsByGridSize = const {},
    this.allowCornerCutting = false,
    this.includeOctile = false,
    this.runOnMainIsolate = false,
    this.start = 'topLeft',
    this.goal = 'bottomRight',
  });

  /// Parse dari map JSON.
  factory ScenarioConfig.fromJson(Map<String, dynamic> json) {
    final inner = <int, int>{};
    (json['innerRepeatsByGridSize'] as Map<String, dynamic>? ?? {}).forEach(
      (k, v) => inner[int.parse(k)] = (v as num).toInt(),
    );
    final config = ScenarioConfig(
      name: json['name'] as String,
      gridSizes: [
        for (final e in json['gridSizes'] as List) (e as num).toInt(),
      ],
      obstacleDensitiesPct: [
        for (final e in json['obstacleDensitiesPct'] as List)
          (e as num).toInt(),
      ],
      movementModes: [
        for (final e in json['movementModes'] as List)
          MovementMode.parse(e as String),
      ],
      heuristics: [
        for (final e in json['heuristics'] as List)
          HeuristicType.parse(e as String),
      ],
      seedsPerConfig: (json['seedsPerConfig'] as num?)?.toInt() ?? 30,
      baseSeed: (json['baseSeed'] as num?)?.toInt() ?? 20260101,
      warmupRuns: (json['warmupRuns'] as num?)?.toInt() ?? 20,
      innerRepeatsByGridSize: inner,
      allowCornerCutting: json['allowCornerCutting'] as bool? ?? false,
      includeOctile: json['includeOctile'] as bool? ?? false,
      runOnMainIsolate: json['runOnMainIsolate'] as bool? ?? false,
      start: json['start'] as String? ?? 'topLeft',
      goal: json['goal'] as String? ?? 'bottomRight',
    );
    config.validate();
    return config;
  }

  /// Parse dari string JSON.
  factory ScenarioConfig.fromJsonString(String source) =>
      ScenarioConfig.fromJson(jsonDecode(source) as Map<String, dynamic>);

  /// Nama skenario.
  final String name;

  /// Ukuran sisi grid (grid persegi).
  final List<int> gridSizes;

  /// Kepadatan rintangan dalam persen.
  final List<int> obstacleDensitiesPct;

  /// Mode gerak yang diuji.
  final List<MovementMode> movementModes;

  /// Heuristik yang diuji (Octile ditambahkan bila [includeOctile]).
  final List<HeuristicType> heuristics;

  /// Jumlah seed/peta per (ukuran, kepadatan).
  final int seedsPerConfig;

  /// Seed dasar.
  final int baseSeed;

  /// Jumlah run warm-up pada peta dummy.
  final int warmupRuns;

  /// Inner repetition per ukuran grid (default 1).
  final Map<int, int> innerRepeatsByGridSize;

  /// Kebijakan corner-cutting (default false = dilarang).
  final bool allowCornerCutting;

  /// Menambahkan Octile sebagai pembanding.
  final bool includeOctile;

  /// Jalankan di main isolate (bukan isolate terpisah).
  final bool runOnMainIsolate;

  /// Posisi start (hanya `topLeft` didukung).
  final String start;

  /// Posisi goal (hanya `bottomRight` didukung).
  final String goal;

  /// Heuristik efektif termasuk Octile bila diaktifkan.
  List<HeuristicType> get effectiveHeuristics => [
    ...heuristics,
    if (includeOctile && !heuristics.contains(HeuristicType.octile))
      HeuristicType.octile,
  ];

  /// Inner repeats untuk [gridSize].
  int innerRepeatsFor(int gridSize) => innerRepeatsByGridSize[gridSize] ?? 1;

  /// Jumlah konfigurasi (ukuran x kepadatan x mode x heuristik).
  int get configurationCount =>
      gridSizes.length *
      obstacleDensitiesPct.length *
      movementModes.length *
      effectiveHeuristics.length;

  /// Total run = konfigurasi x seed.
  int get totalRuns => configurationCount * seedsPerConfig;

  /// Validasi nilai konfigurasi.
  void validate() {
    if (start != 'topLeft' || goal != 'bottomRight') {
      throw const FormatException(
        'Hanya start=topLeft dan goal=bottomRight yang didukung',
      );
    }
    if (gridSizes.any((e) => e < 2)) {
      throw const FormatException('gridSizes harus >= 2');
    }
    if (obstacleDensitiesPct.any((e) => e < 0 || e > 90)) {
      throw const FormatException('obstacleDensitiesPct harus 0..90');
    }
    if (seedsPerConfig < 1) {
      throw const FormatException('seedsPerConfig harus >= 1');
    }
    if (gridSizes.isEmpty ||
        obstacleDensitiesPct.isEmpty ||
        movementModes.isEmpty ||
        heuristics.isEmpty) {
      throw const FormatException('Daftar faktor tidak boleh kosong');
    }
  }

  /// Serialisasi ke JSON.
  Map<String, dynamic> toJson() => {
    'name': name,
    'gridSizes': gridSizes,
    'obstacleDensitiesPct': obstacleDensitiesPct,
    'movementModes': [for (final e in movementModes) e.name],
    'heuristics': [for (final e in heuristics) e.name],
    'seedsPerConfig': seedsPerConfig,
    'baseSeed': baseSeed,
    'warmupRuns': warmupRuns,
    'innerRepeatsByGridSize': {
      for (final e in innerRepeatsByGridSize.entries) '${e.key}': e.value,
    },
    'allowCornerCutting': allowCornerCutting,
    'includeOctile': includeOctile,
    'runOnMainIsolate': runOnMainIsolate,
    'start': start,
    'goal': goal,
  };
}
