import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/domain/models/notebook.dart';
import 'package:simulator_psikotes_it/domain/services/capture_form.dart';
import 'package:simulator_psikotes_it/domain/services/company_log_form.dart';

final DateTime now = DateTime.utc(2026, 10, 22, 8);

CaptureDraft valid({
  String teks = 'Berapa 2 + 2?',
  List<String> opsi = const ['3', '4', '5', ''],
  int? kunci = 1,
  String kategori = 'numerik',
  String? foto,
}) =>
    CaptureDraft(
      teks: teks,
      opsi: opsi,
      kunciSlot: kunci,
      kategori: kategori,
      fotoPath: foto,
    );

void main() {
  group('CaptureDraft.validate', () {
    test('formulir sah tanpa galat', () {
      expect(valid().validate().any, isFalse);
    });

    test('teks atau foto wajib salah satu', () {
      expect(valid(teks: '  ').validate().soal,
          'Isi teks soal atau tambahkan foto soal.');
      expect(valid(teks: '', foto: 'a.jpg').validate().soal, isNull,
          reason: 'foto saja cukup');
    });

    test('minimal dua opsi terisi', () {
      final e = valid(opsi: ['3', ' ', '', ''], kunci: 0).validate();
      expect(e.opsi, 'Isi minimal 2 opsi jawaban.');
    });

    test('kunci wajib dipilih: pesan dari spek', () {
      expect(
        valid(kunci: null).validate().kunci,
        'Kunci jawaban belum dipilih. Pilih lingkaran di kiri opsi yang '
        'benar.',
      );
    });

    test('kunci wajib menunjuk opsi yang terisi', () {
      expect(valid(kunci: 3).validate().kunci, contains('masih kosong'));
    });

    test('kategori wajib', () {
      expect(valid(kategori: ' ').validate().kategori, isNotNull);
    });
  });

  group('CaptureDraft.build', () {
    test('null bila belum sah', () {
      expect(valid(kunci: null).build(now: now), isNull);
    });

    test('slot kosong dibuang dan kunci dipetakan ke indeks baru', () {
      final q =
          valid(opsi: ['', 'A', '', 'C', 'D', ''], kunci: 3).build(now: now)!;
      expect(q.opsi, ['A', 'C', 'D']);
      expect(q.kunci, 1, reason: 'opsi C kini di indeks 1');
      expect(q.validate(), isEmpty);
    });

    test('teks dan opsi dirapikan, pembahasan kosong menjadi null', () {
      final q = valid(teks: '  Soal  ', opsi: [' 3 ', '4', '', ''])
          .copyWith(pembahasan: '  ')
          .build(now: now, id: 7)!;
      expect(q.teks, 'Soal');
      expect(q.opsi, ['3', '4']);
      expect(q.pembahasan, isNull);
      expect(q.id, 7);
      expect(q.dibuat, now);
    });

    test('mengubah soal mempertahankan waktu dibuat', () {
      final created = DateTime.utc(2026, 9, 1);
      final q = valid().build(now: now, id: 3, dibuat: created)!;
      expect(q.dibuat, created);
    });

    test('soal hanya foto sah', () {
      final q = valid(teks: '', foto: 'a.jpg').build(now: now)!;
      expect(q.teks, '');
      expect(q.fotoPath, 'a.jpg');
      expect(q.validate(), isEmpty);
    });

    test('from() mengisi slot sampai empat dan membawa kunci', () {
      final q = CapturedQuestion(
        id: 1,
        teks: 'T',
        opsi: const ['a', 'b'],
        kunci: 1,
        kategori: 'lipat kertas',
        dibuat: now,
      );
      final d = CaptureDraft.from(q);
      expect(d.opsi, ['a', 'b', '', '']);
      expect(d.kunciSlot, 1);
      expect(d.kategori, 'lipat kertas');
    });
  });

  group('CompanyLogDraft', () {
    test('perusahaan dan tanggal wajib; pesan menyebut perbaikannya', () {
      final e = const CompanyLogDraft().validate();
      expect(e.perusahaan, contains('nama perusahaan'));
      expect(e.tanggal, contains('hh/bb/tttt'));
      expect(
        const CompanyLogDraft(perusahaan: 'PT A', tanggal: '31/02/2026')
            .validate()
            .tanggal,
        isNotNull,
        reason: '31 Februari bukan tanggal',
      );
    });

    test('tag tipe baru dirapikan, tanpa kembar, dipisah koma atau baris', () {
      const d = CompanyLogDraft(
        tipeBaru: ' Lipat  kertas, rotasi kubus\nlipat kertas ,, ',
      );
      expect(d.tags, ['Lipat kertas', 'rotasi kubus']);
    });

    test('build menghasilkan catatan sah', () {
      final log = const CompanyLogDraft(
        perusahaan: ' PT Maju ',
        tanggal: '22/10/2026',
        subtes: ['verbal'],
        tipeBaru: 'lipat kertas',
        catatan: ' sulit ',
      ).build(id: 4)!;
      expect(log.id, 4);
      expect(log.perusahaan, 'PT Maju');
      expect(log.tanggal, DateTime.utc(2026, 10, 22));
      expect(log.tipeBaru, ['lipat kertas']);
      expect(log.catatan, 'sulit');
    });
  });

  group('NoteSuggestions', () {
    CompanyTestLog log(int id, List<String> tags, DateTime date) =>
        CompanyTestLog(
          id: id,
          perusahaan: 'PT $id',
          tanggal: date,
          tipeBaru: tags,
        );
    CapturedQuestion cap(String kategori) => CapturedQuestion(
          id: 1,
          teks: 'T',
          opsi: const ['a', 'b'],
          kunci: 0,
          kategori: kategori,
          dibuat: now,
        );

    test('tipe baru tanpa soal Capture menjadi saran, huruf besar diabaikan',
        () {
      final s = NoteSuggestions.pending(
        [
          log(1, ['Lipat kertas', 'rotasi kubus'], DateTime.utc(2026, 9, 1)),
        ],
        [cap('lipat  KERTAS')],
      );
      expect(s.map((x) => x.tipe), ['rotasi kubus']);
      expect(s.single.logId, 1);
    });

    test('satu saran per tipe, dari catatan terbaru', () {
      final s = NoteSuggestions.pending(
        [
          log(1, ['lipat kertas'], DateTime.utc(2026, 8, 1)),
          log(2, ['Lipat kertas'], DateTime.utc(2026, 9, 1)),
        ],
        const [],
      );
      expect(s, hasLength(1));
      expect(s.single.logId, 2);
    });

    test('semua tertutup: tidak ada saran tetapi ada tag', () {
      final logs = [
        log(1, ['x'], DateTime.utc(2026, 9, 1))
      ];
      expect(NoteSuggestions.pending(logs, [cap('x')]), isEmpty);
      expect(NoteSuggestions.hasTags(logs), isTrue);
      expect(NoteSuggestions.hasTags([log(2, [], now)]), isFalse);
    });
  });
}
