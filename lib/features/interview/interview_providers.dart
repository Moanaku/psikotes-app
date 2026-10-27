import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/ai_coach.dart';
import '../settings/settings_provider.dart';

/// Jumlah sesi wawancara per hari yang ditampilkan di S15 sebagai batas.
const int interviewDailyLimit = 3;

/// Pewawancara. Sekarang hanya dialog contoh tertulis (T29); T30 dan T31
/// menggantinya dengan implementasi nyata.
final aiCoachProvider = Provider<AiCoach>(
  (ref) => FakeCoach(delay: const Duration(milliseconds: 600)),
);

/// Syarat wawancara di S15.
enum InterviewGate { ready, noKey, limitReached, offline }

/// Sesi wawancara yang sudah dipakai hari ini. Belum ada pencatat (T30), jadi
/// selalu nol; test menimpanya.
final interviewSessionsUsedProvider = Provider<int>((ref) => 0);

/// Apakah perangkat punya internet. Belum ada pemeriksa koneksi (T30), jadi
/// dianggap tersambung; test menimpanya.
final interviewOnlineProvider = Provider<bool>((ref) => true);

/// Kondisi S15: key belum diisi, batas harian habis, offline, atau siap.
final interviewGateProvider =
    FutureProvider.autoDispose<InterviewGate>((ref) async {
  final provider = await ref.watch(aiProviderSettingProvider.future);
  final hasKey = provider != null &&
      await ref.watch(apiKeyPresentProvider(provider).future);
  if (!hasKey) return InterviewGate.noKey;
  if (ref.watch(interviewSessionsUsedProvider) >= interviewDailyLimit) {
    return InterviewGate.limitReached;
  }
  if (!ref.watch(interviewOnlineProvider)) return InterviewGate.offline;
  return InterviewGate.ready;
});

class InterviewSetupNotifier extends Notifier<InterviewSetup> {
  @override
  InterviewSetup build() => const InterviewSetup();

  void update(InterviewSetup Function(InterviewSetup s) change) =>
      state = change(state);
}

final interviewSetupProvider =
    NotifierProvider<InterviewSetupNotifier, InterviewSetup>(
  InterviewSetupNotifier.new,
);

/// Keadaan dialog S16.
class InterviewDialogState {
  const InterviewDialogState({
    this.turns = const [],
    this.topic = 1,
    this.typing = false,
    this.failed = false,
    this.finished = false,
    this.started = false,
  });

  final List<InterviewTurn> turns;

  /// Topik yang sedang dibahas, mulai dari 1.
  final int topic;
  final bool typing;

  /// Pewawancara tidak menjawab; jawaban terakhir sudah tersimpan di [turns].
  final bool failed;

  /// Penutup sudah disampaikan.
  final bool finished;
  final bool started;

  InterviewDialogState copyWith({
    List<InterviewTurn>? turns,
    int? topic,
    bool? typing,
    bool? failed,
    bool? finished,
    bool? started,
  }) =>
      InterviewDialogState(
        turns: turns ?? this.turns,
        topic: topic ?? this.topic,
        typing: typing ?? this.typing,
        failed: failed ?? this.failed,
        finished: finished ?? this.finished,
        started: started ?? this.started,
      );
}

class InterviewDialog extends Notifier<InterviewDialogState> {
  @override
  InterviewDialogState build() => const InterviewDialogState();

  AiCoach get _coach => ref.read(aiCoachProvider);

  /// Memulai dialog baru dari pengaturan S15.
  Future<void> start() async {
    state = const InterviewDialogState(started: true, typing: true);
    final turn = await _coach.openingTurn(ref.read(interviewSetupProvider));
    state = state.copyWith(turns: [turn], typing: false);
  }

  Future<void> send(String answer) async {
    final text = answer.trim();
    if (text.isEmpty || state.typing || state.finished) return;
    state = state.copyWith(
      turns: [...state.turns, InterviewTurn(byInterviewer: false, text: text)],
      failed: false,
    );
    await _reply();
  }

  /// Mengirim ulang tanpa menambah jawaban ganda.
  Future<void> retry() => _reply();

  Future<void> _reply() async {
    state = state.copyWith(typing: true, failed: false);
    try {
      final turn = await _coach.nextTurn(
        ref.read(interviewSetupProvider),
        state.turns,
        state.topic,
      );
      final done = state.topic >= _coach.topicCount;
      state = state.copyWith(
        turns: [...state.turns, turn],
        topic: done ? state.topic : state.topic + 1,
        typing: false,
        finished: done,
      );
    } on CoachUnavailable {
      state = state.copyWith(typing: false, failed: true);
    }
  }
}

final interviewDialogProvider =
    NotifierProvider<InterviewDialog, InterviewDialogState>(
  InterviewDialog.new,
);

/// Laporan dari dialog yang baru selesai; null bila belum ada dialog.
final interviewReportProvider =
    FutureProvider.autoDispose<InterviewReport?>((ref) async {
  final dialog = ref.watch(interviewDialogProvider);
  if (!dialog.started) return null;
  return ref.read(aiCoachProvider).report(
        ref.read(interviewSetupProvider),
        dialog.turns,
      );
});
