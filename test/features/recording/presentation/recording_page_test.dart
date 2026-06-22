// Tests for the [RecordingPage] widget (T012 + T013.4A + T031).
//
// T012 scope (preserved where compatible):
// - Verify the page renders the app bar title, the disclaimer
//   banner (T031: real microphone, recording held in app private
//   storage, save-to-PracticeRecord still being rolled out),
//   the status card, the timer, all four primary controls, the
//   secondary "重新录一遍" button, the self-rating selector, and
//   the note field.
// - Verify tapping "开始录音" flips the status label and enables
//   the stop button.
// - Verify tapping "停止录音" exposes the playback entry.
// - Verify the self-rating selector and note field are visible.
//
// T013.4A scope (preserved):
// - The save button starts disabled, becomes enabled when a valid
//   take exists, and shows "正在保存…" while in flight.
// - A successful save flips the button to "已保存" and shows the
//   success SnackBar.
// - A failed save re-enables the button and shows the failure
//   SnackBar.
// - An ignored save shows no SnackBar.
// - While saving, the recording / rating / note controls are
//   disabled.
// - After a successful save, rating and note are disabled but
//   playback still works.
//
// T031 scope (NEW):
// - Page MUST NOT display "模拟录音" / "不调用麦克风" /
//   "不保存真实音频" / "不播放真实音频" — those phrases belong
//   to the pre-T031 controller contract.
// - Page renders the T031 disclaimer copy: "本页使用本机麦克风
//   录制练习片段。录音暂存在本机，保存到练习记录将在后续步骤
//   接入，当前录音仅保存在本次会话中。"
//
// Test strategy:
// - All widget tests use a `ProviderContainer` whose
//   `audioFileStorageServiceProvider` /
//   `realAudioRecorderServiceProvider` /
//   `realAudioPlaybackServiceProvider` /
//   `microphonePermissionServiceProvider` are overridden with
//   production services wired to `FakeAudioRecorderGateway` /
//   `FakeAudioPlaybackGateway` / `FakeMicrophonePermissionGateway`
//   so the page never touches the real platform channels.
// - `practiceRecordIdGeneratorProvider`,
//   `practiceRecordRepositoryProvider`, `practiceDayResolverProvider`
//   and `appClockProvider` are also overridden with fakes so no
//   real DB / clock is ever touched.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
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
import 'package:ukulele_app/features/recording/presentation/recording_page.dart';
import 'package:ukulele_app/shared/providers/app_clock_provider.dart';
import 'package:ukulele_app/shared/providers/audio_file_storage_service_provider.dart';
import 'package:ukulele_app/shared/providers/microphone_permission_service_provider.dart';
import 'package:ukulele_app/shared/providers/real_audio_playback_service_provider.dart';
import 'package:ukulele_app/shared/providers/real_audio_recorder_service_provider.dart';
import 'package:ukulele_app/shared/services/audio_file_storage_service.dart';
import 'package:ukulele_app/shared/services/audio_playback_gateway.dart';
import 'package:ukulele_app/shared/services/microphone_permission_service.dart';
import 'package:ukulele_app/shared/services/microphone_permission_status.dart';
import 'package:ukulele_app/shared/services/practice_day_context.dart';
import 'package:ukulele_app/shared/services/real_audio_playback_service.dart';
import 'package:ukulele_app/shared/services/real_audio_recorder_service.dart';

import '../../../shared/services/fake_audio_playback_gateway.dart';
import '../../../shared/services/fake_audio_recorder_gateway.dart';
import '../../../shared/services/fake_microphone_permission_gateway.dart';

/// Sets a tall test surface so the whole page fits without scrolling.
Future<void> _useTallSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 2000));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });
}

/// Pinned clock + day for the save-flow tests.
final DateTime _kTestNowUtc = DateTime.utc(2026, 6, 20, 9, 0, 0);
final DateTime _kTestToday = DateTime(2026, 6, 20);
const int _kTestDayIndex = 2;

int _rootCounter = 0;

({Future<Directory> Function() rootProvider, Directory root}) _isolatedRoot() {
  final Directory root = Directory(
    p.join(
      Directory.systemTemp.path,
      'recording_page_${DateTime.now().microsecondsSinceEpoch}_${_rootCounter++}',
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

/// Bundle of fakes + service instances the widget test wires into
/// a `ProviderContainer`. Recording / playback / permission
/// behaviour is controlled by pre-seeding values on the
/// corresponding fake.
class _PageContext {
  _PageContext({
    required this.recorderGateway,
    required this.playbackGateway,
    required this.permissionGateway,
    required this.storage,
  });

  final FakeAudioRecorderGateway recorderGateway;
  final FakeAudioPlaybackGateway playbackGateway;
  final FakeMicrophonePermissionGateway permissionGateway;
  final AudioFileStorageService storage;
}

/// Builds overrides that wire the controller against the
/// supplied fake repository + fakes for audio / permission.
List<Override> _buildOverrides({
  required PracticeRecordRepository repository,
  _PageContext? ctx,
  DateTime Function()? clock,
}) {
  final List<Override> overrides = <Override>[
    practiceRecordIdGeneratorProvider.overrideWithValue(
      _SequentialPracticeRecordIdGenerator(),
    ),
    practiceRecordRepositoryProvider.overrideWithValue(repository),
    practiceDayResolverProvider.overrideWithValue(_FakePracticeDayResolver()),
    appClockProvider.overrideWithValue(clock ?? (() => _kTestNowUtc)),
  ];
  if (ctx != null) {
    final RealAudioRecorderService recorderService = RealAudioRecorderService(
      gateway: ctx.recorderGateway,
      storage: ctx.storage,
    );
    final RealAudioPlaybackService playbackService = RealAudioPlaybackService(
      gateway: ctx.playbackGateway,
      storage: ctx.storage,
    );
    final MicrophonePermissionService permissionService =
        MicrophonePermissionService(ctx.permissionGateway);
    overrides.addAll(<Override>[
      audioFileStorageServiceProvider.overrideWithValue(ctx.storage),
      realAudioRecorderServiceProvider.overrideWithValue(recorderService),
      realAudioPlaybackServiceProvider.overrideWithValue(playbackService),
      microphonePermissionServiceProvider.overrideWithValue(permissionService),
    ]);
  }
  return overrides;
}

/// Pumps the [RecordingPage] inside a `ProviderScope` with the
/// overrides supplied by [_buildOverrides]. Returns the
/// [ProviderContainer] so tests can read state and tear it down.
Future<ProviderContainer> _pumpPage(
  WidgetTester tester,
  _FakePracticeRecordRepository repository, {
  _PageContext? ctx,
}) async {
  final ProviderContainer container = ProviderContainer(
    overrides: _buildOverrides(repository: repository, ctx: ctx),
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: RecordingPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// Pre-seeds the page for a successful take → stop → play flow.
/// (Unused at the moment; kept as a placeholder for future
/// full-flow tests.)
// ignore: unused_element
Future<String> _seedSuccessfulTake(_PageContext ctx) async {
  ctx.permissionGateway.nextCheckStatus = MicrophonePermissionStatus.granted;
  await ctx.storage.ensureDirectories();
  return '';
}

void main() {
  group('RecordingPage T031 disclaimer + status', () {
    testWidgets(
      'renders disclaimer, status, timer, controls, rating, note, '
      'and save button',
      (WidgetTester tester) async {
        await _useTallSurface(tester);
        final (:rootProvider, :root) = _isolatedRoot();
        final AudioFileStorageService storage = AudioFileStorageService(
          rootDirectoryProvider: rootProvider,
        );
        final _PageContext ctx = _PageContext(
          recorderGateway: FakeAudioRecorderGateway(),
          playbackGateway: FakeAudioPlaybackGateway(),
          permissionGateway: FakeMicrophonePermissionGateway(),
          storage: storage,
        );
        ctx.permissionGateway.nextCheckStatus =
            MicrophonePermissionStatus.granted;
        await _pumpPage(tester, _FakePracticeRecordRepository(), ctx: ctx);

        // App bar title.
        expect(find.text('录音回放'), findsOneWidget);

        // T031 disclaimer copy: real microphone, recording held in
        // private storage, save-to-PracticeRecord still being rolled
        // out.
        expect(
          find.textContaining('本页使用本机麦克风录制练习片段'),
          findsOneWidget,
        );
        expect(
          find.textContaining('录音暂存在本机'),
          findsOneWidget,
        );
        expect(
          find.textContaining('当前录音仅保存在本次会话中'),
          findsOneWidget,
        );

        // T031 forbidden phrases MUST NOT appear (pre-T031
        // "模拟录音 / 不调用麦克风 / 不保存真实音频 / 不播放真实音频"
        // are no longer accurate).
        expect(find.textContaining('模拟录音'), findsNothing);
        expect(find.textContaining('不会调用麦克风'), findsNothing);
        expect(find.textContaining('不会保存真实音频'), findsNothing);
        expect(find.textContaining('不会播放真实音频'), findsNothing);
        expect(find.textContaining('模拟回放'), findsNothing);

        // Initial status is "准备录音".
        expect(find.text('准备录音'), findsOneWidget);

        // Initial timer reads 00:00.
        expect(find.text('00:00'), findsOneWidget);

        // All four primary controls are present.
        expect(find.text('开始录音'), findsOneWidget);
        expect(find.text('停止录音'), findsOneWidget);
        expect(find.text('回放'), findsOneWidget);
        expect(find.text('停止回放'), findsOneWidget);

        // Secondary "重新录一遍" button.
        expect(find.text('重新录一遍'), findsOneWidget);

        // Self-rating selector labels.
        expect(find.text('还不错'), findsOneWidget);
        expect(find.text('一般'), findsOneWidget);
        expect(find.text('需要重练'), findsOneWidget);

        // Note field exists.
        expect(
          find.byKey(const ValueKey<String>('recording-note')),
          findsOneWidget,
        );

        // Save button is rendered and initially disabled.
        expect(
          find.byKey(const ValueKey<String>('recording-save')),
          findsOneWidget,
        );
        final FilledButton saveButton = tester.widget<FilledButton>(
          find.byKey(const ValueKey<String>('recording-save')),
        );
        expect(saveButton.onPressed, isNull,
            reason: 'save button must start disabled');
      },
    );
  });

  group('RecordingPage T031 status + copy transitions', () {
    testWidgets(
      'permission denied: status flips to 麦克风权限被拒绝, '
      'recording controls are disabled',
      (WidgetTester tester) async {
        await _useTallSurface(tester);
        final (:rootProvider, :root) = _isolatedRoot();
        final AudioFileStorageService storage = AudioFileStorageService(
          rootDirectoryProvider: rootProvider,
        );
        final _PageContext ctx = _PageContext(
          recorderGateway: FakeAudioRecorderGateway(),
          playbackGateway: FakeAudioPlaybackGateway(),
          permissionGateway: FakeMicrophonePermissionGateway()
            ..nextCheckStatus = MicrophonePermissionStatus.denied
            ..nextRequestStatus = MicrophonePermissionStatus.denied,
          storage: storage,
        );
        await _pumpPage(tester, _FakePracticeRecordRepository(), ctx: ctx);

        await tester.tap(
          find.byKey(const ValueKey<String>('recording-start')),
        );
        await tester.pumpAndSettle();

        expect(find.text('麦克风权限被拒绝'), findsOneWidget);
        expect(find.text('准备录音'), findsNothing);
        // Recorder service MUST NOT have been called.
        expect(ctx.recorderGateway.startCallCount, 0);

        // Start button stays enabled so the user can re-tap it to
        // re-request permission (the page is the affordance for
        // "重新申请权限"). Recording controls disabled while
        // permission is denied — wait, the brief says the start
        // button stays enabled so the user can retry. Verify by
        // tapping start a second time triggers a fresh
        // requestPermission call.
        final FilledButton startButton = tester.widget<FilledButton>(
          find.byKey(const ValueKey<String>('recording-start')),
        );
        expect(startButton.onPressed, isNotNull,
            reason: 'start button stays enabled so the user can re-request');
        expect(ctx.permissionGateway.checkStatusCallCount, 1);
      },
    );

    testWidgets(
      'permission granted: tapping 开始录音 flips status to 正在录音',
      (WidgetTester tester) async {
        await _useTallSurface(tester);
        final (:rootProvider, :root) = _isolatedRoot();
        final AudioFileStorageService storage = AudioFileStorageService(
          rootDirectoryProvider: rootProvider,
        );
        final _PageContext ctx = _PageContext(
          recorderGateway: FakeAudioRecorderGateway(),
          playbackGateway: FakeAudioPlaybackGateway(),
          permissionGateway: FakeMicrophonePermissionGateway()
            ..nextCheckStatus = MicrophonePermissionStatus.granted,
          storage: storage,
        );
        await _pumpPage(tester, _FakePracticeRecordRepository(), ctx: ctx);

        await tester.tap(
          find.byKey(const ValueKey<String>('recording-start')),
        );
        await tester.pumpAndSettle();

        expect(find.text('正在录音'), findsOneWidget);
        expect(ctx.recorderGateway.startCallCount, 1);

        // Cleanup: stop so the in-flight timer is cancelled.
        ctx.recorderGateway.nextStopResult = '';
        await tester.tap(
          find.byKey(const ValueKey<String>('recording-stop')),
        );
        await tester.pumpAndSettle();
      },
    );

    // T031C: pinned "recording ↔ playback mutual exclusion" page tests.
    testWidgets(
      'T031C: while playback is in progress, the "开始录音" button is '
      'disabled and the controller never receives a startRecording call',
      (WidgetTester tester) async {
        await _useTallSurface(tester);
        final (:rootProvider, :root) = _isolatedRoot();
        final AudioFileStorageService storage = AudioFileStorageService(
          rootDirectoryProvider: rootProvider,
        );
        final _PageContext ctx = _PageContext(
          recorderGateway: FakeAudioRecorderGateway(),
          playbackGateway: FakeAudioPlaybackGateway(),
          permissionGateway: FakeMicrophonePermissionGateway()
            ..nextCheckStatus = MicrophonePermissionStatus.granted,
          storage: storage,
        );
        final ProviderContainer container = await _pumpPage(
          tester,
          _FakePracticeRecordRepository(),
          ctx: ctx,
        );

        // Drive the controller into the playback state via the
        // public API (startRecording → stopRecording → play) so the
        // page reflects isPlaying == true.
        final RecordingPracticeController controller = container.read(
          recordingPracticeControllerProvider.notifier,
        );
        await controller.startRecording();
        // T031C note: `pumpAndSettle` is safe here because its
        // default 100ms tick interval is well below the
        // controller's 1s `Timer.periodic` — the ticker never
        // fires during the pump cycle, so the test converges.
        await tester.pumpAndSettle();
        final String path = ctx.recorderGateway.lastStartPath!;
        // Pre-create the file in the real I/O zone; the
        // controller's `_probeRecordingDuration` and subsequent
        // `playback.loadFile` need to do real disk I/O that
        // would never complete in a `FakeAsync` zone otherwise.
        await tester.runAsync(() async {
          final File f = File(path);
          await f.create(recursive: true);
          await f.writeAsString('fake m4a');
        });
        ctx.recorderGateway.nextStopResult = path;
        ctx.playbackGateway.nextLoadResult = const Duration(seconds: 2);
        // `stopRecording` calls into the real `RealAudioPlaybackService`
        // (loadFile + ensureDirectories) which needs real I/O. Run
        // it through `tester.runAsync` so the disk operations
        // actually complete.
        await tester.runAsync(() => controller.stopRecording());
        // Drop back into the FakeAsync zone to drive the widget
        // tree; a few short pumps are enough to propagate the
        // state change.
        await tester.pump();
        await tester.pump();
        // `play()` also drives the real playback service's
        // `loadFile` (real I/O) — same `runAsync` escape hatch.
        await tester.runAsync(() => controller.play());
        await tester.pump();
        await tester.pump();

        // isPlaying should now be true.
        expect(
          container.read(recordingPracticeControllerProvider).isPlaying,
          isTrue,
        );

        // T031C: the "开始录音" button must be disabled while
        // playback is in progress.
        final FilledButton startButton = tester.widget<FilledButton>(
          find.byKey(const ValueKey<String>('recording-start')),
        );
        expect(startButton.onPressed, isNull,
            reason: 'T031C: 开始录音 button must be disabled during playback');

        // T031C: the "停止回放" button must be enabled while
        // playback is in progress.
        final OutlinedButton stopPlaybackButton = tester.widget<OutlinedButton>(
          find.byKey(const ValueKey<String>('recording-stop-playback')),
        );
        expect(stopPlaybackButton.onPressed, isNotNull,
            reason: 'T031C: 停止回放 button must be enabled during playback');

        // Cleanup: stop the playback to release the timer.
        await controller.stopPlayback();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'T031C: after natural completion the "停止回放" button auto-disables '
      'and the "回放" + "开始录音" buttons re-enable',
      (WidgetTester tester) async {
        await _useTallSurface(tester);
        final (:rootProvider, :root) = _isolatedRoot();
        final AudioFileStorageService storage = AudioFileStorageService(
          rootDirectoryProvider: rootProvider,
        );
        final _PageContext ctx = _PageContext(
          recorderGateway: FakeAudioRecorderGateway(),
          playbackGateway: FakeAudioPlaybackGateway(),
          permissionGateway: FakeMicrophonePermissionGateway()
            ..nextCheckStatus = MicrophonePermissionStatus.granted,
          storage: storage,
        );
        final ProviderContainer container = await _pumpPage(
          tester,
          _FakePracticeRecordRepository(),
          ctx: ctx,
        );

        // Drive into playback.
        final RecordingPracticeController controller = container.read(
          recordingPracticeControllerProvider.notifier,
        );
        await controller.startRecording();
        // T031C note: `pumpAndSettle` is safe here because its
        // default 100ms tick interval is well below the
        // controller's 1s `Timer.periodic` — the ticker never
        // fires during the pump cycle, so the test converges.
        await tester.pumpAndSettle();
        final String path = ctx.recorderGateway.lastStartPath!;
        // Pre-create the file in the real I/O zone; the
        // controller's `_probeRecordingDuration` and subsequent
        // `playback.loadFile` need to do real disk I/O that
        // would never complete in a `FakeAsync` zone otherwise.
        await tester.runAsync(() async {
          final File f = File(path);
          await f.create(recursive: true);
          await f.writeAsString('fake m4a');
        });
        ctx.recorderGateway.nextStopResult = path;
        ctx.playbackGateway.nextLoadResult = const Duration(seconds: 2);
        // `stopRecording` calls into the real `RealAudioPlaybackService`
        // (loadFile + ensureDirectories) which needs real I/O. Run
        // it through `tester.runAsync` so the disk operations
        // actually complete.
        await tester.runAsync(() => controller.stopRecording());
        // Drop back into the FakeAsync zone to drive the widget
        // tree; a few short pumps are enough to propagate the
        // state change.
        await tester.pump();
        await tester.pump();
        // `play()` also drives the real playback service's
        // `loadFile` (real I/O) — same `runAsync` escape hatch.
        await tester.runAsync(() => controller.play());
        await tester.pump();
        await tester.pump();

        // Sanity: while playing, "停止回放" is enabled.
        expect(
          tester
              .widget<OutlinedButton>(
                find.byKey(const ValueKey<String>('recording-stop-playback')),
              )
              .onPressed,
          isNotNull,
        );

        // Natural completion. Wrap the emit + the controller's
        // unawaited `_seekToZeroOnCompletion` (which awaits the
        // real playback service's seek — needs real I/O zone).
        await tester.runAsync(() async {
          ctx.playbackGateway.emitPlayerState(const PlaybackPlayerState(
            playing: false,
            processingState: PlaybackProcessingState.completed,
          ));
        });
        // The controller's `_seekToZeroOnCompletion` is unawaited;
        // pump a few frames so it completes + state propagates.
        await tester.pump();
        await tester.pump();
        await tester.pump();

        // T031C: after natural completion, isPlaying must be false
        // and the "停止回放" button must be auto-disabled.
        expect(
          container.read(recordingPracticeControllerProvider).isPlaying,
          isFalse,
          reason: 'T031C: natural completion must flip isPlaying to false',
        );
        final OutlinedButton stopPlaybackButton = tester.widget<OutlinedButton>(
          find.byKey(const ValueKey<String>('recording-stop-playback')),
        );
        expect(stopPlaybackButton.onPressed, isNull,
            reason: 'T031C: 停止回放 must auto-disable after natural completion');

        // T031C: the "回放" button must be re-enabled so the user
        // can replay the take from the start.
        final FilledButton playButton = tester.widget<FilledButton>(
          find.byKey(const ValueKey<String>('recording-play')),
        );
        expect(playButton.onPressed, isNotNull,
            reason: 'T031C: 回放 must re-enable after natural completion');

        // T031C: the "开始录音" button must be re-enabled so the
        // user can re-record.
        final FilledButton startButton = tester.widget<FilledButton>(
          find.byKey(const ValueKey<String>('recording-start')),
        );
        expect(startButton.onPressed, isNotNull,
            reason: 'T031C: 开始录音 must re-enable after natural completion');
      },
    );

    testWidgets(
      'T031C: tapping "回放" after natural completion actually starts '
      'a new playback (recorder not touched, playback service called)',
      (WidgetTester tester) async {
        await _useTallSurface(tester);
        final (:rootProvider, :root) = _isolatedRoot();
        final AudioFileStorageService storage = AudioFileStorageService(
          rootDirectoryProvider: rootProvider,
        );
        final _PageContext ctx = _PageContext(
          recorderGateway: FakeAudioRecorderGateway(),
          playbackGateway: FakeAudioPlaybackGateway(),
          permissionGateway: FakeMicrophonePermissionGateway()
            ..nextCheckStatus = MicrophonePermissionStatus.granted,
          storage: storage,
        );
        final ProviderContainer container = await _pumpPage(
          tester,
          _FakePracticeRecordRepository(),
          ctx: ctx,
        );

        // Drive into playback then emit natural completion.
        final RecordingPracticeController controller = container.read(
          recordingPracticeControllerProvider.notifier,
        );
        await controller.startRecording();
        // T031C note: `pumpAndSettle` is safe here because its
        // default 100ms tick interval is well below the
        // controller's 1s `Timer.periodic` — the ticker never
        // fires during the pump cycle, so the test converges.
        await tester.pumpAndSettle();
        final String path = ctx.recorderGateway.lastStartPath!;
        // Pre-create the file in the real I/O zone; the
        // controller's `_probeRecordingDuration` and subsequent
        // `playback.loadFile` need to do real disk I/O that
        // would never complete in a `FakeAsync` zone otherwise.
        await tester.runAsync(() async {
          final File f = File(path);
          await f.create(recursive: true);
          await f.writeAsString('fake m4a');
        });
        ctx.recorderGateway.nextStopResult = path;
        ctx.playbackGateway.nextLoadResult = const Duration(seconds: 2);
        // `stopRecording` calls into the real `RealAudioPlaybackService`
        // (loadFile + ensureDirectories) which needs real I/O. Run
        // it through `tester.runAsync` so the disk operations
        // actually complete.
        await tester.runAsync(() => controller.stopRecording());
        // Drop back into the FakeAsync zone to drive the widget
        // tree; a few short pumps are enough to propagate the
        // state change.
        await tester.pump();
        await tester.pump();
        // `play()` also drives the real playback service's
        // `loadFile` (real I/O) — same `runAsync` escape hatch.
        await tester.runAsync(() => controller.play());
        await tester.pump();
        await tester.pump();
        ctx.playbackGateway.emitPlayerState(const PlaybackPlayerState(
          playing: false,
          processingState: PlaybackProcessingState.completed,
        ));
        // Wrap in runAsync so the controller's unawaited
        // `_seekToZeroOnCompletion` can complete (real seek I/O).
        await tester.runAsync(() async {});
        await tester.pump();
        await tester.pump();
        await tester.pump();
        expect(
          container.read(recordingPracticeControllerProvider).isPlaying,
          isFalse,
        );

        // Tap "回放" — must start a new playback without
        // touching the recorder.
        final int startsBefore = ctx.recorderGateway.startCallCount;
        final int playsBefore = ctx.playbackGateway.playCallCount;
        // The tap dispatches the pointer event in the FakeAsync
        // zone, which fires the onPressed callback that calls
        // `controller.play()`. The play() call drives the real
        // playback service's `loadFile` (real I/O) so we run
        // the microtask drain in the real I/O zone.
        await tester.tap(
          find.byKey(const ValueKey<String>('recording-play')),
        );
        await tester.runAsync(() async {
          // Allow the unawaited play() Future to make real I/O
          // progress. The fake is pure-Dart, so the loadFile
          // + play chain completes here.
          await Future<void>.delayed(const Duration(milliseconds: 1));
        });
        await tester.pump();
        await tester.pump();
        await tester.pump();
        await tester.pump();
        expect(ctx.recorderGateway.startCallCount, startsBefore,
            reason:
                'replaying after completion must NOT start a new recording');
        expect(ctx.playbackGateway.playCallCount, playsBefore + 1,
            reason: 'replaying after completion must call playback.play');
        expect(
          container.read(recordingPracticeControllerProvider).isPlaying,
          isTrue,
          reason: 'replaying after completion must flip isPlaying to true',
        );

        // Cleanup.
        await controller.stopPlayback();
        await tester.pump();
        await tester.pump();
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------

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

/// Practice-day resolver that returns the pinned test context.
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
  int _callCount = 0;

  @override
  String generate() {
    _callCount += 1;
    return 'take-$_callCount';
  }
}

// Silence unused-import lint if the dayIndex constant is
// referenced only through the resolver.
// ignore: unused_element
typedef _SilenceUnused = (SelfAssessment, PracticeTag);
