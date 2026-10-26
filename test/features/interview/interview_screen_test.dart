import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/core/widgets/app_bottom_nav.dart';
import 'package:simulator_psikotes_it/core/widgets/app_button.dart';
import 'package:simulator_psikotes_it/core/widgets/empty_view.dart';

import '../../support/fake_repositories.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';

void main() {
  Future<AppHarness> openTab(WidgetTester tester,
      {double textScale = 1}) async {
    final app = await pumpApp(
      tester,
      profiles: FakeProfileRepository([activeProfile()]),
      textScale: textScale,
    );
    await app.go('/wawancara');
    return app;
  }

  testWidgets('tab Wawancara ramah pengguna, tanpa teks pengembang',
      (tester) async {
    await openTab(tester);
    expect(find.byType(EmptyView), findsOneWidget);
    expect(find.text('Simulasi wawancara hadir di rilis berikutnya'),
        findsOneWidget);
    expect(find.byType(AppBottomNav), findsOneWidget);
    for (final dev in ['S15', 'Setup wawancara', 'belum dibangun', 'docs/']) {
      expect(find.textContaining(dev), findsNothing, reason: dev);
    }
  });

  testWidgets('tombol membuka katalog psikotes', (tester) async {
    final app = await openTab(tester);
    await tester.tap(find.widgetWithText(AppButton, 'Buka katalog psikotes'));
    await tester.pumpAndSettle();
    expect(app.location, '/psikotes');
  });

  testWidgets('skala huruf 200%: tombol dan judul tetap terbaca',
      (tester) async {
    await openTab(tester, textScale: 2);
    expect(tester.takeException(), isNull);
    expect(find.text('Buka katalog psikotes'), findsOneWidget);
  });
}
