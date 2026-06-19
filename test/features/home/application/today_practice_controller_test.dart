// Tests for [TodayPracticeController].
//
// T007 scope:
// - Verify that the controller derives Day 1 from a fresh install date
//   and flips completion state correctly.
// - Verify that the clock is injectable so the day index can be driven
//   to other days.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ukulele_app/features/home/application/today_practice_controller.dart';
import 'package:ukulele_app/shared/services/install_date_service.dart';

void main() {
  group('TodayPracticeController', () {
    test('fresh install date with today = install date -> Day 1', () {
      final DateTime fixed = DateTime(2026, 6, 20, 9, 0);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          installDateServiceProvider.overrideWithValue(
            _FakeInstallDateService(fixed),
          ),
          clockProvider.overrideWithValue(() => fixed),
        ],
      );
      addTearDown(container.dispose);

      final TodayPracticeState state =
          container.read(todayPracticeControllerProvider);
      expect(state.dayIndex, 1);
      expect(state.plan.tasks, isNotEmpty);
      expect(state.completedTaskCount, 0);
    });

    test('toggleTaskCompleted flips status and counts', () {
      final DateTime fixed = DateTime(2026, 6, 20, 9, 0);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          installDateServiceProvider.overrideWithValue(
            _FakeInstallDateService(fixed),
          ),
          clockProvider.overrideWithValue(() => fixed),
        ],
      );
      addTearDown(container.dispose);

      final TodayPracticeController controller =
          container.read(todayPracticeControllerProvider.notifier);
      final String firstTaskId =
          container.read(todayPracticeControllerProvider).plan.tasks.first.id;

      controller.toggleTaskCompleted(firstTaskId);

      TodayPracticeState state =
          container.read(todayPracticeControllerProvider);
      expect(state.isTaskCompleted(firstTaskId), isTrue);
      expect(state.completedTaskCount, 1);

      // Toggling again clears the flag.
      controller.toggleTaskCompleted(firstTaskId);
      state = container.read(todayPracticeControllerProvider);
      expect(state.isTaskCompleted(firstTaskId), isFalse);
      expect(state.completedTaskCount, 0);
    });

    test('clock offset by 7 days rolls Day 1 -> Day 1', () {
      final DateTime fixed = DateTime(2026, 6, 20, 9, 0);
      final DateTime todayPlus7 = DateTime(2026, 6, 27, 9, 0);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          installDateServiceProvider.overrideWithValue(
            _FakeInstallDateService(fixed),
          ),
          clockProvider.overrideWithValue(() => todayPlus7),
        ],
      );
      addTearDown(container.dispose);

      final TodayPracticeState state =
          container.read(todayPracticeControllerProvider);
      expect(state.dayIndex, 1);
    });

    test('clock offset by 6 days -> Day 7', () {
      final DateTime fixed = DateTime(2026, 6, 20, 9, 0);
      final DateTime todayPlus6 = DateTime(2026, 6, 26, 9, 0);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          installDateServiceProvider.overrideWithValue(
            _FakeInstallDateService(fixed),
          ),
          clockProvider.overrideWithValue(() => todayPlus6),
        ],
      );
      addTearDown(container.dispose);

      final TodayPracticeState state =
          container.read(todayPracticeControllerProvider);
      expect(state.dayIndex, 7);
    });
  });
}

/// Install date stub that always returns the same instant. We deliberately
/// implement the interface (rather than extending [InMemoryInstallDateService])
/// so the test cannot accidentally mutate the in-memory cache and bleed
/// into other tests.
class _FakeInstallDateService implements InstallDateService {
  _FakeInstallDateService(this._fixed);

  final DateTime _fixed;

  @override
  DateTime getInstallDate() => _fixed;
}