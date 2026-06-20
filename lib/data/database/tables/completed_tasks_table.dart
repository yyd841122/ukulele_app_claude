// CompletedTasks table.
//
// T013.1 scope:
// - Schema-only. Repository / watch* APIs land in T013.2+.
// - Stores "task completed" flags keyed by local calendar date and
//   stable task id. The composite primary key `(localDate, taskId)`
//   is the architectural decision agreed in T013_PREP_LOCAL_PERSISTENCE_AUDIT
//   (Risk 1 in that report): when Day 1 comes around again on day 8,
//   the previous Day 1 completion does NOT bleed over — a fresh row
//   is written for the new localDate.
//
// Why `(localDate, taskId)` rather than `(dayIndex, taskId)`:
// - PRD §9 / DATA_MODEL_DRAFT.md §3.1 mandate that missing tasks do
//   NOT penalise the user nor shift the plan forward. Persisting by
//   `localDate` makes that rule mechanical: the new calendar day is
//   its own row, regardless of day index.
// - Drift's composite primary key + `insertMode: InsertMode.insertOrReplace`
//   (T013.2+ Repository concern) gives us "upsert by (localDate,taskId)"
//   for free.
//
// `completedAt` records the moment the user toggled the checkbox.
// It is NOT the primary key — the same `(localDate, taskId)` pair may
// theoretically be flipped multiple times (mark done → unmark → mark
// done again). `completedAt` is therefore updated alongside the
// row's existence on upsert.

import 'package:drift/drift.dart';

@DataClassName('CompletedTaskData')
class CompletedTasks extends Table {
  /// Local calendar date normalised to ISO-8601 `YYYY-MM-DD`. We use
  /// a `TEXT` column (rather than `INTEGER` epoch) because local
  /// dates do not have a timezone — comparing `"2026-06-20"` against
  /// `DateTime(2026, 6, 20)` would otherwise be a footgun. The
  /// Repository layer (T013.2+) is the single place that converts
  /// between `DateTime` ↔ ISO string.
  TextColumn get localDate => text()();

  /// Stable task id, e.g. `day1_tuner` (see
  /// `lib/features/home/domain/practice_task.dart`).
  TextColumn get taskId => text()();

  /// Moment the user toggled the checkbox most recently.
  DateTimeColumn get completedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {localDate, taskId};
}
