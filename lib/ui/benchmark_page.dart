import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/benchmark/benchmark_runner.dart';
import '../core/benchmark/csv_exporter.dart';
import '../core/benchmark/isolate_benchmark.dart';
import '../core/benchmark/scenario_config.dart';
import '../core/benchmark/summary_calculator.dart';

/// Versi Flame yang dipakai (sinkron dengan pubspec.yaml).
const String kFlameVersion = '1.38.2';

/// Halaman menjalankan benchmark, melihat ringkasan, dan ekspor CSV.
class BenchmarkPage extends StatefulWidget {
  /// Membuat halaman.
  const BenchmarkPage({super.key});

  @override
  State<BenchmarkPage> createState() => _BenchmarkPageState();
}

class _BenchmarkPageState extends State<BenchmarkPage> {
  static const _assets = ['full_factorial.json', 'smoke_test.json'];

  String _asset = _assets.last;
  ScenarioConfig? _customConfig;
  final _pathController = TextEditingController();
  BenchmarkHandle? _handle;
  BenchmarkProgress? _progress;
  BenchmarkResult? _result;
  List<String> _files = [];
  String? _error;
  bool _running = false;

  @override
  void dispose() {
    _handle?.cancel();
    _pathController.dispose();
    super.dispose();
  }

  Future<ScenarioConfig> _loadConfig() async {
    if (_asset == 'custom') {
      final c = _customConfig;
      if (c == null) throw const FormatException('Belum ada JSON dimuat');
      return c;
    }
    return ScenarioConfig.fromJsonString(
      await rootBundle.loadString('assets/scenarios/$_asset'),
    );
  }

  Future<void> _loadFromPath() async {
    try {
      final c = ScenarioConfig.fromJsonString(
        await File(_pathController.text.trim()).readAsString(),
      );
      setState(() {
        _customConfig = c;
        _asset = 'custom';
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'Gagal memuat JSON: $e');
    }
  }

  Future<void> _run() async {
    setState(() {
      _running = true;
      _result = null;
      _files = [];
      _error = null;
      _progress = null;
    });
    var lastUpdate = DateTime.fromMillisecondsSinceEpoch(0);
    try {
      final config = await _loadConfig();
      final handle = startBenchmark(
        config,
        onProgress: (p) {
          final now = DateTime.now();
          final done = p.completed >= p.total;
          if (!done && now.difference(lastUpdate).inMilliseconds < 250) return;
          lastUpdate = now;
          if (mounted) setState(() => _progress = p);
        },
      );
      _handle = handle;
      final result = await handle.result;
      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<Map<String, Object?>> _environment() async {
    final info = <String, Object?>{
      'runtime': 'Flutter app',
      'dartVersion': Platform.version,
      'flutterVersion': const String.fromEnvironment(
        'FLUTTER_VERSION',
        defaultValue: 'see `flutter --version`',
      ),
      'flameVersion': kFlameVersion,
      'buildMode': detectBuildMode(),
      'kDebugMode': kDebugMode,
      'os': Platform.operatingSystem,
      'osVersion': Platform.operatingSystemVersion,
      'processorCount': Platform.numberOfProcessors,
    };
    try {
      info['deviceInfo'] = (await DeviceInfoPlugin().deviceInfo).data;
    } catch (e) {
      info['deviceInfo'] = 'unavailable: $e';
    }
    return info;
  }

  Future<void> _export({required bool share}) async {
    final result = _result;
    if (result == null) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final files = await CsvExporter.writeAll(
        dir,
        result,
        environment: await _environment(),
      );
      setState(() => _files = files);
      if (share) {
        await SharePlus.instance.share(
          ShareParams(files: [for (final f in files) XFile(f)]),
        );
      }
    } catch (e) {
      setState(() => _error = 'Ekspor gagal: $e');
    }
  }

  String _fmt(Duration? d) => d == null ? '-' : '${d.inSeconds}s';

  @override
  Widget build(BuildContext context) {
    final p = _progress;
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('Benchmark')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (kDebugMode)
            Container(
              color: Colors.amber.shade200,
              padding: const EdgeInsets.all(8),
              child: const Text(
                'PERINGATAN: debug mode. Hasil TIDAK valid untuk publikasi; '
                'gunakan flutter run --profile atau --release.',
              ),
            ),
          Row(
            children: [
              DropdownButton<String>(
                value: _asset,
                items: [
                  for (final a in _assets)
                    DropdownMenuItem(value: a, child: Text(a)),
                  if (_customConfig != null)
                    const DropdownMenuItem(
                      value: 'custom',
                      child: Text('custom JSON'),
                    ),
                ],
                onChanged: _running ? null : (v) => setState(() => _asset = v!),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pathController,
                  decoration: const InputDecoration(
                    labelText: 'Path file skenario JSON (opsional)',
                  ),
                ),
              ),
              TextButton(
                onPressed: _running ? null : _loadFromPath,
                child: const Text('Muat'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton(
                onPressed: _running ? null : _run,
                child: const Text('Run Benchmark'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _running ? _handle?.cancel : null,
                child: const Text('Cancel'),
              ),
            ],
          ),
          if (_running || p != null) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: p == null ? null : p.completed / p.total,
            ),
            Text(
              p == null
                  ? 'Memulai...'
                  : '${p.completed}/${p.total} run, sisa ~${_fmt(p.estimatedRemaining)}',
            ),
          ],
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          if (result != null) ...[
            const SizedBox(height: 8),
            Text(
              result.cancelled
                  ? 'Dibatalkan.'
                  : 'Selesai: ${result.records.length} baris.',
            ),
            if (!result.cancelled && result.records.isNotEmpty) ...[
              Row(
                children: [
                  FilledButton(
                    onPressed: () => _export(share: false),
                    child: const Text('Export CSV'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => _export(share: true),
                    child: const Text('Export & Share'),
                  ),
                ],
              ),
              for (final f in _files) SelectableText(f),
              _SummaryTable(SummaryCalculator.summarize(result.records)),
            ],
          ],
        ],
      ),
    );
  }
}

class _SummaryTable extends StatelessWidget {
  const _SummaryTable(this.rows);
  final List<ConfigSummary> rows;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: DataTable(
      columns: const [
        DataColumn(label: Text('Grid')),
        DataColumn(label: Text('Dens%')),
        DataColumn(label: Text('Mode')),
        DataColumn(label: Text('Heur')),
        DataColumn(label: Text('Time µs')),
        DataColumn(label: Text('Expanded')),
        DataColumn(label: Text('Cost')),
      ],
      rows: [
        for (final r in rows)
          DataRow(
            cells: [
              DataCell(Text('${r.gridSize}')),
              DataCell(Text('${r.obstacleDensityPct}')),
              DataCell(Text(r.movementMode == 'fourDirections' ? '4' : '8')),
              DataCell(Text(r.heuristic)),
              DataCell(Text(r.time.mean.toStringAsFixed(1))),
              DataCell(Text(r.expanded.mean.toStringAsFixed(1))),
              DataCell(Text(r.cost.mean.toStringAsFixed(3))),
            ],
          ),
      ],
    ),
  );
}
