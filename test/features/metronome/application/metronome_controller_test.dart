// Tests for [MetronomeController] and [MetronomeSettings].
//
// T010 scope:
// - Settings defaults and clamping.
// - Beat progression (tickForTesting only — never real time).
// - beatsPerBar whitelist.
// - start / stop / toggleRunning behaviour.
//
// Testing strategy — Timer coverage is intentionally limited:
// - T010 does NOT directly assert the number of `Timer` instances
//   held by the controller (we have no fake test double for it and
//   we deliberately do not pull in `package:fake_async` for this
//   MVP).
// - T010 does NOT verify real periodic tick precision, accuracy of
//   the `Duration` between two ticks, or any wall-clock behaviour.
// - T010 NEVER calls `sleep`, `Future.delayed` + await, or
//   `tester.pump(Duration(...))` to wait for a real tick.
// - Timer-related tests only cover:
//     * public state transitions (isRunning flips on start/stop/
//       toggleRunning; currentBeat resets to 1 on stop);
//     * safety of `dispose` when a timer is active (must not throw
//       and must cancel the in-flight periodic timer so the
//       provider can be torn down without leaking it).
// - Beat progression itself is fixed by [tickForTesting]. Every
//   beat-related test calls that method directly. The Timer is
//   therefore the *runtime* driver only; it is not exercised by
//   the test suite.
//
// We deliberately never call [start] in tests, except for the
// handful that explicitly assert the timer is created. Those tests
// dispose the provider immediately to cancel the timer and never
// rely on real wall-clock time.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ukulele_app/features/metronome/application/metronome_controller.dart';
import 'package:ukulele_app/features/metronome/domain/metronome_settings.dart';

void main() {
  group('MetronomeSettings', () {
    test('default values are sane', () {
      const MetronomeSettings s = MetronomeSettings(
        bpm: kMetronomeDefaultBpm,
        minBpm: kMetronomeMinBpm,
        maxBpm: kMetronomeMaxBpm,
        beatsPerBar: kMetronomeDefaultBeatsPerBar,
        soundEnabled: false,
      );
      expect(s.bpm, 80);
      expect(s.minBpm, 40);
      expect(s.maxBpm, 200);
      expect(s.beatsPerBar, 4);
      expect(s.soundEnabled, isFalse);
    });

    test('clampBpm respects min and max', () {
      const MetronomeSettings s = MetronomeSettings(
        bpm: 80,
        minBpm: 40,
        maxBpm: 200,
        beatsPerBar: 4,
        soundEnabled: false,
      );
      expect(s.clampBpm(10), 40);
      expect(s.clampBpm(40), 40);
      expect(s.clampBpm(100), 100);
      expect(s.clampBpm(999), 200);
    });

    test('allowedBeatsPerBar exposes 2, 3, 4, 6', () {
      expect(MetronomeSettings.allowedBeatsPerBar, <int>[2, 3, 4, 6]);
      expect(MetronomeSettings.isAllowedBeatsPerBar(2), isTrue);
      expect(MetronomeSettings.isAllowedBeatsPerBar(3), isTrue);
      expect(MetronomeSettings.isAllowedBeatsPerBar(4), isTrue);
      expect(MetronomeSettings.isAllowedBeatsPerBar(6), isTrue);
      expect(MetronomeSettings.isAllowedBeatsPerBar(5), isFalse);
      expect(MetronomeSettings.isAllowedBeatsPerBar(0), isFalse);
    });

    test('copyWith silently coerces out-of-range bpm and beatsPerBar', () {
      const MetronomeSettings s = MetronomeSettings(
        bpm: 80,
        minBpm: 40,
        maxBpm: 200,
        beatsPerBar: 4,
        soundEnabled: false,
      );
      // BPM clamped.
      expect(s.copyWith(bpm: 5).bpm, 40);
      expect(s.copyWith(bpm: 9999).bpm, 200);
      // Invalid beatsPerBar keeps the existing one.
      expect(s.copyWith(beatsPerBar: 5).beatsPerBar, 4);
      // Valid beatsPerBar is accepted.
      expect(s.copyWith(beatsPerBar: 3).beatsPerBar, 3);
      // soundEnabled toggles.
      expect(s.copyWith(soundEnabled: true).soundEnabled, isTrue);
    });
  });

  group('MetronomeController', () {
    test('initial state has default BPM 80 and beat 1', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final MetronomeState state =
          container.read(metronomeControllerProvider);

      expect(state.bpm, 80);
      expect(state.beatsPerBar, 4);
      expect(state.currentBeat, 1);
      expect(state.isRunning, isFalse);
      expect(state.tickCount, 0);
      expect(state.settings.soundEnabled, isFalse);
    });

    test('setBpm clamps values below min', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final MetronomeController controller =
          container.read(metronomeControllerProvider.notifier);
      controller.setBpm(10);
      expect(
        container.read(metronomeControllerProvider).bpm,
        kMetronomeMinBpm,
      );
    });

    test('setBpm clamps values above max', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final MetronomeController controller =
          container.read(metronomeControllerProvider.notifier);
      controller.setBpm(9999);
      expect(
        container.read(metronomeControllerProvider).bpm,
        kMetronomeMaxBpm,
      );
    });

    test('increaseBpm and decreaseBpm work and stay within bounds', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final MetronomeController controller =
          container.read(metronomeControllerProvider.notifier);

      controller.increaseBpm();
      expect(container.read(metronomeControllerProvider).bpm, 81);
      controller.decreaseBpm();
      controller.decreaseBpm();
      expect(container.read(metronomeControllerProvider).bpm, 79);

      // Walk to the floor.
      for (int i = 0; i < 200; i++) {
        controller.decreaseBpm();
      }
      expect(
        container.read(metronomeControllerProvider).bpm,
        kMetronomeMinBpm,
      );

      // And to the ceiling.
      for (int i = 0; i < 500; i++) {
        controller.increaseBpm();
      }
      expect(
        container.read(metronomeControllerProvider).bpm,
        kMetronomeMaxBpm,
      );
    });

    test('setBeatsPerBar accepts 2, 3, 4, 6', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final MetronomeController controller =
          container.read(metronomeControllerProvider.notifier);

      for (final int beats in MetronomeSettings.allowedBeatsPerBar) {
        controller.setBeatsPerBar(beats);
        expect(
          container.read(metronomeControllerProvider).beatsPerBar,
          beats,
        );
      }
    });

    test('setBeatsPerBar rejects invalid values without changing state', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final MetronomeController controller =
          container.read(metronomeControllerProvider.notifier);
      final int original =
          container.read(metronomeControllerProvider).beatsPerBar;

      // Try a handful of bad values.
      for (final int bad in const <int>[-1, 0, 1, 5, 7, 99]) {
        controller.setBeatsPerBar(bad);
      }
      expect(
        container.read(metronomeControllerProvider).beatsPerBar,
        original,
      );
    });

    test('tickForTesting advances from 1 to 2 and increments tickCount', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final MetronomeController controller =
          container.read(metronomeControllerProvider.notifier);

      expect(container.read(metronomeControllerProvider).currentBeat, 1);
      controller.tickForTesting();
      MetronomeState state = container.read(metronomeControllerProvider);
      expect(state.currentBeat, 2);
      expect(state.tickCount, 1);
    });

    test('currentBeat wraps back to 1 after the last beat of a bar', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final MetronomeController controller =
          container.read(metronomeControllerProvider.notifier);

      // Advance from 1 to 4.
      controller.tickForTesting(); // 2
      controller.tickForTesting(); // 3
      controller.tickForTesting(); // 4
      expect(
        container.read(metronomeControllerProvider).currentBeat,
        4,
      );

      // Next tick wraps to 1.
      controller.tickForTesting();
      expect(
        container.read(metronomeControllerProvider).currentBeat,
        1,
      );
      expect(
        container.read(metronomeControllerProvider).tickCount,
        4,
      );
    });

    test('changing beatsPerBar mid-bar clamps currentBeat into range', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final MetronomeController controller =
          container.read(metronomeControllerProvider.notifier);

      // Walk to beat 4 of a 4-beat bar.
      controller.tickForTesting();
      controller.tickForTesting();
      controller.tickForTesting();
      expect(
        container.read(metronomeControllerProvider).currentBeat,
        4,
      );

      // Drop to 2 beats per bar. currentBeat must clamp to 2.
      controller.setBeatsPerBar(2);
      expect(
        container.read(metronomeControllerProvider).beatsPerBar,
        2,
      );
      expect(
        container.read(metronomeControllerProvider).currentBeat,
        2,
      );
    });

    test('start sets isRunning to true; stop resets currentBeat to 1', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final MetronomeController controller =
          container.read(metronomeControllerProvider.notifier);

      controller.start();
      expect(
        container.read(metronomeControllerProvider).isRunning,
        isTrue,
      );

      // Tick forward manually to move currentBeat away from 1.
      controller.tickForTesting();
      controller.tickForTesting();
      expect(
        container.read(metronomeControllerProvider).currentBeat,
        3,
      );

      controller.stop();
      MetronomeState state =
          container.read(metronomeControllerProvider);
      expect(state.isRunning, isFalse);
      expect(state.currentBeat, 1);
    });

    test('toggleRunning flips state', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final MetronomeController controller =
          container.read(metronomeControllerProvider.notifier);

      controller.toggleRunning();
      expect(
        container.read(metronomeControllerProvider).isRunning,
        isTrue,
      );
      controller.toggleRunning();
      expect(
        container.read(metronomeControllerProvider).isRunning,
        isFalse,
      );
      controller.toggleRunning();
      expect(
        container.read(metronomeControllerProvider).isRunning,
        isTrue,
      );
      // Leave it stopped so the timer is cancelled on dispose.
      controller.stop();
    });

    test('calling start twice does not change the running state', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final MetronomeController controller =
          container.read(metronomeControllerProvider.notifier);

      controller.start();
      expect(
        container.read(metronomeControllerProvider).isRunning,
        isTrue,
      );
      // Second start is a no-op.
      controller.start();
      expect(
        container.read(metronomeControllerProvider).isRunning,
        isTrue,
      );
      // Manually tick — should still work exactly once per call.
      controller.tickForTesting();
      expect(
        container.read(metronomeControllerProvider).currentBeat,
        2,
      );
      controller.tickForTesting();
      expect(
        container.read(metronomeControllerProvider).currentBeat,
        3,
      );

      controller.stop();
    });

    test('dispose cancels the active timer', () {
      final ProviderContainer container = ProviderContainer();
      final MetronomeController controller =
          container.read(metronomeControllerProvider.notifier);

      controller.start();
      expect(
        container.read(metronomeControllerProvider).isRunning,
        isTrue,
      );
      // Disposing must not throw — `ref.onDispose` cancels the timer.
      container.dispose();
      // We can't read state from a disposed container; the assertion
      // is that dispose itself did not raise.
    });

    test('toggleSoundEnabled flips the soundEnabled flag', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final MetronomeController controller =
          container.read(metronomeControllerProvider.notifier);

      expect(
        container.read(metronomeControllerProvider).settings.soundEnabled,
        isFalse,
      );
      controller.toggleSoundEnabled();
      expect(
        container.read(metronomeControllerProvider).settings.soundEnabled,
        isTrue,
      );
      controller.toggleSoundEnabled();
      expect(
        container.read(metronomeControllerProvider).settings.soundEnabled,
        isFalse,
      );
    });

    test('changing BPM while running updates state and timer interval', () {
      // We can't observe the timer interval directly, but we can
      // verify the BPM update is applied to the state and that
      // stopping afterwards is still possible (i.e. no leaked timer).
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final MetronomeController controller =
          container.read(metronomeControllerProvider.notifier);

      controller.start();
      controller.setBpm(120);
      expect(
        container.read(metronomeControllerProvider).bpm,
        120,
      );
      expect(
        container.read(metronomeControllerProvider).isRunning,
        isTrue,
      );
      controller.stop();
      expect(
        container.read(metronomeControllerProvider).isRunning,
        isFalse,
      );
    });
  });
}