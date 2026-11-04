import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../core/grid/grid_map.dart';
import '../core/grid/map_generator.dart';
import '../core/pathfinding/astar_solver.dart';
import '../core/pathfinding/heuristic.dart';
import '../core/pathfinding/movement_mode.dart';
import '../core/pathfinding/pathfinding_result.dart';
import '../game/pathfinding_game.dart';

/// Demo visual satu skenario, termasuk mode Compare berdampingan.
class VisualizerPage extends StatefulWidget {
  /// Membuat halaman.
  const VisualizerPage({super.key});

  @override
  State<VisualizerPage> createState() => _VisualizerPageState();
}

class _VisualizerPageState extends State<VisualizerPage> {
  final PathfindingGame _game = PathfindingGame();
  int _size = 50;
  int _density = 30;
  int _seed = 1;
  MovementMode _mode = MovementMode.eightDirections;
  HeuristicType _heuristic = HeuristicType.euclidean;
  GridMap? _grid;
  String _info = 'Tekan Generate Map.';

  void _generate() {
    final m = MapGenerator.generate(
      width: _size,
      height: _size,
      densityPct: _density,
      seed: _seed,
    );
    _grid = m.grid;
    _game.clearPanels();
    setState(
      () => _info =
          'Peta ${_size}x$_size, ${m.grid.obstacleCount} rintangan, seedUsed=${m.seedUsed}',
    );
  }

  PathfindingResult _solve(HeuristicType h) => AStarSolver(
    _size,
    _size,
  ).solve(_grid!, h, _mode, collectExploredOrder: true);

  String _describe(String name, PathfindingResult r) =>
      '$name: expanded=${r.expandedNodes}, cost=${r.pathCost.toStringAsFixed(3)}, '
      'time=${r.executionTimeUs}µs';

  void _run() {
    if (_grid == null) _generate();
    final r = _solve(_heuristic);
    _game.showSingle(_grid!, r);
    setState(() => _info = _describe(_heuristic.name, r));
  }

  void _compare() {
    if (_grid == null) _generate();
    final m = _solve(HeuristicType.manhattan);
    final e = _solve(HeuristicType.euclidean);
    _game.showCompare(_grid!, m, e);
    setState(
      () =>
          _info = '${_describe('Manhattan', m)}\n${_describe('Euclidean', e)}',
    );
  }

  Widget _dropdown<T>(
    String label,
    T value,
    List<T> items,
    String Function(T) text,
    void Function(T) onChanged,
  ) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('$label '),
      DropdownButton<T>(
        value: value,
        items: [
          for (final i in items)
            DropdownMenuItem(value: i, child: Text(text(i))),
        ],
        onChanged: (v) => setState(() => onChanged(v as T)),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Visualizer')),
    body: Column(
      children: [
        Wrap(
          spacing: 12,
          children: [
            _dropdown<int>(
              'Ukuran',
              _size,
              [20, 50, 100],
              (v) => '$v',
              (v) => _size = v,
            ),
            _dropdown<int>(
              'Kepadatan',
              _density,
              [10, 30, 50],
              (v) => '$v%',
              (v) => _density = v,
            ),
            _dropdown<int>(
              'Seed',
              _seed,
              [for (var i = 1; i <= 30; i++) i],
              (v) => '$v',
              (v) => _seed = v,
            ),
            _dropdown<MovementMode>(
              'Gerak',
              _mode,
              MovementMode.values,
              (v) => v == MovementMode.fourDirections ? '4 arah' : '8 arah',
              (v) => _mode = v,
            ),
            _dropdown<HeuristicType>(
              'Heuristik',
              _heuristic,
              HeuristicType.values,
              (v) => v.name,
              (v) => _heuristic = v,
            ),
            FilledButton(
              onPressed: _generate,
              child: const Text('Generate Map'),
            ),
            FilledButton(onPressed: _run, child: const Text('Run A*')),
            FilledButton.tonal(
              onPressed: _compare,
              child: const Text('Compare'),
            ),
          ],
        ),
        Padding(padding: const EdgeInsets.all(8), child: Text(_info)),
        Expanded(child: GameWidget(game: _game)),
      ],
    ),
  );
}
