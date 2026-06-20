// Drift-backed implementation of [CompletedTasksRepository].
//
// T013.2 scope:
// - Serialises [DateTime] ↔ `YYYY-MM-DD` at the Repository
//   boundary; the schema stores the date as TEXT for human-readable
//   SQLite dumps and for "no timezone" safety (see
//   `lib/data/database/tables/completed_tasks_table.dart`).
// - `completedAt` is stored as a UTC `DateTime` because timestamps
//   always need timezone-aware arithmetic.
//
// T013.2_FIX_REPOSITORY_SCOPE_AND_CONTRACTS — `localDate`
// contract:
// - `_formatLocalDate` always projects to the LOCAL wall clock
//   before extracting y/m/d. This guarantees that two
//   `DateTime`s representing the same instant on the same local
//   day always produce the same ISO string, regardless of whether
//   the caller passed a UTC or local DateTime.
import 'package:ukulele_app/data/database/app_database.dart';
import 'package:ukulele_app/features/home/data/completed_tasks_repository.dart';

/// Concrete [CompletedTasksRepository] backed by an [AppDatabase].
class DriftCompletedTasksRepository implements CompletedTasksRepository {
  DriftCompletedTasksRepository({required AppDatabase database})
      : _db = database;

  final AppDatabase _db;

  // --- Public API ---

  @override
  Future<Set<String>> getCompletedTaskIds(DateTime date) async {
    final String iso = _formatLocalDate(date);
    final List<CompletedTaskData> rows = await (_db.select(_db.completedTasks)
          ..where(($CompletedTasksTable t) => t.localDate.equals(iso)))
        .get();
    return <String>{for (final CompletedTaskData r in rows) r.taskId};
  }

  @override
  Stream<Set<String>> watchCompletedTaskIds(DateTime date) {
    final String iso = _formatLocalDate(date);
    final Stream<List<CompletedTaskData>> source = (_db.select(
      _db.completedTasks,
    )..where(($CompletedTasksTable t) => t.localDate.equals(iso)))
        .watch();
    return source.map(
      (List<CompletedTaskData> rows) =>
          <String>{for (final CompletedTaskData r in rows) r.taskId},
    );
  }

  @override
  Future<void> markCompleted({
    required DateTime date,
    required String taskId,
    required DateTime completedAt,
  }) async {
    if (taskId.isEmpty) {
      throw ArgumentError.value(taskId, 'taskId', 'taskId must not be empty');
    }
    final String iso = _formatLocalDate(date);
    final DateTime tsUtc = completedAt.toUtc();
    await _db.into(_db.completedTasks).insertOnConflictUpdate(
          CompletedTasksCompanion.insert(
            localDate: iso,
            taskId: taskId,
            completedAt: tsUtc,
          ),
        );
  }

  @override
  Future<bool> unmarkCompleted({
    required DateTime date,
    required String taskId,
  }) async {
    if (taskId.isEmpty) {
      throw ArgumentError.value(taskId, 'taskId', 'taskId must not be empty');
    }
    final String iso = _formatLocalDate(date);
    final int affected = await (_db.delete(_db.completedTasks)
          ..where(($CompletedTasksTable t) => t.localDate.equals(iso))
          ..where(($CompletedTasksTable t) => t.taskId.equals(taskId)))
        .go();
    return affected > 0;
  }

  // --- Internal helpers ---

  /// Formats [d] as a local-midnight ISO date `YYYY-MM-DD`. The
  /// time-of-day component is discarded — `CompletedTasks` is
  /// keyed by calendar day, not by instant.
  ///
  /// If the caller passes a `DateTime` flagged `isUtc`, the UTC
  /// wall-clock components are *not* the local calendar day the
  /// user expects. We always project to the local timezone first
  /// so a `DateTime.utc(2026, 6, 20, 23, 0)` (which is already
  /// the next day in CST) lands on `"2026-06-21"`, not
  /// `"2026-06-20"`.
  String _formatLocalDate(DateTime d) {
    final DateTime localD = d.isUtc ? d.toLocal() : d;
    final DateTime midnight = DateTime(localD.year, localD.month, localD.day);
    final String mm = midnight.month.toString().padLeft(2, '0');
    final String dd = midnight.day.toString().padLeft(2, '0');
    return '${midnight.year}-$mm-$dd';
  }
}
