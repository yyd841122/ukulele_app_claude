// Tests for [DriftInstallDateService] (T013.3).
//
// Strategy:
// - Each test owns its in-memory database and closes it on
//   teardown. The single-flight guard is reset implicitly by
//   constructing a fresh service per test, so tests cannot
//   leak in-flight writes to each other.
// - Concurrency tests use `Future.wait` to fire N callers
//   simultaneously and assert that only ONE row gets written
//   to the DB — this is the core contract of single-flight.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ukulele_app/data/database/app_database.dart';
import 'package:ukulele_app/shared/services/drift_install_date_service.dart';

void main() {
  ({AppDatabase db, DriftInstallDateService service}) setup({
    DateTime Function()? clock,
  }) {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final DriftInstallDateService service = DriftInstallDateService(
      database: db,
      clock: clock,
    );
    return (db: db, service: service);
  }

  group('DriftInstallDateService', () {
    test('first call persists the current UTC instant', () async {
      final DateTime fixed = DateTime.utc(2026, 6, 20, 9);
      final ({AppDatabase db, DriftInstallDateService service}) ctx = setup(
        clock: () => fixed,
      );
      final DateTime result = await ctx.service.getInstallDate();
      expect(result.toUtc(), fixed);
      // A row was written.
      final List<UserSettingData> rows =
          await ctx.db.select(ctx.db.userSettings).get();
      expect(rows, hasLength(1));
      expect(rows.single.key, kInstallDateKey);
      expect(rows.single.value, fixed.toIso8601String());
    });

    test('second call returns the persisted value without rewriting', () async {
      final DateTime first = DateTime.utc(2026, 6, 20, 9);
      final ({AppDatabase db, DriftInstallDateService service}) ctx = setup(
        clock: () => first,
      );
      await ctx.service.getInstallDate();
      // Same instance, but a different "now". The service must NOT
      // re-record.
      final DateTime second = DateTime.utc(2026, 6, 21, 12);
      final DriftInstallDateService sameClock =
          DriftInstallDateService(database: ctx.db, clock: () => second);
      final DateTime result = await sameClock.getInstallDate();
      expect(result.toUtc(), first);
      // Still one row, untouched.
      final List<UserSettingData> rows =
          await ctx.db.select(ctx.db.userSettings).get();
      expect(rows, hasLength(1));
    });

    test('a brand-new service against an existing DB reads the same date',
        () async {
      final DateTime first = DateTime.utc(2026, 6, 20, 9);
      // First service: writes the install date.
      final ({AppDatabase db, DriftInstallDateService service}) ctx = setup(
        clock: () => first,
      );
      await ctx.service.getInstallDate();
      // Second service, same DB (cold-start simulation):
      final DriftInstallDateService fresh = DriftInstallDateService(
        database: ctx.db,
      );
      final DateTime result = await fresh.getInstallDate();
      expect(result.toUtc(), first);
    });

    test('concurrent first-launch calls write exactly one row', () async {
      // Pin the clock so all N concurrent callers would otherwise
      // compute the same instant — but only ONE row may land.
      final DateTime fixed = DateTime.utc(2026, 6, 20, 9);
      final ({AppDatabase db, DriftInstallDateService service}) ctx = setup(
        clock: () => fixed,
      );
      final List<Future<DateTime>> calls = <Future<DateTime>>[
        for (int i = 0; i < 10; i++) ctx.service.getInstallDate(),
      ];
      final List<DateTime> results = await Future.wait(calls);
      // All callers see the same instant.
      for (final DateTime r in results) {
        expect(r.toUtc(), fixed);
      }
      // ... and only one DB row exists.
      final List<UserSettingData> rows =
          await ctx.db.select(ctx.db.userSettings).get();
      expect(rows, hasLength(1));
    });

    test('throws FormatException when the persisted value is not ISO-8601',
        () async {
      final ({AppDatabase db, DriftInstallDateService service}) ctx = setup();
      // Pre-seed the DB with garbage.
      await ctx.db.into(ctx.db.userSettings).insertOnConflictUpdate(
            UserSettingsCompanion.insert(
              key: kInstallDateKey,
              value: 'not-a-date',
              updatedAt: DateTime.utc(2026, 6, 20, 9),
            ),
          );
      expect(
        () => ctx.service.getInstallDate(),
        throwsA(isA<FormatException>()),
      );
      // The bad row is NOT silently overwritten.
      final List<UserSettingData> rows =
          await ctx.db.select(ctx.db.userSettings).get();
      expect(rows, hasLength(1));
      expect(rows.single.value, 'not-a-date');
    });

    test('a failed parse does not leave the single-flight slot stuck',
        () async {
      // After a FormatException the next call must be able to
      // retry the DB — otherwise a one-time corruption would
      // permanently brick the install-date path.
      final ({AppDatabase db, DriftInstallDateService service}) ctx = setup();
      await ctx.db.into(ctx.db.userSettings).insertOnConflictUpdate(
            UserSettingsCompanion.insert(
              key: kInstallDateKey,
              value: 'garbage-1',
              updatedAt: DateTime.utc(2026, 6, 20, 9),
            ),
          );
      await expectLater(
        ctx.service.getInstallDate(),
        throwsA(isA<FormatException>()),
      );
      // Repair the row, then call again — this MUST succeed and
      // return the repaired value.
      await ctx.db.into(ctx.db.userSettings).insertOnConflictUpdate(
            UserSettingsCompanion.insert(
              key: kInstallDateKey,
              value: DateTime.utc(2026, 6, 20, 9).toIso8601String(),
              updatedAt: DateTime.utc(2026, 6, 20, 10),
            ),
          );
      final DateTime ok = await ctx.service.getInstallDate();
      expect(ok.toUtc(), DateTime.utc(2026, 6, 20, 9));
    });
  });
}
