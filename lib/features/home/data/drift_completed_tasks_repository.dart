// Drift-backed implementation of [CompletedTasksRepository].
//
// T013.2 scope:
// - Serialises [DateTime] ↔ `YYYY-MM-DD` at the Repository
//   boundary; the schema stores the date as TEXT for human-readable
//   SQLite dumps and for "no timezone" safety (see
//   `lib/data/database/tables/completed_tasks_table.dart`).
// - `completedAt` is stored as a UTC `DateTime` because timestamps
//   always need timezone-aware arithmetic.
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
  String _formatLocalDate(DateTime d) {
    final DateTime midnight = DateTime(d.year, d.month, d.day);
    final String mm = midnight.month.toString().padLeft(2, '0');
    final String dd = midnight.day.toString().padLeft(2, '0');
    return '${midnight.year}-$mm-$dd';
  }
}
