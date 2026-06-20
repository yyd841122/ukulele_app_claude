// Tests for the built-in chord library data.
//
// T008 scope:
// - Verify that C / Am / F / G are all present.
// - Verify every fingering is structurally valid (string count,
//   fret ranges, no spurious finger indices on open / muted strings).
// - Spot-check the displayed fret values so a typo in the constants
//   is caught by tests, not by a beginner at 23:00.

import 'package:flutter_test/flutter_test.dart';

import 'package:ukulele_app/features/chord_library/data/built_in_chords.dart';
import 'package:ukulele_app/features/chord_library/domain/chord.dart';
import 'package:ukulele_app/features/chord_library/domain/chord_difficulty.dart';
import 'package:ukulele_app/features/chord_library/domain/chord_fingering.dart';

void main() {
  group('kBuiltInChords', () {
    test('contains C, Am, F, G', () {
      final List<String> ids =
          kBuiltInChords.map((Chord c) => c.id).toList();
      expect(ids, containsAll(<String>['c', 'am', 'f', 'g']));
      expect(kBuiltInChords.length, 4);
    });

    test('every chord has exactly 4 strings per voicing', () {
      for (final Chord c in kBuiltInChords) {
        expect(c.voicings, isNotEmpty, reason: '${c.id} has no voicings');
        for (final ChordFingering f in c.voicings) {
          expect(
            f.stringPositions.length,
            4,
            reason: '${c.id} voicing must have 4 strings',
          );
        }
      }
    });

    test('every voicing passes structural validation', () {
      for (final Chord c in kBuiltInChords) {
        expect(c.isWellFormed, isTrue, reason: '${c.id} is not well-formed');
        for (final ChordFingering f in c.voicings) {
          expect(
            f.validate(),
            isNull,
            reason: '${c.id} voicing failed validation: ${f.validate()}',
          );
        }
      }
    });

    test('open / muted strings never carry a finger index', () {
      for (final Chord c in kBuiltInChords) {
        for (final ChordFingering f in c.voicings) {
          for (final ChordStringPosition p in f.stringPositions) {
            if (p.isOpen || p.isMuted) {
              expect(
                p.finger,
                isNull,
                reason: '${c.id} string ${p.stringNumber} is '
                    '${p.isOpen ? "open" : "muted"} but has a finger',
              );
            }
          }
        }
      }
    });

    test('C chord uses fret 3,0,0,0 on strings 1-4', () {
      final Chord c = kBuiltInChords.firstWhere(
        (Chord ch) => ch.id == 'c',
      );
      final List<int?> frets = c.primaryVoicing.stringPositions
          .map((ChordStringPosition p) => p.fret)
          .toList();
      expect(frets, <int?>[3, 0, 0, 0]);
    });

    test('Am chord uses fret 0,0,0,2 on strings 1-4', () {
      final Chord c = kBuiltInChords.firstWhere(
        (Chord ch) => ch.id == 'am',
      );
      final List<int?> frets = c.primaryVoicing.stringPositions
          .map((ChordStringPosition p) => p.fret)
          .toList();
      expect(frets, <int?>[0, 0, 0, 2]);
    });

    test('F chord (easy voicing) uses fret 0,1,0,2 on strings 1-4', () {
      final Chord c = kBuiltInChords.firstWhere(
        (Chord ch) => ch.id == 'f',
      );
      final List<int?> frets = c.primaryVoicing.stringPositions
          .map((ChordStringPosition p) => p.fret)
          .toList();
      expect(frets, <int?>[0, 1, 0, 2]);
    });

    test('G chord uses fret 2,3,2,0 on strings 1-4', () {
      final Chord c = kBuiltInChords.firstWhere(
        (Chord ch) => ch.id == 'g',
      );
      final List<int?> frets = c.primaryVoicing.stringPositions
          .map((ChordStringPosition p) => p.fret)
          .toList();
      expect(frets, <int?>[2, 3, 2, 0]);
    });

    test('every chord declares a difficulty', () {
      for (final Chord c in kBuiltInChords) {
        // Trivial read so a future refactor that adds a null case
        // does not silently leak through.
        expect(ChordDifficulty.values, contains(c.difficulty));
      }
    });

    test('findBuiltInChord returns null for unknown ids', () {
      expect(findBuiltInChord('cmaj7'), isNull);
      expect(findBuiltInChord(''), isNull);
      expect(findBuiltInChord('not-a-chord'), isNull);
    });

    test('findBuiltInChord resolves every shipped id', () {
      for (final Chord c in kBuiltInChords) {
        expect(findBuiltInChord(c.id)?.id, c.id);
      }
    });
  });
}
