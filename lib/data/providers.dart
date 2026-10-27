import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/providers.dart';
import 'db/app_database.dart';
import 'db/connection.dart';
import 'backup/drift_backup_service.dart';
import 'photos/photo_store.dart';
import 'repositories/capture_repository.dart';
import 'repositories/knowledge_repository.dart';
import 'repositories/mistake_repository.dart';
import 'repositories/profile_repository.dart';
import 'repositories/session_repository.dart';
import 'repositories/settings_repository.dart';
import 'secrets/secure_secret_store.dart';

/// Satu database untuk seluruh aplikasi; test menimpanya dengan database memori.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = openAppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Mengisi provider repository domain (lib/domain/providers.dart) dengan
/// implementasi Drift. Dipasang di `ProviderScope` akar dan di test.
final List<Override> dataProviderOverrides = [
  profileRepositoryProvider.overrideWith(
    (ref) => DriftProfileRepository(ref.watch(appDatabaseProvider)),
  ),
  sessionRepositoryProvider.overrideWith(
    (ref) => DriftSessionRepository(ref.watch(appDatabaseProvider)),
  ),
  answerRepositoryProvider.overrideWith(
    (ref) => DriftAnswerRepository(ref.watch(appDatabaseProvider)),
  ),
  mistakeRepositoryProvider.overrideWith(
    (ref) => DriftMistakeRepository(ref.watch(appDatabaseProvider)),
  ),
  knowledgeRepositoryProvider.overrideWith(
    (ref) => DriftKnowledgeRepository(ref.watch(appDatabaseProvider)),
  ),
  captureRepositoryProvider.overrideWith(
    (ref) => DriftCaptureRepository(ref.watch(appDatabaseProvider)),
  ),
  capturePhotoStoreProvider.overrideWith((ref) => createPhotoStore()),
  backupServiceProvider.overrideWith(
    (ref) => DriftBackupService(ref.watch(appDatabaseProvider)),
  ),
  secretStoreProvider.overrideWith((ref) => createSecretStore()),
  companyLogRepositoryProvider.overrideWith(
    (ref) => DriftCompanyLogRepository(ref.watch(appDatabaseProvider)),
  ),
  settingsRepositoryProvider.overrideWith(
    (ref) => DriftSettingsRepository(ref.watch(appDatabaseProvider)),
  ),
];
