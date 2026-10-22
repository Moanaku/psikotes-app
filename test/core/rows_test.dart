import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/core/theme/app_icons.dart';
import 'package:simulator_psikotes_it/core/widgets/choice_row.dart';
import 'package:simulator_psikotes_it/core/widgets/list_row.dart';
import 'package:simulator_psikotes_it/core/widgets/status_tag.dart';

import 'golden_helper.dart';

void main() {
  group('ListRow', () {
    Widget all() => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListRow(
              leading: AppIcons.book,
              title: 'Buku kesalahan',
              subtitle: '4 jatuh tempo',
              onTap: () {},
            ),
            const ListRow(title: 'Profil aktif'),
            ListRow(
              title: 'Deret angka',
              subtitle: 'Numerik dan logika',
              trailing: const StatusTag(
                label: 'Hari ini',
                kind: StatusTagKind.attention,
              ),
              onTap: () {},
            ),
            ListRow(
              leading: AppIcons.lock,
              title: longLabel,
              subtitle: longSentence,
              onTap: () {},
            ),
          ],
        );

    goldenTest('golden', (tester) async {
      await pumpScene(tester, all());
      await expectGolden(tester, 'list_row');
    });

    testWidgets('tinggi min 56, target 48, tidak terpotong di skala 2,0',
        (tester) async {
      await pumpScene(tester, all(), textScale: 2);
      for (final row in find.byType(ListRow).evaluate()) {
        expect(tester.getSize(find.byWidget(row.widget)).height,
            greaterThanOrEqualTo(56));
      }
      expectTouchTargets48(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('onTap bekerja', (tester) async {
      var taps = 0;
      await pumpScene(
        tester,
        ListRow(title: 'Pengaturan', onTap: () => taps++),
      );
      await tester.tap(find.text('Pengaturan'));
      expect(taps, 1);
    });
  });

  group('ChoiceRow', () {
    Widget all() => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ChoiceRow(
              title: 'QA Engineer',
              subtitle: 'Ketelitian, logika deduktif, Kraepelin / Pauli',
              selected: true,
              onTap: () {},
            ),
            ChoiceRow(
              title: 'Mobile / App Developer',
              subtitle: 'Figural induktif, pseudocode, numerik',
              selected: false,
              onTap: () {},
            ),
            ChoiceRow(
              title: longLabel,
              subtitle: longSentence,
              selected: false,
              onTap: () {},
            ),
          ],
        );

    goldenTest('golden', (tester) async {
      await pumpScene(tester, all());
      await expectGolden(tester, 'choice_row');
    });

    testWidgets('target 48 dan tidak terpotong di skala 2,0', (tester) async {
      await pumpScene(tester, all(), textScale: 2);
      expectTouchTargets48(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('semantik pilihan tunggal', (tester) async {
      await pumpScene(
        tester,
        ChoiceRow(title: 'IT Business Analyst', selected: true, onTap: () {}),
      );
      expect(
        tester.getSemantics(find.byType(ChoiceRow)),
        matchesSemantics(
          label: 'IT Business Analyst',
          isButton: true,
          isInMutuallyExclusiveGroup: true,
          hasCheckedState: true,
          isChecked: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
    });
  });
}
