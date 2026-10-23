import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../../domain/services/capture_service.dart';
import '../../domain/services/clock.dart';
import 'photo_names.dart';

/// Foto Capture di Android: berkas di folder dokumen app, tidak pernah di
/// folder bersama atau galeri. Hanya namanya yang masuk database.
CapturePhotoStore createPhotoStore() => FileCapturePhotoStore();

class FileCapturePhotoStore implements CapturePhotoStore {
  FileCapturePhotoStore({Future<Directory> Function()? root, Clock? clock})
      : _root = root ?? getApplicationDocumentsDirectory,
        _clock = clock ?? SystemClock();

  static const String folder = 'capture_photos';

  final Future<Directory> Function() _root;
  final Clock _clock;

  Future<Directory> _dir() async {
    final base = await _root();
    final dir = Directory('${base.path}${Platform.pathSeparator}$folder');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File?> _file(String name) async {
    if (!PhotoNames.isValid(name)) return null;
    final dir = await _dir();
    return File('${dir.path}${Platform.pathSeparator}$name');
  }

  @override
  Future<String> save(Uint8List bytes, {String extension = 'jpg'}) async {
    if (bytes.length > CapturePhotoStore.maxBytes) {
      throw const PhotoStoreException(PhotoStoreProblem.tooLarge);
    }
    final name = PhotoNames.create(extension, _clock);
    try {
      await (await _file(name))!.writeAsBytes(bytes, flush: true);
    } on FileSystemException catch (e) {
      // ENOSPC di Linux dan Android; 112 di Windows.
      final code = e.osError?.errorCode;
      throw PhotoStoreException(code == 28 || code == 112
          ? PhotoStoreProblem.storageFull
          : PhotoStoreProblem.unavailable);
    }
    return name;
  }

  @override
  Future<Uint8List?> read(String name) async {
    try {
      final file = await _file(name);
      if (file == null || !await file.exists()) return null;
      return await file.readAsBytes();
    } on FileSystemException {
      return null;
    }
  }

  @override
  Future<void> delete(String name) async {
    try {
      final file = await _file(name);
      if (file != null && await file.exists()) await file.delete();
    } on FileSystemException {
      // Foto yatim tidak mengganggu; soalnya sudah terhapus.
    }
  }
}
