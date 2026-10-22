import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/app/app.dart';

void main() {
  testWidgets('app menyala dan menampilkan layar awal', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: PsikotesApp()));
    await tester.pumpAndSettle();
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsWidgets);
  });
}
