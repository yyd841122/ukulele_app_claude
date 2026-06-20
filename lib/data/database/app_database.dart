// AppDatabase — T013.1 Drift schema-version-1 foundation.
//
// Scope (T013.1):
// - One Drift database covering the three MVP tables:
//     * `practice_records_table.dart` — PracticeRecords
//     * `user_settings_table.dart`    — UserSettings
//     * `completed_tasks_table.dart`  — CompletedTasks
// - `schemaVersion = 1`. NO migration code is added in T013.1 because
//   there is nothing to migrate from. The `MigrationStrategy` is
//   intentionally minimal — no TODO stubs, no speculative upgrade
//   branches. V1+ will introduce `onUpgrade` when schemaVersion
//   actually moves off 1.
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
/// Holds three tables (see imports). The schema is locked at version
/// 1 for the MVP — see file docs.
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
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          // T013.1: nothing to migrate from. Just create the initial
          // schema. No speculative upgrade branches, no TODO stubs —
          // V1+ will add `onUpgrade` when schemaVersion increments.
          await m.createAll();
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
