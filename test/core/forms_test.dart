import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/core/theme/app_icons.dart';
import 'package:simulator_psikotes_it/core/widgets/app_text_field.dart';
import 'package:simulator_psikotes_it/core/widgets/note_box.dart';

import 'golden_helper.dart';

void main() {
  group('NoteBox', () {
    Widget all() => scene([
          const NoteBox(text: 'Bisa membuat lebih dari satu profil nanti.'),
          const NoteBox(
            icon: AppIcons.lock,
            text: 'Disimpan hanya di HP ini dan tidak ikut ke repo. '
                'Jangan bagikan soal asli perusahaan.',
          ),
          const NoteBox(icon: AppIcons.bulb, text: longSentence),
        ], gap: 12);

    testWidgets('golden', (tester) async {
      await pumpScene(tester, all());
      await expectGolden(tester, 'note_box');
    });

    testWidgets('teks panjang tidak terpotong di skala 2,0', (tester) async {
      await pumpScene(tester, all(), textScale: 2);
      expect(tester.takeException(), isNull);
    });
  });

  group('AppTextField', () {
    Widget all() => scene([
          const AppTextField(label: 'Nama profil', hint: 'QA, CCAT-style'),
          AppTextField(
            label: 'Nama profil',
            controller: TextEditingController(text: 'Mobile, Psikotes Bank'),
          ),
          const AppTextField(
            label: 'Tanggal tes',
            hint: '31 Desember 2026',
            helper: 'Boleh dikosongkan.',
          ),
          const AppTextField(
            label: 'Jumlah soal',
            errorText: 'Isi angka 1 sampai 200.',
          ),
          const AppTextField(label: 'Dinonaktifkan', enabled: false),
          const AppTextField(
            label: 'CV untuk wawancara',
            hint: 'Tempel CV di sini',
            minLines: 3,
            maxLines: 5,
          ),
        ]);

    testWidgets('golden', (tester) async {
      await pumpScene(tester, all());
      await expectGolden(tester, 'app_text_field');
    });

    testWidgets('isian satu baris setinggi 48', (tester) async {
      await pumpScene(
        tester,
        const AppTextField(label: 'Nama profil', hint: 'QA'),
      );
      expect(tester.getSize(find.byType(TextField)).height, 48);
    });

    testWidgets('label panjang dan galat tidak terpotong di skala 2,0',
        (tester) async {
      await pumpScene(
        tester,
        const AppTextField(label: longLabel, errorText: longSentence),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('pesan galat ditemani ikon berlabel', (tester) async {
      await pumpScene(
        tester,
        const AppTextField(
            label: 'Jumlah soal', errorText: 'Isi angka 1 sampai 200.'),
      );
      expect(find.byIcon(AppIcons.alert), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^Galat')), findsOneWidget);
    });

    testWidgets('mengetik memanggil onChanged', (tester) async {
      String? value;
      await pumpScene(
        tester,
        AppTextField(label: 'Nama profil', onChanged: (v) => value = v),
      );
      await tester.enterText(find.byType(TextField), 'QA Engineer');
      expect(value, 'QA Engineer');
    });

    testWidgets('semantik: bidang isian berlabel', (tester) async {
      await pumpScene(tester, const AppTextField(label: 'Nama profil'));
      expect(find.bySemanticsLabel(RegExp('Nama profil')), findsWidgets);
    });
  });
}
