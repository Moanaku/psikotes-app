import 'package:drift_flutter/drift_flutter.dart';

import 'app_database.dart';

/// Membuka database aplikasi. Android memakai SQLite bawaan paket
/// `sqlite3_flutter_libs`; web memakai `sqlite3.wasm` dan `drift_worker.js`
/// yang disajikan di akar situs (disiapkan bersama folder `web/` di T20,
/// lihat docs/11-asumsi-dan-pertanyaan.md, A44).
AppDatabase openAppDatabase() => AppDatabase(
      driftDatabase(
        name: 'simulator_psikotes',
        web: DriftWebOptions(
          sqlite3Wasm: Uri.parse('sqlite3.wasm'),
          driftWorker: Uri.parse('drift_worker.js'),
        ),
      ),
    );
