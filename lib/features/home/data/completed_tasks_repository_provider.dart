// Riverpod provider for [CompletedTasksRepository].
//
// T013.2 scope:
// - Hand-written provider (no `@riverpod` codegen) per the project
//   convention (T007-T012).
// - Wires `appDatabaseProvider` into `DriftCompletedTasksRepository`.
// - Production override: nothing to do here.
// - Test override: tests typically override `appDatabaseProvider`
//   so they get a fresh in-memory DB; the default repository
//   implementation then operates on the test DB automatically.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ukulele_app/data/database/app_database_provider.dart';
import 'package:ukulele_app/features/home/data/completed_tasks_repository.dart';
import 'package:ukulele_app/features/home/data/drift_completed_tasks_repository.dart';

/// Provider for the completed-tasks persistence boundary.
final Provider<CompletedTasksRepository> completedTasksRepositoryProvider =
    Provider<CompletedTasksRepository>(
  (Ref ref) => DriftCompletedTasksRepository(
    database: ref.watch(appDatabaseProvider),
  ),
);
