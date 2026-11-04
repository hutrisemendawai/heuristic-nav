import 'dart:typed_data';

/// Occupancy grid disimpan flat (`index = y * width + x`).
///
/// Nilai sel: 0 = bebas, 1 = rintangan.
class GridMap {
  /// Membuat grid dari [cells] (panjang harus `width * height`).
  GridMap(this.width, this.height, this.cells)
    : assert(cells.length == width * height);

  /// Membuat grid kosong (tanpa rintangan).
  factory GridMap.empty(int width, int height) =>
      GridMap(width, height, Uint8List(width * height));

  /// Lebar grid (jumlah kolom).
  final int width;

  /// Tinggi grid (jumlah baris).
  final int height;

  /// Data sel flat.
  final Uint8List cells;

  /// Jumlah sel.
  int get size => width * height;

  /// Index sel start (0,0).
  int get startIndex => 0;

  /// Index sel goal (W-1,H-1).
  int get goalIndex => width * height - 1;

  /// Apakah sel (x,y) rintangan.
  bool isBlocked(int x, int y) => cells[y * width + x] != 0;

  /// Menandai sel (x,y).
  void setBlocked(int x, int y, bool blocked) =>
      cells[y * width + x] = blocked ? 1 : 0;

  /// Jumlah rintangan.
  int get obstacleCount {
    var n = 0;
    for (var i = 0; i < cells.length; i++) {
      n += cells[i];
    }
    return n;
  }

  /// Hash FNV-1a 64-bit (hex, 16 karakter) atas dimensi dan isi sel.
  ///
  /// Dipakai untuk membuktikan bahwa peta identik dipakai oleh semua
  /// heuristik pada satu pasangan.
  String get hash {
    const prime = 0x100000001b3;
    var h = 0xcbf29ce484222325;
    void mix(int v) {
      h ^= v & 0xff;
      h = h * prime; // wrap-around 64-bit
    }

    mix(width);
    mix(width >> 8);
    mix(height);
    mix(height >> 8);
    for (var i = 0; i < cells.length; i++) {
      mix(cells[i]);
    }
    String hex32(int v) => (v & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0');
    return hex32(h >>> 32) + hex32(h);
  }

  /// Salinan dalam.
  GridMap copy() => GridMap(width, height, Uint8List.fromList(cells));
}
