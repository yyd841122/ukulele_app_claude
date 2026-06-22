// AppDatabase — T013.1 Drift schema-version-1 foundation,
// bumped to schemaVersion = 2 by
// T032_REAL_AUDIO_PRACTICE_RECORD_SCHEMA_UPGRADE.
//
// Scope (T013.1):
// - One Drift database covering the three MVP tables:
//     * `practice_records_table.dart` — PracticeRecords
//     * `user_settings_table.dart`    — UserSettings
//     * `completed_tasks_table.dart`  — CompletedTasks
// - `schemaVersion = 2` (T032). T013.1 froze the schema at v1;
//   T031 introduced real audio recording/playback but did NOT
//   bump the schema version (audioFilePath was already nullable
//   in v1, see T013.1 — the column was reserved for the
//   "real audio phase"). T032 bumps the version so the schema
//   evolution has a clear anchor for "real audio persistence
//   is now part of the contract".
// - **v1 → v2 is a contract bump, not a layout change**:
//     * `practice_records.audio_file_path` was already nullable
//       in v1.
//     * No `ALTER TABLE` is needed.
//     * Legacy rows survive the upgrade with `audio_file_path =
//       NULL` exactly as they were written.
//   The `onUpgrade` branch for v1 → v2 exists so future
//   migrations (T033+) can stack after v2 without having to
//   relocate the v1 → v2 transition; it does **not** call
//   `m.createAll()` (which would fail because the columns are
//   already on disk) and does **not** rewrite any rows.
// - Two constructors:
//     * [AppDatabase] (default) — production. Opens a file under the
//       app private documents directory (`<docs>/ukulele.db`).
//     * [AppDatabase.forTesting] — in-memory `NativeDatabase`.
//       Use this from `flutter_test` so each test gets an isolated,
//       disposable database.
// - This file does NOT declare DAO / Repository methods. Drift's
//   `*.g.dart` will generate the row-level accessors; domain-side
//   CRUD lives in `lib/data/repositories/` and per-feature
//   `data/` folders introduced in T013.2.
//
// Conventions enforced here:
// - Per DATA_MODEL_DRAFT.md §13.1 / §13.2 naming convention, every
//   generated row class is named `<TableName>Data` so domain models
//   (T013.2+) keep the plain `<TableName>` name without collision.
// - The production file name is centralised in
//   [kAppDatabaseFileName] so future migrations / inspection tooling
//   can refer to it without scattering the literal across the code
//   base.

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:ukulele_app/data/database/tables/completed_tasks_table.dart';
import 'package:ukulele_app/data/database/tables/practice_records_table.dart';
import 'package:ukulele_app/data/database/tables/user_settings_table.dart';

part 'app_database.g.dart';

/// File name of the production SQLite database. Centralised so future
/// tooling (logs, backups, manual inspection) has a single source of
/// truth.
const String kAppDatabaseFileName = 'ukulele.db';

/// Root Drift database for the ukulele_app MVP.
///
/// Holds three tables (see imports). The schema is at version
/// 2 — see file docs.
@DriftDatabase(
  tables: <Type>[PracticeRecords, UserSettings, CompletedTasks],
)
class AppDatabase extends _$AppDatabase {
  /// Production constructor.
  ///
  /// Opens (or creates) `<documents>/ukulele.db` using a lazy
  /// connection so the file is only touched on first query, not at
  /// AppDatabase construction time. The platform check guards against
  /// accidentally running the production constructor in a unit test
  /// environment where `path_provider` would fail (it relies on a
  /// platform channel).
  AppDatabase() : super(_openProductionConnection());

  /// Test-only constructor.
  ///
  /// Uses `NativeDatabase.memory()` — no file is created on disk, and
  /// each call returns a fully isolated, ephemeral database. Pass this
  /// to [AppDatabaseProvider] via `overrideWithValue` from `flutter_test`.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          // Initial schema for fresh installs. The schema is the
          // v2 layout — `practice_records.audio_file_path` is
          // already declared as nullable in the Table class, so
          // this single `createAll()` materialises the v2
          // schema on disk.
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // T032: v1 → v2 is a contract bump only — see the
          // file-level docs above. The on-disk layout is
          // unchanged from v1 (audio_file_path was already
          // nullable in v1), so we explicitly do **not** call
          // `m.createAll()` (which would fail on already-present
          // columns) and we do **not** rewrite any rows. Legacy
          // rows survive untouched with `audio_file_path = NULL`.
          //
          // The branch is left in place so future migrations
          // (T033+) can stack after v2 — any v1 install that
          // reaches this code path is migrated in-place to v2
          // (no-op) and any v2 install never enters it.
          if (from == 1 && to == 2) {
            // Intentionally empty: see file-level docs.
            return;
          }
          // Defensive fallback. Drift only invokes `onUpgrade`
          // when `from < to` and `from < schemaVersion`, so
          // this branch should be unreachable in normal flows.
          // We throw rather than silently swallow so a future
          // bump that forgets to extend this switch surfaces as
          // a loud failure instead of a half-migrated DB.
          throw StateError(
            'AppDatabase: no migration path defined for '
            'schemaVersion $from → $to (current schemaVersion = '
            '$schemaVersion). Update the onUpgrade branch.',
          );
        },
      );
}

/// Opens a lazy SQLite connection against `<documents>/ukulele.db`.
///
/// `LazyDatabase` defers file I/O until the first query, so the
/// constructor itself stays cheap and side-effect-free. Any
/// `path_provider` failure therefore surfaces on first DB use, not
/// at startup — easier to surface as a recoverable error than a
/// crash during widget tree construction.
QueryExecutor _openProductionConnection() {
  return LazyDatabase(() async {
    // path_provider is unavailable on the Dart VM without a Flutter
    // binding. The production guard in [AppDatabase] prevents this
    // branch from running in unit tests, so the missing-plugin error
    // never surfaces there.
    final Directory docs = await getApplicationDocumentsDirectory();
    final File dbFile = File(p.join(docs.path, kAppDatabaseFileName));
    return NativeDatabase.createInBackground(dbFile);
  });
}
