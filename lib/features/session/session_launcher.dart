import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/codes.dart';
import '../../domain/models/session.dart';
import '../../domain/services/session_controller.dart';

/// Membuat sesi baru di database lewat `SessionController` dan mengembalikan
/// id-nya untuk rute `/sesi/:id`. S04 dan S05 memakainya; layar sesi (T14)
/// membaca keadaan dari controller yang sama.
Future<int> launchSession(
  WidgetRef ref, {
  required int profileId,
  required SessionMode mode,
  required SessionPlan plan,
}) async {
  final controller = ref.read(sessionControllerProvider.notifier);
  await controller.start(profileId: profileId, mode: mode, plan: plan);
  return ref.read(sessionControllerProvider)!.sessionId;
}
