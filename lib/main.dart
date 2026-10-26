import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'data/providers.dart';
import 'domain/providers.dart';
import 'domain/services/verbal_bank.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Bank verbal dimuat sekali sebelum app berjalan. Kegagalan baca tidak
  // menghentikan app: tipe verbal menampilkan keadaan galat di katalog.
  final bank = await loadVerbalBank(rootBundle.loadString);
  runApp(ProviderScope(
    overrides: [
      ...dataProviderOverrides,
      verbalBankStateProvider.overrideWithValue(bank),
    ],
    child: const PsikotesApp(),
  ));
}
