// Shared install-date service provider (T013.4A0_RECORDING_SAVE_FOUNDATION).
//
// Provides the single Riverpod provider for [InstallDateService].
// The previous home-feature-local copy
// (`installDateServiceProvider` in
// `lib/features/home/application/today_practice_controller.dart`)
// was a feature-local dependency even though the recording save
// flow will also need it (T013.4A+ reads the install date to
// compute `PracticeRecord.dayIndex`).
//
// Migration note (T013.4A0):
// - The provider is renamed to `installDateServiceProvider` AND
//   moved into the shared layer so that any feature can read it
//   without creating a home -> recording or recording -> home
//   dependency.
// - The default implementation is still
//   `DriftInstallDateService`, wired against the shared
//   `userSettingsRepositoryProvider`.
// - The previous alias was intentionally NOT preserved as a
//   forwarding export. Every call site now imports this file.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ukulele_app/shared/repositories/user_settings_repository_provider.dart';
import 'package:ukulele_app/shared/services/drift_install_date_service.dart';
import 'package:ukulele_app/shared/services/install_date_service.dart';

/// Provider for the application-wide [InstallDateService].
///
/// Defaults to the Drift-backed implementation. Tests typically
/// override this provider with a stub that returns a fixed
/// install instant (e.g. an in-memory fake or a `Completer`-based
/// stub).
final Provider<InstallDateService> installDateServiceProvider =
    Provider<InstallDateService>((Ref ref) {
  return DriftInstallDateService(
    repository: ref.watch(userSettingsRepositoryProvider),
  );
});
