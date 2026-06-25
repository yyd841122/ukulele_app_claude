// Tests for the built-in single-note library data.
//
// T009 scope:
// - Verify that C / D / E / F / G / A are all present.
// - Verify every note passes structural validation
//   ([SingleNote.validate]).
// - Pin the key fret / string choices so a typo in the constants
//   is caught by CI rather than by a beginner at 23:00.
// - Pin the visible string order to [4, 3, 2, 1] so the diagram
//   cannot drift back to the data-model order.

import 'package:flutter_test/flutter_test.dart';

import 'package:ukulele_app/features/single_note_practice/data/built_in_single_notes.dart';
import 'package:ukulele_app/features/single_note_practice/domain/single_note.dart';
import 'package:ukulele_app/features/single_note_practice/domain/single_note_difficulty.dart';

void main() {
  group('kBuiltInSingleNotes', () {
    test('contains C, D, E, F, G, A, B', () {
      final List<String> ids =
          kBuiltInSingleNotes.map((SingleNote n) => n.id).toList();
      expect(
        ids,
        containsAll(<String>['c', 'd', 'e', 'f', 'g', 'a', 'b']),
      );
      expect(kBuiltInSingleNotes.length, 7);
    });

    test('every note passes structural validation', () {
      for (final SingleNote n in kBuiltInSingleNotes) {
        expect(
          n.validate(),
          isNull,
          reason: '${n.id} failed validation: ${n.validate()}',
        );
      }
    });

    test('every note declares a difficulty', () {
      for (final SingleNote n in kBuiltInSingleNotes) {
        // Trivial read so a future refactor that adds a null case
        // does not silently leak through.
        expect(SingleNoteDifficulty.values, contains(n.difficulty));
      }
    });

    test('C is 3rd string, open', () {
      final SingleNote c =
          kBuiltInSingleNotes.firstWhere((SingleNote n) => n.id == 'c');
      expect(c.stringNumber, 3);
      expect(c.fret, 0);
      expect(c.finger, isNull);
      expect(c.isOpen, isTrue);
    });

    test('D is 3rd string, fret 2, index finger', () {
      final SingleNote d =
          kBuiltInSingleNotes.firstWhere((SingleNote n) => n.id == 'd');
      expect(d.stringNumber, 3);
      expect(d.fret, 2);
      expect(d.finger, 1);
      expect(d.isFretted, isTrue);
    });

    test('E is 2nd string, open', () {
      final SingleNote e =
          kBuiltInSingleNotes.firstWhere((SingleNote n) => n.id == 'e');
      expect(e.stringNumber, 2);
      expect(e.fret, 0);
      expect(e.finger, isNull);
      expect(e.isOpen, isTrue);
    });

    test('F is 2nd string, fret 1, index finger', () {
      final SingleNote f =
          kBuiltInSingleNotes.firstWhere((SingleNote n) => n.id == 'f');
      expect(f.stringNumber, 2);
      expect(f.fret, 1);
      expect(f.finger, 1);
      expect(f.isFretted, isTrue);
    });

    test('G is 4th string, open', () {
      final SingleNote g =
          kBuiltInSingleNotes.firstWhere((SingleNote n) => n.id == 'g');
      expect(g.stringNumber, 4);
      expect(g.fret, 0);
      expect(g.finger, isNull);
      expect(g.isOpen, isTrue);
    });

    test(
        'A is 1st string, open (NOT 4th string fret 2) — chosen for '
        'beginner simplicity', () {
      // The task brief explicitly chooses the 1st-string open A
      // for the MVP. Pin both the affirmative (what we ship) and
      // the negative (the alternative voicing we deliberately
      // do NOT ship) so a future refactor cannot silently flip to
      // the 4th-string fret-2 voicing.
      final SingleNote a =
          kBuiltInSingleNotes.firstWhere((SingleNote n) => n.id == 'a');
      expect(a.stringNumber, 1);
      expect(a.fret, 0);
      expect(a.finger, isNull);
      expect(a.isOpen, isTrue);
      expect(a.stringName, 'A');
    });

    test('B is 4th string, fret 2, index finger (T054)', () {
      // T054: seventh built-in note. The G string at fret 2 is
      // the simplest fretting for B on a high-G ukulele and pairs
      // naturally with the open A on the same string one step
      // away. Pin the field choices so a future refactor cannot
      // silently flip to a different voicing.
      final SingleNote b =
          kBuiltInSingleNotes.firstWhere((SingleNote n) => n.id == 'b');
      expect(b.stringNumber, 4);
      expect(b.stringName, 'G');
      expect(b.fret, 2);
      expect(b.finger, 1);
      expect(b.isFretted, isTrue);
      expect(b.isOpen, isFalse);
      expect(b.difficulty, SingleNoteDifficulty.higherFret);
      expect(b.validate(), isNull);
    });

    test('every stringNumber / fret / finger is in the legal range', () {
      for (final SingleNote n in kBuiltInSingleNotes) {
        expect(n.stringNumber, inInclusiveRange(1, 4),
            reason: '${n.id} stringNumber=${n.stringNumber}');
        expect(n.fret, greaterThanOrEqualTo(0),
            reason: '${n.id} fret=${n.fret}');
        if (n.fret > 0) {
          expect(n.finger, isNotNull,
              reason: '${n.id} is fretted but has no finger');
        } else {
          expect(n.finger, isNull,
              reason: '${n.id} is open but has a finger');
        }
        if (n.finger != null) {
          expect(n.finger, inInclusiveRange(1, 4),
              reason: '${n.id} finger=${n.finger}');
        }
      }
    });

    test('findBuiltInSingleNote returns null for unknown ids', () {
      // T054 added B; the remaining letter ids are NOT shipped
      // (no 'h', 'i', 'j', etc.) and must still return null.
      expect(findBuiltInSingleNote('h'), isNull);
      expect(findBuiltInSingleNote('bb'), isNull);
      expect(findBuiltInSingleNote(''), isNull);
      expect(findBuiltInSingleNote('not-a-note'), isNull);
    });

    test('findBuiltInSingleNote resolves every shipped id', () {
      for (final SingleNote n in kBuiltInSingleNotes) {
        expect(findBuiltInSingleNote(n.id)?.id, n.id);
      }
    });
  });

  group('SingleNote.validate()', () {
    test('rejects stringNumber out of range', () {
      const SingleNote bad = SingleNote(
        id: 'x',
        name: 'X',
        displayName: 'X 音',
        description: '',
        stringName: 'A',
        stringNumber: 5,
        fret: 0,
        finger: null,
        difficulty: SingleNoteDifficulty.openString,
      );
      expect(bad.validate(), isNotNull);
      expect(bad.validate(), contains('String number'));
    });

    test('rejects negative fret', () {
      const SingleNote bad = SingleNote(
        id: 'x',
        name: 'X',
        displayName: 'X 音',
        description: '',
        stringName: 'A',
        stringNumber: 1,
        fret: -1,
        finger: null,
        difficulty: SingleNoteDifficulty.openString,
      );
      expect(bad.validate(), isNotNull);
      expect(bad.validate(), contains('Fret'));
    });

    test('rejects a pressed fret with no finger', () {
      const SingleNote bad = SingleNote(
        id: 'x',
        name: 'X',
        displayName: 'X 音',
        description: '',
        stringName: 'A',
        stringNumber: 1,
        fret: 1,
        finger: null,
        difficulty: SingleNoteDifficulty.firstFret,
      );
      expect(bad.validate(), isNotNull);
      expect(bad.validate(), contains('finger index'));
    });

    test('rejects an open string with a finger', () {
      const SingleNote bad = SingleNote(
        id: 'x',
        name: 'X',
        displayName: 'X 音',
        description: '',
        stringName: 'A',
        stringNumber: 1,
        fret: 0,
        finger: 1,
        difficulty: SingleNoteDifficulty.openString,
      );
      expect(bad.validate(), isNotNull);
      expect(bad.validate(), contains('Open string'));
    });

    test('rejects a finger index out of range', () {
      const SingleNote bad = SingleNote(
        id: 'x',
        name: 'X',
        displayName: 'X 音',
        description: '',
        stringName: 'A',
        stringNumber: 1,
        fret: 1,
        finger: 5,
        difficulty: SingleNoteDifficulty.firstFret,
      );
      expect(bad.validate(), isNotNull);
      expect(bad.validate(), contains('Finger index'));
    });
  });
}
