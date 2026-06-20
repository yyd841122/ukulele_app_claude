// Repository contract for [PracticeRecord] persistence.
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
  /// - generating the UUID `id` if the caller did not supply one
  ///   (T013.2 callers always supply one — see below),
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
}
