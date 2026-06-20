// Built-in single-note library data for the MVP.
//
// T009 scope:
// - Six notes: C / D / E / F / G / A. Fret positions match the
//   standard high-G (re-entrant) tuning G-C-E-A, and use the most
//   common beginner fingerings on a standard ukulele:
//     C  : 3rd string fret 0 (open C)        — no finger
//     D  : 3rd string fret 2                  — index finger
//     E  : 2nd string fret 0 (open E)        — no finger
//     F  : 2nd string fret 1                  — index finger
//     G  : 4th string fret 0 (open G)        — no finger
//     A  : 1st string fret 0 (open A)        — no finger
//   The "A" note could alternatively be played on a different
//   string and fret, but the open A on string 1 is the easier
//   choice for absolute beginners (no fretting required) and
//   matches the order in which the strings are usually taught in
//   the standard "A, E, C, G" recital. We ship the open version.
// - String numbering inside the data model follows T008:
//     stringNumber 1 = A
//     stringNumber 2 = E
//     stringNumber 3 = C
//     stringNumber 4 = G
//   The data model only carries the numbering convention and
//   per-note string / fret metadata — it does NOT carry a
//   linear pitch ordering, because on a re-entrant high-G
//   ukulele the pitch walk from string 1 to string 4 is
//   non-monotonic. Visible orientation rules live in
//   [visibleSingleNoteStringOrder] (G, C, E, A from left to
//   right in the diagram).
// - This file is a pure constant. It must not perform I/O, must not
//   call into Flutter, and must not be mutated. Tests import it
//   directly to assert the contents.

import 'package:ukulele_app/features/single_note_practice/domain/single_note.dart';
import 'package:ukulele_app/features/single_note_practice/domain/single_note_difficulty.dart';

/// The six notes shipped with the MVP, ordered as displayed in the
/// practice carousel. Ordering is stable — do not re-sort in the UI.
final List<SingleNote> kBuiltInSingleNotes = <SingleNote>[
  // ---- C ----
  // 3rd string, open. This is the "C" most ukulele tutorials teach
  // first because it sits on the C string itself.
  SingleNote(
    id: 'c',
    name: 'C',
    displayName: 'C 音',
    description: 'C 大调的第一个音。3 弦空弦，是尤克里里最常用的入门音之一。',
    stringName: 'C',
    stringNumber: 3,
    fret: 0,
    finger: null,
    difficulty: SingleNoteDifficulty.openString,
    tips: <String>[
      '不需要按品，直接拨响 3 弦。',
      '注意不要碰到 2 弦或 4 弦。',
      '右手拇指拨弦，食指可以扶住琴颈稳定琴身。',
    ],
  ),

  // ---- D ----
  // 3rd string, fret 2. Index finger.
  SingleNote(
    id: 'd',
    name: 'D',
    displayName: 'D 音',
    description: 'D 大调的第一个音。食指按 3 弦第 2 品。',
    stringName: 'C',
    stringNumber: 3,
    fret: 2,
    finger: 1,
    difficulty: SingleNoteDifficulty.higherFret,
    tips: <String>[
      '食指按 3 弦（C 弦）第 2 品。',
      '指肚尽量靠近品丝（金属横条），音色更干净。',
      '按好后用右手拇指单独拨 3 弦，确认没有杂音。',
    ],
  ),

  // ---- E ----
  // 2nd string, open.
  SingleNote(
    id: 'e',
    name: 'E',
    displayName: 'E 音',
    description: 'E 大调的第一个音。2 弦空弦，不需要按品。',
    stringName: 'E',
    stringNumber: 2,
    fret: 0,
    finger: null,
    difficulty: SingleNoteDifficulty.openString,
    tips: <String>[
      '不需要按品，直接拨响 2 弦。',
      '注意只拨目标弦，不要碰到 1 弦或 3 弦。',
      '与 C 音切换时，左手可以保留在 3 弦第 2 品。',
    ],
  ),

  // ---- F ----
  // 2nd string, fret 1. Index finger. The first note that
  // requires fretting in the curriculum.
  SingleNote(
    id: 'f',
    name: 'F',
    displayName: 'F 音',
    description: 'F 大调的第一个音。食指按 2 弦第 1 品。',
    stringName: 'E',
    stringNumber: 2,
    fret: 1,
    finger: 1,
    difficulty: SingleNoteDifficulty.firstFret,
    tips: <String>[
      '食指按 2 弦（E 弦）第 1 品。',
      '指肚立起来，不要碰到 1 弦或 3 弦。',
      '刚按的时候可能会有"嗡嗡"的杂音，多练几次手指力度会改善。',
    ],
  ),

  // ---- G ----
  // 4th string, open.
  SingleNote(
    id: 'g',
    name: 'G',
    displayName: 'G 音',
    description: 'G 大调的第一个音。4 弦空弦，不需要按品。',
    stringName: 'G',
    stringNumber: 4,
    fret: 0,
    finger: null,
    difficulty: SingleNoteDifficulty.openString,
    tips: <String>[
      '不需要按品，直接拨响 4 弦。',
      '4 弦在图中显示在最左侧。',
      '右手食指或拇指都可以拨弦，新手建议用拇指。',
    ],
  ),

  // ---- A ----
  // 1st string, open. We deliberately use the open 1st-string A
  // rather than the 4th-string fret-2 A because it is the easier
  // choice for absolute beginners (no fretting required) and
  // matches the "A, E, C, G" recital ordering. See file-level
  // docs for the rationale.
  SingleNote(
    id: 'a',
    name: 'A',
    displayName: 'A 音',
    description: 'A 大调的第一个音。1 弦空弦，最简单的入门音。',
    stringName: 'A',
    stringNumber: 1,
    fret: 0,
    finger: null,
    difficulty: SingleNoteDifficulty.openString,
    tips: <String>[
      '不需要按品，直接拨响 1 弦。',
      '1 弦在图中显示在最右侧。',
      '如果想换个位置练习同名 A 音，可以在 4 弦第 2 品上找到。',
    ],
  ),
];

/// Lookup by id. Returns `null` for unknown ids — the controller
/// uses this to decide between "show note" and "treat as unknown".
final Map<String, SingleNote> _kBuiltInSingleNotesById = <String, SingleNote>{
  for (final SingleNote n in kBuiltInSingleNotes) n.id: n,
};

/// Returns the single note with the given [id], or `null` if not
/// found.
///
/// The lookup is `O(1)` and is safe to call from the UI for every
/// rebuild — it is backed by an immutable map built once at startup.
SingleNote? findBuiltInSingleNote(String id) => _kBuiltInSingleNotesById[id];
