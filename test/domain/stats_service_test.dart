import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:question_engine/question_engine.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/domain/models/session.dart';
import 'package:simulator_psikotes_it/domain/services/stats_service.dart';

/// Kamis 22 Oktober 2026. Semua jam pukul 08.00 UTC agar tanggal setempat
/// sama dengan tanggal UTC di zona waktu mana pun dari UTC-8 sampai UTC+15.
final now = DateTime.utc(2026, 10, 22, 8);

DateTime day(int month, int d) => DateTime.utc(2026, month, d, 8);

SessionRecord session(
  int id,
  DateTime? selesai, {
  SessionMode mode = SessionMode.simulasi,
  double? skor = 70,
}) =>
    SessionRecord(
      id: id,
      profileId: 1,
      mode: mode,
      plan: const SessionPlan(items: []),
      mulai: (selesai ?? now).subtract(const Duration(minutes: 20)),
      selesai: selesai,
      skor: selesai == null ? null : skor,
    );

AnswerRecord answer(
  int sessionId,
  int posisi,
  String kategori, {
  bool benar = true,
  int ms = 30000,
  bool skipped = false,
  AnswerSource sumber = AnswerSource.engine,
}) =>
    AnswerRecord(
      sessionId: sessionId,
      posisi: posisi,
      tipe: 'NUM-SEQ',
      kategori: kategori,
      seed: posisi,
      kesulitan: Difficulty.medium,
      genVersi: 1,
      sumber: sumber,
      refId: sumber == AnswerSource.engine ? null : posisi,
      opsiDipilih: skipped ? null : 0,
      benar: benar && !skipped,
      durasiMs: ms,
      label: SpeedLabel.benarCepat,
    );

/// CSV paling sederhana yang cukup untuk memeriksa hasil `StatsService.csv`
/// (RFC 4180: kutip ganda, koma dan baris baru di dalam kutip).
List<List<String>> parseCsv(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (quoted) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        cell.write(ch);
      }
    } else if (ch == '"') {
      quoted = true;
    } else if (ch == ',') {
      row.add(cell.toString());
      cell.clear();
    } else if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') {
      row.add(cell.toString());
      cell.clear();
      rows.add(row);
      row = [];
      i++;
    } else {
      cell.write(ch);
    }
  }
  expect(quoted, isFalse, reason: 'kutip tidak tertutup');
  expect(cell.isEmpty && row.isEmpty, isTrue,
      reason: 'berkas harus berakhir dengan CRLF');
  return rows;
}

void main() {
  group('periode', () {
    test('weekStart: Senin; monthStart: tanggal 1', () {
      expect(StatsService.weekStart(DateTime(2026, 10, 22)),
          DateTime(2026, 10, 19));
      expect(StatsService.weekStart(DateTime(2026, 10, 19)),
          DateTime(2026, 10, 19));
      expect(StatsService.weekStart(DateTime(2026, 10, 25)),
          DateTime(2026, 10, 19));
      expect(StatsService.weekStart(DateTime(2026, 11, 1)),
          DateTime(2026, 10, 26));
      expect(
          StatsService.monthStart(DateTime(2026, 10, 22)), DateTime(2026, 10));
    });
  });

  group('hari beruntun', () {
    test('berakhir hari ini', () {
      expect(
          StatsService.streak(
              [day(10, 22), day(10, 21), day(10, 20), day(10, 17)], now),
          3);
    });

    test('belum ada sesi hari ini: berakhir kemarin, belum putus', () {
      expect(StatsService.streak([day(10, 21), day(10, 20)], now), 2);
    });

    test('putus bila kemarin dan hari ini kosong', () {
      expect(StatsService.streak([day(10, 20), day(10, 19)], now), 0);
      expect(StatsService.streak(const [], now), 0);
    });

    test('beberapa sesi sehari dihitung satu hari', () {
      expect(
          StatsService.streak([
            day(10, 22),
            day(10, 22).add(const Duration(hours: 1)),
            day(10, 21),
          ], now),
          2);
    });

    test('melintasi batas bulan', () {
      expect(
          StatsService.streak(
              [day(10, 22), day(10, 21), DateTime.utc(2026, 9, 30, 8)], now),
          2);
      expect(
          StatsService.streak([
            DateTime.utc(2026, 11, 1, 8),
            DateTime.utc(2026, 10, 31, 8),
            DateTime.utc(2026, 10, 30, 8),
          ], DateTime.utc(2026, 11, 1, 9)),
          3);
    });
  });

  group('compute mingguan', () {
    // Minggu ini: Senin 19 sampai Minggu 25 Oktober. Minggu lalu: 12 sampai 18.
    final sessions = [
      session(1, day(10, 13), skor: 50), // simulasi, minggu lalu
      session(2, day(10, 20), skor: 60), // simulasi, minggu ini
      session(3, day(10, 21), skor: 80), // simulasi, minggu ini
      session(4, day(10, 22), mode: SessionMode.latihan, skor: 90),
      session(5, null), // belum selesai: diabaikan
      session(6, day(8, 1), skor: 99), // di luar jendela 8 minggu
    ];
    final answers = [
      answer(1, 0, 'numerik', ms: 10000),
      answer(1, 1, 'verbal', benar: false, ms: 20000),
      answer(2, 0, 'numerik', ms: 30000),
      answer(2, 1, 'numerik', benar: false, ms: 50000),
      answer(2, 2, 'logika', skipped: true, ms: 7000),
      answer(3, 0, 'numerik', ms: 60000),
      answer(3, 1, 'figural', ms: 90000),
      answer(4, 0, 'figural', benar: false, ms: 120000),
      answer(5, 0, 'numerik', ms: 999000), // sesi belum selesai
      answer(6, 0, 'verbal', ms: 888000), // sesi di luar jendela
    ];
    late StatsSummary s;
    setUp(() {
      s = StatsService.compute(
        sessions: sessions,
        answers: answers,
        now: now,
        range: StatsRange.mingguan,
      );
    });

    test('tiga angka sama dengan hitungan langsung', () {
      // Menit minggu ini: sesi 2, 3, 4 = 30+50+7+60+90+120 detik = 357 detik.
      expect(s.minutes, (357000 / 60000).round());
      expect(s.sessionsDone, 3);
      expect(s.streakDays, 3, reason: '22, 21, 20 Oktober');
      expect(s.hasSessions, isTrue);
    });

    test('grafik: rata-rata skor simulasi per minggu, latihan tidak ikut', () {
      expect(s.simulations, 3);
      expect(s.trend, hasLength(2));
      expect(s.trend[0].index, 6);
      expect(s.trend[0].start, DateTime(2026, 10, 12));
      expect(s.trend[0].skor, 50);
      expect(s.trend[0].count, 1);
      expect(s.trend[1].index, 7);
      expect(s.trend[1].start, DateTime(2026, 10, 19));
      expect(s.trend[1].skor, 70, reason: '(60 + 80) / 2');
      expect(s.trend[1].count, 2);
    });

    test('delapan periode di jendela, terlama dulu', () {
      expect(s.bucketStarts, hasLength(8));
      expect(s.bucketStarts.first, DateTime(2026, 8, 31));
      expect(s.bucketStarts.last, DateTime(2026, 10, 19));
    });

    test('per kategori: akurasi dan median sama dengan hitungan langsung', () {
      final byName = {for (final k in s.categories) k.kategori: k};
      // numerik: sesi 1, 2, 3 -> 10s b, 30s b, 50s s, 60s b
      expect(byName['numerik']!.jumlah, 4);
      expect(byName['numerik']!.benar, 3);
      expect(byName['numerik']!.akurasi, 75);
      expect(byName['numerik']!.medianMs, (30000 + 50000) ~/ 2);
      // logika: satu soal dilewati dihitung salah, tanpa median.
      expect(byName['logika']!.akurasi, 0);
      expect(byName['logika']!.medianMs, isNull);
      // figural: sesi 3 benar 90s, sesi 4 salah 120s.
      expect(byName['figural']!.akurasi, 50);
      expect(byName['figural']!.medianMs, (90000 + 120000) ~/ 2);
      expect(byName['verbal']!.jumlah, 1,
          reason: 'sesi di luar jendela keluar');
      expect(s.categories.first.kategori, 'numerik',
          reason: 'jumlah soal terbanyak lebih dulu');
    });

    test('sesi belum selesai dan di luar jendela tidak masuk angka apa pun',
        () {
      expect(s.minutes, isNot((357000 + 999000) ~/ 60000));
      expect(s.categories.any((k) => k.jumlah > 4), isFalse);
    });
  });

  group('compute bulanan', () {
    test('periode adalah bulan kalender; enam bulan di jendela', () {
      final sessions = [
        session(1, DateTime.utc(2026, 9, 28, 8), skor: 40),
        session(2, day(10, 2), skor: 60),
        session(3, day(10, 21), skor: 80),
        session(4, DateTime.utc(2026, 3, 1, 8), skor: 10), // lewat 6 bulan
      ];
      final answers = [
        answer(1, 0, 'numerik', ms: 60000),
        answer(2, 0, 'numerik', ms: 120000),
        answer(3, 0, 'numerik', ms: 180000),
        answer(4, 0, 'numerik', ms: 600000),
      ];
      final s = StatsService.compute(
        sessions: sessions,
        answers: answers,
        now: now,
        range: StatsRange.bulanan,
      );
      expect(s.bucketStarts, hasLength(6));
      expect(s.bucketStarts.first, DateTime(2026, 5));
      expect(s.bucketStarts.last, DateTime(2026, 10));
      expect(s.minutes, 5, reason: '2 + 3 menit di Oktober');
      expect(s.sessionsDone, 2);
      expect(s.trend.map((p) => p.index), [4, 5]);
      expect(s.trend.map((p) => p.skor), [40, 70]);
      expect(s.categories.single.jumlah, 3);
      expect(s.simulations, 3);
    });
  });

  group('kondisi tepi', () {
    test('tanpa sesi: hasSessions false', () {
      final s = StatsService.compute(
        sessions: const [],
        answers: const [],
        now: now,
        range: StatsRange.mingguan,
      );
      expect(s.hasSessions, isFalse);
      expect(s.trend, isEmpty);
      expect(s.categories, isEmpty);
      expect((s.minutes, s.sessionsDone, s.streakDays), (0, 0, 0));
    });

    test('satu simulasi: satu titik', () {
      final s = StatsService.compute(
        sessions: [session(1, day(10, 21), skor: 66.6)],
        answers: [answer(1, 0, 'numerik')],
        now: now,
        range: StatsRange.mingguan,
      );
      expect(s.trend, hasLength(1));
      expect(s.trend.single.skor, 66.6);
      expect(s.simulations, 1);
    });

    test('hanya latihan: ada sesi tetapi tanpa titik grafik', () {
      final s = StatsService.compute(
        sessions: [session(1, day(10, 21), mode: SessionMode.latihan)],
        answers: [answer(1, 0, 'numerik')],
        now: now,
        range: StatsRange.mingguan,
      );
      expect(s.hasSessions, isTrue);
      expect(s.trend, isEmpty);
      expect(s.simulations, 0);
      expect(s.categories, hasLength(1));
    });

    test('dua simulasi di satu minggu: satu titik, dua simulasi', () {
      final s = StatsService.compute(
        sessions: [
          session(1, day(10, 20), skor: 40),
          session(2, day(10, 21), skor: 60),
        ],
        answers: const [],
        now: now,
        range: StatsRange.mingguan,
      );
      expect(s.trend, hasLength(1));
      expect(s.simulations, 2);
      expect(s.trend.single.skor, 50);
    });
  });

  group('CSV', () {
    final sessions = [
      session(2, day(10, 21), mode: SessionMode.latihan, skor: 50),
      session(1, day(10, 20), skor: 66.66),
      session(3, null),
    ];
    final answers = [
      answer(1, 0, 'numerik', ms: 10000),
      answer(1, 1, 'numerik', benar: false, ms: 21000),
      answer(1, 2, 'figural', ms: 5000),
      answer(2, 0, 'verbal', skipped: true),
      answer(3, 0, 'numerik'),
    ];

    test('kolom sesuai spek, koma, CRLF, satu baris per sesi dan kategori', () {
      final text = StatsService.csv(sessions: sessions, answers: answers);
      expect(text.endsWith('\r\n'), isTrue);
      expect(text.split('\r\n').first,
          'tanggal,mode,skor,kategori,akurasi,median detik');
      final rows = parseCsv(text);
      expect(rows, hasLength(1 + 3));
      expect(rows.every((r) => r.length == 6), isTrue);
      // Urut menurut waktu selesai, lalu kategori.
      expect(rows[1],
          ['2026-10-20', 'simulasi', '66.7', 'figural', '100.0', '5.0']);
      expect(rows[2],
          ['2026-10-20', 'simulasi', '66.7', 'numerik', '50.0', '15.5']);
      expect(rows[3], ['2026-10-21', 'latihan', '50.0', 'verbal', '0.0', '']);
    });

    test('angka sama dengan agregasi langsung', () {
      final rows =
          parseCsv(StatsService.csv(sessions: sessions, answers: answers))
              .skip(1);
      final numerik = rows.firstWhere((r) => r[3] == 'numerik');
      final summary = StatsService.compute(
        sessions: sessions,
        answers: answers,
        now: now,
        range: StatsRange.mingguan,
      );
      final stat =
          summary.categories.firstWhere((k) => k.kategori == 'numerik');
      expect(double.parse(numerik[4]), closeTo(stat.akurasi, 0.05));
      expect(double.parse(numerik[5]) * 1000, closeTo(stat.medianMs!, 50));
    });

    test('sesi belum selesai tidak ikut', () {
      final rows =
          parseCsv(StatsService.csv(sessions: sessions, answers: answers));
      expect(rows.expand((r) => r), isNot(contains('2026-10-22')));
      expect(rows.length, 4);
    });

    test('jawaban Capture tidak masuk ekspor', () {
      final rows = parseCsv(StatsService.csv(
        sessions: [session(1, day(10, 20))],
        answers: [
          answer(1, 0, 'numerik'),
          answer(1, 1, 'tes-pt-rahasia', sumber: AnswerSource.capture),
        ],
      ));
      expect(rows, hasLength(2));
      expect(rows.expand((r) => r).join(), isNot(contains('rahasia')));
    });

    test('sel dengan koma, kutip, dan baris baru diberi kutip', () {
      final text = StatsService.csv(
        sessions: [session(1, day(10, 20))],
        answers: [answer(1, 0, 'a,b "c"\nd')],
      );
      final rows = parseCsv(text);
      expect(rows[1][3], 'a,b "c"\nd');
      expect(rows[1], hasLength(6));
    });

    test('UTF-8: teks non-ASCII bertahan lewat encode dan decode', () {
      final text = StatsService.csv(
        sessions: [session(1, day(10, 20))],
        answers: [answer(1, 0, 'tipe baru é')],
      );
      expect(utf8.decode(utf8.encode(text)), text);
      expect(parseCsv(text)[1][3], 'tipe baru é');
    });

    test('tanpa sesi: hanya baris judul', () {
      expect(StatsService.csv(sessions: const [], answers: const []),
          'tanggal,mode,skor,kategori,akurasi,median detik\r\n');
    });
  });

  test('QuestionType dipakai hanya untuk kategori yang dikenal', () {
    // Pengaman: kategori di statistik adalah kode kategori engine.
    expect(QuestionType.numSeq.category.code, 'numerik');
  });
}
