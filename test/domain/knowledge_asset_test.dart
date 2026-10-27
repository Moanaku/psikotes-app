import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/domain/models/knowledge.dart';
import 'package:simulator_psikotes_it/domain/services/knowledge_bank.dart';

void main() {
  test('bank bawaan terbaca pemuat app: 20 butir per role dan level', () async {
    final state = await loadKnowledgeBank(
      (p) async => File(p).readAsStringSync(),
    );
    expect(state.isFailed, isFalse, reason: state.error);
    final bank = state.bank!;
    for (final role in [
      KnowledgeRole.qa,
      KnowledgeRole.mobile,
      KnowledgeRole.ba,
    ]) {
      for (final level in KnowledgeLevel.values) {
        expect(bank.of(role, level), hasLength(20), reason: '$role $level');
      }
    }
    // Tidak ada butir yang mengaku terverifikasi tanpa sumber.
    expect(
      bank.items.where((i) => i.sumber == null && !i.needsVerification),
      isEmpty,
    );
  });
}
