import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/services/capture_service.dart';
import '../../domain/services/clock.dart';
import 'photo_names.dart';

/// Foto Capture di web: base64 di penyimpanan lokal peramban (localStorage).
/// Batasnya sekitar 5 MB untuk seluruh situs, jadi satu foto dibatasi lebih
/// kecil daripada di Android dan foto hilang bila pengguna menghapus data
/// situs (A86).
CapturePhotoStore createPhotoStore() => WebCapturePhotoStore();

class WebCapturePhotoStore implements CapturePhotoStore {
  WebCapturePhotoStore({Clock? clock}) : _clock = clock ?? SystemClock();

  final Clock _clock;

  static const int maxWebBytes = 600 * 1024;
  static const String prefix = 'capture_photo:';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<String> save(Uint8List bytes, {String extension = 'jpg'}) async {
    if (bytes.length > maxWebBytes) {
      throw const PhotoStoreException(PhotoStoreProblem.tooLarge);
    }
    final name = PhotoNames.create(extension, _clock);
    try {
      final ok =
          await (await _prefs).setString('$prefix$name', base64Encode(bytes));
      if (!ok) throw const PhotoStoreException(PhotoStoreProblem.storageFull);
    } on PhotoStoreException {
      rethrow;
    } catch (_) {
      throw const PhotoStoreException(PhotoStoreProblem.storageFull);
    }
    return name;
  }

  @override
  Future<Uint8List?> read(String name) async {
    if (!PhotoNames.isValid(name)) return null;
    final text = (await _prefs).getString('$prefix$name');
    if (text == null) return null;
    try {
      return base64Decode(text);
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> delete(String name) async {
    if (!PhotoNames.isValid(name)) return;
    await (await _prefs).remove('$prefix$name');
  }
}
