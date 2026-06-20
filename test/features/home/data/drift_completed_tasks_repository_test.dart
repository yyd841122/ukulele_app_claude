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
//
// T013.2_FIX_REPOSITORY_SCOPE_AND_CONTRACTS additions:
// - Watch subscription tests drive writes AFTER subscribing and
//   verify the live emissions, not just the first snapshot.
// - UTC date-boundary tests pin that a `DateTime.utc(...)` input
//   is interpreted in the LOCAL calendar day, not the UTC one.
// - Other-date writes must NOT bleed into a different-date
//   subscription.

import 'dart:async';

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

    test('watchCompletedTaskIds emits post-subscribe marks and unmarks',
        () async {
      // T013.2_FIX_REPOSITORY_SCOPE_AND_CONTRACTS: subscribe first
      // (empty set), then mark / unmark on the same date and
      // verify each subsequent emission. We poll the `emissions`
      // list rather than relying on `Future.delayed` so the test
      // is robust against scheduling jitter.
      final ({AppDatabase db, DriftCompletedTasksRepository repo}) ctx =
          setup();
      final List<Set<String>> emissions = <Set<String>>[];
      final StreamSubscription<Set<String>> sub = ctx.repo
          .watchCompletedTaskIds(DateTime(2026, 6, 20))
          .listen(emissions.add);
      addTearDown(sub.cancel);

      // Drain the very first emission (empty set).
      await _waitForEmissions(emissions, hasLength: 1);
      expect(emissions.single, isEmpty);

      // Mark → second emission contains the taskId.
      await ctx.repo.markCompleted(
        date: DateTime(2026, 6, 20),
        taskId: 'day1_tuner',
        completedAt: DateTime.utc(2026, 6, 20, 9),
      );
      await _waitForEmissions(emissions, hasLength: 2);
      expect(emissions[1], equals(<String>{'day1_tuner'}));

      // Mark a second task → third emission contains both.
      await ctx.repo.markCompleted(
        date: DateTime(2026, 6, 20),
        taskId: 'day1_single_note',
        completedAt: DateTime.utc(2026, 6, 20, 10),
      );
      await _waitForEmissions(emissions, hasLength: 3);
      expect(
        emissions[2],
        equals(<String>{'day1_tuner', 'day1_single_note'}),
      );

      // Unmark → fourth emission drops back to a single taskId.
      await ctx.repo.unmarkCompleted(
        date: DateTime(2026, 6, 20),
        taskId: 'day1_tuner',
      );
      await _waitForEmissions(emissions, hasLength: 4);
      expect(emissions[3], equals(<String>{'day1_single_note'}));

      // Unmark the last one → final emission is empty.
      await ctx.repo.unmarkCompleted(
        date: DateTime(2026, 6, 20),
        taskId: 'day1_single_note',
      );
      await _waitForEmissions(emissions, hasLength: 5);
      expect(emissions[4], isEmpty);
    });

    test(
        'watchCompletedTaskIds subscription does not see writes on other dates',
        () async {
      final ({AppDatabase db, DriftCompletedTasksRepository repo}) ctx =
          setup();
      final List<Set<String>> emissions = <Set<String>>[];
      final StreamSubscription<Set<String>> sub = ctx.repo
          .watchCompletedTaskIds(DateTime(2026, 6, 20))
          .listen(emissions.add);
      addTearDown(sub.cancel);

      // Drain the initial empty emission.
      await _waitForEmissions(emissions, hasLength: 1);

      // Write on a DIFFERENT date. The subscription must NOT emit
      // a non-empty set — the row is for 2026-06-27, not 2026-06-20.
      await ctx.repo.markCompleted(
        date: DateTime(2026, 6, 27),
        taskId: 'day1_tuner',
        completedAt: DateTime.utc(2026, 6, 27, 9),
      );
      // Give the stream a window to (potentially) emit, then
      // assert the last known state is still empty for the
      // 2026-06-20 subscription.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(emissions.last, isEmpty);
    });

    test('localDate is interpreted as the LOCAL calendar day, not the UTC one',
        () async {
      // T013.2_FIX_REPOSITORY_SCOPE_AND_CONTRACTS: a UTC DateTime
      // near the local-midnight boundary must be projected to the
      // local calendar day before being stored. We pick a UTC
      // instant that is already the NEXT local day in CST (+08):
      // `2026-06-20T20:00:00Z` is `2026-06-21T04:00:00` locally.
      final ({AppDatabase db, DriftCompletedTasksRepository repo}) ctx =
          setup();
      await ctx.repo.markCompleted(
        date: DateTime.utc(2026, 6, 20, 20),
        taskId: 'boundary',
        completedAt: DateTime.utc(2026, 6, 20, 20),
      );
      final List<CompletedTaskData> rows =
          await ctx.db.select(ctx.db.completedTasks).get();
      expect(rows, hasLength(1));
      // The stored localDate must reflect the LOCAL day, not the
      // UTC day. In any timezone east of UTC, this is "2026-06-21";
      // in any timezone west of UTC, this is "2026-06-20". The
      // Repository's contract is "the local calendar day", so we
      // assert by *deriving* the expected value from the same
      // projection the Repository uses.
      final DateTime expectedLocal = DateTime.utc(2026, 6, 20, 20).toLocal();
      final String expectedIso = _expectedLocalIso(expectedLocal);
      expect(rows.single.localDate, expectedIso);
    });
  });
}

/// Replicates `_formatLocalDate` semantics so the test can
/// derive the expected `YYYY-MM-DD` value from the same
/// `toLocal()` projection the Repository performs. Kept private
/// to this file so the test never relies on the Repository's
/// private helper.
String _expectedLocalIso(DateTime d) {
  final DateTime local = d.isUtc ? d.toLocal() : d;
  final DateTime midnight = DateTime(local.year, local.month, local.day);
  final String mm = midnight.month.toString().padLeft(2, '0');
  final String dd = midnight.day.toString().padLeft(2, '0');
  return '${midnight.year}-$mm-$dd';
}

/// Polls [emissions] until it reaches [hasLength] entries. Drift's
/// watch streams are async; the test driver must wait for the
/// table-update notification to round-trip before asserting on the
/// latest emission.
Future<void> _waitForEmissions(
  List<Set<String>> emissions, {
  required int hasLength,
}) async {
  final DateTime deadline = DateTime.now().add(const Duration(seconds: 2));
  while (emissions.length < hasLength) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for emission #$hasLength '
          '(saw ${emissions.length})');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
