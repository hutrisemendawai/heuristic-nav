import 'dart:io';

import 'package:heuristic_nav/core/benchmark/benchmark_runner.dart';
import 'package:heuristic_nav/core/benchmark/csv_exporter.dart';
import 'package:heuristic_nav/core/benchmark/scenario_config.dart';

/// CLI headless: `dart run bin/benchmark_cli.dart --scenario <json> --out <dir>`.
Future<void> main(List<String> args) async {
  String? scenarioPath;
  var outDir = './out';
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--scenario':
        scenarioPath = args[++i];
      case '--out':
        outDir = args[++i];
      default:
        stderr.writeln('Argumen tidak dikenal: ${args[i]}');
        exit(64);
    }
  }
  if (scenarioPath == null) {
    stderr.writeln(
      'Usage: dart run bin/benchmark_cli.dart --scenario <file.json> [--out <dir>]',
    );
    exit(64);
  }
  final config = ScenarioConfig.fromJsonString(
    await File(scenarioPath).readAsString(),
  );
  stdout.writeln('Skenario ${config.name}: ${config.totalRuns} run');
  final runner = BenchmarkRunner(
    config,
    isolateMode: 'mainIsolate',
    buildMode: 'cli-jit-or-aot',
  );
  final result = await runner.run(
    onProgress: (p) => stdout.writeln(
      '[${p.completed}/${p.total}] ${p.elapsed.inSeconds}s elapsed',
    ),
  );
  final files = await CsvExporter.writeAll(
    Directory(outDir),
    result,
    environment: {
      'runtime': 'Dart CLI',
      'dartVersion': Platform.version,
      'flutterVersion': 'n/a (CLI)',
      'flameVersion': 'n/a (CLI)',
      'buildMode': runner.buildMode,
      'os': Platform.operatingSystem,
      'osVersion': Platform.operatingSystemVersion,
      'deviceModel': 'n/a (CLI host)',
      'processorCount': Platform.numberOfProcessors,
    },
  );
  for (final f in files) {
    stdout.writeln('Ditulis: $f');
  }
}
