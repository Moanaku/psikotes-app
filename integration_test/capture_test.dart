import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:simulator_psikotes_it/core/widgets/app_chip.dart';
import 'package:simulator_psikotes_it/core/widgets/list_row.dart';
import 'package:simulator_psikotes_it/data/db/app_database.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/domain/providers.dart';
import 'package:simulator_psikotes_it/domain/services/secret_store.dart';

import 'support/real_app.dart';

/// Alur 3 (docs/08-rencana-tes.md): simpan soal Capture, kerjakan di latihan,
/// jawab salah, kartu muncul di buku kesalahan; ekspor backup lalu impor di
/// database bersih.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Capture sampai kartu, lalu backup dipulihkan di database bersih',
      (tester) async {
    final app = await RealApp.start(tester);
    addTearDown(app.dispose);
    await app.createUmumProfile();

    // Simpan soal Capture lewat formulir S12.
    await app.tapText('Psikotes', last: true);
    expect(find.text('Belum ada soal Capture'), findsOneWidget);
    await app.tapText('Buka Capture');
    await app.tapChip('Numerik');
    await tester.enterText(fieldLabeled('Teks soal'), 'Berapa 2 + 2?');
    await tester.enterText(fieldLabeled('Opsi A'), '3');
    await tester.enterText(fieldLabeled('Opsi B'), '4');
    await tester.enterText(fieldLabeled('Opsi C'), '5');
    final key = find.byKey(const ValueKey('kunci-1'));
    await tester.ensureVisible(key);
    await tester.tap(key);
    await tester.pumpAndSettle();
    await app.tapButton('Simpan ke bank pribadi');

    var questions = await app.db.select(app.db.capturedQuestionTable).get();
    expect(questions, hasLength(1));
    expect(questions.single.teks, 'Berapa 2 + 2?');
    expect(questions.single.kunci, 1);
    expect(find.text('Soal hasil Capture: 1'), findsOneWidget);
    // Konfirmasi simpan tampil di layar asal, lalu hilang sendiri.
    expect(find.text('Soal disimpan ke bank pribadi'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Soal disimpan ke bank pribadi'), findsNothing);

    // Kerjakan di sesi latihan dari bank pribadi dan jawab salah.
    await app.tapText('Soal hasil Capture: 1');
    expect(find.text('Berapa 2 + 2?'), findsOneWidget);
    expect(app.correctIndex, 1);
    await app.chooseOption(0);
    await app.tapButton('Kirim jawaban A');
    expect(find.text('Salah. Kunci: B'), findsOneWidget);
    await app.tapButton('Lihat hasil');
    expect(find.text('Hasil sesi'), findsOneWidget);

    // Kartu Capture muncul di buku kesalahan dan terhubung ke soalnya.
    var cards = await app.db.select(app.db.mistakeCardTable).get();
    expect(cards, hasLength(1));
    expect(cards.single.sumber, AnswerSource.capture.code);
    expect(cards.single.refId, questions.single.id);
    await app.go('/buku-kesalahan');
    await app.tapChip('Capture');
    expect(find.byType(ListRow), findsOneWidget);
    expect(find.widgetWithText(AppChip, 'Capture'), findsOneWidget);

    // Backup: ekspor tanpa key API, lalu impor ke database bersih.
    await app.secrets.write(AiProvider.gemini.secretName, 'KUNCI-RAHASIA-UJI');
    final json =
        await app.container.read(backupServiceProvider).export(app.clock.now());
    expect(json, isNot(contains('KUNCI-RAHASIA-UJI')));
    expect(json, contains('Berapa 2 + 2?'));
    expect(jsonDecode(json), isA<Map<String, dynamic>>());

    await app.dispose();
    final clean = AppDatabase(NativeDatabase.memory());
    expect(await clean.select(clean.capturedQuestionTable).get(), isEmpty);
    final restored = await RealApp.start(tester, db: clean);
    addTearDown(restored.dispose);
    // Tanpa profil, app menuju onboarding; impor lewat layanan yang sama
    // dengan tombol "Impor backup" di Pengaturan.
    expect(find.text('Kamu melamar sebagai apa?'), findsOneWidget);
    final summary =
        await restored.container.read(backupServiceProvider).import(json);
    expect(summary, isNotNull);
    await restored.tester.pumpAndSettle();

    questions = await clean.select(clean.capturedQuestionTable).get();
    expect(questions.map((q) => q.teks), ['Berapa 2 + 2?']);
    cards = await clean.select(clean.mistakeCardTable).get();
    expect(cards.single.sumber, AnswerSource.capture.code);
    expect(cards.single.refId, questions.single.id);
    expect(await clean.select(clean.testProfileTable).get(), hasLength(1));
    expect(await clean.select(clean.answerTable).get(), hasLength(1));

    // Setelah dipulihkan, app langsung memakai datanya.
    await restored.go('/psikotes');
    expect(find.text('Soal hasil Capture: 1'), findsOneWidget);
    await restored.go('/buku-kesalahan');
    expect(find.byType(ListRow), findsOneWidget);
  });
}
