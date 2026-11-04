# heuristic-nav

Testbed eksperimen untuk penelitian *"Analisis Komparasi Kinerja Heuristik Manhattan dan Euclidean pada Algoritma A\* dalam Lingkungan Game 2D Berbasis Flutter"*.

Core algoritma (`lib/core`) adalah **Dart murni** (tanpa Flutter/Flame) sehingga dapat dijalankan headless. UI Flutter + Flame hanya untuk menjalankan benchmark dan visualisasi.

## Versi dependensi
`flame ^1.38.2`, `path_provider ^2.1.6`, `share_plus ^13.3.1`, `device_info_plus ^13.3.0`, `collection ^1.19.0`, `flutter_lints ^6.0.0` (SDK `^3.8.0`). Lihat `pubspec.yaml`.

## Menjalankan
```
flutter pub get
flutter analyze && flutter test
flutter run --profile            # atau --release; debug mode memunculkan peringatan
flutter build apk --profile
```
Debug mode **tidak valid** untuk data publikasi.

### CLI headless
```
dart run bin/benchmark_cli.dart --scenario assets/scenarios/full_factorial.json --out ./out
```
(Jika `dart run` menolak karena dependensi Flutter, gunakan `flutter pub run bin/benchmark_cli.dart ...`.) Menulis 3 CSV + 1 JSON metadata ke folder `out`.

### Analisis Python
```
pip install pandas scipy matplotlib tabulate
python analysis/analyze_results.py --paired out/results_paired_<ts>.csv
```
Output: `analysis/output/*.csv|.md` dan `analysis/figures/*.png`. Uji: Shapiro-Wilk pada selisih → paired t-test atau Wilcoxon, effect size (Cohen's d / rank-biserial), koreksi Holm per metrik, alpha 0.05.

## Struktur CSV
- `results_raw_<ts>.csv`: satu baris per run. Kolom: `runId,timestamp,gridSize,width,height,obstacleDensityPct,obstacleCount,seedIndex,seedUsed,reseedAttempts,mapRepaired,mapHash,movementMode,heuristic,allowCornerCutting,orderInPair,warmupRuns,innerRepeats,isolateMode,buildMode,pathFound,executionTimeUs,expandedNodes,generatedNodes,maxOpenListSize,pathCost,pathLengthSteps`
- `results_summary_<ts>.csv`: per (gridSize, density, mode, heuristic): n, successRate, mean/std/min/max/median untuk `executionTimeUs`, `expandedNodes`, `pathCost`.
- `results_paired_<ts>.csv`: per (gridSize, density, mode, seedIndex) nilai Manhattan & Euclidean berdampingan + `costGapPct`.
- `run_metadata_<ts>.json`: versi, build mode, OS, perangkat, config skenario, corner-cutting, tie-breaking.

Full factorial: 36 konfigurasi × 30 seed = **1.080 baris raw** (540 pasangan; 36 konfigurasi sudah termasuk 2 heuristik).

## Design Decisions / Asumsi
- **Corner-cutting dilarang** (`allowCornerCutting=false`, dicatat di tiap baris).
- **Tie-breaking**: f terkecil, lalu h terkecil, lalu index node terkecil.
- **Closed node tidak dibuka kembali**; heuristik Manhattan pada 8 arah inadmissible sehingga boleh suboptimal (itulah yang diukur `costGapPct`).
- `generatedNodes` = jumlah operasi push ke open list (termasuk duplikat lazy deletion); `expandedNodes` tidak menghitung entry stale.
- **Warm-up**: `warmupRuns` solve pada peta dummy 50×50 sebelum pengukuran. **Inner repeats**: waktu = total k solve / k, nilai k dicatat.
- **Counterbalancing**: urutan heuristik dirotasi menurut `seedIndex` (genap: Manhattan dulu, ganjil: Euclidean dulu); `orderInPair` dicatat.
- **Peta**: satu peta per (ukuran, kepadatan, seedIndex) dipakai semua mode & heuristik; `mapHash` (FNV-1a 64-bit) membuktikannya. Re-seed `seed + 1000*attempt` bila tidak solvable (BFS 4 arah).
- **Kepadatan 50%** berada di bawah ambang perkolasi, sehingga peta acak hampir tak pernah solvable di grid besar. Setelah 100 re-seed, dibuka koridor minimal-rintangan lalu jumlah rintangan dipulihkan secara acak di luar koridor (jumlah tetap tepat). Peta ini ditandai `mapRepaired=true`; analisis dapat memfilternya.
- Hot loop solver tidak memiliki callback; urutan expand selalu ditulis ke buffer yang sudah dialokasikan dan hanya disalin bila `collectExploredOrder=true`.
- Mode isolate dicatat di `isolateMode` (`mainIsolate`/`separateIsolate`); progres UI dibatasi sekali per 250 ms.
- Memuat skenario kustom dilakukan lewat input path file JSON (tanpa menambah dependensi `file_picker`).
- Versi Flutter di metadata dapat diisi dengan `--dart-define=FLUTTER_VERSION=...`.
