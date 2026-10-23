import '../models/codes.dart';
import '../models/session.dart';
import 'scoring.dart';

/// Rentang statistik di S11 (segmen Mingguan atau Bulanan).
enum StatsRange {
  mingguan('Mingguan', 8),
  bulanan('Bulanan', 6);

  const StatsRange(this.label, this.buckets);
  final String label;

  /// Jumlah periode di grafik, termasuk periode sekarang.
  final int buckets;
}

/// Satu titik grafik: rata-rata skor simulasi yang selesai di satu periode.
class TrendPoint {
  const TrendPoint({
    required this.index,
    required this.start,
    required this.skor,
    required this.count,
  });

  /// Posisi periode di grafik, 0 sampai `buckets - 1` (terlama dulu).
  final int index;

  /// Awal periode, tanggal setempat.
  final DateTime start;

  /// Persen, 0 sampai 100.
  final double skor;

  /// Jumlah simulasi di periode ini.
  final int count;
}

class CategoryStat {
  const CategoryStat({
    required this.kategori,
    required this.benar,
    required this.jumlah,
    this.medianMs,
  });

  final String kategori;
  final int benar;
  final int jumlah;

  /// Median `durasi_ms` soal yang dijawab; null bila tidak ada.
  final int? medianMs;

  double get akurasi => jumlah == 0 ? 0 : benar * 100.0 / jumlah;
}

/// Isi S11. Tanpa I/O.
class StatsSummary {
  const StatsSummary({
    required this.range,
    required this.hasSessions,
    required this.minutes,
    required this.sessionsDone,
    required this.streakDays,
    required this.trend,
    required this.simulations,
    required this.bucketStarts,
    required this.categories,
  });

  final StatsRange range;

  /// Ada sesi yang sudah selesai (di mana pun, bukan hanya di rentang).
  final bool hasSessions;

  /// Menit mengerjakan di periode sekarang (minggu atau bulan kalender).
  final int minutes;

  /// Sesi selesai di periode sekarang.
  final int sessionsDone;

  /// Hari kalender berturut-turut dengan sedikitnya satu sesi selesai,
  /// berakhir hari ini atau kemarin.
  final int streakDays;

  /// Periode yang punya simulasi, terlama dulu.
  final List<TrendPoint> trend;

  /// Jumlah simulasi di seluruh jendela grafik.
  final int simulations;

  /// Awal tiap periode di jendela grafik, terlama dulu.
  final List<DateTime> bucketStarts;

  /// Akurasi dan median per kategori di jendela grafik, urut menurut jumlah
  /// soal terbanyak lalu nama.
  final List<CategoryStat> categories;
}

/// Agregasi statistik (F08, S11) dan ekspor CSV. Fungsi murni; semua tanggal
/// dibaca dalam waktu setempat.
abstract final class StatsService {
  static DateTime _day(DateTime utc) {
    final l = utc.toLocal();
    return DateTime(l.year, l.month, l.day);
  }

  /// Senin minggu tanggal [day].
  static DateTime weekStart(DateTime day) =>
      DateTime(day.year, day.month, day.day - (day.weekday - 1));

  static DateTime monthStart(DateTime day) => DateTime(day.year, day.month);

  static DateTime _periodStart(StatsRange range, DateTime day) =>
      range == StatsRange.mingguan ? weekStart(day) : monthStart(day);

  /// Awal periode ke-[i] (0 = terlama) di jendela yang berakhir di periode
  /// sekarang.
  static DateTime _bucketStart(StatsRange range, DateTime current, int i) {
    final back = range.buckets - 1 - i;
    return range == StatsRange.mingguan
        ? DateTime(current.year, current.month, current.day - 7 * back)
        : DateTime(current.year, current.month - back);
  }

  /// Hari beruntun: dihitung mundur dari hari ini; bila hari ini belum ada
  /// sesi, dari kemarin (hari ini masih bisa menyelamatkannya).
  static int streak(Iterable<DateTime> finishedUtc, DateTime now) {
    final days = {for (final d in finishedUtc) _day(d)};
    final today = _day(now);
    var cursor = days.contains(today)
        ? today
        : DateTime(today.year, today.month, today.day - 1);
    var n = 0;
    while (days.contains(cursor)) {
      n++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    return n;
  }

  static StatsSummary compute({
    required List<SessionRecord> sessions,
    required List<AnswerRecord> answers,
    required DateTime now,
    required StatsRange range,
  }) {
    final done = [
      for (final s in sessions)
        if (s.selesai != null) s,
    ];
    final byId = {for (final s in done) s.id: s};
    final today = _day(now);
    final current = _periodStart(range, today);
    final starts = [
      for (var i = 0; i < range.buckets; i++) _bucketStart(range, current, i),
    ];
    final windowStart = starts.first;

    bool inWindow(SessionRecord s) => !_day(s.selesai!).isBefore(windowStart);
    bool inCurrent(SessionRecord s) => !_day(s.selesai!).isBefore(current);

    final currentSessions = done.where(inCurrent).toList();
    final minutes = answers.where((a) {
          final s = byId[a.sessionId];
          return s != null && inCurrent(s);
        }).fold<int>(0, (sum, a) => sum + a.durasiMs) /
        60000;

    // Rata-rata skor simulasi per periode.
    final scores = <int, List<double>>{};
    var simulations = 0;
    for (final s in done) {
      if (s.mode != SessionMode.simulasi || s.skor == null || !inWindow(s)) {
        continue;
      }
      simulations++;
      final day = _day(s.selesai!);
      var index = 0;
      for (var i = 0; i < starts.length; i++) {
        if (!day.isBefore(starts[i])) index = i;
      }
      (scores[index] ??= []).add(s.skor!);
    }
    final trend = [
      for (final e
          in (scores.entries.toList()..sort((a, b) => a.key.compareTo(b.key))))
        TrendPoint(
          index: e.key,
          start: starts[e.key],
          skor: e.value.reduce((a, b) => a + b) / e.value.length,
          count: e.value.length,
        ),
    ];

    // Per kategori di jendela grafik; soal dilewati dihitung salah (sama
    // dengan S08).
    final benar = <String, int>{};
    final jumlah = <String, int>{};
    final durasi = <String, List<int>>{};
    for (final a in answers) {
      final s = byId[a.sessionId];
      if (s == null || !inWindow(s)) continue;
      jumlah[a.kategori] = (jumlah[a.kategori] ?? 0) + 1;
      if (a.benar) benar[a.kategori] = (benar[a.kategori] ?? 0) + 1;
      if (a.opsiDipilih != null) (durasi[a.kategori] ??= []).add(a.durasiMs);
    }
    final categories = [
      for (final k in jumlah.keys)
        CategoryStat(
          kategori: k,
          benar: benar[k] ?? 0,
          jumlah: jumlah[k]!,
          medianMs: Scoring.median(durasi[k] ?? const []),
        ),
    ]..sort((a, b) {
        final byCount = b.jumlah.compareTo(a.jumlah);
        return byCount != 0 ? byCount : a.kategori.compareTo(b.kategori);
      });

    return StatsSummary(
      range: range,
      hasSessions: done.isNotEmpty,
      minutes: minutes.round(),
      sessionsDone: currentSessions.length,
      streakDays: streak(done.map((s) => s.selesai!), now),
      trend: trend,
      simulations: simulations,
      bucketStarts: starts,
      categories: categories,
    );
  }

  /// Kolom CSV, sesuai docs/05-spek-layar.md (S11).
  static const List<String> csvHeader = [
    'tanggal',
    'mode',
    'skor',
    'kategori',
    'akurasi',
    'median detik',
  ];

  /// CSV semua sesi selesai: satu baris per sesi dan kategori. Pemisah koma,
  /// akhir baris CRLF, desimal titik, teks UTF-8 (RFC 4180). Hanya agregat;
  /// jawaban soal Capture tidak ikut karena kategorinya buatan pengguna dan
  /// bisa memuat nama perusahaan.
  static String csv({
    required List<SessionRecord> sessions,
    required List<AnswerRecord> answers,
  }) {
    final bySession = <int, List<AnswerRecord>>{};
    for (final a in answers) {
      if (a.sumber == AnswerSource.capture) continue;
      (bySession[a.sessionId] ??= []).add(a);
    }
    final rows = <List<String>>[csvHeader];
    final done = [
      for (final s in sessions)
        if (s.selesai != null) s,
    ]..sort((a, b) {
        final byDate = a.selesai!.compareTo(b.selesai!);
        return byDate != 0 ? byDate : a.id.compareTo(b.id);
      });
    for (final s in done) {
      final list = bySession[s.id] ?? const <AnswerRecord>[];
      final benar = <String, int>{};
      final jumlah = <String, int>{};
      final durasi = <String, List<int>>{};
      for (final a in list) {
        jumlah[a.kategori] = (jumlah[a.kategori] ?? 0) + 1;
        if (a.benar) benar[a.kategori] = (benar[a.kategori] ?? 0) + 1;
        if (a.opsiDipilih != null) (durasi[a.kategori] ??= []).add(a.durasiMs);
      }
      final date = _isoDay(_day(s.selesai!));
      final skor = (s.skor ?? 0).toStringAsFixed(1);
      for (final k in jumlah.keys.toList()..sort()) {
        final median = Scoring.median(durasi[k] ?? const []);
        rows.add([
          date,
          s.mode.code,
          skor,
          k,
          ((benar[k] ?? 0) * 100.0 / jumlah[k]!).toStringAsFixed(1),
          median == null ? '' : (median / 1000).toStringAsFixed(1),
        ]);
      }
    }
    return '${rows.map((r) => r.map(_cell).join(',')).join('\r\n')}\r\n';
  }

  static String _isoDay(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String _cell(String v) =>
      v.contains(RegExp(r'[",\r\n]')) ? '"${v.replaceAll('"', '""')}"' : v;
}
