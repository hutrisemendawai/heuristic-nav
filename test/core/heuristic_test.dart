import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:heuristic_nav/core/pathfinding/heuristic.dart';

void main() {
  test('Manhattan', () {
    expect(heuristicValue(HeuristicType.manhattan, 3, 4), 7);
    expect(heuristicValue(HeuristicType.manhattan, 0, 0), 0);
  });
  test('Euclidean', () {
    expect(heuristicValue(HeuristicType.euclidean, 3, 4), 5);
    expect(
      heuristicValue(HeuristicType.euclidean, 1, 1),
      closeTo(sqrt(2), 1e-12),
    );
  });
  test('Octile', () {
    expect(
      heuristicValue(HeuristicType.octile, 3, 4),
      closeTo(3 * sqrt(2) + 1, 1e-12),
    );
    expect(heuristicValue(HeuristicType.octile, 5, 0), 5);
  });
}
