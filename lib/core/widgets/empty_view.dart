import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'app_button.dart';

/// Kondisi kosong: judul `title`, satu kalimat penjelasan, satu tombol aksi.
/// Bedakan "belum ada data sama sekali" dari "hasil filter kosong" lewat teks
/// dan aksinya ("Mulai latihan" lawan "Tampilkan semua"). Tombol boleh dihilangkan
/// bila tidak ada yang bisa dilakukan pengguna.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  }) : assert(
          (actionLabel == null) == (onAction == null),
          'actionLabel dan onAction diisi bersama.',
        );

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    return Padding(
      padding: const EdgeInsets.all(AppSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
              header: true, child: Text(title, style: AppType.title(c.ink))),
          const SizedBox(height: AppSpace.s8),
          Text(message, style: AppType.body(c.inkMuted)),
          if (actionLabel != null) ...[
            const SizedBox(height: AppSpace.s24),
            AppButton(label: actionLabel!, onPressed: onAction, expand: false),
          ],
        ],
      ),
    );
  }
}
