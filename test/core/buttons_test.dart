import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/core/theme/app_icons.dart';
import 'package:simulator_psikotes_it/core/widgets/app_button.dart';
import 'package:simulator_psikotes_it/core/widgets/app_icon_button.dart';

import 'golden_helper.dart';

void main() {
  group('AppButton', () {
    Widget all() => scene([
          AppButton(label: 'Mulai diagnostik', onPressed: () {}),
          AppButton(
            label: 'Lihat pembahasan',
            onPressed: () {},
            variant: AppButtonVariant.secondary,
          ),
          AppButton(
            label: 'Tambah catatan tes',
            onPressed: () {},
            variant: AppButtonVariant.outline,
            icon: AppIcons.plus,
          ),
          const AppButton(label: 'Mulai simulasi', onPressed: null),
          const AppButton(
            label: 'Ekspor CSV',
            onPressed: null,
            variant: AppButtonVariant.outline,
          ),
          AppButton(label: 'Mulai', onPressed: () {}, expand: false),
          AppButton(label: longLabel, onPressed: () {}),
        ], gap: 12);

    goldenTest('golden', (tester) async {
      await pumpScene(tester, all());
      await expectGolden(tester, 'app_button');
    });

    testWidgets('target sentuh 48 dp dan label tidak terpotong di skala 2,0',
        (tester) async {
      await pumpScene(tester, all(), textScale: 2);
      expectTouchTargets48(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('memanggil onPressed dan melaporkan semantik tombol',
        (tester) async {
      var taps = 0;
      await pumpScene(
        tester,
        AppButton(label: 'Kirim jawaban B', onPressed: () => taps++),
      );
      await tester.tap(find.text('Kirim jawaban B'));
      expect(taps, 1);
      expect(
        tester.getSemantics(find.byType(AppButton)),
        matchesSemantics(
          label: 'Kirim jawaban B',
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          hasTapAction: true,
        ),
      );
    });

    testWidgets('nonaktif tidak memanggil apa pun', (tester) async {
      await pumpScene(
        tester,
        const AppButton(label: 'Kirim jawaban', onPressed: null),
      );
      await tester.tap(find.text('Kirim jawaban'));
      expect(tester.takeException(), isNull);
    });
  });

  group('AppIconButton', () {
    Widget all() => scene([
          Row(children: [
            AppIconButton(
                icon: AppIcons.close, label: 'Tutup sesi', onPressed: () {}),
            AppIconButton(
                icon: AppIcons.sliders, label: 'Pengaturan', onPressed: () {}),
            const AppIconButton(
                icon: AppIcons.send, label: 'Kirim jawaban', onPressed: null),
          ]),
        ]);

    goldenTest('golden', (tester) async {
      await pumpScene(tester, all());
      await expectGolden(tester, 'app_icon_button');
    });

    testWidgets('48 x 48 dan punya label semantik', (tester) async {
      await pumpScene(tester, all());
      expectTouchTargets48(tester);
      expect(
          tester.getSize(find.byType(AppIconButton).first), const Size(48, 48));
      expect(
        tester.getSemantics(find.byType(AppIconButton).first),
        matchesSemantics(
          label: 'Tutup sesi',
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          hasTapAction: true,
        ),
      );
    });
  });
}
