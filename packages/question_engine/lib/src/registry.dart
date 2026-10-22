/// Daftar generator dan solver menurut tipe soal. Tipe baru didaftarkan di
/// sini oleh tugas yang membuatnya.
library;

import 'generator.dart';
import 'generators/figural/fig_mir.dart';
import 'generators/figural/fig_mtx.dart';
import 'generators/figural/fig_mtx_solver.dart';
import 'generators/figural/fig_odd.dart';
import 'generators/figural/fig_seq.dart';
import 'generators/figural/fig_seq_solver.dart';
import 'models.dart';

final class RegisteredType {
  const RegisteredType(this.generator, this.solver);

  final QuestionGenerator generator;
  final QuestionSolver solver;
}

abstract final class GeneratorRegistry {
  static const Map<QuestionType, RegisteredType> _entries = {
    QuestionType.figMtx: RegisteredType(FigMtxGenerator(), FigMtxSolver()),
    QuestionType.figMir: RegisteredType(FigMirGenerator(), FigMirSolver()),
    QuestionType.figSeq: RegisteredType(FigSeqGenerator(), FigSeqSolver()),
    QuestionType.figOdd: RegisteredType(FigOddGenerator(), FigOddSolver()),
  };

  static List<QuestionType> get types => _entries.keys.toList();

  static bool has(QuestionType type) => _entries.containsKey(type);

  static QuestionGenerator generator(QuestionType type) =>
      _entry(type).generator;

  static QuestionSolver solver(QuestionType type) => _entry(type).solver;

  static Question generate(QuestionType type, int seed, Difficulty d) =>
      generator(type).generate(seed, d);

  static RegisteredType _entry(QuestionType type) =>
      _entries[type] ??
      (throw ArgumentError.value(type.code, 'type', 'belum terdaftar'));
}
