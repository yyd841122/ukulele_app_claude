// Tests for [DriftCompletedTasksRepository] (T013.2).
//
// Strategy:
// - Each test gets its own in-memory database; the test owns its
//   lifecycle (the repository in T013.2 is consumed by tests
//   directly — no Riverpod override is exercised here).
// - Tests pin dates as `DateTime` (any time-of-day) and assert that
//   the Repository normalises them to local-midnight for storage.
// - Cross-day isolation is exercised explicitly: two different
//   `localDate` values must be treated as independent rows even
//   when the `taskId` is the same.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ukulele_app/data/database/app_database.dart';
import 'package:ukulele_app/features/home/data/drift_completed_tasks_repository.dart';

void main() {
  ({AppDatabase db, DriftCompletedTasksRepository repo}) setup() {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final DriftCompletedTasksRepository repo =
        DriftCompletedTasksRepository(database: db);
    return (db: db, repo: repo);
  }

  group('DriftCompletedTasksRepository', () {
    test('getCompletedTaskIds returns empty set for a fresh day', () async {
      final ({AppDatabase db, DriftCompletedTasksRepository repo}) ctx =
          setup();
      expect(
        await ctx.repo.getCompletedTaskIds(DateTime(2026, 6, 20)),
        isEmpty,
      );
    });

    test('markCompleted + getCompletedTaskIds round-trips within a day',
        () async {
      final ({AppDatabase db, DriftCompletedTasksRepository repo}) ctx =
          setup();
      final DateTime now = DateTime.utc(2026, 6, 20, 9, 30);
      await ctx.repo.markCompleted(
        date: DateTime(2026, 6, 20),
        taskId: 'day1_tuner',
        completedAt: now,
      );

      final Set<String> ids =
          await ctx.repo.getCompletedTaskIds(DateTime(2026, 6, 20));
      expect(ids, equals(<String>{'day1_tuner'}));
    });

    test('isolates rows by localDate (same taskId, different days)', () async {
      final ({AppDatabase db, DriftCompletedTasksRepository repo}) ctx =
          setup();
      await ctx.repo.markCompleted(
        date: DateTime(2026, 6, 20),
        taskId: 'day1_tuner',
        completedAt: DateTime.utc(2026, 6, 20, 9),
      );
      await ctx.repo.markCompleted(
        date: DateTime(2026, 6, 27),
        taskId: 'day1_tuner',
        completedAt: DateTime.utc(2026, 6, 27, 9),
      );

      final Set<String> day1 =
          await ctx.repo.getCompletedTaskIds(DateTime(2026, 6, 20));
      final Set<String> day8 =
          await ctx.repo.getCompletedTaskIds(DateTime(2026, 6, 27));
      expect(day1, equals(<String>{'day1_tuner'}));
      expect(day8, equals(<String>{'day1_tuner'}));
    });

    test('re-marking the same (date, taskId) upserts completedAt', () async {
      final ({AppDatabase db, DriftCompletedTasksRepository repo}) ctx =
          setup();
      final DateTime first = DateTime(2026, 6, 20, 9);
      final DateTime second = DateTime(2026, 6, 20, 11);
      await ctx.repo.markCompleted(
        date: DateTime(2026, 6, 20),
        taskId: 'day1_tuner',
        completedAt: first,
      );
      await ctx.repo.markCompleted(
        date: DateTime(2026, 6, 20),
        taskId: 'day1_tuner',
        completedAt: second,
      );

      // The set of ids is unchanged (still one row). Inspect the
      // underlying table to confirm the timestamp was updated.
      // Drift stores the unix-seconds value, so a wall-clock
      // comparison must use the instant, not the `isUtc` flag —
      // drift can flip the flag on read.
      final List<CompletedTaskData> rows =
          await ctx.db.select(ctx.db.completedTasks).get();
      expect(rows, hasLength(1));
      expect(rows.single.taskId, 'day1_tuner');
      expect(
        rows.single.completedAt.millisecondsSinceEpoch,
        second.millisecondsSinceEpoch,
      );
    });

    test('unmarkCompleted removes the row and returns true', () async {
      final ({AppDatabase db, DriftCompletedTasksRepository repo}) ctx =
          setup();
      await ctx.repo.markCompleted(
        date: DateTime(2026, 6, 20),
        taskId: 'day1_tuner',
        completedAt: DateTime.utc(2026, 6, 20, 9),
      );
      expect(
        await ctx.repo.unmarkCompleted(
          date: DateTime(2026, 6, 20),
          taskId: 'day1_tuner',
        ),
        isTrue,
      );
      expect(
        await ctx.repo.getCompletedTaskIds(DateTime(2026, 6, 20)),
        isEmpty,
      );
    });

    test('unmarkCompleted returns false when nothing matched', () async {
      final ({AppDatabase db, DriftCompletedTasksRepository repo}) ctx =
          setup();
      expect(
        await ctx.repo.unmarkCompleted(
          date: DateTime(2026, 6, 20),
          taskId: 'never-marked',
        ),
        isFalse,
      );
    });

    test('rejects empty taskId on markCompleted', () async {
      final ({AppDatabase db, DriftCompletedTasksRepository repo}) ctx =
          setup();
      expect(
        () => ctx.repo.markCompleted(
          date: DateTime(2026, 6, 20),
          taskId: '',
          completedAt: DateTime.utc(2026, 6, 20, 9),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects empty taskId on unmarkCompleted', () async {
      final ({AppDatabase db, DriftCompletedTasksRepository repo}) ctx =
          setup();
      expect(
        () => ctx.repo.unmarkCompleted(
          date: DateTime(2026, 6, 20),
          taskId: '',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('normalises localDate to local midnight', () async {
      final ({AppDatabase db, DriftCompletedTasksRepository repo}) ctx =
          setup();
      await ctx.repo.markCompleted(
        // Pass a time-of-day; the Repository must store "2026-06-20".
        date: DateTime(2026, 6, 20, 14, 23, 17),
        taskId: 'day1_tuner',
        completedAt: DateTime.utc(2026, 6, 20, 9),
      );

      final List<CompletedTaskData> rows =
          await ctx.db.select(ctx.db.completedTasks).get();
      expect(rows.single.localDate, '2026-06-20');
    });

    test('watchCompletedTaskIds emits the set for the given date', () async {
      final ({AppDatabase db, DriftCompletedTasksRepository repo}) ctx =
          setup();
      await ctx.repo.markCompleted(
        date: DateTime(2026, 6, 20),
        taskId: 'day1_tuner',
        completedAt: DateTime.utc(2026, 6, 20, 9),
      );
      await ctx.repo.markCompleted(
        date: DateTime(2026, 6, 20),
        taskId: 'day1_single_note',
        completedAt: DateTime.utc(2026, 6, 20, 10),
      );

      final List<Set<String>> emissions = await ctx.repo
          .watchCompletedTaskIds(DateTime(2026, 6, 20))
          .take(1)
          .toList();
      expect(emissions, hasLength(1));
      expect(
        emissions.single,
        equals(<String>{'day1_tuner', 'day1_single_note'}),
      );
    });

    test('watchCompletedTaskIds is isolated by localDate', () async {
      final ({AppDatabase db, DriftCompletedTasksRepository repo}) ctx =
          setup();
      await ctx.repo.markCompleted(
        date: DateTime(2026, 6, 20),
        taskId: 'day1_tuner',
        completedAt: DateTime.utc(2026, 6, 20, 9),
      );

      final List<Set<String>> emissions = await ctx.repo
          .watchCompletedTaskIds(DateTime(2026, 6, 27))
          .take(1)
          .toList();
      expect(emissions.single, isEmpty);
    });
  });
}
