// Repository contract for completed-today's-task tracking.
//
// T013.2 scope:
// - CompletedTasks keys off `(localDate, taskId)` so that "Day 1
//   done on 2026-06-20" does NOT bleed over to the next Day 1 on
//   2026-06-27. See DATA_MODEL_DRAFT.md §7 and
//   `lib/data/database/tables/completed_tasks_table.dart`.
// - `localDate` is normalised to `YYYY-MM-DD` at the Repository
//   boundary. Callers pass a `DateTime`; the Repository converts it
//   to local-midnight then to the ISO string.
// - `completedAt` is stamped by the Repository as a UTC instant.

/// Persistence boundary for the per-day "task completed" flags.
abstract class CompletedTasksRepository {
  /// Returns the task ids that are marked completed for the given
  /// local [date]. The date is normalised to local-midnight.
  Future<Set<String>> getCompletedTaskIds(DateTime date);

  /// Streams the completed task ids for the given local [date].
  Stream<Set<String>> watchCompletedTaskIds(DateTime date);

  /// Marks [taskId] as completed on the given local [date] at
  /// [completedAt] (UTC). If a row with the same composite key
  /// already exists, it is replaced (upsert).
  Future<void> markCompleted({
    required DateTime date,
    required String taskId,
    required DateTime completedAt,
  });

  /// Removes the completion flag for [taskId] on the given local
  /// [date]. Returns `true` if a row was actually deleted.
  Future<bool> unmarkCompleted({
    required DateTime date,
    required String taskId,
  });
}
