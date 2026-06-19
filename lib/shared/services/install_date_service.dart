// installDate storage.
//
// T007 temporary implementation:
// - The spec for T007 explicitly forbids adding a `shared_preferences`
//   dependency and forbids touching Drift for this task. So we provide
//   a lightweight abstraction with an in-memory implementation.
// - On a cold start, [InMemoryInstallDateService] records the *current*
//   `DateTime.now()` as the install date. This means every cold start
//   resets the 7-day cycle — acceptable for T007, marked below as a
//   known limitation.
// - The expected follow-up is T013 (local settings persistence) where a
//   real Drift / SharedPreferences backed implementation replaces
//   [InMemoryInstallDateService] without changing the interface.
//
// !!! DO NOT persist anything here until T013.
// !!! This service is the SINGLE source of truth for "Day 1 vs Day 7".
// !!! All other code MUST go through [InstallDateService] — no direct
// !!! `DateTime.now()` calls when computing the day index.

/// Abstract install-date source.
///
/// T007 ships one in-memory implementation. T013 is expected to add a
/// Drift-backed implementation that survives cold starts.
abstract class InstallDateService {
  /// Returns the install date recorded for this device.
  ///
  /// Implementations are allowed to lazily record `DateTime.now()` on
  /// first access, and they MUST return a stable value across subsequent
  /// reads within the same app session.
  DateTime getInstallDate();
}

/// Session-only in-memory install date.
///
/// T007 behaviour:
/// - On the first call to [getInstallDate] within a process, the current
///   `DateTime.now()` is recorded.
/// - Subsequent calls return that same instant.
/// - When the process dies and restarts, the recorded date is lost and
///   the next call re-records `DateTime.now()` (i.e. the 7-day cycle
///   resets on every cold start). This is the documented T007 limitation.
class InMemoryInstallDateService implements InstallDateService {
  InMemoryInstallDateService({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  DateTime? _installDate;

  @override
  DateTime getInstallDate() {
    return _installDate ??= _clock();
  }

  /// Test-only: clears the recorded install date. Production code should
  /// not call this — the controller exposes a richer reset hook.
  void resetForTesting() {
    _installDate = null;
  }
}
