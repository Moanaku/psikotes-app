import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/personality.dart';

/// Lokasi pool di aset app (pubspec.yaml).
const String personalityPoolAsset = 'assets/personality_pool.json';

/// Pembaca teks aset; diganti di test.
final personalityAssetReaderProvider =
    Provider<Future<String> Function(String path)>(
  (ref) => rootBundle.loadString,
);

/// Pool kepribadian (F12), dimuat saat S14 pertama kali dibuka. Galat baca
/// atau skema tampil sebagai kondisi galat S14 dengan "Coba lagi".
final personalityPoolProvider = FutureProvider<PersonalityPool>((ref) async {
  final read = ref.watch(personalityAssetReaderProvider);
  return PersonalityPool.parse(await read(personalityPoolAsset));
});
