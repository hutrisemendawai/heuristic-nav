import 'package:flutter/material.dart';

import 'ui/home_page.dart';

void main() => runApp(const HeuristicNavApp());

/// Aplikasi testbed eksperimen A* Manhattan vs Euclidean.
class HeuristicNavApp extends StatelessWidget {
  /// Membuat aplikasi.
  const HeuristicNavApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Heuristic Nav',
    theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
    home: const HomePage(),
  );
}
