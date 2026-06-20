// Riverpod provider for [AppDatabase].
//
// T013.1 scope:
// - Single hand-written provider (no `@riverpod` codegen) to match
//   the project convention from T007-T012 (see e.g.
//   `lib/features/home/application/today_practice_controller.dart`).
// - Owns the database lifecycle: when the provider is disposed
//   (typically at app shutdown), `AppDatabase.close()` is called,
//   releasing the underlying SQLite connection.
// - Production override: nothing to do here — `AppDatabase()` opens
//   `<documents>/ukulele.db` automatically.
// - Test override: pass an `AppDatabase.forTesting(...)` instance via
//   `appDatabaseProvider.overrideWithValue(...)`. Each test gets a
//   fresh, in-memory database and `close()` is a no-op safe call
//   (Drift closes the in-memory NativeDatabase cleanly).
//
// Why we deliberately do NOT wire this provider into `main.dart` in
// T013.1: the task brief explicitly forbids modifying `lib/main.dart`
// and forbids touching feature Controllers. The provider is *ready*
// for T013.3+ to consume; no T013.1 business code depends on it.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ukulele_app/data/database/app_database.dart';

/// Provides the singleton [AppDatabase] for the running app.
///
/// Disposal semantics: when the ProviderContainer that holds this
/// provider is disposed, [AppDatabase.close] runs, which in turn
/// closes the underlying [QueryExecutor] (the production `LazyDatabase`
/// or the in-memory `NativeDatabase` used in tests).
final Provider<AppDatabase> appDatabaseProvider = Provider<AppDatabase>(
  (Ref ref) {
    final AppDatabase db = AppDatabase();
    ref.onDispose(db.close);
    return db;
  },
);
