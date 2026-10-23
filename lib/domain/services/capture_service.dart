import 'dart:typed_data';

import '../models/notebook.dart';
import '../repositories/repositories.dart';
import 'capture_form.dart';

/// Penyimpanan foto soal Capture di perangkat. Foto tidak masuk database,
/// backup, repo, atau log. Implementasinya ada di `data/photos`.
abstract class CapturePhotoStore {
  /// Batas ukuran satu foto yang disimpan.
  static const int maxBytes = 2 * 1024 * 1024;

  /// Menyimpan foto dan mengembalikan namanya (bukan jalur lengkap).
  /// Melempar [PhotoStoreException] bila foto tidak bisa disimpan.
  Future<String> save(Uint8List bytes, {String extension = 'jpg'});

  /// Isi foto, atau null bila berkasnya tidak ada di perangkat ini (mis.
  /// backup dipulihkan di perangkat lain).
  Future<Uint8List?> read(String name);

  Future<void> delete(String name);
}

enum PhotoStoreProblem { tooLarge, storageFull, unavailable }

class PhotoStoreException implements Exception {
  const PhotoStoreException(this.problem);

  final PhotoStoreProblem problem;

  /// Kalimat untuk pengguna, tanpa teks exception mentah.
  String get message => switch (problem) {
        PhotoStoreProblem.tooLarge =>
          'Foto terlalu besar. Pilih foto yang lebih kecil, atau potret ulang.',
        PhotoStoreProblem.storageFull =>
          'Penyimpanan penuh. Hapus foto Capture lama, atau simpan soal tanpa '
              'foto.',
        PhotoStoreProblem.unavailable =>
          'Foto belum tersimpan. Penyimpanan di perangkat tidak bisa dipakai. '
              'Ketuk simpan sekali lagi, atau simpan tanpa foto.',
      };

  @override
  String toString() => 'PhotoStoreException(${problem.name})';
}

/// Menyimpan dan menghapus soal Capture bersama fotonya (F09).
class CaptureService {
  CaptureService(this._captures, this._photos);

  final CaptureRepository _captures;
  final CapturePhotoStore _photos;

  /// Menyimpan formulir. [newPhoto] adalah foto baru yang belum disimpan;
  /// [removePhoto] membuang foto lama. Foto lama dihapus setelah soal berhasil
  /// tersimpan. Melempar [ArgumentError] bila formulir belum sah dan
  /// [PhotoStoreException] bila foto gagal disimpan.
  Future<int> save({
    required CaptureDraft draft,
    required DateTime now,
    int? id,
    Uint8List? newPhoto,
    bool removePhoto = false,
  }) async {
    final existing = id == null ? null : await _captures.byId(id);
    final oldPhoto = existing?.fotoPath;
    String? name = removePhoto ? null : draft.fotoPath;
    String? added;
    if (newPhoto != null) {
      added = await _photos.save(newPhoto);
      name = added;
    }
    final question = (name == null
            ? draft.copyWith(clearFoto: true)
            : draft.copyWith(fotoPath: name))
        .build(now: now, id: id, dibuat: existing?.dibuat);
    if (question == null) {
      if (added != null) await _photos.delete(added);
      throw ArgumentError('formulir Capture belum sah');
    }
    final int saved;
    try {
      saved = await _captures.save(question);
    } catch (_) {
      if (added != null) await _photos.delete(added);
      rethrow;
    }
    if (oldPhoto != null && oldPhoto != name) await _photos.delete(oldPhoto);
    return saved;
  }

  /// Menghapus soal, kartu buku kesalahannya (di repository), dan fotonya.
  Future<void> delete(int id) async {
    final existing = await _captures.byId(id);
    await _captures.delete(id);
    final photo = existing?.fotoPath;
    if (photo != null) await _photos.delete(photo);
  }

  /// Isi foto soal, atau null bila tidak ada.
  Future<Uint8List?> photoOf(CapturedQuestion q) async =>
      q.hasPhoto ? _photos.read(q.fotoPath!) : null;
}
