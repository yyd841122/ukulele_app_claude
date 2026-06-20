// Shared practice-day context and resolver
// (T013.4A0_RECORDING_SAVE_FOUNDATION).
//
// The Home Controller and (future) Recording save flow both need
// to answer three questions on every read:
//   1. What is "today" in the user's local calendar?
//   2. What was the install date (local calendar)?
//   3. Which day in the 7-day cycle is the user on?
//
// Before T013.4A0 those three answers were computed inline inside
// `TodayPracticeController.build()`. That worked for one consumer,
// but the recording save flow is about to need the SAME pair of
// local-midnight values to derive `PracticeRecord.dayIndex` and
// `PracticeRecord.practiceDate` — duplicating the logic in two
// controllers would risk drift (e.g. one path forgets to normalise
// the install instant, the other path uses `today` while the
// controller uses `now.toLocal()` for the calculator).
//
// This file is the single source of truth. Both features
// (home, recording) consume [PracticeDayResolver] and read the
// returned [PracticeDayContext] fields.
//
// Design rules:
// - `resolve()` is intentionally NOT cached. Every call re-reads
//   the clock + the install date. Caching here would mean a
//   long-lived app that crosses local midnight at 23:59:59
//   keeps returning yesterday's context for the rest of its life
//   (or until the Provider is rebuilt). The previous Home
//   controller behaviour already re-ran on `ref.invalidate(...)`
//   for this reason; the resolver just makes that the default.
// - No `DateTime.now()` call inside the resolver body. The
//   instant comes from the injected clock so tests can pin "now"
//   exactly.
// - No direct `AppDatabase` or Repository access here. The
//   resolver depends only on the abstract [InstallDateService]
//   and the clock.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ukulele_app/core/utils/practice_day_calculator.dart';
import 'package:ukulele_app/shared/providers/app_clock_provider.dart';
import 'package:ukulele_app/shared/services/install_date_service.dart';
import 'package:ukulele_app/shared/services/install_date_service_provider.dart';

/// Immutable snapshot of "today" for the user's local calendar.
///
/// Both [today] and [installDate] are projected to the device's
/// local time zone and stripped to local-midnight — i.e. their
/// time-of-day is `00:00:00.000000`. They are the SAME local
/// midnights that were fed to `calculatePracticeDayIndex`, so the
/// in-memory context and the day-index call share a single
/// frame-of-reference. There is no possible UTC/local mismatch
/// between this struct and the index it carries.
@immutable
class PracticeDayContext {
  const PracticeDayContext({
    required this.today,
    required this.installDate,
    required this.dayIndex,
  }) : assert(dayIndex >= 1 && dayIndex <= 7,
            'dayIndex must be in 1..7, got $dayIndex');

  /// Local-midnight of "today" (the user's current calendar day).
  ///
  /// `today.hour == 0 && today.minute == 0 && today.second == 0`,
  /// and `today.isUtc == false`.
  final DateTime today;

  /// Local-midnight of the install date.
  ///
  /// The underlying [InstallDateService] returns a UTC instant; the
  /// resolver projects that instant to local time and strips the
  /// time-of-day. `installDate.hour == 0 && installDate.minute == 0
  /// && installDate.second == 0`, and `installDate.isUtc == false`.
  final DateTime installDate;

  /// 1-based day in the 7-day cycle. Always in `1..7`.
  final int dayIndex;
}

/// Resolves the user's [PracticeDayContext] from the
/// [InstallDateService] and the shared clock.
///
/// Both inputs are projected to local-midnight BEFORE being fed to
/// `calculatePracticeDayIndex`, so the returned [dayIndex] and the
/// stored [PracticeDayContext.today] / `.installDate` agree on the
/// same calendar frame.
class PracticeDayResolver {
  PracticeDayResolver({
    required InstallDateService installDateService,
    required DateTime Function() clock,
  })  : _installDateService = installDateService,
        _clock = clock;

  final InstallDateService _installDateService;
  final DateTime Function() _clock;

  /// Reads the install instant + the current "now", projects both
  /// to local-midnight, and computes the 7-day cycle index.
  ///
  /// Errors from [InstallDateService.getInstallDate] are NOT
  /// swallowed — they propagate to the caller, which surfaces
  /// them through the existing AsyncValue / retry pathway in the
  /// consuming Controller.
  Future<PracticeDayContext> resolve() async {
    final DateTime installInstant = await _installDateService.getInstallDate();
    final DateTime now = _clock();
    final DateTime localInstallDate = _toLocalMidnight(installInstant);
    final DateTime localToday = _toLocalMidnight(now);
    final int dayIndex = calculatePracticeDayIndex(
      installDate: localInstallDate,
      today: localToday,
    );
    return PracticeDayContext(
      today: localToday,
      installDate: localInstallDate,
      dayIndex: dayIndex,
    );
  }

  /// Strips the time-of-day from [d] using the local wall clock.
  ///
  /// If [d] is `isUtc == true`, we project to local first so that
  /// `2026-06-20T23:30Z` (which is already the next day in CST)
  /// lands on the *local* "2026-06-21" midnight, not the UTC
  /// "2026-06-20" midnight.
  static DateTime _toLocalMidnight(DateTime d) {
    final DateTime localD = d.isUtc ? d.toLocal() : d;
    return DateTime(localD.year, localD.month, localD.day);
  }
}

/// Provider for the default [PracticeDayResolver]. Wires the shared
/// `installDateServiceProvider` and `appClockProvider` so every
/// consumer sees the same configuration.
final Provider<PracticeDayResolver> practiceDayResolverProvider =
    Provider<PracticeDayResolver>(
  (Ref ref) => PracticeDayResolver(
    installDateService: ref.watch(installDateServiceProvider),
    clock: ref.watch(appClockProvider),
  ),
);
