// Tests for [AppDatabase] v1 → v2 migration (T032).
//
// Strategy (T032_REAL_AUDIO_PRACTICE_RECORD_SCHEMA_UPGRADE):
//
//   - We do NOT depend on `package:sqlite3/sqlite3.dart` (it is a
//     transitive dependency of `drift` and not declared in
//     `pubspec.yaml`, so the test file cannot import it).
//
//   - The v1 → v2 transition is a **contract-only bump**: the
//     on-disk layout is unchanged from v1 (audio_file_path was
//     already nullable in v1). The MigrationStrategy.onUpgrade
//     branch for `(from=1, to=2)` is intentionally empty (see the
//     file-level docs on `AppDatabase`). What we must verify is:
//
//       1. A legacy v1-shaped database (audio_file_path already
//          nullable in v1, schema_version = 1) opens cleanly under
//          schemaVersion = 2 and the data survives the "upgrade"
//          without rewriting any rows.
//
//       2. New records written under schemaVersion = 2 round-trip
//          including a non-null audio_file_path.
//
//       3. The on-disk SQLite `user_version` PRAGMA — which is
//          Drift's source of truth for schemaVersion — is bumped
//          from 1 to 2 by the migration.
//
//   - To stand up a "v1-shaped" database without importing sqlite3,
//     we open a temp file via `NativeDatabase`, run `onCreate` (v2
//     schema hits disk), then force the `user_version` PRAGMA back
//     to 1 (simulating a legacy install) before reopening under the
//     production schemaVersion = 2 code path. The "upgrade" then
//     runs `MigrationStrategy.onUpgrade(m, 1, 2)`, which is a no-op
//     (intentional). We then read back rows to confirm:
//       * data was not rewritten / lost,
//       * audio_file_path is still null on the legacy row,
//       * the `user_version` PRAGMA is now 2.
//
//   - The test uses ONLY Drift's public APIs:
//     `AppDatabase.forTesting`, `NativeDatabase`, `customSelect`,
//     `customStatement`, `into(...).insert(...)`. No sqlite3
//     direct API.

import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ukulele_app/data/database/app_database.dart';

void main() {
  group('AppDatabase v1 → v2 migration', () {
    test(
        'a v1-shaped database (schema_version=1, audio_file_path nullable) '
        'opens cleanly under schemaVersion=2 and survives the upgrade '
        'with audio_file_path still NULL', () async {
      // Stage 1: Create a temp-file v1-shaped database.
      //
      // We open the file with `enableMigrations: false` so Drift
      // does NOT auto-run onCreate at this point. We then use raw
      // SQL (`customStatement`) to:
      //   - manually create the v1-shaped `practice_records` table
      //     (audio_file_path nullable, exactly as T013.1 declared),
      //   - manually set `PRAGMA user_version = 1`.
      //
      // This is a "manual" v1 install — no Drift codegen is
      // involved in the table layout; we replicate the v1 schema
      // by hand so the upgrade is realistic.
      final Directory tempDir =
          await Directory.systemTemp.createTemp('t032_drift_v1_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final File dbFile = File('${tempDir.path}/ukulele.db');

      // Pre-create the v1 database with `enableMigrations: false`.
      final AppDatabase v1Setup = AppDatabase.forTesting(
        NativeDatabase(dbFile, setup: null, enableMigrations: false),
      );
      addTearDown(() async {
        await v1Setup.close();
      });

      // Replicate the v1 `practice_records` layout by hand. This
      // is the EXACT shape T013.1 generated (see
      // `app_database.g.dart` line ~73 — `audio_file_path TEXT
      // NULL`). We pin all 12 columns so the upgrade path is
      // faithful even if the future schema adds new columns.
      // `customStatement` returns `Future<void>` (see drift's
      // `connection_user.dart`), so it is awaited for symmetry
      // with other DB calls.
      await v1Setup.customStatement('''
        CREATE TABLE IF NOT EXISTS practice_records (
          id TEXT NOT NULL PRIMARY KEY,
          practice_date INTEGER NOT NULL,
          day_index INTEGER NOT NULL,
          primary_practice_type TEXT NOT NULL,
          practice_tags_json TEXT NOT NULL,
          practice_content TEXT NOT NULL,
          duration_seconds INTEGER NOT NULL,
          is_completed INTEGER NOT NULL DEFAULT 0,
          self_assessment TEXT NULL,
          audio_file_path TEXT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );
      ''');
      // Pin user_version = 1 to mark the database as a legacy
      // install. Drift reads `user_version` on open to decide
      // whether to run onCreate / onUpgrade.
      await v1Setup.customStatement('PRAGMA user_version = 1;');

      // Insert a legacy v1 row using the EXACT shape of the
      // schema. The record mirrors what T012 / T013.1 simulated
      // recordings would have written — no real audio path,
      // is_completed=0, default everything else.
      // SQLite stores DateTime as unix seconds (INTEGER), so we
      // pass `1750000000` (a stable epoch chosen for the test).
      const int legacyCreatedAtEpoch = 1750000000;
      // Drift's `customStatement` accepts `List<dynamic>` for the
      // args parameter (see drift's `connection_user.dart`), so a
      // mixed-type literal with `null` entries compiles cleanly.
      await v1Setup.customStatement(
        'INSERT INTO practice_records ('
        'id, practice_date, day_index, primary_practice_type, '
        'practice_tags_json, practice_content, duration_seconds, '
        'is_completed, self_assessment, audio_file_path, '
        'created_at, updated_at'
        ') VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);',
        <dynamic>[
          'legacy-rec-1',
          1749772800, // 2025-06-13 00:00:00 UTC
          1,
          'singleNote',
          '["tuner"]',
          'Day 1: 单音 C/E 练习 (legacy v1 row)',
          60,
          0, // is_completed = false
          null, // self_assessment = null
          null, // audio_file_path = null  ← the v1 contract
          legacyCreatedAtEpoch,
          legacyCreatedAtEpoch,
        ],
      );
      // Sanity: confirm the legacy row really is on disk with
      // user_version = 1.
      final int userVersionBefore = await v1Setup
          .customSelect('PRAGMA user_version;')
          .map((QueryRow row) => row.read<int>('user_version'))
          .getSingle();
      expect(userVersionBefore, 1,
          reason: 'pre-upgrade: legacy db must be tagged user_version=1');

      // Close the v1 setup handle so the file is flushed.
      await v1Setup.close();

      // Stage 2: Reopen with the production schemaVersion = 2 code.
      // Drift sees `user_version = 1` < `schemaVersion = 2` and
      // invokes `MigrationStrategy.onUpgrade(m, 1, 2)`, which is
      // intentionally empty (contract bump only).
      final AppDatabase upgraded = AppDatabase.forTesting(
        NativeDatabase(dbFile),
      );
      addTearDown(() async {
        await upgraded.close();
      });

      // Force the lazy open so onUpgrade (if any) runs.
      await upgraded.customSelect('SELECT 1').get();

      // Stage 3: Verify the legacy row survived the upgrade and
      // audio_file_path is still NULL.
      final List<PracticeRecordData> rows =
          await upgraded.select(upgraded.practiceRecords).get();
      expect(rows, hasLength(1),
          reason: 'legacy row must survive the v1 → v2 upgrade');
      final PracticeRecordData row = rows.single;
      expect(row.id, 'legacy-rec-1');
      expect(row.practiceContent, 'Day 1: 单音 C/E 练习 (legacy v1 row)');
      expect(row.audioFilePath, isNull,
          reason: 'legacy rows must keep audio_file_path = null after '
              'the v1 → v2 migration');
      expect(row.selfAssessment, isNull);
      expect(row.isCompleted, isFalse);

      // user_version must now be 2 (Drift writes it after
      // onUpgrade finishes).
      final int userVersionAfter = await upgraded
          .customSelect('PRAGMA user_version;')
          .map((QueryRow row) => row.read<int>('user_version'))
          .getSingle();
      expect(userVersionAfter, 2,
          reason: 'post-upgrade: user_version must be bumped to 2');
    });

    test(
        'a v2 fresh-install database lets the Repository write '
        'audioFilePath, and the column round-trips verbatim', () async {
      // This is the "forward" path — after the migration, new
      // records can carry a non-null audio path. The drift
      // schema (already nullable in v1) does not need any
      // rewriting; this test pins that the Repository layer
      // (T013.2) does not mangle the audioFilePath string and
      // that the column round-trips exactly.
      //
      // Why we put this in the migration test file rather than
      // drift_practice_record_repository_test.dart: the migration
      // test owns the post-T032 contract, and the Repository
      // test file already has a dedicated `audioFilePath` group
      // for fine-grained null/string behaviour.
      final Directory tempDir =
          await Directory.systemTemp.createTemp('t032_drift_v2_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final File dbFile = File('${tempDir.path}/ukulele.db');

      final AppDatabase db = AppDatabase.forTesting(NativeDatabase(dbFile));
      addTearDown(() async {
        await db.close();
      });
      // Force the lazy open so onCreate (v2) runs and the file
      // is materialised on disk.
      await db.customSelect('SELECT 1').get();

      // Write a record with a non-null audio path via Drift
      // directly (bypassing the Repository) so we can pin the
      // raw column behaviour without depending on the
      // Repository's UTC / local-midnight normalisation.
      final DateTime now = DateTime.utc(2026, 6, 22, 10);
      await db.into(db.practiceRecords).insert(
            PracticeRecordsCompanion.insert(
              id: 'v2-rec-1',
              practiceDate: now,
              dayIndex: 3,
              primaryPracticeType: 'recording',
              practiceTagsJson: '[]',
              practiceContent: 'Day 3: 真实录音',
              durationSeconds: 45,
              audioFilePath: const Value<String>('saved/2026-06-22/'
                  'v2-rec-1.m4a'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Read it back via Drift directly. The pattern (matching
      // `app_database_test.dart`) is: build the Selectable with
      // `select`, then `await ...get()` to get a `List<T>`, then
      // use the standard Dart `List.single` extension to assert
      // exactly one row matches.
      final List<PracticeRecordData> allRows =
          await db.select(db.practiceRecords).get();
      final PracticeRecordData row =
          allRows.where((PracticeRecordData r) => r.id == 'v2-rec-1').single;
      expect(row.audioFilePath, 'saved/2026-06-22/v2-rec-1.m4a',
          reason: 'v2 schema must persist audio_file_path verbatim');

      // Round-trip once more across a reopen to confirm the
      // path is durable (no in-memory caching).
      await db.close();
      final AppDatabase reopened =
          AppDatabase.forTesting(NativeDatabase(dbFile));
      addTearDown(() async {
        await reopened.close();
      });
      final List<PracticeRecordData> reopenedRows =
          await reopened.select(reopened.practiceRecords).get();
      final PracticeRecordData reopenedRow = reopenedRows
          .where((PracticeRecordData r) => r.id == 'v2-rec-1')
          .single;
      expect(reopenedRow.audioFilePath, 'saved/2026-06-22/v2-rec-1.m4a');
    });

    test(
        'onUpgrade branch does NOT call m.createAll (which would fail '
        'on existing columns) — verified by the no-op contract', () async {
      // Indirect verification of the onUpgrade contract: a v1
      // database that already has the v1 schema (audio_file_path
      // present, nullable) survives a reopen under schemaVersion
      // = 2 with all columns intact. If onUpgrade had called
      // m.createAll() (which it deliberately does not), Drift
      // would throw "duplicate column name: audio_file_path"
      // because the column already exists. The fact that the
      // reopen succeeds is the test.
      final Directory tempDir =
          await Directory.systemTemp.createTemp('t032_drift_noop_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final File dbFile = File('${tempDir.path}/ukulele.db');

      // Stage A: open as v1 with the v1 shape already in place.
      final AppDatabase v1 = AppDatabase.forTesting(
        NativeDatabase(dbFile, enableMigrations: false),
      );
      addTearDown(v1.close);
      await v1.customStatement('''
        CREATE TABLE IF NOT EXISTS practice_records (
          id TEXT NOT NULL PRIMARY KEY,
          practice_date INTEGER NOT NULL,
          day_index INTEGER NOT NULL,
          primary_practice_type TEXT NOT NULL,
          practice_tags_json TEXT NOT NULL,
          practice_content TEXT NOT NULL,
          duration_seconds INTEGER NOT NULL,
          is_completed INTEGER NOT NULL DEFAULT 0,
          self_assessment TEXT NULL,
          audio_file_path TEXT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );
      ''');
      await v1.customStatement('PRAGMA user_version = 1;');
      await v1.customStatement(
        'INSERT INTO practice_records VALUES ('
        "'v1-noop-1', 1749772800, 1, 'singleNote', '[]', 'noop test', "
        '30, 0, NULL, NULL, 1750000000, 1750000000);',
      );
      await v1.close();

      // Stage B: reopen under schemaVersion = 2. The onUpgrade
      // branch must NOT call m.createAll() — Drift would throw
      // because audio_file_path already exists. We confirm:
      //   - reopen succeeds without exception,
      //   - the row count is preserved (no rows deleted/rewritten),
      //   - audio_file_path is still NULL.
      final AppDatabase v2 = AppDatabase.forTesting(NativeDatabase(dbFile));
      addTearDown(v2.close);
      await v2.customSelect('SELECT 1').get();

      final List<PracticeRecordData> rows =
          await v2.select(v2.practiceRecords).get();
      expect(rows, hasLength(1),
          reason: 'v1 row must survive the upgrade untouched');
      expect(rows.single.id, 'v1-noop-1');
      expect(rows.single.audioFilePath, isNull);
    });
  });
}
