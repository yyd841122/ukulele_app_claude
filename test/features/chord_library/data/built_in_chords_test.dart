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

    test('every voicing has positive startFret and maxFretShown', () {
      for (final Chord c in kBuiltInChords) {
        for (final ChordFingering f in c.voicings) {
          expect(
            f.startFret,
            greaterThanOrEqualTo(1),
            reason: '${c.id} voicing has startFret=${f.startFret}',
          );
          expect(
            f.maxFretShown,
            greaterThanOrEqualTo(1),
            reason: '${c.id} voicing has maxFretShown=${f.maxFretShown}',
          );
        }
      }
    });

    test('every pressed fret sits inside the visible window', () {
      for (final Chord c in kBuiltInChords) {
        for (final ChordFingering f in c.voicings) {
          final int maxRenderable = f.startFret + f.maxFretShown - 1;
          for (final ChordStringPosition p in f.stringPositions) {
            if (p.fret == null || p.fret == 0) {
              continue;
            }
            expect(
              p.fret,
              greaterThanOrEqualTo(f.startFret),
              reason: '${c.id} string ${p.stringNumber} fret=${p.fret} '
                  'below startFret=${f.startFret}',
            );
            expect(
              p.fret,
              lessThanOrEqualTo(maxRenderable),
              reason: '${c.id} string ${p.stringNumber} fret=${p.fret} '
                  'above window top=$maxRenderable',
            );
          }
        }
      }
    });

    test('C / Am / F / G difficulty tiers match the enum examples', () {
      // The difficulty examples in [ChordDifficulty] document which
      // chords live in which tier. Tests pin that mapping so a
      // future data tweak that demotes/promotes a chord also
      // surfaces here for the next Agent to update the docstring.
      final Map<String, ChordDifficulty> expected =
          <String, ChordDifficulty>{
        'c': ChordDifficulty.beginner,
        'am': ChordDifficulty.beginner,
        'f': ChordDifficulty.easy,
        'g': ChordDifficulty.intermediate,
      };
      expected.forEach((String id, ChordDifficulty tier) {
        final Chord? chord = findBuiltInChord(id);
        expect(chord, isNotNull, reason: 'missing chord $id');
        expect(
          chord!.difficulty,
          tier,
          reason: 'chord $id should be $tier, got ${chord.difficulty}',
        );
      });
    });
  });

  group('ChordFingering.validate()', () {
    // A reusable 4-string block. The fret values are placeholders;
    // tests below override them as needed.
    List<ChordStringPosition> fourStrings({int? fret}) {
      return <ChordStringPosition>[
        ChordStringPosition(stringNumber: 1, fret: fret),
        ChordStringPosition(stringNumber: 2, fret: fret),
        ChordStringPosition(stringNumber: 3, fret: fret),
        ChordStringPosition(stringNumber: 4, fret: fret),
      ];
    }

    test('rejects startFret == 0', () {
      final ChordFingering bad = ChordFingering(
        startFret: 0,
        maxFretShown: 4,
        stringPositions: fourStrings(fret: 0),
      );
      expect(bad.validate(), isNotNull);
      expect(bad.validate(), contains('startFret'));
    });

    test('rejects negative startFret', () {
      final ChordFingering bad = ChordFingering(
        startFret: -1,
        maxFretShown: 4,
        stringPositions: fourStrings(fret: 0),
      );
      expect(bad.validate(), isNotNull);
      expect(bad.validate(), contains('startFret'));
    });

    test('rejects maxFretShown == 0', () {
      final ChordFingering bad = ChordFingering(
        startFret: 1,
        maxFretShown: 0,
        stringPositions: fourStrings(fret: 0),
      );
      expect(bad.validate(), isNotNull);
      expect(bad.validate(), contains('maxFretShown'));
    });

    test('rejects a pressed fret below startFret', () {
      // Window is frets 3..6 (startFret=3, maxFretShown=4).
      final ChordFingering bad = ChordFingering(
        startFret: 3,
        maxFretShown: 4,
        stringPositions: <ChordStringPosition>[
          ChordStringPosition(stringNumber: 1, fret: 2, finger: 1),
          ChordStringPosition(stringNumber: 2, fret: 0),
          ChordStringPosition(stringNumber: 3, fret: 0),
          ChordStringPosition(stringNumber: 4, fret: 0),
        ],
      );
      expect(bad.validate(), isNotNull);
      expect(bad.validate(), contains('below startFret'));
    });

    test('rejects a pressed fret above the visible window', () {
      // Window is frets 1..4 (startFret=1, maxFretShown=4).
      final ChordFingering bad = ChordFingering(
        startFret: 1,
        maxFretShown: 4,
        stringPositions: <ChordStringPosition>[
          ChordStringPosition(stringNumber: 1, fret: 5, finger: 1),
          ChordStringPosition(stringNumber: 2, fret: 0),
          ChordStringPosition(stringNumber: 3, fret: 0),
          ChordStringPosition(stringNumber: 4, fret: 0),
        ],
      );
      expect(bad.validate(), isNotNull);
      expect(bad.validate(), contains('outside the visible window'));
    });

    test('rejects a pressed fret at the boundary above the window', () {
      // Window is frets 1..2 (startFret=1, maxFretShown=2).
      final ChordFingering bad = ChordFingering(
        startFret: 1,
        maxFretShown: 2,
        stringPositions: <ChordStringPosition>[
          ChordStringPosition(stringNumber: 1, fret: 3, finger: 1),
          ChordStringPosition(stringNumber: 2, fret: 0),
          ChordStringPosition(stringNumber: 3, fret: 0),
          ChordStringPosition(stringNumber: 4, fret: 0),
        ],
      );
      expect(bad.validate(), isNotNull);
    });

    test('accepts a pressed fret exactly at the window top', () {
      // Window is frets 1..2 (startFret=1, maxFretShown=2).
      final ChordFingering ok = ChordFingering(
        startFret: 1,
        maxFretShown: 2,
        stringPositions: <ChordStringPosition>[
          ChordStringPosition(stringNumber: 1, fret: 2, finger: 1),
          ChordStringPosition(stringNumber: 2, fret: 0),
          ChordStringPosition(stringNumber: 3, fret: 0),
          ChordStringPosition(stringNumber: 4, fret: 0),
        ],
      );
      expect(ok.validate(), isNull);
    });

    test('still returns null for every built-in chord', () {
      // Regression: the tightened validator must not break the
      // existing shipped voicings.
      for (final Chord c in kBuiltInChords) {
        for (final ChordFingering f in c.voicings) {
          expect(
            f.validate(),
            isNull,
            reason: '${c.id} voicing failed validation: ${f.validate()}',
          );
        }
      }
    });

    test('open / muted strings still do not require a finger index', () {
      // Regression: open and muted strings must continue to pass
      // validation when their finger index is null.
      final ChordFingering ok = ChordFingering(
        startFret: 1,
        maxFretShown: 4,
        stringPositions: <ChordStringPosition>[
          ChordStringPosition(stringNumber: 1, fret: 0),
          ChordStringPosition(stringNumber: 2, fret: null),
          ChordStringPosition(stringNumber: 3, fret: 0),
          ChordStringPosition(stringNumber: 4, fret: 0),
        ],
      );
      expect(ok.validate(), isNull);
    });
  });
}
