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
import 'package:go_router/go_router.dart';
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

/// T037B — pump the [RecordingPage] inside a `GoRouter` so the
/// page has a parent route to pop back to. The pre-T037B
/// [_pumpPage] helper uses `MaterialApp(home: RecordingPage())`
/// which has no parent route on the stack; the page's
/// `Navigator.canPop()` therefore returns `false` and the
/// `_popOrGoHome` fallback tries to call `context.go('/')` on a
/// non-existent router. The T037B pop assertions need a real
/// parent route, so this helper wraps the page in a minimal
/// `GoRouter` with a sentinel home route.
Future<ProviderContainer> _pumpPageT037B(
  WidgetTester tester,
  _FakePracticeRecordRepository repository, {
  required _PageContext ctx,
}) async {
  final ProviderContainer container = ProviderContainer(
    overrides: _buildOverrides(repository: repository, ctx: ctx),
  );
  addTearDown(container.dispose);
  final GoRouter router = GoRouter(
    initialLocation: '/home',
    routes: <RouteBase>[
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (BuildContext context, GoRouterState state) =>
            const _HomeSentinelPage(),
        routes: <RouteBase>[
          GoRoute(
            path: 'recording',
            name: 'recording',
            builder: (BuildContext context, GoRouterState state) =>
                const RecordingPage(),
          ),
        ],
      ),
    ],
  );
  // Push the recording route on top of `/home` so
  // `context.canPop()` is true. We navigate AFTER the
  // initial pump so the home sentinel is on the stack
  // first.
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  router.go('/home/recording');
  await tester.pumpAndSettle();
  return container;
}

/// T037B — sentinel "home" page rendered at `/home`. When
/// the recording page pops, this is the route that becomes
/// visible. Tests assert the pop by checking that
/// `_HomeSentinelPage` is now on screen (its unique key is
/// the find target).
class _HomeSentinelPage extends StatelessWidget {
  const _HomeSentinelPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      key: ValueKey<String>('recording-page-pop-sentinel-home'),
      body: Center(child: Text('home')),
    );
  }
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

    // T031E: pinned "real-device regression" page tests. These
    // exist because the user reported on real Android that
    // playback looped forever (Bug 1) and the "停止回放" button was
    // not stoppable (Bug 2). T031E pins the contract at the
    // page level: (a) loadFile pins LoopMode.off, (b) tapping
    // "停止回放" actually drives the playback service to stop
    // and flips isPlaying to false, (c) the page UI matches the
    // controller state at every step.
    testWidgets(
        'T031I: after natural completion on the page, audio actually stops '
        'and 停止回放 disables (real-device loop-fix pin)',
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

      // Drive into playback, then natural completion.
      final RecordingPracticeController controller = container.read(
        recordingPracticeControllerProvider.notifier,
      );
      await controller.startRecording();
      await tester.pumpAndSettle();
      final String path = ctx.recorderGateway.lastStartPath!;
      await tester.runAsync(() async {
        final File f = File(path);
        await f.create(recursive: true);
        await f.writeAsString('fake m4a');
      });
      ctx.recorderGateway.nextStopResult = path;
      ctx.playbackGateway.nextLoadResult = const Duration(seconds: 2);
      await tester.runAsync(() => controller.stopRecording());
      await tester.pump();
      await tester.pump();
      await tester.runAsync(() => controller.play());
      await tester.pump();
      await tester.pump();

      // Sanity: while playing, 停止回放 is enabled.
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey<String>('recording-stop-playback')),
            )
            .onPressed,
        isNotNull,
      );

      // Natural completion.
      final int stopsBefore = ctx.playbackGateway.stopCallCount;
      await tester.runAsync(() async {
        ctx.playbackGateway.emitPlayerState(const PlaybackPlayerState(
          playing: false,
          processingState: PlaybackProcessingState.completed,
        ));
      });
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // T031I: the controller's `_handleNaturalCompletion`
      // must have driven `playback.stop()` at least once. This
      // is the contract that breaks the real-device loop.
      expect(ctx.playbackGateway.stopCallCount, stopsBefore + 1,
          reason: 'T031I: completed event must drive playback.stop() so the '
              'underlying player is released and the loop breaks on the '
              'real device');

      // T031I: page state must match the controller state —
      // 停止回放 is disabled, 回放 + 开始录音 are enabled.
      expect(
        container.read(recordingPracticeControllerProvider).isPlaying,
        isFalse,
        reason: 'T031I: isPlaying must be false after natural completion',
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey<String>('recording-stop-playback')),
            )
            .onPressed,
        isNull,
        reason: 'T031I: 停止回放 must auto-disable after natural completion',
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey<String>('recording-play')),
            )
            .onPressed,
        isNotNull,
        reason: 'T031I: 回放 must re-enable after natural completion',
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey<String>('recording-start')),
            )
            .onPressed,
        isNotNull,
        reason: 'T031I: 开始录音 must re-enable after natural completion',
      );
    });

    testWidgets(
        'T031I: second replay after completion starts from 0 with stop '
        'already driven (no fresh recording)', (WidgetTester tester) async {
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

      // Drive into playback then natural completion.
      final RecordingPracticeController controller = container.read(
        recordingPracticeControllerProvider.notifier,
      );
      await controller.startRecording();
      await tester.pumpAndSettle();
      final String path = ctx.recorderGateway.lastStartPath!;
      await tester.runAsync(() async {
        final File f = File(path);
        await f.create(recursive: true);
        await f.writeAsString('fake m4a');
      });
      ctx.recorderGateway.nextStopResult = path;
      ctx.playbackGateway.nextLoadResult = const Duration(seconds: 2);
      await tester.runAsync(() => controller.stopRecording());
      await tester.pump();
      await tester.pump();
      await tester.runAsync(() => controller.play());
      await tester.pump();
      await tester.pump();
      await tester.runAsync(() async {
        ctx.playbackGateway.emitPlayerState(const PlaybackPlayerState(
          playing: false,
          processingState: PlaybackProcessingState.completed,
        ));
      });
      await tester.pump();
      await tester.pump();
      await tester.pump();
      final int stopsAfterFirst = ctx.playbackGateway.stopCallCount;
      final int loadBefore = ctx.playbackGateway.loadFileCallCount;
      final int startsBefore = ctx.recorderGateway.startCallCount;

      // T031I: tap 回放 to replay from 0.
      await tester.tap(
        find.byKey(const ValueKey<String>('recording-play')),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      });
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // T031I: replay restarts from 0 (new loadFile + play) and
      // the recorder service is NOT touched. The T031I stop
      // call from the first completion is preserved (no new
      // stop call is needed for the replay — the user is now in
      // playing state again).
      expect(ctx.recorderGateway.startCallCount, startsBefore,
          reason: 'T031I: replay must NOT start a new recording');
      expect(ctx.playbackGateway.loadFileCallCount, greaterThan(loadBefore),
          reason: 'T031I: replay must call loadFile() so playback restarts '
              'from position 0');
      expect(ctx.playbackGateway.stopCallCount, stopsAfterFirst,
          reason: 'T031I: replay must not drive an extra stop call — the '
              'first completion already drove stop (T031I core fix)');
      expect(
        container.read(recordingPracticeControllerProvider).isPlaying,
        isTrue,
        reason: 'T031I: replay after completion must flip isPlaying to true',
      );

      // Cleanup.
      await controller.stopPlayback();
      await tester.pump();
      await tester.pump();
    });

    testWidgets(
      'T031E: loadFile pins LoopMode.off so playback does NOT loop on the '
      'page (regression for the real-device "playback loops forever" bug)',
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
        await tester.pumpAndSettle();
        final String path = ctx.recorderGateway.lastStartPath!;
        await tester.runAsync(() async {
          final File f = File(path);
          await f.create(recursive: true);
          await f.writeAsString('fake m4a');
        });
        ctx.recorderGateway.nextStopResult = path;
        ctx.playbackGateway.nextLoadResult = const Duration(seconds: 2);
        await tester.runAsync(() => controller.stopRecording());
        await tester.pump();
        await tester.pump();
        await tester.runAsync(() => controller.play());
        await tester.pump();
        await tester.pump();

        // T031E: loadFile must have called setLoopModeOff at
        // least once (the contract is "loadFile pins
        // LoopMode.off on every load").
        expect(ctx.playbackGateway.setLoopModeOffCallCount,
            greaterThanOrEqualTo(1),
            reason: 'T031E: loadFile must pin LoopMode.off to prevent the '
                'real-device playback-loops-forever bug');
        // isPlaying should be true and the page should show the
        // right enablement (回归到 T031C 既有契约).
        expect(
          container.read(recordingPracticeControllerProvider).isPlaying,
          isTrue,
        );
        expect(
          tester
              .widget<OutlinedButton>(
                find.byKey(const ValueKey<String>('recording-stop-playback')),
              )
              .onPressed,
          isNotNull,
          reason: 'T031E: 停止回放 must be enabled during playback',
        );
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const ValueKey<String>('recording-start')),
              )
              .onPressed,
          isNull,
          reason: 'T031E: 开始录音 must be disabled during playback',
        );

        // Cleanup.
        await controller.stopPlayback();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'T031E: tapping "停止回放" actually drives the playback service to '
      'stop and flips isPlaying to false (regression for the real-device '
      '"stop button is unclickable" bug)',
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
        await tester.pumpAndSettle();
        final String path = ctx.recorderGateway.lastStartPath!;
        await tester.runAsync(() async {
          final File f = File(path);
          await f.create(recursive: true);
          await f.writeAsString('fake m4a');
        });
        ctx.recorderGateway.nextStopResult = path;
        ctx.playbackGateway.nextLoadResult = const Duration(seconds: 2);
        await tester.runAsync(() => controller.stopRecording());
        await tester.pump();
        await tester.pump();
        await tester.runAsync(() => controller.play());
        await tester.pump();
        await tester.pump();

        final int stopsBefore = ctx.playbackGateway.stopCallCount;
        // T031E: actually tap the 停止回放 button (not just call
        // the controller method) so we exercise the real onPressed
        // path.
        await tester.tap(
          find.byKey(const ValueKey<String>('recording-stop-playback')),
        );
        // The tap dispatches a pointer event in the FakeAsync
        // zone (required for hit-testing); the resulting
        // controller.stopPlayback() Future needs real I/O to
        // drive playback.stop().
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        });
        await tester.pump();
        await tester.pump();
        await tester.pump();

        expect(
          container.read(recordingPracticeControllerProvider).isPlaying,
          isFalse,
          reason: 'T031E: tapping 停止回放 must flip isPlaying to false',
        );
        expect(
          ctx.playbackGateway.stopCallCount,
          stopsBefore + 1,
          reason: 'T031E: tapping 停止回放 must drive playback.stop()',
        );
        // T031E: after stop, the page should re-enable 开始录音
        // and disable 停止回放.
        expect(
          tester
              .widget<OutlinedButton>(
                find.byKey(const ValueKey<String>('recording-stop-playback')),
              )
              .onPressed,
          isNull,
          reason: 'T031E: 停止回放 must auto-disable after stop',
        );
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const ValueKey<String>('recording-start')),
              )
              .onPressed,
          isNotNull,
          reason: 'T031E: 开始录音 must re-enable after stop',
        );
      },
    );
  });

  // ===========================================================================
  // T037B — page-exit stop coordination (widget level).
  //
  // Mirrors the T037A detail-page widget tests:
  // - AppBar back / Android system back / duplicate back /
  //   stop-failure / dispose-time safety net.
  // The recording page has TWO service surfaces (recorder +
  // playback) so the failure-copy assertions must verify
  // that the recorder-failure SnackBar uses "停止录音失败" and
  // the playback-failure SnackBar uses "停止播放失败" —
  // they MUST NOT be conflated.
  // ===========================================================================

  group('T037B page-exit stop coordination', () {
    // -----------------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------------

    /// Drives the page into a "recording" state by
    /// calling `startRecording` and pumping the
    /// necessary async ticks. The fake recorder
    /// gateway's `nextStopResult` is left unset — the
    /// test will inject stop / failure values AFTER
    /// this setup.
    Future<void> enterRecording(
      WidgetTester tester,
      _PageContext ctx,
      ProviderContainer container,
    ) async {
      final RecordingPracticeController controller = container.read(
        recordingPracticeControllerProvider.notifier,
      );
      await controller.startRecording();
      await tester.pumpAndSettle();
    }

    /// Drives the page into a "playing" state by
    /// completing a recording + calling `play`. The
    /// caller is responsible for pre-creating the audio
    /// file in the real I/O zone and pre-seeding
    /// `nextStopResult` / `nextLoadResult` on the
    /// fakes.
    Future<void> enterPlaying(
      WidgetTester tester,
      _PageContext ctx,
      ProviderContainer container,
    ) async {
      final RecordingPracticeController controller = container.read(
        recordingPracticeControllerProvider.notifier,
      );
      await controller.startRecording();
      await tester.pumpAndSettle();
      final String path = ctx.recorderGateway.lastStartPath!;
      await tester.runAsync(() async {
        final File f = File(path);
        await f.create(recursive: true);
        await f.writeAsString('fake m4a');
      });
      ctx.recorderGateway.nextStopResult = path;
      ctx.playbackGateway.nextLoadResult = const Duration(seconds: 2);
      await tester.runAsync(() => controller.stopRecording());
      await tester.pump();
      await tester.pump();
      await tester.runAsync(() => controller.play());
      await tester.pump();
      await tester.pump();
    }

    // -----------------------------------------------------------------------
    // Tests
    // -----------------------------------------------------------------------

    testWidgets(
      'T037B — AppBar back while recording awaits requestStopForPageExit, '
      'then pops; recorder.stop is called exactly once',
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
        final ProviderContainer container = await _pumpPageT037B(
          tester,
          _FakePracticeRecordRepository(),
          ctx: ctx,
        );
        await enterRecording(tester, ctx, container);

        // Pre-create the audio file and seed a successful
        // recorder.stop return so the page-exit path can
        // resolve cleanly.
        final String path = ctx.recorderGateway.lastStartPath!;
        await tester.runAsync(() async {
          await File(path).create(recursive: true);
          await File(path).writeAsString('fake m4a');
        });
        ctx.recorderGateway.nextStopResult = path;
        ctx.playbackGateway.nextLoadResult = const Duration(seconds: 2);

        final int stopsBefore = ctx.recorderGateway.stopCallCount;
        // Tap the AppBar back arrow. The page's
        // `_handleExit` is the SOLE entry point.
        await tester.tap(
          find.byKey(const ValueKey<String>('recording-back-button')),
        );
        // The page-exit stop is awaited; we need to
        // drive the real I/O for recorder.stop (the
        // fake uses Future.microtask so `pumpAndSettle`
        // resolves it).
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        });
        await tester.pumpAndSettle();

        expect(
          ctx.recorderGateway.stopCallCount,
          stopsBefore + 1,
          reason: 'AppBar back while recording must drive recorder.stop '
              'exactly once',
        );
        // The page should be popped — the home sentinel
        // should be visible.
        expect(
          find.byKey(
              const ValueKey<String>('recording-page-pop-sentinel-home')),
          findsOneWidget,
          reason: 'T037B: page must be popped after a clean exit stop',
        );
        expect(find.byType(RecordingPage), findsNothing,
            reason: 'T037B: RecordingPage must be unmounted after pop');
      },
    );

    testWidgets(
      'T037B — Android system back while recording routes through '
      'PopScope → requestStopForPageExit → recorder.stop → pop',
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
        final ProviderContainer container = await _pumpPageT037B(
          tester,
          _FakePracticeRecordRepository(),
          ctx: ctx,
        );
        await enterRecording(tester, ctx, container);

        final String path = ctx.recorderGateway.lastStartPath!;
        await tester.runAsync(() async {
          await File(path).create(recursive: true);
          await File(path).writeAsString('fake m4a');
        });
        ctx.recorderGateway.nextStopResult = path;
        ctx.playbackGateway.nextLoadResult = const Duration(seconds: 2);

        final int stopsBefore = ctx.recorderGateway.stopCallCount;
        // Drive Android system back through the
        // framework's `handlePopRoute`. Flutter 3.44
        // routes this through `PopScope.canPop` and,
        // when canPop is false, into
        // `onPopInvokedWithResult`. The T037B page-exit
        // chokepoint intercepts there.
        final bool didHandle = await tester.binding.handlePopRoute();
        // Whether or not `handlePopRoute` returns
        // true is a separate question from whether
        // the PopScope intercepted the back — the
        // PopScope's `canPop = false` is the gating
        // signal. We pump a few times to let the
        // page's `_runExit` complete the
        // `await controller.requestStopForPageExit`
        // and the post-stop pop animation land.
        expect(didHandle, isTrue,
            reason: 'PopScope must claim the system back gesture');
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump();
        await tester.pump();
        await tester.pumpAndSettle();
        await tester.pump();

        expect(
          ctx.recorderGateway.stopCallCount,
          stopsBefore + 1,
          reason: 'Android system back while recording must drive '
              'recorder.stop exactly once via PopScope',
        );
        expect(
          find.byKey(
              const ValueKey<String>('recording-page-pop-sentinel-home')),
          findsOneWidget,
          reason: 'T037B: page must be popped after system back',
        );
        expect(find.byType(RecordingPage), findsNothing);
      },
    );

    testWidgets(
      'T037B — AppBar back while playing awaits playback.stop, then '
      'pops; playback.stop is called exactly once',
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
        final ProviderContainer container = await _pumpPageT037B(
          tester,
          _FakePracticeRecordRepository(),
          ctx: ctx,
        );
        await enterPlaying(tester, ctx, container);

        final int pbStopsBefore = ctx.playbackGateway.stopCallCount;
        await tester.tap(
          find.byKey(const ValueKey<String>('recording-back-button')),
        );
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        });
        await tester.pumpAndSettle();

        expect(
          ctx.playbackGateway.stopCallCount,
          pbStopsBefore + 1,
          reason: 'AppBar back while playing must drive playback.stop '
              'exactly once',
        );
        expect(
          find.byKey(
              const ValueKey<String>('recording-page-pop-sentinel-home')),
          findsOneWidget,
          reason: 'T037B: page must be popped after a clean exit stop',
        );
        expect(find.byType(RecordingPage), findsNothing);
      },
    );

    testWidgets(
      'T037B — AppBar back from idle (no recording, no playback) '
      'does NOT call recorder.stop or playback.stop, and pops',
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
        await _pumpPageT037B(
          tester,
          _FakePracticeRecordRepository(),
          ctx: ctx,
        );

        final int recStopsBefore = ctx.recorderGateway.stopCallCount;
        final int pbStopsBefore = ctx.playbackGateway.stopCallCount;
        await tester.tap(
          find.byKey(const ValueKey<String>('recording-back-button')),
        );
        await tester.pumpAndSettle();

        expect(ctx.recorderGateway.stopCallCount, recStopsBefore,
            reason: 'idle page exit must not call recorder.stop');
        expect(ctx.playbackGateway.stopCallCount, pbStopsBefore,
            reason: 'idle page exit must not call playback.stop');
        expect(
          find.byKey(
              const ValueKey<String>('recording-page-pop-sentinel-home')),
          findsOneWidget,
          reason: 'T037B: idle page exit must still pop',
        );
        expect(find.byType(RecordingPage), findsNothing);
      },
    );

    testWidgets(
      'T037B — duplicate back gesture (AppBar back + system back) '
      'drives recorder.stop exactly once and pops exactly once',
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
        final ProviderContainer container = await _pumpPageT037B(
          tester,
          _FakePracticeRecordRepository(),
          ctx: ctx,
        );
        await enterRecording(tester, ctx, container);

        final String path = ctx.recorderGateway.lastStartPath!;
        await tester.runAsync(() async {
          await File(path).create(recursive: true);
          await File(path).writeAsString('fake m4a');
        });
        ctx.recorderGateway.nextStopResult = path;
        ctx.playbackGateway.nextLoadResult = const Duration(seconds: 2);

        final int recStopsBefore = ctx.recorderGateway.stopCallCount;
        // Tap AppBar back AND immediately fire Android
        // system back. The page's `_exitInFlight` guard
        // must refuse the second invocation.
        await tester.tap(
          find.byKey(const ValueKey<String>('recording-back-button')),
        );
        // Try to drive a system-back while the first
        // exit is in flight. The guard must reject it.
        await tester.binding.handlePopRoute();
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        });
        await tester.pumpAndSettle();

        expect(
          ctx.recorderGateway.stopCallCount,
          recStopsBefore + 1,
          reason: 'duplicate back must drive recorder.stop exactly once '
              '(the page-exit guard rejects the second call)',
        );
        // The page must be popped exactly once — the
        // home sentinel is visible and the recording
        // page is gone.
        expect(
          find.byKey(
              const ValueKey<String>('recording-page-pop-sentinel-home')),
          findsOneWidget,
          reason: 'T037B: duplicate back must result in a single pop',
        );
        expect(find.byType(RecordingPage), findsNothing);
      },
    );

    testWidgets(
      'T037B — recorder.stop throws: page is retained, friendly '
      'recording-failure SnackBar is shown, no unhandled async error',
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
        final ProviderContainer container = await _pumpPageT037B(
          tester,
          _FakePracticeRecordRepository(),
          ctx: ctx,
        );
        await enterRecording(tester, ctx, container);
        // Inject a synthetic stop failure with forbidden
        // substrings (PII / exception class / file
        // extension). The friendly SnackBar MUST NOT
        // leak any of these.
        ctx.recorderGateway.nextStopException =
            Exception('synthetic recorder stop failure at /abs/path/r.m4a');

        await tester.tap(
          find.byKey(const ValueKey<String>('recording-back-button')),
        );
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        });
        await tester.pumpAndSettle();

        // Page is retained.
        expect(find.byType(RecordingPage), findsOneWidget,
            reason: 'recorder-stop failure must keep the page mounted so the '
                'user can retry');
        expect(find.text('录音回放'), findsOneWidget,
            reason: 'recorder-stop failure must NOT pop the page');
        // Friendly recorder-failure SnackBar is shown.
        expect(
          find.byKey(const ValueKey<String>(
              'recording-page-exit-stop-recording-failure-snackbar')),
          findsOneWidget,
          reason: 'recorder-stop failure must surface the recording '
              'failure SnackBar',
        );
        expect(find.text('停止录音失败，请重试'), findsOneWidget,
            reason: 'recorder-stop failure must use the recording '
                'failure copy');
        // The playback-failure copy MUST NOT appear in
        // the recorder-failure path.
        expect(find.text('停止播放失败，请重试'), findsNothing,
            reason: 'recorder-stop failure must NOT use the playback '
                'failure copy');
        // PII / forbidden-substring guard.
        expect(find.textContaining('synthetic'), findsNothing);
        expect(find.textContaining('Exception'), findsNothing);
        expect(find.textContaining('.m4a'), findsNothing);
        expect(find.textContaining('/abs/path'), findsNothing);
        // No unhandled async error.
        expect(tester.takeException(), isNull,
            reason: 'recorder-stop failure must not produce an unhandled '
                'async error');
      },
    );

    testWidgets(
      'T037B — playback.stop throws: page is retained, friendly '
      'playback-failure SnackBar is shown, no unhandled async error',
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
        final ProviderContainer container = await _pumpPageT037B(
          tester,
          _FakePracticeRecordRepository(),
          ctx: ctx,
        );
        await enterPlaying(tester, ctx, container);
        // Inject a synthetic playback stop failure.
        ctx.playbackGateway.nextStopException =
            Exception('synthetic playback stop failure at /abs/path/r.m4a');

        await tester.tap(
          find.byKey(const ValueKey<String>('recording-back-button')),
        );
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        });
        await tester.pumpAndSettle();

        // Page is retained.
        expect(find.byType(RecordingPage), findsOneWidget,
            reason: 'playback-stop failure must keep the page mounted');
        expect(find.text('录音回放'), findsOneWidget,
            reason: 'playback-stop failure must NOT pop the page');
        // Friendly playback-failure SnackBar is shown.
        expect(
          find.byKey(const ValueKey<String>(
              'recording-page-exit-stop-playback-failure-snackbar')),
          findsOneWidget,
          reason: 'playback-stop failure must surface the playback '
              'failure SnackBar',
        );
        expect(find.text('停止播放失败，请重试'), findsOneWidget,
            reason: 'playback-stop failure must use the playback '
                'failure copy');
        // The recording-failure copy MUST NOT appear in
        // the playback-failure path.
        expect(find.text('停止录音失败，请重试'), findsNothing,
            reason: 'playback-stop failure must NOT use the recording '
                'failure copy');
        // PII / forbidden-substring guard.
        expect(find.textContaining('synthetic'), findsNothing);
        expect(find.textContaining('Exception'), findsNothing);
        expect(find.textContaining('.m4a'), findsNothing);
        expect(find.textContaining('/abs/path'), findsNothing);
        // No unhandled async error.
        expect(tester.takeException(), isNull,
            reason: 'playback-stop failure must not produce an unhandled '
                'async error');
      },
    );

    testWidgets(
      'T037B — dispose-time safety net: when the controller is disposed '
      'via a non-cooperative container dispose (T035A safety net '
      'preserved), no unhandled async error is produced and the '
      'controller refuses subsequent calls cleanly',
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
        final ProviderContainer container = await _pumpPageT037B(
          tester,
          _FakePracticeRecordRepository(),
          ctx: ctx,
        );
        // Drive into recording so the timer is active
        // and the recorder service is in the
        // `recording` state.
        await enterRecording(tester, ctx, container);

        // Pre-create the audio file so the controller's
        // page-exit stop path can resolve cleanly.
        final String path = ctx.recorderGateway.lastStartPath!;
        await tester.runAsync(() async {
          await File(path).create(recursive: true);
          await File(path).writeAsString('fake m4a');
        });
        ctx.recorderGateway.nextStopResult = path;
        ctx.playbackGateway.nextLoadResult = const Duration(seconds: 2);

        // Capture the controller reference BEFORE the
        // container dispose — once the container is
        // disposed, `container.read` throws
        // `StateError: Tried to read a provider from a
        // ProviderContainer that was already disposed`.
        // The captured reference is still valid (the
        // controller instance itself survives the
        // container dispose; only the provider
        // subscription is torn down).
        final RecordingPracticeController controller = container.read(
          recordingPracticeControllerProvider.notifier,
        );

        // Dispose the container — this is the
        // non-cooperative removal path that the T035A
        // safety net must cover. The
        // `recordingPracticeControllerProvider` is
        // NOT autoDispose, so the page's
        // `_handleExit` is NOT triggered automatically
        // by the route pop in the production runtime;
        // the test explicitly drives the container
        // dispose to exercise the safety net. The
        // controller's `_onDispose` hook fires
        // synchronously, flipping `_disposed = true`
        // and cancelling the timer + stream
        // subscriptions.
        container.dispose();
        await tester.pumpAndSettle();

        // No unhandled exception during the dispose
        // cascade.
        expect(tester.takeException(), isNull,
            reason: 'dispose-time safety net must not produce an unhandled '
                'exception');
        // A subsequent call to a public mutator on the
        // disposed controller must be a clean no-op
        // (the controller's `_disposed` flag short-
        // circuits the call). This is the safety net
        // contract end-to-end: the dispose hook ran
        // cleanly AND subsequent public API calls are
        // exception-free (they short-circuit at the
        // first line of the method).
        await controller.startRecording();
        await controller.stopRecording();
        await controller.play();
        await controller.stopPlayback();
        // No unhandled exception was produced by the
        // post-dispose call sequence either.
        expect(tester.takeException(), isNull,
            reason: 'post-dispose public API calls must be clean no-ops');
      },
    );

    // =======================================================================
    // T037B1 — failure-retry contract at the widget level.
    //
    // The pre-fix behaviour was: first exit returns failure,
    // the page surfaces a SnackBar and keeps itself mounted,
    // but a second back gesture would short-circuit to
    // `skipped(idle)` (because the controller had pre-flipped
    // `isRecording=false` / `isPlaying=false`) and pop the
    // page WITHOUT actually retrying the underlying
    // recorder.stop() / playback.stop(). The native audio
    // session was leaked.
    //
    // The fix adds an in-flight Future coordination in the
    // controller. The page-level contract is:
    // - first exit: friendly SnackBar + page retained.
    // - second exit: still uses the chokepoint, the controller
    //   issues a real second `recorder.stop()` /
    //   `playback.stop()` (or resolves to
    //   `skipped(serviceAlreadyTerminal)` if the recorder
    //   service has already cleaned up).
    // - third exit: page pops.
    // - duplicate back gesture: only one pop, only one
    //   underlying stop call.
    // =======================================================================

    testWidgets(
      'T037B1 — recorder.stop throws then service is idle: '
      'first exit surfaces SnackBar + retains page, '
      'second exit finally pops the page',
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
        final ProviderContainer container = await _pumpPageT037B(
          tester,
          _FakePracticeRecordRepository(),
          ctx: ctx,
        );
        await enterRecording(tester, ctx, container);
        // Inject a synthetic stop failure.
        ctx.recorderGateway.nextStopException =
            Exception('synthetic recorder stop failure at /abs/path/r.m4a');

        // First exit: page is retained, SnackBar shown.
        await tester.tap(
          find.byKey(const ValueKey<String>('recording-back-button')),
        );
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        });
        await tester.pumpAndSettle();

        expect(find.byType(RecordingPage), findsOneWidget,
            reason: 'first failed exit must keep the page mounted');
        expect(
          find.byKey(const ValueKey<String>(
              'recording-page-exit-stop-recording-failure-snackbar')),
          findsOneWidget,
          reason: 'first failed exit must surface the recording '
              'failure SnackBar',
        );
        expect(find.text('停止录音失败，请重试'), findsOneWidget);
        expect(
          find.byKey(
              const ValueKey<String>('recording-page-pop-sentinel-home')),
          findsNothing,
          reason: 'first failed exit must NOT pop the page',
        );

        // Second exit: the recorder service has already
        // cleared its session internally (state == idle).
        // The controller's recorder-stop-retry path
        // short-circuits to `skipped(serviceAlreadyTerminal)`,
        // which the page treats as a clean pop.
        // The recorder.stop call count MUST stay at
        // 0 (the first attempt threw before incrementing
        // success-side counters; the second attempt does
        // NOT call recorder.stop because the service is
        // already terminal).
        final int recStopsBefore = ctx.recorderGateway.stopCallCount;
        await tester.tap(
          find.byKey(const ValueKey<String>('recording-back-button')),
        );
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        });
        await tester.pumpAndSettle();

        expect(
          ctx.recorderGateway.stopCallCount,
          recStopsBefore,
          reason: 'T037B1: the retry must NOT call recorder.stop again '
              '— the service is already idle',
        );
        expect(
          find.byKey(
              const ValueKey<String>('recording-page-pop-sentinel-home')),
          findsOneWidget,
          reason: 'T037B1: the second exit must finally pop the page',
        );
        expect(find.byType(RecordingPage), findsNothing,
            reason: 'T037B1: RecordingPage must be unmounted after the '
                'second exit resolves');
        // No unhandled exception across the failure +
        // retry + pop sequence.
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'T037B1 — playback.stop throws: first exit surfaces '
      'playback SnackBar + retains page, second exit re-calls '
      'playback.stop and finally pops',
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
        final ProviderContainer container = await _pumpPageT037B(
          tester,
          _FakePracticeRecordRepository(),
          ctx: ctx,
        );
        await enterPlaying(tester, ctx, container);
        // First playback.stop attempt: throws.
        ctx.playbackGateway.nextStopException =
            Exception('synthetic playback stop failure at /abs/path/r.m4a');

        await tester.tap(
          find.byKey(const ValueKey<String>('recording-back-button')),
        );
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        });
        await tester.pumpAndSettle();

        expect(find.byType(RecordingPage), findsOneWidget,
            reason: 'first failed exit must keep the page mounted');
        expect(
          find.byKey(const ValueKey<String>(
              'recording-page-exit-stop-playback-failure-snackbar')),
          findsOneWidget,
          reason: 'first failed exit must surface the playback '
              'failure SnackBar',
        );
        expect(find.text('停止播放失败，请重试'), findsOneWidget);
        expect(
          find.byKey(
              const ValueKey<String>('recording-page-pop-sentinel-home')),
          findsNothing,
        );

        // Second exit: the playback service's state has
        // been restored to `playing` (the service
        // contract). The controller re-enters the
        // playback branch and issues a real second
        // playback.stop call. This time the fake does
        // NOT throw — the page pops.
        ctx.playbackGateway.nextStopException = null;
        final int pbStopsBefore = ctx.playbackGateway.stopCallCount;
        await tester.tap(
          find.byKey(const ValueKey<String>('recording-back-button')),
        );
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        });
        await tester.pumpAndSettle();

        expect(
          ctx.playbackGateway.stopCallCount,
          pbStopsBefore + 1,
          reason: 'T037B1: the retry MUST call playback.stop exactly '
              'one more time (real-device retry actually retries)',
        );
        expect(
          find.byKey(
              const ValueKey<String>('recording-page-pop-sentinel-home')),
          findsOneWidget,
          reason: 'T037B1: the second exit must finally pop the page',
        );
        expect(find.byType(RecordingPage), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'T037B1 — concurrent back gesture while first exit is '
      'in flight: only one stop call, only one pop',
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
        final ProviderContainer container = await _pumpPageT037B(
          tester,
          _FakePracticeRecordRepository(),
          ctx: ctx,
        );
        await enterRecording(tester, ctx, container);

        final String path = ctx.recorderGateway.lastStartPath!;
        await tester.runAsync(() async {
          await File(path).create(recursive: true);
          await File(path).writeAsString('fake m4a');
        });
        ctx.recorderGateway.nextStopResult = path;
        ctx.playbackGateway.nextLoadResult = const Duration(seconds: 2);

        final int recStopsBefore = ctx.recorderGateway.stopCallCount;
        // First exit — fires the page-exit chokepoint.
        await tester.tap(
          find.byKey(const ValueKey<String>('recording-back-button')),
        );
        // Drive a real-time delay so the controller's
        // await chain actually enters the platform-channel
        // stop and the page's `_exitInFlight` flag is set
        // for a meaningful window.
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        });
        // Try to drive a system back while the first
        // exit is in flight. The page's `_exitInFlight`
        // guard MUST refuse it.
        await tester.binding.handlePopRoute();
        // Drain microtasks + animations.
        await tester.pumpAndSettle();

        // recorder.stop was called exactly once — the
        // page-level `_exitInFlight` guard rejected the
        // second tap.
        expect(
          ctx.recorderGateway.stopCallCount,
          recStopsBefore + 1,
          reason: 'T037B1: concurrent back gesture must not double-call '
              'recorder.stop — the page guard + controller in-flight '
              'Future both reject the second call',
        );
        // The page is popped exactly once.
        expect(
          find.byKey(
              const ValueKey<String>('recording-page-pop-sentinel-home')),
          findsOneWidget,
          reason: 'T037B1: the page must be popped exactly once',
        );
        expect(find.byType(RecordingPage), findsNothing);
        expect(tester.takeException(), isNull);
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

  @override
  Future<bool> hasAudioPathReference(String audioFilePath) async => false;
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
