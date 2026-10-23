import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/models/notebook.dart';
import '../../domain/providers.dart';

/// Satu soal Capture; null bila sudah dihapus.
final capturedQuestionProvider =
    FutureProvider.autoDispose.family<CapturedQuestion?, int>(
  (ref, id) => ref.watch(captureRepositoryProvider).byId(id),
);

/// Isi foto soal; null bila berkasnya tidak ada di perangkat ini.
final capturePhotoProvider =
    FutureProvider.autoDispose.family<Uint8List?, String>(
  (ref, name) => ref.watch(capturePhotoStoreProvider).read(name),
);

/// Semua catatan tes, terbaru dulu, diperbarui setiap ada perubahan.
final companyLogsProvider = StreamProvider.autoDispose<List<CompanyTestLog>>(
  (ref) => ref.watch(companyLogRepositoryProvider).watchAll(),
);

enum PhotoSource { camera, gallery }

/// Alasan foto tidak didapat dari pemilih; layar menulis pesannya.
class PhotoPickFailure implements Exception {
  const PhotoPickFailure();
}

/// Mengambil foto dari kamera atau galeri. Null berarti pengguna membatalkan;
/// [PhotoPickFailure] bila kamera atau galeri tidak bisa dibuka. Test
/// menggantinya.
typedef PhotoPicker = Future<Uint8List?> Function(PhotoSource source);

/// Foto diperkecil saat diambil (sisi terpanjang 1280 px, mutu 80) supaya
/// muat di penyimpanan, terutama di web (A86).
Future<Uint8List?> pickWithImagePicker(PhotoSource source) async {
  try {
    final file = await ImagePicker().pickImage(
      source: source == PhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 80,
    );
    return file == null ? null : await file.readAsBytes();
  } catch (_) {
    throw const PhotoPickFailure();
  }
}

final photoPickerProvider = Provider<PhotoPicker>((ref) => pickWithImagePicker);
