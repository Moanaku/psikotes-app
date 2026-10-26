import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/domain/models/question_guides.dart';
import 'package:simulator_psikotes_it/domain/models/session.dart';

void main() {
  group('planItemName untuk soal Capture', () {
    PlanItem capture(String kategori) =>
        PlanItem.capture(refId: 1, kategori: kategori, subtes: 'numerik');

    test('judul diawali huruf kapital seperti judul lain', () {
      expect(planItemName(capture('numerik')), 'Numerik');
      expect(planItemName(capture('lipat kertas')), 'Lipat kertas');
    });

    test('nama yang sudah berkapital tidak berubah; kosong tetap kosong', () {
      expect(planItemName(capture('Deret huruf')), 'Deret huruf');
      expect(planItemName(capture('')), '');
    });
  });
}
