// Riverpod provider for [PracticeRecordRepository].
//
// T013.2 scope:
// - Hand-written provider (no `@riverpod` codegen) per the project
//   convention (T007-T012).
// - Wires `appDatabaseProvider` into `DriftPracticeRecordRepository`.
// - Production override: nothing to do here — the default chain
//   resolves to `AppDatabase()` which opens `<docs>/ukulele.db`.
// - Test override: tests can replace either
//   `appDatabaseProvider` (preferred — swap the whole DB) or
//   `practiceRecordRepositoryProvider` directly via `overrideWith`.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ukulele_app/data/database/app_database_provider.dart';
import 'package:ukulele_app/features/practice_records/data/drift_practice_record_repository.dart';
import 'package:ukulele_app/features/practice_records/data/practice_record_repository.dart';

/// Provider for the practice record persistence boundary.
final Provider<PracticeRecordRepository> practiceRecordRepositoryProvider =
    Provider<PracticeRecordRepository>(
  (Ref ref) => DriftPracticeRecordRepository(
    database: ref.watch(appDatabaseProvider),
  ),
);
