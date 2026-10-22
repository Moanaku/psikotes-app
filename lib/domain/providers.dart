/// Provider domain. Repository dideklarasikan di sini dengan tipe antarmukanya
/// dan diisi lapisan data lewat `dataProviderOverrides` (lib/data/providers.dart)
/// di akar `ProviderScope`, sehingga domain tidak mengimpor `data/`.
library;

import 'dart:async';

import 'package:question_engine/question_engine.dart';
import 'package:riverpod/riverpod.dart';

import 'models/session.dart';
import 'repositories/repositories.dart';
import 'services/clock.dart';

/// Membuat penanda waktu berkala; test menggantinya dengan penanda manual.
typedef TickerFactory = Timer Function(
  Duration interval,
  void Function() onTick,
);

Timer periodicTicker(Duration interval, void Function() onTick) =>
    Timer.periodic(interval, (_) => onTick());

/// Membuat ulang soal dari satu butir rencana.
typedef QuestionBuilder = Question Function(PlanItem item);

/// Soal lama hanya bisa dibuat ulang identik oleh generator versi yang sama
/// (docs/03-data-model.md).
class QuestionUnavailable implements Exception {
  QuestionUnavailable(this.item, this.reason);

  final PlanItem item;
  final String reason;

  @override
  String toString() =>
      'QuestionUnavailable(${item.type.code}, seed ${item.seed}: $reason)';
}

Question buildFromRegistry(PlanItem item) {
  if (!GeneratorRegistry.has(item.type)) {
    throw QuestionUnavailable(item, 'tipe belum terdaftar');
  }
  final generator = GeneratorRegistry.generator(item.type);
  if (generator.version != item.genVersi) {
    throw QuestionUnavailable(
        item, 'versi generator ${generator.version}, soal ${item.genVersi}');
  }
  return generator.generate(item.seed, item.difficulty);
}

final clockProvider = Provider<Clock>((ref) => SystemClock());

final tickerFactoryProvider = Provider<TickerFactory>((ref) => periodicTicker);

final questionBuilderProvider =
    Provider<QuestionBuilder>((ref) => buildFromRegistry);

Never _unbound(String name) => throw UnimplementedError(
    '$name belum diisi; pasang dataProviderOverrides di ProviderScope');

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => _unbound('profileRepositoryProvider'),
);

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => _unbound('sessionRepositoryProvider'),
);

final answerRepositoryProvider = Provider<AnswerRepository>(
  (ref) => _unbound('answerRepositoryProvider'),
);

final mistakeRepositoryProvider = Provider<MistakeRepository>(
  (ref) => _unbound('mistakeRepositoryProvider'),
);

final captureRepositoryProvider = Provider<CaptureRepository>(
  (ref) => _unbound('captureRepositoryProvider'),
);

final companyLogRepositoryProvider = Provider<CompanyLogRepository>(
  (ref) => _unbound('companyLogRepositoryProvider'),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => _unbound('settingsRepositoryProvider'),
);
