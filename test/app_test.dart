import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

void main() {
  testWidgets('app menyala dan menampilkan layar awal', (tester) async {
    await pumpApp(tester);
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsWidgets);
    // Belum ada profil: layar awal adalah S01.
    expect(find.text('Kamu melamar sebagai apa?'), findsOneWidget);
  });
}
