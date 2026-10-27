import 'package:question_engine/question_engine.dart';

/// Jalannya satu tes Kraepelin/Pauli (T23, F13). Dart murni: waktu dioper
/// dari jam monoton `Clock.monotonic()` sehingga perubahan jam perangkat
/// tidak menggeser kolom.
///
/// Tiap kolom punya [KrpConfig.secondsPerColumn] detik. Saat waktunya habis
/// tes pindah ke kolom berikutnya walau kolom belum selesai; setelah kolom
/// terakhir tes selesai. Waktu tetap berjalan saat app di latar belakang,
/// seperti tes kertas.
class KraepelinRun {
  KraepelinRun(this.sheet, {required Duration start}) : _columnStart = start;

  final KrpSheet sheet;

  final List<List<int>> _answers = [[]];
  Duration _columnStart;
  var _column = 0;
  var _finished = false;

  Duration get perColumn => Duration(seconds: sheet.config.secondsPerColumn);

  /// Kolom yang sedang dikerjakan, mulai 0.
  int get column => _column;

  bool get finished => _finished;

  /// Isian per kolom yang sudah lewat dan yang berjalan.
  List<List<int>> get answers =>
      List.unmodifiable([for (final a in _answers) List<int>.unmodifiable(a)]);

  /// Pasangan berikutnya di kolom berjalan.
  int get index => _answers[_column].length;

  /// Kolom berjalan sudah terisi semua; tinggal menunggu waktunya habis.
  bool get columnFull => index >= sheet.pairsPerColumn;

  /// Sisa waktu kolom berjalan pada [now].
  Duration remaining(Duration now) {
    if (_finished) return Duration.zero;
    final left = _columnStart + perColumn - now;
    return left.isNegative ? Duration.zero : left;
  }

  /// Memajukan kolom sesuai waktu [now]. Mengembalikan true bila kolom
  /// berganti atau tes selesai.
  bool tick(Duration now) {
    var changed = false;
    while (!_finished && now >= _columnStart + perColumn) {
      changed = true;
      _columnStart += perColumn;
      if (_column == sheet.config.columns - 1) {
        _finished = true;
      } else {
        _column++;
        _answers.add([]);
      }
    }
    return changed;
  }

  /// Mencatat angka [digit] untuk pasangan berikutnya. Diabaikan bila tes
  /// selesai atau kolom penuh.
  void input(int digit, Duration now) {
    RangeError.checkValueInInterval(digit, 0, 9, 'digit');
    tick(now);
    if (_finished || columnFull) return;
    _answers[_column].add(digit);
  }

  /// Mengakhiri tes sekarang; kolom yang belum dimulai dihitung kosong.
  void finish() => _finished = true;

  KrpScore get score => KrpScore.of(sheet, _answers);
}
