import 'dart:async';

import 'package:simulator_psikotes_it/domain/models/profile.dart';
import 'package:simulator_psikotes_it/domain/repositories/repositories.dart';

/// Repository profil di memori tanpa database: aman untuk widget test (tanpa
/// timer dan I/O nyata). Meniru aturan repository Drift: profil pertama
/// otomatis aktif, menyimpan profil aktif menonaktifkan yang lain, dan `save`
/// pada profil yang ada tidak mengubah CV bila `cvTeks` null.
class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository([Iterable<TestProfile> initial = const []]) {
    for (final p in initial) {
      _items.add(p.id == null ? p.copyWith(id: _next++) : p);
      if (p.id != null && p.id! >= _next) _next = p.id! + 1;
    }
  }

  final List<TestProfile> _items = [];
  final StreamController<void> _changes = StreamController.broadcast(
    sync: true,
  );
  int _next = 1;

  /// Bila diisi, `save` dan `byId` melempar ini (menguji kondisi galat).
  Object? failWith;

  /// Jumlah panggilan `save`.
  int saves = 0;

  /// Bila diisi, `save` menunggu sampai selesai (menguji ketukan ganda).
  Completer<void>? saveGate;

  List<TestProfile> get items => List.unmodifiable(_items);

  @override
  Stream<List<TestProfile>> watchAll() => Stream.multi((c) {
        c.add(items);
        final sub = _changes.stream.listen((_) => c.add(items));
        c.onCancel = sub.cancel;
      });

  @override
  Future<TestProfile?> active() async {
    for (final p in _items) {
      if (p.aktif) return p;
    }
    return null;
  }

  @override
  Future<TestProfile?> byId(int id) async {
    if (failWith != null) throw failWith!;
    for (final p in _items) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Future<int> save(TestProfile profile) async {
    if (failWith != null) throw failWith!;
    saves++;
    await saveGate?.future;
    final makeActive = profile.aktif || _items.isEmpty;
    final id = profile.id ?? _next++;
    final index = _items.indexWhere((p) => p.id == id);
    final cv = profile.cvTeks ?? (index >= 0 ? _items[index].cvTeks : null);
    final saved = TestProfile(
      id: id,
      nama: profile.nama,
      role: profile.role,
      formatTes: profile.formatTes,
      tanggalTes: profile.tanggalTes,
      aktif: makeActive,
      blueprint: profile.blueprint,
      cvTeks: cv,
      dibuat: profile.dibuat,
    );
    if (makeActive) {
      for (var i = 0; i < _items.length; i++) {
        if (_items[i].aktif) _items[i] = _items[i].copyWith(aktif: false);
      }
    }
    if (index >= 0) {
      _items[index] = saved;
    } else {
      _items.add(saved);
    }
    _changes.add(null);
    return id;
  }

  @override
  Future<void> setCv(int id, String? cvTeks) async {}

  @override
  Future<void> setActive(int id) async {
    for (var i = 0; i < _items.length; i++) {
      _items[i] = _items[i].copyWith(aktif: _items[i].id == id);
    }
    _changes.add(null);
  }
}
