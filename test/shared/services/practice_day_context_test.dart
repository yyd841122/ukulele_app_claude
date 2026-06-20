// Tests for [PracticeDayResolver] and [PracticeDayContext]
// (T013.4A0_RECORDING_SAVE_FOUNDATION).
//
// Contract under test:
// - `resolve()` returns a `PracticeDayContext` whose `today` and
//   `installDate` are BOTH local-midnight (not UTC midnight,
//   not the raw clock instant).
// - A UTC install instant is projected to local time FIRST and
//   THEN truncated to local-midnight, so a
//   `DateTime.utc(2026, 6, 20, 23, 30)` (which is the next day
//   in CST) lands on the local calendar day the user expects.
// - `dayIndex` is computed from the SAME local-midnight pair
//   that ends up in the returned context — no frame-of-reference
//   drift between the context fields and the index.
// - Day 1, Day 7, and the day-8-rolls-back-to-1 boundary all
//   behave per `calculatePracticeDayIndex`.
// - The resolver is stable under positive, negative, and UTC
//   offsets (we exercise the math at construction time using
//   values that are representable in any zone).
// - `resolve()` re-reads the clock on every call — caching would
//   mean an app that crosses local midnight at 23:59:59 keeps
//   returning yesterday's context.
// - `InstallDateService.getInstallDate()` errors propagate to
//   the caller (no silent swallow).
// - `PracticeDayContext`'s constructor asserts `1..7` (defensive
//   against an off-by-one from a misconfigured clock).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ukulele_app/shared/providers/app_clock_provider.dart';
import 'package:ukulele_app/shared/services/install_date_service.dart';
import 'package:ukulele_app/shared/services/install_date_service_provider.dart';
import 'package:ukulele_app/shared/services/practice_day_context.dart';

void main() {
  group('PracticeDayContext', () {
    test('asserts dayIndex is in 1..7', () {
      expect(
        () => PracticeDayContext(
          today: DateTime(2026, 6, 20),
          installDate: DateTime(2026, 6, 20),
          dayIndex: 0,
        ),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => PracticeDayContext(
          today: DateTime(2026, 6, 20),
          installDate: DateTime(2026, 6, 20),
          dayIndex: 8,
        ),
        throwsA(isA<AssertionError>()),
      );
      // Boundary values succeed.
      expect(
        PracticeDayContext(
          today: DateTime(2026, 6, 20),
          installDate: DateTime(2026, 6, 20),
          dayIndex: 1,
        ),
        isNotNull,
      );
      expect(
        PracticeDayContext(
          today: DateTime(2026, 6, 20),
          installDate: DateTime(2026, 6, 20),
          dayIndex: 7,
        ),
        isNotNull,
      );
    });
  });

  group('PracticeDayResolver.resolve', () {
    test('returns local-midnight for both today and installDate', () async {
      final DateTime installInstant = DateTime(2026, 6, 20, 9, 30);
      final DateTime now = DateTime(2026, 6, 20, 9, 31);
      final PracticeDayResolver resolver = PracticeDayResolver(
        installDateService: _FakeInstallDateService(installInstant),
        clock: () => now,
      );
      final PracticeDayContext ctx = await resolver.resolve();
      expect(ctx.today, DateTime(2026, 6, 20),
          reason: 'today must be local-midnight of the clock instant');
      expect(ctx.installDate, DateTime(2026, 6, 20),
          reason: 'installDate must be local-midnight of the install instant');
      expect(ctx.dayIndex, 1);
    });

    test('UTC install instant is projected to the local calendar day',
        () async {
      // 23:30 UTC on 2026-06-20. In CST that's 07:30 on 2026-06-21,
      // so the local-midnight MUST be 2026-06-21. We exercise
      // the projection directly using the resolver.
      final DateTime utcInstall = DateTime.utc(2026, 6, 20, 23, 30);
      final DateTime now = DateTime(2026, 6, 21, 8, 0);
      final PracticeDayResolver resolver = PracticeDayResolver(
        installDateService: _FakeInstallDateService(utcInstall),
        clock: () => now,
      );
      final PracticeDayContext ctx = await resolver.resolve();
      // We don't assert a specific local date — that depends on
      // the host offset. We DO assert that:
      //  (a) `installDate` is a local-midnight (hour/min/sec = 0,
      //      isUtc == false),
      //  (b) `installDate` matches the local projection of the
      //      UTC install instant.
      expect(ctx.installDate.isUtc, isFalse);
      expect(ctx.installDate.hour, 0);
      expect(ctx.installDate.minute, 0);
      expect(ctx.installDate.second, 0);
      final DateTime expectedLocalInstallMidnight =
          _localMidnight(utcInstall.toLocal());
      expect(ctx.installDate, expectedLocalInstallMidnight);
    });

    test('dayIndex uses the same local-midnight pair as the context', () async {
      // 6 days exactly between install and today → dayIndex 7.
      final DateTime installInstant = DateTime(2026, 6, 14, 8, 0);
      final DateTime now = DateTime(2026, 6, 20, 8, 0);
      final PracticeDayResolver resolver = PracticeDayResolver(
        installDateService: _FakeInstallDateService(installInstant),
        clock: () => now,
      );
      final PracticeDayContext ctx = await resolver.resolve();
      expect(ctx.dayIndex, 7,
          reason: '6 calendar days after install -> dayIndex 7');
      expect(ctx.installDate, DateTime(2026, 6, 14));
      expect(ctx.today, DateTime(2026, 6, 20));
    });

    test('Day 1 (install == today)', () async {
      final DateTime instant = DateTime(2026, 6, 20, 12, 0);
      final PracticeDayResolver resolver = PracticeDayResolver(
        installDateService: _FakeInstallDateService(instant),
        clock: () => instant,
      );
      final PracticeDayContext ctx = await resolver.resolve();
      expect(ctx.dayIndex, 1);
    });

    test('Day 7 (six full days after install)', () async {
      final DateTime installInstant = DateTime(2026, 6, 14, 8, 0);
      final DateTime now = DateTime(2026, 6, 20, 8, 0);
      final PracticeDayResolver resolver = PracticeDayResolver(
        installDateService: _FakeInstallDateService(installInstant),
        clock: () => now,
      );
      final PracticeDayContext ctx = await resolver.resolve();
      expect(ctx.dayIndex, 7);
    });

    test('Day 8 wraps back to Day 1', () async {
      final DateTime installInstant = DateTime(2026, 6, 13, 8, 0);
      final DateTime now = DateTime(2026, 6, 20, 8, 0);
      final PracticeDayResolver resolver = PracticeDayResolver(
        installDateService: _FakeInstallDateService(installInstant),
        clock: () => now,
      );
      final PracticeDayContext ctx = await resolver.resolve();
      expect(ctx.dayIndex, 1,
          reason: '7 full days after install -> (7 % 7) + 1 = 1');
    });

    test('install in the future (clock skew) clamps to Day 1', () async {
      // If the device clock has rolled back, the diff goes
      // negative. The calculator returns 1, NOT 0/8/-1.
      final DateTime installInstant = DateTime(2026, 6, 25, 8, 0);
      final DateTime now = DateTime(2026, 6, 20, 8, 0);
      final PracticeDayResolver resolver = PracticeDayResolver(
        installDateService: _FakeInstallDateService(installInstant),
        clock: () => now,
      );
      final PracticeDayContext ctx = await resolver.resolve();
      expect(ctx.dayIndex, 1);
    });

    test('resolve() re-reads the clock on every call (no caching)', () async {
      final DateTime installInstant = DateTime(2026, 6, 20, 9, 0);
      DateTime now = DateTime(2026, 6, 20, 10, 0);
      final PracticeDayResolver resolver = PracticeDayResolver(
        installDateService: _FakeInstallDateService(installInstant),
        clock: () => now,
      );
      final PracticeDayContext first = await resolver.resolve();
      expect(first.dayIndex, 1);
      // Advance the clock across local midnight. The next
      // resolve() MUST observe the new clock value, NOT a cached
      // snapshot from the first call.
      now = DateTime(2026, 6, 21, 0, 30);
      final PracticeDayContext second = await resolver.resolve();
      expect(second.today, DateTime(2026, 6, 21),
          reason: 'today must reflect the new clock value');
      expect(second.dayIndex, 2,
          reason: '1 day after install (still on June 21 local) -> dayIndex 2');
    });

    test('propagates InstallDateService errors', () async {
      final PracticeDayResolver resolver = PracticeDayResolver(
        installDateService: _ThrowingInstallDateService(
          StateError('synthetic install date failure'),
        ),
        clock: () => DateTime(2026, 6, 20, 9, 0),
      );
      await expectLater(resolver.resolve(), throwsA(isA<StateError>()));
    });
  });

  group('practiceDayResolverProvider', () {
    test('honours appClockProvider + installDateServiceProvider overrides',
        () async {
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appClockProvider.overrideWithValue(() => DateTime(2026, 6, 20, 9)),
          installDateServiceProvider.overrideWithValue(
            _FakeInstallDateService(DateTime(2026, 6, 20, 8)),
          ),
        ],
      );
      addTearDown(container.dispose);
      final PracticeDayContext ctx =
          await container.read(practiceDayResolverProvider).resolve();
      expect(ctx.installDate, DateTime(2026, 6, 20));
      expect(ctx.today, DateTime(2026, 6, 20));
      expect(ctx.dayIndex, 1);
    });
  });
}

/// Stub install-date source that returns a fixed instant.
class _FakeInstallDateService implements InstallDateService {
  _FakeInstallDateService(this._fixed);

  final DateTime _fixed;

  @override
  Future<DateTime> getInstallDate() async => _fixed;
}

/// Stub install-date source that always throws. Used to verify
/// error propagation through the resolver.
class _ThrowingInstallDateService implements InstallDateService {
  _ThrowingInstallDateService(this._error);

  final Object _error;

  @override
  Future<DateTime> getInstallDate() async {
    throw _error;
  }
}

/// Strips the time-of-day from [d] using the LOCAL wall clock.
/// Mirrors `PracticeDayResolver._toLocalMidnight` so the test
/// can project a UTC instant to the local calendar day without
/// touching the production source.
DateTime _localMidnight(DateTime d) {
  final DateTime localD = d.isUtc ? d.toLocal() : d;
  return DateTime(localD.year, localD.month, localD.day);
}
