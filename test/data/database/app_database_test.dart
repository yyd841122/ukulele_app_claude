// Tests for [AppDatabase] (T013.1, T032).
//
// Strategy:
// - All tests use `AppDatabase.forTesting(NativeDatabase.memory())`,
//   so each test starts from an empty schema and cannot leak state
//   to siblings.
// - We assert on the generated row classes (`PracticeRecordData`,
//   `UserSettingData`, `CompletedTaskData`) — this doubles as a
//   smoke test for the Drift codegen output.
// - T032 bump: `schemaVersion` is now 2 (was 1 in T013.1). The
//   schema-version pin test below reflects the post-T032 value.
// - We deliberately do NOT test the production constructor (which
//   calls `path_provider`); that path requires a Flutter binding and
//   is exercised by the widget_test.dart full-App smoke test in
//   T013.3+ when `appDatabaseProvider` is wired in.

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ukulele_app/data/database/app_database.dart';

void main() {
  // -------- schema_version ------

  group('AppDatabase schema', () {
    test('schemaVersion is exactly 2', () {
      // T032_REAL_AUDIO_PRACTICE_RECORD_SCHEMA_UPGRADE bumped
      // schemaVersion from 1 → 2 to mark the "real audio
      // persistence phase" schema-evolution anchor. The on-disk
      // layout is unchanged (audio_file_path was already nullable
      // in v1); the bump is a contract-only marker so future
      // migrations (T033+) can stack after v2.
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      expect(db.schemaVersion, 2);
    });

    test('onCreate produces all three MVP tables', () async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      // After open, the initial migration has run. Inspect the table
      // list via Drift's introspection to confirm the three tables
      // exist with the documented names.
      final List<String> names = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' "
            "ORDER BY name;",
            readsFrom: <ResultSetImplementation<dynamic, dynamic>>{},
          )
          .map((QueryRow row) => row.read<String>('name'))
          .get();

      // We only assert on our three documented app tables.
      expect(names, contains('practice_records'));
      expect(names, contains('user_settings'));
      expect(names, contains('completed_tasks'));
    });

    test(
        'practice_records.audio_file_path is part of the v2 schema '
        '(nullable TEXT column)', () async {
      // T032 contract pin: the column must already exist on disk
      // after onCreate so v2 is forward-compatible with code that
      // writes non-null audio paths. The column was already
      // declared nullable in v1 (T013.1 reserved it for the
      // "real audio phase"); the v2 schema-evolution anchor
      // exists so we can track "this is the version that
      // officially wires audio persistence into the contract".
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      // Force the lazy open so onCreate runs.
      await db.customSelect('SELECT 1').get();

      final List<QueryRow> cols = await db
          .customSelect(
            "SELECT name, type, \"notnull\" FROM pragma_table_info("
            "'practice_records') WHERE name = 'audio_file_path';",
          )
          .get();
      expect(cols, hasLength(1),
          reason: 'practice_records.audio_file_path must exist on disk');
      final QueryRow row = cols.single;
      expect(row.read<String>('name'), 'audio_file_path');
      expect(row.read<String>('type'), 'TEXT');
      // `notnull == 0` means the column is nullable in SQLite.
      expect(row.read<int>('notnull'), 0,
          reason: 'audio_file_path must remain nullable so old rows '
              'survive the v1 → v2 migration with audioFilePath = null');
    });

    test(
        'fresh install lands at user_version = 2 '
        '(onCreate writes the current schemaVersion)', () async {
      // T032 contract pin: a fresh install (no prior DB on disk)
      // must reach schemaVersion = 2 immediately after onCreate.
      // Drift writes `user_version` from the `schemaVersion`
      // field at the end of onCreate, so this verifies the v2
      // schema-evolution anchor is "first install" compatible
      // without needing onUpgrade to fire.
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await db.customSelect('SELECT 1').get();
      final int userVersion = await db
          .customSelect('PRAGMA user_version;')
          .map((QueryRow row) => row.read<int>('user_version'))
          .getSingle();
      expect(userVersion, 2,
          reason: 'fresh install must write user_version = '
              'schemaVersion (= 2) after onCreate');
    });
  });

  // -------- UserSettings ------

  group('UserSettings round-trip', () {
    test('insert a key/value row and read it back', () async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final DateTime now = DateTime(2026, 6, 20, 9);
      await db.into(db.userSettings).insert(
            UserSettingsCompanion.insert(
              key: 'app.installDate',
              value: '2026-06-20T00:00:00Z',
              updatedAt: now,
            ),
          );

      final List<UserSettingData> rows = await db.select(db.userSettings).get();
      expect(rows, hasLength(1));
      expect(rows.single.key, 'app.installDate');
      expect(rows.single.value, '2026-06-20T00:00:00Z');
      expect(rows.single.updatedAt, now);
    });

    test('same key cannot be inserted twice (PK violation)', () async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final DateTime now = DateTime(2026, 6, 20, 9);
      await db.into(db.userSettings).insert(
            UserSettingsCompanion.insert(
              key: 'app.installDate',
              value: 'first',
              updatedAt: now,
            ),
          );

      expect(
        () => db.into(db.userSettings).insert(
              UserSettingsCompanion.insert(
                key: 'app.installDate',
                value: 'second',
                updatedAt: now,
              ),
            ),
        throwsA(anything),
      );
    });
  });

  // -------- CompletedTasks ------

  group('CompletedTasks composite primary key', () {
    test('same (localDate, taskId) cannot be inserted twice', () async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final DateTime t0 = DateTime(2026, 6, 20, 9);
      await db.into(db.completedTasks).insert(
            CompletedTasksCompanion.insert(
              localDate: '2026-06-20',
              taskId: 'day1_tuner',
              completedAt: t0,
            ),
          );

      expect(
        () => db.into(db.completedTasks).insert(
              CompletedTasksCompanion.insert(
                localDate: '2026-06-20',
                taskId: 'day1_tuner',
                completedAt: t0.add(const Duration(minutes: 1)),
              ),
            ),
        throwsA(anything),
      );
    });

    test('same taskId on different localDate is allowed', () async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final DateTime t0 = DateTime(2026, 6, 20, 9);
      await db.into(db.completedTasks).insert(
            CompletedTasksCompanion.insert(
              localDate: '2026-06-20',
              taskId: 'day1_tuner',
              completedAt: t0,
            ),
          );
      // Same task id, but a new calendar day — must succeed.
      await db.into(db.completedTasks).insert(
            CompletedTasksCompanion.insert(
              localDate: '2026-06-27',
              taskId: 'day1_tuner',
              completedAt: t0.add(const Duration(days: 7)),
            ),
          );

      final List<CompletedTaskData> rows =
          await db.select(db.completedTasks).get();
      expect(rows, hasLength(2));
      expect(
        rows.map((CompletedTaskData r) => r.localDate).toList()..sort(),
        equals(<String>['2026-06-20', '2026-06-27']),
      );
      for (final CompletedTaskData r in rows) {
        expect(r.taskId, 'day1_tuner');
      }
    });
  });

  // -------- PracticeRecords ------

  group('PracticeRecords round-trip', () {
    test('minimal legal record with null audioFilePath round-trips', () async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final DateTime now = DateTime(2026, 6, 20, 10);
      await db.into(db.practiceRecords).insert(
            PracticeRecordsCompanion.insert(
              id: 'rec-1',
              practiceDate: now,
              dayIndex: 1,
              primaryPracticeType: 'singleNote',
              practiceTagsJson: '["tuner"]',
              practiceContent: 'Day 1: 单音 C/E 练习',
              durationSeconds: 60,
              isCompleted: const Value<bool>(true),
              selfAssessment: const Value<String>('good'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final PracticeRecordData row =
          (await db.select(db.practiceRecords).get()).single;
      expect(row.id, 'rec-1');
      expect(row.practiceDate, now);
      expect(row.dayIndex, 1);
      expect(row.primaryPracticeType, 'singleNote');
      expect(row.practiceTagsJson, '["tuner"]');
      expect(row.practiceContent, 'Day 1: 单音 C/E 练习');
      expect(row.durationSeconds, 60);
      expect(row.isCompleted, isTrue);
      expect(row.selfAssessment, 'good');
      expect(row.audioFilePath, isNull);
      expect(row.createdAt, now);
      expect(row.updatedAt, now);
    });

    test('audioFilePath is nullable and can be set and cleared', () async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final DateTime now = DateTime(2026, 6, 20, 10);

      // 1) Insert with a path.
      await db.into(db.practiceRecords).insert(
            PracticeRecordsCompanion.insert(
              id: 'rec-2',
              practiceDate: now,
              dayIndex: 3,
              primaryPracticeType: 'recording',
              practiceTagsJson: '[]',
              practiceContent: 'Day 3: 录音 1 段',
              durationSeconds: 30,
              audioFilePath: const Value<String>('recordings/x.m4a'),
              createdAt: now,
              updatedAt: now,
            ),
          );
      expect(
        (await db.select(db.practiceRecords).get()).single.audioFilePath,
        'recordings/x.m4a',
      );

      // 2) Clear it back to null. Drift's `update` lets us flip a
      //    single column without re-supplying non-null fields.
      await db.customStatement(
        "UPDATE practice_records SET audio_file_path = NULL WHERE id = ?",
        <Object>['rec-2'],
      );
      expect(
        (await db.select(db.practiceRecords).get()).single.audioFilePath,
        isNull,
      );
    });
  });

  // -------- lifecycle ------

  group('AppDatabase lifecycle', () {
    test('close() is safe to call on a fresh in-memory database', () async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      // Issue a trivial query to make sure the schema is realised
      // before we close — guarantees close() runs against a live
      // connection, not a never-opened lazy handle.
      await db.select(db.userSettings).get();
      await db.close();
      // A second close() must not throw. Drift's close is idempotent.
      await db.close();
    });
  });
}
