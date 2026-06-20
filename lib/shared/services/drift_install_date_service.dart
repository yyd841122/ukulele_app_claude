// Drift-backed install-date service (T013.3).
//
// Stores the first-launch instant under the
// `app.installDate` key in the `user_settings` table. The
// value is persisted as an ISO-8601 UTC string so it round-trips
// losslessly across timezones.
//
// Contract highlights:
// - First call within a process records `DateTime.now().toUtc()`
//   and persists it.
// - Subsequent calls (in the same process or after a cold start)
//   return the persisted value verbatim.
// - Concurrent callers MUST observe a single write — the
//   implementation uses a `Completer` to single-flight the
//   first-launch write so two simultaneous `getInstallDate()`
//   calls cannot race to install two different dates.
// - If the persisted value cannot be parsed as ISO-8601, the
//   service throws [FormatException] rather than silently
//   overwriting it. The caller (the Controller) is responsible
//   for surfacing this error.
import 'dart:async';

import 'package:ukulele_app/data/database/app_database.dart';
import 'package:ukulele_app/shared/services/install_date_service.dart';

/// Key used to store the install date in `user_settings`.
const String kInstallDateKey = 'app.installDate';

/// Drift-backed [InstallDateService] reading and writing the
/// `app.installDate` row.
class DriftInstallDateService implements InstallDateService {
  DriftInstallDateService({
    required AppDatabase database,
    DateTime Function()? clock,
  })  : _db = database,
        _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  // Single-flight guard for the first-launch write.
  //
  // On the very first call we kick off an async DB read + (maybe)
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
      final UserSettingData? row = await (_db.select(_db.userSettings)
            ..where(($UserSettingsTable t) => t.key.equals(kInstallDateKey)))
          .getSingleOrNull();
      if (row != null) {
        completer.complete(_parseIso(row.value));
        return;
      }
      // First launch in this process AND on this device. Persist
      // the current UTC instant. The DB layer uses
      // `insertOnConflictUpdate` so a re-run of this branch (e.g.
      // because two processes raced before either wrote) converges
      // to the same row.
      final DateTime now = _clock().toUtc();
      await _db.into(_db.userSettings).insertOnConflictUpdate(
            UserSettingsCompanion.insert(
              key: kInstallDateKey,
              value: now.toIso8601String(),
              updatedAt: now,
            ),
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

  /// Parses [raw] as an ISO-8601 UTC instant. Throws
  /// [FormatException] on any deviation so callers can decide
  /// whether to surface, repair, or quarantine the bad data.
  static DateTime _parseIso(String raw) {
    final DateTime? parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      throw FormatException(
        'Stored install date "$raw" is not a valid ISO-8601 string',
      );
    }
    return parsed;
  }
}
