// Tests for [RecordingPracticeController] (T012 + T013.4A).
//
// T012 scope (preserved):
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
// T013.4A scope:
// - Take identity: `takeId` is null initially, mints a fresh UUID
//   v4 on the first `startRecording`, is stable across a re-tap
//   while recording, gets a new id for a new take, and is cleared
//   by `reset`.
// - Recorded duration: `recordedDurationSeconds` is 0 initially,
//   freezes to `elapsedSeconds` on `stopRecording`, and is NOT
//   touched by subsequent playback ticks.
// - Save state machine: `isSaving` / `savedRecordId` / `isSaved` /
//   `canSave` follow the documented rules; while `isSaving == true`
//   every other mutator is a no-op; after a successful save the
//   user can still replay and start a new take but cannot mutate
//   the saved rating / note.
// - `saveCurrentTake` returns `success` / `ignored` / `failure`
//   per the brief and never generates a second id; a retry reuses
//   the same `takeId`.
// - All persisted fields (id, practiceDate, dayIndex,
//   primaryPracticeType, practiceTags, practiceContent,
//   durationSeconds, isCompleted, selfAssessment, audioFilePath,
//   createdAt, updatedAt) are exactly what the brief specifies.
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
// - For the save flow we substitute fake implementations of
//   [PracticeRecordRepository] / [PracticeDayResolver] /
//   [PracticeRecordIdGenerator] / [appClockProvider] so the test
//   never touches the real DB or `DateTime.now`.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ukulele_app/features/practice_records/application/practice_record_id_generator.dart';
import 'package:ukulele_app/features/practice_records/data/practice_record_repository.dart';
import 'package:ukulele_app/features/practice_records/data/practice_record_repository_provider.dart';
import 'package:ukulele_app/features/practice_records/domain/practice_record.dart';
import 'package:ukulele_app/features/practice_records/domain/practice_tag.dart';
import 'package:ukulele_app/features/practice_records/domain/practice_type.dart';
import 'package:ukulele_app/features/practice_records/domain/self_assessment.dart';
import 'package:ukulele_app/features/recording/application/recording_practice_controller.dart';
import 'package:ukulele_app/features/recording/domain/self_rating.dart';
import 'package:ukulele_app/shared/providers/app_clock_provider.dart';
import 'package:ukulele_app/shared/services/install_date_service.dart';
import 'package:ukulele_app/shared/services/install_date_service_provider.dart';
import 'package:ukulele_app/shared/services/practice_day_context.dart';

void main() {
  group('RecordingPracticeState', () {
    test('initial baseline is documented', () {
      const RecordingPracticeState s = RecordingPracticeState.initial;
      expect(s.isRecording, isFalse);
      expect(s.hasRecording, isFalse);
      expect(s.isPlaying, isFalse);
      expect(s.elapsedSeconds, 0);
      expect(s.recordedDurationSeconds, 0);
      expect(s.takeId, isNull);
      expect(s.selfRating, isNull);
      expect(s.note, '');
      expect(s.isSaving, isFalse);
      expect(s.savedRecordId, isNull);
      expect(s.isSaved, isFalse);
      expect(s.canSave, isFalse);
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
        recordedDurationSeconds: 0,
        takeId: 'take-1',
        selfRating: null,
        note: '',
        isSaving: false,
        savedRecordId: null,
      );
      expect(recording.statusLabel, '模拟录音中');

      const RecordingPracticeState playback = RecordingPracticeState(
        isRecording: false,
        hasRecording: true,
        isPlaying: true,
        elapsedSeconds: 5,
        recordedDurationSeconds: 5,
        takeId: 'take-1',
        selfRating: null,
        note: '',
        isSaving: false,
        savedRecordId: null,
      );
      expect(playback.statusLabel, '模拟回放中');

      const RecordingPracticeState done = RecordingPracticeState(
        isRecording: false,
        hasRecording: true,
        isPlaying: false,
        elapsedSeconds: 12,
        recordedDurationSeconds: 12,
        takeId: 'take-1',
        selfRating: SelfRating.good,
        note: 'ok',
        isSaving: false,
        savedRecordId: null,
      );
      expect(done.statusLabel, '已录音（可回放 / 自评）');
    });

    test('formattedElapsed pads minutes and seconds to two digits', () {
      const RecordingPracticeState s = RecordingPracticeState(
        isRecording: false,
        hasRecording: false,
        isPlaying: false,
        elapsedSeconds: 0,
        recordedDurationSeconds: 0,
        takeId: null,
        selfRating: null,
        note: '',
        isSaving: false,
        savedRecordId: null,
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
        recordedDurationSeconds: 10,
        takeId: 'take-1',
        selfRating: SelfRating.good,
        note: 'x',
        isSaving: false,
        savedRecordId: null,
      );
      expect(s.copyWith(clearSelfRating: true).selfRating, isNull);
      // Passing selfRating via copyWith still works.
      expect(s.copyWith(selfRating: SelfRating.retry).selfRating,
          SelfRating.retry);
    });

    test('copyWith with clearTakeId drops the takeId', () {
      const RecordingPracticeState s = RecordingPracticeState(
        isRecording: false,
        hasRecording: true,
        isPlaying: false,
        elapsedSeconds: 10,
        recordedDurationSeconds: 10,
        takeId: 'take-1',
        selfRating: null,
        note: '',
        isSaving: false,
        savedRecordId: null,
      );
      expect(s.copyWith(clearTakeId: true).takeId, isNull);
    });

    test('canSave requires all of the documented preconditions', () {
      // Build a "minimally valid" take and then flip exactly one
      // condition off at a time.
      RecordingPracticeState valid() => RecordingPracticeState(
            isRecording: false,
            hasRecording: true,
            isPlaying: false,
            elapsedSeconds: 3,
            recordedDurationSeconds: 3,
            takeId: 'take-1',
            selfRating: null,
            note: '',
            isSaving: false,
            savedRecordId: null,
          );

      expect(valid().canSave, isTrue);
      expect(valid().copyWith(hasRecording: false).canSave, isFalse);
      expect(valid().copyWith(recordedDurationSeconds: 0).canSave, isFalse);
      expect(valid().copyWith(isRecording: true).canSave, isFalse);
      expect(valid().copyWith(isPlaying: true).canSave, isFalse);
      expect(valid().copyWith(isSaving: true).canSave, isFalse);
      expect(
        valid().copyWith(savedRecordId: 'take-1').canSave,
        isFalse,
        reason: 'isSaved must block canSave so a re-save is impossible',
      );
      expect(valid().copyWith(clearTakeId: true).canSave, isFalse);
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
      final ProviderContainer container = _buildDefaultContainer();
      addTearDown(container.dispose);

      final RecordingPracticeState state =
          container.read(recordingPracticeControllerProvider);

      expect(state.isRecording, isFalse);
      expect(state.hasRecording, isFalse);
      expect(state.isPlaying, isFalse);
      expect(state.elapsedSeconds, 0);
      expect(state.recordedDurationSeconds, 0);
      expect(state.takeId, isNull);
      expect(state.selfRating, isNull);
      expect(state.note, '');
      expect(state.isSaving, isFalse);
      expect(state.savedRecordId, isNull);
      expect(state.canSave, isFalse);
      expect(state.isSaved, isFalse);
    });

    test(
      'startRecording flips isRecording and clears the previous take',
      () {
        final ProviderContainer container = _buildDefaultContainer();
        addTearDown(container.dispose);

        final RecordingPracticeController controller =
            container.read(recordingPracticeControllerProvider.notifier);

        // Walk through a full previous take so isRecording /
        // hasRecording / selfRating / note are all populated.
        controller.startRecording();
        controller.tickForTesting();
        controller.tickForTesting();
        controller.stopRecording();
        controller.setSelfRating(SelfRating.good);
        controller.setNote('forgot the Am fingering');
        // Sanity check: the previous take is on file with metadata.
        RecordingPracticeState poisoned =
            container.read(recordingPracticeControllerProvider);
        expect(poisoned.isRecording, isFalse);
        expect(poisoned.hasRecording, isTrue);
        expect(poisoned.selfRating, SelfRating.good);
        expect(poisoned.note, 'forgot the Am fingering');
        final String previousTakeId = poisoned.takeId!;

        // Start a new take. The previous take is dropped: clock
        // resets to 0, hasRecording flips to false, and the
        // self-rating + note are CLEARED so the user does not see
        // "no recording but a rating is still selected".
        // A FRESH takeId is minted — different from the previous
        // one.
        controller.startRecording();
        RecordingPracticeState state =
            container.read(recordingPracticeControllerProvider);
        expect(state.isRecording, isTrue);
        expect(state.hasRecording, isFalse);
        expect(state.isPlaying, isFalse);
        expect(state.elapsedSeconds, 0);
        expect(state.recordedDurationSeconds, 0);
        expect(state.selfRating, isNull);
        expect(state.note, '');
        expect(state.takeId, isNotNull);
        expect(state.takeId, isNot(equals(previousTakeId)),
            reason: 'a new take must mint a new id');

        // Cleanup the timer.
        controller.stopRecording();
      },
    );

    test('startRecording while already recording is a no-op', () {
      final ProviderContainer container = _buildDefaultContainer();
      addTearDown(container.dispose);

      final RecordingPracticeController controller =
          container.read(recordingPracticeControllerProvider.notifier);
      controller.startRecording();
      final String firstTakeId =
          container.read(recordingPracticeControllerProvider).takeId!;
      final int firstElapsed =
          container.read(recordingPracticeControllerProvider).elapsedSeconds;

      controller.startRecording();
      final RecordingPracticeState state =
          container.read(recordingPracticeControllerProvider);
      expect(state.isRecording, isTrue);
      expect(state.elapsedSeconds, firstElapsed);
      expect(state.takeId, firstTakeId,
          reason: 're-tapping start while recording must not mint a new id');

      controller.stopRecording();
    });

    test('stopRecording sets hasRecording = true', () {
      final ProviderContainer container = _buildDefaultContainer();
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
      expect(state.recordedDurationSeconds, 2,
          reason: 'recordedDurationSeconds freezes to elapsedSeconds');
    });

    test(
        'stopRecording freezes recordedDurationSeconds at the stop '
        'instant and playback does NOT change it', () {
      final ProviderContainer container = _buildDefaultContainer();
      addTearDown(container.dispose);

      final RecordingPracticeController controller =
          container.read(recordingPracticeControllerProvider.notifier);
      controller.startRecording();
      // 3-second take.
      controller.tickForTesting();
      controller.tickForTesting();
      controller.tickForTesting();
      controller.stopRecording();
      final int frozen = container
          .read(recordingPracticeControllerProvider)
          .recordedDurationSeconds;
      expect(frozen, 3);

      // Now play the take back. The simulated clock continues to
      // advance (T012 behaviour, preserved) but the FROZEN
      // recordedDurationSeconds value MUST stay at 3.
      controller.play();
      controller.tickForTesting();
      controller.tickForTesting();
      controller.tickForTesting();
      controller.tickForTesting();
      controller.stopPlayback();

      final RecordingPracticeState state =
          container.read(recordingPracticeControllerProvider);
      expect(state.elapsedSeconds, 7,
          reason: 'elapsedSeconds keeps advancing during playback');
      expect(state.recordedDurationSeconds, frozen,
          reason: 'recordedDurationSeconds is the canonical duration and '
              'is frozen at stopRecording');
    });

    test('stopRecording without an active recording is a no-op', () {
      final ProviderContainer container = _buildDefaultContainer();
      addTearDown(container.dispose);

      final RecordingPracticeController controller =
          container.read(recordingPracticeControllerProvider.notifier);
      controller.stopRecording();
      final RecordingPracticeState state =
          container.read(recordingPracticeControllerProvider);
      expect(state.isRecording, isFalse);
      expect(state.hasRecording, isFalse);
      expect(state.recordedDurationSeconds, 0);
    });

    test('play is a no-op when there is no recording', () {
      final ProviderContainer container = _buildDefaultContainer();
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
      final ProviderContainer container = _buildDefaultContainer();
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
      final ProviderContainer container = _buildDefaultContainer();
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
      final ProviderContainer container = _buildDefaultContainer();
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
      final ProviderContainer container = _buildDefaultContainer();
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
        final ProviderContainer container = _buildDefaultContainer();
        addTearDown(container.dispose);

        final RecordingPracticeController controller =
            container.read(recordingPracticeControllerProvider.notifier);
        controller.startRecording();
        controller.tickForTesting();
        controller.stopRecording();
        final String firstTakeId =
            container.read(recordingPracticeControllerProvider).takeId!;

        // Rate the previous take + add a note.
        controller.setSelfRating(SelfRating.good);
        controller.setNote('first take was solid');

        controller.play();
        expect(
          container.read(recordingPracticeControllerProvider).isPlaying,
          isTrue,
        );

        // Now start a new recording. Playback must end and the new
        // take must be the active one. The old take's self-rating
        // and note must be CLEARED (T012_FIX) so the UI does not
        // show "no recording but a rating is still selected".
        // A FRESH takeId is minted.
        controller.startRecording();
        final RecordingPracticeState state =
            container.read(recordingPracticeControllerProvider);
        expect(state.isRecording, isTrue);
        expect(state.isPlaying, isFalse);
        expect(state.hasRecording, isFalse);
        expect(state.elapsedSeconds, 0);
        expect(state.recordedDurationSeconds, 0);
        expect(state.selfRating, isNull);
        expect(state.note, '');
        expect(state.takeId, isNotNull);
        expect(state.takeId, isNot(equals(firstTakeId)),
            reason: 'a new take mints a new id, even when started '
                'from playback');

        controller.stopRecording();
      },
    );

    test('reset clears state, self-rating, note, and takeId', () {
      final ProviderContainer container = _buildDefaultContainer();
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
      expect(state.takeId, isNull);
      expect(state.savedRecordId, isNull);
    });

    test('setSelfRating is a no-op while recording', () {
      final ProviderContainer container = _buildDefaultContainer();
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
      final ProviderContainer container = _buildDefaultContainer();
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
      final ProviderContainer container = _buildDefaultContainer();
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
      final ProviderContainer container = _buildDefaultContainer();
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
      final ProviderContainer container = _buildDefaultContainer();
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
      final ProviderContainer container = _buildDefaultContainer();
      final RecordingPracticeController controller =
          container.read(recordingPracticeControllerProvider.notifier);
      controller.startRecording();
      // Disposing must cancel the in-flight periodic timer; this
      // must not throw.
      container.dispose();
    });

    test('dispose while playback is active does not throw', () {
      final ProviderContainer container = _buildDefaultContainer();
      final RecordingPracticeController controller =
          container.read(recordingPracticeControllerProvider.notifier);
      controller.startRecording();
      controller.stopRecording();
      controller.play();
      container.dispose();
    });

    test('full happy path: record -> stop -> play -> rate -> note', () {
      final ProviderContainer container = _buildDefaultContainer();
      addTearDown(container.dispose);

      final RecordingPracticeController controller =
          container.read(recordingPracticeControllerProvider.notifier);

      controller.startRecording();
      controller.tickForTesting();
      controller.tickForTesting();
      controller.tickForTesting();
      controller.stopRecording();
      // elapsedSeconds at this point: 3.
      // recordedDurationSeconds is FROZEN at 3.

      controller.play();
      controller.tickForTesting();
      controller.stopPlayback();
      // elapsedSeconds continues from 3, so it becomes 4. The
      // controller does NOT reset the clock on play — the same
      // elapsed counter is reused for symmetry with the recording
      // phase. recordedDurationSeconds stays at 3.

      controller.setSelfRating(SelfRating.good);
      controller.setNote('节奏稳定');

      final RecordingPracticeState state =
          container.read(recordingPracticeControllerProvider);
      expect(state.isRecording, isFalse);
      expect(state.hasRecording, isTrue);
      expect(state.isPlaying, isFalse);
      expect(state.elapsedSeconds, 4);
      expect(state.recordedDurationSeconds, 3);
      expect(state.selfRating, SelfRating.good);
      expect(state.note, '节奏稳定');
    });
  });

  group('RecordingPracticeController save (T013.4A)', () {
    setUp(() {
      // Each test gets a fresh id generator (and therefore a
      // fresh callCount). The sequential generator shares static
      // state across tests, so this reset is necessary to keep
      // assertions deterministic.
      _SequentialPracticeRecordIdGenerator.callCount = 0;
      // The gated repository has a single static gate. Reset
      // it between tests so a previous test's completion
      // doesn't leak into the next one. Each gated-repo test
      // is responsible for calling `gate.complete()` before
      // the test ends (or letting the ProviderScope dispose
      // drop the in-flight save).
      _GatedPracticeRecordRepository.resetGate();
    });

    test('saveCurrentTake returns success and writes savedRecordId', () async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository();
      final ProviderContainer container = _buildSaveContainer(
        repository: repo,
      );
      addTearDown(container.dispose);

      final RecordingPracticeController controller =
          container.read(recordingPracticeControllerProvider.notifier);
      controller.startRecording();
      controller.tickForTesting();
      controller.tickForTesting();
      controller.tickForTesting();
      controller.stopRecording();
      controller.setSelfRating(SelfRating.good);
      controller.setNote('  C -> Am 切换太慢  ');
      final String expectedTakeId =
          container.read(recordingPracticeControllerProvider).takeId!;

      final SaveRecordingResult result = await controller.saveCurrentTake();
      expect(result, SaveRecordingResult.success);

      final RecordingPracticeState after =
          container.read(recordingPracticeControllerProvider);
      expect(after.isSaved, isTrue);
      expect(after.savedRecordId, expectedTakeId);
      expect(after.isSaving, isFalse);
      expect(after.takeId, expectedTakeId,
          reason: 'a successful save must not mint a new id');
      expect(after.hasRecording, isTrue);
      expect(after.selfRating, SelfRating.good);
      expect(after.note, '  C -> Am 切换太慢  ',
          reason: 'a successful save preserves the take + rating + note');

      expect(repo.inserted.length, 1);
      final PracticeRecord saved = repo.inserted.single;
      expect(saved.id, expectedTakeId);
      expect(saved.practiceDate, _kTestToday);
      expect(saved.dayIndex, _kTestDayIndex);
      expect(saved.primaryPracticeType, PracticeType.recording);
      expect(saved.practiceTags, contains(PracticeTag.recording));
      expect(saved.practiceTags, contains(PracticeTag.selfAssessment));
      expect(saved.practiceContent, 'C -> Am 切换太慢',
          reason: 'note is trimmed on save');
      expect(saved.durationSeconds, 3,
          reason: 'duration is the FROZEN recordedDurationSeconds');
      expect(saved.isCompleted, isTrue);
      expect(saved.selfAssessment, SelfAssessment.good);
      expect(saved.audioFilePath, isNull);
      expect(saved.createdAt, _kTestNowUtc);
      expect(saved.updatedAt, _kTestNowUtc);
    });

    test('save without a rating persists the recording tag only', () async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository();
      final ProviderContainer container = _buildSaveContainer(
        repository: repo,
      );
      addTearDown(container.dispose);

      final RecordingPracticeController controller =
          container.read(recordingPracticeControllerProvider.notifier);
      controller.startRecording();
      controller.tickForTesting();
      controller.stopRecording();
      // No selfRating set; note is empty.

      final SaveRecordingResult result = await controller.saveCurrentTake();
      expect(result, SaveRecordingResult.success);

      final PracticeRecord saved = repo.inserted.single;
      expect(saved.practiceTags, <PracticeTag>[PracticeTag.recording],
          reason: 'no self-rating => no selfAssessment tag');
      expect(saved.selfAssessment, isNull,
          reason: 'no self-rating => null assessment, not a default');
      expect(saved.practiceContent, 'Day $_kTestDayIndex 模拟录音练习',
          reason: 'empty note uses the default Day-N 模拟录音练习 copy');
    });

    test(
        'empty / whitespace-only note is trimmed and falls back to default '
        'practice content', () async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository();
      final ProviderContainer container = _buildSaveContainer(
        repository: repo,
      );
      addTearDown(container.dispose);

      final RecordingPracticeController controller =
          container.read(recordingPracticeControllerProvider.notifier);
      controller.startRecording();
      controller.tickForTesting();
      controller.stopRecording();
      controller.setNote('   ');

      final SaveRecordingResult result = await controller.saveCurrentTake();
      expect(result, SaveRecordingResult.success);

      expect(
          repo.inserted.single.practiceContent, 'Day $_kTestDayIndex 模拟录音练习');
    });

    test('note with surrounding whitespace is trimmed on save', () async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository();
      final ProviderContainer container = _buildSaveContainer(
        repository: repo,
      );
      addTearDown(container.dispose);

      final RecordingPracticeController controller =
          container.read(recordingPracticeControllerProvider.notifier);
      controller.startRecording();
      controller.tickForTesting();
      controller.stopRecording();
      controller.setNote('   备注两侧有空格   ');

      final SaveRecordingResult result = await controller.saveCurrentTake();
      expect(result, SaveRecordingResult.success);

      expect(repo.inserted.single.practiceContent, '备注两侧有空格');
    });

    test(
        'SelfRating maps to the correct SelfAssessment for all three '
        'values', () async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository();
      final ProviderContainer container = _buildSaveContainer(
        repository: repo,
      );
      addTearDown(container.dispose);

      for (final SelfRating rating in SelfRating.values) {
        final RecordingPracticeController controller =
            container.read(recordingPracticeControllerProvider.notifier);
        controller.startRecording();
        controller.tickForTesting();
        controller.stopRecording();
        controller.setSelfRating(rating);
        final SaveRecordingResult result = await controller.saveCurrentTake();
        expect(result, SaveRecordingResult.success,
            reason: 'rating=$rating should save successfully');
        final PracticeRecord saved = repo.inserted.last;
        final SelfAssessment? expected = _mapExpectedAssessment(rating);
        expect(saved.selfAssessment, expected,
            reason: 'rating=$rating must map to $expected');
      }
    });

    test('saveCurrentTake is ignored before the user has a valid take',
        () async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository();
      final ProviderContainer container = _buildSaveContainer(
        repository: repo,
      );
      addTearDown(container.dispose);

      final RecordingPracticeController controller =
          container.read(recordingPracticeControllerProvider.notifier);
      // Never call startRecording — state.hasRecording == false
      // and recordedDurationSeconds == 0.
      final SaveRecordingResult result = await controller.saveCurrentTake();
      expect(result, SaveRecordingResult.ignored);
      expect(repo.inserted, isEmpty);
    });

    test(
        'saveCurrentTake is ignored if recordedDurationSeconds is 0 '
        '(0-second recording)', () async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository();
      final ProviderContainer container = _buildSaveContainer(
        repository: repo,
      );
      addTearDown(container.dispose);

      final RecordingPracticeController controller =
          container.read(recordingPracticeControllerProvider.notifier);
      controller.startRecording();
      // Do NOT tick — 0-second recording.
      controller.stopRecording();

      final SaveRecordingResult result = await controller.saveCurrentTake();
      expect(result, SaveRecordingResult.ignored);
      expect(repo.inserted, isEmpty);
    });

    test('saveCurrentTake returns ignored on a second concurrent call',
        () async {
      final _GatedPracticeRecordRepository repo =
          _GatedPracticeRecordRepository();
      final ProviderContainer container = _buildSaveContainer(
        repository: repo,
      );
      addTearDown(container.dispose);

      final RecordingPracticeController controller =
          container.read(recordingPracticeControllerProvider.notifier);
      controller.startRecording();
      controller.tickForTesting();
      controller.stopRecording();

      // First call: blocks on the gate.
      final Future<SaveRecordingResult> first = controller.saveCurrentTake();
      // Second call: state.isSaving == true => ignored.
      final SaveRecordingResult secondResult =
          await controller.saveCurrentTake();
      expect(secondResult, SaveRecordingResult.ignored);

      // Release the gate so the first call can complete.
      _GatedPracticeRecordRepository.gate.complete();
      final SaveRecordingResult firstResult = await first;
      expect(firstResult, SaveRecordingResult.success);
    });

    test('saveCurrentTake returns failure when the Repository throws',
        () async {
      final _FakePracticeRecordRepository repo = _FakePracticeRecordRepository()
        ..throwOnInsert = StateError('synthetic insert failure');
      final ProviderContainer container = _buildSaveContainer(
        repository: repo,
      );
      addTearDown(container.dispose);

      final RecordingPracticeController controller =
          container.read(recordingPracticeControllerProvider.notifier);
      controller.startRecording();
      controller.tickForTesting();
      controller.stopRecording();
      final String takeId =
          container.read(recordingPracticeControllerProvider).takeId!;
      final int recorded = container
          .read(recordingPracticeControllerProvider)
          .recordedDurationSeconds;

      final SaveRecordingResult result = await controller.saveCurrentTake();
      expect(result, SaveRecordingResult.failure);

      final RecordingPracticeState after =
          container.read(recordingPracticeControllerProvider);
      expect(after.isSaved, isFalse);
      expect(after.savedRecordId, isNull);
      expect(after.isSaving, isFalse);
      expect(after.takeId, takeId,
          reason: 'a failed save must preserve the takeId for retry');
      expect(after.hasRecording, isTrue);
      expect(after.recordedDurationSeconds, recorded,
          reason: 'a failed save must preserve recordedDurationSeconds');
    });

    test('saveCurrentTake can be retried with the same takeId after failure',
        () async {
      final _FakePracticeRecordRepository repo = _FakePracticeRecordRepository()
        ..throwOnInsert = StateError('synthetic insert failure');
      final ProviderContainer container = _buildSaveContainer(
        repository: repo,
      );
      addTearDown(container.dispose);

      final RecordingPracticeController controller =
          container.read(recordingPracticeControllerProvider.notifier);
      controller.startRecording();
      controller.tickForTesting();
      controller.stopRecording();
      final String takeId =
          container.read(recordingPracticeControllerProvider).takeId!;

      final SaveRecordingResult first = await controller.saveCurrentTake();
      expect(first, SaveRecordingResult.failure);

      // The generator was called exactly once — the failed save
      // did not mint a second id.
      expect(_SequentialPracticeRecordIdGenerator.callCount, 1);

      // Make the second attempt succeed.
      repo.throwOnInsert = null;
      final SaveRecordingResult second = await controller.saveCurrentTake();
      expect(second, SaveRecordingResult.success);
      expect(repo.inserted.single.id, takeId,
          reason: 'the retry must reuse the same takeId');
      expect(_SequentialPracticeRecordIdGenerator.callCount, 1,
          reason: 'the retry must not call the generator again');
    });

    test('saveCurrentTake returns failure when PracticeDayResolver throws',
        () async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository();
      final ProviderContainer container = _buildSaveContainer(
        repository: repo,
        resolver: _ThrowingPracticeDayResolver(),
      );
      addTearDown(container.dispose);

      final RecordingPracticeController controller =
          container.read(recordingPracticeControllerProvider.notifier);
      controller.startRecording();
      controller.tickForTesting();
      controller.stopRecording();

      final SaveRecordingResult result = await controller.saveCurrentTake();
      expect(result, SaveRecordingResult.failure);
      expect(repo.inserted, isEmpty);

      final RecordingPracticeState after =
          container.read(recordingPracticeControllerProvider);
      expect(after.isSaving, isFalse,
          reason: 'isSaving must be cleared on failure');
      expect(after.isSaved, isFalse);
    });

    test('saveCurrentTake returns ignored when Provider is disposed mid-await',
        () async {
      final _GatedPracticeRecordRepository repo =
          _GatedPracticeRecordRepository();
      final ProviderContainer container = _buildSaveContainer(
        repository: repo,
      );
      // We deliberately do NOT addTearDown — we dispose manually
      // after kicking off the save.

      final RecordingPracticeController controller =
          container.read(recordingPracticeControllerProvider.notifier);
      controller.startRecording();
      controller.tickForTesting();
      controller.stopRecording();

      final Future<SaveRecordingResult> pending = controller.saveCurrentTake();
      // The save is blocked on the gate. Dispose the container now;
      // the post-await check should see `ref.mounted == false` and
      // return ignored. We do NOT expect the gate to be released
      // (it has no further effect either way), so the in-flight
      // Future is dropped silently.
      container.dispose();
      _GatedPracticeRecordRepository.gate.complete();
      final SaveRecordingResult result = await pending;
      expect(result, SaveRecordingResult.ignored);
    });

    test(
        'saveCurrentTake is drop-safe: isSaving guards the takeId, '
        'so an in-flight save stays consistent', () async {
      // This test pins the cross-await contract for take-id
      // consistency. The controller takes a snapshot of the
      // takeId before awaiting the resolver; after the await it
      // re-checks that the snapshot still matches the live
      // `state.takeId`. The "no-op while isSaving" guard on
      // every mutator is what makes this re-check trivially
      // pass — the takeId cannot change while the save is in
      // flight, so the snapshot is never stale.
      final _GatedPracticeRecordRepository repo =
          _GatedPracticeRecordRepository();
      final ProviderContainer container = _buildSaveContainer(
        repository: repo,
      );
      addTearDown(container.dispose);

      final RecordingPracticeController controller =
          container.read(recordingPracticeControllerProvider.notifier);
      controller.startRecording();
      controller.tickForTesting();
      controller.stopRecording();
      final String firstTakeId =
          container.read(recordingPracticeControllerProvider).takeId!;

      // Kick off a save that will block on the gate.
      final Future<SaveRecordingResult> first = controller.saveCurrentTake();

      // Verify isSaving flipped and the gate is blocking.
      expect(
        container.read(recordingPracticeControllerProvider).isSaving,
        isTrue,
      );

      // The contract is: while isSaving == true, every mutator
      // is a no-op. So `startRecording()` is ignored and the
      // takeId is preserved — the in-flight save's snapshot is
      // therefore NOT stale and the post-await check passes.
      controller.startRecording();
      // Take a snapshot of the takeId mid-await to confirm the
      // isSaving guard did its job.
      expect(
        container.read(recordingPracticeControllerProvider).takeId,
        firstTakeId,
        reason: 'startRecording while isSaving must NOT mint a new id',
      );

      // Release the gate so the save can complete.
      _GatedPracticeRecordRepository.gate.complete();
      final SaveRecordingResult firstResult = await first;
      expect(firstResult, SaveRecordingResult.success,
          reason: 'isSaving must protect the takeId from concurrent '
              'mutation, so the post-await takeId check sees the same '
              'snapshot and the save commits');
      expect(repo.inserted.length, 1);
      expect(repo.inserted.single.id, firstTakeId);
    });

    test(
        'startRecording, stopRecording, play, stopPlayback, reset, '
        'setSelfRating, setNote are all no-ops while isSaving == true',
        () async {
      final _GatedPracticeRecordRepository repo =
          _GatedPracticeRecordRepository();
      final ProviderContainer container = _buildSaveContainer(
        repository: repo,
      );
      addTearDown(container.dispose);

      final RecordingPracticeController controller =
          container.read(recordingPracticeControllerProvider.notifier);
      controller.startRecording();
      controller.tickForTesting();
      controller.tickForTesting();
      controller.stopRecording();
      controller.setSelfRating(SelfRating.good);
      controller.setNote('a note');
      final RecordingPracticeState pre = container.read(
        recordingPracticeControllerProvider,
      );

      // Kick off a save that blocks on the gate.
      final Future<SaveRecordingResult> pending = controller.saveCurrentTake();
      // Read state mid-await: isSaving is true.
      final RecordingPracticeState mid = container.read(
        recordingPracticeControllerProvider,
      );
      expect(mid.isSaving, isTrue);

      // Every mutator must be a no-op. Re-tap them and check
      // state is byte-equal to `pre` on the take-related fields.
      controller.startRecording();
      controller.stopRecording();
      controller.play();
      controller.stopPlayback();
      controller.reset();
      controller.setSelfRating(SelfRating.retry);
      controller.setNote('different note');

      final RecordingPracticeState after = container.read(
        recordingPracticeControllerProvider,
      );
      expect(after.takeId, pre.takeId);
      expect(after.hasRecording, pre.hasRecording);
      expect(after.elapsedSeconds, pre.elapsedSeconds);
      expect(after.recordedDurationSeconds, pre.recordedDurationSeconds);
      expect(after.selfRating, pre.selfRating);
      expect(after.note, pre.note);
      expect(after.isSaving, isTrue,
          reason: 'isSaving must NOT be cleared by these no-op calls');
      expect(after.savedRecordId, isNull);

      // Release the gate so the original save can complete.
      _GatedPracticeRecordRepository.gate.complete();
      final SaveRecordingResult result = await pending;
      expect(result, SaveRecordingResult.success);
    });

    test('setSelfRating and setNote are no-ops after a successful save',
        () async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository();
      final ProviderContainer container = _buildSaveContainer(
        repository: repo,
      );
      addTearDown(container.dispose);

      final RecordingPracticeController controller =
          container.read(recordingPracticeControllerProvider.notifier);
      controller.startRecording();
      controller.tickForTesting();
      controller.stopRecording();
      controller.setSelfRating(SelfRating.good);
      controller.setNote('good take');
      final SaveRecordingResult save = await controller.saveCurrentTake();
      expect(save, SaveRecordingResult.success);

      // The saved record is the source of truth. The user must
      // not be able to silently mutate it by tapping the rating
      // selector or the note field.
      controller.setSelfRating(SelfRating.retry);
      controller.setNote('completely different note');

      final RecordingPracticeState after =
          container.read(recordingPracticeControllerProvider);
      expect(after.selfRating, SelfRating.good);
      expect(after.note, 'good take');
      expect(after.isSaved, isTrue);
      expect(after.savedRecordId, isNotNull);
    });

    test('playback still works after a successful save', () async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository();
      final ProviderContainer container = _buildSaveContainer(
        repository: repo,
      );
      addTearDown(container.dispose);

      final RecordingPracticeController controller =
          container.read(recordingPracticeControllerProvider.notifier);
      controller.startRecording();
      controller.tickForTesting();
      controller.stopRecording();
      await controller.saveCurrentTake();
      expect(
        container.read(recordingPracticeControllerProvider).isSaved,
        isTrue,
      );

      // Playback is explicitly allowed after a save (the saved
      // record's metadata must not be touched, but the user can
      // still re-listen to the in-memory take).
      controller.play();
      final RecordingPracticeState playing = container.read(
        recordingPracticeControllerProvider,
      );
      expect(playing.isPlaying, isTrue);
      expect(playing.isSaved, isTrue,
          reason: 'isSaved stays true during playback after save');
      controller.stopPlayback();
    });

    test('startRecording after a successful save mints a fresh takeId',
        () async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository();
      final ProviderContainer container = _buildSaveContainer(
        repository: repo,
      );
      addTearDown(container.dispose);

      final RecordingPracticeController controller =
          container.read(recordingPracticeControllerProvider.notifier);
      controller.startRecording();
      controller.tickForTesting();
      controller.stopRecording();
      await controller.saveCurrentTake();
      final String savedTakeId =
          container.read(recordingPracticeControllerProvider).savedRecordId!;

      controller.startRecording();
      final RecordingPracticeState after =
          container.read(recordingPracticeControllerProvider);
      expect(after.isSaved, isFalse,
          reason: 'starting a new take clears the saved state');
      expect(after.savedRecordId, isNull);
      expect(after.takeId, isNotNull);
      expect(after.takeId, isNot(equals(savedTakeId)),
          reason: 'a new take mints a new id');
      controller.stopRecording();
    });

    test('createdAt and updatedAt are sourced from appClockProvider', () async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository();
      final DateTime pinnedNow = DateTime.utc(2026, 6, 20, 9, 30, 0);
      final ProviderContainer container = _buildSaveContainer(
        repository: repo,
        clock: () => pinnedNow,
      );
      addTearDown(container.dispose);

      final RecordingPracticeController controller =
          container.read(recordingPracticeControllerProvider.notifier);
      controller.startRecording();
      controller.tickForTesting();
      controller.stopRecording();
      final SaveRecordingResult result = await controller.saveCurrentTake();
      expect(result, SaveRecordingResult.success);

      final PracticeRecord saved = repo.inserted.single;
      expect(saved.createdAt, pinnedNow);
      expect(saved.updatedAt, pinnedNow);
    });
  });
}

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------

/// Pinned clock instant for the save-flow tests.
final DateTime _kTestNowUtc = DateTime.utc(2026, 6, 20, 9, 0, 0);

/// Pinned local-midnight "today" for the resolver.
final DateTime _kTestToday = DateTime(2026, 6, 20);

/// Pinned dayIndex returned by the fake resolver.
const int _kTestDayIndex = 2;

/// Helper that maps a [SelfRating] to the expected [SelfAssessment]
/// (mirrors [mapSelfRatingToSelfAssessment] but is hand-rolled to
/// pin the test against the mapper contract).
SelfAssessment? _mapExpectedAssessment(SelfRating rating) {
  switch (rating) {
    case SelfRating.good:
      return SelfAssessment.good;
    case SelfRating.okay:
      return SelfAssessment.neutral;
    case SelfRating.retry:
      return SelfAssessment.needsImprovement;
  }
}

/// Builds a `ProviderContainer` with the default
/// `practiceRecordIdGeneratorProvider` override (a sequential
/// generator) and a fake `installDateServiceProvider` so the
/// non-save tests never hit the real clock.
ProviderContainer _buildDefaultContainer() {
  final _SequentialPracticeRecordIdGenerator idGen =
      _SequentialPracticeRecordIdGenerator();
  return ProviderContainer(
    overrides: <Override>[
      practiceRecordIdGeneratorProvider.overrideWithValue(idGen),
      installDateServiceProvider.overrideWithValue(
        _FakeInstallDateService(
          DateTime.utc(2026, 6, 19, 0, 0, 0),
        ),
      ),
    ],
  );
}

/// Builds a `ProviderContainer` for the save-flow tests. The
/// caller MUST pass at least a [repository] override (so the
/// real Drift DB is never touched). The [resolver] and [clock]
/// overrides are optional — when omitted, a pinned
/// [_FakePracticeDayResolver] and a pinned clock
/// (`_kTestNowUtc`) are used so every saved record is
/// deterministic.
ProviderContainer _buildSaveContainer({
  required PracticeRecordRepository repository,
  PracticeDayResolver? resolver,
  DateTime Function()? clock,
}) {
  final _SequentialPracticeRecordIdGenerator idGen =
      _SequentialPracticeRecordIdGenerator();
  return ProviderContainer(
    overrides: <Override>[
      practiceRecordIdGeneratorProvider.overrideWithValue(idGen),
      practiceRecordRepositoryProvider.overrideWithValue(repository),
      practiceDayResolverProvider
          .overrideWithValue(resolver ?? _FakePracticeDayResolver()),
      appClockProvider.overrideWithValue(clock ?? (() => _kTestNowUtc)),
    ],
  );
}

/// In-memory [PracticeRecordRepository] used by the save-flow
/// tests. Records every inserted row so assertions can inspect
/// them. Can be flipped to throw on insert to exercise the
/// failure path.
class _FakePracticeRecordRepository implements PracticeRecordRepository {
  Object? throwOnInsert;
  final List<PracticeRecord> inserted = <PracticeRecord>[];

  @override
  Future<PracticeRecord> insert(PracticeRecord record) async {
    if (throwOnInsert != null) {
      throw throwOnInsert!;
    }
    inserted.add(record);
    return record;
  }

  @override
  Future<PracticeRecord?> getById(String id) async {
    for (final PracticeRecord r in inserted) {
      if (r.id == id) return r;
    }
    return null;
  }

  @override
  Future<List<PracticeRecord>> listRecent({int limit = 50}) async {
    return List<PracticeRecord>.unmodifiable(inserted);
  }

  @override
  Stream<List<PracticeRecord>> watchAll() async* {
    yield List<PracticeRecord>.unmodifiable(inserted);
  }

  @override
  Future<bool> delete(String id) async => false;
}

/// Repository whose `insert` blocks on a static `gate` future
/// (initialised lazily). Used to hold the controller inside
/// `saveCurrentTake` so the test can observe the in-flight state.
class _GatedPracticeRecordRepository implements PracticeRecordRepository {
  static Completer<void> gate = Completer<void>();
  final List<PracticeRecord> inserted = <PracticeRecord>[];

  /// Resets the shared gate. Called from the test `setUp` so
  /// each test gets a fresh gate.
  static void resetGate() {
    if (!gate.isCompleted) {
      gate = Completer<void>();
    } else {
      gate = Completer<void>();
    }
  }

  @override
  Future<PracticeRecord> insert(PracticeRecord record) async {
    await gate.future;
    inserted.add(record);
    return record;
  }

  @override
  Future<PracticeRecord?> getById(String id) async => null;

  @override
  Future<List<PracticeRecord>> listRecent({int limit = 50}) async =>
      const <PracticeRecord>[];

  @override
  Stream<List<PracticeRecord>> watchAll() async* {
    yield const <PracticeRecord>[];
  }

  @override
  Future<bool> delete(String id) async => false;
}

/// Practice-day resolver whose `resolve()` always throws — used
/// to exercise the failure path of `saveCurrentTake`.
class _ThrowingPracticeDayResolver implements PracticeDayResolver {
  @override
  Future<PracticeDayContext> resolve() async {
    throw StateError('synthetic resolver failure');
  }
}

/// Practice-day resolver that returns the pinned test context —
/// used to make every test's saved record deterministic.
class _FakePracticeDayResolver implements PracticeDayResolver {
  @override
  Future<PracticeDayContext> resolve() async {
    return PracticeDayContext(
      today: _kTestToday,
      installDate: _kTestToday.subtract(const Duration(days: 1)),
      dayIndex: _kTestDayIndex,
    );
  }
}

/// ID generator that returns a sequence of stable test ids:
/// `take-1`, `take-2`, ... Tracking the call count lets the
/// tests verify the controller did not mint a second id on
/// failure or retry.
class _SequentialPracticeRecordIdGenerator
    implements PracticeRecordIdGenerator {
  static int callCount = 0;

  @override
  String generate() {
    callCount += 1;
    return 'take-$callCount';
  }
}

/// Install-date stub that returns a fixed UTC instant. Used to
/// keep the day-index calculation deterministic for the
/// non-save tests.
class _FakeInstallDateService implements InstallDateService {
  _FakeInstallDateService(this._fixed);

  final DateTime _fixed;

  @override
  Future<DateTime> getInstallDate() async => _fixed;
}
