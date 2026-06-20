// Per-string fingering data for a single chord voicing.
//
// T008 scope:
// - Ukulele has exactly 4 strings, conventionally numbered 1..4 from
//   the player's left to right (G-C-E-A from top to bottom when
//   holding the instrument in playing position). We expose a
//   [ChordStringPosition] for each of the 4 strings, ordered from
//   string 1 to string 4 so the UI can render left-to-right.
// - [fret] semantics:
//   * `null`        -> the string is muted (do not strum).
//   * `0`           -> the string is played open (no finger).
//   * `1..maxFret`  -> the finger presses behind that fret number.
//   Out-of-range or negative values are treated as invalid by
//   [ChordFingering.validate].
// - [finger] semantics:
//   * `null`        -> no finger pressing this string (used for open
//                      strings and muted strings).
//   * `1..4`        -> index finger / middle / ring / pinky.
//   We accept 0 to mean "no finger" for convenience but normalise it
//   to `null` so consumers only need to check for `null`.
//
// This file is intentionally dependency-free so it can be unit-tested
// without spinning up Flutter.

import 'package:flutter/foundation.dart';

/// Finger index for a single fretting finger. `null` = no finger.
typedef FingerIndex = int?;

/// State of a single string inside a chord voicing.
@immutable
class ChordStringPosition {
  const ChordStringPosition({
    required this.stringNumber,
    required this.fret,
    this.finger,
  });

  /// 1-based string index. 1 = leftmost (G) when rendered horizontally.
  final int stringNumber;

  /// Fret number. See file-level docs for semantics.
  final int? fret;

  /// Finger used to press this fret. `null` for open / muted strings.
  final FingerIndex finger;

  /// Returns a copy with any fields replaced.
  ChordStringPosition copyWith({
    int? stringNumber,
    int? fret,
    FingerIndex finger,
  }) {
    return ChordStringPosition(
      stringNumber: stringNumber ?? this.stringNumber,
      fret: fret ?? this.fret,
      finger: finger ?? this.finger,
    );
  }

  /// `true` if this string is played open (no finger).
  bool get isOpen => fret == 0;

  /// `true` if this string is muted (not played).
  bool get isMuted => fret == null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChordStringPosition &&
          other.stringNumber == stringNumber &&
          other.fret == fret &&
          other.finger == finger);

  @override
  int get hashCode => Object.hash(stringNumber, fret, finger);
}

/// One concrete voicing of a chord (how to fret it on the neck).
@immutable
class ChordFingering {
  const ChordFingering({
    required this.stringPositions,
    required this.startFret,
    required this.maxFretShown,
  });

  /// Exactly 4 entries, ordered string 1..4 (left to right when
  /// rendered).
  final List<ChordStringPosition> stringPositions;

  /// Fret shown at the top of the diagram. Normally 1.
  /// We keep it parametric so a future chord that lives higher up the
  /// neck can be rendered without changing the widget.
  final int startFret;

  /// How many frets to draw vertically. Defaults to 4 per the brief.
  final int maxFretShown;

  /// Light-weight structural validator. Returns the first error
  /// message it finds, or `null` if the voicing is renderable.
  ///
  /// We do not throw — `built_in_chords.dart` uses this to gate
  /// data, and tests use it to assert that every built-in chord is
  /// well-formed.
  String? validate() {
    if (stringPositions.length != 4) {
      return 'A ukulele voicing must have exactly 4 strings, '
          'got ${stringPositions.length}';
    }
    final Set<int> seenStringNumbers = <int>{};
    for (final ChordStringPosition pos in stringPositions) {
      if (pos.stringNumber < 1 || pos.stringNumber > 4) {
        return 'String number must be in 1..4, got ${pos.stringNumber}';
      }
      if (!seenStringNumbers.add(pos.stringNumber)) {
        return 'Duplicate string number: ${pos.stringNumber}';
      }
      final int? fret = pos.fret;
      if (fret != null) {
        if (fret < 0) {
          return 'Fret must be >= 0, got $fret';
        }
        if (fret > 0 && fret < startFret) {
          return 'Pressed fret $fret is below startFret $startFret '
              'on string ${pos.stringNumber}';
        }
      }
      if (pos.finger != null) {
        final int finger = pos.finger!;
        if (finger < 1 || finger > 4) {
          return 'Finger index must be in 1..4, got $finger';
        }
      }
      // An open or muted string must not have a finger index.
      if ((pos.isOpen || pos.isMuted) && pos.finger != null) {
        return 'String ${pos.stringNumber} is ${pos.isOpen ? "open" : "muted"} '
            'but has a finger index ${pos.finger}';
      }
    }
    return null;
  }

  /// Returns the position for [stringNumber] (1..4), or `null` if the
  /// voicing is malformed (defensive — well-formed voicings always
  /// return a value).
  ChordStringPosition? positionFor(int stringNumber) {
    for (final ChordStringPosition pos in stringPositions) {
      if (pos.stringNumber == stringNumber) {
        return pos;
      }
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChordFingering &&
          listEquals(other.stringPositions, stringPositions) &&
          other.startFret == startFret &&
          other.maxFretShown == maxFretShown);

  @override
  int get hashCode => Object.hash(
        Object.hashAll(stringPositions),
        startFret,
        maxFretShown,
      );
}
