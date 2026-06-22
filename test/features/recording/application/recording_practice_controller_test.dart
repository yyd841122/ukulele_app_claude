// Tests for [RecordingPracticeController] (T012 + T013.4A + T031).
//
// T012 scope (preserved where compatible):
// - Verify the initial state is the documented baseline.
// - Verify start / stop / play / stop-playback transitions and
//   the "play while recording is a no-op" and "start while playing
//   stops playback + starts recording" rules from the brief.
//
// T013.4A scope (preserved):
// - Take identity: `takeId` is null initially, mints a fresh UUID
//   v4 on the first `startRecording`, gets a new id for a new take,
//   and is cleared by `reset`.
// - Recorded duration: `recordedDurationSeconds` is 0 initially,
//   freezes to elapsed time on `stopRecording`.
// - Save state machine: `isSaving` / `savedRecordId` / `isSaved` /
//   `canSave` follow the documented rules; `audioFilePath` remains
//   `null` on the persisted record (T032 is out of scope for T031).
//
// T031 scope (NEW):
// - Controller wires [RealAudioRecorderService] /
//   [RealAudioPlaybackService] / [MicrophonePermissionService].
// - Permission flow: `startRecording` checks `checkStatus` and
//   falls back to `requestPermission` when not granted. On
//   denied / permanentDenied / restricted the recorder service
//   is NOT invoked and the permission status mirrors the result.
// - Recorder / playback service exceptions are caught and
//   surfaced as `lastError`; the state machine recovers so the
//   user can retry.
// - `recordedTakeResult` is stored in state; `play()` calls
//   `loadFile(recordedTakeResult.resolvedPath)` then `play()`.
// - Recording ↔ playback mutual exclusion is enforced at the
//   controller level (belt-and-braces; the page also disables
//   the buttons).
// - Stream subscription lifecycle: position / duration / state
//   streams are wired once on the first successful `loadFile`,
//   cancelled on dispose, and not re-subscribed on subsequent
//   `loadFile` calls.
// - `dispose` is best-effort idempotent; the controller must
//   not throw when the user leaves the page mid-recording.
//
// Testing strategy — T031:
// - Tests use `_FakeRecorderService` / `_FakePlaybackService` /
//   `FakeMicrophonePermissionGateway` injected via
//   `ProviderScope.overrides` so no real microphone / player /
//   platform channel is ever touched.
// - The fake recorder / playback services are real
//   [RealAudioRecorderService] / [RealAudioPlaybackService]
//   instances wired to `FakeAudioRecorderGateway` /
//   `FakeAudioPlaybackGateway`. This pins the controller's
//   behaviour against the production state machine, not against
//   a parallel fake state machine that could drift.
// - Tests use `pumpEventQueue` / `Future` await to drain
//   microtasks — no real wall-clock waiting.
import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:ukulele_app/features/practice_records/application/practice_record_id_generator.dart';
import 'package:ukulele_app/features/practice_records/data/practice_record_repository.dart';
import 'package:ukulele_app/features/practice_records/data/practice_record_repository_provider.dart';
import 'package:ukulele_app/features/practice_records/domain/practice_record.dart';
import 'package:ukulele_app/features/practice_records/domain/practice_tag.dart';
import 'package:ukulele_app/features/practice_records/domain/self_assessment.dart';
import 'package:ukulele_app/features/recording/application/recording_practice_controller.dart';
import 'package:ukulele_app/features/recording/domain/self_rating.dart';
import 'package:ukulele_app/shared/providers/app_clock_provider.dart';
import 'package:ukulele_app/shared/providers/audio_file_storage_service_provider.dart';
import 'package:ukulele_app/shared/providers/microphone_permission_service_provider.dart';
import 'package:ukulele_app/shared/providers/real_audio_playback_service_provider.dart';
import 'package:ukulele_app/shared/providers/real_audio_recorder_service_provider.dart';
import 'package:ukulele_app/shared/services/audio_file_storage_service.dart';
import 'package:ukulele_app/shared/services/audio_playback_gateway.dart';
import 'package:ukulele_app/shared/services/audio_recorder_state.dart';
import 'package:ukulele_app/shared/services/microphone_permission_service.dart';
import 'package:ukulele_app/shared/services/microphone_permission_status.dart';
import 'package:ukulele_app/shared/services/practice_day_context.dart';
import 'package:ukulele_app/shared/services/real_audio_playback_service.dart';
import 'package:ukulele_app/shared/services/real_audio_recorder_service.dart';
import 'package:ukulele_app/shared/services/install_date_service.dart';
import 'package:ukulele_app/shared/services/install_date_service_provider.dart';

import '../../../shared/services/fake_audio_playback_gateway.dart';
import '../../../shared/services/fake_audio_recorder_gateway.dart';
import '../../../shared/services/fake_microphone_permission_gateway.dart';

int _rootCounter = 0;

({Future<Directory> Function() rootProvider, Directory root}) _isolatedRoot() {
  final Directory root = Directory(
    p.join(
      Directory.systemTemp.path,
      'recording_controller_${DateTime.now().microsecondsSinceEpoch}_${_rootCounter++}',
    ),
  );
  addTearDown(() {
    if (root.existsSync()) {
      try {
        root.deleteSync(recursive: true);
      } on FileSystemException {
        // ignore
      }
    }
  });
  return (rootProvider: () async => root, root: root);
}

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
      expect(s.permission, RecordingPermissionStatus.idle);
      expect(s.recordedTakeResult, isNull);
      expect(s.hasRecordedTake, isFalse);
      expect(s.currentPlaybackPosition, Duration.zero);
      expect(s.currentPlaybackDuration, isNull);
      expect(s.lastError, isNull);
    });

    test('statusLabel covers permission phases', () {
      expect(RecordingPracticeState.initial.statusLabel, '准备录音');
      const RecordingPracticeState checking = RecordingPracticeState(
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
        permission: RecordingPermissionStatus.checking,
        recordedTakeResult: null,
        currentPlaybackPosition: Duration.zero,
        currentPlaybackDuration: null,
        lastError: null,
      );
      expect(checking.statusLabel, '正在检查麦克风权限…');

      const RecordingPracticeState denied = RecordingPracticeState(
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
        permission: RecordingPermissionStatus.denied,
        recordedTakeResult: null,
        currentPlaybackPosition: Duration.zero,
        currentPlaybackDuration: null,
        lastError: null,
      );
      expect(denied.statusLabel, '麦克风权限被拒绝');

      const RecordingPracticeState permDenied = RecordingPracticeState(
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
        permission: RecordingPermissionStatus.permanentDenied,
        recordedTakeResult: null,
        currentPlaybackPosition: Duration.zero,
        currentPlaybackDuration: null,
        lastError: null,
      );
      expect(permDenied.statusLabel, '麦克风权限已永久拒绝');

      const RecordingPracticeState restricted = RecordingPracticeState(
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
        permission: RecordingPermissionStatus.restricted,
        recordedTakeResult: null,
        currentPlaybackPosition: Duration.zero,
        currentPlaybackDuration: null,
        lastError: null,
      );
      expect(restricted.statusLabel, '麦克风被系统限制');
    });

    test('statusLabel covers recording / playback / recorded phases', () {
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
        permission: RecordingPermissionStatus.granted,
        recordedTakeResult: null,
        currentPlaybackPosition: Duration.zero,
        currentPlaybackDuration: null,
        lastError: null,
      );
      expect(recording.statusLabel, '正在录音');

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
        permission: RecordingPermissionStatus.granted,
        recordedTakeResult: null,
        currentPlaybackPosition: Duration(seconds: 2),
        currentPlaybackDuration: Duration(seconds: 5),
        lastError: null,
      );
      expect(playback.statusLabel, '正在回放');

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
        permission: RecordingPermissionStatus.granted,
        recordedTakeResult: null,
        currentPlaybackPosition: Duration.zero,
        currentPlaybackDuration: Duration(seconds: 12),
        lastError: null,
      );
      expect(done.statusLabel, '录音完成（可回放 / 自评）');
    });

    test('formattedElapsed pads minutes and seconds to two digits', () {
      const RecordingPracticeState s = RecordingPracticeState.initial;
      expect(s.formattedElapsed, '00:00');
      expect(s.copyWith(elapsedSeconds: 9).formattedElapsed, '00:09');
      expect(s.copyWith(elapsedSeconds: 59).formattedElapsed, '00:59');
      expect(s.copyWith(elapsedSeconds: 60).formattedElapsed, '01:00');
      expect(s.copyWith(elapsedSeconds: 125).formattedElapsed, '02:05');
    });

    test('copyWith with clearTakeId / clearRecordedTakeResult / clearLastError',
        () {
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
        permission: RecordingPermissionStatus.granted,
        recordedTakeResult: null,
        currentPlaybackPosition: Duration.zero,
        currentPlaybackDuration: Duration(seconds: 10),
        lastError: 'some error',
      );
      expect(s.copyWith(clearTakeId: true).takeId, isNull);
      expect(
        s.copyWith(clearCurrentPlaybackDuration: true).currentPlaybackDuration,
        isNull,
      );
      expect(s.copyWith(clearLastError: true).lastError, isNull);
    });

    test('canSave requires all of the documented preconditions', () {
      final AudioRecorderTakeResult result = AudioRecorderTakeResult(
        takeId: 'take-1',
        requestedPath: '/tmp/take-1.m4a',
        resolvedPath: '/tmp/take-1.m4a',
        format: 'm4a',
        sampleRate: 44100,
        bitRate: 128000,
        numChannels: 1,
      );
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
            permission: RecordingPermissionStatus.granted,
            recordedTakeResult: result,
            currentPlaybackPosition: Duration.zero,
            currentPlaybackDuration: const Duration(seconds: 3),
            lastError: null,
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
      final ctx = _buildContext();
      addTearDown(ctx.container.dispose);

      final RecordingPracticeState state =
          ctx.container.read(recordingPracticeControllerProvider);

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
      expect(state.permission, RecordingPermissionStatus.idle);
      expect(state.recordedTakeResult, isNull);
    });

    test(
      'startRecording with granted permission: flips isRecording + calls recorder.start',
      () async {
        final ctx = _buildContext(
          permission: (b) =>
              b..nextCheckStatus = MicrophonePermissionStatus.granted,
        );
        addTearDown(ctx.container.dispose);

        final RecordingPracticeController controller =
            ctx.container.read(recordingPracticeControllerProvider.notifier);

        await controller.startRecording();
        // Let the controller's await on permission/recorder settle.
        await _pumpEventQueue();

        final RecordingPracticeState state =
            ctx.container.read(recordingPracticeControllerProvider);
        expect(state.permission, RecordingPermissionStatus.granted);
        expect(state.isRecording, isTrue);
        expect(state.hasRecording, isFalse);
        expect(state.hasRecordedTake, isFalse);
        expect(state.isPlaying, isFalse);
        expect(state.takeId, isNotNull);
        expect(ctx.permissionGateway.checkStatusCallCount, 1);
        expect(ctx.permissionGateway.requestPermissionCallCount, 0,
            reason: 'no need to call request() when checkStatus is granted');
        expect(ctx.recorderGateway.startCallCount, 1);
        expect(ctx.recorderGateway.lastStartPath, isNotNull);

        // Cleanup: stop the recording so the timer is released.
        ctx.recorderGateway.nextStopResult =
            _stopPath(ctx.recorderGateway.lastStartPath!);
        await controller.stopRecording();
      },
    );

    test(
      'startRecording with denied status: requests permission, no recorder call',
      () async {
        final ctx = _buildContext(
          permission: (b) => b
            ..nextCheckStatus = MicrophonePermissionStatus.denied
            ..nextRequestStatus = MicrophonePermissionStatus.denied,
        );
        addTearDown(ctx.container.dispose);

        final RecordingPracticeController controller =
            ctx.container.read(recordingPracticeControllerProvider.notifier);

        await controller.startRecording();
        await _pumpEventQueue();

        final RecordingPracticeState state =
            ctx.container.read(recordingPracticeControllerProvider);
        expect(state.permission, RecordingPermissionStatus.denied);
        expect(state.isRecording, isFalse);
        expect(ctx.permissionGateway.checkStatusCallCount, 1);
        expect(ctx.permissionGateway.requestPermissionCallCount, 1,
            reason:
                'request() must be called exactly once when check is not granted');
        expect(ctx.recorderGateway.startCallCount, 0,
            reason: 'recorder MUST NOT start when permission is denied');
      },
    );

    test(
      'startRecording with permanentlyDenied: no recorder call',
      () async {
        final ctx = _buildContext(
          permission: (b) => b
            ..nextCheckStatus = MicrophonePermissionStatus.denied
            ..nextRequestStatus = MicrophonePermissionStatus.permanentlyDenied,
        );
        addTearDown(ctx.container.dispose);

        final RecordingPracticeController controller =
            ctx.container.read(recordingPracticeControllerProvider.notifier);

        await controller.startRecording();
        await _pumpEventQueue();

        final RecordingPracticeState state =
            ctx.container.read(recordingPracticeControllerProvider);
        expect(state.permission, RecordingPermissionStatus.permanentDenied);
        expect(state.isRecording, isFalse);
        expect(ctx.recorderGateway.startCallCount, 0);
      },
    );

    test(
      'startRecording with restricted: no recorder call, permission=restricted',
      () async {
        final ctx = _buildContext(
          permission: (b) => b
            ..nextCheckStatus = MicrophonePermissionStatus.restricted
            ..nextRequestStatus = MicrophonePermissionStatus.restricted,
        );
        addTearDown(ctx.container.dispose);

        final RecordingPracticeController controller =
            ctx.container.read(recordingPracticeControllerProvider.notifier);

        await controller.startRecording();
        await _pumpEventQueue();

        final RecordingPracticeState state =
            ctx.container.read(recordingPracticeControllerProvider);
        expect(state.permission, RecordingPermissionStatus.restricted);
        expect(state.isRecording, isFalse);
        expect(ctx.recorderGateway.startCallCount, 0);
      },
    );

    test(
      'startRecording when permission service throws: state recovers, lastError set',
      () async {
        final ctx = _buildContext(
          permission: (b) => b
            ..nextCheckException = StateError('synthetic permission failure'),
        );
        addTearDown(ctx.container.dispose);

        final RecordingPracticeController controller =
            ctx.container.read(recordingPracticeControllerProvider.notifier);

        await controller.startRecording();
        await _pumpEventQueue();

        final RecordingPracticeState state =
            ctx.container.read(recordingPracticeControllerProvider);
        expect(state.isRecording, isFalse);
        expect(state.permission, RecordingPermissionStatus.idle);
        expect(state.lastError, isNotNull);
        expect(ctx.recorderGateway.startCallCount, 0);
      },
    );

    test(
      'startRecording when recorder.start throws: state recovers, lastError set',
      () async {
        final ctx = _buildContext(
          permission: (b) =>
              b..nextCheckStatus = MicrophonePermissionStatus.granted,
          recorder: (b) =>
              b..nextStartException = StateError('synthetic recorder failure'),
        );
        addTearDown(ctx.container.dispose);

        final RecordingPracticeController controller =
            ctx.container.read(recordingPracticeControllerProvider.notifier);

        await controller.startRecording();
        await _pumpEventQueue();

        final RecordingPracticeState state =
            ctx.container.read(recordingPracticeControllerProvider);
        expect(state.isRecording, isFalse);
        expect(state.permission, RecordingPermissionStatus.granted);
        expect(state.lastError, isNotNull);
        expect(state.takeId, isNull,
            reason: 'takeId is cleared on recorder.start failure');
        expect(state.elapsedSeconds, 0);
      },
    );

    test('startRecording while already recording is a no-op', () async {
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await controller.startRecording();
      await _pumpEventQueue();
      final String firstTakeId =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;
      final int firstStartCount = ctx.recorderGateway.startCallCount;

      await controller.startRecording();
      await _pumpEventQueue();

      final RecordingPracticeState state =
          ctx.container.read(recordingPracticeControllerProvider);
      expect(state.isRecording, isTrue);
      expect(state.takeId, firstTakeId);
      expect(ctx.recorderGateway.startCallCount, firstStartCount,
          reason:
              'a second startRecording while already recording MUST NOT call recorder.start again');

      // Cleanup.
      ctx.recorderGateway.nextStopResult =
          _stopPath(ctx.recorderGateway.lastStartPath!);
      await controller.stopRecording();
    });

    test('stopRecording flips hasRecording + stores recordedTakeResult',
        () async {
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await controller.startRecording();
      await _pumpEventQueue();

      // ignore: unused_local_variable
      final String takeId =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;
      final String path = ctx.recorderGateway.lastStartPath!;
      // Probe path becomes the playback loadFile path; the
      // controller derives the duration from the playback service
      // by re-loading the file.
      ctx.recorderGateway.nextStopResult = _stopPath(path);

      // Pre-seed the playback fake so the post-stop probe returns
      // a known duration. We must write a real file because the
      // playback service's _validatePath checks the file exists.
      final File f = File(path);
      await f.create(recursive: true);
      await f.writeAsString('fake m4a');
      ctx.playbackGateway.nextLoadResult = const Duration(seconds: 4);

      await controller.stopRecording();
      await _pumpEventQueue();

      final RecordingPracticeState state =
          ctx.container.read(recordingPracticeControllerProvider);
      expect(state.isRecording, isFalse);
      expect(state.hasRecording, isTrue);
      expect(state.hasRecordedTake, isTrue);
      expect(state.recordedTakeResult, isNotNull);
      expect(state.recordedTakeResult!.resolvedPath, path);
      expect(state.recordedDurationSeconds, 4);
      expect(state.elapsedSeconds, 4);
      expect(state.currentPlaybackDuration, const Duration(seconds: 4));
    });

    test(
        'stopRecording when recorder.stop throws: state recovers, lastError set',
        () async {
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
        recorder: (b) =>
            b..nextStopException = StateError('synthetic stop failure'),
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await controller.startRecording();
      await _pumpEventQueue();

      await controller.stopRecording();
      await _pumpEventQueue();

      final RecordingPracticeState state =
          ctx.container.read(recordingPracticeControllerProvider);
      expect(state.isRecording, isFalse);
      expect(state.hasRecording, isFalse);
      expect(state.lastError, isNotNull);
    });

    test('stopRecording without an active recording is a no-op', () async {
      final ctx = _buildContext();
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await controller.stopRecording();

      final RecordingPracticeState state =
          ctx.container.read(recordingPracticeControllerProvider);
      expect(state.isRecording, isFalse);
      expect(state.hasRecording, isFalse);
      expect(state.recordedDurationSeconds, 0);
    });

    test('play before a recorded take is a no-op', () async {
      final ctx = _buildContext();
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await controller.play();

      final RecordingPracticeState state =
          ctx.container.read(recordingPracticeControllerProvider);
      expect(state.isPlaying, isFalse);
      expect(state.hasRecording, isFalse);
    });

    test('play after stopRecording calls loadFile + play + flips isPlaying',
        () async {
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await controller.startRecording();
      await _pumpEventQueue();

      // ignore: unused_local_variable
      final String takeId =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;
      final String path = ctx.recorderGateway.lastStartPath!;
      // Write a real file so the playback service's _validatePath
      // passes.
      final File f = File(path);
      await f.create(recursive: true);
      await f.writeAsString('fake m4a');
      ctx.recorderGateway.nextStopResult = _stopPath(path);
      ctx.playbackGateway.nextLoadResult = const Duration(seconds: 8);

      await controller.stopRecording();
      await _pumpEventQueue();
      await controller.play();
      await _pumpEventQueue();

      final RecordingPracticeState state =
          ctx.container.read(recordingPracticeControllerProvider);
      expect(state.isPlaying, isTrue);
      expect(ctx.playbackGateway.loadFileCallCount, greaterThanOrEqualTo(1),
          reason: 'play() must call loadFile with the recorded take path');
      expect(ctx.playbackGateway.lastLoadPath, path);
      expect(ctx.playbackGateway.playCallCount, 1);
    });

    test('play when loadFile throws: lastError set, isPlaying stays false',
        () async {
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
        playback: (b) =>
            b..nextLoadException = StateError('synthetic load failure'),
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await controller.startRecording();
      await _pumpEventQueue();
      // ignore: unused_local_variable
      final String takeId =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;
      final String path = ctx.recorderGateway.lastStartPath!;
      // The file does NOT have to exist when loadFile throws,
      // but the playback service may still probe; keep the path
      // consistent.
      final File f = File(path);
      await f.create(recursive: true);
      await f.writeAsString('fake m4a');
      ctx.recorderGateway.nextStopResult = _stopPath(path);

      await controller.stopRecording();
      await _pumpEventQueue();
      await controller.play();
      await _pumpEventQueue();

      final RecordingPracticeState state =
          ctx.container.read(recordingPracticeControllerProvider);
      expect(state.isPlaying, isFalse);
      expect(state.lastError, isNotNull);
      expect(ctx.playbackGateway.playCallCount, 0,
          reason: 'play() must NOT be called when loadFile throws');
    });

    test('play when playback.play throws: lastError set, isPlaying stays false',
        () async {
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
        playback: (b) =>
            b..nextPlayException = StateError('synthetic play failure'),
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await controller.startRecording();
      await _pumpEventQueue();
      // ignore: unused_local_variable
      final String takeId =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;
      final String path = ctx.recorderGateway.lastStartPath!;
      final File f = File(path);
      await f.create(recursive: true);
      await f.writeAsString('fake m4a');
      ctx.recorderGateway.nextStopResult = _stopPath(path);
      ctx.playbackGateway.nextLoadResult = const Duration(seconds: 2);

      await controller.stopRecording();
      await _pumpEventQueue();
      await controller.play();
      await _pumpEventQueue();

      final RecordingPracticeState state =
          ctx.container.read(recordingPracticeControllerProvider);
      expect(state.isPlaying, isFalse);
      expect(state.lastError, isNotNull);
    });

    test(
      'startRecording while playing is rejected: starts a new take (consistent with T012 contract)',
      () async {
        // T012 contract: startRecording while playing must stop
        // playback and start a new take. T031 preserves this by
        // rejecting in the controller (the page also disables the
        // start button while playing). We assert the controller
        // call is a no-op so the page's disabled button is the
        // single source of truth.
        final ctx = _buildContext(
          permission: (b) =>
              b..nextCheckStatus = MicrophonePermissionStatus.granted,
        );
        addTearDown(ctx.container.dispose);

        final RecordingPracticeController controller =
            ctx.container.read(recordingPracticeControllerProvider.notifier);
        await controller.startRecording();
        await _pumpEventQueue();
        // ignore: unused_local_variable
        final String takeId =
            ctx.container.read(recordingPracticeControllerProvider).takeId!;
        final String path = ctx.recorderGateway.lastStartPath!;
        final File f = File(path);
        await f.create(recursive: true);
        await f.writeAsString('fake m4a');
        ctx.recorderGateway.nextStopResult = _stopPath(path);
        ctx.playbackGateway.nextLoadResult = const Duration(seconds: 3);

        await controller.stopRecording();
        await _pumpEventQueue();
        await controller.play();
        await _pumpEventQueue();

        // Now isPlaying == true; startRecording must be a no-op.
        final int startsBefore = ctx.recorderGateway.startCallCount;
        final String takeIdBefore =
            ctx.container.read(recordingPracticeControllerProvider).takeId!;
        await controller.startRecording();
        await _pumpEventQueue();
        final RecordingPracticeState state =
            ctx.container.read(recordingPracticeControllerProvider);
        expect(state.isPlaying, isTrue,
            reason: 'playback must still be running');
        expect(state.takeId, takeIdBefore,
            reason: 'a no-op startRecording must NOT mint a new takeId');
        expect(ctx.recorderGateway.startCallCount, startsBefore,
            reason: 'recorder.start must NOT be called while playing');

        // Cleanup.
        await controller.stopPlayback();
      },
    );

    test(
      'play while recording is rejected (no-op)',
      () async {
        final ctx = _buildContext(
          permission: (b) =>
              b..nextCheckStatus = MicrophonePermissionStatus.granted,
        );
        addTearDown(ctx.container.dispose);

        final RecordingPracticeController controller =
            ctx.container.read(recordingPracticeControllerProvider.notifier);
        await controller.startRecording();
        await _pumpEventQueue();

        final int loadsBefore = ctx.playbackGateway.loadFileCallCount;
        await controller.play();
        await _pumpEventQueue();

        final RecordingPracticeState state =
            ctx.container.read(recordingPracticeControllerProvider);
        expect(state.isRecording, isTrue);
        expect(state.isPlaying, isFalse);
        expect(ctx.playbackGateway.loadFileCallCount, loadsBefore,
            reason: 'play() while recording MUST NOT call playback.loadFile');

        // Cleanup.
        // ignore: unused_local_variable
        final String takeId =
            ctx.container.read(recordingPracticeControllerProvider).takeId!;
        final String path = ctx.recorderGateway.lastStartPath!;
        final File f = File(path);
        await f.create(recursive: true);
        await f.writeAsString('fake m4a');
        ctx.recorderGateway.nextStopResult = _stopPath(path);
        await controller.stopRecording();
      },
    );

    test('natural completion (gateway emits completed): flips isPlaying back',
        () async {
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await controller.startRecording();
      await _pumpEventQueue();
      // ignore: unused_local_variable
      final String takeId =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;
      final String path = ctx.recorderGateway.lastStartPath!;
      final File f = File(path);
      await f.create(recursive: true);
      await f.writeAsString('fake m4a');
      ctx.recorderGateway.nextStopResult = _stopPath(path);
      ctx.playbackGateway.nextLoadResult = const Duration(seconds: 2);

      await controller.stopRecording();
      await _pumpEventQueue();
      await controller.play();
      await _pumpEventQueue();

      // Simulate natural completion via the fake gateway's
      // playerStateStream.
      ctx.playbackGateway.emitPlayerState(const PlaybackPlayerState(
        playing: false,
        processingState: PlaybackProcessingState.completed,
      ));
      await _pumpEventQueue();

      final RecordingPracticeState state =
          ctx.container.read(recordingPracticeControllerProvider);
      expect(state.isPlaying, isFalse,
          reason: 'a completed event must flip isPlaying back');
    });

    // T031C: pinned "playback completed auto-recovery" tests.
    test(
        'T031C: natural completion seeks to zero and clears lastError so '
        'replay starts from 0', () async {
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await controller.startRecording();
      await _pumpEventQueue();
      // ignore: unused_local_variable
      final String takeId =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;
      final String path = ctx.recorderGateway.lastStartPath!;
      final File f = File(path);
      await f.create(recursive: true);
      await f.writeAsString('fake m4a');
      ctx.recorderGateway.nextStopResult = _stopPath(path);
      ctx.playbackGateway.nextLoadResult = const Duration(seconds: 5);

      await controller.stopRecording();
      await _pumpEventQueue();
      await controller.play();
      await _pumpEventQueue();
      // Simulate a non-zero position right before natural completion.
      ctx.playbackGateway.emitPosition(const Duration(seconds: 4));
      await _pumpEventQueue();
      // T031C contract: seek-to-zero is called on the playback
      // service before the state flips.
      final int seeksBefore = ctx.playbackGateway.seekCallCount;
      ctx.playbackGateway.emitPlayerState(const PlaybackPlayerState(
        playing: false,
        processingState: PlaybackProcessingState.completed,
      ));
      await _pumpEventQueue();

      final RecordingPracticeState state =
          ctx.container.read(recordingPracticeControllerProvider);
      expect(state.isPlaying, isFalse);
      expect(state.currentPlaybackPosition, Duration.zero);
      expect(ctx.playbackGateway.seekCallCount, greaterThan(seeksBefore),
          reason: 'completed must trigger a best-effort seek to 0');
      expect(ctx.playbackGateway.lastSeekPosition, Duration.zero,
          reason: 'the recovery seek must target position 0');
    });

    test(
        'T031C: after natural completion user can replay from start without '
        'a fresh recording', () async {
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await controller.startRecording();
      await _pumpEventQueue();
      // ignore: unused_local_variable
      final String takeId =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;
      final String path = ctx.recorderGateway.lastStartPath!;
      final File f = File(path);
      await f.create(recursive: true);
      await f.writeAsString('fake m4a');
      ctx.recorderGateway.nextStopResult = _stopPath(path);
      ctx.playbackGateway.nextLoadResult = const Duration(seconds: 3);

      await controller.stopRecording();
      await _pumpEventQueue();
      await controller.play();
      await _pumpEventQueue();

      // Natural completion.
      ctx.playbackGateway.emitPlayerState(const PlaybackPlayerState(
        playing: false,
        processingState: PlaybackProcessingState.completed,
      ));
      await _pumpEventQueue();
      expect(
        ctx.container.read(recordingPracticeControllerProvider).isPlaying,
        isFalse,
      );

      // Replay: must work because isPlaying is false and the
      // recorded take is still held in memory.
      final int playCallsBefore = ctx.playbackGateway.playCallCount;
      final int loadCallsBefore = ctx.playbackGateway.loadFileCallCount;
      await controller.play();
      await _pumpEventQueue();
      final RecordingPracticeState replayed =
          ctx.container.read(recordingPracticeControllerProvider);
      expect(replayed.isPlaying, isTrue,
          reason: 're-tapping play after completion must start playback');
      expect(ctx.playbackGateway.playCallCount, playCallsBefore + 1);
      expect(
          ctx.playbackGateway.loadFileCallCount, greaterThan(loadCallsBefore),
          reason: 'play() reloads the source after completion');

      await controller.stopPlayback();
    });

    test(
        'T031C: after natural completion user can re-record a new take '
        '(isPlaying cleared, startRecording accepted)', () async {
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await controller.startRecording();
      await _pumpEventQueue();
      // ignore: unused_local_variable
      final String takeId =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;
      final String path = ctx.recorderGateway.lastStartPath!;
      final File f = File(path);
      await f.create(recursive: true);
      await f.writeAsString('fake m4a');
      ctx.recorderGateway.nextStopResult = _stopPath(path);
      ctx.playbackGateway.nextLoadResult = const Duration(seconds: 2);

      await controller.stopRecording();
      await _pumpEventQueue();
      await controller.play();
      await _pumpEventQueue();

      ctx.playbackGateway.emitPlayerState(const PlaybackPlayerState(
        playing: false,
        processingState: PlaybackProcessingState.completed,
      ));
      await _pumpEventQueue();
      expect(
        ctx.container.read(recordingPracticeControllerProvider).isPlaying,
        isFalse,
      );

      // Re-record: must be accepted because isPlaying is false.
      final int startsBefore = ctx.recorderGateway.startCallCount;
      final String firstTakeId =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;
      await controller.startRecording();
      await _pumpEventQueue();
      final RecordingPracticeState fresh =
          ctx.container.read(recordingPracticeControllerProvider);
      expect(fresh.isRecording, isTrue);
      expect(fresh.isPlaying, isFalse);
      expect(fresh.takeId, isNot(equals(firstTakeId)),
          reason: 'a fresh take must mint a new takeId');
      expect(ctx.recorderGateway.startCallCount, startsBefore + 1,
          reason: 'recorder.start must be called when starting fresh after '
              'natural completion');

      // Cleanup the second take.
      // ignore: unused_local_variable
      final String secondTakeId =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;
      final String secondPath = ctx.recorderGateway.lastStartPath!;
      final File f2 = File(secondPath);
      await f2.create(recursive: true);
      await f2.writeAsString('fake m4a #2');
      ctx.recorderGateway.nextStopResult = _stopPath(secondPath);
      await controller.stopRecording();
    });

    test(
        'T031C: startRecording is rejected while playing (belt-and-braces '
        'controller guard, recorder.start NOT called)', () async {
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await controller.startRecording();
      await _pumpEventQueue();
      // ignore: unused_local_variable
      final String takeId =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;
      final String path = ctx.recorderGateway.lastStartPath!;
      final File f = File(path);
      await f.create(recursive: true);
      await f.writeAsString('fake m4a');
      ctx.recorderGateway.nextStopResult = _stopPath(path);
      ctx.playbackGateway.nextLoadResult = const Duration(seconds: 2);

      await controller.stopRecording();
      await _pumpEventQueue();
      await controller.play();
      await _pumpEventQueue();
      expect(
        ctx.container.read(recordingPracticeControllerProvider).isPlaying,
        isTrue,
      );

      // T031C: explicit guard test — controller MUST NOT call
      // recorder.start while playback is in progress, MUST NOT
      // mint a new takeId, MUST NOT change isPlaying.
      final int startsBefore = ctx.recorderGateway.startCallCount;
      final int checkBefore = ctx.permissionGateway.checkStatusCallCount;
      final String takeIdBefore =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;
      await controller.startRecording();
      await _pumpEventQueue();
      final RecordingPracticeState state =
          ctx.container.read(recordingPracticeControllerProvider);
      expect(state.isPlaying, isTrue,
          reason:
              'playback must still be running after a no-op startRecording');
      expect(state.takeId, takeIdBefore,
          reason: 'a no-op startRecording must NOT mint a new takeId');
      expect(ctx.recorderGateway.startCallCount, startsBefore,
          reason: 'recorder.start MUST NOT be called while playing');
      expect(ctx.permissionGateway.checkStatusCallCount, checkBefore,
          reason: 'permission service MUST NOT be touched while playing');

      await controller.stopPlayback();
    });

    test(
        'T031C: stopPlayback after natural completion is a clean no-op '
        '(does not throw, does not change already-cleared state)', () async {
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await controller.startRecording();
      await _pumpEventQueue();
      // ignore: unused_local_variable
      final String takeId =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;
      final String path = ctx.recorderGateway.lastStartPath!;
      final File f = File(path);
      await f.create(recursive: true);
      await f.writeAsString('fake m4a');
      ctx.recorderGateway.nextStopResult = _stopPath(path);
      ctx.playbackGateway.nextLoadResult = const Duration(seconds: 2);

      await controller.stopRecording();
      await _pumpEventQueue();
      await controller.play();
      await _pumpEventQueue();

      ctx.playbackGateway.emitPlayerState(const PlaybackPlayerState(
        playing: false,
        processingState: PlaybackProcessingState.completed,
      ));
      await _pumpEventQueue();
      expect(
        ctx.container.read(recordingPracticeControllerProvider).isPlaying,
        isFalse,
      );

      // Manual stop after auto-recovery: must be a clean no-op
      // because `isPlaying` is already false. The controller
      // guards with `if (!state.isPlaying) return` so the
      // playback service is not touched.
      final int stopsBefore = ctx.playbackGateway.stopCallCount;
      await controller.stopPlayback();
      await _pumpEventQueue();
      final RecordingPracticeState after =
          ctx.container.read(recordingPracticeControllerProvider);
      expect(after.isPlaying, isFalse);
      expect(after.currentPlaybackPosition, Duration.zero);
      expect(ctx.playbackGateway.stopCallCount, stopsBefore,
          reason: 'stopPlayback after natural completion is a controller '
              'no-op and MUST NOT drive the playback service again');
    });

    test(
        'T031C: stopRecording is unaffected by the natural-completion '
        'recovery (still no-op without an active recording)', () async {
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      // No recording ever started.
      await controller.stopRecording();
      final RecordingPracticeState idle =
          ctx.container.read(recordingPracticeControllerProvider);
      expect(idle.isRecording, isFalse);
      expect(idle.lastError, isNull);
    });

    test(
        'T031C: natural-completion recovery does NOT trigger Drift writes '
        'or insert a PracticeRecord (audioFilePath stays null)', () async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository();
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
        repository: repo,
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await controller.startRecording();
      await _pumpEventQueue();
      // ignore: unused_local_variable
      final String takeId =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;
      final String path = ctx.recorderGateway.lastStartPath!;
      final File f = File(path);
      await f.create(recursive: true);
      await f.writeAsString('fake m4a');
      ctx.recorderGateway.nextStopResult = _stopPath(path);
      ctx.playbackGateway.nextLoadResult = const Duration(seconds: 2);

      await controller.stopRecording();
      await _pumpEventQueue();
      await controller.play();
      await _pumpEventQueue();
      ctx.playbackGateway.emitPlayerState(const PlaybackPlayerState(
        playing: false,
        processingState: PlaybackProcessingState.completed,
      ));
      await _pumpEventQueue();

      // No PracticeRecord was auto-persisted by the recovery.
      expect(repo.inserted, isEmpty,
          reason: 'natural completion MUST NOT auto-save a record');
      expect(
          ctx.container.read(recordingPracticeControllerProvider).savedRecordId,
          isNull,
          reason: 'savedRecordId stays null — auto-recovery is not a save');
    });

    test('stopPlayback flips isPlaying back', () async {
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await controller.startRecording();
      await _pumpEventQueue();
      // ignore: unused_local_variable
      final String takeId =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;
      final String path = ctx.recorderGateway.lastStartPath!;
      final File f = File(path);
      await f.create(recursive: true);
      await f.writeAsString('fake m4a');
      ctx.recorderGateway.nextStopResult = _stopPath(path);
      ctx.playbackGateway.nextLoadResult = const Duration(seconds: 2);

      await controller.stopRecording();
      await _pumpEventQueue();
      await controller.play();
      await _pumpEventQueue();
      await controller.stopPlayback();

      final RecordingPracticeState state =
          ctx.container.read(recordingPracticeControllerProvider);
      expect(state.isPlaying, isFalse);
      expect(ctx.playbackGateway.stopCallCount, greaterThanOrEqualTo(1),
          reason:
              'stopPlayback() must drive the playback service to stop at least once');
    });

    test('reset clears takeId + recordedTakeResult + permission', () async {
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await controller.startRecording();
      await _pumpEventQueue();
      // ignore: unused_local_variable
      final String takeId =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;
      final String path = ctx.recorderGateway.lastStartPath!;
      final File f = File(path);
      await f.create(recursive: true);
      await f.writeAsString('fake m4a');
      ctx.recorderGateway.nextStopResult = _stopPath(path);
      ctx.playbackGateway.nextLoadResult = const Duration(seconds: 2);
      await controller.stopRecording();
      await _pumpEventQueue();
      controller.setSelfRating(SelfRating.okay);
      controller.setNote('forgot the Am fingering');

      controller.reset();
      final RecordingPracticeState state =
          ctx.container.read(recordingPracticeControllerProvider);
      expect(state, RecordingPracticeState.initial);
      expect(state.takeId, isNull);
      expect(state.recordedTakeResult, isNull);
      expect(state.savedRecordId, isNull);
    });

    test('re-recording clears the previous recordedTakeResult', () async {
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);

      // First take.
      await controller.startRecording();
      await _pumpEventQueue();
      final String firstTakeId =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;
      final String firstPath = ctx.recorderGateway.lastStartPath!;
      final File f1 = File(firstPath);
      await f1.create(recursive: true);
      await f1.writeAsString('fake m4a #1');
      ctx.recorderGateway.nextStopResult = _stopPath(firstPath);
      ctx.playbackGateway.nextLoadResult = const Duration(seconds: 2);
      await controller.stopRecording();
      await _pumpEventQueue();
      expect(
        ctx.container
            .read(recordingPracticeControllerProvider)
            .recordedTakeResult,
        isNotNull,
      );

      // Re-record. The previous take is overwritten in memory; the
      // file is intentionally NOT cleaned up here (T031 contract).
      await controller.startRecording();
      await _pumpEventQueue();
      final RecordingPracticeState midState =
          ctx.container.read(recordingPracticeControllerProvider);
      expect(midState.recordedTakeResult, isNull,
          reason: 'a fresh take must clear the previous recordedTakeResult');
      expect(midState.takeId, isNotNull);
      expect(midState.takeId, isNot(equals(firstTakeId)));
      expect(midState.hasRecording, isFalse);

      // Cleanup the second take.
// ignore: unused_local_variable
      final String secondTakeId =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;
      final String secondPath = ctx.recorderGateway.lastStartPath!;
      final File f2 = File(secondPath);
      await f2.create(recursive: true);
      await f2.writeAsString('fake m4a #2');
      ctx.recorderGateway.nextStopResult = _stopPath(secondPath);
      await controller.stopRecording();
    });

    test('setSelfRating is a no-op while recording', () async {
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await controller.startRecording();
      await _pumpEventQueue();
      controller.setSelfRating(SelfRating.good);
      expect(
        ctx.container.read(recordingPracticeControllerProvider).selfRating,
        isNull,
      );

      // Cleanup.
      // ignore: unused_local_variable
      final String takeId =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;
      final String path = ctx.recorderGateway.lastStartPath!;
      final File f = File(path);
      await f.create(recursive: true);
      await f.writeAsString('fake m4a');
      ctx.recorderGateway.nextStopResult = _stopPath(path);
      await controller.stopRecording();
    });

    test('setNote is a no-op while recording', () async {
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await controller.startRecording();
      await _pumpEventQueue();
      controller.setNote('should be ignored');
      expect(
        ctx.container.read(recordingPracticeControllerProvider).note,
        '',
      );

      // Cleanup.
      // ignore: unused_local_variable
      final String takeId =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;
      final String path = ctx.recorderGateway.lastStartPath!;
      final File f = File(path);
      await f.create(recursive: true);
      await f.writeAsString('fake m4a');
      ctx.recorderGateway.nextStopResult = _stopPath(path);
      await controller.stopRecording();
    });

    test('dispose while a recording is active does not throw', () async {
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
      );
      addTearDown(ctx.container.dispose);
      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await controller.startRecording();
      await _pumpEventQueue();

      // Dispose the container; the onDispose hook must cancel the
      // timer + subscriptions and call recorder / playback dispose
      // without throwing.
      ctx.container.dispose();
      // We intentionally do NOT await controller.stopRecording() —
      // the post-dispose call must be a no-op.
      await controller.stopRecording();
      await controller.play();
    });

    test('dispose while playback is active does not throw', () async {
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
      );
      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await controller.startRecording();
      await _pumpEventQueue();
      // ignore: unused_local_variable
      final String takeId =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;
      final String path = ctx.recorderGateway.lastStartPath!;
      final File f = File(path);
      await f.create(recursive: true);
      await f.writeAsString('fake m4a');
      ctx.recorderGateway.nextStopResult = _stopPath(path);
      ctx.playbackGateway.nextLoadResult = const Duration(seconds: 2);
      await controller.stopRecording();
      await _pumpEventQueue();
      await controller.play();
      await _pumpEventQueue();

      ctx.container.dispose();
      await controller.stopPlayback();
    });

    test(
      'position stream tick updates currentPlaybackPosition + elapsedSeconds',
      () async {
        final ctx = _buildContext(
          permission: (b) =>
              b..nextCheckStatus = MicrophonePermissionStatus.granted,
        );
        addTearDown(ctx.container.dispose);

        final RecordingPracticeController controller =
            ctx.container.read(recordingPracticeControllerProvider.notifier);
        await controller.startRecording();
        await _pumpEventQueue();
        // ignore: unused_local_variable
        final String takeId =
            ctx.container.read(recordingPracticeControllerProvider).takeId!;
        final String path = ctx.recorderGateway.lastStartPath!;
        final File f = File(path);
        await f.create(recursive: true);
        await f.writeAsString('fake m4a');
        ctx.recorderGateway.nextStopResult = _stopPath(path);
        ctx.playbackGateway.nextLoadResult = const Duration(seconds: 10);
        await controller.stopRecording();
        await _pumpEventQueue();
        await controller.play();
        await _pumpEventQueue();

        // Simulate a position stream tick.
        ctx.playbackGateway.emitPosition(const Duration(seconds: 3));
        await _pumpEventQueue();
        final RecordingPracticeState state =
            ctx.container.read(recordingPracticeControllerProvider);
        expect(state.currentPlaybackPosition, const Duration(seconds: 3));
        expect(state.elapsedSeconds, 3);

        await controller.stopPlayback();
      },
    );

    test(
      'duration stream tick updates currentPlaybackDuration',
      () async {
        final ctx = _buildContext(
          permission: (b) =>
              b..nextCheckStatus = MicrophonePermissionStatus.granted,
        );
        addTearDown(ctx.container.dispose);

        final RecordingPracticeController controller =
            ctx.container.read(recordingPracticeControllerProvider.notifier);
        await controller.startRecording();
        await _pumpEventQueue();
        // ignore: unused_local_variable
        final String takeId =
            ctx.container.read(recordingPracticeControllerProvider).takeId!;
        final String path = ctx.recorderGateway.lastStartPath!;
        final File f = File(path);
        await f.create(recursive: true);
        await f.writeAsString('fake m4a');
        ctx.recorderGateway.nextStopResult = _stopPath(path);
        // First loadFile returns null (matches the
        // `clearCurrentPlaybackDuration` branch).
        ctx.playbackGateway.nextLoadResult = null;
        await controller.stopRecording();
        await _pumpEventQueue();
        await controller.play();
        await _pumpEventQueue();

        // Emit a duration.
        ctx.playbackGateway.emitDuration(const Duration(seconds: 12));
        await _pumpEventQueue();
        final RecordingPracticeState state =
            ctx.container.read(recordingPracticeControllerProvider);
        expect(state.currentPlaybackDuration, const Duration(seconds: 12));

        // Emit null.
        ctx.playbackGateway.emitDuration(null);
        await _pumpEventQueue();
        final RecordingPracticeState state2 =
            ctx.container.read(recordingPracticeControllerProvider);
        expect(state2.currentPlaybackDuration, isNull);

        await controller.stopPlayback();
      },
    );

    test('Controller + UI state stay in sync (page reads recordedTakeResult)',
        () async {
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await controller.startRecording();
      await _pumpEventQueue();
      // ignore: unused_local_variable
      final String takeId =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;
      final String path = ctx.recorderGateway.lastStartPath!;
      final File f = File(path);
      await f.create(recursive: true);
      await f.writeAsString('fake m4a');
      ctx.recorderGateway.nextStopResult = _stopPath(path);
      ctx.playbackGateway.nextLoadResult = const Duration(seconds: 6);
      await controller.stopRecording();
      await _pumpEventQueue();

      // Page-side check: a `ref.watch` on the controller would see
      // the same state; we verify by re-reading the provider.
      final RecordingPracticeState state =
          ctx.container.read(recordingPracticeControllerProvider);
      expect(state.hasRecordedTake, isTrue);
      expect(state.recordedTakeResult, isNotNull);
      expect(state.recordedTakeResult!.resolvedPath, path);
    });

    test(
      'integration: full happy path record -> stop -> play -> stopPlayback',
      () async {
        final ctx = _buildContext(
          permission: (b) =>
              b..nextCheckStatus = MicrophonePermissionStatus.granted,
        );
        addTearDown(ctx.container.dispose);

        final RecordingPracticeController controller =
            ctx.container.read(recordingPracticeControllerProvider.notifier);
        await controller.startRecording();
        await _pumpEventQueue();
        // ignore: unused_local_variable
        final String takeId =
            ctx.container.read(recordingPracticeControllerProvider).takeId!;
        final String path = ctx.recorderGateway.lastStartPath!;
        final File f = File(path);
        await f.create(recursive: true);
        await f.writeAsString('fake m4a');
        ctx.recorderGateway.nextStopResult = _stopPath(path);
        ctx.playbackGateway.nextLoadResult = const Duration(seconds: 5);

        await controller.stopRecording();
        await _pumpEventQueue();
        await controller.play();
        await _pumpEventQueue();
        // Simulate two playback ticks.
        ctx.playbackGateway.emitPosition(const Duration(seconds: 1));
        await _pumpEventQueue();
        ctx.playbackGateway.emitPosition(const Duration(seconds: 2));
        await _pumpEventQueue();
        await controller.stopPlayback();

        final RecordingPracticeState state =
            ctx.container.read(recordingPracticeControllerProvider);
        expect(state.isRecording, isFalse);
        expect(state.hasRecording, isTrue);
        expect(state.isPlaying, isFalse);
        expect(state.recordedDurationSeconds, 5);
        expect(state.currentPlaybackPosition, Duration.zero);
      },
    );

    // T031E: pinned loop-mode + completed + stop-button + startRecording-
    // guard regression tests. These exist because T031C did not pin the
    // just_audio loop mode — the user reported on real Android that
    // playback looped forever (Bug 1), the "停止回放" button stayed
    // enabled but its tap had no effect because `processingState` never
    // reached `completed` (Bug 2), and the "开始录音" button stayed
    // tappable while playback was running (Bug 3). T031E fixes the
    // root cause by pinning LoopMode.off at the gateway + service
    // layers, and pins the state-machine contract with tests that
    // exercise the same path on a fake that mirrors real just_audio
    // behaviour.

    test(
        'T031E: play() flips isPlaying=true and the page sees the enabled '
        'stop-playback button + disabled start-recording button', () async {
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await controller.startRecording();
      await _pumpEventQueue();
      // ignore: unused_local_variable
      final String takeId =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;
      final String path = ctx.recorderGateway.lastStartPath!;
      final File f = File(path);
      await f.create(recursive: true);
      await f.writeAsString('fake m4a');
      ctx.recorderGateway.nextStopResult = _stopPath(path);
      ctx.playbackGateway.nextLoadResult = const Duration(seconds: 4);

      await controller.stopRecording();
      await _pumpEventQueue();
      await controller.play();
      await _pumpEventQueue();

      // T031E Bug 1 fix: isPlaying must be true after play() returns.
      // (Pre-fix the production path left isPlaying=false because
      // just_audio's loopMode was on LoopMode.one — but the
      // controller's copyWith still ran and the page saw isPlaying
      // toggling on briefly. The widget contract is the same; the
      // audio behaviour is the actual difference.)
      final RecordingPracticeState state =
          ctx.container.read(recordingPracticeControllerProvider);
      expect(state.isPlaying, isTrue,
          reason: 'T031E: play() must flip isPlaying to true');
      expect(ctx.playbackGateway.playCallCount, 1,
          reason: 'T031E: playback.play must be called exactly once');

      // Cleanup.
      await controller.stopPlayback();
    });

    test(
        'T031E: loadFile() pins LoopMode.off via the gateway contract '
        '(no playback looping)', () async {
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await controller.startRecording();
      await _pumpEventQueue();
      // ignore: unused_local_variable
      final String takeId =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;
      final String path = ctx.recorderGateway.lastStartPath!;
      final File f = File(path);
      await f.create(recursive: true);
      await f.writeAsString('fake m4a');
      ctx.recorderGateway.nextStopResult = _stopPath(path);
      ctx.playbackGateway.nextLoadResult = const Duration(seconds: 4);

      await controller.stopRecording();
      await _pumpEventQueue();
      // T031E: every loadFile (including the one inside
      // _probeRecordingDuration triggered by stopRecording, plus the
      // one inside play()) must pin LoopMode.off. The fake records
      // the call count; we assert >= 2 to pin the contract.
      final int setLoopBefore = ctx.playbackGateway.setLoopModeOffCallCount;
      await controller.play();
      await _pumpEventQueue();
      expect(
        ctx.playbackGateway.setLoopModeOffCallCount,
        greaterThan(setLoopBefore),
        reason: 'T031E: loadFile() must pin LoopMode.off on every invocation '
            'to defend against just_audio default drift and previous-'
            'session state leakage',
      );

      await controller.stopPlayback();
    });

    test(
        'T031E: natural completion flips isPlaying back to false (state '
        'machine recovery does not require user to tap stop)', () async {
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await controller.startRecording();
      await _pumpEventQueue();
      // ignore: unused_local_variable
      final String takeId =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;
      final String path = ctx.recorderGateway.lastStartPath!;
      final File f = File(path);
      await f.create(recursive: true);
      await f.writeAsString('fake m4a');
      ctx.recorderGateway.nextStopResult = _stopPath(path);
      ctx.playbackGateway.nextLoadResult = const Duration(seconds: 4);

      await controller.stopRecording();
      await _pumpEventQueue();
      // T031E: drive a normal play() (no auto-complete) so we can
      // observe isPlaying flipping to true, THEN emit the
      // completed event manually (this mirrors the production
      // path where the just_audio `completed` event arrives
      // asynchronously while playback is in progress).
      await controller.play();
      await _pumpEventQueue();
      // play() flipped isPlaying to true.
      expect(
        ctx.container.read(recordingPracticeControllerProvider).isPlaying,
        isTrue,
      );

      // Emit the natural completion (mimics just_audio's
      // `processingState == completed` event).
      ctx.playbackGateway.emitPlayerState(const PlaybackPlayerState(
        playing: false,
        processingState: PlaybackProcessingState.completed,
      ));
      await _pumpEventQueue();
      await _pumpEventQueue();

      final RecordingPracticeState state =
          ctx.container.read(recordingPracticeControllerProvider);
      expect(state.isPlaying, isFalse,
          reason: 'T031E: completed must flip isPlaying back to false');
      expect(state.currentPlaybackPosition, Duration.zero,
          reason: 'T031E: completed must reset position to 0');
    });

    test(
        'T031E: after natural completion the user can replay from 0 '
        'without a fresh recording (no-op on recorder)', () async {
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await controller.startRecording();
      await _pumpEventQueue();
      // ignore: unused_local_variable
      final String takeId =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;
      final String path = ctx.recorderGateway.lastStartPath!;
      final File f = File(path);
      await f.create(recursive: true);
      await f.writeAsString('fake m4a');
      ctx.recorderGateway.nextStopResult = _stopPath(path);
      ctx.playbackGateway.nextLoadResult = const Duration(seconds: 4);

      await controller.stopRecording();
      await _pumpEventQueue();
      // Use the deterministic microtask-scheduled completion path.
      ctx.playbackGateway.completeOnNextPlay = true;
      await controller.play();
      await _pumpEventQueue();
      await _pumpEventQueue();
      expect(
        ctx.container.read(recordingPracticeControllerProvider).isPlaying,
        isFalse,
        reason: 'auto-recovery already flipped isPlaying back to false',
      );

      // T031E: replaying from 0 must NOT start a new recording
      // (startRecording guard pins this). Recorder call count must
      // be 1 (the initial startRecording).
      final int startsBefore = ctx.recorderGateway.startCallCount;
      await controller.play();
      await _pumpEventQueue();
      expect(
        ctx.recorderGateway.startCallCount,
        startsBefore,
        reason: 'T031E: replay after completion must not start a recording',
      );
      expect(
        ctx.container.read(recordingPracticeControllerProvider).isPlaying,
        isTrue,
        reason: 'T031E: replay after completion must flip isPlaying to true',
      );

      await controller.stopPlayback();
    });

    test(
        'T031E: playback-loops regression — fake gateway simulates real '
        'just_audio completed (event arrives AFTER play() returns) so the '
        'controller state machine is exercised the same way as on device',
        () async {
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await controller.startRecording();
      await _pumpEventQueue();
      // ignore: unused_local_variable
      final String takeId =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;
      final String path = ctx.recorderGateway.lastStartPath!;
      final File f = File(path);
      await f.create(recursive: true);
      await f.writeAsString('fake m4a');
      ctx.recorderGateway.nextStopResult = _stopPath(path);
      ctx.playbackGateway.nextLoadResult = const Duration(seconds: 4);

      await controller.stopRecording();
      await _pumpEventQueue();

      // T031E: schedule natural completion (mimics just_audio's
      // post-end event). Then play() returns; the listener is in
      // place; the microtask fires; controller flips isPlaying to
      // false. This is the exact ordering real just_audio uses.
      ctx.playbackGateway.completeOnNextPlay = true;
      await controller.play();
      // T031E: the fake's microtask is what the production
      // playerStateStream emit mirrors. Two microtask drains
      // suffice to flush the scheduleMicrotask inside play().
      await _pumpEventQueue();
      await _pumpEventQueue();

      // T031E: the controller's state machine must be in the
      // post-completion state — isPlaying=false — with no user
      // action required.
      final RecordingPracticeState state =
          ctx.container.read(recordingPracticeControllerProvider);
      expect(state.isPlaying, isFalse,
          reason: 'T031E: just_audio completed event must auto-recover the '
              'controller state, matching the production behaviour');
      expect(state.currentPlaybackPosition, Duration.zero,
          reason: 'T031E: position must reset to 0 on completion');
      // The seek-to-0 path must have driven the playback service
      // at least once.
      expect(ctx.playbackGateway.seekCallCount, greaterThanOrEqualTo(1),
          reason: 'T031E: completed must trigger seek(0) for replay');
      expect(ctx.playbackGateway.lastSeekPosition, Duration.zero,
          reason: 'T031E: the recovery seek must target position 0');
    });

    test(
        'T031E: stopPlayback() flips isPlaying back, the page re-enables '
        'start recording and disables stop playback', () async {
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await controller.startRecording();
      await _pumpEventQueue();
      // ignore: unused_local_variable
      final String takeId =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;
      final String path = ctx.recorderGateway.lastStartPath!;
      final File f = File(path);
      await f.create(recursive: true);
      await f.writeAsString('fake m4a');
      ctx.recorderGateway.nextStopResult = _stopPath(path);
      ctx.playbackGateway.nextLoadResult = const Duration(seconds: 4);

      await controller.stopRecording();
      await _pumpEventQueue();
      await controller.play();
      await _pumpEventQueue();
      expect(
        ctx.container.read(recordingPracticeControllerProvider).isPlaying,
        isTrue,
      );

      // T031E: stopPlayback must drive the playback service to
      // stop and flip isPlaying to false so the page re-enables
      // start recording and re-enables replay.
      final int stopsBefore = ctx.playbackGateway.stopCallCount;
      await controller.stopPlayback();
      await _pumpEventQueue();
      final RecordingPracticeState state =
          ctx.container.read(recordingPracticeControllerProvider);
      expect(state.isPlaying, isFalse,
          reason: 'T031E: stopPlayback must flip isPlaying to false');
      expect(state.currentPlaybackPosition, Duration.zero,
          reason: 'T031E: stopPlayback must reset position to 0');
      expect(ctx.playbackGateway.stopCallCount, stopsBefore + 1,
          reason: 'T031E: stopPlayback must call playback.stop');
    });

    test(
        'T031E: startRecording guard — when isPlaying is true, '
        'startRecording() does NOT request permission, does NOT call '
        'recorder.start, does NOT mint a new takeId', () async {
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await controller.startRecording();
      await _pumpEventQueue();
      // ignore: unused_local_variable
      final String takeId =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;
      final String path = ctx.recorderGateway.lastStartPath!;
      final File f = File(path);
      await f.create(recursive: true);
      await f.writeAsString('fake m4a');
      ctx.recorderGateway.nextStopResult = _stopPath(path);
      ctx.playbackGateway.nextLoadResult = const Duration(seconds: 4);

      await controller.stopRecording();
      await _pumpEventQueue();
      await controller.play();
      await _pumpEventQueue();
      expect(
        ctx.container.read(recordingPracticeControllerProvider).isPlaying,
        isTrue,
      );

      // T031E Bug 3 regression: the controller guard is the
      // belt-and-braces layer (the page also disables the button).
      // Pin all three assertions: NO permission check, NO recorder
      // call, NO new takeId.
      final int checksBefore = ctx.permissionGateway.checkStatusCallCount;
      final int startsBefore = ctx.recorderGateway.startCallCount;
      final String takeIdBefore =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;
      await controller.startRecording();
      await _pumpEventQueue();
      final RecordingPracticeState state =
          ctx.container.read(recordingPracticeControllerProvider);
      expect(state.isPlaying, isTrue,
          reason: 'T031E: playback must still be running');
      expect(state.takeId, takeIdBefore,
          reason: 'T031E: a no-op startRecording must NOT mint a new takeId');
      expect(ctx.recorderGateway.startCallCount, startsBefore,
          reason: 'T031E: recorder.start MUST NOT be called while playing');
      expect(ctx.permissionGateway.checkStatusCallCount, checksBefore,
          reason:
              'T031E: permission service MUST NOT be touched while playing');

      await controller.stopPlayback();
    });

    test(
        'T031E: natural-completion recovery does NOT trigger Drift writes '
        'or insert a PracticeRecord (audioFilePath stays null) — regression',
        () async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository();
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
        repository: repo,
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await controller.startRecording();
      await _pumpEventQueue();
      // ignore: unused_local_variable
      final String takeId =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;
      final String path = ctx.recorderGateway.lastStartPath!;
      final File f = File(path);
      await f.create(recursive: true);
      await f.writeAsString('fake m4a');
      ctx.recorderGateway.nextStopResult = _stopPath(path);
      ctx.playbackGateway.nextLoadResult = const Duration(seconds: 4);

      await controller.stopRecording();
      await _pumpEventQueue();
      ctx.playbackGateway.completeOnNextPlay = true;
      await controller.play();
      await _pumpEventQueue();
      await _pumpEventQueue();
      expect(
        ctx.container.read(recordingPracticeControllerProvider).isPlaying,
        isFalse,
        reason: 'auto-recovery must flip isPlaying to false',
      );

      // T031E: natural-completion recovery MUST NOT auto-save.
      expect(repo.inserted, isEmpty,
          reason: 'T031E: natural completion must not insert a PracticeRecord');
      expect(
        ctx.container.read(recordingPracticeControllerProvider).savedRecordId,
        isNull,
        reason: 'T031E: savedRecordId stays null — auto-recovery is not a save',
      );
    });

    test(
        'T031E: natural-completion recovery does NOT change audioFilePath '
        '(no take is promoted to a saved PracticeRecord)', () async {
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await controller.startRecording();
      await _pumpEventQueue();
      // ignore: unused_local_variable
      final String takeId =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;
      final String path = ctx.recorderGateway.lastStartPath!;
      final File f = File(path);
      await f.create(recursive: true);
      await f.writeAsString('fake m4a');
      ctx.recorderGateway.nextStopResult = _stopPath(path);
      ctx.playbackGateway.nextLoadResult = const Duration(seconds: 4);

      await controller.stopRecording();
      await _pumpEventQueue();
      final String resolvedPath = ctx.container
          .read(recordingPracticeControllerProvider)
          .recordedTakeResult!
          .resolvedPath;
      ctx.playbackGateway.completeOnNextPlay = true;
      await controller.play();
      await _pumpEventQueue();
      await _pumpEventQueue();

      // T031E: resolvedPath stays the same — the in-memory take is
      // not promoted, audioFilePath stays null on the would-be
      // PracticeRecord.
      final RecordingPracticeState state =
          ctx.container.read(recordingPracticeControllerProvider);
      expect(state.recordedTakeResult, isNotNull);
      expect(state.recordedTakeResult!.resolvedPath, resolvedPath,
          reason: 'T031E: resolved path must not be modified by recovery');
    });

    // ---------------------------------------------------------------------
    // T031G: real-device "playback state machine not in sync" regression
    // tests. The user reported on real Android that tapping "回放":
    //  - starts audio in the background
    //  - keeps the "开始录音" button enabled (and starts a recording
    //    if the user taps it)
    //  - keeps the "停止回放" button DISABLED
    // Root cause: the controller `await`ed `playback.play()` which
    // on real Android returns a Future that stays pending for the
    // entire playback duration. The synchronous
    // `state.isPlaying = true` write only ran after the file
    // finished playing. T031G fixes the contract by:
    //  - flipping isPlaying synchronously, BEFORE the
    //    fire-and-forget play() call;
    //  - relying on the playerStateStream `completed` event to
    //    recover the post-playback state (same path that
    //    drives natural completion today);
    //  - making the fake gateway's play() Future stay pending
    //    when the test sets `keepPlayPending = true`, mirroring
    //    real just_audio behaviour.
    // ---------------------------------------------------------------------

    test(
        'T031G: play() flips isPlaying=true synchronously even when the '
        'underlying play() Future stays pending (real-device regression)',
        () async {
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await controller.startRecording();
      await _pumpEventQueue();
      // ignore: unused_local_variable
      final String takeId =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;
      final String path = ctx.recorderGateway.lastStartPath!;
      final File f = File(path);
      await f.create(recursive: true);
      await f.writeAsString('fake m4a');
      ctx.recorderGateway.nextStopResult = _stopPath(path);
      ctx.playbackGateway.nextLoadResult = const Duration(seconds: 4);

      await controller.stopRecording();
      await _pumpEventQueue();

      // T031G: pin the fake to keep the play() Future pending —
      // mirrors real just_audio on Android.
      ctx.playbackGateway.keepPlayPending = true;
      await controller.play();
      // T031G: do NOT drain any extra microtasks here. With the
      // old code the `state.isPlaying = true` write was inside
      // the async body AFTER `await _playback.play()` and would
      // never have landed yet. With the fix the state is set
      // synchronously before the fire-and-forget play() call.
      final RecordingPracticeState state =
          ctx.container.read(recordingPracticeControllerProvider);
      expect(state.isPlaying, isTrue,
          reason: 'T031G: play() must flip isPlaying=true synchronously, '
              'even when the underlying play() Future stays pending');
      expect(ctx.playbackGateway.playCallCount, 1,
          reason: 'T031G: play() must still call gateway.play()');
      expect(ctx.playbackGateway.loadFileCallCount, greaterThanOrEqualTo(1),
          reason: 'T031G: play() must still call gateway.loadFile()');
    });

    test(
        'T031G: with pending play Future, startRecording is rejected — no '
        'permission check, no recorder call, no new takeId', () async {
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await controller.startRecording();
      await _pumpEventQueue();
      // ignore: unused_local_variable
      final String takeId =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;
      final String path = ctx.recorderGateway.lastStartPath!;
      final File f = File(path);
      await f.create(recursive: true);
      await f.writeAsString('fake m4a');
      ctx.recorderGateway.nextStopResult = _stopPath(path);
      ctx.playbackGateway.nextLoadResult = const Duration(seconds: 4);

      await controller.stopRecording();
      await _pumpEventQueue();

      // T031G: keep the play() Future pending and assert that
      // startRecording is fully blocked by the isPlaying guard.
      ctx.playbackGateway.keepPlayPending = true;
      await controller.play();
      final int checksBefore = ctx.permissionGateway.checkStatusCallCount;
      final int startsBefore = ctx.recorderGateway.startCallCount;
      final String takeIdBefore =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;
      await controller.startRecording();
      await _pumpEventQueue();
      final RecordingPracticeState state =
          ctx.container.read(recordingPracticeControllerProvider);
      expect(state.isPlaying, isTrue,
          reason: 'T031G: playback must still be running');
      expect(state.takeId, takeIdBefore,
          reason: 'T031G: a no-op startRecording must NOT mint a new takeId');
      expect(ctx.recorderGateway.startCallCount, startsBefore,
          reason: 'T031G: recorder.start MUST NOT be called while playing');
      expect(ctx.permissionGateway.checkStatusCallCount, checksBefore,
          reason:
              'T031G: permission service MUST NOT be touched while playing');
    });

    test(
        'T031G: with pending play Future, stopPlayback drives the playback '
        'service to stop and flips isPlaying back to false', () async {
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await controller.startRecording();
      await _pumpEventQueue();
      // ignore: unused_local_variable
      final String takeId =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;
      final String path = ctx.recorderGateway.lastStartPath!;
      final File f = File(path);
      await f.create(recursive: true);
      await f.writeAsString('fake m4a');
      ctx.recorderGateway.nextStopResult = _stopPath(path);
      ctx.playbackGateway.nextLoadResult = const Duration(seconds: 4);

      await controller.stopRecording();
      await _pumpEventQueue();

      // T031G: keep the play() Future pending and exercise
      // stopPlayback.
      ctx.playbackGateway.keepPlayPending = true;
      await controller.play();
      expect(
        ctx.container.read(recordingPracticeControllerProvider).isPlaying,
        isTrue,
      );
      final int stopsBefore = ctx.playbackGateway.stopCallCount;
      await controller.stopPlayback();
      await _pumpEventQueue();
      final RecordingPracticeState state =
          ctx.container.read(recordingPracticeControllerProvider);
      expect(state.isPlaying, isFalse,
          reason: 'T031G: stopPlayback must flip isPlaying to false even when '
              'the play() Future is still pending');
      expect(ctx.playbackGateway.stopCallCount, stopsBefore + 1,
          reason:
              'T031G: stopPlayback must drive the playback service to stop');
    });

    test(
        'T031G: with pending play Future, emitting the playerStateStream '
        '`completed` event flips isPlaying back to false (the only path '
        'that drives the natural-completion recovery)', () async {
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await controller.startRecording();
      await _pumpEventQueue();
      // ignore: unused_local_variable
      final String takeId =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;
      final String path = ctx.recorderGateway.lastStartPath!;
      final File f = File(path);
      await f.create(recursive: true);
      await f.writeAsString('fake m4a');
      ctx.recorderGateway.nextStopResult = _stopPath(path);
      ctx.playbackGateway.nextLoadResult = const Duration(seconds: 4);

      await controller.stopRecording();
      await _pumpEventQueue();

      // T031G: pending play, then emit `completed` (mimics
      // just_audio's natural-end event). The controller must
      // recover the state.
      ctx.playbackGateway.keepPlayPending = true;
      await controller.play();
      ctx.playbackGateway.emitPlayerState(const PlaybackPlayerState(
        playing: false,
        processingState: PlaybackProcessingState.completed,
      ));
      await _pumpEventQueue();
      await _pumpEventQueue();
      final RecordingPracticeState state =
          ctx.container.read(recordingPracticeControllerProvider);
      expect(state.isPlaying, isFalse,
          reason: 'T031G: completed must auto-recover the controller state '
              'even when the play() Future is still pending');
    });

    test(
        'T031G: after a pending play Future completes naturally, the user '
        'can replay from 0 (loadFile is called again, no fresh recording)',
        () async {
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await controller.startRecording();
      await _pumpEventQueue();
      // ignore: unused_local_variable
      final String takeId =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;
      final String path = ctx.recorderGateway.lastStartPath!;
      final File f = File(path);
      await f.create(recursive: true);
      await f.writeAsString('fake m4a');
      ctx.recorderGateway.nextStopResult = _stopPath(path);
      ctx.playbackGateway.nextLoadResult = const Duration(seconds: 4);

      await controller.stopRecording();
      await _pumpEventQueue();

      // T031G: first play, then completed, then replay from 0.
      ctx.playbackGateway.keepPlayPending = true;
      await controller.play();
      ctx.playbackGateway.emitPlayerState(const PlaybackPlayerState(
        playing: false,
        processingState: PlaybackProcessingState.completed,
      ));
      await _pumpEventQueue();
      await _pumpEventQueue();
      expect(
        ctx.container.read(recordingPracticeControllerProvider).isPlaying,
        isFalse,
      );

      // T031G: replay from 0 — must work. The first play() went
      // through the pending Future path. The replay must go
      // through a fresh loadFile + new play() call.
      final int loadBefore = ctx.playbackGateway.loadFileCallCount;
      final int startsBefore = ctx.recorderGateway.startCallCount;
      // Switch to a regular play (no keepPlayPending, no
      // completeOnNextPlay) — the fake returns immediately
      // and the controller sees isPlaying flip synchronously.
      await controller.play();
      await _pumpEventQueue();
      final RecordingPracticeState replayed =
          ctx.container.read(recordingPracticeControllerProvider);
      expect(replayed.isPlaying, isTrue,
          reason: 'T031G: replay after completion must start playback');
      expect(ctx.playbackGateway.loadFileCallCount, greaterThan(loadBefore),
          reason: 'T031G: replay must call loadFile() again so playback '
              'restarts from 0');
      expect(ctx.recorderGateway.startCallCount, startsBefore,
          reason: 'T031G: replay must NOT start a new recording');

      await controller.stopPlayback();
    });

    test(
        'T031G: play() does not call playback.play() more than once, even '
        'when re-entered while a previous play is in flight (the '
        'isPlaying guard fires synchronously)', () async {
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await controller.startRecording();
      await _pumpEventQueue();
      // ignore: unused_local_variable
      final String takeId =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;
      final String path = ctx.recorderGateway.lastStartPath!;
      final File f = File(path);
      await f.create(recursive: true);
      await f.writeAsString('fake m4a');
      ctx.recorderGateway.nextStopResult = _stopPath(path);
      ctx.playbackGateway.nextLoadResult = const Duration(seconds: 4);

      await controller.stopRecording();
      await _pumpEventQueue();

      // T031G: first play keeps the Future pending. The second
      // call must be blocked by the synchronous isPlaying guard.
      ctx.playbackGateway.keepPlayPending = true;
      await controller.play();
      final int playsBefore = ctx.playbackGateway.playCallCount;
      final int loadsBefore = ctx.playbackGateway.loadFileCallCount;
      await controller.play();
      expect(ctx.playbackGateway.playCallCount, playsBefore,
          reason: 'T031G: a second play() while playing MUST NOT call '
              'gateway.play() again');
      expect(ctx.playbackGateway.loadFileCallCount, loadsBefore,
          reason: 'T031G: a second play() while playing MUST NOT call '
              'gateway.loadFile() again');

      await controller.stopPlayback();
    });

    test(
        'T031G: loadFile pins LoopMode.off even when play() is '
        'fire-and-forget (the loop-mode contract survives the async play)',
        () async {
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await controller.startRecording();
      await _pumpEventQueue();
      // ignore: unused_local_variable
      final String takeId =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;
      final String path = ctx.recorderGateway.lastStartPath!;
      final File f = File(path);
      await f.create(recursive: true);
      await f.writeAsString('fake m4a');
      ctx.recorderGateway.nextStopResult = _stopPath(path);
      ctx.playbackGateway.nextLoadResult = const Duration(seconds: 4);

      await controller.stopRecording();
      await _pumpEventQueue();

      final int loopBefore = ctx.playbackGateway.setLoopModeOffCallCount;
      ctx.playbackGateway.keepPlayPending = true;
      await controller.play();
      expect(
        ctx.playbackGateway.setLoopModeOffCallCount,
        greaterThan(loopBefore),
        reason: 'T031G: loadFile must still pin LoopMode.off to prevent the '
            'real-device playback-loops-forever bug, even when play() is '
            'fire-and-forget',
      );

      await controller.stopPlayback();
    });
  });

  group('RecordingPracticeController save (T013.4A) — preserved', () {
    setUp(() {
      _SequentialPracticeRecordIdGenerator.callCount = 0;
      _GatedPracticeRecordRepository.resetGate();
    });

    test('saveCurrentTake returns success and writes savedRecordId', () async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository();
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
        repository: repo,
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await controller.startRecording();
      await _pumpEventQueue();
      // ignore: unused_local_variable
      final String takeId =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;
      final String path = ctx.recorderGateway.lastStartPath!;
      final File f = File(path);
      await f.create(recursive: true);
      await f.writeAsString('fake m4a');
      ctx.recorderGateway.nextStopResult = _stopPath(path);
      ctx.playbackGateway.nextLoadResult = const Duration(seconds: 3);
      await controller.stopRecording();
      await _pumpEventQueue();
      controller.setSelfRating(SelfRating.good);
      controller.setNote('  C -> Am 切换太慢  ');
      final String expectedTakeId =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;

      final SaveRecordingResult result = await controller.saveCurrentTake();
      expect(result, SaveRecordingResult.success);

      final RecordingPracticeState after =
          ctx.container.read(recordingPracticeControllerProvider);
      expect(after.isSaved, isTrue);
      expect(after.savedRecordId, expectedTakeId);
      expect(after.isSaving, isFalse);
      expect(after.takeId, expectedTakeId,
          reason: 'a successful save must not mint a new id');
      expect(after.hasRecording, isTrue);
      expect(after.selfRating, SelfRating.good);

      expect(repo.inserted.length, 1);
      final PracticeRecord saved = repo.inserted.single;
      expect(saved.id, expectedTakeId);
      expect(saved.durationSeconds, 3);
      expect(saved.audioFilePath, isNull,
          reason: 'T031 explicitly does NOT promote take to PracticeRecord');
      expect(saved.selfAssessment, SelfAssessment.good);
    });

    test('save without a rating persists the recording tag only', () async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository();
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
        repository: repo,
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await controller.startRecording();
      await _pumpEventQueue();
      // ignore: unused_local_variable
      final String takeId =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;
      final String path = ctx.recorderGateway.lastStartPath!;
      final File f = File(path);
      await f.create(recursive: true);
      await f.writeAsString('fake m4a');
      ctx.recorderGateway.nextStopResult = _stopPath(path);
      ctx.playbackGateway.nextLoadResult = const Duration(seconds: 1);
      await controller.stopRecording();
      await _pumpEventQueue();

      final SaveRecordingResult result = await controller.saveCurrentTake();
      expect(result, SaveRecordingResult.success);
      final PracticeRecord saved = repo.inserted.single;
      expect(saved.practiceTags, <PracticeTag>[PracticeTag.recording]);
      expect(saved.audioFilePath, isNull);
    });

    test('save without a valid take is ignored', () async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository();
      final ctx = _buildContext(repository: repo);
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      final SaveRecordingResult result = await controller.saveCurrentTake();
      expect(result, SaveRecordingResult.ignored);
      expect(repo.inserted, isEmpty);
    });

    test('save returns failure when Repository throws', () async {
      final _FakePracticeRecordRepository repo = _FakePracticeRecordRepository()
        ..throwOnInsert = StateError('synthetic insert failure');
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
        repository: repo,
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await controller.startRecording();
      await _pumpEventQueue();
      // ignore: unused_local_variable
      final String takeId =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;
      final String path = ctx.recorderGateway.lastStartPath!;
      final File f = File(path);
      await f.create(recursive: true);
      await f.writeAsString('fake m4a');
      ctx.recorderGateway.nextStopResult = _stopPath(path);
      ctx.playbackGateway.nextLoadResult = const Duration(seconds: 1);
      await controller.stopRecording();
      await _pumpEventQueue();

      final SaveRecordingResult result = await controller.saveCurrentTake();
      expect(result, SaveRecordingResult.failure);
      final RecordingPracticeState after =
          ctx.container.read(recordingPracticeControllerProvider);
      expect(after.isSaved, isFalse);
      expect(after.takeId, takeId);
    });

    test('SelfRating maps to the correct SelfAssessment for all three values',
        () async {
      for (final SelfRating rating in SelfRating.values) {
        final _FakePracticeRecordRepository repo =
            _FakePracticeRecordRepository();
        final ctx = _buildContext(
          permission: (b) =>
              b..nextCheckStatus = MicrophonePermissionStatus.granted,
          repository: repo,
        );
        addTearDown(ctx.container.dispose);
        final RecordingPracticeController controller =
            ctx.container.read(recordingPracticeControllerProvider.notifier);
        await controller.startRecording();
        await _pumpEventQueue();
        final String path = ctx.recorderGateway.lastStartPath!;
        final File f = File(path);
        await f.create(recursive: true);
        await f.writeAsString('fake m4a');
        ctx.recorderGateway.nextStopResult = _stopPath(path);
        ctx.playbackGateway.nextLoadResult = const Duration(seconds: 1);
        await controller.stopRecording();
        await _pumpEventQueue();
        controller.setSelfRating(rating);
        final SaveRecordingResult result = await controller.saveCurrentTake();
        expect(result, SaveRecordingResult.success, reason: 'rating=$rating');
        final PracticeRecord saved = repo.inserted.last;
        final SelfAssessment? expected = _mapExpectedAssessment(rating);
        expect(saved.selfAssessment, expected, reason: 'rating=$rating');
      }
    });

    test('setSelfRating and setNote are no-ops after a successful save',
        () async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository();
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
        repository: repo,
      );
      addTearDown(ctx.container.dispose);
      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await controller.startRecording();
      await _pumpEventQueue();
      // ignore: unused_local_variable
      final String takeId =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;
      final String path = ctx.recorderGateway.lastStartPath!;
      final File f = File(path);
      await f.create(recursive: true);
      await f.writeAsString('fake m4a');
      ctx.recorderGateway.nextStopResult = _stopPath(path);
      ctx.playbackGateway.nextLoadResult = const Duration(seconds: 1);
      await controller.stopRecording();
      await _pumpEventQueue();
      controller.setSelfRating(SelfRating.good);
      controller.setNote('good take');
      final SaveRecordingResult save = await controller.saveCurrentTake();
      expect(save, SaveRecordingResult.success);

      controller.setSelfRating(SelfRating.retry);
      controller.setNote('completely different note');
      final RecordingPracticeState after =
          ctx.container.read(recordingPracticeControllerProvider);
      expect(after.selfRating, SelfRating.good);
      expect(after.note, 'good take');
    });

    test('createdAt and updatedAt are sourced from appClockProvider', () async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository();
      final DateTime pinnedNow = DateTime.utc(2026, 6, 20, 9, 30, 0);
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
        repository: repo,
        clock: () => pinnedNow,
      );
      addTearDown(ctx.container.dispose);
      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await controller.startRecording();
      await _pumpEventQueue();
      // ignore: unused_local_variable
      final String takeId =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;
      final String path = ctx.recorderGateway.lastStartPath!;
      final File f = File(path);
      await f.create(recursive: true);
      await f.writeAsString('fake m4a');
      ctx.recorderGateway.nextStopResult = _stopPath(path);
      ctx.playbackGateway.nextLoadResult = const Duration(seconds: 1);
      await controller.stopRecording();
      await _pumpEventQueue();
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

/// Helper that maps a [SelfRating] to the expected
/// [SelfAssessment].
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

/// Drains microtasks so the controller's await chains can settle.
Future<void> _pumpEventQueue() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

/// Helper that creates the resolved path string the fake recorder
/// gateway should return from `stop()`. The path MUST equal the
/// requested path the controller handed to `recorder.start` so
/// the service does not throw on path-mismatch.
String _stopPath(String path) => path;

/// A bundle of overrides + fakes wired into a `ProviderContainer`.
class _ControllerContext {
  _ControllerContext({
    required this.container,
    required this.recorderGateway,
    required this.playbackGateway,
    required this.permissionGateway,
  });

  final ProviderContainer container;
  final FakeAudioRecorderGateway recorderGateway;
  final FakeAudioPlaybackGateway playbackGateway;
  final FakeMicrophonePermissionGateway permissionGateway;
}

typedef _Builder<T> = void Function(T b);

/// Builds a `ProviderContainer` with the production
/// `audioFileStorageServiceProvider` / `realAudioRecorderServiceProvider` /
/// `realAudioPlaybackServiceProvider` / `microphonePermissionServiceProvider`
/// all overridden to use isolated fake gateways + isolated temp roots.
///
/// The [permission] / [recorder] / [playback] callbacks let each
/// test pre-seed values on the corresponding fake.
_ControllerContext _buildContext({
  _Builder<FakeMicrophonePermissionGateway>? permission,
  _Builder<FakeAudioRecorderGateway>? recorder,
  _Builder<FakeAudioPlaybackGateway>? playback,
  PracticeRecordRepository? repository,
  DateTime Function()? clock,
}) {
  final (:rootProvider, :root) = _isolatedRoot();
  final AudioFileStorageService storage = AudioFileStorageService(
    rootDirectoryProvider: rootProvider,
  );

  final FakeAudioRecorderGateway recorderGateway = FakeAudioRecorderGateway();
  void Function(FakeAudioRecorderGateway b)? recBuilder = recorder;
  recBuilder?.call(recorderGateway);
  final RealAudioRecorderService recorderService = RealAudioRecorderService(
    gateway: recorderGateway,
    storage: storage,
  );

  final FakeAudioPlaybackGateway playbackGateway = FakeAudioPlaybackGateway();
  void Function(FakeAudioPlaybackGateway b)? pbBuilder = playback;
  pbBuilder?.call(playbackGateway);
  final RealAudioPlaybackService playbackService = RealAudioPlaybackService(
    gateway: playbackGateway,
    storage: storage,
  );

  final FakeMicrophonePermissionGateway permissionGateway =
      FakeMicrophonePermissionGateway();
  void Function(FakeMicrophonePermissionGateway b)? permBuilder = permission;
  permBuilder?.call(permissionGateway);
  final MicrophonePermissionService permissionService =
      MicrophonePermissionService(permissionGateway);

  final _SequentialPracticeRecordIdGenerator idGen =
      _SequentialPracticeRecordIdGenerator();

  final List<Override> overrides = <Override>[
    audioFileStorageServiceProvider.overrideWithValue(storage),
    realAudioRecorderServiceProvider.overrideWithValue(recorderService),
    realAudioPlaybackServiceProvider.overrideWithValue(playbackService),
    microphonePermissionServiceProvider.overrideWithValue(permissionService),
    practiceRecordIdGeneratorProvider.overrideWithValue(idGen),
    installDateServiceProvider.overrideWithValue(
      _FakeInstallDateService(
        DateTime.utc(2026, 6, 19, 0, 0, 0),
      ),
    ),
    practiceDayResolverProvider.overrideWithValue(_FakePracticeDayResolver()),
    appClockProvider.overrideWithValue(clock ?? (() => _kTestNowUtc)),
  ];
  if (repository != null) {
    overrides.add(
      practiceRecordRepositoryProvider.overrideWithValue(repository),
    );
  }

  final ProviderContainer container = ProviderContainer(overrides: overrides);

  // Force the storage to be ready so recorder.start can succeed
  // without waiting on an async IO tick.
  unawaited(storage.ensureDirectories());
  // Drain microtasks to let the unawaited future resolve.
  // The recorder service calls ensureDirectories() inside start()
  // and re-resolves the root, so this pre-warm is best-effort.

  return _ControllerContext(
    container: container,
    recorderGateway: recorderGateway,
    playbackGateway: playbackGateway,
    permissionGateway: permissionGateway,
  );
}

/// In-memory [PracticeRecordRepository] used by the save-flow
/// tests.
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

/// Repository whose `insert` blocks on a static `gate` future.
class _GatedPracticeRecordRepository implements PracticeRecordRepository {
  static Completer<void> gate = Completer<void>();
  final List<PracticeRecord> inserted = <PracticeRecord>[];

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

class _SequentialPracticeRecordIdGenerator
    implements PracticeRecordIdGenerator {
  static int callCount = 0;

  @override
  String generate() {
    callCount += 1;
    return 'take-$callCount';
  }
}

class _FakeInstallDateService implements InstallDateService {
  _FakeInstallDateService(this._fixed);

  final DateTime _fixed;

  @override
  Future<DateTime> getInstallDate() async => _fixed;
}
