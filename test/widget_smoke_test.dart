import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heuristic_nav/main.dart';

void main() {
  testWidgets('home page shows navigation buttons', (tester) async {
    await tester.pumpWidget(const HeuristicNavApp());
    expect(find.text('Benchmark'), findsOneWidget);
    expect(find.text('Visualizer'), findsOneWidget);
    expect(find.byType(FilledButton), findsNWidgets(2));
  });
}
