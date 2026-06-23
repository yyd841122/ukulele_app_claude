// Repository contract for [PracticeRecord] persistence.
//
// T013.4A0_RECORDING_SAVE_FOUNDATION — ID ownership:
// - `PracticeRecord.id` is a UUID v4 string. The Repository is NOT
//   responsible for generating it. IDs are minted by the
//   application / use-case layer via
//   `PracticeRecordIdGenerator` (see
//   `lib/features/practice_records/application/practice_record_id_generator.dart`)
//   BEFORE this Repository is called.
// - `insert(...)` validates that `record.id` is non-empty and
//   persists it verbatim. It does NOT auto-generate an id, does
//   NOT call any ID generator, and does NOT inspect the caller
//   for a missing id. An empty `id` is a contract violation and
//   results in `ArgumentError`.
//
// T013.2 scope:
// - Repository is the SINGLE data-conversion boundary. UI /
//   Controllers only see [PracticeRecord]; they never touch
//   `PracticeRecordData` (the Drift-generated row class) or raw
//   JSON / ISO strings.
// - The contract deliberately does NOT expose an `update` method:
//   per task brief §7, "PracticeRecord 创建后不提供修改自评/备注
//   的 update API". If a future task needs to revise a record, it
//   must delete + insert instead.
// - `watchAll` returns a reactive stream so the UI can react to
//   changes without polling; `listRecent` is a one-shot snapshot for
//   callers that don't need live updates.

import 'package:ukulele_app/features/practice_records/domain/practice_record.dart';

/// Persistence boundary for [PracticeRecord]s.
abstract class PracticeRecordRepository {
  /// Persists [record] and returns the stored copy.
  ///
  /// The Repository is responsible for:
  /// - validating that [PracticeRecord.id] is non-empty (the id
  ///   was minted upstream by `PracticeRecordIdGenerator`; the
  ///   Repository NEVER generates or fabricates one),
  /// - normalising `practiceDate` to local-midnight,
  /// - stamping `createdAt` / `updatedAt` to the current UTC instant,
  /// - serialising `practiceTags` via `jsonEncode`.
  ///
  /// Throws [ArgumentError] when required fields violate the
  /// documented invariants (see DATA_MODEL_DRAFT.md §2.1 and §13.1):
  /// empty `id`, empty `practiceContent`, negative `durationSeconds`,
  /// or `dayIndex` outside `1..7`.
  Future<PracticeRecord> insert(PracticeRecord record);

  /// Returns the record with [id] or `null` if no such row exists.
  Future<PracticeRecord?> getById(String id);

  /// Returns up to [limit] most-recent records, ordered by
  /// `practiceDate DESC, createdAt DESC`.
  Future<List<PracticeRecord>> listRecent({int limit = 50});

  /// Streams ALL records, ordered by `practiceDate DESC,
  /// createdAt DESC`.
  Stream<List<PracticeRecord>> watchAll();

  /// Removes the record with [id]. Returns `true` if a row was
  /// actually deleted, `false` otherwise.
  Future<bool> delete(String id);

  /// Returns `true` iff at least one row in `practice_records`
  /// references [audioFilePath] verbatim (the persisted string is
  /// byte-for-byte equal to the argument).
  ///
  /// **T034 contract — application-layer audio file cleanup**:
  /// - The Repository is a pure persistence boundary and **does
  ///   NOT** touch the file system. This method is read-only and
  ///   exists so the application layer can decide whether the
  ///   on-disk audio file is still referenced by ANY record
  ///   before cleaning it up. A path shared by multiple records
  ///   is never deleted while at least one referencing record
  ///   survives.
  /// - The comparison is **verbatim** — no `TRIM()`, no
  ///   `LOWER()`, no canonicalisation, no `LIKE`. Two records
  ///   whose `audioFilePath` differ only by a trailing slash,
  ///   a different case, or a `..` segment are NOT considered
  ///   to reference the same file.
  /// - Empty / null input is rejected with [ArgumentError], same
  ///   rationale as [delete] (the Repository is not a place for
  ///   "what if?" queries on invalid data).
  /// - This is a counting query (`SELECT EXISTS(...)`) — the
  ///   application layer only needs the boolean answer.
  Future<bool> hasAudioPathReference(String audioFilePath);
}
