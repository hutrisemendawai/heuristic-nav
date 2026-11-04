import 'package:flutter_test/flutter_test.dart';
import 'package:heuristic_nav/core/pathfinding/binary_min_heap.dart';

void main() {
  test('pop order by f', () {
    final h = BinaryMinHeap(2);
    for (final f in [5.0, 1.0, 4.0, 2.0, 3.0, 9.0, 0.5]) {
      h.push(f.toInt(), f, 0);
    }
    final out = <double>[];
    while (!h.isEmpty) {
      h.pop();
      out.add(h.poppedF);
    }
    expect(out, [0.5, 1.0, 2.0, 3.0, 4.0, 5.0, 9.0]);
  });

  test('tie-breaking: f, then h, then index', () {
    final h = BinaryMinHeap();
    h.push(7, 10, 3);
    h.push(2, 10, 5);
    h.push(9, 10, 3);
    h.push(1, 11, 0);
    final out = <int>[];
    while (!h.isEmpty) {
      h.pop();
      out.add(h.poppedNode);
    }
    expect(out, [7, 9, 2, 1]);
  });

  test('duplicates allowed and clear works', () {
    final h = BinaryMinHeap()
      ..push(1, 2, 0)
      ..push(1, 1, 0);
    expect(h.length, 2);
    h.clear();
    expect(h.isEmpty, isTrue);
    expect(h.pop, throwsStateError);
  });
}
