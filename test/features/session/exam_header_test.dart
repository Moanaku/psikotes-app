import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/features/session/session_widgets.dart';

import '../../support/fixtures.dart';
import '../../support/text_fit.dart';
import 'session_screen_test.dart' show openSession;

/// Uji perangkat 2 (temuan 3 dan 5): di skala huruf besar kepala simulasi
/// (S07) memakan sepertiga layar, dan nama subtes ("Numerik") terpotong di 1,3.
/// Diukur dengan font app sungguhan di layar 360 x 800.
void main() {
  const height = 800.0;

  Future<double> stemTop(WidgetTester tester) async =>
      tester.getTopLeft(find.byType(QuestionBody)).dy;

  testWidgets('skala 1,0: nama profil dan keterangan lengkap', (tester) async {
    await openSession(tester, SessionMode.simulasi, simulasiPlan());
    expect(find.text('QA, CCAT-style'), findsOneWidget);
    expect(find.text('Subtes 1 dari 3, soal 1 dari 3'), findsOneWidget);
    for (final name in ['Numerik', 'Logika', 'Figural']) {
      expect(find.text(name), findsOneWidget);
    }
  });

  testWidgets('skala 1,3: nama subtes utuh dalam satu baris', (tester) async {
    await openSession(tester, SessionMode.simulasi, simulasiPlan(),
        textScale: 1.3);
    expectNoMidWordBreaks(tester);
    for (final name in ['Numerik', 'Logika', 'Figural']) {
      final box = tester.getSize(find.text(name));
      expect(box.height, lessThan(30), reason: '$name satu baris');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('skala 2,0: kepala dipadatkan, soal terlihat di atas 30% layar',
      (tester) async {
    await openSession(tester, SessionMode.simulasi, simulasiPlan(),
        textScale: 2.0);
    expectNoMidWordBreaks(tester);
    expect(find.text('QA, CCAT-style'), findsNothing,
        reason: 'nama profil dibuang di skala besar');
    expect(find.text('Numerik, soal 1 dari 3'), findsOneWidget);
    final top = await stemTop(tester);
    expect(top / height, lessThan(0.30));
  });
}
