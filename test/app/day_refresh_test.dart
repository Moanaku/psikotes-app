import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/app/routes.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/domain/models/notebook.dart';

import '../support/fake_clock.dart';
import '../support/fake_repositories.dart';
import '../support/fixtures.dart';
import '../support/pump_app.dart';

/// A95: beranda dan buku kesalahan menyegarkan "hari ini" saat app terbuka
/// melewati tengah malam atau kembali dari latar belakang di hari lain.
MistakeCard dueTomorrow() => MistakeCard(
      id: 1,
      tipe: 'FIG-MTX',
      kategori: 'figural',
      seed: 1,
      sumber: AnswerSource.engine,
      jatuhTempo: appNow.add(const Duration(days: 1)),
      intervalHari: 1,
      streakBenar: 0,
      status: CardStatus.aktif,
      dibuat: appNow.subtract(const Duration(days: 1)),
    );

void background(WidgetTester tester) {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
}

void foreground(WidgetTester tester) {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}

void main() {
  group('A95 penyegaran hari', () {
    testWidgets('buku kesalahan: kembali dari latar belakang esok harinya',
        (tester) async {
      final clock = FakeClock(appNow);
      final app = await pumpApp(
        tester,
        profiles: FakeProfileRepository([activeProfile()]),
        mistakes: FakeMistakeRepository([dueTomorrow()]),
        clock: clock,
      );
      await app.go(Routes.bukuKesalahan);
      expect(find.text('Besok'), findsOneWidget);
      expect(find.text('Tidak ada kartu jatuh tempo hari ini'), findsOneWidget);

      background(tester);
      clock.advance(const Duration(days: 1));
      foreground(tester);
      await tester.pumpAndSettle();

      expect(find.text('Hari ini'), findsOneWidget);
      expect(find.text('Besok'), findsNothing);
      expect(find.text('Ulangi yang jatuh tempo'), findsOneWidget);
    });

    testWidgets('buku kesalahan: app terbuka terus melewati tengah malam',
        (tester) async {
      final clock = FakeClock(appNow);
      final app = await pumpApp(
        tester,
        profiles: FakeProfileRepository([activeProfile()]),
        mistakes: FakeMistakeRepository([dueTomorrow()]),
        clock: clock,
      );
      await app.go(Routes.bukuKesalahan);
      expect(find.text('Besok'), findsOneWidget);

      // Jam berjalan lewat tengah malam; timer ke tengah malam berbunyi.
      clock.advance(const Duration(days: 1));
      await tester.pump(const Duration(days: 1));
      await tester.pumpAndSettle();

      expect(find.text('Hari ini'), findsOneWidget);
      expect(find.text('Besok'), findsNothing);
    });

    testWidgets('beranda: hitungan kartu jatuh tempo ikut hari baru',
        (tester) async {
      final clock = FakeClock(appNow);
      final app = await pumpApp(
        tester,
        profiles: FakeProfileRepository([activeProfile()]),
        mistakes: FakeMistakeRepository([dueTomorrow()]),
        clock: clock,
        height: 1800,
      );
      await app.go(Routes.beranda);
      expect(find.text('Tidak ada kartu jatuh tempo'), findsOneWidget);

      background(tester);
      clock.advance(const Duration(days: 1));
      foreground(tester);
      await tester.pumpAndSettle();

      expect(find.text('1 jatuh tempo'), findsOneWidget);
      expect(find.text('Tidak ada kartu jatuh tempo'), findsNothing);
    });

    testWidgets(
        'hari yang sama: kembali dari latar belakang tidak memuat ulang',
        (tester) async {
      final clock = FakeClock(appNow);
      final app = await pumpApp(
        tester,
        profiles: FakeProfileRepository([activeProfile()]),
        mistakes: FakeMistakeRepository([dueTomorrow()]),
        clock: clock,
      );
      await app.go(Routes.bukuKesalahan);
      background(tester);
      clock.advance(const Duration(minutes: 5));
      foreground(tester);
      await tester.pumpAndSettle();
      expect(find.text('Besok'), findsOneWidget);
    });
  });
}
