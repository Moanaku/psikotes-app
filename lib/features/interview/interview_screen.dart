import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/empty_view.dart';

/// Tab Wawancara (S15) selama simulasi wawancara belum ada. Fiturnya (F15,
/// F18) dikerjakan terakhir (ADR-11); layar ini hanya memberi tahu dan
/// mengarahkan ke psikotes.
class InterviewScreen extends StatelessWidget {
  const InterviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppTopBar(title: 'Wawancara'),
        Expanded(
          child: SingleChildScrollView(
            child: EmptyView(
              title: 'Simulasi wawancara hadir di rilis berikutnya',
              message: 'Fitur ini belum bisa dipakai. Latihan psikotes sudah '
                  'siap dikerjakan.',
              actionLabel: 'Buka katalog psikotes',
              onAction: () => context.go(Routes.psikotes),
            ),
          ),
        ),
      ],
    );
  }
}
