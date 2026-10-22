import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'data/providers.dart';

void main() {
  runApp(ProviderScope(
    overrides: dataProviderOverrides,
    child: const PsikotesApp(),
  ));
}
