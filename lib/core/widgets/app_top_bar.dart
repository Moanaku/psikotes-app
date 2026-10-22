import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_tokens.dart';
import 'app_icon_button.dart';

/// Bilah atas: kembali di kiri, judul, aksi di kanan. Tinggi minimal 56 dan
/// bertambah bila judul panjang atau font sistem besar. Dipasang di badan layar,
/// bukan di `Scaffold.appBar`, karena `appBar` memaksa tinggi tetap.
class AppTopBar extends StatelessWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.onBack,
    this.backIcon = AppIcons.back,
    this.backLabel = 'Kembali',
    this.actions = const [],
  });

  final String title;

  /// Null berarti tanpa tombol kembali (layar tab).
  final VoidCallback? onBack;
  final IconData backIcon;
  final String backLabel;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSizes.topBarHeight),
      child: Row(
        children: [
          if (onBack != null)
            AppIconButton(icon: backIcon, label: backLabel, onPressed: onBack)
          else
            const SizedBox(width: AppSpace.s16),
          Expanded(
            child: Semantics(
              header: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s8,
                  vertical: AppSpace.s8,
                ),
                child: Text(title, style: AppType.title(c.ink)),
              ),
            ),
          ),
          ...actions,
          if (actions.isEmpty) const SizedBox(width: AppSpace.s8),
        ],
      ),
    );
  }
}
