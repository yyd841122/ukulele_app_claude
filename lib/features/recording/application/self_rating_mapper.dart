// SelfRating -> SelfAssessment mapping (T013.4A0_RECORDING_SAVE_FOUNDATION).
//
// Why a dedicated mapping function (rather than letting the
// `RecordingPracticeController` decide):
// - The vocabulary on the recording side
//   (`good` / `okay` / `retry`) is tuned for the in-session UX
//   — see `SelfRating` in `lib/features/recording/domain/`.
// - The vocabulary on the persistence side
//   (`good` / `neutral` / `needsImprovement`) is the stable
//   vocabulary stored in `practice_records.self_assessment` — see
//   `SelfAssessment` in `lib/features/practice_records/domain/`.
// - The Chief Architect ruling (T013.4A0 §7) keeps the mapping in
//   the `recording` feature's application layer so that the
//   `practice_records` domain NEVER depends on the `recording`
//   feature. The reverse dependency (`recording -> practice_records`
//   for the enum) is acceptable: persistence is a downstream
//   concern of any flow that produces a record.
//
// Contract:
// - This is a pure function — no Riverpod, no Repository, no DB,
//   no UI. It can be called from any context, including tests.
// - `null` in -> `null` out. The user may skip the self-rating
//   entirely; we MUST NOT coerce a missing rating into a default.
// - `SelfRating.good`     -> `SelfAssessment.good`
// - `SelfRating.okay`     -> `SelfAssessment.neutral`
// - `SelfRating.retry`    -> `SelfAssessment.needsImprovement`
//
// Out of scope for this task:
// - Saving the mapped assessment. T013.4A0 only lays the
//   vocabulary foundation; the recording save flow lives in
//   T013.4A.

import 'package:ukulele_app/features/practice_records/domain/self_assessment.dart';
import 'package:ukulele_app/features/recording/domain/self_rating.dart';

/// Maps a UI-facing [SelfRating] to the persisted
/// [SelfAssessment] enum.
///
/// Returns `null` when [rating] is `null` — a user that skipped the
/// self-rating step MUST NOT be coerced into a default bucket.
SelfAssessment? mapSelfRatingToSelfAssessment(SelfRating? rating) {
  if (rating == null) {
    return null;
  }
  switch (rating) {
    case SelfRating.good:
      return SelfAssessment.good;
    case SelfRating.okay:
      return SelfAssessment.neutral;
    case SelfRating.retry:
      return SelfAssessment.needsImprovement;
  }
}
