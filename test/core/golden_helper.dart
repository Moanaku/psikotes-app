import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/core/theme/app_theme.dart';
import 'package:simulator_psikotes_it/core/theme/app_tokens.dart';

const _boundary = ValueKey('golden-boundary');

/// Teks Indonesia terpanjang yang masuk akal untuk label dan keterangan.
const longLabel = 'Simpan ke bank pribadi dan hubungkan ke catatan tes';
const longSentence =
    'Backup dibuat oleh versi aplikasi yang lebih baru, perbarui aplikasi '
    'lalu coba lagi dari menu pengaturan.';

/// Test golden bertag `golden` (lihat dart_test.yaml dan ADR-13).
void goldenTest(String description, Future<void> Function(WidgetTester) body) =>
    testWidgets(description, body, tags: ['golden']);

/// Memasang [child] pada tema terang di lebar [width] dp, skala 1:1.
Future<void> pumpScene(
  WidgetTester tester,
  Widget child, {
  double width = 360,
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 2400);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: app!,
      ),
      home: Material(
        color: AppColors.light.surface,
        child: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: _boundary,
            child: Container(
              width: width,
              color: AppColors.light.surface,
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Mencocokkan tampilan dengan berkas di test/core/goldens/[name].png.
Future<void> expectGolden(WidgetTester tester, String name) =>
    expectLater(find.byKey(_boundary), matchesGoldenFile('goldens/$name.png'));

/// Susunan vertikal untuk menampilkan beberapa keadaan satu komponen.
Widget scene(List<Widget> children, {double gap = AppSpace.s16}) => Padding(
      padding: const EdgeInsets.all(AppSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: gap),
            children[i],
          ],
        ],
      ),
    );

/// Semua area yang bisa diketuk (InkWell) minimal 48 x 48 dp.
void expectTouchTargets48(WidgetTester tester) {
  final targets = find.byType(InkWell);
  expect(targets, findsWidgets);
  for (final element in targets.evaluate()) {
    final size = tester.getSize(find.byWidget(element.widget));
    expect(size.width, greaterThanOrEqualTo(AppSizes.touchTarget),
        reason: 'lebar target ${element.widget}');
    expect(size.height, greaterThanOrEqualTo(AppSizes.touchTarget),
        reason: 'tinggi target ${element.widget}');
  }
}
