// Tests for [RecordingPracticeController] (T012).
//
// Scope:
// - Verify the initial state is the documented baseline.
// - Verify start / stop / play / stop-playback transitions and
//   the "play while recording is a no-op" and "start while playing
//   stops playback + starts recording" rules from the brief.
// - Verify setSelfRating / setNote mutate only outside recording.
// - Verify reset clears state, rating, and note.
// - Verify tickForTesting advances the simulated clock without
//   any wall-clock time.
// - Verify dispose cancels an in-flight timer without throwing.
//
// Testing strategy — Timer coverage mirrors [MetronomeController]:
// - Tests never call `sleep`, never `await Future.delayed`, never
//   pump a real Duration. They only call [tickForTesting].
// - Tests that DO call [startRecording] / [play] (which spin up a
//   real timer) dispose the container immediately to cancel the
//   timer so it does not leak between tests.
// - We deliberately do NOT assert the *number* of `Timer`s held by
//   the controller; we only assert that public state transitions
//   happen and that dispose is safe.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ukulele_app/features/recording/application/recording_practice_controller.dart';
import 'package:ukulele_app/features/recording/domain/self_rating.dart';

void main() {
  group('RecordingPracticeState', () {
    test('initial baseline is documented', () {
      const RecordingPracticeState s = RecordingPracticeState.initial;
      expect(s.isRecording, isFalse);
      expect(s.hasRecording, isFalse);
      expect(s.isPlaying, isFalse);
      expect(s.elapsedSeconds, 0);
      expect(s.selfRating, isNull);
      expect(s.note, '');
      expect(s.statusLabel, '准备录音');
      expect(s.formattedElapsed, '00:00');
    });

    test('statusLabel reflects each documented phase', () {
      const RecordingPracticeState ready = RecordingPracticeState.initial;
      expect(ready.statusLabel, '准备录音');

      const RecordingPracticeState recording = RecordingPracticeState(
        isRecording: true,
        hasRecording: false,
        isPlaying: false,
        elapsedSeconds: 3,
        selfRating: null,
        note: '',
      );
      expect(recording.statusLabel, '模拟录音中');

      const RecordingPracticeState playback = RecordingPracticeState(
        isRecording: false,
        hasRecording: true,
        isPlaying: true,
        elapsedSeconds: 5,
        selfRating: null,
        note: '',
      );
      expect(playback.statusLabel, '模拟回放中');

      const RecordingPracticeState done = RecordingPracticeState(
        isRecording: false,
        hasRecording: true,
        isPlaying: false,
        elapsedSeconds: 12,
        selfRating: SelfRating.good,
        note: 'ok',
      );
      expect(done.statusLabel, '已录音（可回放 / 自评）');
    });

    test('formattedElapsed pads minutes and seconds to two digits', () {
      const RecordingPracticeState s = RecordingPracticeState(
        isRecording: false,
        hasRecording: false,
        isPlaying: false,
        elapsedSeconds: 0,
        selfRating: null,
        note: '',
      );
      // Build a few derived states by copyWith to exercise the
      // formatter across the minute boundary.
      expect(s.formattedElapsed, '00:00');
      expect(s.copyWith(elapsedSeconds: 9).formattedElapsed, '00:09');
      expect(s.copyWith(elapsedSeconds: 59).formattedElapsed, '00:59');
      expect(s.copyWith(elapsedSeconds: 60).formattedElapsed, '01:00');
      expect(s.copyWith(elapsedSeconds: 125).formattedElapsed, '02:05');
    });

    test('copyWith with clearSelfRating drops the rating', () {
      const RecordingPracticeState s = RecordingPracticeState(
        isRecording: false,
        hasRecording: true,
        isPlaying: false,
        elapsedSeconds: 10,
        selfRating: SelfRating.good,
        note: 'x',
      );
      expect(s.copyWith(clearSelfRating: true).selfRating, isNull);
      // Passing selfRating via copyWith still works.
      expect(s.copyWith(selfRating: SelfRating.retry).selfRating,
          SelfRating.retry);
    });
  });

  group('SelfRating', () {
    test('labels and shortLabels cover all three buckets', () {
      expect(SelfRating.values.length, 3);
      expect(SelfRating.good.label, '还不错');
      expect(SelfRating.good.shortLabel, '好');
      expect(SelfRating.okay.label, '一般');
      expect(SelfRating.okay.shortLabel, '一般');
      expect(SelfRating.retry.label, '需要重练');
      expect(SelfRating.retry.shortLabel, '重练');
    });
  });

  group('RecordingPracticeController', () {
    test('initial state is the documented baseline', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final RecordingPracticeState state =
          container.read(recordingPracticeControllerProvider);

      expect(state.isRecording, isFalse);
      expect(state.hasRecording, isFalse);
      expect(state.isPlaying, isFalse);
      expect(state.elapsedSeconds, 0);
      expect(state.selfRating, isNull);
      expect(state.note, '');
    });

    test('startRecording flips isRecording and resets elapsedSeconds',
        () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final RecordingPracticeController controller =
          container.read(recordingPracticeControllerProvider.notifier);

      // Pre-poison the state via tickForTesting + setSelfRating to
      // prove startRecording resets the clock and starts a fresh
      // take.
      controller.tickForTesting();
      controller.tickForTesting();

      controller.startRecording();
      RecordingPracticeState state =
          container.read(recordingPracticeControllerProvider);
      expect(state.isRecording, isTrue);
      expect(state.hasRecording, isFalse);
      expect(state.isPlaying, isFalse);
      expect(state.elapsedSeconds, 0);

      // Cleanup the timer.
      controller.stopRecording();
    });

    test('startRecording while already recording is a no-op', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final RecordingPracticeController controller =
          container.read(recordingPracticeControllerProvider.notifier);
      controller.startRecording();
      final int firstElapsed = container
          .read(recordingPracticeControllerProvider)
          .elapsedSeconds;

      controller.startRecording();
      final RecordingPracticeState state =
          container.read(recordingPracticeControllerProvider);
      expect(state.isRecording, isTrue);
      expect(state.elapsedSeconds, firstElapsed);

      controller.stopRecording();
    });

    test('stopRecording sets hasRecording = true', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final RecordingPracticeController controller =
          container.read(recordingPracticeControllerProvider.notifier);
      controller.startRecording();
      controller.tickForTesting();
      controller.tickForTesting();
      controller.stopRecording();

      final RecordingPracticeState state =
          container.read(recordingPracticeControllerProvider);
      expect(state.isRecording, isFalse);
      expect(state.hasRecording, isTrue);
      expect(state.elapsedSeconds, 2);
    });

    test('stopRecording without an active recording is a no-op', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final RecordingPracticeController controller =
          container.read(recordingPracticeControllerProvider.notifier);
      controller.stopRecording();
      final RecordingPracticeState state =
          container.read(recordingPracticeControllerProvider);
      expect(state.isRecording, isFalse);
      expect(state.hasRecording, isFalse);
    });

    test('play is a no-op when there is no recording', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final RecordingPracticeController controller =
          container.read(recordingPracticeControllerProvider.notifier);
      controller.play();
      final RecordingPracticeState state =
          container.read(recordingPracticeControllerProvider);
      expect(state.isPlaying, isFalse);
      expect(state.hasRecording, isFalse);
    });

    test('play is a no-op while recording', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final RecordingPracticeController controller =
          container.read(recordingPracticeControllerProvider.notifier);
      controller.startRecording();
      controller.play();
      final RecordingPracticeState state =
          container.read(recordingPracticeControllerProvider);
      expect(state.isRecording, isTrue);
      expect(state.isPlaying, isFalse);

      controller.stopRecording();
    });

    test('play works after stopRecording', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final RecordingPracticeController controller =
          container.read(recordingPracticeControllerProvider.notifier);
      controller.startRecording();
      controller.tickForTesting();
      controller.stopRecording();

      controller.play();
      RecordingPracticeState state =
          container.read(recordingPracticeControllerProvider);
      expect(state.isPlaying, isTrue);
      expect(state.isRecording, isFalse);
      expect(state.hasRecording, isTrue);

      // Cleanup the playback timer.
      controller.stopPlayback();
    });

    test('stopPlayback clears isPlaying but keeps hasRecording', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final RecordingPracticeController controller =
          container.read(recordingPracticeControllerProvider.notifier);
      controller.startRecording();
      controller.tickForTesting();
      controller.stopRecording();
      controller.play();
      controller.stopPlayback();

      final RecordingPracticeState state =
          container.read(recordingPracticeControllerProvider);
      expect(state.isPlaying, isFalse);
      expect(state.hasRecording, isTrue);
    });

    test('stopPlayback without playback is a no-op', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final RecordingPracticeController controller =
          container.read(recordingPracticeControllerProvider.notifier);
      controller.stopPlayback();
      final RecordingPracticeState state =
          container.read(recordingPracticeControllerProvider);
      expect(state.isPlaying, isFalse);
      expect(state.hasRecording, isFalse);
    });

    test(
      'startRecording while playing stops playback and starts a new take',
      () {
        final ProviderContainer container = ProviderContainer();
        addTearDown(container.dispose);

        final RecordingPracticeController controller =
            container.read(recordingPracticeControllerProvider.notifier);
        controller.startRecording();
        controller.tickForTesting();
        controller.stopRecording();

        // Rate the previous take + add a note.
        controller.setSelfRating(SelfRating.good);
        controller.setNote('first take was solid');

        controller.play();
        expect(
          container.read(recordingPracticeControllerProvider).isPlaying,
          isTrue,
        );

        // Now start a new recording. Playback must end and the new
        // take must be the active one.
        controller.startRecording();
        final RecordingPracticeState state =
            container.read(recordingPracticeControllerProvider);
        expect(state.isRecording, isTrue);
        expect(state.isPlaying, isFalse);
        expect(state.hasRecording, isFalse);
        expect(state.elapsedSeconds, 0);
        // selfRating and note are intentionally preserved by the
        // controller — only the new take replaces the old one when
        // it is stopped.

        controller.stopRecording();
      },
    );

    test('reset clears state, self-rating, and note', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final RecordingPracticeController controller =
          container.read(recordingPracticeControllerProvider.notifier);
      controller.startRecording();
      controller.tickForTesting();
      controller.tickForTesting();
      controller.stopRecording();
      controller.setSelfRating(SelfRating.okay);
      controller.setNote('forgot the Am fingering');

      controller.reset();
      final RecordingPracticeState state =
          container.read(recordingPracticeControllerProvider);
      expect(state, RecordingPracticeState.initial);
    });

    test('setSelfRating is a no-op while recording', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final RecordingPracticeController controller =
          container.read(recordingPracticeControllerProvider.notifier);
      controller.startRecording();
      controller.setSelfRating(SelfRating.good);
      expect(
        container.read(recordingPracticeControllerProvider).selfRating,
        isNull,
      );

      controller.stopRecording();
    });

    test('setSelfRating stores the choice after recording', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final RecordingPracticeController controller =
          container.read(recordingPracticeControllerProvider.notifier);
      controller.startRecording();
      controller.stopRecording();
      controller.setSelfRating(SelfRating.retry);
      expect(
        container.read(recordingPracticeControllerProvider).selfRating,
        SelfRating.retry,
      );

      // Passing null clears it.
      controller.setSelfRating(null);
      expect(
        container.read(recordingPracticeControllerProvider).selfRating,
        isNull,
      );
    });

    test('setNote is a no-op while recording', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final RecordingPracticeController controller =
          container.read(recordingPracticeControllerProvider.notifier);
      controller.startRecording();
      controller.setNote('should be ignored');
      expect(
        container.read(recordingPracticeControllerProvider).note,
        '',
      );

      controller.stopRecording();
    });

    test('setNote stores the value after recording', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final RecordingPracticeController controller =
          container.read(recordingPracticeControllerProvider.notifier);
      controller.startRecording();
      controller.stopRecording();
      controller.setNote('C -> Am 切换太慢');
      expect(
        container.read(recordingPracticeControllerProvider).note,
        'C -> Am 切换太慢',
      );
    });

    test('tickForTesting advances elapsedSeconds by one', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final RecordingPracticeController controller =
          container.read(recordingPracticeControllerProvider.notifier);
      expect(
        container.read(recordingPracticeControllerProvider).elapsedSeconds,
        0,
      );

      controller.tickForTesting();
      controller.tickForTesting();
      controller.tickForTesting();

      expect(
        container.read(recordingPracticeControllerProvider).elapsedSeconds,
        3,
      );
    });

    test('dispose while a recording is active does not throw', () {
      final ProviderContainer container = ProviderContainer();
      final RecordingPracticeController controller =
          container.read(recordingPracticeControllerProvider.notifier);
      controller.startRecording();
      // Disposing must cancel the in-flight periodic timer; this
      // must not throw.
      container.dispose();
    });

    test('dispose while playback is active does not throw', () {
      final ProviderContainer container = ProviderContainer();
      final RecordingPracticeController controller =
          container.read(recordingPracticeControllerProvider.notifier);
      controller.startRecording();
      controller.stopRecording();
      controller.play();
      container.dispose();
    });

    test('full happy path: record -> stop -> play -> rate -> note', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final RecordingPracticeController controller =
          container.read(recordingPracticeControllerProvider.notifier);

      controller.startRecording();
      controller.tickForTesting();
      controller.tickForTesting();
      controller.tickForTesting();
      controller.stopRecording();
      // elapsedSeconds at this point: 3.

      controller.play();
      controller.tickForTesting();
      controller.stopPlayback();
      // elapsedSeconds continues from 3, so it becomes 4. The
      // controller does NOT reset the clock on play — the same
      // elapsed counter is reused for symmetry with the recording
      // phase.

      controller.setSelfRating(SelfRating.good);
      controller.setNote('节奏稳定');

      final RecordingPracticeState state =
          container.read(recordingPracticeControllerProvider);
      expect(state.isRecording, isFalse);
      expect(state.hasRecording, isTrue);
      expect(state.isPlaying, isFalse);
      expect(state.elapsedSeconds, 4);
      expect(state.selfRating, SelfRating.good);
      expect(state.note, '节奏稳定');
    });
  });
}