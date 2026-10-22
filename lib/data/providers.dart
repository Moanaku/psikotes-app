import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/repositories/repositories.dart';
import 'db/app_database.dart';
import 'db/connection.dart';
import 'repositories/capture_repository.dart';
import 'repositories/mistake_repository.dart';
import 'repositories/profile_repository.dart';
import 'repositories/session_repository.dart';
import 'repositories/settings_repository.dart';

/// Satu database untuk seluruh aplikasi; test menimpanya dengan database memori.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = openAppDatabase();
  ref.onDispose(db.close);
  return db;
});

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => DriftProfileRepository(ref.watch(appDatabaseProvider)),
);

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => DriftSessionRepository(ref.watch(appDatabaseProvider)),
);

final answerRepositoryProvider = Provider<AnswerRepository>(
  (ref) => DriftAnswerRepository(ref.watch(appDatabaseProvider)),
);

final mistakeRepositoryProvider = Provider<MistakeRepository>(
  (ref) => DriftMistakeRepository(ref.watch(appDatabaseProvider)),
);

final captureRepositoryProvider = Provider<CaptureRepository>(
  (ref) => DriftCaptureRepository(ref.watch(appDatabaseProvider)),
);

final companyLogRepositoryProvider = Provider<CompanyLogRepository>(
  (ref) => DriftCompanyLogRepository(ref.watch(appDatabaseProvider)),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => DriftSettingsRepository(ref.watch(appDatabaseProvider)),
);
