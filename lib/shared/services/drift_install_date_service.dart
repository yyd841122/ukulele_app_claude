// Drift-backed install-date service (T013.3).
//
// Stores the first-launch instant under the
// `app.installDate` key in the `user_settings` table via the
// generic [UserSettingsRepository] boundary.
//
// T013.3_FIX_PENDING_RESULT_AND_INSTALL_DATE_BOUNDARY changes:
// - The service now depends ONLY on [UserSettingsRepository].
//   It does NOT import `AppDatabase`, `UserSettingData`, or
//   `UserSettingsCompanion`. Feature-side services MUST stay
//   behind the repository boundary; reaching into Drift here
//   would force the controller (and any future caller) to share
//   the same Drift-typed surface area.
//
// Timezone contract:
// - On first launch the service writes the current UTC instant
//   as an ISO-8601 string with an explicit `Z` (e.g.
//   `2026-06-20T09:00:00.000Z`).
// - On read, the service accepts any timezone-aware ISO-8601
//   string:
//     * `Z` suffix      → returns `DateTime` in UTC.
//     * `±HH:MM` offset → returns `DateTime.parse(...).toUtc()`.
// - Naive ISO strings (no `Z`, no offset), pure date strings
//   (`YYYY-MM-DD`), and unparseable garbage all throw
//   [FormatException]. The controller surfaces this as an
//   AsyncError and the UI offers a Retry.
//
// Single-flight contract (preserved from T013.3 baseline):
// - First call within a process records `clock().toUtc()` and
//   persists it.
// - Subsequent calls (in the same process or after a cold start)
//   return the persisted value verbatim.
// - Concurrent callers MUST observe a single write — the
//   implementation uses a `Completer` to single-flight the
//   first-launch write so two simultaneous `getInstallDate()`
//   calls cannot race to install two different dates.
// - If the persisted value cannot be parsed as ISO-8601, the
//   service throws [FormatException] rather than silently
//   overwriting it, and the single-flight slot is reset so a
//   subsequent call (after the row has been repaired) can
//   retry.
import 'dart:async';

import 'package:ukulele_app/shared/repositories/user_settings_repository.dart';
import 'package:ukulele_app/shared/services/install_date_service.dart';

/// Key used to store the install date in `user_settings`.
const String kInstallDateKey = 'app.installDate';

/// Drift-backed [InstallDateService] reading and writing the
/// `app.installDate` row through the generic
/// [UserSettingsRepository] boundary.
class DriftInstallDateService implements InstallDateService {
  DriftInstallDateService({
    required UserSettingsRepository repository,
    DateTime Function()? clock,
  })  : _repository = repository,
        _clock = clock ?? DateTime.now;

  final UserSettingsRepository _repository;
  final DateTime Function() _clock;

  // Single-flight guard for the first-launch write.
  //
  // On the very first call we kick off an async read + (maybe)
  // write. Every other concurrent caller awaits the same
  // [Completer] so the underlying row is touched exactly once per
  // process.
  Future<DateTime>? _inflight;

  @override
  Future<DateTime> getInstallDate() {
    final Future<DateTime>? existing = _inflight;
    if (existing != null) {
      return existing;
    }
    final Completer<DateTime> completer = Completer<DateTime>();
    _inflight = completer.future;
    // Run on the next microtask so synchronous re-entry from the
    // caller cannot observe `_inflight` before this line completes.
    unawaited(_loadOrInstall(completer));
    return completer.future;
  }

  Future<void> _loadOrInstall(Completer<DateTime> completer) async {
    try {
      final String? existing = await _repository.getValue(kInstallDateKey);
      if (existing != null) {
        completer.complete(parseIsoUtc(existing));
        return;
      }
      // First launch in this process AND on this device. Persist
      // the current UTC instant.
      final DateTime now = _clock().toUtc();
      await _repository.setValue(
        key: kInstallDateKey,
        value: now.toIso8601String(),
        updatedAt: now,
      );
      completer.complete(now);
    } catch (e, st) {
      // Reset the single-flight slot so a *subsequent* call can
      // retry. If we leave `_inflight` pointing at the failed
      // future, every caller after this point would observe the
      // same error without ever attempting the DB again.
      _inflight = null;
      completer.completeError(e, st);
    }
  }

  /// Parses [raw] as a timezone-aware ISO-8601 instant and
  /// returns it as a UTC `DateTime`.
  ///
  /// Accepted shapes:
  /// - `YYYY-MM-DDTHH:MM:SS(.fff)?Z` (UTC, e.g. produced by
  ///   [DateTime.toIso8601String] on a UTC instant).
  /// - `YYYY-MM-DDTHH:MM:SS(.fff)?±HH:MM` (explicit offset).
  ///
  /// Rejected shapes — all throw [FormatException]:
  /// - `YYYY-MM-DDTHH:MM:SS` (no timezone designator).
  /// - `YYYY-MM-DD` (pure date, no time).
  /// - Anything [DateTime.parse] refuses.
  ///
  /// The static surface exists so tests can exercise the
  /// parser without instantiating a full Drift stack.
  static DateTime parseIsoUtc(String raw) {
    final DateTime? parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      throw FormatException(
        'Stored install date "$raw" is not a valid ISO-8601 string',
      );
    }
    // DateTime.tryParse / parse returns a UTC `DateTime` when the
    // input ends in `Z` and a local `DateTime` when the input has
    // an explicit offset (per the Dart spec). Either way we need
    // the caller's `isUtc` flag to read as `true` so downstream
    // `state.installDate` is always UTC. We additionally guard
    // against naive strings by inspecting the input ourselves.
    if (!_hasTimezoneDesignator(raw)) {
      throw FormatException(
        'Stored install date "$raw" is missing a timezone designator',
      );
    }
    return parsed.toUtc();
  }

  /// Returns `true` iff [raw] carries an explicit `Z` or
  /// `±HH:MM` offset. The Dart parser is permissive about
  /// timezone-less ISO strings, so we double-check here.
  static bool _hasTimezoneDesignator(String raw) {
    if (raw.isEmpty) return false;
    // Walk the string looking for `Z` or `±` (i.e. `+` / `-` in
    // the time-of-day position). The position must come AFTER
    // the time component (`T...`).
    final int tIndex = raw.indexOf('T');
    if (tIndex < 0) {
      // No time component: pure date, not allowed.
      return false;
    }
    final String afterT = raw.substring(tIndex + 1);
    if (afterT.endsWith('Z') || afterT.endsWith('z')) {
      return true;
    }
    // Look for a `+` or `-` after the seconds component.
    final RegExp offsetPattern = RegExp(r'[+\-]\d{2}:\d{2}$');
    return offsetPattern.hasMatch(raw);
  }
}
