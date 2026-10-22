import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/models/session.dart';
import '../../domain/providers.dart';
import '../../domain/services/session_controller.dart';
import '../../domain/services/stats_service.dart';

/// Segmen Mingguan atau Bulanan di S11; bertahan saat pindah tab.
final statsRangeProvider = StateProvider<StatsRange>(
  (ref) => StatsRange.mingguan,
);

/// Sesi dan jawaban yang sudah selesai. Dibaca ulang saat sesi selesai.
class StatsData {
  const StatsData({required this.sessions, required this.answers});

  final List<SessionRecord> sessions;
  final List<AnswerRecord> answers;
}

final statsDataProvider = FutureProvider.autoDispose<StatsData>((ref) async {
  ref.watch(
      sessionControllerProvider.select((s) => (s?.sessionId, s?.finished)));
  final sessions =
      await ref.watch(sessionRepositoryProvider).finishedSessions();
  final answers =
      await ref.watch(answerRepositoryProvider).forFinishedSessions();
  return StatsData(sessions: sessions, answers: answers);
});

/// Isi S11 untuk segmen terpilih. Jam dari `Clock`.
final statsProvider = Provider.autoDispose<AsyncValue<StatsSummary>>((ref) {
  final range = ref.watch(statsRangeProvider);
  final now = ref.watch(clockProvider).now();
  return ref.watch(statsDataProvider).whenData(
        (d) => StatsService.compute(
          sessions: d.sessions,
          answers: d.answers,
          now: now,
          range: range,
        ),
      );
});

/// Membagikan berkas CSV lewat lembar bagikan sistem. Dipisah agar test tidak
/// memanggil plugin.
abstract interface class CsvSharer {
  Future<void> share({required String fileName, required String content});
}

class SharePlusCsvSharer implements CsvSharer {
  const SharePlusCsvSharer();

  @override
  Future<void> share(
      {required String fileName, required String content}) async {
    final bytes = Uint8List.fromList(utf8.encode(content));
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(bytes, mimeType: 'text/csv', name: fileName)],
      fileNameOverrides: [fileName],
      title: 'Statistik psikotes',
    ));
  }
}

final csvSharerProvider =
    Provider<CsvSharer>((ref) => const SharePlusCsvSharer());
