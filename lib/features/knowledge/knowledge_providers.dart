import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/knowledge.dart';
import '../../domain/services/knowledge_bank.dart';

/// Lokasi bank di aset app (pubspec.yaml).
const String knowledgeBankAsset = 'assets/knowledge_bank.json';

/// Pembaca teks aset; diganti di test.
final knowledgeAssetReaderProvider =
    Provider<Future<String> Function(String path)>(
  (ref) => rootBundle.loadString,
);

/// Bank pengetahuan (F17), dimuat saat S19 pertama kali dibuka. Kegagalan baca
/// atau skema salah menjadi [KnowledgeBankState.failed], tidak melempar; S19
/// menampilkannya sebagai kondisi galat dengan "Coba lagi".
final knowledgeBankProvider = FutureProvider<KnowledgeBankState>((ref) async {
  final read = ref.watch(knowledgeAssetReaderProvider);
  return loadKnowledgeBank(read, path: knowledgeBankAsset);
});

/// Satu sesi kartu: butir yang sudah dipilih dan cakupannya.
class KnowledgeSessionPlan {
  const KnowledgeSessionPlan({
    required this.id,
    required this.role,
    required this.level,
    required this.items,
  });

  final int id;
  final KnowledgeRole role;
  final KnowledgeLevel level;
  final List<KnowledgeItem> items;
}

/// Sesi kartu yang sedang berjalan, hanya di memori (A107): penilaian per
/// kartu tersimpan di `knowledge_progress`, jadi sesi yang hilang karena app
/// ditutup tidak menghilangkan kemajuan.
class KnowledgeSessions extends Notifier<Map<int, KnowledgeSessionPlan>> {
  var _next = 1;

  @override
  Map<int, KnowledgeSessionPlan> build() => const {};

  int start({
    required KnowledgeRole role,
    required KnowledgeLevel level,
    required List<KnowledgeItem> items,
  }) {
    final id = _next++;
    state = {
      ...state,
      id: KnowledgeSessionPlan(id: id, role: role, level: level, items: items),
    };
    return id;
  }
}

final knowledgeSessionsProvider =
    NotifierProvider<KnowledgeSessions, Map<int, KnowledgeSessionPlan>>(
  KnowledgeSessions.new,
);
