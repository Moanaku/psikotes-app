import 'dart:typed_data';

import '../../domain/services/capture_service.dart';

/// Platform tanpa penyimpanan foto: setiap simpan gagal dengan pesan yang
/// jelas dan foto tidak pernah ditemukan.
CapturePhotoStore createPhotoStore() => const _NoPhotoStore();

class _NoPhotoStore implements CapturePhotoStore {
  const _NoPhotoStore();

  @override
  Future<String> save(Uint8List bytes, {String extension = 'jpg'}) =>
      throw const PhotoStoreException(PhotoStoreProblem.unavailable);

  @override
  Future<Uint8List?> read(String name) async => null;

  @override
  Future<void> delete(String name) async {}
}
