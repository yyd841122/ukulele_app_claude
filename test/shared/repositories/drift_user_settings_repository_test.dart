// Tests for [DriftUserSettingsRepository] (T013.2).
//
// Strategy:
// - Each test gets its own in-memory database; the test owns its
//   lifecycle.
// - We pin `updatedAt` to a deterministic value so equality
//   comparisons are stable.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ukulele_app/data/database/app_database.dart';
import 'package:ukulele_app/shared/repositories/drift_user_settings_repository.dart';

void main() {
  ({AppDatabase db, DriftUserSettingsRepository repo}) setup() {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final DriftUserSettingsRepository repo =
        DriftUserSettingsRepository(database: db);
    return (db: db, repo: repo);
  }

  group('DriftUserSettingsRepository', () {
    test('getValue returns null for unknown key', () async {
      final ({AppDatabase db, DriftUserSettingsRepository repo}) ctx = setup();
      expect(await ctx.repo.getValue('app.installDate'), isNull);
    });

    test('setValue + getValue round-trips', () async {
      final ({AppDatabase db, DriftUserSettingsRepository repo}) ctx = setup();
      await ctx.repo.setValue(
        key: 'app.installDate',
        value: '2026-06-20T00:00:00Z',
        updatedAt: DateTime.utc(2026, 6, 20, 9),
      );
      expect(
        await ctx.repo.getValue('app.installDate'),
        '2026-06-20T00:00:00Z',
      );
    });

    test('setValue overwrites the existing value on the same key', () async {
      final ({AppDatabase db, DriftUserSettingsRepository repo}) ctx = setup();
      await ctx.repo.setValue(
        key: 'metronome.defaultBpm',
        value: '80',
        updatedAt: DateTime.utc(2026, 6, 20, 9),
      );
      await ctx.repo.setValue(
        key: 'metronome.defaultBpm',
        value: '120',
        updatedAt: DateTime.utc(2026, 6, 20, 11),
      );
      expect(
        await ctx.repo.getValue('metronome.defaultBpm'),
        '120',
      );
      // Only one row remains.
      final List<UserSettingData> rows =
          await ctx.db.select(ctx.db.userSettings).get();
      expect(rows, hasLength(1));
    });

    test('setValue preserves the wall-clock instant of updatedAt', () async {
      final ({AppDatabase db, DriftUserSettingsRepository repo}) ctx = setup();
      // Pass a local DateTime; the Repository must coerce to UTC
      // before storing. Drift's column type stores the unix-seconds
      // value, so a round-trip is only equal-by-instant. The
      // `isUtc` flag-flip behaviour depends on the Drift build, so
      // we assert on the instant, not the flag.
      final DateTime localStamp = DateTime(2026, 6, 20, 9);
      await ctx.repo.setValue(
        key: 'app.installDate',
        value: 'x',
        updatedAt: localStamp,
      );
      final List<UserSettingData> rows =
          await ctx.db.select(ctx.db.userSettings).get();
      expect(
        rows.single.updatedAt.millisecondsSinceEpoch,
        localStamp.toUtc().millisecondsSinceEpoch,
      );
    });

    test('deleteValue removes the row and returns true', () async {
      final ({AppDatabase db, DriftUserSettingsRepository repo}) ctx = setup();
      await ctx.repo.setValue(
        key: 'app.installDate',
        value: 'x',
        updatedAt: DateTime.utc(2026, 6, 20, 9),
      );
      expect(await ctx.repo.deleteValue('app.installDate'), isTrue);
      expect(await ctx.repo.getValue('app.installDate'), isNull);
    });

    test('deleteValue returns false when nothing matched', () async {
      final ({AppDatabase db, DriftUserSettingsRepository repo}) ctx = setup();
      expect(await ctx.repo.deleteValue('never-set'), isFalse);
    });

    test('rejects empty key on getValue', () async {
      final ({AppDatabase db, DriftUserSettingsRepository repo}) ctx = setup();
      expect(
        () => ctx.repo.getValue(''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects empty key on setValue', () async {
      final ({AppDatabase db, DriftUserSettingsRepository repo}) ctx = setup();
      expect(
        () => ctx.repo.setValue(
          key: '',
          value: 'x',
          updatedAt: DateTime.utc(2026, 6, 20, 9),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects empty key on deleteValue', () async {
      final ({AppDatabase db, DriftUserSettingsRepository repo}) ctx = setup();
      expect(
        () => ctx.repo.deleteValue(''),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
