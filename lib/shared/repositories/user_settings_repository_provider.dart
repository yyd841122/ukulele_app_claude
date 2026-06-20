// Riverpod provider for [UserSettingsRepository].
//
// T013.2 scope:
// - Hand-written provider (no `@riverpod` codegen) per the project
//   convention (T007-T012).
// - Wires `appDatabaseProvider` into `DriftUserSettingsRepository`.
// - Production override: nothing to do here.
// - Test override: tests typically override `appDatabaseProvider`
//   so they get a fresh in-memory DB; the default repository
//   implementation then operates on the test DB automatically.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ukulele_app/data/database/app_database_provider.dart';
import 'package:ukulele_app/shared/repositories/drift_user_settings_repository.dart';
import 'package:ukulele_app/shared/repositories/user_settings_repository.dart';

/// Provider for the user-settings persistence boundary.
final Provider<UserSettingsRepository> userSettingsRepositoryProvider =
    Provider<UserSettingsRepository>(
  (Ref ref) => DriftUserSettingsRepository(
    database: ref.watch(appDatabaseProvider),
  ),
);
