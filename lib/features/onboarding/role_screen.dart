import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/choice_row.dart';
import '../../domain/services/profile_templates.dart';
import 'onboarding_draft.dart';
import 'onboarding_frame.dart';

/// S01 Pilih role (F01). Satu pilihan aktif; QA Engineer sudah terpilih,
/// jadi "Lanjut" selalu aktif.
class RoleScreen extends ConsumerStatefulWidget {
  const RoleScreen({super.key});

  @override
  ConsumerState<RoleScreen> createState() => _RoleScreenState();
}

class _RoleScreenState extends ConsumerState<RoleScreen> {
  @override
  void initState() {
    super.initState();
    // Sisa mode ubah profil yang ditinggalkan tidak boleh terbawa ke profil baru.
    Future.microtask(() {
      if (!mounted) return;
      if (ref.read(onboardingDraftProvider).editing) {
        ref.read(onboardingDraftProvider.notifier).reset();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    final role = ref.watch(onboardingDraftProvider.select((d) => d.role));
    final notifier = ref.read(onboardingDraftProvider.notifier);

    return OnboardingFrame(
      header: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.topBarHeight),
        child: Align(
          alignment: Alignment.centerLeft,
          child: ScreenPadding(
            child: Text('Langkah 1 dari 3', style: AppType.label(c.inkMuted)),
          ),
        ),
      ),
      footer: AppButton(
        label: 'Lanjut',
        onPressed: () => context.go(Routes.onboardingProfil),
      ),
      children: [
        ScreenPadding(
          child: Semantics(
            header: true,
            child: Text(
              'Kamu melamar sebagai apa?',
              style: AppType.headline(c.ink),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.s8),
        ScreenPadding(
          child: Text(
            'Latihan, simulasi, dan wawancara disusun dari role dan tes yang '
            'akan kamu hadapi.',
            style: AppType.body(c.inkMuted),
          ),
        ),
        const SizedBox(height: AppSpace.s16),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: c.outlineVariant)),
          ),
          child: Column(
            children: [
              for (final r in ProfileTemplates.roles)
                ChoiceRow(
                  title: ProfileTemplates.roleName(r),
                  subtitle: ProfileTemplates.roleHint(r),
                  selected: r == role,
                  onTap: () => notifier.selectRole(r),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.s12),
        ScreenPadding(
          child: Text(
            'Bisa membuat lebih dari satu profil nanti.',
            style: AppType.label(c.inkMuted),
          ),
        ),
      ],
    );
  }
}
