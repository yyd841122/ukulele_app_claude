// Built-in chord library data for the MVP.
//
// T008 scope:
// - Four chords: C / Am / F / G. Fret positions match the standard
//   high-G (re-entrant) tuning G-C-E-A, top to bottom:
//     String 4 (leftmost in the diagram):  G
//     String 3:                            C
//     String 2:                            E
//     String 1 (rightmost in the diagram): A
//   When the player holds the ukulele in playing position the *top*
//   string (closest to the player's face) is G — we render the G
//   string as the leftmost column of the diagram and the A string as
//   the rightmost column, which is the conventional orientation used
//   by most beginner chord charts.
//
// Voicings below are the *most common* beginner voicings as
// documented by mainstream ukulele learning resources (UkuTabs,
// Ukulele Underground, Justin Guitar ukulele track, etc.):
//
//   C  : A3            — 1 finger (ring on A string fret 3)
//   Am : G2            — 1 finger (middle on G string fret 2)
//   F  : E1 + G2       — 2 fingers (index on E string fret 1,
//                                   middle on G string fret 2)
//   G  : C2 + E3 + A2  — 3 fingers (index on C string fret 2,
//                                   middle on E string fret 3,
//                                   ring on A string fret 2)
//
// Fret arrays below are stored string 1..4 (A, E, C, G), left-to-right
// in the rendered diagram. Tests pin these arrays so a typo in the
// constants is caught by CI rather than by a beginner at 23:00.
//
// - This file is a pure constant. It must not perform I/O, must not
//   call into Flutter, and must not be mutated. Tests import it
//   directly to assert the contents.

import 'package:ukulele_app/features/chord_library/domain/chord.dart';
import 'package:ukulele_app/features/chord_library/domain/chord_difficulty.dart';
import 'package:ukulele_app/features/chord_library/domain/chord_fingering.dart';

/// The four chords shipped with the MVP, ordered as displayed in the
/// library list. Ordering is stable — do not re-sort in the UI.
final List<Chord> kBuiltInChords = <Chord>[
  // ---- C major ----
  // Standard 1-finger voicing on high-G ukulele.
  // Resulting notes (A..G): C, E, C, G  → C major.
  Chord(
    id: 'c',
    name: 'C',
    displayName: 'C 和弦',
    description: 'C 大三和弦。最常用的入门和弦，按法简单、音色明亮。',
    difficulty: ChordDifficulty.beginner,
    voicings: <ChordFingering>[
      ChordFingering(
        startFret: 1,
        maxFretShown: 4,
        stringPositions: <ChordStringPosition>[
          // String 1 = A. fret 3 → C. Ring finger.
          ChordStringPosition(stringNumber: 1, fret: 3, finger: 3),
          // String 2 = E. open.
          ChordStringPosition(stringNumber: 2, fret: 0),
          // String 3 = C. open.
          ChordStringPosition(stringNumber: 3, fret: 0),
          // String 4 = G. open.
          ChordStringPosition(stringNumber: 4, fret: 0),
        ],
      ),
    ],
    tips: <String>[
      '只需要一根手指：无名指按 1 弦（A 弦）第 3 品。',
      '其他 3 根弦保持空弦，音色自带明亮色彩。',
      '按好后从 4 弦到 1 弦依次拨响，确认每一根都清晰。',
    ],
    relatedChordIds: <String>['am', 'f', 'g'],
  ),

  // ---- A minor ----
  // Standard 1-finger voicing.
  // Resulting notes (A..G): A, E, C, A  → A minor.
  Chord(
    id: 'am',
    name: 'Am',
    displayName: 'Am 和弦',
    description: 'A 小三和弦。只需要一根手指，是 C 和弦的最佳搭档。',
    difficulty: ChordDifficulty.beginner,
    voicings: <ChordFingering>[
      ChordFingering(
        startFret: 1,
        maxFretShown: 4,
        stringPositions: <ChordStringPosition>[
          // String 1 = A. open.
          ChordStringPosition(stringNumber: 1, fret: 0),
          // String 2 = E. open.
          ChordStringPosition(stringNumber: 2, fret: 0),
          // String 3 = C. open.
          ChordStringPosition(stringNumber: 3, fret: 0),
          // String 4 = G. fret 2 → A. Middle finger.
          ChordStringPosition(stringNumber: 4, fret: 2, finger: 2),
        ],
      ),
    ],
    tips: <String>[
      '只需要一根手指：中指按 4 弦（G 弦）第 2 品。',
      '与 C 和弦切换时，可以保留 1 / 2 / 3 弦空弦不动。',
      '确认 4 弦音色干净，不要碰到 3 弦。',
    ],
    relatedChordIds: <String>['c', 'f', 'g'],
  ),

  // ---- F major ----
  // Beginner-friendly 2-finger voicing (no barree).
  // Resulting notes (A..G): A, F, C, A  → F major (no 5th doubled).
  //
  // We deliberately ship the 2-finger voicing rather than the
  // 3-finger full voicing or the 1-finger barree; both are
  // significantly harder for absolute beginners and out of scope for
  // the MVP beginner curriculum.
  Chord(
    id: 'f',
    name: 'F',
    displayName: 'F 和弦',
    description: 'F 大三和弦的简化按法。用 2 根手指，初学时常见挑战是同时按住两根弦。',
    difficulty: ChordDifficulty.easy,
    voicings: <ChordFingering>[
      ChordFingering(
        startFret: 1,
        maxFretShown: 4,
        stringPositions: <ChordStringPosition>[
          // String 1 = A. open.
          ChordStringPosition(stringNumber: 1, fret: 0),
          // String 2 = E. fret 1 → F. Index finger.
          ChordStringPosition(stringNumber: 2, fret: 1, finger: 1),
          // String 3 = C. open.
          ChordStringPosition(stringNumber: 3, fret: 0),
          // String 4 = G. fret 2 → A. Middle finger.
          ChordStringPosition(stringNumber: 4, fret: 2, finger: 2),
        ],
      ),
    ],
    tips: <String>[
      '食指按 2 弦（E 弦）第 1 品，中指按 4 弦（G 弦）第 2 品。',
      '1 弦（A 弦）和 3 弦（C 弦）保持空弦不动。',
      '食指与中指要分别立起来，避免互相影响或碰到相邻弦。',
      '如果两根手指放不平，可以先按住 2 弦单弦练习，再加 4 弦。',
    ],
    relatedChordIds: <String>['c', 'g'],
  ),

  // ---- G major ----
  // Standard 3-finger voicing.
  // Resulting notes (A..G): B, G, D, G  → G major.
  Chord(
    id: 'g',
    name: 'G',
    displayName: 'G 和弦',
    description: 'G 大三和弦。需要 3 根手指，是大量流行歌曲的基础和弦。',
    difficulty: ChordDifficulty.intermediate,
    voicings: <ChordFingering>[
      ChordFingering(
        startFret: 1,
        maxFretShown: 4,
        stringPositions: <ChordStringPosition>[
          // String 1 = A. fret 2 → B. Ring finger.
          ChordStringPosition(stringNumber: 1, fret: 2, finger: 3),
          // String 2 = E. fret 3 → G. Middle finger.
          ChordStringPosition(stringNumber: 2, fret: 3, finger: 2),
          // String 3 = C. fret 2 → D. Index finger.
          ChordStringPosition(stringNumber: 3, fret: 2, finger: 1),
          // String 4 = G. open.
          ChordStringPosition(stringNumber: 4, fret: 0),
        ],
      ),
    ],
    tips: <String>[
      '食指按 3 弦（C 弦）第 2 品，中指按 2 弦（E 弦）第 3 品，无名指按 1 弦（A 弦）第 2 品。',
      '4 弦（G 弦）保持空弦。',
      '注意食指不要碰到 4 弦。',
      '3 根手指呈"小楼梯"形状，立起来按弦。',
    ],
    relatedChordIds: <String>['c', 'am', 'f'],
  ),
];

/// Lookup by id. Returns `null` for unknown ids — the detail page uses
/// this to decide between "show chord" and "show not-found state".
final Map<String, Chord> _kBuiltInChordsById = <String, Chord>{
  for (final Chord c in kBuiltInChords) c.id: c,
};

/// Returns the chord with the given [id], or `null` if not found.
///
/// The lookup is `O(1)` and is safe to call from the UI for every
/// rebuild — it is backed by an immutable map built once at
/// startup.
Chord? findBuiltInChord(String id) => _kBuiltInChordsById[id];