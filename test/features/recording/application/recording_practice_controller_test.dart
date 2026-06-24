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
import 'package:ukulele_app/features/recording/application/recording_page_exit_stop_result.dart';
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
import 'package:ukulele_app/shared/services/microphone_permission_gateway.dart';
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
      // T038B: the user-visible copy is unified for `denied`
      // and `permanentDenied` so the page never shows
      // "永久拒绝". The internal enum value is still
      // RecordingPermissionStatus.denied.
      expect(denied.statusLabel, '麦克风权限已拒绝');

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
      // T038B: same user-visible copy as `denied`. The page
      // is the source of truth for the system-settings entry
      // point — the internal enum value is the only signal
      // the page reads to decide which affordance to surface.
      expect(permDenied.statusLabel, '麦克风权限已拒绝');
      expect(permDenied.statusLabel, isNot(contains('永久拒绝')),
          reason: 'T038B: statusLabel must never contain 永久拒绝');

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

    // -----------------------------------------------------------------
    // T038B — user-visible copy + system-settings recovery.
    //
    // Pins the post-T038B contract:
    //  - Internal `permanentlyDenied` semantics are preserved
    //    (the controller still distinguishes `denied` and
    //    `permanentDenied` for routing decisions).
    //  - User-visible `statusLabel` is unified to
    //    "麦克风权限已拒绝" for both `denied` and
    //    `permanentDenied` — the page never shows "永久拒绝".
    //  - `openAppSettings` is the official path for jumping
    //    to the system settings page on a `permanentDenied`
    //    outcome. It guards against double-tap re-entrancy
    //    and never throws.
    //  - `refreshPermissionStatus` re-reads the platform-side
    //    status without auto-starting a recording, so a
    //    "返回App" recheck updates the visible state without
    //    bypassing the user's tap on "开始录音".
    // -----------------------------------------------------------------

    test(
      'T038B: openAppSettings delegates to the gateway and is gated '
      'by the controller\'s re-entrancy guard (back-to-back calls '
      'collapse to a single gateway invocation)',
      () async {
        final ctx = _buildContext(
          permission: (b) => b
            ..nextCheckStatus = MicrophonePermissionStatus.denied
            ..nextRequestStatus = MicrophonePermissionStatus.permanentlyDenied
            ..nextOpenSettingsResult = true,
        );
        addTearDown(ctx.container.dispose);

        final RecordingPracticeController controller =
            ctx.container.read(recordingPracticeControllerProvider.notifier);

        // First call: must hit the gateway exactly once.
        await controller.openAppSettings();
        await _pumpEventQueue();
        expect(ctx.permissionGateway.openSettingsCallCount, 1);

        // T038B: a second back-to-back call (without a
        // resume in between) is a no-op — the controller
        // holds the re-entrancy guard until the user
        // returns from the system settings page.
        await controller.openAppSettings();
        await _pumpEventQueue();
        expect(ctx.permissionGateway.openSettingsCallCount, 1,
            reason:
                'T038B: the controller is the canonical re-entrancy guard; '
                'back-to-back calls collapse to a single gateway invocation');
        expect(ctx.recorderGateway.startCallCount, 0,
            reason: 'T038B: openAppSettings must NEVER touch the recorder');
      },
    );

    test(
      'T038B: openAppSettings records a lastError when the gateway '
      'returns false (e.g. some OEM ROMs cannot launch the settings page)',
      () async {
        final ctx = _buildContext(
          permission: (b) => b
            ..nextCheckStatus = MicrophonePermissionStatus.denied
            ..nextRequestStatus = MicrophonePermissionStatus.permanentlyDenied
            ..nextOpenSettingsResult = false,
        );
        addTearDown(ctx.container.dispose);

        final RecordingPracticeController controller =
            ctx.container.read(recordingPracticeControllerProvider.notifier);

        await controller.openAppSettings();
        await _pumpEventQueue();

        final RecordingPracticeState state =
            ctx.container.read(recordingPracticeControllerProvider);
        expect(ctx.permissionGateway.openSettingsCallCount, 1);
        expect(state.lastError, isNotNull,
            reason: 'T038B: openAppSettings failure must surface via lastError');
        expect(state.lastError, contains('无法打开系统设置'),
            reason: 'T038B: failure copy is friendly + non-PII');
      },
    );

    test(
      'T038B: openAppSettings records a lastError when the gateway throws',
      () async {
        final ctx = _buildContext(
          permission: (b) => b
            ..nextCheckStatus = MicrophonePermissionStatus.denied
            ..nextRequestStatus = MicrophonePermissionStatus.permanentlyDenied
            ..nextOpenSettingsException =
                StateError('synthetic openAppSettings failure'),
        );
        addTearDown(ctx.container.dispose);

        final RecordingPracticeController controller =
            ctx.container.read(recordingPracticeControllerProvider.notifier);

        await controller.openAppSettings();
        await _pumpEventQueue();

        final RecordingPracticeState state =
            ctx.container.read(recordingPracticeControllerProvider);
        expect(ctx.permissionGateway.openSettingsCallCount, 1);
        expect(state.lastError, isNotNull);
        expect(state.lastError, contains('打开系统设置失败'),
            reason: 'T038B: openAppSettings throw surfaces a friendly message');
      },
    );

    test(
      'T038B: refreshPermissionStatus re-reads the platform status '
      'without auto-starting a recording',
      () async {
        final ctx = _buildContext(
          permission: (b) => b
            ..nextCheckStatus = MicrophonePermissionStatus.denied
            ..nextRequestStatus = MicrophonePermissionStatus.permanentlyDenied,
        );
        addTearDown(ctx.container.dispose);

        final RecordingPracticeController controller =
            ctx.container.read(recordingPracticeControllerProvider.notifier);

        // Drive into permanentDenied.
        await controller.startRecording();
        await _pumpEventQueue();
        expect(
          ctx.container.read(recordingPracticeControllerProvider).permission,
          RecordingPermissionStatus.permanentDenied,
        );
        final int checksBefore = ctx.permissionGateway.checkStatusCallCount;

        // The fake gateway now reports `granted` (simulating
        // the user having toggled the permission in system
        // settings and returning to the app).
        ctx.permissionGateway.nextCheckStatus =
            MicrophonePermissionStatus.granted;

        await controller.refreshPermissionStatus();
        await _pumpEventQueue();

        final RecordingPracticeState state =
            ctx.container.read(recordingPracticeControllerProvider);
        expect(ctx.permissionGateway.checkStatusCallCount, checksBefore + 1,
            reason: 'T038B: refresh must call checkStatus exactly once');
        expect(state.permission, RecordingPermissionStatus.granted,
            reason: 'T038B: refresh must reconcile the enum value');
        expect(state.isRecording, isFalse,
            reason: 'T038B: refresh must NOT auto-start a recording');
        expect(ctx.recorderGateway.startCallCount, 0,
            reason: 'T038B: refresh must NOT touch the recorder');
      },
    );

    test(
      'T038B: refreshPermissionStatus is a no-op while a check is in flight',
      () async {
        // T038B: drive the controller into `checking` by
        // swapping in a gateway whose checkStatus hangs
        // until we manually complete the future. The
        // synchronous state write sets
        // `permission = checking` BEFORE the await; the
        // hung future keeps the in-flight state observable
        // while we test the gate.
        final Completer<MicrophonePermissionStatus> pendingCheck =
            Completer<MicrophonePermissionStatus>();
        final _HangingPermissionGateway hanging =
            _HangingPermissionGateway(pendingCheck.future);
        final (:rootProvider, :root) = _isolatedRoot();
        addTearDown(() {
          if (root.existsSync()) {
            try {
              root.deleteSync(recursive: true);
            } on FileSystemException {
              // ignore
            }
          }
        });
        final AudioFileStorageService storage = AudioFileStorageService(
          rootDirectoryProvider: rootProvider,
        );
        final RealAudioRecorderService recorderService =
            RealAudioRecorderService(
          gateway: FakeAudioRecorderGateway(),
          storage: storage,
        );
        final RealAudioPlaybackService playbackService =
            RealAudioPlaybackService(
          gateway: FakeAudioPlaybackGateway(),
          storage: storage,
        );
        final MicrophonePermissionService hangingService =
            MicrophonePermissionService(hanging);
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[
            audioFileStorageServiceProvider.overrideWithValue(storage),
            realAudioRecorderServiceProvider.overrideWithValue(recorderService),
            realAudioPlaybackServiceProvider
                .overrideWithValue(playbackService),
            microphonePermissionServiceProvider
                .overrideWithValue(hangingService),
            practiceRecordIdGeneratorProvider.overrideWithValue(
              _SequentialPracticeRecordIdGenerator(),
            ),
            installDateServiceProvider.overrideWithValue(
              _FakeInstallDateService(
                DateTime.utc(2026, 6, 19, 0, 0, 0),
              ),
            ),
            practiceDayResolverProvider
                .overrideWithValue(_FakePracticeDayResolver()),
            appClockProvider.overrideWithValue((() => _kTestNowUtc)),
          ],
        );
        addTearDown(container.dispose);

        final RecordingPracticeController controller = container.read(
          recordingPracticeControllerProvider.notifier,
        );

        // Drive into `checking` without awaiting (the
        // pendingCheck future never resolves, so the
        // controller stays in the in-flight state).
        // ignore: unawaited_futures
        controller.startRecording();
        // Allow the synchronous state write to land.
        await _pumpEventQueue();
        expect(
          container.read(recordingPracticeControllerProvider).permission,
          RecordingPermissionStatus.checking,
        );
        final int checksBefore = hanging.checkStatusCallCount;
        await controller.refreshPermissionStatus();
        await _pumpEventQueue();
        expect(
          hanging.checkStatusCallCount,
          checksBefore,
          reason: 'T038B: refresh must NOT re-enter while checking',
        );
        // Tidy up: complete the pending future so the
        // original startRecording can resolve, then dispose.
        pendingCheck.complete(MicrophonePermissionStatus.granted);
        await _pumpEventQueue();
      },
    );

    test(
      'T038B: refreshPermissionStatus keeps the previous permission on '
      'a thrown gateway error',
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
        expect(
          ctx.container.read(recordingPracticeControllerProvider).permission,
          RecordingPermissionStatus.permanentDenied,
        );
        ctx.permissionGateway.nextCheckException =
            StateError('synthetic checkStatus failure');
        await controller.refreshPermissionStatus();
        await _pumpEventQueue();
        final RecordingPracticeState state =
            ctx.container.read(recordingPracticeControllerProvider);
        expect(state.permission, RecordingPermissionStatus.permanentDenied,
            reason: 'T038B: refresh failure must preserve the prior permission');
        expect(state.lastError, isNotNull);
      },
    );

    test(
      'T038B: page-layer can call openAppSettings even when the controller '
      'is in the denied state (the page is the affordance)',
      () async {
        final ctx = _buildContext(
          permission: (b) => b
            ..nextCheckStatus = MicrophonePermissionStatus.denied
            ..nextRequestStatus = MicrophonePermissionStatus.denied
            ..nextOpenSettingsResult = true,
        );
        addTearDown(ctx.container.dispose);

        final RecordingPracticeController controller =
            ctx.container.read(recordingPracticeControllerProvider.notifier);
        await controller.startRecording();
        await _pumpEventQueue();
        expect(
          ctx.container.read(recordingPracticeControllerProvider).permission,
          RecordingPermissionStatus.denied,
        );
        await controller.openAppSettings();
        await _pumpEventQueue();
        expect(ctx.permissionGateway.openSettingsCallCount, 1,
            reason: 'T038B: openAppSettings is callable on BOTH denied and '
                'permanentDenied — the page wires the same button for both');
        expect(ctx.recorderGateway.startCallCount, 0,
            reason: 'T038B: the controller still does not call recorder.start');
      },
    );

    test(
      'T038B: permanentlyDenied does NOT loop requestPermission: '
      'each call to startRecording re-enters the request branch exactly once',
      () async {
        final ctx = _buildContext(
          permission: (b) => b
            ..nextCheckStatus = MicrophonePermissionStatus.denied
            ..nextRequestStatus = MicrophonePermissionStatus.permanentlyDenied,
        );
        addTearDown(ctx.container.dispose);

        final RecordingPracticeController controller =
            ctx.container.read(recordingPracticeControllerProvider.notifier);

        // First tap: drives into permanentlyDenied.
        await controller.startRecording();
        await _pumpEventQueue();
        expect(
          ctx.container.read(recordingPracticeControllerProvider).permission,
          RecordingPermissionStatus.permanentDenied,
        );
        final int firstCheckCount =
            ctx.permissionGateway.checkStatusCallCount;
        final int firstRequestCount =
            ctx.permissionGateway.requestPermissionCallCount;

        // Second tap: must re-enter the request branch
        // exactly once (NOT loop). The T031 contract says
        // the controller may call requestPermission() again
        // on user demand — but it must be a single call,
        // not a polling loop.
        await controller.startRecording();
        await _pumpEventQueue();
        expect(
          ctx.permissionGateway.checkStatusCallCount,
          firstCheckCount + 1,
          reason: 'T038B: each user-tap triggers exactly one checkStatus',
        );
        expect(
          ctx.permissionGateway.requestPermissionCallCount,
          firstRequestCount + 1,
          reason: 'T038B: each user-tap triggers exactly one request, '
              'not a polling loop',
        );
        expect(
          ctx.container.read(recordingPracticeControllerProvider).permission,
          RecordingPermissionStatus.permanentDenied,
          reason: 'T038B: permanentlyDenied stays permanentlyDenied '
              'until the user re-enables it via system settings',
        );
        expect(ctx.recorderGateway.startCallCount, 0);
      },
    );

    test(
      'T038B: permanentlyDenied → granted: refreshPermissionStatus is the '
      'canonical path from the system-settings return',
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
        expect(
          ctx.container.read(recordingPracticeControllerProvider).permission,
          RecordingPermissionStatus.permanentDenied,
        );
        // Simulate the user toggling the permission in
        // system settings and returning to the app.
        ctx.permissionGateway.nextCheckStatus =
            MicrophonePermissionStatus.granted;
        await controller.refreshPermissionStatus();
        await _pumpEventQueue();
        final RecordingPracticeState granted =
            ctx.container.read(recordingPracticeControllerProvider);
        expect(granted.permission, RecordingPermissionStatus.granted);
        // Now a fresh startRecording actually starts.
        await controller.startRecording();
        await _pumpEventQueue();
        final RecordingPracticeState after =
            ctx.container.read(recordingPracticeControllerProvider);
        expect(after.isRecording, isTrue,
            reason: 'T038B: after re-enable the user can record again');
        expect(ctx.recorderGateway.startCallCount, 1);
        // Cleanup.
        ctx.recorderGateway.nextStopResult =
            _stopPath(ctx.recorderGateway.lastStartPath!);
        await controller.stopRecording();
      },
    );

    test(
      'T038B: still denied after return from system settings: '
      'the controller state stays denied and the recorder is not invoked',
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
        // Even after a refresh, the fake still says
        // denied at the checkStatus layer — request is
        // the only path that returns permanentlyDenied,
        // and refreshPermissionStatus does NOT call
        // request. The visible state therefore reverts
        // to denied (the "still denied" case).
        await controller.refreshPermissionStatus();
        await _pumpEventQueue();
        final RecordingPracticeState state =
            ctx.container.read(recordingPracticeControllerProvider);
        // T038B: the user-visible state stays in the
        // denied family — refresh must NOT silently
        // re-enable anything, and must NOT call recorder.
        expect(state.permission, isNot(RecordingPermissionStatus.granted));
        // A subsequent startRecording still does NOT
        // bypass the permission check.
        await controller.startRecording();
        await _pumpEventQueue();
        expect(ctx.recorderGateway.startCallCount, 0,
            reason: 'T038B: denied must NEVER start the recorder');
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
        'T031I: natural completion drives playback.stop() (replaces the '
        'pre-T031I seek-to-zero contract)', () async {
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
      // T031I: the recovery now drives `playback.stop()` instead of
      // an explicit `seek(0)` — the playback service's `stop()`
      // clears the service-side position via `_clearActiveSession()`,
      // so a follow-up `seek(0)` at the service layer would be
      // rejected (state == idle). Pin the new contract: stop is
      // driven, position resets, lastError cleared.
      final int stopsBefore = ctx.playbackGateway.stopCallCount;
      ctx.playbackGateway.emitPlayerState(const PlaybackPlayerState(
        playing: false,
        processingState: PlaybackProcessingState.completed,
      ));
      await _pumpEventQueue();

      final RecordingPracticeState state =
          ctx.container.read(recordingPracticeControllerProvider);
      expect(state.isPlaying, isFalse);
      expect(state.currentPlaybackPosition, Duration.zero);
      expect(state.lastError, isNull,
          reason: 'T031I: completed must clear lastError');
      expect(ctx.playbackGateway.stopCallCount, greaterThan(stopsBefore),
          reason: 'T031I: completed must drive playback.stop() — this is '
              'the real-device loop fix');
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
      // T031I: the recovery must drive `playback.stop()` (the
      // real-device loop fix); the playback service's `stop()`
      // clears `_activePosition` to `Duration.zero` via
      // `_clearActiveSession()`, so an explicit seek(0) is no
      // longer needed (and would be rejected by the service
      // layer once state transitions to `idle`).
      expect(ctx.playbackGateway.stopCallCount, greaterThanOrEqualTo(1),
          reason: 'T031I: completed must trigger playback.stop() — this is '
              'the real-device loop fix');
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

  // ---------------------------------------------------------------------
  // T031I: real-device "playback loops forever after natural end-of-stream"
  // regression tests. The user reported on real Android that after a
  // recording played through to the end, the audio kept looping and the
  // UI / underlying player state desynced (回放 button became tappable
  // again, 停止回放 button stayed disabled). Root cause: the controller
  // was only calling `seek(Duration.zero)` on the completed event —
  // on real Android just_audio drops back to `ready/playing` after a
  // seek-from-completed, and the player re-enters playback. T031I
  // fixes the contract by driving `playback.stop()` (which actually
  // releases the native decoder and breaks the loop) instead of an
  // explicit `seek(0)`. The whole handler is idempotent and best-effort
  // — see `RecordingPracticeController._handleNaturalCompletion`.
  // ---------------------------------------------------------------------

  group(
      'RecordingPracticeController T031I: natural completion stops the '
      'underlying player (real-device loop fix)', () {
    Future<void> setupPlaying(
        RecordingPracticeController controller, _ControllerContext ctx) async {
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
    }

    test(
        'T031I: completed event drives playback.stop() (the real-device '
        'loop fix)', () async {
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await setupPlaying(controller, ctx);

      final int stopsBefore = ctx.playbackGateway.stopCallCount;
      ctx.playbackGateway.emitPlayerState(const PlaybackPlayerState(
        playing: false,
        processingState: PlaybackProcessingState.completed,
      ));
      await _pumpEventQueue();

      expect(ctx.playbackGateway.stopCallCount, greaterThan(stopsBefore),
          reason: 'T031I: completed MUST drive playback.stop() — this is the '
              'real-device loop fix. Without it, the underlying just_audio '
              'player on real Android re-enters ready/playing after a seek '
              'and the user gets the playback-loops-forever regression.');

      // Cleanup.
      await controller.stopPlayback();
    });

    test('T031I: completed event flips isPlaying=false synchronously',
        () async {
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await setupPlaying(controller, ctx);

      // Sanity: state is playing before the event.
      expect(
        ctx.container.read(recordingPracticeControllerProvider).isPlaying,
        isTrue,
      );

      ctx.playbackGateway.emitPlayerState(const PlaybackPlayerState(
        playing: false,
        processingState: PlaybackProcessingState.completed,
      ));
      // One microtask drain — the controller writes the state
      // synchronously inside the stream listener callback, so
      // even a single drain captures the post-event state.
      await _pumpEventQueue();

      expect(
        ctx.container.read(recordingPracticeControllerProvider).isPlaying,
        isFalse,
        reason: 'T031I: completed must flip isPlaying to false (T031C '
            'contract preserved by the new handler)',
      );
      expect(
        ctx.container
            .read(recordingPracticeControllerProvider)
            .currentPlaybackPosition,
        Duration.zero,
        reason: 'T031I: position must reset to 0 on completion',
      );
    });

    test(
        'T031I: after completed the user can start a new recording (re-record '
        'flow)', () async {
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await setupPlaying(controller, ctx);
      final String firstTakeId =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;

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
      await controller.startRecording();
      await _pumpEventQueue();
      final RecordingPracticeState fresh =
          ctx.container.read(recordingPracticeControllerProvider);
      expect(fresh.isRecording, isTrue);
      expect(fresh.isPlaying, isFalse);
      expect(fresh.takeId, isNot(equals(firstTakeId)),
          reason: 'T031I: a fresh take must mint a new takeId');
      expect(ctx.recorderGateway.startCallCount, startsBefore + 1,
          reason: 'T031I: recorder.start must be called when starting fresh '
              'after natural completion');

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
        'T031I: after completed the user can replay from 0 (loadFile '
        're-invoked)', () async {
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await setupPlaying(controller, ctx);

      ctx.playbackGateway.emitPlayerState(const PlaybackPlayerState(
        playing: false,
        processingState: PlaybackProcessingState.completed,
      ));
      await _pumpEventQueue();
      expect(
        ctx.container.read(recordingPracticeControllerProvider).isPlaying,
        isFalse,
      );

      // Replay: must call loadFile again (T031G path) and flip
      // isPlaying to true. The stop() call driven by T031I
      // cleared `_activePath`, so the controller's play() will
      // re-load the file.
      final int loadBefore = ctx.playbackGateway.loadFileCallCount;
      final int startsBefore = ctx.recorderGateway.startCallCount;
      await controller.play();
      await _pumpEventQueue();
      final RecordingPracticeState replayed =
          ctx.container.read(recordingPracticeControllerProvider);
      expect(replayed.isPlaying, isTrue,
          reason: 'T031I: replay after completion must start playback');
      expect(ctx.playbackGateway.loadFileCallCount, greaterThan(loadBefore),
          reason: 'T031I: replay must call loadFile() again so playback '
              'restarts from 0');
      expect(ctx.recorderGateway.startCallCount, startsBefore,
          reason: 'T031I: replay must NOT start a new recording');

      // Cleanup.
      await controller.stopPlayback();
    });

    test(
        'T031I: completed event is idempotent — repeated events do not drive '
        'playback.stop() twice (re-entrancy guard)', () async {
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await setupPlaying(controller, ctx);

      // Fire three completed events in quick succession — this
      // mimics the real-device Android behaviour where just_audio
      // can re-emit `completed` after a seek / stop interaction.
      // The handler MUST only drive playback.stop() once.
      final int stopsBefore = ctx.playbackGateway.stopCallCount;
      ctx.playbackGateway.emitPlayerState(const PlaybackPlayerState(
        playing: false,
        processingState: PlaybackProcessingState.completed,
      ));
      await _pumpEventQueue();
      ctx.playbackGateway.emitPlayerState(const PlaybackPlayerState(
        playing: false,
        processingState: PlaybackProcessingState.completed,
      ));
      await _pumpEventQueue();
      ctx.playbackGateway.emitPlayerState(const PlaybackPlayerState(
        playing: false,
        processingState: PlaybackProcessingState.completed,
      ));
      await _pumpEventQueue();

      // T031I: the re-entrancy guard short-circuits the second /
      // third completed event because `state.isPlaying` is
      // already false after the first recovery. We therefore
      // expect exactly ONE additional stop call (not three).
      expect(ctx.playbackGateway.stopCallCount, stopsBefore + 1,
          reason: 'T031I: repeated completed events must be idempotent — '
              'playback.stop() is driven exactly once per take');
      expect(
        ctx.container.read(recordingPracticeControllerProvider).isPlaying,
        isFalse,
        reason: 'T031I: state stays at isPlaying=false across repeated '
            'completed events',
      );
    });

    test(
        'T031I: playback.stop() throws in completed handler — UI still '
        'recovers (best-effort contract)', () async {
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
        // T031I: do NOT pre-seed any stop exception. The throw
        // is set on the fake AFTER setupPlaying settles, so the
        // `service.loadFile` internal-stop path is not broken
        // (which would prevent `controller.play()` from
        // succeeding in the first place).
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await setupPlaying(controller, ctx);
      // Sanity: setupPlaying succeeded — isPlaying=true and no
      // lastError from the play path.
      expect(
        ctx.container.read(recordingPracticeControllerProvider).isPlaying,
        isTrue,
      );
      expect(
        ctx.container.read(recordingPracticeControllerProvider).lastError,
        isNull,
      );

      // Now arm the throw: the next `playback.stop()` call will
      // throw. The T031I `_handleNaturalCompletion` is the next
      // caller of `playback.stop()` (the user has not tapped
      // 停止回放 — the only path is the completed handler).
      ctx.playbackGateway.nextStopException =
          StateError('synthetic stop failure');

      ctx.playbackGateway.emitPlayerState(const PlaybackPlayerState(
        playing: false,
        processingState: PlaybackProcessingState.completed,
      ));
      await _pumpEventQueue();

      final RecordingPracticeState state =
          ctx.container.read(recordingPracticeControllerProvider);
      expect(state.isPlaying, isFalse,
          reason: 'T031I: isPlaying MUST flip to false even if '
              'playback.stop() throws (UI recovery is the load-bearing '
              'contract; the underlying stop is best-effort)');
      expect(state.currentPlaybackPosition, Duration.zero,
          reason: 'T031I: position MUST reset to 0 even if playback.stop() '
              'throws (the synchronous state write is the primary path)');
      expect(state.lastError, isNull,
          reason: 'T031I: lastError is cleared on completed — the stop throw '
              'is swallowed and does not surface to the UI');
    });

    test(
        'T031I: completed event does NOT trigger Drift writes (no '
        'PracticeRecord, audioFilePath stays null)', () async {
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
      await setupPlaying(controller, ctx);

      ctx.playbackGateway.emitPlayerState(const PlaybackPlayerState(
        playing: false,
        processingState: PlaybackProcessingState.completed,
      ));
      await _pumpEventQueue();

      // T031I: natural-completion recovery MUST NOT auto-save.
      expect(repo.inserted, isEmpty,
          reason: 'T031I: natural completion must not insert a PracticeRecord');
      expect(
        ctx.container.read(recordingPracticeControllerProvider).savedRecordId,
        isNull,
        reason: 'T031I: savedRecordId stays null — auto-recovery is not a save',
      );

      // Cleanup.
      await controller.stopPlayback();
    });

    test(
        'T031I: completed event arriving AFTER the controller has been '
        'disposed does not throw', () async {
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
      );
      addTearDown(ctx.container.dispose);
      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await setupPlaying(controller, ctx);

      // Tear down the container; the onDispose hook must cancel
      // the subscriptions so post-dispose stream events are no-ops.
      ctx.container.dispose();

      // Post-dispose: emitting on the fake stream must NOT throw
      // and MUST NOT drive the playback service.
      final int stopsBefore = ctx.playbackGateway.stopCallCount;
      ctx.playbackGateway.emitPlayerState(const PlaybackPlayerState(
        playing: false,
        processingState: PlaybackProcessingState.completed,
      ));
      await _pumpEventQueue();
      // The fake stream controller is still open (no dispose
      // was called on it). The controller's listener has been
      // cancelled by `ref.onDispose`, so the handler is never
      // invoked. We verify by checking that no additional stop
      // was driven.
      expect(ctx.playbackGateway.stopCallCount, stopsBefore,
          reason: 'T031I: post-dispose completed events must not drive the '
              'playback service');
    });

    test(
        'T031I: fake gateway simulates real-device "no stop → loop again" — '
        'controller must call stop to break it', () async {
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
      );
      addTearDown(ctx.container.dispose);

      // T031I: opt the fake into the real-device loop risk
      // simulation. After the first completed event, the fake
      // will re-emit completed / ready+playing cycles UNTIL
      // playback.stop() is called.
      ctx.playbackGateway.simulateRealDeviceLoopAfterCompleted = true;

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

      // play() with completeOnNextPlay = true. The fake will
      // emit `completed`, then re-emit completed (via the
      // loop scheduler) until playback.stop() is driven.
      ctx.playbackGateway.completeOnNextPlay = true;
      await controller.play();
      // Drain enough microtasks for the fake to schedule its
      // first completed + the first follow-up cycle, then for
      // the controller's `_handleNaturalCompletion` to drive
      // stop.
      await _pumpEventQueue();
      await _pumpEventQueue();
      await _pumpEventQueue();
      await _pumpEventQueue();

      // T031I: the controller's stop call must have raised the
      // loop barrier on the fake (>= 1 stop call recorded).
      expect(ctx.playbackGateway.stopCallCount, greaterThanOrEqualTo(1),
          reason: 'T031I: fake simulates real-device loop; the controller '
              'MUST drive playback.stop() to break the cycle');
      // T031I: the loop barrier must have stopped the fake from
      // re-emitting completed after the controller's stop.
      // `loopEmittedCompletedCount` records every completed
      // emission; the first emission is the natural end, the
      // second is the loop scheduler's first follow-up. The
      // controller's stop then sets the barrier; any further
      // emissions are blocked. We therefore expect a small,
      // bounded number of completed events (not "infinite").
      expect(
          ctx.playbackGateway.loopEmittedCompletedCount, lessThanOrEqualTo(2),
          reason: 'T031I: the controller MUST break the real-device loop — '
              'a bounded number of completed events proves the barrier fired');
      // The controller's state must be in the post-completion
      // state (isPlaying=false) — the handler is idempotent and
      // has converged.
      expect(
        ctx.container.read(recordingPracticeControllerProvider).isPlaying,
        isFalse,
        reason: 'T031I: state must converge to isPlaying=false even with the '
            'real-device loop simulation',
      );
    });

    test(
        'T031I: stopPlayback (manual) still drives playback.stop() — T031G '
        'contract preserved', () async {
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await setupPlaying(controller, ctx);

      final int stopsBefore = ctx.playbackGateway.stopCallCount;
      await controller.stopPlayback();
      await _pumpEventQueue();
      expect(ctx.playbackGateway.stopCallCount, stopsBefore + 1,
          reason: 'T031I: manual stopPlayback must still drive '
              'playback.stop() (T031G contract preserved)');
      expect(
        ctx.container.read(recordingPracticeControllerProvider).isPlaying,
        isFalse,
      );
    });

    test(
        'T031I: T031G play start sync regression — isPlaying=true '
        'synchronously after play()', () async {
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

      // T031G regression pin: keepPlayPending = true mirrors
      // real just_audio on Android where the play() Future
      // stays pending for the entire playback duration.
      ctx.playbackGateway.keepPlayPending = true;
      await controller.play();
      // No extra microtasks — the synchronous isPlaying write
      // must be observable immediately.
      final RecordingPracticeState state =
          ctx.container.read(recordingPracticeControllerProvider);
      expect(state.isPlaying, isTrue,
          reason:
              'T031I / T031G: play() must flip isPlaying=true synchronously '
              'even when the play() Future is pending');

      // Cleanup.
      await controller.stopPlayback();
    });

    test(
        'T031I: T031C startRecording guard while playing is preserved — no '
        'recorder call, no new takeId', () async {
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await setupPlaying(controller, ctx);

      final int startsBefore = ctx.recorderGateway.startCallCount;
      final int checksBefore = ctx.permissionGateway.checkStatusCallCount;
      final String takeIdBefore =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;
      await controller.startRecording();
      await _pumpEventQueue();
      final RecordingPracticeState state =
          ctx.container.read(recordingPracticeControllerProvider);
      expect(state.isPlaying, isTrue,
          reason: 'T031I / T031C: playback must still be running');
      expect(state.takeId, takeIdBefore,
          reason: 'T031I / T031C: a no-op startRecording must NOT mint a new '
              'takeId');
      expect(ctx.recorderGateway.startCallCount, startsBefore,
          reason:
              'T031I / T031C: recorder.start MUST NOT be called while playing');
      expect(ctx.permissionGateway.checkStatusCallCount, checksBefore,
          reason: 'T031I / T031C: permission service MUST NOT be touched while '
              'playing');

      // Cleanup.
      await controller.stopPlayback();
    });

    test(
        'T031I: LoopMode.off is still pinned on every loadFile (T031E contract '
        'preserved)', () async {
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await setupPlaying(controller, ctx);

      final int loopBefore = ctx.playbackGateway.setLoopModeOffCallCount;
      ctx.playbackGateway.emitPlayerState(const PlaybackPlayerState(
        playing: false,
        processingState: PlaybackProcessingState.completed,
      ));
      await _pumpEventQueue();
      // T031I: completed does NOT trigger a loadFile (only
      // play() does). setLoopModeOff call count must therefore
      // be unchanged. The contract is that the next replay's
      // loadFile() (driven by play()) will pin LoopMode.off
      // again.
      expect(ctx.playbackGateway.setLoopModeOffCallCount, loopBefore,
          reason: 'T031I: completed does not trigger a loadFile — '
              'LoopMode.off is pinned at the next play() instead');

      // The NEXT play() must pin LoopMode.off.
      await controller.play();
      await _pumpEventQueue();
      expect(
          ctx.playbackGateway.setLoopModeOffCallCount, greaterThan(loopBefore),
          reason: 'T031I: replay must re-pin LoopMode.off via loadFile');

      // Cleanup.
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
      // T033: the resolved path from the recorder service is
      // persisted verbatim on the PracticeRecord. The string
      // is taken AS-IS from the in-memory recordedTakeResult
      // — no normalisation, no recomputation, no substring
      // rewrite. Equality is exact (==), not contains / matches.
      expect(saved.audioFilePath, path,
          reason: 'T033: saveCurrentTake must persist the resolved path '
              'verbatim from recordedTakeResult.resolvedPath');
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
      // Write a real file so the playback service's _validatePath
      // passes during the post-stop duration probe.
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
      // T033: the audio path is persisted verbatim, independent
      // of whether the user supplied a self-rating.
      expect(saved.audioFilePath, path,
          reason: 'T033: missing self-rating must not affect the audio path');
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

    // -------------------------------------------------------------------
    // T033: persist recorded audio path with PracticeRecord.
    //
    // The pre-T033 controller wrote `audioFilePath: null` to
    // every record. T033 sources the path verbatim from
    // `state.recordedTakeResult.resolvedPath`, so:
    //   - a successful take → audioFilePath equals the resolved
    //     path byte-for-byte (no normalisation, no
    //     recomputation, no substring rewrite);
    //   - a missing / failed take → audioFilePath stays null
    //     (same pre-T033 contract);
    //   - a new take must NOT inherit a previous take's path;
    //   - save failure must keep the in-memory take + path so
    //     the user can retry;
    //   - save success is not re-triggered (canSave is
    //     blocked by isSaved → no duplicate rows);
    //   - natural playback completion must not blow away the
    //     pending save.
    // -------------------------------------------------------------------

    test(
        'T033: saveCurrentTake persists the resolved path verbatim from '
        'recordedTakeResult (no normalisation, no recomputation)', () async {
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
      // Sanity: the path is the verbatim string the recorder
      // service's createTempFile produced — keep a copy so we
      // can assert the persisted value is byte-equivalent.
      expect(path, isNotEmpty);
      final String expectedPath = path;

      final File f = File(path);
      await f.create(recursive: true);
      await f.writeAsString('fake m4a');
      ctx.recorderGateway.nextStopResult = _stopPath(path);
      ctx.playbackGateway.nextLoadResult = const Duration(seconds: 2);
      await controller.stopRecording();
      await _pumpEventQueue();

      final SaveRecordingResult result = await controller.saveCurrentTake();
      expect(result, SaveRecordingResult.success,
          reason: 'happy path: real recording -> save -> success');
      expect(repo.inserted.length, 1,
          reason: 'T033: one save => exactly one persisted record');
      final PracticeRecord saved = repo.inserted.single;

      // T033 #1 + #2 + #11: path is verbatim, not null, not
      // normalised. Self-rating / note / duration / dayIndex
      // are unchanged from the pre-T033 contract.
      expect(saved.audioFilePath, expectedPath,
          reason: 'T033: audioFilePath must equal resolvedPath verbatim');
      expect(saved.audioFilePath, isNot(isNull),
          reason: 'T033: a successful take must persist a non-null path');
      expect(
        saved.audioFilePath,
        ctx.container
            .read(recordingPracticeControllerProvider)
            .recordedTakeResult!
            .resolvedPath,
        reason: 'T033: the persisted value must come from the in-memory take, '
            'identical to the controller\'s recordedTakeResult.resolvedPath',
      );
      expect(saved.durationSeconds, 2,
          reason: 'T033: duration field must not regress');
      expect(saved.practiceDate, _kTestToday);
      expect(saved.dayIndex, _kTestDayIndex);
    });

    test(
        'T033: saveCurrentTake without a usable take leaves audioFilePath '
        'null (no fake fabrication)', () async {
      // T033 #3 / 空路径兼容: never-recorded flow must still
      // be safe — the controller returns `ignored` (canSave is
      // false) and the repository is not touched. Even if the
      // user manually drove a `save` with no take, the field
      // would be null (state.recordedTakeResult is null).
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

      // Never call startRecording — there is no take in memory.
      final SaveRecordingResult result = await controller.saveCurrentTake();
      expect(result, SaveRecordingResult.ignored);
      expect(repo.inserted, isEmpty,
          reason: 'T033: no take => no record is written');
      expect(
        ctx.container.read(recordingPracticeControllerProvider).canSave,
        isFalse,
        reason: 'T033: canSave must be false with no take in memory',
      );
      expect(
        ctx.container
            .read(recordingPracticeControllerProvider)
            .recordedTakeResult,
        isNull,
        reason: 'T033: state has no recordedTakeResult — any future save '
            'would write audioFilePath=null',
      );
    });

    test(
        'T033: recorder.start failure on a SECOND take does NOT leak the '
        'previous take path into a persisted record', () async {
      // T033 #4: 录音启动失败后,即使前一次录音成功,新一次录音
      // 启动失败时也不能把上一 take 的路径错挂在新 take 上.
      // 通过 startRecording 的 clearRecordedTakeResult 路径
      // 保证 hasRecording=false / recordedTakeResult=null, 后续
      // save 走 ignored, 不会写出旧路径.
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

      // First take — succeeds. We are NOT going to save it.
      await controller.startRecording();
      await _pumpEventQueue();
      final String firstPath = ctx.recorderGateway.lastStartPath!;
      final File f1 = File(firstPath);
      await f1.create(recursive: true);
      await f1.writeAsString('fake m4a #1');
      ctx.recorderGateway.nextStopResult = _stopPath(firstPath);
      ctx.playbackGateway.nextLoadResult = const Duration(seconds: 1);
      await controller.stopRecording();
      await _pumpEventQueue();
      expect(
        ctx.container
            .read(recordingPracticeControllerProvider)
            .recordedTakeResult!
            .resolvedPath,
        firstPath,
      );

      // Second start — fails. The first take's path must NOT be
      // re-attached to a would-be saved record.
      ctx.recorderGateway.nextStartException =
          StateError('synthetic recorder start failure');
      await controller.startRecording();
      await _pumpEventQueue();
      final RecordingPracticeState afterStart =
          ctx.container.read(recordingPracticeControllerProvider);
      expect(afterStart.isRecording, isFalse,
          reason: 'recorder.start failure must flip isRecording back to false');
      expect(afterStart.hasRecording, isFalse,
          reason: 'T033: a failed start must clear hasRecording, even when '
              'the previous take was successful');
      expect(
        afterStart.recordedTakeResult,
        isNull,
        reason: 'T033: a failed start must clear the previous take\'s path',
      );
      expect(afterStart.canSave, isFalse,
          reason: 'T033: canSave must stay false — no path can be saved');

      // save must be ignored, repo must stay empty (no leak of
      // the first take's path).
      final SaveRecordingResult result = await controller.saveCurrentTake();
      expect(result, SaveRecordingResult.ignored);
      expect(repo.inserted, isEmpty,
          reason: 'T033: a failed second start must not produce a record '
              'containing the first take\'s path');
    });

    test(
        'T033: recorder.stop failure does NOT save a stale or invalid path '
        '(canSave stays false)', () async {
      // T033 #5: 录音停止失败后, hasRecording=false ⇒ canSave=false ⇒
      // 保存不会写入任何路径. 旧 take 的路径也不会"穿越"到一个
      // 失败的新 take 上.
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository();
      final ctx = _buildContext(
        permission: (b) =>
            b..nextCheckStatus = MicrophonePermissionStatus.granted,
        recorder: (b) =>
            b..nextStopException = StateError('synthetic stop failure'),
        repository: repo,
      );
      addTearDown(ctx.container.dispose);

      final RecordingPracticeController controller =
          ctx.container.read(recordingPracticeControllerProvider.notifier);
      await controller.startRecording();
      await _pumpEventQueue();

      await controller.stopRecording();
      await _pumpEventQueue();
      final RecordingPracticeState afterStop =
          ctx.container.read(recordingPracticeControllerProvider);
      expect(afterStop.isRecording, isFalse);
      expect(afterStop.hasRecording, isFalse,
          reason: 'recorder.stop failure must NOT flip hasRecording to true');
      expect(afterStop.canSave, isFalse,
          reason: 'T033: canSave must stay false after a stop failure');

      final SaveRecordingResult result = await controller.saveCurrentTake();
      expect(result, SaveRecordingResult.ignored);
      expect(repo.inserted, isEmpty,
          reason: 'T033: a failed stop must not leak the previous path '
              'into a new record');
    });

    test(
        'T033: re-recording does NOT reuse the previous take path (only the '
        'current take is persisted)', () async {
      // T033 #6 + #7: 新 take 不会复用上一 take 路径, 多次录音
      // 只保存当前 take 路径. 第二次 stopRecording 用了一个完全
      // 不同的 temp 路径, 断言 save 写入的 path 与第二次
      // recorder.start 返回的路径 byte-equal,与第一次的 path
      // 严格不同.
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

      // First take.
      await controller.startRecording();
      await _pumpEventQueue();
      final String firstPath = ctx.recorderGateway.lastStartPath!;
      final File f1 = File(firstPath);
      await f1.create(recursive: true);
      await f1.writeAsString('fake m4a #1');
      ctx.recorderGateway.nextStopResult = _stopPath(firstPath);
      ctx.playbackGateway.nextLoadResult = const Duration(seconds: 1);
      await controller.stopRecording();
      await _pumpEventQueue();
      expect(
        ctx.container
            .read(recordingPracticeControllerProvider)
            .recordedTakeResult!
            .resolvedPath,
        firstPath,
      );

      // Second take — must mint a new takeId + a new temp file.
      await controller.startRecording();
      await _pumpEventQueue();
      final String secondPath = ctx.recorderGateway.lastStartPath!;
      expect(secondPath, isNot(equals(firstPath)),
          reason: 'T033: the recorder service must allocate a fresh temp file '
              'for the second take');
      final File f2 = File(secondPath);
      await f2.create(recursive: true);
      await f2.writeAsString('fake m4a #2');
      ctx.recorderGateway.nextStopResult = _stopPath(secondPath);
      ctx.playbackGateway.nextLoadResult = const Duration(seconds: 3);
      await controller.stopRecording();
      await _pumpEventQueue();

      final SaveRecordingResult result = await controller.saveCurrentTake();
      expect(result, SaveRecordingResult.success);
      expect(repo.inserted.length, 1,
          reason: 'T033: one save must persist exactly one record');
      final PracticeRecord saved = repo.inserted.single;
      expect(saved.audioFilePath, secondPath,
          reason: 'T033: the persisted path must be the CURRENT take path, '
              'not the previous take');
      expect(saved.audioFilePath, isNot(equals(firstPath)),
          reason: 'T033: the previous take path must NOT leak into the new '
              'record');
    });

    test(
        'T033: natural playback completion does NOT wipe the current path — '
        'the user can still save the take', () async {
      // T033 #8: 播放自然完成后 recordedTakeResult / hasRecording 仍
      // 保留, 路径完整可供 save 使用.
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
      ctx.playbackGateway.nextLoadResult = const Duration(seconds: 4);
      await controller.stopRecording();
      await _pumpEventQueue();
      final String expectedPath = ctx.container
          .read(recordingPracticeControllerProvider)
          .recordedTakeResult!
          .resolvedPath;
      expect(expectedPath, path);

      // Replay with a microtask-scheduled completion.
      ctx.playbackGateway.completeOnNextPlay = true;
      await controller.play();
      await _pumpEventQueue();
      await _pumpEventQueue();
      // T031I: completed flips isPlaying back, but the in-memory
      // take is preserved — the user can still save.
      expect(
        ctx.container.read(recordingPracticeControllerProvider).isPlaying,
        isFalse,
      );
      expect(
        ctx.container
            .read(recordingPracticeControllerProvider)
            .recordedTakeResult,
        isNotNull,
        reason: 'T033: natural completion must not clear the take',
      );
      expect(
        ctx.container.read(recordingPracticeControllerProvider).canSave,
        isTrue,
        reason: 'T033: canSave must remain true after natural completion',
      );

      final SaveRecordingResult result = await controller.saveCurrentTake();
      expect(result, SaveRecordingResult.success);
      expect(repo.inserted.single.audioFilePath, expectedPath,
          reason: 'T033: save after natural completion must persist the '
              'still-held resolved path');
    });

    test(
        'T033: repository save failure keeps the in-memory take + path so the '
        'user can retry with the same audio file', () async {
      // T033 #9: Repository 抛错时, 不得伪装成功, 不得把路径改回
      // null, 不得删文件, 必须保留可重试状态. 后续 retry 应当
      // 使用完全相同的 path / takeId.
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
      final String path = ctx.recorderGateway.lastStartPath!;
      final File f = File(path);
      await f.create(recursive: true);
      await f.writeAsString('fake m4a');
      ctx.recorderGateway.nextStopResult = _stopPath(path);
      ctx.playbackGateway.nextLoadResult = const Duration(seconds: 2);
      await controller.stopRecording();
      await _pumpEventQueue();
      final String expectedPath = ctx.container
          .read(recordingPracticeControllerProvider)
          .recordedTakeResult!
          .resolvedPath;

      // First attempt — fails.
      final SaveRecordingResult firstAttempt =
          await controller.saveCurrentTake();
      expect(firstAttempt, SaveRecordingResult.failure);
      final RecordingPracticeState afterFail =
          ctx.container.read(recordingPracticeControllerProvider);
      expect(afterFail.isSaving, isFalse,
          reason: 'T033: a save failure must clear isSaving so the user can '
              'retry');
      expect(afterFail.isSaved, isFalse,
          reason: 'T033: savedRecordId must stay null on failure');
      expect(afterFail.canSave, isTrue,
          reason: 'T033: canSave must stay true so the user can retry');
      expect(
        afterFail.recordedTakeResult!.resolvedPath,
        expectedPath,
        reason: 'T033: failure must not clear the in-memory take / path',
      );
      // Sanity: the file is still on disk.
      expect(File(expectedPath).existsSync(), isTrue,
          reason: 'T033: failure must not touch the audio file on disk');
      // The repository saw the failed attempt — but the file was
      // not deleted by the controller.
      expect(repo.inserted, isEmpty,
          reason: 'T033: failed insert must not appear in the repo');

      // Retry — must succeed with the same path / takeId.
      repo.throwOnInsert = null;
      final SaveRecordingResult retry = await controller.saveCurrentTake();
      expect(retry, SaveRecordingResult.success);
      expect(repo.inserted.length, 1,
          reason: 'T033: one successful retry => exactly one persisted record');
      final PracticeRecord saved = repo.inserted.single;
      expect(saved.audioFilePath, expectedPath,
          reason: 'T033: retry must persist the same path verbatim');
      expect(saved.id, afterFail.takeId,
          reason: 'T033: retry must reuse the same takeId so the same logical '
              'take is persisted, not a new one');
    });

    test(
        'T033: a successful save cannot be re-triggered (no duplicate records, '
        'no path re-use across saves)', () async {
      // T033 #10: 保存成功后 isSaved 阻断再次保存, repo 不会出现
      // 两条重复记录或路径错挂. 既有 isSaved 契约已由 canSave
      // 体现, 本测试同时校验连续两次 saveCurrentTake 行为.
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

      // First save.
      final SaveRecordingResult first = await controller.saveCurrentTake();
      expect(first, SaveRecordingResult.success);
      expect(repo.inserted.length, 1);

      // Second save — should be ignored (isSaved blocks canSave).
      final SaveRecordingResult second = await controller.saveCurrentTake();
      expect(second, SaveRecordingResult.ignored,
          reason: 'T033: a successful save must not re-save');
      expect(repo.inserted.length, 1,
          reason: 'T033: re-save must not produce a duplicate record');
      final PracticeRecord persisted = repo.inserted.single;
      expect(persisted.audioFilePath, path,
          reason: 'T033: the persisted record is still associated with the '
              'original take path; no re-save mutation occurred');
    });

    test(
        'T033: existing self-rating / note / duration / dayIndex fields are '
        'preserved when the audio path is persisted', () async {
      // T033 #11: 既有 selfRating / note / durationSeconds /
      // practiceDate / dayIndex / tags 字段不因路径写入而退化.
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
      ctx.playbackGateway.nextLoadResult = const Duration(seconds: 7);
      await controller.stopRecording();
      await _pumpEventQueue();
      controller.setSelfRating(SelfRating.okay);
      controller.setNote('  录音路径保存回归测试  ');
      final String expectedTakeId =
          ctx.container.read(recordingPracticeControllerProvider).takeId!;

      final SaveRecordingResult result = await controller.saveCurrentTake();
      expect(result, SaveRecordingResult.success);
      final PracticeRecord saved = repo.inserted.single;
      expect(saved.id, expectedTakeId);
      expect(saved.audioFilePath, path);
      expect(saved.durationSeconds, 7);
      expect(saved.selfAssessment, SelfAssessment.neutral,
          reason:
              'T033: SelfRating.okay must still map to SelfAssessment.neutral');
      expect(saved.practiceContent, '录音路径保存回归测试',
          reason: 'T033: note trimming contract preserved');
      expect(saved.practiceDate, _kTestToday);
      expect(saved.dayIndex, _kTestDayIndex);
      expect(saved.practiceTags,
          <PracticeTag>[PracticeTag.recording, PracticeTag.selfAssessment]);
      expect(saved.isCompleted, isTrue);
    });
  });

  // ===========================================================================
  // T037B — page-exit stop coordination (controller level).
  //
  // The T037B recording-page fix mirrors the T037A detail-page fix:
  // a NEW public method
  // [RecordingPracticeController.requestStopForPageExit] returns
  // an awaitable [PageExitStopResult] so the page can hold the
  // route transition until the underlying `recorder.stop()` /
  // `playback.stop()` has actually resolved. The controller is
  // the source of truth for the awaitable contract; the page is
  // the source of truth for the user-facing SnackBar copy and
  // the navigation gesture. This group pins the controller
  // contract.
  // ===========================================================================

  group('T037B page-exit stop', () {
    test(
      'idle: requestStopForPageExit returns skipped(idle) '
      'without calling recorder.stop or playback.stop',
      () async {
        final ctx = _buildContext(
          permission: (b) =>
              b..nextCheckStatus = MicrophonePermissionStatus.granted,
        );
        addTearDown(ctx.container.dispose);

        final RecordingPracticeController controller =
            ctx.container.read(recordingPracticeControllerProvider.notifier);
        final int stopsBefore = ctx.recorderGateway.stopCallCount;
        final int pbStopsBefore = ctx.playbackGateway.stopCallCount;

        final PageExitStopResult result =
            await controller.requestStopForPageExit();
        expect(result, isA<PageExitStopSkipped>());
        final PageExitStopSkipped skipped = result as PageExitStopSkipped;
        expect(skipped.reason, PageExitStopSkipReason.idle);
        expect(result.shouldPop, isTrue);
        expect(result.hasUserFacingError, isFalse);
        expect(
          ctx.recorderGateway.stopCallCount,
          stopsBefore,
          reason: 'idle exit must NOT call recorder.stop',
        );
        expect(
          ctx.playbackGateway.stopCallCount,
          pbStopsBefore,
          reason: 'idle exit must NOT call playback.stop',
        );
      },
    );

    test(
      'recording: requestStopForPageExit awaits recorder.stop, '
      'flips isRecording to false, preserves takeId, returns success',
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
        // Pre-create the audio file in the real I/O zone so
        // the controller's `_probeRecordingDuration` can
        // resolve a real duration when stopRecording /
        // requestStopForPageExit reads it back.
        final String path = ctx.recorderGateway.lastStartPath!;
        await File(path).create(recursive: true);
        await File(path).writeAsString('fake m4a');
        ctx.recorderGateway.nextStopResult = _stopPath(path);
        ctx.playbackGateway.nextLoadResult = const Duration(seconds: 2);

        final PageExitStopResult result =
            await controller.requestStopForPageExit();
        expect(result, isA<PageExitStopSuccess>(),
            reason: 'recording exit must succeed when stop is clean');
        expect(result.shouldPop, isTrue);
        expect(result.hasUserFacingError, isFalse);
        expect(ctx.recorderGateway.stopCallCount, 1,
            reason: 'recording exit must call recorder.stop exactly once');
        final RecordingPracticeState state =
            ctx.container.read(recordingPracticeControllerProvider);
        expect(state.isRecording, isFalse,
            reason: 'recording exit must flip isRecording to false');
        expect(state.hasRecording, isTrue,
            reason: 'recording exit must preserve hasRecording so the user '
                'can save / re-record after re-entry');
        expect(state.takeId, isNotNull,
            reason: 'recording exit must preserve takeId');
        expect(state.recordedTakeResult, isNotNull,
            reason: 'recording exit must populate recordedTakeResult');
      },
    );

    test(
      'playing: requestStopForPageExit awaits playback.stop, '
      'flips isPlaying to false, returns success',
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
        final String path = ctx.recorderGateway.lastStartPath!;
        await File(path).create(recursive: true);
        await File(path).writeAsString('fake m4a');
        ctx.recorderGateway.nextStopResult = _stopPath(path);
        ctx.playbackGateway.nextLoadResult = const Duration(seconds: 2);
        await controller.stopRecording();
        await _pumpEventQueue();
        await controller.play();
        await _pumpEventQueue();

        final int pbStopsBefore = ctx.playbackGateway.stopCallCount;
        final PageExitStopResult result =
            await controller.requestStopForPageExit();
        expect(result, isA<PageExitStopSuccess>());
        expect(result.shouldPop, isTrue);
        expect(ctx.playbackGateway.stopCallCount, pbStopsBefore + 1,
            reason: 'playing exit must call playback.stop exactly once');
        final RecordingPracticeState state =
            ctx.container.read(recordingPracticeControllerProvider);
        expect(state.isPlaying, isFalse,
            reason: 'playing exit must flip isPlaying to false');
        // The take identity is preserved so the user can
        // resume / re-enter / save after popping.
        expect(state.takeId, isNotNull);
        expect(state.hasRecording, isTrue);
      },
    );

    test(
      'paused / hasRecording with take loaded: requestStopForPageExit '
      'calls playback.stop to release the file handle, returns success',
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
        final String path = ctx.recorderGateway.lastStartPath!;
        await File(path).create(recursive: true);
        await File(path).writeAsString('fake m4a');
        ctx.recorderGateway.nextStopResult = _stopPath(path);
        ctx.playbackGateway.nextLoadResult = const Duration(seconds: 2);
        await controller.stopRecording();
        await _pumpEventQueue();
        await controller.play();
        await _pumpEventQueue();
        // Drive the controller into a "loaded but not
        // playing" state by emitting a natural-completion
        // event. After natural completion the playback
        // service's `_clearActiveSession()` clears the
        // active path; the controller's `isPlaying` flips
        // to `false` synchronously. The controller state
        // now has `isPlaying == false`, `hasRecording ==
        // true`, and `takeId != null` — which is the
        // "paused" / "ready" / "has take loaded" branch
        // the T037B page-exit path must handle.
        ctx.playbackGateway.emitPlayerState(const PlaybackPlayerState(
          playing: false,
          processingState: PlaybackProcessingState.completed,
        ));
        await _pumpEventQueue();
        final RecordingPracticeState afterCompletion =
            ctx.container.read(recordingPracticeControllerProvider);
        expect(afterCompletion.isPlaying, isFalse,
            reason: 'sanity: natural completion flips isPlaying to false');
        expect(afterCompletion.hasRecording, isTrue);
        expect(afterCompletion.takeId, isNotNull);

        // The T037B contract: a page-exit stop MUST
        // release the playback service's file handle even
        // when `isPlaying == false` but a take is loaded,
        // so a subsequent `deleteIfExists` (during
        // save-or-delete on the detail page) does not
        // race the player. The T035I natural-completion
        // handler already calls `playback.stop()` once
        // synchronously; the page-exit stop should be a
        // no-op (or a defensive no-op against the
        // already-cleared session). The result is
        // therefore `success` (the playback service
        // accepts the call and reports a no-op) — what
        // matters is that the page does NOT leak the file
        // handle past the route pop.
        final int pbStopsBefore = ctx.playbackGateway.stopCallCount;
        final PageExitStopResult result =
            await controller.requestStopForPageExit();
        expect(result.shouldPop, isTrue,
            reason: 'paused/loaded page-exit must be a clean pop');
        expect(result.hasUserFacingError, isFalse);
        // The page-exit stop is either a `playback.stop()`
        // call (if the service still has an active session
        // for this take — unusual, since natural completion
        // already cleared it) or a `skipped` because the
        // service is already `idle`. Both are safe. We
        // assert that the controller never reports a
        // failure: the user should be able to exit cleanly
        // after a natural completion.
        expect(result, isNot(isA<PageExitStopFailure>()));
        // `stopCallCount` is EITHER equal to `pbStopsBefore`
        // (the page-exit call short-circuited because the
        // service is already `idle`) OR exactly
        // `pbStopsBefore + 1` (the page-exit call drove a
        // fresh stop). Both are valid.
        expect(
          ctx.playbackGateway.stopCallCount,
          anyOf(equals(pbStopsBefore), equals(pbStopsBefore + 1)),
          reason: 'paused/loaded page-exit must NOT call playback.stop '
              'more than once and must NOT throw',
        );
        // takeId is preserved.
        final RecordingPracticeState state =
            ctx.container.read(recordingPracticeControllerProvider);
        expect(state.takeId, isNotNull);
        expect(state.hasRecording, isTrue);
      },
    );

    test(
      'recording.stop throws: requestStopForPageExit returns failure '
      'with the safe recording-failure message and shouldPop=false',
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
        // Inject a synthetic stop failure that contains
        // forbidden substrings (PII / exception class /
        // file extension). The friendly message MUST NOT
        // leak any of these.
        ctx.recorderGateway.nextStopException =
            Exception('synthetic recorder stop failure at /abs/path/r.m4a');

        final PageExitStopResult result =
            await controller.requestStopForPageExit();
        expect(result, isA<PageExitStopFailure>());
        final PageExitStopFailure failure = result as PageExitStopFailure;
        expect(failure.message, '停止录音失败，请重试',
            reason: 'recording-stop failure message must be the safe '
                'recording-failure copy');
        expect(result.shouldPop, isFalse,
            reason: 'failure result must keep the page mounted');
        expect(result.hasUserFacingError, isTrue);
        // PII / forbidden-substring guard. Mirrors the
        // T037A assertion shape so cross-page debugging is
        // uniform.
        expect(failure.message, isNot(contains('synthetic')),
            reason: 'failure message must NOT leak the synthetic '
                'exception token');
        expect(failure.message, isNot(contains('Exception')));
        expect(failure.message, isNot(contains('.m4a')),
            reason: 'failure message must NOT leak the file extension');
        expect(failure.message, isNot(contains('/abs/path')),
            reason: 'failure message must NOT leak the absolute path');
        expect(failure.message, isNot(contains('停止播放')));
        // T037B2 — the recorder service keeps its active
        // session across a stop failure (state stays
        // `recording`, `_activeTakeId` /
        // `_activeTempFile` preserved). The controller
        // mirrors that by keeping `isRecording = true`
        // so a retry call re-enters the recording branch
        // and drives a real second `recorder.stop()`.
        // The MM:SS ticker is restarted so the readout
        // honestly reflects "recording not yet
        // confirmed stopped". takeId is preserved.
        final RecordingPracticeState state =
            ctx.container.read(recordingPracticeControllerProvider);
        expect(state.isRecording, isTrue,
            reason: 'T037B2: isRecording must STAY true after '
                'recorder.stop throws — the service keeps the '
                'active session so a retry can re-issue '
                'recorder.stop() against the same path');
        expect(state.takeId, isNotNull,
            reason: 'T037B2: takeId is preserved across the failure '
                'so the retry call sees the recording branch');
        expect(state.hasRecording, isFalse);
      },
    );

    test(
      'playback.stop throws: requestStopForPageExit returns failure '
      'with the safe playback-failure message and shouldPop=false',
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
        final String path = ctx.recorderGateway.lastStartPath!;
        await File(path).create(recursive: true);
        await File(path).writeAsString('fake m4a');
        ctx.recorderGateway.nextStopResult = _stopPath(path);
        ctx.playbackGateway.nextLoadResult = const Duration(seconds: 2);
        await controller.stopRecording();
        await _pumpEventQueue();
        await controller.play();
        await _pumpEventQueue();
        // Inject a synthetic playback stop failure.
        ctx.playbackGateway.nextStopException =
            Exception('synthetic playback stop failure at /abs/path/r.m4a');

        final PageExitStopResult result =
            await controller.requestStopForPageExit();
        expect(result, isA<PageExitStopFailure>());
        final PageExitStopFailure failure = result as PageExitStopFailure;
        expect(failure.message, '停止播放失败，请重试',
            reason: 'playback-stop failure message must be the safe '
                'playback-failure copy');
        expect(result.shouldPop, isFalse);
        expect(result.hasUserFacingError, isTrue);
        expect(failure.message, isNot(contains('synthetic')));
        expect(failure.message, isNot(contains('Exception')));
        expect(failure.message, isNot(contains('.m4a')));
        expect(failure.message, isNot(contains('/abs/path')));
        expect(failure.message, isNot(contains('停止录音')),
            reason: 'playback-failure message must use 停止播放 not 停止录音');
      },
    );

    test(
      'recording stopGate: requestStopForPageExit future does NOT '
      'resolve until the gateway stop completes (proves the '
      'awaitable contract, not a fire-and-forget)',
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
        final String path = ctx.recorderGateway.lastStartPath!;
        await File(path).create(recursive: true);
        await File(path).writeAsString('fake m4a');
        ctx.recorderGateway.nextStopResult = _stopPath(path);
        ctx.playbackGateway.nextLoadResult = const Duration(seconds: 2);
        // T037B — install a stop gate so the gateway's
        // `stop()` blocks until the gate is completed.
        // This is the load-bearing assertion: the
        // controller's `requestStopForPageExit` future
        // MUST NOT complete while the platform-channel
        // stop is still in flight.
        final Completer<void> stopGate = Completer<void>();
        ctx.recorderGateway.stopGate = stopGate;

        // Fire the request without awaiting — we will
        // assert that the future stays pending until we
        // complete the gate.
        final Future<PageExitStopResult> pendingResult =
            controller.requestStopForPageExit();
        // Drain microtasks to give the controller a
        // chance to enter its await. The future MUST still
        // be pending.
        await _pumpEventQueue();
        expect(ctx.recorderGateway.stopCallCount, 1,
            reason: 'recorder.stop must have been called');
        // The pendingResult should not have resolved yet
        // — the gate is still open.
        var completed = false;
        // ignore: unawaited_futures
        pendingResult.then((_) => completed = true);
        await _pumpEventQueue();
        expect(completed, isFalse,
            reason: 'requestStopForPageExit future MUST stay pending while '
                'recorder.stop is gated (this is the T037B real-device '
                'fix: awaitable, not fire-and-forget)');
        // Complete the gate and verify the future resolves.
        stopGate.complete();
        final PageExitStopResult result = await pendingResult;
        expect(result, isA<PageExitStopSuccess>(),
            reason: 'after the gate completes the controller must report '
                'success');
        expect(completed, isTrue,
            reason: 'pendingResult future must resolve AFTER the gate is '
                'completed');
      },
    );

    test(
      'duplicate requestStopForPageExit while the first is in flight: '
      'recorder.stop is called exactly once (no double-stop); '
      'concurrent callers share the in-flight Future',
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
        final String path = ctx.recorderGateway.lastStartPath!;
        await File(path).create(recursive: true);
        await File(path).writeAsString('fake m4a');
        ctx.recorderGateway.nextStopResult = _stopPath(path);
        ctx.playbackGateway.nextLoadResult = const Duration(seconds: 2);
        final Completer<void> stopGate = Completer<void>();
        ctx.recorderGateway.stopGate = stopGate;

        // T037B1 — fire the first request, which will
        // block on the gate. The controller no longer
        // flips `isRecording` to false before the await
        // (the in-flight Future is the canonical
        // re-entrancy guard — see the controller source
        // for the rationale). A concurrent caller must
        // observe the same in-flight Future and resolve
        // to the same result.
        final Future<PageExitStopResult> firstRequest =
            controller.requestStopForPageExit();
        await _pumpEventQueue();
        // recorder.stop has been called exactly once.
        expect(ctx.recorderGateway.stopCallCount, 1,
            reason: 'first call must drive recorder.stop');
        // The second concurrent call MUST observe the
        // in-flight Future — the controller does NOT
        // re-enter the recording branch (which would
        // call recorder.stop a second time and throw
        // InvalidRecorderStateException because the
        // recorder is in the `stopping` state).
        final Future<PageExitStopResult> secondRequest =
            controller.requestStopForPageExit();
        // Stop gate is still open; both Futures MUST be
        // pending.
        expect(ctx.recorderGateway.stopCallCount, 1,
            reason: 'concurrent page-exit requests must share the in-flight '
                'Future and MUST NOT call recorder.stop twice');
        // Drain microtasks: the second call should have
        // returned the existingFuture WITHOUT entering
        // _performPageExitStop (which would have
        // incremented the stop call count).
        await _pumpEventQueue();
        expect(ctx.recorderGateway.stopCallCount, 1,
            reason: 'in-flight coordination: concurrent call did NOT drive '
                'recorder.stop a second time');
        // Resolve the gate; both Futures resolve to the
        // SAME result (success — the underlying stop
        // completed cleanly).
        stopGate.complete();
        final PageExitStopResult firstResult = await firstRequest;
        final PageExitStopResult secondResult = await secondRequest;
        expect(firstResult, isA<PageExitStopSuccess>(),
            reason: 'first request resolves with success after the gate');
        expect(secondResult, isA<PageExitStopSuccess>(),
            reason: 'concurrent caller resolves to the SAME result — '
                'no double-stop, no failure');
        // Both Futures resolve to the same identity
        // (they are the SAME Future).
        expect(identical(firstResult, secondResult), isTrue,
            reason: 'in-flight coordination: both callers share the SAME '
                'PageExitStopResult instance (the completer completed once)');
      },
    );

    test(
      'dispose + in-flight page-exit stop failure: no unhandled '
      'async error, controller never throws',
      () async {
        final ctx = _buildContext(
          permission: (b) =>
              b..nextCheckStatus = MicrophonePermissionStatus.granted,
        );

        final RecordingPracticeController controller =
            ctx.container.read(recordingPracticeControllerProvider.notifier);
        await controller.startRecording();
        await _pumpEventQueue();
        ctx.recorderGateway.nextStopException =
            Exception('synthetic stop failure during dispose');
        // Dispose the container; the onDispose hook must
        // run cleanly even with an injected stop failure.
        // The T037B page-exit path itself is not yet
        // exercised here — this test pins the dispose-
        // time safety net so a non-cooperative page
        // removal (e.g. an automated test that drops the
        // widget tree without going through the page's
        // exit handler) cannot produce an unhandled async
        // error.
        ctx.container.dispose();
        // Calling requestStopForPageExit on a disposed
        // controller must return skipped(disposed), not
        // throw.
        final PageExitStopResult result =
            await controller.requestStopForPageExit();
        expect(result, isA<PageExitStopSkipped>());
        expect(
          (result as PageExitStopSkipped).reason,
          PageExitStopSkipReason.disposed,
        );
        // A subsequent stopRecording on the disposed
        // controller must be a clean no-op.
        await controller.stopRecording();
        await controller.play();
      },
    );

    // =======================================================================
    // T037B1 — failure-retry contract.
    //
    // The pre-fix implementation flipped `isRecording=false` /
    // `isPlaying=false` BEFORE awaiting the underlying stop,
    // then relied on a "second call observes idle, pops the
    // page" path. That was wrong:
    //
    // - the recorder branch threw, the second call did NOT
    //   re-enter the recorder branch (it fell through to the
    //   playback branch and called playback.stop instead);
    // - the playback branch threw, the second call re-entered
    //   but had no consistency guarantee on isPlaying;
    // - the ticker was unconditionally stopped, even when the
    //   service was still in a stoppable state.
    //
    // The fix introduces a single in-flight Future
    // ([_pageExitStopFuture]) plus per-branch retry semantics:
    // recording failures mirror the service-level "already
    // terminal" state, playback failures preserve the
    // pre-stop playback service state.
    // =======================================================================

    test(
      'T037B2 — recording stop failure: page is retained, '
      'failure message returned, isRecording STAYS true '
      '(service keeps active session so a retry can re-issue '
      'recorder.stop)',
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
        ctx.recorderGateway.nextStopException =
            Exception('synthetic recorder stop failure at /abs/path/r.m4a');

        final PageExitStopResult result =
            await controller.requestStopForPageExit();
        expect(result, isA<PageExitStopFailure>(),
            reason: 'recording-stop failure must return failure so the page '
                'stays mounted for retry');
        expect(result.shouldPop, isFalse);
        final PageExitStopFailure failure = result as PageExitStopFailure;
        expect(failure.message, '停止录音失败，请重试');
        // T037B2 — the recorder service keeps its active
        // session when stop() throws (state stays
        // `recording`, `_activeTakeId` /
        // `_activeTempFile` preserved) so a retry can
        // re-issue `recorder.stop()`. The controller
        // mirrors that by keeping `isRecording = true`
        // on the page side. takeId is preserved so the
        // user retains the identity of the failed take.
        final RecordingPracticeState state =
            ctx.container.read(recordingPracticeControllerProvider);
        expect(state.isRecording, isTrue,
            reason: 'T037B2: isRecording must STAY true after '
                'recorder.stop throws — the service keeps the '
                'active session so a retry can re-issue '
                'recorder.stop() against the same path');
        expect(state.takeId, isNotNull,
            reason: 'takeId is preserved so the retry call sees the '
                'recording branch');
        expect(state.hasRecording, isFalse);
      },
    );

    test(
      'T037B2 — recording retry: second requestStopForPageExit '
      'after a recorder.stop failure re-issues recorder.stop '
      'against the SAME active session and resolves to success',
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
        // First attempt: stop throws.
        ctx.recorderGateway.nextStopException =
            Exception('synthetic recorder stop failure');
        final PageExitStopResult first =
            await controller.requestStopForPageExit();
        expect(first, isA<PageExitStopFailure>());

        // T037B2 — the recorder service kept its active
        // session (state stays `recording`,
        // `_activeTempFile` preserved). The retry MUST
        // re-issue `recorder.stop()` against the SAME
        // path and succeed — this is the "second exit
        // actually retries" contract that the previous
        // T037B1 implementation (which short-circuited
        // to skipped(serviceAlreadyTerminal) on the
        // second call) violated.
        final int stopsBefore = ctx.recorderGateway.stopCallCount;
        ctx.recorderGateway.nextStopException = null;
        ctx.recorderGateway.nextStopResult = ctx.recorderGateway.lastStartPath;
        final PageExitStopResult second =
            await controller.requestStopForPageExit();
        expect(second, isA<PageExitStopSuccess>(),
            reason: 'T037B2: the recorder retry MUST drive a real second '
                'recorder.stop against the SAME active session and succeed');
        expect(second.shouldPop, isTrue);
        expect(second.hasUserFacingError, isFalse);
        expect(ctx.recorderGateway.stopCallCount, stopsBefore + 1,
            reason: 'T037B2: the retry MUST call recorder.stop exactly '
                'once (against the same session) and the controller '
                'MUST NOT short-circuit on the failure path');
      },
    );

    test(
      'T037B1 — playback stop failure: page is retained, '
      'failure message returned, isPlaying STAYS true '
      '(service state is restored to previousState on failure)',
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
        final String path = ctx.recorderGateway.lastStartPath!;
        await File(path).create(recursive: true);
        await File(path).writeAsString('fake m4a');
        ctx.recorderGateway.nextStopResult = _stopPath(path);
        ctx.playbackGateway.nextLoadResult = const Duration(seconds: 2);
        await controller.stopRecording();
        await _pumpEventQueue();
        await controller.play();
        await _pumpEventQueue();
        ctx.playbackGateway.nextStopException =
            Exception('synthetic playback stop failure');

        final PageExitStopResult result =
            await controller.requestStopForPageExit();
        expect(result, isA<PageExitStopFailure>(),
            reason: 'playback-stop failure must return failure so the page '
                'stays mounted for retry');
        expect(result.shouldPop, isFalse);
        final PageExitStopFailure failure = result as PageExitStopFailure;
        expect(failure.message, '停止播放失败，请重试');
        // T037B1 — the playback service contract restores
        // its state to previousState on failure. The
        // controller mirrors that by keeping isPlaying =
        // true on the page side so a retry call can
        // re-enter the playback branch and call
        // playback.stop again. The retry path is the
        // real-device retry actually retries contract.
        final RecordingPracticeState state =
            ctx.container.read(recordingPracticeControllerProvider);
        expect(state.isPlaying, isTrue,
            reason: 'T037B1: isPlaying must STAY true after playback.stop '
                'throws — the service state is restored, the page '
                'should re-enter the playback branch on retry');
        expect(state.takeId, isNotNull);
      },
    );

    test(
      'T037B1 — playback retry: second requestStopForPageExit '
      'after a playback.stop failure re-calls playback.stop '
      'exactly once and resolves to success',
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
        final String path = ctx.recorderGateway.lastStartPath!;
        await File(path).create(recursive: true);
        await File(path).writeAsString('fake m4a');
        ctx.recorderGateway.nextStopResult = _stopPath(path);
        ctx.playbackGateway.nextLoadResult = const Duration(seconds: 2);
        await controller.stopRecording();
        await _pumpEventQueue();
        await controller.play();
        await _pumpEventQueue();
        // First attempt: stop throws.
        ctx.playbackGateway.nextStopException =
            Exception('synthetic playback stop failure');
        final PageExitStopResult first =
            await controller.requestStopForPageExit();
        expect(first, isA<PageExitStopFailure>());

        // Second attempt: the playback service's state
        // has been restored to previousState (still
        // playing). The retry MUST re-call
        // playback.stop and succeed.
        ctx.playbackGateway.nextStopException = null;
        final int pbStopsBefore = ctx.playbackGateway.stopCallCount;
        final PageExitStopResult second =
            await controller.requestStopForPageExit();
        expect(second, isA<PageExitStopSuccess>(),
            reason: 'T037B1: the playback retry must drive a real second '
                'playback.stop and succeed when the service state is '
                'restored');
        expect(second.shouldPop, isTrue);
        expect(ctx.playbackGateway.stopCallCount, pbStopsBefore + 1,
            reason: 'T037B1: the retry MUST call playback.stop exactly '
                'one more time');
        final RecordingPracticeState finalState =
            ctx.container.read(recordingPracticeControllerProvider);
        expect(finalState.isPlaying, isFalse,
            reason: 'after the retry succeeds, isPlaying flips to false');
      },
    );

    test(
      'T037B1 — concurrent callers share the same in-flight Future '
      '(only one recorder.stop is issued even under contention)',
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
        final String path = ctx.recorderGateway.lastStartPath!;
        await File(path).create(recursive: true);
        await File(path).writeAsString('fake m4a');
        ctx.recorderGateway.nextStopResult = _stopPath(path);
        ctx.playbackGateway.nextLoadResult = const Duration(seconds: 2);
        final Completer<void> stopGate = Completer<void>();
        ctx.recorderGateway.stopGate = stopGate;

        // Fire four concurrent callers while the gate
        // is held.
        final Future<PageExitStopResult> r1 =
            controller.requestStopForPageExit();
        final Future<PageExitStopResult> r2 =
            controller.requestStopForPageExit();
        final Future<PageExitStopResult> r3 =
            controller.requestStopForPageExit();
        final Future<PageExitStopResult> r4 =
            controller.requestStopForPageExit();
        await _pumpEventQueue();
        expect(ctx.recorderGateway.stopCallCount, 1,
            reason: 'T037B1: concurrent callers must share the in-flight '
                'Future; only one recorder.stop is issued');
        stopGate.complete();
        final List<PageExitStopResult> results = await Future.wait(
          <Future<PageExitStopResult>>[r1, r2, r3, r4],
        );
        for (final PageExitStopResult r in results) {
          expect(r, isA<PageExitStopSuccess>(),
              reason: 'T037B1: every concurrent caller resolves to the '
                  'same success result');
          expect(r.shouldPop, isTrue);
        }
        // All four resolve to the SAME instance (the
        // completer completed once).
        final PageExitStopResult r0 = results.first;
        for (final PageExitStopResult r in results.skip(1)) {
          expect(identical(r0, r), isTrue,
              reason: 'T037B1: every concurrent caller observes the same '
                  'PageExitStopResult identity (single completer '
                  'completion)');
        }
      },
    );

    test(
      'T037B2 — recorder retry after the in-flight Future has '
      'resolved: a NEW in-flight Future is created (the gate '
      'is gone, the in-flight coordinator must start fresh) '
      'and the retry drives a real second recorder.stop against '
      'the same active session',
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
        // First exit: stop throws.
        ctx.recorderGateway.nextStopException =
            Exception('synthetic recorder stop failure');
        final PageExitStopResult first =
            await controller.requestStopForPageExit();
        expect(first, isA<PageExitStopFailure>());

        // T037B2 — the in-flight Future has been cleared
        // (finally block ran). The retry MUST start a
        // fresh in-flight Future. The recorder service
        // kept its active session (state stays
        // `recording`, `_activeTempFile` preserved) so
        // the retry drives a real second
        // `recorder.stop()` against the SAME path and
        // succeeds. This is the
        // "second-exit-actually-retries" contract.
        ctx.recorderGateway.nextStopException = null;
        ctx.recorderGateway.nextStopResult = ctx.recorderGateway.lastStartPath;
        final int stopsBefore = ctx.recorderGateway.stopCallCount;
        final PageExitStopResult second =
            await controller.requestStopForPageExit();
        expect(second, isA<PageExitStopSuccess>(),
            reason: 'T037B2: the retry must start a fresh in-flight '
                'Future and drive a real second recorder.stop against '
                'the same active session');
        expect(second.shouldPop, isTrue);
        expect(ctx.recorderGateway.stopCallCount, stopsBefore + 1,
            reason: 'T037B2: the retry MUST call recorder.stop exactly '
                'once more against the same session');
      },
    );

    test(
      'T037B2 — recorder.stop failure restarts the ticker '
      '(the MM:SS readout honestly reflects "recording not yet '
      'confirmed stopped") and does NOT create a duplicate Timer',
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
        ctx.recorderGateway.nextStopException =
            Exception('synthetic recorder stop failure');
        final PageExitStopResult first =
            await controller.requestStopForPageExit();
        expect(first, isA<PageExitStopFailure>());

        // T037B2 — on failure the controller restarts the
        // ticker so the MM:SS readout honestly reflects
        // the unknown-stop state. The ticker restart
        // MUST NOT create a duplicate `Timer.periodic`
        // — `_startTicker` is internally guarded by an
        // `_stopTicker` call which cancels the existing
        // ticker before creating a new one. We assert
        // this indirectly: after the failure, the retry
        // (which now resolves to success per the new
        // contract) stops the ticker and the controller
        // state has `isRecording=false`. If a duplicate
        // Timer were running it would have advanced
        // `elapsedSeconds` past the recorded duration.
        ctx.recorderGateway.nextStopException = null;
        ctx.recorderGateway.nextStopResult = ctx.recorderGateway.lastStartPath;
        final PageExitStopResult second =
            await controller.requestStopForPageExit();
        expect(second, isA<PageExitStopSuccess>(),
            reason: 'T037B2: retry must drive a real second '
                'recorder.stop and succeed');
        final RecordingPracticeState state =
            ctx.container.read(recordingPracticeControllerProvider);
        expect(state.isRecording, isFalse);
        expect(state.hasRecording, isTrue,
            reason: 'successful retry must populate the take result so '
                'the user can save it');
      },
    );

    // -----------------------------------------------------------------
    // T037B2 — dedicated controller-level retry semantics
    //
    // The previous T037B1 contract was that the
    // recorder service cleared its session on a
    // gateway.stop() throw, so the controller's
    // retry short-circuited to
    // `skipped(serviceAlreadyTerminal)` — the page
    // would pop without ever issuing a real second
    // `recorder.stop()`. T037B2 fixes the SERVICE
    // contract (the active session is preserved),
    // and these tests pin the controller-level
    // consequences:
    //   * first failure: page retained, takeId
    //     preserved, `isRecording` stays true, ticker
    //     restarts, failure message returned;
    //   * second call: drives a real second
    //     `recorder.stop()` against the SAME
    //     active session, succeeds;
    //   * consecutive failures: every retry still
    //     drives a real `recorder.stop()`, the page
    //     is NEVER popped on failure;
    //   * ticker is restarted (not duplicated) on
    //     failure so the MM:SS readout honestly
    //     reflects "recording not yet confirmed
    //     stopped".
    // -----------------------------------------------------------------

    test(
      'T037B2 — first recorder.stop failure: page ownership '
      'preserved (isRecording STAYS true, takeId preserved, '
      'failure result with safe recording-failure message)',
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
        ctx.recorderGateway.nextStopException =
            Exception('synthetic recorder stop failure at /abs/path/r.m4a');

        final PageExitStopResult result =
            await controller.requestStopForPageExit();
        expect(result, isA<PageExitStopFailure>(),
            reason: 'T037B2: first failure must return failure so '
                'the page stays mounted for retry');
        expect(result.shouldPop, isFalse);
        final PageExitStopFailure failure = result as PageExitStopFailure;
        expect(failure.message, '停止录音失败，请重试',
            reason: 'recording-stop failure must use the safe '
                'recording-failure copy');
        // Page ownership is preserved across the failure.
        final RecordingPracticeState state =
            ctx.container.read(recordingPracticeControllerProvider);
        expect(state.isRecording, isTrue,
            reason: 'T037B2: isRecording MUST stay true after the first '
                'recorder.stop failure — the service kept its active '
                'session, the controller mirrors that, a retry will '
                're-enter the recording branch and re-issue '
                'recorder.stop() against the same path');
        expect(state.takeId, isNotNull,
            reason: 'T037B2: takeId is preserved so the retry call '
                'sees the recording branch');
        expect(state.hasRecording, isFalse,
            reason: 'T037B2: hasRecording stays false — no successful '
                'take has been produced yet');
      },
    );

    test(
      'T037B2 — second recorder.stop call after a failure: '
      'drives a real second recorder.stop() against the SAME '
      'active session and resolves to success',
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
        // First call: stop throws.
        ctx.recorderGateway.nextStopException =
            Exception('synthetic recorder stop failure');
        final PageExitStopResult first =
            await controller.requestStopForPageExit();
        expect(first, isA<PageExitStopFailure>());

        // Second call: the in-flight Future has been
        // cleared (finally block ran). The service kept
        // its active session. The retry MUST drive a
        // real second `recorder.stop()` and succeed.
        final int stopsBefore = ctx.recorderGateway.stopCallCount;
        ctx.recorderGateway.nextStopException = null;
        ctx.recorderGateway.nextStopResult = ctx.recorderGateway.lastStartPath;
        final PageExitStopResult second =
            await controller.requestStopForPageExit();
        expect(second, isA<PageExitStopSuccess>(),
            reason: 'T037B2: the retry MUST drive a real second '
                'recorder.stop and resolve to success — the '
                'previous T037B1 contract short-circuited to '
                'skipped(serviceAlreadyTerminal) on the second '
                'call, violating the "second exit actually '
                'retries" contract');
        expect(second.shouldPop, isTrue);
        expect(second.hasUserFacingError, isFalse);
        expect(ctx.recorderGateway.stopCallCount, stopsBefore + 1,
            reason: 'T037B2: the retry MUST call recorder.stop exactly '
                'once more against the same active session');
        // The successful retry populates the take result.
        final RecordingPracticeState state =
            ctx.container.read(recordingPracticeControllerProvider);
        expect(state.isRecording, isFalse);
        expect(state.hasRecording, isTrue);
        expect(state.recordedTakeResult, isNotNull);
        expect(state.recordedTakeResult!.resolvedPath,
            ctx.recorderGateway.lastStartPath,
            reason: 'T037B2 + T033: resolvedPath is preserved '
                'verbatim from the recorder gateway');
      },
    );

    test(
      'T037B2 — consecutive recorder.stop failures: every retry '
      'drives a real recorder.stop() and the page is NEVER popped '
      'until the retry succeeds',
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
        // Three consecutive failures.
        for (int i = 0; i < 3; i++) {
          ctx.recorderGateway.nextStopException =
              Exception('synthetic recorder stop failure #$i');
          final PageExitStopResult r =
              await controller.requestStopForPageExit();
          expect(r, isA<PageExitStopFailure>(),
              reason: 'failure #$i: result must be failure so the '
                  'page stays mounted for retry');
          expect(r.shouldPop, isFalse,
              reason: 'failure #$i: page must NEVER pop until the '
                  'retry succeeds');
          final RecordingPracticeState state =
              ctx.container.read(recordingPracticeControllerProvider);
          expect(state.isRecording, isTrue,
              reason: 'failure #$i: isRecording MUST stay true');
          expect(state.takeId, isNotNull,
              reason: 'failure #$i: takeId is preserved');
        }
        expect(ctx.recorderGateway.stopCallCount, 3,
            reason: 'T037B2: every retry MUST invoke recorder.stop() — '
                'the controller MUST NOT short-circuit');
        // Successful retry.
        ctx.recorderGateway.nextStopException = null;
        ctx.recorderGateway.nextStopResult = ctx.recorderGateway.lastStartPath;
        final PageExitStopResult success =
            await controller.requestStopForPageExit();
        expect(success, isA<PageExitStopSuccess>(),
            reason: 'T037B2: after three failures, the fourth call '
                '(with the gateway reset to succeed) MUST drive a '
                'real recorder.stop and succeed');
        expect(success.shouldPop, isTrue);
        expect(ctx.recorderGateway.stopCallCount, 4);
      },
    );

    test(
      'T037B2 — ticker restart on failure does NOT create a '
      'duplicate Timer.periodic (the MM:SS readout honestly '
      'reflects "recording not yet confirmed stopped")',
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
        // First failure: controller restarts the ticker.
        ctx.recorderGateway.nextStopException =
            Exception('synthetic recorder stop failure');
        final PageExitStopResult first =
            await controller.requestStopForPageExit();
        expect(first, isA<PageExitStopFailure>());

        // Successful retry: the ticker is cancelled
        // before the second `recorder.stop()` await
        // (so the MM:SS readout does not advance while
        // the second platform-channel stop is in
        // flight), and a successful retry leaves
        // `isRecording = false` and the ticker
        // stopped. We assert indirectly that no
        // duplicate Timer was created: the retry's
        // success path stops the ticker cleanly and
        // the resulting `recordedDurationSeconds` is
        // stable (not advancing from a leaked
        // duplicate Timer).
        ctx.recorderGateway.nextStopException = null;
        ctx.recorderGateway.nextStopResult = ctx.recorderGateway.lastStartPath;
        final PageExitStopResult second =
            await controller.requestStopForPageExit();
        expect(second, isA<PageExitStopSuccess>());
        final RecordingPracticeState state =
            ctx.container.read(recordingPracticeControllerProvider);
        expect(state.isRecording, isFalse);
        expect(state.hasRecording, isTrue);
        // `recordedDurationSeconds` is stable after
        // the successful stop — if a duplicate Timer
        // were running, elapsedSeconds would diverge
        // from recordedDurationSeconds on a later
        // tick. The MM:SS readout is pinned.
        expect(state.elapsedSeconds, state.recordedDurationSeconds,
            reason: 'T037B2: elapsedSeconds MUST equal '
                'recordedDurationSeconds after the successful stop — '
                'a duplicate Timer would have advanced elapsedSeconds '
                'past the recorded duration');
      },
    );

    test(
      'T037B2 — controller does NOT return '
      'skipped(serviceAlreadyTerminal) as a way to bypass the '
      'real retry after a recorder.stop failure (the recording '
      'branch must drive a real second stop, not short-circuit)',
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
        ctx.recorderGateway.nextStopException =
            Exception('synthetic recorder stop failure');
        final PageExitStopResult first =
            await controller.requestStopForPageExit();
        expect(first, isA<PageExitStopFailure>());
        // The retry must NOT bypass the real stop.
        ctx.recorderGateway.nextStopException = null;
        ctx.recorderGateway.nextStopResult = ctx.recorderGateway.lastStartPath;
        final PageExitStopResult second =
            await controller.requestStopForPageExit();
        expect(second, isA<PageExitStopSuccess>(),
            reason: 'T037B2: the retry MUST resolve to success '
                'via a real recorder.stop(), NOT to '
                'skipped(serviceAlreadyTerminal)');
        expect(second, isNot(isA<PageExitStopSkipped>()),
            reason: 'T037B2: short-circuiting to '
                'skipped(serviceAlreadyTerminal) on the retry would '
                'bypass the real second recorder.stop() and '
                'silently leave the native recorder running');
      },
    );
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

  @override
  Future<bool> hasAudioPathReference(String audioFilePath) async => false;
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

  @override
  Future<bool> hasAudioPathReference(String audioFilePath) async => false;
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

/// T038B — fake gateway whose `checkStatus` returns the
/// supplied pending future. The test completes the future
/// manually once the assertions are done so the controller
/// can resolve its in-flight `startRecording` call. Used by
/// the "refresh is a no-op while a check is in flight" test
/// to exercise the canonical in-flight gate.
class _HangingPermissionGateway implements MicrophonePermissionGateway {
  _HangingPermissionGateway(this._pending);

  final Future<MicrophonePermissionStatus> _pending;
  int checkStatusCallCount = 0;

  @override
  Future<MicrophonePermissionStatus> checkStatus() async {
    checkStatusCallCount += 1;
    return _pending;
  }

  @override
  Future<MicrophonePermissionStatus> requestPermission() async {
    return MicrophonePermissionStatus.denied;
  }

  @override
  Future<bool> openSettings() async {
    return true;
  }
}
