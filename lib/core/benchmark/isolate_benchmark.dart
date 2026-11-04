import 'dart:async';
import 'dart:isolate';

import 'benchmark_runner.dart';
import 'scenario_config.dart';

/// Mendeteksi build mode dari konstanta compile-time Dart VM.
String detectBuildMode() {
  if (const bool.fromEnvironment('dart.vm.product')) return 'release';
  if (const bool.fromEnvironment('dart.vm.profile')) return 'profile';
  return 'debug';
}

/// Handle benchmark yang berjalan; mendukung pembatalan.
class BenchmarkHandle {
  BenchmarkHandle._(this.result, this._cancel);

  /// Hasil akhir (selesai atau dibatalkan). Error isolate -> exception.
  final Future<BenchmarkResult> result;
  final void Function() _cancel;

  /// Membatalkan benchmark.
  void cancel() => _cancel();
}

/// Menjalankan benchmark sesuai `config.runOnMainIsolate`.
///
/// Mode isolate terpisah: seluruh pengukuran terjadi di dalam isolate itu.
BenchmarkHandle startBenchmark(
  ScenarioConfig config, {
  String? buildMode,
  void Function(BenchmarkProgress)? onProgress,
}) {
  final build = buildMode ?? detectBuildMode();
  if (config.runOnMainIsolate) {
    var cancelled = false;
    final future =
        BenchmarkRunner(
          config,
          isolateMode: 'mainIsolate',
          buildMode: build,
        ).run(
          onProgress: onProgress,
          isCancelled: () => cancelled,
          yieldToEventLoop: true,
        );
    return BenchmarkHandle._(future, () => cancelled = true);
  }

  final completer = Completer<BenchmarkResult>();
  final receive = ReceivePort();
  final errors = ReceivePort();
  Isolate? isolate;
  var cancelRequested = false;

  void finish(void Function() f) {
    receive.close();
    errors.close();
    isolate?.kill(priority: Isolate.immediate);
    f();
  }

  receive.listen((message) {
    if (message is List && message.length == 4 && message[0] == 'progress') {
      onProgress?.call(
        BenchmarkProgress(
          message[1] as int,
          message[2] as int,
          Duration(microseconds: message[3] as int),
        ),
      );
    } else if (message is BenchmarkResult) {
      finish(() => completer.complete(message));
    }
  });
  errors.listen((e) {
    finish(
      () => completer.completeError(
        StateError('Isolate error: ${(e as List).first}'),
      ),
    );
  });

  Isolate.spawn<List<Object>>(_entry, [
    receive.sendPort,
    config,
    build,
  ], onError: errors.sendPort).then((i) {
    isolate = i;
    if (cancelRequested) i.kill(priority: Isolate.immediate);
  });

  return BenchmarkHandle._(completer.future, () {
    cancelRequested = true;
    // Isolate dihentikan; hasil parsial tidak dikirim.
    finish(() {
      if (!completer.isCompleted) {
        completer.complete(BenchmarkResult(config, const [], true));
      }
    });
  });
}

Future<void> _entry(List<Object> args) async {
  final port = args[0] as SendPort;
  final config = args[1] as ScenarioConfig;
  final build = args[2] as String;
  final runner = BenchmarkRunner(
    config,
    isolateMode: 'separateIsolate',
    buildMode: build,
  );
  final result = await runner.run(
    onProgress: (p) =>
        port.send(['progress', p.completed, p.total, p.elapsed.inMicroseconds]),
  );
  port.send(result);
}
