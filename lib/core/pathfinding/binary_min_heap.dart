import 'dart:typed_data';

/// Binary min-heap berbasis array integer/double (tanpa objek per entry).
///
/// Urutan: f terkecil, lalu h terkecil, lalu index node terkecil
/// (deterministik). Duplikat node diperbolehkan (lazy deletion).
class BinaryMinHeap {
  /// Membuat heap dengan kapasitas awal [capacity].
  BinaryMinHeap([int capacity = 64])
    : _node = Int32List(capacity),
      _f = Float64List(capacity),
      _h = Float64List(capacity);

  Int32List _node;
  Float64List _f;
  Float64List _h;
  int _length = 0;

  /// Node hasil [pop] terakhir.
  int poppedNode = -1;

  /// Nilai f hasil [pop] terakhir.
  double poppedF = 0;

  /// Jumlah entry (termasuk stale).
  int get length => _length;

  /// Apakah kosong.
  bool get isEmpty => _length == 0;

  /// Mengosongkan heap tanpa membebaskan memori.
  void clear() => _length = 0;

  bool _less(int a, int b) {
    if (_f[a] != _f[b]) return _f[a] < _f[b];
    if (_h[a] != _h[b]) return _h[a] < _h[b];
    return _node[a] < _node[b];
  }

  void _swap(int a, int b) {
    final n = _node[a];
    _node[a] = _node[b];
    _node[b] = n;
    final f = _f[a];
    _f[a] = _f[b];
    _f[b] = f;
    final h = _h[a];
    _h[a] = _h[b];
    _h[b] = h;
  }

  void _grow() {
    final cap = _node.length * 2;
    _node = Int32List(cap)..setRange(0, _length, _node);
    _f = Float64List(cap)..setRange(0, _length, _f);
    _h = Float64List(cap)..setRange(0, _length, _h);
  }

  /// Memasukkan [node] dengan key [f] dan tie-breaker [h].
  void push(int node, double f, double h) {
    if (_length == _node.length) _grow();
    var i = _length++;
    _node[i] = node;
    _f[i] = f;
    _h[i] = h;
    while (i > 0) {
      final p = (i - 1) >> 1;
      if (!_less(i, p)) break;
      _swap(i, p);
      i = p;
    }
  }

  /// Mengeluarkan entry terkecil; hasil di [poppedNode] dan [poppedF].
  void pop() {
    if (_length == 0) throw StateError('Heap kosong');
    poppedNode = _node[0];
    poppedF = _f[0];
    _length--;
    if (_length > 0) {
      _node[0] = _node[_length];
      _f[0] = _f[_length];
      _h[0] = _h[_length];
      var i = 0;
      while (true) {
        final l = 2 * i + 1, r = l + 1;
        var m = i;
        if (l < _length && _less(l, m)) m = l;
        if (r < _length && _less(r, m)) m = r;
        if (m == i) break;
        _swap(i, m);
        i = m;
      }
    }
  }
}
