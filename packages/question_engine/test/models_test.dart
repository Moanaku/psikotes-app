import 'dart:convert';

import 'package:question_engine/question_engine.dart';
import 'package:test/test.dart';

/// Contoh format soal dari docs/06-bank-konten.md, "Format soal".
const _sample = '''
{
  "type": "FIG-MTX",
  "category": "figural",
  "seed": 20481,
  "difficulty": "medium",
  "stem": {
    "text": "Pilih gambar yang melengkapi pola.",
    "figure": {
      "kind": "matrix3x3",
      "cells": [
        [
          {"kind": "single", "objects": [{"shape": "circle", "count": 1, "fill": "empty", "rotation": 0, "size": "m"}]},
          {"kind": "single", "objects": [{"shape": "circle", "count": 2, "fill": "empty", "rotation": 0, "size": "m"}]},
          {"kind": "single", "objects": [{"shape": "circle", "count": 3, "fill": "empty", "rotation": 0, "size": "m"}]}
        ],
        [
          {"kind": "single", "objects": [{"shape": "triangle", "count": 1, "fill": "hatch", "rotation": 90, "size": "s"}]},
          {"kind": "single", "objects": [{"shape": "triangle", "count": 2, "fill": "hatch", "rotation": 90, "size": "s"}]},
          {"kind": "single", "objects": [{"shape": "triangle", "count": 3, "fill": "hatch", "rotation": 90, "size": "s"}]}
        ],
        [
          {"kind": "single", "objects": [{"shape": "square", "count": 1, "fill": "solid", "rotation": 0, "size": "l"}]},
          {"kind": "single", "objects": [{"shape": "square", "count": 2, "fill": "solid", "rotation": 0, "size": "l"}]},
          null
        ]
      ]
    }
  },
  "options": [
    {"id": "A", "content": {"figure": {"kind": "single", "objects": [{"shape": "square", "count": 2, "fill": "solid", "rotation": 0, "size": "l"}]}}},
    {"id": "B", "content": {"figure": {"kind": "single", "objects": [{"shape": "square", "count": 3, "fill": "solid", "rotation": 0, "size": "l"}]}}}
  ],
  "correctIndex": 1,
  "explanation": "Baris 1: bentuk tetap lingkaran dan jumlah naik per kolom. Baris 3: kotak dengan jumlah 1, 2, jadi sel kosong berisi 3 kotak.",
  "estimatedSeconds": 45,
  "tags": ["rule:constant-row", "rule:progress-col"]
}
''';

Question _decode(String source) => Question.fromJson(jsonDecode(source));

Map<String, Object?> _sampleMap() =>
    jsonDecode(_sample) as Map<String, Object?>;

Question _textQuestion(List<String> options, {int correctIndex = 0}) =>
    Question(
      type: QuestionType.numSeq,
      seed: 7,
      difficulty: Difficulty.easy,
      stem: const QuestionContent(text: '2, 4, 6, ...'),
      options: [
        for (var i = 0; i < options.length; i++)
          Option(
              id: Option.idFor(i), content: QuestionContent(text: options[i])),
      ],
      correctIndex: correctIndex,
      explanation: 'Selisih tetap 2.',
      estimatedSeconds: 30,
    );

void main() {
  group('JSON Question', () {
    test('contoh dokumen terbaca dan sah', () {
      final q = _decode(_sample);
      expect(q.type, QuestionType.figMtx);
      expect(q.category, QuestionCategory.figural);
      expect(q.difficulty, Difficulty.medium);
      expect(q.options, hasLength(2));
      expect(q.validate(), isEmpty);
      final matrix = q.stem.figure! as MatrixFigure;
      expect(matrix.cells[2][2], isNull);
      expect(matrix.cells[1][0]!.objects.single.rotation, Rotation.r90);
      expect(matrix.cells[1][0]!.objects.single.size, FigureSize.small);
    });

    test('bolak-balik identik sampai tingkat string', () {
      final once = jsonEncode(_decode(_sample).toJson());
      final twice = jsonEncode(_decode(once).toJson());
      expect(twice, once);
      expect(jsonDecode(once), jsonDecode(_sample));
    });

    test('kunci kosong dihilangkan, bukan ditulis null', () {
      final json = _textQuestion(['8', '9']).toJson();
      expect((json['stem']! as Map).containsKey('figure'), isFalse);
      expect(json['tags'], isEmpty);
    });

    test('category tidak cocok dengan tipe ditolak', () {
      final m = _sampleMap()..['category'] = 'verbal';
      expect(() => Question.fromJson(m), throwsFormatException);
    });

    test('kode tidak dikenal ditolak', () {
      for (final entry in {
        'type': 'FIG-XXX',
        'difficulty': 'brutal',
      }.entries) {
        final m = _sampleMap()..[entry.key] = entry.value;
        expect(() => Question.fromJson(m), throwsFormatException,
            reason: entry.key);
      }
    });

    test('tipe nilai salah ditolak', () {
      expect(() => Question.fromJson(_sampleMap()..['seed'] = '20481'),
          throwsFormatException);
      expect(() => Question.fromJson(_sampleMap()..remove('explanation')),
          throwsFormatException);
      expect(() => Question.fromJson('bukan objek'), throwsFormatException);
    });

    test('gambar dengan kind atau rotasi tidak dikenal ditolak', () {
      expect(
          () => FigureSpec.fromJson({'kind': 'spiral'}), throwsFormatException);
      expect(
          () => FigureObject.fromJson({
                'shape': 'circle',
                'count': 1,
                'fill': 'empty',
                'rotation': 45,
                'size': 'm',
              }),
          throwsFormatException);
    });
  });

  group('validate', () {
    test('soal teks yang benar sah', () {
      expect(_textQuestion(['8', '9']).validate(), isEmpty);
    });

    test('jumlah opsi 2 sampai 8', () {
      expect(_textQuestion(['8']).validate(),
          contains(startsWith('jumlah opsi 1')));
      expect(_textQuestion([for (var i = 0; i < 9; i++) '$i']).validate(),
          contains(startsWith('jumlah opsi 9')));
    });

    test('correctIndex di luar rentang', () {
      expect(_textQuestion(['8', '9'], correctIndex: 2).validate(),
          contains(startsWith('correctIndex 2')));
    });

    test('ID opsi harus urut A, B, C', () {
      final q = Question(
        type: QuestionType.numSeq,
        seed: 1,
        difficulty: Difficulty.easy,
        stem: const QuestionContent(text: 'x'),
        options: const [
          Option(id: 'A', content: QuestionContent(text: '1')),
          Option(id: 'C', content: QuestionContent(text: '2')),
        ],
        correctIndex: 0,
        explanation: 'y',
        estimatedSeconds: 10,
      );
      expect(q.validate(), contains(startsWith('options[1].id "C"')));
    });

    test('stem dan opsi wajib berisi', () {
      final q = Question(
        type: QuestionType.numSeq,
        seed: 1,
        difficulty: Difficulty.easy,
        stem: const QuestionContent(),
        options: const [
          Option(id: 'A', content: QuestionContent(text: '  ')),
          Option(id: 'B', content: QuestionContent(text: '2')),
        ],
        correctIndex: 0,
        explanation: ' ',
        estimatedSeconds: 0,
        tags: const ['a', 'a'],
      );
      expect(
          q.validate(),
          containsAll([
            'stem harus punya text atau figure',
            'options[0].content.text kosong',
            'explanation kosong',
            startsWith('estimatedSeconds 0'),
            'tag kembar',
          ]));
    });

    test('seed di luar 32 bit', () {
      final m = _sampleMap()..['seed'] = -1;
      expect(Question.fromJson(m).validate(), contains(startsWith('seed')));
    });

    test('count objek 1 sampai 4', () {
      final figure = SingleFigure(const [
        FigureObject(shape: Shape.square, count: 5),
      ]);
      expect(figure.validate('f'), ['f.objects[0].count di luar 1..4: 5']);
    });

    test('matriks harus 3x3 dengan tepat satu sel kosong', () {
      final cell = SingleFigure(const [FigureObject(shape: Shape.circle)]);
      final full = MatrixFigure([
        for (var r = 0; r < 3; r++) [cell, cell, cell],
      ]);
      expect(full.validate('m'), [contains('tepat satu sel kosong, ada 0')]);
      final ragged = MatrixFigure([
        [cell, cell, cell],
        [cell, cell],
        [cell, cell, null],
      ]);
      expect(ragged.validate('m'), contains('m.cells bukan 3x3'));
    });
  });

  group('kesamaan visual', () {
    QuestionContent fig(Shape shape, Rotation rotation) => QuestionContent(
          figure:
              SingleFigure([FigureObject(shape: shape, rotation: rotation)]),
        );

    test('rotasi tidak terlihat pada bentuk simetris', () {
      for (final shape in [Shape.circle, Shape.square, Shape.cross]) {
        expect(fig(shape, Rotation.r90).visualKey,
            fig(shape, Rotation.r0).visualKey,
            reason: shape.code);
      }
      expect(fig(Shape.diamond, Rotation.r180).visualKey,
          fig(Shape.diamond, Rotation.r0).visualKey);
      expect(fig(Shape.diamond, Rotation.r90).visualKey,
          isNot(fig(Shape.diamond, Rotation.r0).visualKey));
    });

    test('rotasi terlihat pada segitiga dan segi lima', () {
      for (final shape in [Shape.triangle, Shape.pentagon]) {
        final keys = {
          for (final r in Rotation.values) fig(shape, r).visualKey,
        };
        expect(keys, hasLength(4), reason: shape.code);
      }
    });

    test('teks dibandingkan tanpa spasi berlebih dan huruf besar', () {
      expect(const QuestionContent(text: ' Bank  Data ').visualKey,
          const QuestionContent(text: 'bank data').visualKey);
      expect(const QuestionContent(text: '12').visualKey,
          isNot(const QuestionContent(text: '21').visualKey));
    });

    test('canonical tidak mengubah JSON asli', () {
      final q = _decode(_sample);
      final before = jsonEncode(q.toJson());
      q.stem.figure!.canonical();
      expect(jsonEncode(q.toJson()), before);
    });
  });

  test('Rotation.turn berputar melingkar', () {
    expect(Rotation.r270.turn(1), Rotation.r0);
    expect(Rotation.r0.turn(-1), Rotation.r270);
    expect(Rotation.r90.turn(6), Rotation.r270);
  });

  test('setiap tipe punya kode unik dan kategori', () {
    final codes = QuestionType.values.map((t) => t.code).toSet();
    expect(codes, hasLength(QuestionType.values.length));
    for (final t in QuestionType.values) {
      expect(QuestionType.fromCode(t.code), t);
    }
  });

  test('model tidak dapat diubah', () {
    final q = _textQuestion(['8', '9']);
    expect(() => q.options.add(q.options.first), throwsUnsupportedError);
    expect(() => q.tags.add('x'), throwsUnsupportedError);
  });
}
