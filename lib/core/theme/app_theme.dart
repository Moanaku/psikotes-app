import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// ThemeData ditulis eksplisit dari token. Tidak memakai ColorScheme.fromSeed
/// dan tidak memakai dynamic color. Komponen inti (T02) membaca tema ini.
abstract final class AppTheme {
  static ThemeData light() => _build(AppColors.light, Brightness.light);
  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors c, Brightness b) {
    final scheme = ColorScheme(
      brightness: b,
      primary: c.ink,
      onPrimary: c.surfaceContainer,
      secondary: c.accent,
      onSecondary: c.onAccent,
      error: c.bad,
      onError: c.surfaceContainer,
      surface: c.surface,
      onSurface: c.ink,
      onSurfaceVariant: c.inkMuted,
      outline: c.outline,
      outlineVariant: c.outlineVariant,
      surfaceContainer: c.surfaceContainer,
      surfaceContainerHigh: c.surfaceContainerHigh,
    );

    final text = TextTheme(
      displayLarge: AppType.display(c.ink),
      displayMedium: AppType.display(c.ink),
      displaySmall: AppType.display(c.ink),
      headlineLarge: AppType.headline(c.ink),
      headlineMedium: AppType.headline(c.ink),
      headlineSmall: AppType.headline(c.ink),
      titleLarge: AppType.title(c.ink),
      titleMedium: AppType.title(c.ink),
      titleSmall: AppType.title(c.ink),
      bodyLarge: AppType.body(c.ink),
      bodyMedium: AppType.body(c.ink),
      bodySmall: AppType.label(c.inkMuted),
      labelLarge: AppType.label(c.ink),
      labelMedium: AppType.label(c.ink),
      labelSmall: AppType.caption(c.inkMuted),
    );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    );
    const minSize = Size(AppSizes.touchTarget, AppSizes.touchTarget);

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.surface,
      textTheme: text,
      fontFamily: AppType.family,
      extensions: [AppTokens(colors: c)],
      dividerTheme: DividerThemeData(
        color: c.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.ink,
          foregroundColor: c.surfaceContainer,
          minimumSize: minSize,
          shape: shape,
          textStyle: AppType.body(c.surfaceContainer)
              .copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: c.surfaceContainer,
          foregroundColor: c.ink,
          minimumSize: minSize,
          shape: shape,
          side: BorderSide(color: c.outline),
          textStyle:
              AppType.body(c.ink).copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.ink,
          minimumSize: minSize,
          shape: shape,
          textStyle:
              AppType.body(c.ink).copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceContainer,
        hintStyle: AppType.body(c.placeholder),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s12,
          vertical: AppSpace.s12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: c.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: c.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: c.ink, width: 2),
        ),
      ),
      splashFactory: InkRipple.splashFactory,
    );
  }
}
