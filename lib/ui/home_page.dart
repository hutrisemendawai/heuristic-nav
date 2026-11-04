import 'package:flutter/material.dart';

import 'benchmark_page.dart';
import 'visualizer_page.dart';

/// Halaman awal: pilih Benchmark atau Visualizer.
class HomePage extends StatelessWidget {
  /// Membuat halaman.
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('A* Manhattan vs Euclidean')),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const BenchmarkPage()),
            ),
            child: const Text('Benchmark'),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const VisualizerPage()),
            ),
            child: const Text('Visualizer'),
          ),
        ],
      ),
    ),
  );
}
