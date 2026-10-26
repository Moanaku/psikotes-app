import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/core/widgets/app_bottom_nav.dart';
import 'package:simulator_psikotes_it/core/widgets/app_button.dart';
import 'package:simulator_psikotes_it/core/widgets/number_bubble.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/features/session/session_widgets.dart';
import 'package:simulator_psikotes_it/features/stats/trend_chart.dart';

import '../support/fake_repositories.dart';
import '../support/fixtures.dart';
import '../support/pump_app.dart';
import '../support/text_fit.dart';
import 'review/review_test_support.dart';
import 'session/session_screen_test.dart' show openSession;

const _mixed = [
  Outcome.benarCepat,
  Outcome.salahCepat,
  Outcome.benarLambat,
  Outcome.dilewati,
];

Future<FakeSessionRepository> _statsSessions() async {
  final repo = FakeSessionRepository();
  for (final d in [14, 7, 1]) {
    await seedSession(
      repo,
      mode: SessionMode.simulasi,
      plan: latihanPlan(),
      finished: true,
      mulai: appNow.subtract(Duration(days: d)),
      correct: (i) => i == 0,
    );
  }
  return repo;
}

/// Uji perangkat v1 (temuan 1 sampai 6): pada skala huruf 2,0 tidak ada kata
/// yang terpotong di tengah kata di layar-layar utama, dan bilah aksi, kepala,
/// serta panel bawah menyesuaikan diri.
void main() {
  const scale = 2.0;
  Rect rect(WidgetTester t, Finder f) => t.getRect(f);

  group('tidak ada kata terpotong di 2,0', () {
    testWidgets('S04 beranda tanpa tanggal tes', (tester) async {
      await pumpApp(
        tester,
        profiles: FakeProfileRepository([activeProfile()]),
        textScale: scale,
      );
      expectNoMidWordBreaks(tester);
    });

    testWidgets('S04 beranda dengan tanggal tes', (tester) async {
      await pumpApp(
        tester,
        profiles: FakeProfileRepository(
            [activeProfile(tanggalTes: DateTime.utc(2026, 11, 5))]),
        textScale: scale,
      );
      expectNoMidWordBreaks(tester);
    });

    testWidgets('S05 tab Simulasi dan Latihan', (tester) async {
      final app = await pumpApp(
        tester,
        profiles: FakeProfileRepository([activeProfile()]),
        textScale: scale,
      );
      await app.go('/psikotes');
      expectNoMidWordBreaks(tester, reason: 'tab pertama');
      await tester.tap(find.text('Simulasi').first);
      await tester.pumpAndSettle();
      expectNoMidWordBreaks(tester, reason: 'tab Simulasi');
    });

    testWidgets('S06 latihan', (tester) async {
      await openSession(tester, SessionMode.latihan, latihanPlan(),
          textScale: scale);
      expectNoMidWordBreaks(tester);
    });

    testWidgets('S07 simulasi', (tester) async {
      await openSession(tester, SessionMode.simulasi, simulasiPlan(),
          textScale: scale);
      expectNoMidWordBreaks(tester);
    });

    testWidgets('S08 hasil dan S09 pembahasan', (tester) async {
      final sessions = FakeSessionRepository();
      final id = await seedFinished(sessions, _mixed);
      final app = await pumpApp(
        tester,
        profiles: FakeProfileRepository([activeProfile()]),
        sessions: sessions,
        textScale: scale,
      );
      await app.go('/hasil/$id');
      expectNoMidWordBreaks(tester, reason: 'hasil');
      await app.go('/hasil/$id/soal/2');
      expectNoMidWordBreaks(tester, reason: 'pembahasan');
    });

    testWidgets('S11 statistik', (tester) async {
      final app = await pumpApp(
        tester,
        profiles: FakeProfileRepository([activeProfile()]),
        sessions: await _statsSessions(),
        textScale: scale,
      );
      await app.go('/statistik');
      expectNoMidWordBreaks(tester);
    });
  });

  group('bilah aksi, kepala, dan panel', () {
    testWidgets('tombol bilah aksi disusun vertikal selebar penuh di 2,0',
        (tester) async {
      await openSession(tester, SessionMode.simulasi, simulasiPlan(),
          textScale: scale);
      final back = rect(tester, find.widgetWithText(AppButton, 'Sebelumnya'));
      final next = rect(tester, find.widgetWithText(AppButton, 'Berikutnya'));
      expect(next.width, back.width, reason: 'sama lebar');
      expect(next.width, greaterThan(300), reason: 'selebar bilah aksi');
      expect(next.bottom, lessThanOrEqualTo(back.top),
          reason: 'aksi utama di atas');
    });

    testWidgets(
        'tombol bilah aksi berdampingan di skala normal dan tidak '
        'patah di 1,3', (tester) async {
      await openSession(tester, SessionMode.simulasi, simulasiPlan());
      final back = rect(tester, find.widgetWithText(AppButton, 'Sebelumnya'));
      final next = rect(tester, find.widgetWithText(AppButton, 'Berikutnya'));
      expect(back.top, next.top);
      expect(back.right, lessThan(next.left));
    });

    testWidgets('di 1,3 tidak ada kata terpotong di sesi, hasil, dan beranda',
        (tester) async {
      await openSession(tester, SessionMode.simulasi, simulasiPlan(),
          textScale: 1.3);
      expectNoMidWordBreaks(tester, reason: 'simulasi');
      await openSession(tester, SessionMode.latihan, latihanPlan(),
          textScale: 1.3);
      expectNoMidWordBreaks(tester, reason: 'latihan');
    });

    testWidgets('latihan di 2,0: Buka petunjuk dan Kirim jawaban bertumpuk',
        (tester) async {
      await openSession(tester, SessionMode.latihan, latihanPlan(),
          textScale: scale);
      final hint =
          rect(tester, find.widgetWithText(AppButton, 'Buka petunjuk'));
      final send =
          rect(tester, find.widgetWithText(AppButton, 'Kirim jawaban'));
      expect(send.bottom, lessThanOrEqualTo(hint.top));
      expect(send.width, hint.width);
    });

    testWidgets('navigator simulasi satu baris dengan sel 48 dp',
        (tester) async {
      await openSession(tester, SessionMode.simulasi, simulasiPlan(),
          textScale: scale);
      final strip = find.byType(NumberStrip);
      expect(strip, findsOneWidget);
      expect(rect(tester, strip).height, 48);
      final tops = {
        for (final b
            in tester.widgetList<NumberBubble>(find.byType(NumberBubble)))
          tester.getTopLeft(find.byWidget(b)).dy,
      };
      expect(tops, hasLength(1), reason: 'semua nomor di satu baris');
    });

    testWidgets('simulasi di 2,0: timer tetap di kepala saat isi digulir',
        (tester) async {
      await openSession(tester, SessionMode.simulasi, simulasiPlan(),
          textScale: scale);
      final before = rect(tester, find.byType(TimerLabel));
      await tester.drag(
          find.byType(SingleChildScrollView).first, const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(rect(tester, find.byType(TimerLabel)), before);
    });

    testWidgets('Simulasi penuh di S05 ikut tergulir sebagai bagian akhir',
        (tester) async {
      final app = await pumpApp(
        tester,
        profiles: FakeProfileRepository([activeProfile()]),
        textScale: scale,
      );
      await app.go('/psikotes');
      final panel = find.text('Simulasi penuh');
      expect(panel, findsOneWidget);
      expect(
        find.ancestor(of: panel, matching: find.byType(SingleChildScrollView)),
        findsOneWidget,
        reason: 'panel ada di dalam daftar yang digulir',
      );
      final nav = rect(tester, find.byType(AppBottomNav));
      expect(rect(tester, panel).top, greaterThan(nav.top),
          reason: 'di 2,0 panel jauh di bawah dan belum terlihat');
      await tester.ensureVisible(panel);
      await tester.pumpAndSettle();
      expect(rect(tester, panel).bottom, lessThanOrEqualTo(nav.top));
    });

    testWidgets('Isi tanggal tes tidak menjadi tiga baris', (tester) async {
      await pumpApp(
        tester,
        profiles: FakeProfileRepository([activeProfile()]),
        textScale: scale,
      );
      final label = find.descendant(
        of: find.widgetWithText(AppButton, 'Isi tanggal tes'),
        matching: find.text('Isi tanggal tes'),
      );
      // Satu baris teks 16 dp berskala 2 setinggi 48 dp; dua baris 96 dp.
      expect(rect(tester, label).height, lessThanOrEqualTo(2 * 24 * scale));
    });

    testWidgets('hasil di 2,0 pada layar pendek: isi digulir, tombol tetap',
        (tester) async {
      final sessions = FakeSessionRepository();
      final id = await seedFinished(sessions, _mixed);
      final app = await pumpApp(
        tester,
        profiles: FakeProfileRepository([activeProfile()]),
        sessions: sessions,
        textScale: scale,
        height: 640,
      );
      await app.go('/hasil/$id');
      final action = find.widgetWithText(AppButton, 'Lihat pembahasan');
      final button = rect(tester, action);
      expect(button.bottom, lessThanOrEqualTo(640));
      final body = find.byType(SingleChildScrollView).first;
      await tester.drag(body, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(rect(tester, action), button,
          reason: 'tombol aksi tidak ikut tergulir');
    });

    testWidgets('pembahasan di 2,0 pada layar pendek: kunci terjangkau',
        (tester) async {
      final sessions = FakeSessionRepository();
      final id = await seedFinished(sessions, _mixed);
      final app = await pumpApp(
        tester,
        profiles: FakeProfileRepository([activeProfile()]),
        sessions: sessions,
        textScale: scale,
        height: 640,
      );
      await app.go('/hasil/$id/soal/2');
      expect(rect(tester, find.widgetWithText(AppButton, 'Berikutnya')).bottom,
          lessThanOrEqualTo(640));
      await tester.ensureVisible(find.text('Kunci').first);
      await tester.pumpAndSettle();
      expect(find.text('Kunci'), findsWidgets);
    });

    testWidgets('grafik S11 di 2,0: angka sumbu tidak bertumpuk',
        (tester) async {
      final app = await pumpApp(
        tester,
        profiles: FakeProfileRepository([activeProfile()]),
        sessions: await _statsSessions(),
        textScale: scale,
      );
      await app.go('/statistik');
      final chart = find.byType(TrendChart);
      for (final t in ['0', '50', '100']) {
        final label = find.descendant(of: chart, matching: find.text(t));
        expect(label, findsWidgets, reason: t);
        expect(rect(tester, label.first).height, lessThan(24),
            reason: 'angka sumbu "$t" satu baris');
      }
    });
  });
}
