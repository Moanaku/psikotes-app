import 'package:flutter/material.dart';

/// Token desain. Nilai mengikuti docs/design/tokens.json dan docs/04-sistem-desain.md.
/// Ubah ketiganya bersama. Widget tidak boleh memakai hex mentah atau Colors.*;
/// ambil dari context.tokens atau Theme.of(context).colorScheme.

@immutable
class AppColors {
  const AppColors({
    required this.surface,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.ink,
    required this.inkMuted,
    required this.outlineVariant,
    required this.outline,
    required this.accent,
    required this.onAccent,
    required this.ok,
    required this.okContainer,
    required this.bad,
    required this.badContainer,
    required this.placeholder,
  });

  final Color surface;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color ink;
  final Color inkMuted;
  final Color outlineVariant;
  final Color outline;
  final Color accent; // stabilo, satu-satunya aksen
  final Color onAccent;
  final Color ok;
  final Color okContainer;
  final Color bad;
  final Color badContainer;
  final Color placeholder;

  static const light = AppColors(
    surface: Color(0xFFF1F2ED),
    surfaceContainer: Color(0xFFFAFAF7),
    surfaceContainerHigh: Color(0xFFE4E7DF),
    ink: Color(0xFF1B1E1C),
    inkMuted: Color(0xFF565C57),
    outlineVariant: Color(0xFFCDD2C8),
    outline: Color(0xFF7F867F),
    accent: Color(0xFFF2CF3D),
    onAccent: Color(0xFF1B1E1C),
    ok: Color(0xFF2B6A4B),
    okContainer: Color(0xFFE0EDE4),
    bad: Color(0xFFA23B2F),
    badContainer: Color(0xFFF5E2DE),
    placeholder: Color(0xFF6B716C),
  );

  /// Usulan; diperiksa per layar di tugas T21.
  static const dark = AppColors(
    surface: Color(0xFF151816),
    surfaceContainer: Color(0xFF1D211E),
    surfaceContainerHigh: Color(0xFF2A2F2B),
    ink: Color(0xFFECEEE8),
    inkMuted: Color(0xFFA9AFA8),
    outlineVariant: Color(0xFF3A403B),
    outline: Color(0xFF7F867F),
    accent: Color(0xFFF2CF3D),
    onAccent: Color(0xFF1B1E1C),
    ok: Color(0xFF7FD1A0),
    okContainer: Color(0xFF1F3A2B),
    bad: Color(0xFFEE9A8F),
    badContainer: Color(0xFF3B1F1B),
    placeholder: Color(0xFFA9AFA8),
  );
}

/// Skala jarak tunggal. Tidak ada nilai lain.
abstract final class AppSpace {
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s48 = 48;
}

/// Tiga radius. Bentuk bulat penuh adalah bentuk, bukan nilai radius.
abstract final class AppRadius {
  static const double sm = 4;
  static const double md = 8;
  static const double lg = 12;
  static const double full = 999;
}

abstract final class AppSizes {
  static const double touchTarget = 48;
  static const double listRowMinHeight = 56;
  static const double screenMargin = 16;
  static const double iconBase = 24;
}

/// Satu durasi dan satu kurva untuk semua transisi.
abstract final class AppMotion {
  static const Duration duration = Duration(milliseconds: 150);
  static const Curve curve = Curves.easeOut;
}

/// Skala tipografi: enam ukuran. Angka memakai tabular figures.
abstract final class AppType {
  static const String family = 'InstrumentSans';
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  static TextStyle _s(double size, double height, FontWeight w, Color c) =>
      TextStyle(
        fontFamily: family,
        fontSize: size,
        height: height / size,
        fontWeight: w,
        color: c,
        fontFeatures: tabular,
      );

  static TextStyle caption(Color c) => _s(12, 16, FontWeight.w600, c);
  static TextStyle label(Color c) => _s(14, 20, FontWeight.w500, c);
  static TextStyle body(Color c) => _s(16, 24, FontWeight.w400, c);
  static TextStyle title(Color c) => _s(20, 28, FontWeight.w700, c);
  static TextStyle headline(Color c) => _s(28, 36, FontWeight.w700, c);
  static TextStyle display(Color c) => _s(36, 44, FontWeight.w700, c);
}

@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({required this.colors});

  final AppColors colors;

  @override
  AppTokens copyWith({AppColors? colors}) =>
      AppTokens(colors: colors ?? this.colors);

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    // Perpindahan tema tidak dianimasikan antar palet; ambil yang terdekat.
    if (other is! AppTokens) return this;
    return t < 0.5 ? this : other;
  }
}

extension AppTokensContext on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}
