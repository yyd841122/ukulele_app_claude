// installDate storage.
//
// T013.3_FIX_PENDING_RESULT_AND_INSTALL_DATE_BOUNDARY scope:
// - The interface is asynchronous. T007 used a synchronous
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
//   the default Provider value. The Drift implementation depends
//   ONLY on `UserSettingsRepository` — feature-side services
//   MUST NOT reach into the Drift table directly.
//
// Timezone contract (T013.3):
// - Every implementation MUST return a UTC `DateTime` (i.e.
//   `isUtc == true`). Callers — most importantly
//   `TodayPracticeController` — project to local time before
//   computing the day index, so a UTC instant is the safe common
//   shape. Returning a local `DateTime` here would silently
//   break the calculator the moment the device crosses a
//   timezone.
//
// !!! This service is the SINGLE source of truth for "Day 1 vs Day 7".
// !!! All other code MUST go through [InstallDateService] — no direct
// !!! `DateTime.now()` calls when computing the day index.

/// Abstract install-date source.
///
/// Implementations MUST:
/// - Lazily record a UTC `DateTime` on first access.
/// - Return a stable UTC value across subsequent reads within the
///   same process.
/// - Survive cold starts (the Drift implementation persists the
///   first-launch instant).
abstract class InstallDateService {
  /// Returns the install date recorded for this device as a UTC
  /// `DateTime`. The instant is what was observed at first
  /// launch; the caller is responsible for projecting to the
  /// local calendar day before computing the day index.
  Future<DateTime> getInstallDate();
}

/// Session-only in-memory install date.
///
/// - On the first call to [getInstallDate] within a process, the
///   current `DateTime.now()` is recorded as UTC.
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
    // Always project to UTC. `_clock()` may return a local
    // DateTime when the production `DateTime.now` is used (the
    // default), and the timezone contract is "UTC on the wire".
    return _installDate ??= _clock().toUtc();
  }

  /// Test-only: clears the recorded install date. Production code
  /// should not call this — the controller exposes a richer
  /// reset hook.
  void resetForTesting() {
    _installDate = null;
  }
}
