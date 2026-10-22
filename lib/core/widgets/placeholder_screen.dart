import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Penanda sementara sampai layar nyata dibangun. Dihapus bertahap per tugas.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.id, required this.title});

  final String id;
  final String title;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(id, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: AppSpace.s4),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpace.s8),
              Text(
                'Layar ini belum dibangun. Spesifikasi: docs/05-spek-layar.md',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: t.colors.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
