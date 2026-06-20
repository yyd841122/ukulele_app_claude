// installDate storage.
//
// T013.3 scope:
// - The interface is now asynchronous. T007 used a synchronous
//   `DateTime getInstallDate()` because persistence was out of
//   scope; T013.3 wires the install date through Drift and the
//   controller needs to await it during `build`. The async shape
//   is the only sane contract for a Future-returning repository
//   stack (`UserSettingsRepository`, `CompletedTasksRepository`).
// - In-memory implementation keeps its lazy, single-flight
//   semantics but returns a `Future` so call sites can be
//   implementation-agnostic.
// - Drift-backed implementation lives in
//   `lib/shared/services/drift_install_date_service.dart` and is
//   the default Provider value.
//
// !!! This service is the SINGLE source of truth for "Day 1 vs Day 7".
// !!! All other code MUST go through [InstallDateService] — no direct
// !!! `DateTime.now()` calls when computing the day index.

/// Abstract install-date source.
///
/// Implementations MUST:
/// - Lazily record `DateTime.now().toUtc()` on first access.
/// - Return a stable value across subsequent reads within the
///   same process.
/// - Survive cold starts (the Drift implementation persists the
///   first-launch instant).
abstract class InstallDateService {
  /// Returns the install date recorded for this device.
  Future<DateTime> getInstallDate();
}

/// Session-only in-memory install date.
///
/// - On the first call to [getInstallDate] within a process, the
///   current `DateTime.now()` is recorded.
/// - Subsequent calls return that same instant.
/// - The recorded date is lost when the process dies. Tests use
///   the `resetForTesting` hook (or override the Provider) to
///   force a fresh install instant.
class InMemoryInstallDateService implements InstallDateService {
  InMemoryInstallDateService({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  DateTime? _installDate;

  @override
  Future<DateTime> getInstallDate() async {
    return _installDate ??= _clock();
  }

  /// Test-only: clears the recorded install date. Production code
  /// should not call this — the controller exposes a richer
  /// reset hook.
  void resetForTesting() {
    _installDate = null;
  }
}
