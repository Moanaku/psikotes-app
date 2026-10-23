import 'dart:math';

import '../../domain/services/clock.dart';

/// Nama berkas foto Capture. Nama dari backup tidak dipercaya: hanya huruf,
/// angka, titik, garis bawah, dan strip yang diterima, supaya `foto_path` dari
/// berkas impor tidak bisa menunjuk ke luar folder foto.
abstract final class PhotoNames {
  static final RegExp _valid = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.-]{0,95}$');

  static bool isValid(String name) =>
      _valid.hasMatch(name) && !name.contains('..');

  /// Nama baru. Waktu dibaca dari [clock] dan garam dari [random] supaya test
  /// bisa memalsukan keduanya.
  static String create(String extension, Clock clock, {Random? random}) {
    final ext = extension.replaceAll(RegExp('[^A-Za-z0-9]'), '');
    final stamp = clock.now().microsecondsSinceEpoch.toRadixString(36);
    final salt = (random ?? Random()).nextInt(1 << 20).toRadixString(36);
    return 'cap_$stamp$salt.${ext.isEmpty ? 'jpg' : ext}';
  }
}
