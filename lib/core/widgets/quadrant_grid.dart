import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_tokens.dart';

class QuadrantCell {
  const QuadrantCell({
    required this.title,
    required this.count,
    required this.correct,
    this.note,
  });

  /// Mis. "Benar dan cepat".
  final String title;
  final int count;

  /// Benar: `okContainer` dan ikon centang. Salah: `badContainer` dan ikon silang.
  final bool correct;

  /// Mis. "Terburu-buru" atau "Belum paham pola".
  final String? note;
}

/// Kisi 2 x 2 kecepatan lawan ketepatan. Urutan sel: kiri atas, kanan atas,
/// kiri bawah, kanan bawah. Tiap sel punya ikon dan teks, bukan warna saja.
class QuadrantGrid extends StatelessWidget {
  const QuadrantGrid({super.key, required this.cells});

  final List<QuadrantCell> cells;

  @override
  Widget build(BuildContext context) {
    assert(cells.length == 4, 'QuadrantGrid selalu empat sel.');
    Widget row(int a) => IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _Cell(cell: cells[a])),
              const SizedBox(width: AppSpace.s8),
              Expanded(child: _Cell(cell: cells[a + 1])),
            ],
          ),
        );
    return Column(
      children: [row(0), const SizedBox(height: AppSpace.s8), row(2)],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.cell});

  final QuadrantCell cell;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.colors;
    final fg = cell.correct ? c.ok : c.bad;
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.all(AppSpace.s12),
        decoration: BoxDecoration(
          color: cell.correct ? c.okContainer : c.badContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${cell.count}', style: AppType.headline(fg)),
            const SizedBox(height: AppSpace.s8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Icon(
                    cell.correct ? AppIcons.check : AppIcons.close,
                    size: AppSizes.iconInText,
                    color: fg,
                  ),
                ),
                const SizedBox(width: AppSpace.s4),
                Expanded(
                  child: Text(
                    cell.title,
                    style:
                        AppType.label(fg).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (cell.note != null) ...[
              const SizedBox(height: AppSpace.s4),
              Text(cell.note!, style: AppType.label(fg)),
            ],
          ],
        ),
      ),
    );
  }
}
