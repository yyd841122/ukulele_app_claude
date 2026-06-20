// Self-assessment bucket attached to a [PracticeRecord].
//
// T013.2 scope:
// - Mirrors DATA_MODEL_DRAFT.md §2.4. The enum is intentionally
//   separate from the recording-flow [SelfRating] (T012): the recording
//   page uses a three-way "good / okay / retry" choice that is tuned
//   for the in-session UI, while the persisted model uses
//   "good / neutral / needsImprovement" so the storage vocabulary
//   does not change when the recording UX is re-thought.
// - The conversion between the two enums is left to a future
//   "recording → practice record" task (T013.5+) — see
//   docs/dev/T013_PREP_LOCAL_PERSISTENCE_AUDIT.
// - Stored as the enum-case `name` string (not an `int` index) so
//   future enum re-orderings do not shift historical data.

/// Three-way self-assessment attached to a [PracticeRecord].
enum SelfAssessment {
  /// "好" — the session went well.
  good,

  /// "一般" — usable, but with rough spots.
  neutral,

  /// "需改进" — needs another attempt.
  needsImprovement,
}
