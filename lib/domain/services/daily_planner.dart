import 'package:question_engine/question_engine.dart';

import '../models/profile.dart';
import '../models/session.dart';

/// Bagian rencana latihan harian (docs/03-data-model.md, "Rencana latihan
/// harian"): kelemahan terbesar, kartu buku kesalahan jatuh tempo, atau
/// campuran sesuai bobot profil.
enum PlanBlockKind { weakest, due, mixed }

class PlanBlock {
  const PlanBlock({required this.kind, required this.count, this.type});

  final PlanBlockKind kind;

  /// Jumlah soal bagian ini.
  final int count;

  /// Tipe soal untuk [PlanBlockKind.weakest]; null untuk yang lain.
  final QuestionType? type;
}

/// Rencana latihan hari ini: soal yang akan dikerjakan dan ringkasannya untuk
/// panel di S04.
class DailyPlan {
  const DailyPlan({
    required this.session,
    required this.blocks,
    required this.estimatedMinutes,
  });

  /// Soal berurutan; menjadi `rencana_json` sesi latihan.
  final SessionPlan session;
  final List<PlanBlock> blocks;
  final int estimatedMinutes;
}

/// Satu tipe soal di daftar "Kelemahan saat ini".
class WeaknessEntry {
  const WeaknessEntry({
    required this.type,
    required this.accuracy,
    required this.answered,
  });

  final QuestionType type;

  /// Akurasi 0 sampai 1 yang dipakai skor kelemahan (dihaluskan).
  final double accuracy;

  /// Jumlah jawaban yang dipakai menghitungnya.
  final int answered;
}

/// Menyusun rencana latihan harian. Implementasi nyata di T13; sebelum itu
/// `PlaceholderDailyPlanner` memakai bobot profil tanpa riwayat.
abstract interface class DailyPlanner {
  /// [now] dari `Clock`; seed soal diturunkan darinya, bukan dari jam sistem.
  Future<DailyPlan> plan(TestProfile profile, DateTime now);
}

/// Skor kelemahan per tipe (docs/03-data-model.md). Implementasi nyata di T13.
abstract interface class WeaknessModel {
  /// Tipe dengan kelemahan terbesar, dari yang terlemah. Kosong bila belum ada
  /// riwayat jawaban sama sekali.
  Future<List<WeaknessEntry>> weakest(
    TestProfile profile,
    DateTime now, {
    int count = 3,
  });
}
