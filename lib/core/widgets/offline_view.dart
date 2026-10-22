import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_tokens.dart';
import 'app_button.dart';
import 'note_box.dart';

/// Kondisi offline, dibedakan dari galat biasa: menyebut apa yang tidak jalan
/// (`message`) dan apa yang tetap jalan tanpa internet (`stillWorks`, di kotak catatan).
/// Psikotes selalu offline; hanya wawancara yang memakai layar ini.
class OfflineView extends StatelessWidget {
  const OfflineView({
    super.key,
    required this.message,
    required this.stillWorks,
    this.actionLabel,
    this.onAction,
    this.title = 'Tidak ada internet',
  }) : assert(
          (actionLabel == null) == (onAction == null),
          'actionLabel dan onAction diisi bersama.',
        );

  final String title;
  final String message;
  final String stillWorks;
  final String? actionLabel;
  final VoidCallback? onAction;

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
            const SizedBox(height: AppSpace.s16),
            NoteBox(text: stillWorks, icon: AppIcons.check),
            if (actionLabel != null) ...[
              const SizedBox(height: AppSpace.s24),
              AppButton(
                  label: actionLabel!, onPressed: onAction, expand: false),
            ],
          ],
        ),
      ),
    );
  }
}
