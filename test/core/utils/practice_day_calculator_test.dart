// Tests for [calculatePracticeDayIndex].
//
// Covers all cases listed in the T007 task brief §8.

import 'package:flutter_test/flutter_test.dart';

import 'package:ukulele_app/core/utils/practice_day_calculator.dart';

void main() {
  group('calculatePracticeDayIndex', () {
    final DateTime install = DateTime(2026, 6, 20); // local-midnight

    test('install day -> Day 1', () {
      expect(
        calculatePracticeDayIndex(
          installDate: install,
          today: DateTime(2026, 6, 20),
        ),
        1,
      );
    });

    test('one day after install -> Day 2', () {
      expect(
        calculatePracticeDayIndex(
          installDate: install,
          today: DateTime(2026, 6, 21),
        ),
        2,
      );
    });

    test('six days after install -> Day 7', () {
      expect(
        calculatePracticeDayIndex(
          installDate: install,
          today: DateTime(2026, 6, 26),
        ),
        7,
      );
    });

    test('seven days after install -> Day 1 (cycle wraps)', () {
      expect(
        calculatePracticeDayIndex(
          installDate: install,
          today: DateTime(2026, 6, 27),
        ),
        1,
      );
    });

    test('eight days after install -> Day 2', () {
      expect(
        calculatePracticeDayIndex(
          installDate: install,
          today: DateTime(2026, 6, 28),
        ),
        2,
      );
    });

    test('today earlier than installDate -> Day 1 (clock skew safety)', () {
      expect(
        calculatePracticeDayIndex(
          installDate: install,
          today: DateTime(2026, 6, 19),
        ),
        1,
      );
    });

    test('time-of-day is ignored (both sides normalised to local midnight)',
        () {
      // Install late at night, then check immediately. The local date
      // has not rolled over yet, so it should still be Day 1.
      final DateTime installLateNight = DateTime(2026, 6, 20, 23, 30);
      final DateTime todayLaterSameDay = DateTime(2026, 6, 20, 23, 45);
      expect(
        calculatePracticeDayIndex(
          installDate: installLateNight,
          today: todayLaterSameDay,
        ),
        1,
      );

      // The next morning the local date has rolled over -> Day 2.
      final DateTime todayEarlyMorning = DateTime(2026, 6, 21, 0, 30);
      expect(
        calculatePracticeDayIndex(
          installDate: installLateNight,
          today: todayEarlyMorning,
        ),
        2,
      );
    });

    test('result is always in 1..7 even across a long stretch', () {
      // 365 days after install. 365 % 7 == 1, so result must be 2.
      expect(
        calculatePracticeDayIndex(
          installDate: install,
          today: DateTime(2027, 6, 20),
        ),
        2,
      );
    });
  });
}
