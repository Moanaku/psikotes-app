import 'dart:async';
import 'dart:convert';

import 'package:simulator_psikotes_it/domain/models/knowledge.dart';
import 'package:simulator_psikotes_it/domain/repositories/repositories.dart';
import 'package:simulator_psikotes_it/domain/services/knowledge_bank.dart';

/// Butir uji: `kb(KnowledgeRole.qa, KnowledgeLevel.dasar, 1)` menjadi
/// `KB-QA-D-001`.
KnowledgeItem kb(
  KnowledgeRole role,
  KnowledgeLevel level,
  int n, {
  String topik = 'siklus-bug',
  String? sumber,
  List<String>? poin,
}) =>
    KnowledgeItem(
      id: 'KB-${role.idCode}-${level.idCode}-${n.toString().padLeft(3, '0')}',
      role: role,
      level: level,
      topik: topik,
      pertanyaan: 'Pertanyaan ${role.label} ${level.label} nomor $n?',
      jawabanModel: 'Jawaban model ${role.label} ${level.label} nomor $n.',
      poinKunci: poin ?? ['Poin satu', 'Poin dua', 'Poin tiga'],
      sumber: sumber,
      needsVerification: sumber == null,
    );

/// Bank kecil: QA dasar 3 butir (dua topik), QA lanjut 3, Mobile dasar 2, BA
/// dasar 2, Umum dasar 2. Mobile menengah kosong.
KnowledgeBank smallBank() => KnowledgeBank.of([
      kb(KnowledgeRole.qa, KnowledgeLevel.dasar, 1),
      kb(KnowledgeRole.qa, KnowledgeLevel.dasar, 2, topik: 'test-case'),
      kb(KnowledgeRole.qa, KnowledgeLevel.dasar, 3,
          sumber: 'ISTQB Foundation Syllabus'),
      kb(KnowledgeRole.qa, KnowledgeLevel.lanjut, 1, topik: 'strategi-tes'),
      kb(KnowledgeRole.qa, KnowledgeLevel.lanjut, 2, topik: 'strategi-tes'),
      kb(KnowledgeRole.qa, KnowledgeLevel.lanjut, 3, topik: 'flaky-test'),
      kb(KnowledgeRole.mobile, KnowledgeLevel.dasar, 1, topik: 'state'),
      kb(KnowledgeRole.mobile, KnowledgeLevel.dasar, 2, topik: 'layout'),
      kb(KnowledgeRole.ba, KnowledgeLevel.dasar, 1, topik: 'requirement'),
      kb(KnowledgeRole.ba, KnowledgeLevel.dasar, 2, topik: 'user-story'),
      kb(KnowledgeRole.umum, KnowledgeLevel.dasar, 1, topik: 'git'),
      kb(KnowledgeRole.umum, KnowledgeLevel.dasar, 2, topik: 'git'),
    ]);

/// Teks JSON bank dari [items], sesuai skema docs/06-bank-konten.md.
String bankJson(List<KnowledgeItem> items, {int versi = 1}) => jsonEncode({
      'versi': versi,
      'dibuat': '2026-10-27',
      'butir': [
        for (final i in items)
          {
            'id': i.id,
            'role': i.role.code,
            'level': i.level.code,
            'topik': i.topik,
            'pertanyaan': i.pertanyaan,
            'jawabanModel': i.jawabanModel,
            'poinKunci': i.poinKunci,
            'sumber': i.sumber,
            'needsVerification': i.needsVerification,
          },
      ],
    });

/// Kemajuan di memori.
class FakeKnowledgeRepository implements KnowledgeRepository {
  FakeKnowledgeRepository([Map<String, KnowledgeProgress> initial = const {}])
      : _data = {...initial};

  final Map<String, KnowledgeProgress> _data;
  final _changes = StreamController<void>.broadcast();

  /// Bila diisi, `watchAll` mengeluarkan galat ini.
  Object? failWatchWith;

  /// Bila diisi, `save` melempar ini.
  Object? failSaveWith;

  /// Bila diisi, `watchAll` menahan data pertama sampai selesai.
  Completer<void>? gate;

  Map<String, KnowledgeProgress> get data => Map.unmodifiable(_data);

  @override
  Stream<Map<String, KnowledgeProgress>> watchAll() async* {
    await gate?.future;
    if (failWatchWith != null) throw failWatchWith!;
    yield Map.of(_data);
    await for (final _ in _changes.stream) {
      yield Map.of(_data);
    }
  }

  @override
  Future<Map<String, KnowledgeProgress>> all() async => Map.of(_data);

  @override
  Future<void> save(KnowledgeProgress progress) async {
    if (failSaveWith != null) throw failSaveWith!;
    _data[progress.butirId] = progress;
    _changes.add(null);
  }
}
