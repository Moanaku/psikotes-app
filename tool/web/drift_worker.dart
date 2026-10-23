import 'package:drift/wasm.dart';

/// Sumber `web/drift_worker.js`, pekerja web yang membuka database Drift.
/// Dikompilasi oleh `tool/prepare_web.sh`.
void main() {
  WasmDatabase.workerMainForOpen();
}
