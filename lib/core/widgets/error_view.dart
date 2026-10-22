import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'app_button.dart';

/// Kondisi galat: apa yang gagal (`title`), apa yang bisa dilakukan (`message`),
/// dan tombol "Coba lagi" di tempatnya. Hanya menerima teks yang sudah ditulis
/// untuk pengguna; jangan pernah mengoper `exception.toString()`.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
    this.retryLabel = 'Coba lagi',
  });

  final String title;
  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    return Padding(
      padding: const EdgeInsets.all(AppSpace.s16),
      child: Semantics(
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              header: true,
              child: Text(title, style: AppType.title(c.ink)),
            ),
            const SizedBox(height: AppSpace.s8),
            Text(message, style: AppType.body(c.inkMuted)),
            const SizedBox(height: AppSpace.s24),
            AppButton(
              label: retryLabel,
              onPressed: onRetry,
              variant: AppButtonVariant.outline,
              expand: false,
            ),
          ],
        ),
      ),
    );
  }
}
