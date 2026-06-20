// Immutable domain model for a single practice record.
//
// T013.4A0_RECORDING_SAVE_FOUNDATION — ID ownership:
// - `PracticeRecord.id` MUST be a UUID v4 string.
// - IDs are minted by the application / use-case layer (see
//   `lib/features/practice_records/application/practice_record_id_generator.dart`)
//   BEFORE this struct is constructed and handed to the
//   Repository. The Repository NEVER generates IDs — it only
//   validates that `id` is non-empty and persists it verbatim.
// - Callers MUST NOT pass an empty `id`. The Repository will
//   throw `ArgumentError`.
//
// T013.2 scope:
// - This is the *domain* model — the Drift-generated row class is
//   `PracticeRecordData` (see `lib/data/database/app_database.g.dart`).
//   The two types are kept apart on purpose per
//   `docs/DATA_MODEL_DRAFT.md` §13.1: the Repository layer is the
//   SINGLE place that converts between them.
// - The domain model is a plain immutable class (no freezed, no
//   json_serializable) because T013.2 is a persistence foundation
//   task and adding codegen would be out of scope.
// - Field semantics mirror the Drift schema verbatim. Two pieces
//   require normalisation that the Repository applies:
//     * `practiceDate` — must be local-midnight.
//     * `createdAt` / `updatedAt` — UTC timestamps owned by the
//       Repository, not by the caller.
//
// T013.2_FIX_REPOSITORY_SCOPE_AND_CONTRACTS — immutability
// hardening:
// - The constructor no longer accepts a `const` because we must
//   defensively copy the incoming `practiceTags` list (the previous
//   implementation allowed callers to mutate the list after the
//   fact, defeating the `final` field). The Repository wraps the
//   incoming list in `List<PracticeTag>.unmodifiable(...)` before
//   constructing, so the resulting field is guaranteed immutable.
// - Tests pin the post-construction mutability contract.

import 'package:flutter/foundation.dart';

import 'package:ukulele_app/features/practice_records/domain/practice_tag.dart';
import 'package:ukulele_app/features/practice_records/domain/practice_type.dart';
import 'package:ukulele_app/features/practice_records/domain/self_assessment.dart';

/// One persisted practice session.
///
/// Construct via the Repository, not directly — see
/// [lib/features/practice_records/data/practice_record_repository.dart].
/// The Repository guarantees that the [practiceTags] list is
/// unmodifiable; tests pin this contract.
@immutable
class PracticeRecord {
  PracticeRecord({
    required this.id,
    required this.practiceDate,
    required this.dayIndex,
    required this.primaryPracticeType,
    required List<PracticeTag> practiceTags,
    required this.practiceContent,
    required this.durationSeconds,
    required this.isCompleted,
    this.selfAssessment,
    this.audioFilePath,
    required this.createdAt,
    required this.updatedAt,
  }) : practiceTags = List<PracticeTag>.unmodifiable(practiceTags);

  /// UUID v4 string. Minted by the application / use-case layer
  /// (see `PracticeRecordIdGenerator`) BEFORE this struct is
  /// constructed and handed to the Repository. The Repository
  /// MUST NOT generate IDs and MUST NOT auto-generate one when
  /// the caller leaves this empty — passing an empty `id` is a
  /// contract violation and the Repository will reject it.
  final String id;

  /// Local-date of the session, normalised to local midnight by the
  /// Repository on insert / read.
  final DateTime practiceDate;

  /// 1-based day index in the 7-day cycle. Always in 1..7.
  final int dayIndex;

  /// Primary practice type.
  final PracticeType primaryPracticeType;

  /// Extra tags (tuner / singleNote / ...). May be empty. The list
  /// is always unmodifiable; mutating it throws `UnsupportedError`.
  final List<PracticeTag> practiceTags;

  /// Human-readable description of what the user practised.
  final String practiceContent;

  /// Total practice duration in seconds. Always >= 0.
  final int durationSeconds;

  /// Whether the user marked the session as completed.
  final bool isCompleted;

  /// Optional self-assessment. `null` if the user skipped it.
  final SelfAssessment? selfAssessment;

  /// Optional relative path to a recording file. `null` if no
  /// recording is attached.
  final String? audioFilePath;

  /// UTC timestamp at insert time.
  final DateTime createdAt;

  /// UTC timestamp of the last write. For T013.2 this equals
  /// [createdAt] — there is no `update` API.
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PracticeRecord &&
          other.id == id &&
          other.practiceDate == practiceDate &&
          other.dayIndex == dayIndex &&
          other.primaryPracticeType == primaryPracticeType &&
          _listEquals(other.practiceTags, practiceTags) &&
          other.practiceContent == practiceContent &&
          other.durationSeconds == durationSeconds &&
          other.isCompleted == isCompleted &&
          other.selfAssessment == selfAssessment &&
          other.audioFilePath == audioFilePath &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt);

  @override
  int get hashCode => Object.hash(
        id,
        practiceDate,
        dayIndex,
        primaryPracticeType,
        Object.hashAll(practiceTags),
        practiceContent,
        durationSeconds,
        isCompleted,
        selfAssessment,
        audioFilePath,
        createdAt,
        updatedAt,
      );
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
