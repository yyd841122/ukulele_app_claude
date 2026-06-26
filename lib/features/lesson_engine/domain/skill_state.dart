// Lesson Engine — Adaptive Skill Model (T057_ADAPTIVE_LEARNING_SYSTEM).
//
// What this file is:
// - The T057 value layer that captures the user's per-skill
//   mastery as three independent axes:
//     * `rhythm`   — ability to follow a metronome / BPM
//     * `chord`    — ability to play chords
//     * `note`     — ability to play single notes
//   Each axis is a double in [0.0, 1.0] where 0.0 means
//   "untouched" and 1.0 means "fully mastered".
//
// Why a separate domain file:
// - The T055/T056 layers deal with *tasks* and *tools*. T057 deals
//   with *mastery*. Mixing the two in `lesson.dart` would force
//   every consumer of Lesson / LessonTask to import the skill
//   model whether they care about it or not. Keeping the Skill
//   State in its own file makes the dependency one-way: the
//   adaptive policy depends on Lesson (to know what tasks exist)
//   but the existing lesson surface does NOT depend on
//   `SkillState`.
//
// Design notes:
// - `SkillState` is `@immutable`, value-equality, and `const`-
//   constructible. The adaptive policy always returns a NEW
//   state instead of mutating in place — that way the policy
//   can be unit-tested as a pure function.
// - The "untouched" state is `(0, 0, 0)`. We do NOT default to
//   `0.5` because the policy needs a clean signal that
//   "no evidence has arrived yet" (the difficulty selector
//   interprets 0.0 as "no data, give a moderate default task").
// - The three axes are independent. A user can have rhythm=0.8
//   and chord=0.1 at the same time. We deliberately do NOT
//   model a single "overall" score; the policy itself rolls the
//   three axes up when it needs to (see `overall()`).

import 'package:flutter/foundation.dart';

/// Per-skill mastery snapshot for the adaptive policy.
///
/// T057 contract:
/// - All three axes are in [0.0, 1.0]. The [clamp] constructor
///   enforces this so the policy can never accidentally feed
///   out-of-range scores into the difficulty selector.
/// - Instances are immutable. The [SkillTracker] in the
///   application layer always returns a new state from
///   `recordOutcome`.
/// - Equality is value-based: two `SkillState`s with the same
///   three axes are equal regardless of how they were built.
@immutable
class SkillState {
  /// Creates a [SkillState] from raw axis values. Asserts each
  /// axis is in [0.0, 1.0] so a programming error in the
  /// tracker surfaces at the construction site rather than
  /// deeper inside the policy.
  const SkillState({
    required this.rhythm,
    required this.chord,
    required this.note,
  })  : assert(rhythm >= 0.0 && rhythm <= 1.0,
            'SkillState.rhythm must be in 0.0..1.0; got $rhythm'),
        assert(chord >= 0.0 && chord <= 1.0,
            'SkillState.chord must be in 0.0..1.0; got $chord'),
        assert(note >= 0.0 && note <= 1.0,
            'SkillState.note must be in 0.0..1.0; got $note');

  /// The "no evidence yet" state. Used as the seed the
  /// [SkillTracker] starts from on a fresh install.
  static const SkillState initial = SkillState(
    rhythm: 0.0,
    chord: 0.0,
    note: 0.0,
  );

  /// Metronome / BPM-following mastery. 0.0 = no evidence,
  /// 1.0 = full mastery.
  final double rhythm;

  /// Chord-playing mastery. Independent of `rhythm` / `note`.
  final double chord;

  /// Single-note mastery. Independent of `rhythm` / `chord`.
  final double note;

  /// The simple average of the three axes. The adaptive
  /// policy uses this as a "global" signal when it does not
  /// need per-axis detail. Always in [0.0, 1.0] because the
  /// three axes already are.
  double get overall => (rhythm + chord + note) / 3.0;

  /// Returns a NEW [SkillState] with the named axis replaced.
  /// Out-of-range values are clamped to [0.0, 1.0] so the
  /// tracker can pass raw deltas without first sanitising them.
  SkillState withAxis({
    double? rhythm,
    double? chord,
    double? note,
  }) {
    return SkillState(
      rhythm: _clamp01(rhythm ?? this.rhythm),
      chord: _clamp01(chord ?? this.chord),
      note: _clamp01(note ?? this.note),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SkillState &&
          other.rhythm == rhythm &&
          other.chord == chord &&
          other.note == note);

  @override
  int get hashCode => Object.hash(rhythm, chord, note);

  @override
  String toString() =>
      'SkillState(rhythm: ${rhythm.toStringAsFixed(2)}, '
      'chord: ${chord.toStringAsFixed(2)}, '
      'note: ${note.toStringAsFixed(2)})';

  static double _clamp01(double v) {
    if (v.isNaN) return 0.0;
    if (v < 0.0) return 0.0;
    if (v > 1.0) return 1.0;
    return v;
  }
}
