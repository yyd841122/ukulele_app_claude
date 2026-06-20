// Domain model for a single ukulele note practice item.
//
// T009 scope:
// - The MVP ships one note per beginner pitch (C, D, E, F, G, A).
//   Each note is a single, atomic "play this string at this fret"
//   instruction, with optional practice tips.
// - The [SingleNote] model is intentionally narrower than the
//   chord library's [Chord]: a single note is *one* string / fret
//   pair, not a 4-string voicing. We re-use the same internal
//   [stringNumber] convention established by T008 so future
//   components (e.g. a combined single-note + chord diagram) can
//   read both models without a translation layer.
// - [stringNumber] semantics (T008 carry-over):
//     1 = A string
//     2 = E string
//     3 = C string
//     4 = G string
//   The visible left-to-right order in the diagram is the reverse
//   (G, C, E, A) — see [visibleSingleNoteStringOrder] in
//   `presentation/widgets/single_note_position_diagram.dart`.
// - [fret] semantics (T008 carry-over):
//     0        -> open string, no finger.
//     1..N     -> finger pressed behind that fret number.
//   [SingleNote.validate] treats 0 and 1..N as valid; only the
//   `built_in_single_notes.dart` module is allowed to set it.
// - [finger] semantics (T008 carry-over):
//     null     -> no finger (open strings).
//     1..4     -> index / middle / ring / pinky.

import 'package:flutter/foundation.dart';

import 'package:ukulele_app/features/single_note_practice/domain/single_note_difficulty.dart';

/// A single pitch to practice on a ukulele.
@immutable
class SingleNote {
  const SingleNote({
    required this.id,
    required this.name,
    required this.displayName,
    required this.description,
    required this.stringName,
    required this.stringNumber,
    required this.fret,
    required this.finger,
    required this.difficulty,
    this.tips = const <String>[],
  });

  /// Stable lowercase id, e.g. `"c"`, `"d"`, `"e"`, `"f"`, `"g"`,
  /// `"a"`. Used by the controller to look up completion state and
  /// by tests to pin data.
  final String id;

  /// Short musical name as commonly printed, e.g. `"C"`, `"D"`.
  final String name;

  /// Chinese-friendly display name for the UI, e.g. `"C 音"`.
  final String displayName;

  /// One-sentence plain description aimed at absolute beginners.
  final String description;

  /// Friendly string name shown in the UI, e.g. `"A"`, `"E"`,
  /// `"C"`, `"G"`. Matches the [stringNumber] semantics — see
  /// file-level docs.
  final String stringName;

  /// 1-based string index. 1 = A, 2 = E, 3 = C, 4 = G on a standard
  /// high-G ukulele. The visible left-to-right order in the diagram
  /// is the reverse — see [visibleSingleNoteStringOrder].
  final int stringNumber;

  /// Fret number. 0 = open, 1..N = pressed fret. See file-level docs.
  final int fret;

  /// Finger used to press the fret. `null` for open strings.
  /// When non-null, must be in 1..4.
  final int? finger;

  /// Difficulty tier used by the card chip.
  final SingleNoteDifficulty difficulty;

  /// Short practice tips shown below the info card.
  final List<String> tips;

  /// `true` iff this note is an open string (no fret, no finger).
  bool get isOpen => fret == 0;

  /// `true` iff this note uses a finger (fret > 0).
  bool get isFretted => fret > 0;

  /// Light-weight structural validator. Returns the first error
  /// message it finds, or `null` if the note is renderable.
  ///
  /// We do not throw — the built-in data module uses this to gate
  /// bad data, and tests use it to assert every shipped note is
  /// well-formed.
  String? validate() {
    if (stringNumber < 1 || stringNumber > 4) {
      return 'String number must be in 1..4, got $stringNumber';
    }
    if (fret < 0) {
      return 'Fret must be >= 0, got $fret';
    }
    if (fret == 0) {
      if (finger != null) {
        return 'Open string must not have a finger index, '
            'got finger=$finger on string $stringNumber';
      }
    } else {
      if (finger == null) {
        return 'Pressed fret $fret on string $stringNumber must declare '
            'a finger index';
      }
      final int f = finger!;
      if (f < 1 || f > 4) {
        return 'Finger index must be in 1..4, got $f';
      }
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SingleNote &&
          other.id == id &&
          other.name == name &&
          other.displayName == displayName &&
          other.description == description &&
          other.stringName == stringName &&
          other.stringNumber == stringNumber &&
          other.fret == fret &&
          other.finger == finger &&
          other.difficulty == difficulty &&
          listEquals(other.tips, tips));

  @override
  int get hashCode => Object.hash(
        id,
        name,
        displayName,
        description,
        stringName,
        stringNumber,
        fret,
        finger,
        difficulty,
        Object.hashAll(tips),
      );
}
