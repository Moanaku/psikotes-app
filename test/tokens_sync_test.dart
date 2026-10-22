import 'dart:convert';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/core/theme/app_tokens.dart';

/// Menjaga docs/design/tokens.json dan app_tokens.dart tetap sama.
void main() {
  final json = jsonDecode(File('docs/design/tokens.json').readAsStringSync())
      as Map<String, dynamic>;

  String hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  Map<String, String> asMap(AppColors c) => {
        'surface': hex(c.surface),
        'surfaceContainer': hex(c.surfaceContainer),
        'surfaceContainerHigh': hex(c.surfaceContainerHigh),
        'ink': hex(c.ink),
        'inkMuted': hex(c.inkMuted),
        'outlineVariant': hex(c.outlineVariant),
        'outline': hex(c.outline),
        'accent': hex(c.accent),
        'onAccent': hex(c.onAccent),
        'ok': hex(c.ok),
        'okContainer': hex(c.okContainer),
        'bad': hex(c.bad),
        'badContainer': hex(c.badContainer),
        'placeholder': hex(c.placeholder),
      };

  for (final mode in ['light', 'dark']) {
    test('warna $mode sama dengan tokens.json', () {
      final expected =
          Map<String, String>.from(json['color'][mode] as Map<String, dynamic>);
      final actual = asMap(mode == 'light' ? AppColors.light : AppColors.dark);
      expect(actual, expected);
    });
  }

  test('skala jarak sama dengan tokens.json', () {
    expect(json['spacing'], [4, 8, 12, 16, 24, 32, 48]);
    expect([
      AppSpace.s4,
      AppSpace.s8,
      AppSpace.s12,
      AppSpace.s16,
      AppSpace.s24,
      AppSpace.s32,
      AppSpace.s48,
    ], [
      4,
      8,
      12,
      16,
      24,
      32,
      48
    ]);
  });
}
