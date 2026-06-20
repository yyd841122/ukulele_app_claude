// Tests for [TunerController].
//
// T011 scope:
// - Verify the initial state is sane (confirmedCount 0, every
//   built-in string present, allConfirmed false).
// - Verify toggleConfirmed adds / removes a string and does NOT
//   double-count.
// - Verify unknown stringNumbers are no-ops.
// - Verify resetAll clears state and emits a fresh empty set.
// - Verify confirmAll marks every shipped string as confirmed.
// - Verify allConfirmed flips to true only when every shipped
//   string is confirmed.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ukulele_app/features/tuner/application/tuner_controller.dart';
import 'package:ukulele_app/features/tuner/data/standard_ukulele_tuning.dart';
import 'package:ukulele_app/features/tuner/domain/tuning_string.dart';

void main() {
  group('TunerController', () {
    test('initial state has all four strings and zero confirmed', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final TunerState state = container.read(tunerControllerProvider);

      expect(state.strings.length, kBuiltInTuningStrings.length);
      expect(state.totalCount, kBuiltInTuningStrings.length);
      expect(state.confirmedCount, 0);
      expect(state.confirmedStringNumbers, isEmpty);
      expect(state.allConfirmed, isFalse);
      // Display order: G, C, E, A.
      expect(
        state.stringsInDisplayOrder
            .map((TuningString s) => s.stringName)
            .toList(),
        <String>['G', 'C', 'E', 'A'],
      );
    });

    test('toggleConfirmed adds and removes a known string', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final TunerController controller =
          container.read(tunerControllerProvider.notifier);

      // Confirm string 1 (A).
      controller.toggleConfirmed(1);
      TunerState state = container.read(tunerControllerProvider);
      expect(state.confirmedCount, 1);
      expect(state.isConfirmed(1), isTrue);
      expect(state.confirmedStringNumbers, <int>{1});

      // Toggle again removes it.
      controller.toggleConfirmed(1);
      state = container.read(tunerControllerProvider);
      expect(state.confirmedCount, 0);
      expect(state.isConfirmed(1), isFalse);
      expect(state.confirmedStringNumbers, isEmpty);
    });

    test('toggleConfirmed does not double-count the same string', () {
      // Toggling the same string many times must never exceed 1
      // confirmed entry for it.
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final TunerController controller =
          container.read(tunerControllerProvider.notifier);

      for (int i = 0; i < 5; i++) {
        controller.toggleConfirmed(4); // add
        controller.toggleConfirmed(4); // remove
      }
      final TunerState state = container.read(tunerControllerProvider);
      expect(state.confirmedCount, 0);
      expect(state.isConfirmed(4), isFalse);
    });

    test('toggleConfirmed supports multiple strings', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final TunerController controller =
          container.read(tunerControllerProvider.notifier);

      controller.toggleConfirmed(4); // G
      controller.toggleConfirmed(3); // C
      controller.toggleConfirmed(2); // E

      final TunerState state = container.read(tunerControllerProvider);
      expect(state.confirmedCount, 3);
      expect(state.isConfirmed(4), isTrue);
      expect(state.isConfirmed(3), isTrue);
      expect(state.isConfirmed(2), isTrue);
      expect(state.isConfirmed(1), isFalse);
      expect(state.allConfirmed, isFalse);
    });

    test('toggleConfirmed is a no-op for unknown stringNumbers', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final TunerController controller =
          container.read(tunerControllerProvider.notifier);
      final TunerState before = container.read(tunerControllerProvider);

      for (final int n in const <int>[0, -1, 5, 99, -100]) {
        controller.toggleConfirmed(n);
      }

      final TunerState after = container.read(tunerControllerProvider);
      expect(after.confirmedCount, before.confirmedCount);
      expect(after.confirmedStringNumbers, before.confirmedStringNumbers);
      expect(after.isConfirmed(0), isFalse);
      expect(after.isConfirmed(5), isFalse);
      expect(after.isConfirmed(-1), isFalse);
    });

    test('resetAll clears every confirmed string', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final TunerController controller =
          container.read(tunerControllerProvider.notifier);

      controller.toggleConfirmed(4);
      controller.toggleConfirmed(2);
      expect(container.read(tunerControllerProvider).confirmedCount, 2);

      controller.resetAll();

      final TunerState state = container.read(tunerControllerProvider);
      expect(state.confirmedCount, 0);
      expect(state.confirmedStringNumbers, isEmpty);
      expect(state.allConfirmed, isFalse);
    });

    test('resetAll on an already-empty set does not throw', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final TunerController controller =
          container.read(tunerControllerProvider.notifier);
      // Should not throw and should leave state unchanged.
      controller.resetAll();
      final TunerState state = container.read(tunerControllerProvider);
      expect(state.confirmedCount, 0);
      expect(state.confirmedStringNumbers, isEmpty);
    });

    test('confirmAll marks every shipped string as confirmed', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final TunerController controller =
          container.read(tunerControllerProvider.notifier);
      controller.confirmAll();

      final TunerState state = container.read(tunerControllerProvider);
      expect(state.confirmedCount, state.totalCount);
      expect(state.allConfirmed, isTrue);
      expect(state.confirmedStringNumbers, <int>{1, 2, 3, 4});
    });

    test('allConfirmed is true only when every string is confirmed', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final TunerController controller =
          container.read(tunerControllerProvider.notifier);

      // Confirm three out of four.
      controller.toggleConfirmed(4);
      controller.toggleConfirmed(3);
      controller.toggleConfirmed(2);
      expect(
        container.read(tunerControllerProvider).allConfirmed,
        isFalse,
      );

      // Confirm the fourth.
      controller.toggleConfirmed(1);
      final TunerState state = container.read(tunerControllerProvider);
      expect(state.confirmedCount, 4);
      expect(state.allConfirmed, isTrue);
    });

    test('builtInTuningStringsProvider exposes the shipped list', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);
      final List<TuningString> strings =
          container.read(builtInTuningStringsProvider);
      expect(strings.length, kBuiltInTuningStrings.length);
      expect(
        strings.map((TuningString s) => s.stringName).toList(),
        kBuiltInTuningStrings.map((TuningString s) => s.stringName).toList(),
      );
    });

    test(
        'tuningStringsDisplayOrderProvider exposes G, C, E, A in that order',
        () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);
      final List<TuningString> ordered =
          container.read(tuningStringsDisplayOrderProvider);
      expect(
        ordered.map((TuningString s) => s.stringName).toList(),
        <String>['G', 'C', 'E', 'A'],
      );
    });
  });
}