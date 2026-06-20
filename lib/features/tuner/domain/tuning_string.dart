// Domain model for a single ukulele tuning instruction.
//
// T011 scope:
// - This is a *manual tuning guide* entry, not a real-tuner
//   data structure: there is no pitch / frequency / cents field,
//   and no audio capture is ever wired up. The model only carries
//   the string name, its [stringNumber], a beginner tip and a
//   common-mistake warning.
// - [stringNumber] semantics match T008 / T009:
//     1 = A string
//     2 = E string
//     3 = C string
//     4 = G string
//   The *display* order is G, C, E, A (from the player's
//   perspective, top to bottom / leftmost to rightmost in a
//   chord chart). The data module exposes
//   [kTuningStringDisplayOrder] for that.
// - The MVP ships exactly one tuning preset — standard high-G
//   re-entrant G-C-E-A. No low-G, no baritone, no D-G-B-D.
//   A future task can introduce a [UkuleleTuningPreset] enum
//   without touching this model.

import 'package:flutter/foundation.dart';

/// A single ukulele string in a manual tuning guide.
@immutable
class TuningString {
  const TuningString({
    required this.stringNumber,
    required this.stringName,
    required this.displayName,
    required this.description,
    required this.beginnerTip,
    required this.commonMistake,
  });

  /// 1-based string index. 1 = A, 2 = E, 3 = C, 4 = G on a
  /// standard high-G ukulele. See file-level docs.
  final int stringNumber;

  /// Friendly string name shown in the UI, e.g. `"G"`, `"C"`,
  /// `"E"`, `"A"`.
  final String stringName;

  /// Pre-formatted label used on the card header,
  /// e.g. `"4 弦 · G"`.
  final String displayName;

  /// One-sentence plain description aimed at absolute beginners.
  final String description;

  /// A short, actionable tuning tip for this specific string.
  final String beginnerTip;

  /// The most common mistake beginners make when tuning this
  /// string. Surfaced so the UI can warn before the user
  /// over-tunes and breaks the string.
  final String commonMistake;

  /// Light-weight structural validator. Returns the first error
  /// message it finds, or `null` if the string is renderable.
  ///
  /// We do not throw — the built-in data module uses this to
  /// gate bad data, and tests use it to assert every shipped
  /// string is well-formed.
  String? validate() {
    if (stringNumber < 1 || stringNumber > 4) {
      return 'String number must be in 1..4, got $stringNumber';
    }
    if (stringName.isEmpty) {
      return 'String name must not be empty';
    }
    if (displayName.isEmpty) {
      return 'Display name must not be empty';
    }
    if (description.isEmpty) {
      return 'Description must not be empty';
    }
    if (beginnerTip.isEmpty) {
      return 'Beginner tip must not be empty';
    }
    if (commonMistake.isEmpty) {
      return 'Common mistake must not be empty';
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TuningString &&
          other.stringNumber == stringNumber &&
          other.stringName == stringName &&
          other.displayName == displayName &&
          other.description == description &&
          other.beginnerTip == beginnerTip &&
          other.commonMistake == commonMistake);

  @override
  int get hashCode => Object.hash(
        stringNumber,
        stringName,
        displayName,
        description,
        beginnerTip,
        commonMistake,
      );
}