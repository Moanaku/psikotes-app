import 'package:question_engine/question_engine.dart';

import '../models/session.dart';
import 'seed_allocator.dart';
import 'session_plan_builder.dart';
import 'verbal_bank.dart';

/// Membagikan butir rencana untuk satu rencana: soal engine lewat
/// [SeedAllocator], soal bank lewat [VerbalBank.pick]. Pasangan yang sudah
/// muncul 30 hari terakhir ([avoid]) dan yang sudah dibagikan di rencana yang
/// sama tidak dibagikan lagi (A65), untuk engine berupa (tipe, seed) dan untuk
/// bank berupa (tipe, nomor butir).
class ItemAllocator {
  ItemAllocator(int base, {Iterable<String> avoid = const [], this.bank})
      : _seeds = SeedAllocator(base, avoid: avoid),
        _taken = {...avoid};

  final VerbalBank? bank;
  final SeedAllocator _seeds;
  final Set<String> _taken;

  /// Apakah [type] dikerjakan dari bank pada alokator ini.
  bool fromBank(QuestionType type) =>
      VerbalBank.bankTypes.contains(type) && (bank?.has(type) ?? false);

  PlanItem next(
    QuestionType type,
    Difficulty difficulty, {
    String? subtes,
    int? cardId,
  }) {
    final seed = _seeds.next(type);
    if (!fromBank(type)) {
      return SessionPlanBuilder.item(
        type,
        seed,
        difficulty,
        subtes: subtes,
        cardId: cardId,
      );
    }
    final picked = bank!.pick(type, difficulty, seed, avoid: _taken)!;
    _taken.add(VerbalBank.keyOf(type.code, picked.number));
    return PlanItem.bank(
      type: type,
      refId: picked.number,
      seed: seed,
      difficulty: picked.difficulty,
      genVersi: bank!.versi,
      subtes: subtes ?? type.category.code,
      cardId: cardId,
    );
  }
}
