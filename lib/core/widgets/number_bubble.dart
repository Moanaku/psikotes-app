import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

enum NumberBubbleState { answered, current, unanswered }

/// Bulatan nomor soal, 32. Terjawab: `ink`. Sekarang: `accent` berbatas `ink` 2.
/// Belum: batas `outline`. Bila `onTap` ada, area sentuh diperluas ke 48.
class NumberBubble extends StatelessWidget {
  const NumberBubble({
    super.key,
    required this.number,
    required this.state,
    this.onTap,
  });

  final int number;
  final NumberBubbleState state;
  final VoidCallback? onTap;

  String get _stateLabel => switch (state) {
        NumberBubbleState.answered => 'sudah dijawab',
        NumberBubbleState.current => 'sedang dikerjakan',
        NumberBubbleState.unanswered => 'belum dijawab',
      };

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    final duration = context.motion;

    final Color bg;
    final Color fg;
    final Color border;
    final double borderWidth;
    switch (state) {
      case NumberBubbleState.answered:
        bg = c.ink;
        fg = c.surfaceContainer;
        border = c.ink;
        borderWidth = 1;
      case NumberBubbleState.current:
        bg = c.accent;
        fg = c.onAccent;
        border = c.ink;
        borderWidth = 2;
      case NumberBubbleState.unanswered:
        bg = Colors.transparent;
        fg = c.inkMuted;
        border = c.outline;
        borderWidth = 1;
    }

    final bubble = AnimatedContainer(
      duration: duration,
      curve: AppMotion.curve,
      width: AppSizes.bubble,
      height: AppSizes.bubble,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
      foregroundDecoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: border, width: borderWidth),
      ),
      child: Text('$number', style: AppType.caption(fg)),
    );

    return Semantics(
      button: onTap != null,
      selected: state == NumberBubbleState.current,
      label: 'Soal $number, $_stateLabel',
      excludeSemantics: true,
      onTap: onTap,
      child: onTap == null
          ? bubble
          : InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: AppSizes.touchTarget,
                height: AppSizes.touchTarget,
                child: Center(child: bubble),
              ),
            ),
    );
  }
}
