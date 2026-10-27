import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Gelembung percakapan wawancara. Pewawancara: `surfaceContainer` dengan
/// batas `outlineVariant`, radius 12 dengan sudut kiri bawah 4, di kiri.
/// Pengguna: latar `ink`, teks `surfaceContainer`, sudut kanan bawah 4, di
/// kanan. [ChatBubble.typing] adalah penanda pewawancara sedang mengetik
/// (tiga titik diam; gerak hanya untuk respons atas aksi pengguna).
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required String this.text,
    required this.fromInterviewer,
    this.speaker = 'Pewawancara',
  });

  const ChatBubble.typing({super.key, this.speaker = 'Pewawancara'})
      : text = null,
        fromInterviewer = true;

  final String? text;
  final bool fromInterviewer;

  /// Nama pembicara di atas isi pesan pewawancara.
  final String speaker;

  /// Bagian lebar yang boleh dipakai satu gelembung.
  static const double maxWidthFactor = 0.86;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    final typing = text == null;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(AppRadius.lg),
      topRight: const Radius.circular(AppRadius.lg),
      bottomLeft:
          Radius.circular(fromInterviewer ? AppRadius.sm : AppRadius.lg),
      bottomRight:
          Radius.circular(fromInterviewer ? AppRadius.lg : AppRadius.sm),
    );
    final decoration = fromInterviewer
        ? BoxDecoration(
            color: c.surfaceContainer,
            border: Border.all(color: c.outlineVariant),
            borderRadius: radius,
          )
        : BoxDecoration(color: c.ink, borderRadius: radius);

    final Widget body;
    if (typing) {
      body = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: AppSpace.s4),
            TypingDot(color: c.outline),
          ],
        ],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (fromInterviewer) ...[
            Text(
              speaker,
              style: AppType.label(c.inkMuted)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpace.s4),
          ],
          Text(text!,
              style:
                  AppType.body(fromInterviewer ? c.ink : c.surfaceContainer)),
        ],
      );
    }

    return Align(
      alignment: fromInterviewer ? Alignment.centerLeft : Alignment.centerRight,
      child: LayoutBuilder(
        builder: (context, box) => ConstrainedBox(
          constraints: BoxConstraints(maxWidth: box.maxWidth * maxWidthFactor),
          child: Semantics(
            label: typing
                ? '$speaker sedang mengetik'
                : '${fromInterviewer ? speaker : 'Kamu'}: $text',
            excludeSemantics: true,
            child: DecoratedBox(
              decoration: decoration,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpace.s16,
                  vertical: typing ? AppSpace.s16 : AppSpace.s12,
                ),
                child: body,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Satu titik penanda mengetik, 8 dp.
class TypingDot extends StatelessWidget {
  const TypingDot({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: AppSpace.s8,
        child: DecoratedBox(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      );
}
