import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/note_box.dart';
import '../../domain/models/session.dart';
import 'capture_provider.dart';

/// Foto soal dalam bingkai seperti gambar figural di `QuestionBody`.
class PhotoFrame extends StatelessWidget {
  const PhotoFrame({super.key, required this.bytes});

  final Uint8List bytes;

  static const double maxHeight = 320;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: c.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: maxHeight),
          child: Center(
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              semanticLabel: 'Foto soal',
              errorBuilder: (_, __, ___) => const NoteBox(
                icon: AppIcons.alert,
                text: 'Foto tidak bisa ditampilkan. Soal tetap bisa '
                    'dikerjakan dari teks dan opsinya.',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Foto untuk butir rencana: hanya soal Capture yang punya.
Widget? photoForItem(PlanItem item) =>
    item.isCapture ? CapturePhotoView(refId: item.refId!) : null;

/// Foto soal Capture [refId] bila ada. Tidak menampilkan apa-apa untuk soal
/// tanpa foto; foto yang berkasnya hilang (backup dipulihkan di perangkat lain)
/// diganti catatan.
class CapturePhotoView extends ConsumerWidget {
  const CapturePhotoView({super.key, required this.refId});

  final int refId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final question = ref.watch(capturedQuestionProvider(refId)).valueOrNull;
    final name = question?.fotoPath;
    if (name == null || name.isEmpty) return const SizedBox.shrink();
    return ref.watch(capturePhotoProvider(name)).when(
          loading: () => const _PhotoSkeleton(),
          error: (_, __) => const _PhotoMissing(),
          data: (bytes) =>
              bytes == null ? const _PhotoMissing() : PhotoFrame(bytes: bytes),
        );
  }
}

class _PhotoMissing extends StatelessWidget {
  const _PhotoMissing();

  @override
  Widget build(BuildContext context) => const NoteBox(
        icon: AppIcons.image,
        text: 'Foto soal tidak ada di perangkat ini. Foto tidak ikut backup. '
            'Teks dan opsi soal tetap bisa dikerjakan.',
      );
}

class _PhotoSkeleton extends StatelessWidget {
  const _PhotoSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    return Semantics(
      label: 'Memuat foto soal',
      liveRegion: true,
      excludeSemantics: true,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: c.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }
}
