import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_tokens.dart';

/// Isian dengan label di atas (`label` 600), tinggi 48, batas `outline`.
/// Fokus: kontur `ink` 2. Galat: kontur `bad` 2 dan pesan di bawah; pesan galat
/// harus menyebut apa yang salah dan apa yang bisa dilakukan.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.helper,
    this.errorText,
    this.onChanged,
    this.keyboardType,
    this.inputFormatters,
    this.textInputAction,
    this.obscureText = false,
    this.enabled = true,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? helper;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool enabled;
  final int minLines;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    final hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppType.label(c.ink).copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpace.s4),
        Semantics(
          label: label,
          textField: true,
          child: TextField(
            controller: controller,
            enabled: enabled,
            onChanged: onChanged,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            textInputAction: textInputAction,
            obscureText: obscureText,
            minLines: minLines,
            maxLines: obscureText ? 1 : maxLines,
            style: AppType.body(c.ink),
            cursorColor: c.ink,
            decoration: InputDecoration(
              hintText: hint,
              // Kontur galat ikut tema; tanpa errorText agar pesan memakai gaya sendiri.
              enabledBorder: hasError
                  ? Theme.of(context).inputDecorationTheme.errorBorder
                  : null,
              focusedBorder: hasError
                  ? Theme.of(context).inputDecorationTheme.focusedErrorBorder
                  : null,
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: AppSpace.s4),
          Semantics(
            liveRegion: true,
            child: Text(errorText!, style: AppType.label(c.bad)),
          ),
        ] else if (helper != null) ...[
          const SizedBox(height: AppSpace.s4),
          Text(helper!, style: AppType.label(c.inkMuted)),
        ],
      ],
    );
  }
}
