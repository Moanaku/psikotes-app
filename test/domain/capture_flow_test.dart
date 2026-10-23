import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:simulator_psikotes_it/data/repositories/capture_repository.dart';
import 'package:simulator_psikotes_it/data/repositories/mistake_repository.dart';
import 'package:simulator_psikotes_it/domain/models/codes.dart';
import 'package:simulator_psikotes_it/domain/models/session.dart';
import 'package:simulator_psikotes_it/domain/services/capture_form.dart';
import 'package:simulator_psikotes_it/domain/services/capture_service.dart';
import 'package:simulator_psikotes_it/domain/services/review_planner.dart';
import 'package:simulator_psikotes_it/domain/services/session_plan_builder.dart';
import 'package:question_engine/question_engine.dart';

import '../support/fake_repositories.dart';
import 'session_harness.dart';

CaptureDraft draft({String kategori = 'lipat kertas', int kunci = 1}) =>
    CaptureDraft(
      teks: 'Kertas dilipat dua kali lalu dilubangi. Berapa lubangnya?',
      opsi: const ['2', '4', '8', ''],
      kunciSlot: kunci,
      kategori: kategori,
      pembahasan: 'Tiap lipatan menggandakan lubang.',
    );

void main() {
  late Harness h;
  late DriftCaptureRepository captures;
  late DriftMistakeRepository mistakes;
  late MemoryPhotoStore photos;
  late CaptureService service;

  setUp(() {
    h = Harness();
    captures = DriftCaptureRepository(h.db);
    mistakes = DriftMistakeRepository(h.db);
    photos = MemoryPhotoStore();
    service = CaptureService(captures, photos);
  });

  tearDown(() => h.dispose());

  test('simpan, kerjakan di sesi latihan, salah masuk buku kesalahan',
      () async {
    final id = await service.save(draft: draft(), now: h.clock.now());
    final saved = (await captures.byId(id))!;
    expect(saved.opsi, ['2', '4', '8']);
    expect(saved.kunci, 1);

    final plan = SessionPlanBuilder.capture([saved], now: h.clock.now());
    await h.start(SessionMode.latihan, plan);
    expect(h.s.question!.stem.text, contains('dilubangi'));
    expect(h.s.question!.correctIndex, 1);

    await h.c.select(0);
    await h.c.submit();
    expect(h.s.feedback!.benar, isFalse);
    await h.c.next();
    expect(h.s.finished, isTrue);

    final answers = await h.answers(h.s.sessionId);
    final a = answers[0]!;
    expect(a.sumber, AnswerSource.capture);
    expect(a.refId, id);
    expect(a.tipe, PlanItem.captureTipe);
    expect(a.kategori, 'lipat kertas');
    expect(a.benar, isFalse);

    final cards = await mistakes.watchAll().first;
    expect(cards, hasLength(1));
    expect(cards.single.sumber, AnswerSource.capture);
    expect(cards.single.refId, id);
    expect(cards.single.seed, isNull);
    expect(cards.single.kategori, 'lipat kertas');
    expect(cards.single.streakBenar, 0);
  });

  test('jawaban benar tidak membuat kartu', () async {
    final id = await service.save(draft: draft(), now: h.clock.now());
    final plan = SessionPlanBuilder.capture(
      [(await captures.byId(id))!],
      now: h.clock.now(),
    );
    await h.start(SessionMode.latihan, plan);
    await h.c.select(h.rightOption());
    await h.c.submit();
    await h.c.next();
    expect(await mistakes.watchAll().first, isEmpty);
  });

  test('ulangan kartu Capture memakai butir yang sama dan menjadwal ulang',
      () async {
    final id = await service.save(draft: draft(), now: h.clock.now());
    final saved = (await captures.byId(id))!;
    await h.start(SessionMode.latihan,
        SessionPlanBuilder.capture([saved], now: h.clock.now()));
    await h.c.select(0);
    await h.c.submit();
    await h.c.next();
    final card = (await mistakes.watchAll().first).single;

    h.clock.advance(const Duration(days: 2));
    final review = ReviewPlanner.build(
      [card],
      now: h.clock.now(),
      available: GeneratorRegistry.types.toSet(),
    );
    final item = review.plan.items.single;
    expect(item.isCapture, isTrue);
    expect(item.refId, id);
    expect(item.cardId, card.id);

    await h.start(SessionMode.latihan, review.plan);
    expect(h.s.question!.stem.text, saved.teks, reason: 'butir yang sama');
    await h.c.select(h.rightOption());
    await h.c.submit();
    await h.c.next();

    final after = (await mistakes.byId(card.id))!;
    expect(after.streakBenar, 1);
    expect(after.intervalHari, 3);
    expect(await mistakes.watchAll().first, hasLength(1),
        reason: 'ulangan tidak membuat kartu baru');
  });

  test('soal Capture yang dihapus di tengah rencana bisa dilewati', () async {
    final id = await service.save(draft: draft(), now: h.clock.now());
    final plan = SessionPlanBuilder.capture(
      [(await captures.byId(id))!],
      now: h.clock.now(),
    );
    await service.delete(id);
    await h.start(SessionMode.latihan, plan);
    expect(h.s.question, isNull);
    expect(h.s.questionFailed, isTrue);
    await h.c.next();
    expect(h.s.finished, isTrue);
  });

  group('CaptureService', () {
    final bytes = Uint8List.fromList([1, 2, 3]);

    test('foto disimpan lewat penyimpanan lokal; database hanya memuat nama',
        () async {
      final id = await service.save(
        draft: draft(),
        now: h.clock.now(),
        newPhoto: bytes,
      );
      final saved = (await captures.byId(id))!;
      expect(saved.fotoPath, isNotNull);
      expect(saved.fotoPath, isNot(contains('/')));
      expect(photos.files[saved.fotoPath], bytes);
      expect(await service.photoOf(saved), bytes);
    });

    test('soal hanya foto sah; tanpa teks dan foto ditolak', () async {
      final id = await service.save(
        draft: draft().copyWith(teks: ''),
        now: h.clock.now(),
        newPhoto: bytes,
      );
      expect((await captures.byId(id))!.teks, '');
      await expectLater(
        service.save(draft: draft().copyWith(teks: ''), now: h.clock.now()),
        throwsArgumentError,
      );
    });

    test('mengganti foto menghapus foto lama; menghapus foto membuang nama',
        () async {
      final id = await service.save(
        draft: draft(),
        now: h.clock.now(),
        newPhoto: bytes,
      );
      final first = (await captures.byId(id))!.fotoPath!;
      await service.save(
        draft: CaptureDraft.from((await captures.byId(id))!),
        now: h.clock.now(),
        id: id,
        newPhoto: Uint8List.fromList([9]),
      );
      final second = (await captures.byId(id))!.fotoPath!;
      expect(second, isNot(first));
      expect(photos.files.keys, [second]);

      await service.save(
        draft: CaptureDraft.from((await captures.byId(id))!),
        now: h.clock.now(),
        id: id,
        removePhoto: true,
      );
      expect((await captures.byId(id))!.fotoPath, isNull);
      expect(photos.files, isEmpty);
    });

    test('mengubah soal mempertahankan waktu dibuat dan id', () async {
      final id = await service.save(draft: draft(), now: h.clock.now());
      h.clock.advance(const Duration(days: 1));
      await service.save(
        draft: draft(kunci: 0),
        now: h.clock.now(),
        id: id,
      );
      final q = (await captures.byId(id))!;
      expect(q.kunci, 0);
      expect(q.dibuat, DateTime.utc(2026, 10, 1, 8));
      expect(await captures.watchAll().first, hasLength(1));
    });

    test('foto gagal disimpan: soal tidak tersimpan', () async {
      photos.failWith =
          const PhotoStoreException(PhotoStoreProblem.storageFull);
      await expectLater(
        service.save(draft: draft(), now: h.clock.now(), newPhoto: bytes),
        throwsA(isA<PhotoStoreException>()),
      );
      expect(await captures.watchAll().first, isEmpty);
    });

    test('hapus soal menghapus kartu buku kesalahan dan fotonya', () async {
      final id = await service.save(
        draft: draft(),
        now: h.clock.now(),
        newPhoto: bytes,
      );
      await h.start(
        SessionMode.latihan,
        SessionPlanBuilder.capture(
          [(await captures.byId(id))!],
          now: h.clock.now(),
        ),
      );
      await h.c.select(0);
      await h.c.submit();
      await h.c.next();
      expect(await mistakes.watchAll().first, hasLength(1));

      await service.delete(id);
      expect(await captures.byId(id), isNull);
      expect(await mistakes.watchAll().first, isEmpty);
      expect(photos.files, isEmpty);
    });
  });
}
