@TestOn('vm')
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/data/photos/photo_names.dart';
import 'package:simulator_psikotes_it/data/photos/photo_store_io.dart';
import 'package:simulator_psikotes_it/domain/services/capture_service.dart';

void main() {
  late Directory root;
  late FileCapturePhotoStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('foto_capture_test');
    store = FileCapturePhotoStore(root: () async => root);
  });

  tearDown(() => root.delete(recursive: true));

  test('simpan, baca, dan hapus foto di folder khusus app', () async {
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    final name = await store.save(bytes);
    expect(PhotoNames.isValid(name), isTrue);
    expect(name, endsWith('.jpg'));
    expect(
      File('${root.path}/${FileCapturePhotoStore.folder}/$name').existsSync(),
      isTrue,
    );
    expect(await store.read(name), bytes);

    await store.delete(name);
    expect(await store.read(name), isNull);
  });

  test('foto yang tidak ada dibaca sebagai null, bukan galat', () async {
    expect(await store.read('cap_tidakada.jpg'), isNull);
    await store.delete('cap_tidakada.jpg');
  });

  test('foto terlalu besar ditolak sebelum menulis', () async {
    final big = Uint8List(CapturePhotoStore.maxBytes + 1);
    await expectLater(
      store.save(big),
      throwsA(
        isA<PhotoStoreException>()
            .having((e) => e.problem, 'problem', PhotoStoreProblem.tooLarge),
      ),
    );
  });

  test('nama dari backup yang menunjuk ke luar folder tidak dipakai', () async {
    final outside = File('${root.path}/rahasia.txt')..writeAsStringSync('x');
    for (final bad in ['../rahasia.txt', '..', 'a/b.jpg', r'..\rahasia.txt']) {
      expect(PhotoNames.isValid(bad), isFalse, reason: bad);
      expect(await store.read(bad), isNull, reason: bad);
      await store.delete(bad);
    }
    expect(outside.existsSync(), isTrue,
        reason: 'berkas di luar tidak terhapus');
  });

  test('nama baru unik dan hanya berisi karakter aman', () {
    final names = {for (var i = 0; i < 50; i++) PhotoNames.create('jpg')};
    expect(names, hasLength(50));
    expect(
        PhotoNames.create('p/n g'), matches(RegExp(r'^cap_[a-z0-9]+\.png$')));
  });

  test('pesan galat foto tanpa teks exception', () {
    for (final p in PhotoStoreProblem.values) {
      final m = PhotoStoreException(p).message;
      expect(m, isNotEmpty);
      expect(m, isNot(contains('Exception')));
    }
  });
}
