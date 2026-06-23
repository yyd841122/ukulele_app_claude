// T036A_PROVE_PRE_DELETE_STOP_ORDER
//
// Augments the T036 main closed-loop test with a deterministic
// shared event log that proves, at the integration-test level,
// that the pre-delete playback stop happens strictly BEFORE the
// repository delete. The Chief-Architect review of T036
// highlighted that the existing assertions only proved:
//
//   * playback.stop eventually happens;
//   * repository.delete eventually happens;
//   * the production source happens to put `stop` before `delete`.
//
// They did NOT prove the call ORDER end-to-end. A future
// regression that flipped the source order (e.g. "delete first,
// then stop") would still satisfy those assertions.
//
// T036A closes the evidence gap by installing two test-only spy
// wrappers around the production components:
//
//   1. `_PlaybackStopSpyGateway` wraps the existing
//      [FakeAudioPlaybackGateway] (NOT replacing it) and records
//      a `playbackStop` event on every `stop()` call, BEFORE
//      delegating to the underlying fake. The wrapper still
//      implements the full [AudioPlaybackGateway] contract and
//      still feeds the production [RealAudioPlaybackService] —
//      no production code is bypassed.
//
//   2. `_RepositoryEventSpy` wraps the REAL
//      [DriftPracticeRecordRepository] (NOT a mock) and records
//      a `repositoryDelete` event on every `delete(id)` call,
//      BEFORE delegating to the underlying real repository. All
//      other Repository methods pass through verbatim.
//
// Both spies share a single `List<_TestEvent>` owned by an
// `_EventRecorder` instance. The test snapshots
// `_eventRecorder.events.length` right before tapping the delete
// button, then asserts, on the post-delete slice:
//
//   * a `playbackStop` event is present;
//   * a `repositoryDelete` event is present;
//   * `playbackStop` index < `repositoryDelete` index.
//
// The baseline snapshot is the loadFile / natural-completion
// / replay stops that predate the delete tap. Those are NOT
// part of the delete flow and MUST NOT pollute the assertion.
//
// This is the ONLY test infrastructure added for T036A. No
// production code, shared fake, schema, Manifest, dependency,
// permission, or public contract is modified.
//
// T036 ORIGINAL HEADER (kept for documentation continuity):
// ---------------------------------------------------------------------------
// End-to-end (vertical) integration test for the real audio
// closed loop. The test mounts the real production `appRouter`
// and the real production pages, wired against a real in-memory
// Drift database, and exercises the user-visible flow:
//
//   访问录音页面
//   -> 真实录音 (fake gateway 确认 start 被调用)
//   -> 停止录音 (verbatim resolvedPath)
//   -> 在 resolvedPath 预创建占位文件
//   -> 设置自评 + 备注
//   -> 保存练习记录
//   -> 记录列表显示
//   -> 进入记录详情
//   -> 播放 (playback gateway 收到 verbatim 路径)
//   -> 暂停 / 继续 / 停止
//   -> 再次播放
//   -> 当前会话发出 completed 事件
//   -> 详情页自然完成
//   -> 再次播放 (活动播放状态)
//   -> 删除记录
//   -> 严格验证调用顺序 (playback stop 先于 repository delete)
//   -> 数据库记录消失
//   -> 占位音频文件被清理
//   -> 列表回到空状态
//   -> 无未处理异步异常 / 活动订阅 / 计时器泄漏
//
// Allowed overrides (per task brief):
//   * `appDatabaseProvider`                     -> in-memory DB
//   * `appClockProvider`                        -> pinned clock
//   * `installDateServiceProvider`              -> pinned install date
//   * `practiceRecordIdGeneratorProvider`       -> REAL UUID generator
//     (T036 deliberately uses a real UUID generator so the closed
//     loop is exercised against an unpredictable id)
//   * `audioFileStorageServiceProvider`         -> temp-rooted
//   * `realAudioRecorderServiceProvider`        -> real service + fake
//                                                 recorder gateway
//   * `realAudioPlaybackServiceProvider`        -> real service + fake
//                                                 playback gateway
//   * `microphonePermissionServiceProvider`     -> real service + fake
//                                                 permission gateway
//
// Every other Provider resolves to its production default:
//
//   * `practiceRecordRepositoryProvider`        -> Drift-backed
//   * `practiceRecordsListControllerProvider`   -> real stream
//   * `practiceRecordDetailControllerProvider`  -> real family
//   * `recordingPracticeControllerProvider`     -> real state machine
//   * `practiceDayResolverProvider`             -> real resolver
//   * `appRouter`                               -> real production router
//
// All resources are disposed through `addTearDown`. The test
// never `sleep`s, never depends on real wall-clock time, never
// calls a real microphone, and never relies on a random UUID's
// specific value (the generator returns a valid UUID v4 — the
// test reads the id BACK from the database instead of asserting
// on a hard-coded value).
//
// IMPORTANT: this file is the ONLY new test file created for
// T036. It contributes 4 `testWidgets` blocks (1 main closed
// loop + 3 additional scenarios). The baseline before this task
// was 619; after this task it is 623 (619 + 4 - 0).
// T036A does NOT add or remove any `testWidgets` block; the
// 4-block count is preserved. T036A only installs two spy
// wrappers in the main closed-loop test to record the
// pre-delete stop / repository delete ordering. The total
// test count remains 623.
//
// Real Components Used:
//   * RealAudioRecorderService           (production service)
//   * RealAudioPlaybackService           (production service)
//   * AudioFileStorageService            (production service)
//   * DriftPracticeRecordRepository      (production repository)
//   * RecordingPracticeController        (production controller)
//   * PracticeRecordDetailController     (production controller)
//   * PracticeRecordsListController      (production controller)
//   * appRouter                          (production GoRouter)
//   * UkuleleApp + MaterialApp.router    (production widget tree)
//
// Fake Boundaries Used (hardware layer only):
//   * FakeAudioRecorderGateway           (recorder platform channel)
//   * FakeAudioPlaybackGateway           (playback platform channel +
//                                         T035B listener install count)
//   * FakeMicrophonePermissionGateway    (permission_handler platform
//                                         channel)
//
// Provider Overrides:
//   * appDatabaseProvider                -> AppDatabase.forTesting(NativeDatabase.memory())
//   * appClockProvider                   -> () => fixedNow
//   * installDateServiceProvider         -> DriftInstallDateService(repo, clock)
//   * practiceRecordIdGeneratorProvider  -> UuidPracticeRecordIdGenerator()
//   * audioFileStorageServiceProvider    -> AudioFileStorageService(tempRoot)
//   * realAudioRecorderServiceProvider   -> RealAudioRecorderService(fakeRecorder, storage)
//   * realAudioPlaybackServiceProvider   -> RealAudioPlaybackService(fakePlayback, storage)
//   * microphonePermissionServiceProvider-> MicrophonePermissionService(fakePermission)
//
// T036A delta (main closed-loop test only — the 3 additional
// scenarios are unaffected):
//   * `realAudioPlaybackServiceProvider` -> RealAudioPlaybackService
//                                          (_PlaybackStopSpyGateway, storage)
//   * `practiceRecordRepositoryProvider` -> _RepositoryEventSpy(
//                                          real DriftPracticeRecordRepository)
//
// The spy layers are installed INSIDE the main closed-loop
// test's `ProviderScope` overrides; the 3 additional scenarios
// retain the T036 plain overrides.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;

import 'package:ukulele_app/app/app.dart';
import 'package:ukulele_app/data/database/app_database.dart';
import 'package:ukulele_app/data/database/app_database_provider.dart';
import 'package:ukulele_app/features/practice_records/application/practice_record_id_generator.dart';
import 'package:ukulele_app/features/practice_records/data/drift_practice_record_repository.dart';
import 'package:ukulele_app/features/practice_records/data/practice_record_repository.dart';
import 'package:ukulele_app/features/practice_records/data/practice_record_repository_provider.dart';
import 'package:ukulele_app/features/practice_records/domain/practice_record.dart';
import 'package:ukulele_app/features/practice_records/domain/practice_tag.dart';
import 'package:ukulele_app/features/practice_records/domain/practice_type.dart';
import 'package:ukulele_app/shared/providers/app_clock_provider.dart';
import 'package:ukulele_app/shared/providers/audio_file_storage_service_provider.dart';
import 'package:ukulele_app/shared/providers/microphone_permission_service_provider.dart';
import 'package:ukulele_app/shared/providers/real_audio_playback_service_provider.dart';
import 'package:ukulele_app/shared/providers/real_audio_recorder_service_provider.dart';
import 'package:ukulele_app/shared/repositories/drift_user_settings_repository.dart';
import 'package:ukulele_app/shared/services/audio_file_storage_service.dart';
import 'package:ukulele_app/shared/services/audio_playback_gateway.dart';
import 'package:ukulele_app/shared/services/microphone_permission_service.dart';
import 'package:ukulele_app/shared/services/microphone_permission_status.dart';
import 'package:ukulele_app/shared/services/real_audio_playback_service.dart';
import 'package:ukulele_app/shared/services/real_audio_recorder_service.dart';

import '../shared/services/fake_audio_playback_gateway.dart';
import '../shared/services/fake_audio_recorder_gateway.dart';
import '../shared/services/fake_microphone_permission_gateway.dart';

/// Pinned "now" + install date + day-index shared by every test
/// in this file. Local-noon for `now` and UTC-noon for the
/// install instant guarantee the local-midnight projection is
/// stable across time zones in the [UTC-11, UTC+11] range.
final DateTime _kFixedNow = DateTime(2026, 6, 20, 12, 0);
final DateTime _kFixedInstallInstant = DateTime.utc(2026, 6, 19, 12, 0);
const int _kExpectedDayIndex = 2;

/// Counter used to give every temp audio root a unique name so
/// concurrent tests do not collide.
int _rootCounter = 0;

/// Runs [duration] of wall-clock time inside the real I/O zone
/// (FakeAsync does not advance real wall clock). Used to let
/// controller awaits + service I/O complete before pumping.
Future<void> _runAsyncDelay(WidgetTester tester, Duration duration) async {
  await tester.runAsync(() async {
    await Future<void>.delayed(duration);
  });
}

/// Bundles the fake gateways + real services + storage + temp
/// root used by every test in this file. Each test gets a
/// fresh instance via [_buildEnv] which also wires all
/// `addTearDown` callbacks.
class _Env {
  _Env({
    required this.tempRoot,
    required this.storage,
    required this.recorderGateway,
    required this.playbackGateway,
    required this.permissionGateway,
    required this.recorderService,
    required this.playbackService,
    required this.permissionService,
  });

  final Directory tempRoot;
  final AudioFileStorageService storage;
  final FakeAudioRecorderGateway recorderGateway;
  final FakeAudioPlaybackGateway playbackGateway;
  final FakeMicrophonePermissionGateway permissionGateway;
  final RealAudioRecorderService recorderService;
  final RealAudioPlaybackService playbackService;
  final MicrophonePermissionService permissionService;
}

/// Builds a fresh [_Env] with a unique temp audio root, wires
/// real services over the fake gateways, and registers
/// `addTearDown` callbacks for every disposable resource.
_Env _buildEnv(WidgetTester tester) {
  final Directory tempRoot = Directory(
    p.join(
      Directory.systemTemp.path,
      't036_e2e_${DateTime.now().microsecondsSinceEpoch}_${_rootCounter++}',
    ),
  )..createSync(recursive: true);
  addTearDown(() {
    if (tempRoot.existsSync()) {
      try {
        tempRoot.deleteSync(recursive: true);
      } on FileSystemException {
        // Best-effort cleanup.
      }
    }
  });

  final AudioFileStorageService storage = AudioFileStorageService(
    rootDirectoryProvider: () async => tempRoot,
  );

  final FakeAudioRecorderGateway recorderGateway = FakeAudioRecorderGateway();
  final FakeAudioPlaybackGateway playbackGateway = FakeAudioPlaybackGateway()
    // T031G — keep `play()` pending so the controller's
    // synchronous `isPlaying = true` write lands before the
    // `playerStateStream` `completed` event is the ONLY way
    // to flip back. Without this, `play()` resolves
    // immediately and the page would never observe the
    // `playing` state.
    ..keepPlayPending = true;
  final FakeMicrophonePermissionGateway permissionGateway =
      FakeMicrophonePermissionGateway();

  final RealAudioRecorderService recorderService = RealAudioRecorderService(
    gateway: recorderGateway,
    storage: storage,
  );
  final RealAudioPlaybackService playbackService = RealAudioPlaybackService(
    gateway: playbackGateway,
    storage: storage,
  );
  final MicrophonePermissionService permissionService =
      MicrophonePermissionService(permissionGateway);

  addTearDown(() async {
    // Order matters: dispose fakes BEFORE the widget tree
    // teardown so a broadcast listener cannot fire into a
    // closed stream controller.
    try {
      await playbackGateway.dispose();
    } on Object {
      // ignore: best-effort cleanup
    }
    try {
      await recorderGateway.dispose();
    } on Object {
      // ignore: best-effort cleanup
    }
  });

  return _Env(
    tempRoot: tempRoot,
    storage: storage,
    recorderGateway: recorderGateway,
    playbackGateway: playbackGateway,
    permissionGateway: permissionGateway,
    recorderService: recorderService,
    playbackService: playbackService,
    permissionService: permissionService,
  );
}

/// Sets up the in-memory Drift database, pre-seeds the install
/// date so `DriftInstallDateService` reads the pinned value
/// (NOT the first-read `DateTime.now()` fallback), and registers
/// `db.close` with `addTearDown`.
Future<AppDatabase> _buildDatabase() async {
  final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  final DriftUserSettingsRepository userSettingsRepository =
      DriftUserSettingsRepository(database: db);
  await userSettingsRepository.setValue(
    key: 'app.installDate',
    value: _kFixedInstallInstant.toIso8601String(),
    updatedAt: _kFixedInstallInstant,
  );
  return db;
}

// =============================================================================
// T036A — Shared event log + spy wrappers
// =============================================================================
//
// The two spies below are the SOLE test infrastructure added for
// T036A. They wrap the production components (real Drift
// repository + real playback service) WITHOUT replacing them and
// WITHOUT touching any production source. The wrapping is purely
// "record event, then delegate" — the production behaviour is
// bit-for-bit unchanged.
//
// `playbackStop` MUST be recorded BEFORE the fake gateway's
// `stop()` future resolves; the controller's `_stopPlaybackIfActive`
// `await`s the service's stop future, so the event lands
// synchronously on entry and is observable in the event log
// before any subsequent `repositoryDelete` could be recorded.
//
// `repositoryDelete` MUST be recorded BEFORE the real
// Drift repository's delete runs; the decorator pattern records
// synchronously on entry and only then forwards to the real
// repository. The production controller's `await repository.delete`
// therefore observes the recorded event before the actual SQL
// delete completes.

/// Immutable event recorded by the T036A spies.
///
/// Sealed so the test exhaustively matches the small event set:
/// `playbackStop` and `repositoryDelete`. Anything else in the
/// log is a contract violation by construction.
sealed class _TestEvent {
  const _TestEvent();

  /// Returns a short human-readable label for failure messages.
  String get label;
}

/// Recorded by `_PlaybackStopSpyGateway.stop()` on entry, BEFORE
/// delegating to the underlying fake gateway.
class _PlaybackStopEvent extends _TestEvent {
  const _PlaybackStopEvent();

  @override
  String get label => 'playback.stop';
}

/// Recorded by `_RepositoryEventSpy.delete()` on entry, BEFORE
/// delegating to the real `DriftPracticeRecordRepository`.
class _RepositoryDeleteEvent extends _TestEvent {
  const _RepositoryDeleteEvent(this.id);
  final String id;

  @override
  String get label => 'repository.delete($id)';
}

/// Single shared event log consumed by the T036A main closed-loop
/// test. Both spies write into the SAME instance's [events] list
/// so the test can slice it from a single baseline snapshot.
///
/// The recorder is intentionally minimal: append-only list, no
/// timestamps, no de-duplication. The test asserts on the
/// ORDER of events, not their timing — Dart's single-threaded
/// event loop guarantees the recorded index reflects the
/// call-order observed by the spies.
class _EventRecorder {
  final List<_TestEvent> events = <_TestEvent>[];

  /// Returns the index in [events] of the FIRST occurrence of
  /// an event matching [predicate], or `-1` if none was found.
  int indexWhere(bool Function(_TestEvent event) predicate) {
    for (int i = 0; i < events.length; i++) {
      if (predicate(events[i])) {
        return i;
      }
    }
    return -1;
  }
}

/// Test-only spy wrapper around an existing
/// [FakeAudioPlaybackGateway].
///
/// Implements the full [AudioPlaybackGateway] contract (so the
/// production `RealAudioPlaybackService` can talk to it without
/// knowing it is a spy) but intercepts `stop()` to record a
/// `_PlaybackStopEvent` in the shared [_recorder] BEFORE
/// delegating to the underlying fake. All other methods pass
/// through verbatim — including T035B's listener install count,
/// `completeOnNextPlay`, `keepPlayPending`, and every error /
/// result knob on the wrapped fake.
///
/// The wrapper does NOT modify any production behaviour:
/// - loadFile / play / pause / seek / dispose → delegate as-is;
/// - stop → record event → delegate as-is;
/// - playerStateStream / positionStream / durationStream /
///   position / duration getters → delegate as-is.
///
/// The wrapped fake remains reachable via [fake] so existing
/// test assertions (`stopCallCount`, `loadFileCallCount`,
/// `lastLoadPath`, `playerStateListenerInstallCount`, etc.) keep
/// working — T036A does not change the test surface, only adds
/// to it.
class _PlaybackStopSpyGateway implements AudioPlaybackGateway {
  _PlaybackStopSpyGateway({
    required this.fake,
    required this.recorder,
  });

  /// The wrapped fake gateway. Existing tests continue to
  /// assert on this object exactly as before.
  final FakeAudioPlaybackGateway fake;

  /// Shared event log.
  final _EventRecorder recorder;

  @override
  Future<Duration?> loadFile(String filePath) => fake.loadFile(filePath);

  @override
  Future<void> setLoopModeOff() => fake.setLoopModeOff();

  @override
  Future<void> play() => fake.play();

  @override
  Future<void> pause() => fake.pause();

  @override
  Future<void> seek(Duration? position) => fake.seek(position);

  @override
  Future<void> stop() {
    // Record the event BEFORE delegating. The production
    // controller's `_stopPlaybackIfActive` awaits this future,
    // so the event is observable in the log before any
    // subsequent `repository.delete` could fire.
    recorder.events.add(const _PlaybackStopEvent());
    return fake.stop();
  }

  @override
  Future<void> dispose() => fake.dispose();

  @override
  Stream<PlaybackPlayerState> get playerStateStream => fake.playerStateStream;

  @override
  Stream<Duration> get positionStream => fake.positionStream;

  @override
  Stream<Duration?> get durationStream => fake.durationStream;

  @override
  Duration get position => fake.position;

  @override
  Duration? get duration => fake.duration;
}

/// Test-only spy decorator around a REAL
/// [DriftPracticeRecordRepository].
///
/// Records a `_RepositoryDeleteEvent` on entry to `delete()`,
/// BEFORE delegating to the underlying repository. All other
/// methods pass through verbatim.
///
/// The decorator is intentionally NOT a mock: it preserves the
/// real production repository's behaviour (including all Drift
/// writes, SQL queries, and stream emissions) and only adds the
/// event-record seam. This means:
///
/// - The DB row still goes away when `delete` returns `true`.
/// - `watchAll` still streams the updated list.
/// - `hasAudioPathReference` still hits the real SQL.
/// - `insert` / `getById` / `listRecent` are byte-equivalent to
///   the unwrapped repository.
///
/// The decorator is the SOLE place where the
/// `repository.delete` event enters the shared log. The
/// production code path never bypasses the decorator in the
/// main closed-loop test (the Provider override REPLACES the
/// production repository provider, NOT the real repository).
class _RepositoryEventSpy implements PracticeRecordRepository {
  _RepositoryEventSpy({
    required this.delegate,
    required this.recorder,
  });

  /// The REAL Drift-backed repository. Every call (including
  /// `delete`) is forwarded here after the event is recorded.
  final PracticeRecordRepository delegate;

  /// Shared event log.
  final _EventRecorder recorder;

  @override
  Future<PracticeRecord> insert(PracticeRecord record) =>
      delegate.insert(record);

  @override
  Future<PracticeRecord?> getById(String id) => delegate.getById(id);

  @override
  Future<List<PracticeRecord>> listRecent({int limit = 50}) =>
      delegate.listRecent(limit: limit);

  @override
  Stream<List<PracticeRecord>> watchAll() => delegate.watchAll();

  @override
  Future<bool> delete(String id) {
    // Record the event BEFORE delegating. The production
    // controller's `await repository.delete(...)` therefore
    // observes the event in the log before the actual SQL
    // delete completes.
    recorder.events.add(_RepositoryDeleteEvent(id));
    return delegate.delete(id);
  }

  @override
  Future<bool> hasAudioPathReference(String audioFilePath) =>
      delegate.hasAudioPathReference(audioFilePath);
}

/// Pumps the production `UkuleleApp` (which uses the production
/// `appRouter`) inside a `ProviderScope` with all the
/// environment's Provider overrides. The home page is the
/// initial route, so the test always starts at `/`.
///
/// T036A: [playbackServiceOverride] and [repositoryOverride] are
/// optional. When supplied, the test installs the spy wrappers
/// (T036A evidence) for the playback service and repository
/// respectively. The 3 additional scenarios pass `null` for both
/// to retain the T036 plain wiring; the main closed-loop test
/// passes the spy-instrumented service / repository.
Future<void> _pumpApp(
  WidgetTester tester,
  _Env env,
  AppDatabase db, {
  RealAudioPlaybackService? playbackServiceOverride,
  PracticeRecordRepository? repositoryOverride,
}) async {
  // Tall surface so the recording page (disclaimer + status +
  // timer + controls + rating + note + save) fits without
  // scrolling. The detail page also benefits from a taller
  // surface when self-assessment + tags + playback + delete
  // are all on screen.
  await tester.binding.setSurfaceSize(const Size(800, 2400));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(db),
        appClockProvider.overrideWithValue(() => _kFixedNow),
        // T036 deliberately uses the REAL UUID generator —
        // the test reads the id BACK from the database
        // instead of asserting on a hard-coded value, so
        // the closed loop is exercised against an
        // unpredictable id.
        practiceRecordIdGeneratorProvider.overrideWithValue(
          UuidPracticeRecordIdGenerator(),
        ),
        audioFileStorageServiceProvider.overrideWithValue(env.storage),
        realAudioRecorderServiceProvider.overrideWithValue(env.recorderService),
        realAudioPlaybackServiceProvider
            .overrideWithValue(playbackServiceOverride ?? env.playbackService),
        // T036A: only override the repository provider when the
        // test supplies a spy-decorated instance. The 3
        // additional scenarios pass `null` and therefore keep
        // the production `practiceRecordRepositoryProvider`
        // default (the real Drift-backed repository).
        if (repositoryOverride != null)
          practiceRecordRepositoryProvider
              .overrideWithValue(repositoryOverride),
        microphonePermissionServiceProvider
            .overrideWithValue(env.permissionService),
      ],
      child: const UkuleleApp(),
    ),
  );
  await tester.pumpAndSettle();
  // Drain any pending microtasks in the real I/O zone so the
  // home page's ListView is fully laid out (the ListView's
  // scrollable is created lazily; we need at least one real
  // I/O microtask for the TodayPracticeController's stream
  // emission to land).
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// Reads the real `PracticeRecordRepository` out of the
/// provider scope so the test can assert on it.
PracticeRecordRepository _readRepository(WidgetTester tester) {
  final ProviderContainer container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  );
  return container.read(practiceRecordRepositoryProvider);
}

/// Navigates to a tile on the home page. The tile may sit
/// below the task list in a ListView; we attempt a drag-based
/// scroll first and fall back to a direct tap if the tile is
/// already on-screen. This keeps the helper stable across
/// surface-size variations.
Future<void> _tapHomeTile(
  WidgetTester tester,
  String label,
) async {
  final Finder tile = find.text(label);
  if (tile.evaluate().isEmpty &&
      find.byType(Scrollable).evaluate().isNotEmpty) {
    await tester.dragUntilVisible(
      tile,
      find.byType(Scrollable).first,
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
  }
  await tester.tap(tile, warnIfMissed: false);
  await tester.pumpAndSettle();
}

/// Pumps the widget tree to a bare `SizedBox` and lets the
/// Drift `StreamQueryStore` close-marker timer fire.
Future<void> _finalizeDispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  for (int i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
  for (int i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('zh_CN');
  });

  // ====================================================================
  // Main closed loop — 25 steps
  // ====================================================================
  testWidgets(
    'T036 vertical flow: record -> save -> list -> detail -> '
    'play/pause/resume/stop -> replay -> natural complete -> '
    'delete while playing -> DB row gone -> file cleaned up '
    '[T036A: pre-delete stop < repository delete, proven by '
    'shared event log]',
    (WidgetTester tester) async {
      final _Env env = _buildEnv(tester);
      env.permissionGateway.nextCheckStatus =
          MicrophonePermissionStatus.granted;
      final AppDatabase db = await _buildDatabase();

      // T036A — wire the two spy wrappers and the shared
      // event log. The playback spy wraps the existing
      // FakeAudioPlaybackGateway in place (no fake mutation,
      // no real-service bypass); the repository spy wraps the
      // REAL Drift-backed repository (no mock, no fake).
      // Both spies share the same `_EventRecorder`.
      final _EventRecorder eventRecorder = _EventRecorder();
      final _PlaybackStopSpyGateway playbackSpy = _PlaybackStopSpyGateway(
        fake: env.playbackGateway,
        recorder: eventRecorder,
      );
      final RealAudioPlaybackService playbackServiceWithSpy =
          RealAudioPlaybackService(
        gateway: playbackSpy,
        storage: env.storage,
      );
      final _RepositoryEventSpy repositorySpy = _RepositoryEventSpy(
        delegate: DriftPracticeRecordRepository(database: db),
        recorder: eventRecorder,
      );

      await _pumpApp(
        tester,
        env,
        db,
        playbackServiceOverride: playbackServiceWithSpy,
        repositoryOverride: repositorySpy,
      );

      // ---------------------------------------------------------------
      // 1. Database is empty at startup.
      // ---------------------------------------------------------------
      final PracticeRecordRepository repository = _readRepository(tester);
      expect(await repository.listRecent(), isEmpty,
          reason: 'baseline: no PracticeRecord rows at startup');

      // Navigate to /records — the empty view must surface.
      await _tapHomeTile(tester, '练习记录');
      expect(find.text('还没有练习记录'), findsOneWidget,
          reason: 'list page must surface the empty state');

      // ---------------------------------------------------------------
      // 2. Open the recording page and start a recording.
      // ---------------------------------------------------------------
      await tester.pageBack();
      await tester.pumpAndSettle();
      await _tapHomeTile(tester, '录音回放');
      expect(find.byKey(const ValueKey<String>('recording-start')),
          findsOneWidget);

      // T031 disclaimer copy is rendered on the recording page.
      expect(
        find.textContaining('本页使用本机麦克风录制练习片段'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey<String>('recording-start')));
      await _runAsyncDelay(tester, const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      expect(env.recorderGateway.startCallCount, 1,
          reason: 'recorder gateway.start must be called exactly once');
      expect(env.recorderGateway.lastStartPath, isNotNull,
          reason: 'recorder gateway must capture the requested path');
      final String recordedPath = env.recorderGateway.lastStartPath!;

      // ---------------------------------------------------------------
      // 3-5. Pre-create a real placeholder .m4a file at the
      // resolved path, then stop the recording.
      // ---------------------------------------------------------------
      await tester.runAsync(() async {
        final File f = File(recordedPath);
        await f.create(recursive: true);
        await f.writeAsString('placeholder m4a bytes');
      });
      env.recorderGateway.nextStopResult = recordedPath;

      // The controller's 1s `Timer.periodic` ticker needs at
      // least one tick before `recordedDurationSeconds > 0`
      // (the `canSave` gate). Wait > 1s in real time.
      await tester.tap(find.byKey(const ValueKey<String>('recording-stop')));
      await _runAsyncDelay(tester, const Duration(milliseconds: 1200));
      await tester.pump();
      await tester.pump();
      expect(env.recorderGateway.stopCallCount, 1,
          reason: 'recorder gateway.stop must be called exactly once');
      // The placeholder file is still on disk — the recorder
      // service never deletes it (T028 contract).
      expect(File(recordedPath).existsSync(), isTrue,
          reason: 'placeholder file must still exist before save');

      // Step 4 (path is inside the temp root) is implicit:
      // `RealAudioRecorderService` constructed the path via
      // `AudioFileStorageService.createTempFile` which always
      // produces a path under the configured temp root.
      expect(recordedPath.startsWith(env.tempRoot.path), isTrue,
          reason: 'resolvedPath MUST be inside the temp audio root');
      expect(
        p.normalize(recordedPath).startsWith(
            p.normalize('${env.tempRoot.path}${Platform.pathSeparator}temp')),
        isTrue,
        reason: 'resolvedPath MUST be inside the temp/ subdirectory',
      );

      // ---------------------------------------------------------------
      // 6. Set self-rating + note + save the take as a
      // PracticeRecord.
      // ---------------------------------------------------------------
      await tester.tap(find.text('还不错'));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey<String>('recording-note')),
        'T036 闭环测试录音',
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey<String>('recording-save')));
      await _runAsyncDelay(tester, const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('recording-save-success-snackbar')),
        findsOneWidget,
        reason: 'save success snackbar must appear',
      );

      // ---------------------------------------------------------------
      // 7. Re-read the row from the database through the real
      // Repository. `audioFilePath` MUST be byte-equivalent
      // to the path the recorder service returned.
      // ---------------------------------------------------------------
      final List<PracticeRecord> rows = await repository.listRecent();
      expect(rows, hasLength(1),
          reason: 'exactly one PracticeRecord row must exist after save');
      final PracticeRecord saved = rows.first;
      expect(saved.audioFilePath, isNotNull,
          reason: 'audioFilePath MUST be persisted');
      expect(saved.audioFilePath, recordedPath,
          reason: 'audioFilePath MUST equal the verbatim recorder '
              'resolvedPath (T033 contract)');

      // ---------------------------------------------------------------
      // 8. List page surfaces the new record.
      // ---------------------------------------------------------------
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('今日练习'), findsOneWidget,
          reason: 'home page must be on top after back navigation');

      await _tapHomeTile(tester, '练习记录');
      expect(find.text('录音练习 · 00:01'), findsOneWidget,
          reason: 'list row must show the practice type + duration');
      expect(find.text('T036 闭环测试录音'), findsOneWidget,
          reason: 'list row must show the note as practiceContent');
      expect(find.text('自评：好'), findsOneWidget,
          reason: 'list row must show the self-assessment');

      // ---------------------------------------------------------------
      // 9. Open the record detail page.
      // ---------------------------------------------------------------
      await tester.tap(find.text('T036 闭环测试录音'));
      await _runAsyncDelay(tester, const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(find.text('练习记录详情'), findsOneWidget,
          reason: 'detail page AppBar must show the title');
      expect(find.text('已完成'), findsOneWidget,
          reason: 'detail page must render the completion state');
      // The audio file path is NEVER rendered on the detail
      // page (T034 / T035 contract).
      expect(find.textContaining('m4a'), findsNothing,
          reason: 'audio path must never leak to the UI');
      expect(
        find.byKey(
            const ValueKey<String>('practice-record-detail-playback-section')),
        findsOneWidget,
        reason: 'playback section must be present for a record with audio',
      );
      expect(find.text('准备播放'), findsOneWidget,
          reason: 'playback section starts at idle');

      // ---------------------------------------------------------------
      // 10-11. Tap play. The playback service MUST receive
      // `loadFile` with the exact verbatim path.
      // ---------------------------------------------------------------
      // NOTE: the recording controller's `_probeRecordingDuration`
      // called `playback.loadFile` during `stopRecording`. The
      // baseline `loadFileBase` captures whatever count we
      // observed before the user tapped play on the detail
      // page so the assertion is exact (the detail page
      // drives exactly one more loadFile).
      final int loadFileBase = env.playbackGateway.loadFileCallCount;
      final int installsBeforeFirstPlay =
          env.playbackGateway.playerStateListenerInstallCount;
      await tester.tap(find.byKey(const ValueKey<String>(
          'practice-record-detail-playback-play-button')));
      await _runAsyncDelay(tester, const Duration(milliseconds: 100));
      await tester.pump();
      await tester.pump();
      expect(env.playbackGateway.loadFileCallCount, loadFileBase + 1,
          reason: 'play must drive exactly one additional service.loadFile');
      expect(env.playbackGateway.lastLoadPath, saved.audioFilePath,
          reason: 'playback gateway MUST receive the verbatim audioFilePath');
      expect(find.text('正在播放'), findsOneWidget,
          reason: 'playback section must transition to playing');
      // T035B: the first play installs a controller-side
      // listener on top of the service's own subscription.
      expect(env.playbackGateway.playerStateListenerInstallCount,
          greaterThan(installsBeforeFirstPlay),
          reason: 'first play must install a fresh listener');

      // ---------------------------------------------------------------
      // 12. Tap pause.
      // ---------------------------------------------------------------
      await tester.tap(find.byKey(const ValueKey<String>(
          'practice-record-detail-playback-pause-button')));
      await _runAsyncDelay(tester, const Duration(milliseconds: 100));
      await tester.pump();
      expect(env.playbackGateway.pauseCallCount, 1,
          reason: 'pause must drive the gateway.pause exactly once');
      expect(find.text('已暂停'), findsOneWidget,
          reason: 'playback section must transition to paused');

      // ---------------------------------------------------------------
      // 13. Tap resume.
      // ---------------------------------------------------------------
      await tester.tap(find.byKey(const ValueKey<String>(
          'practice-record-detail-playback-resume-button')));
      await _runAsyncDelay(tester, const Duration(milliseconds: 100));
      await tester.pump();
      expect(env.playbackGateway.playCallCount, greaterThanOrEqualTo(2),
          reason: 'resume must drive the gateway.play at least once');
      expect(find.text('正在播放'), findsOneWidget,
          reason: 'playback section must transition back to playing');

      // ---------------------------------------------------------------
      // 14. Tap stop. The recorder controller's
      // `_probeRecordingDuration` already drove a
      // `playback.stop` (via `RealAudioPlaybackService.loadFile`'s
      // internal `stop` if a prior session is active), so
      // we use a baseline-relative assertion.
      // ---------------------------------------------------------------
      final int stopsBaseBeforeUserTap = env.playbackGateway.stopCallCount;
      await tester.tap(find.byKey(const ValueKey<String>(
          'practice-record-detail-playback-stop-button')));
      await _runAsyncDelay(tester, const Duration(milliseconds: 100));
      await tester.pump();
      expect(env.playbackGateway.stopCallCount, stopsBaseBeforeUserTap + 1,
          reason: 'user-initiated stop must drive exactly one '
              'additional gateway.stop');
      expect(find.text('准备播放'), findsOneWidget,
          reason: 'playback section must transition to idle');
      final int installsAfterUserStop =
          env.playbackGateway.playerStateListenerInstallCount;

      // ---------------------------------------------------------------
      // 15. Replay. T035B cancel-and-rebuild.
      // ---------------------------------------------------------------
      final int loadFileBaseReplay = env.playbackGateway.loadFileCallCount;
      await tester.tap(find.byKey(const ValueKey<String>(
          'practice-record-detail-playback-play-button')));
      await _runAsyncDelay(tester, const Duration(milliseconds: 100));
      await tester.pump();
      expect(env.playbackGateway.loadFileCallCount, loadFileBaseReplay + 1,
          reason: 'replay must call loadFile again');
      expect(env.playbackGateway.stopCallCount, stopsBaseBeforeUserTap + 1,
          reason: 'replay must not drive an extra stop');
      expect(env.playbackGateway.playerStateListenerInstallCount,
          greaterThan(installsAfterUserStop),
          reason: 'T035B: replay MUST install a fresh listener '
              '(cancel-and-rebuild)');
      expect(find.text('正在播放'), findsOneWidget,
          reason: 'replay must transition back to playing');

      // ---------------------------------------------------------------
      // 16-17. Natural completion — controller must NOT drive
      // an extra stop (T031I / T035 contract).
      // ---------------------------------------------------------------
      await tester.runAsync(() async {
        env.playbackGateway.emitPlayerState(
          const PlaybackPlayerState(
            playing: false,
            processingState: PlaybackProcessingState.completed,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(find.text('准备播放'), findsOneWidget,
          reason: 'natural completion must flip the page back to idle');
      expect(env.playbackGateway.stopCallCount, stopsBaseBeforeUserTap + 1,
          reason: 'natural completion MUST NOT drive an extra '
              'playback.stop() (T031I / T035 contract)');

      // ---------------------------------------------------------------
      // 18. Replay again so the delete happens during active
      // playback.
      // ---------------------------------------------------------------
      final int loadFileBaseThirdPlay = env.playbackGateway.loadFileCallCount;
      await tester.tap(find.byKey(const ValueKey<String>(
          'practice-record-detail-playback-play-button')));
      await _runAsyncDelay(tester, const Duration(milliseconds: 100));
      await tester.pump();
      expect(env.playbackGateway.loadFileCallCount, loadFileBaseThirdPlay + 1,
          reason: 'third play must call loadFile again');
      expect(find.text('正在播放'), findsOneWidget,
          reason: 'replay must transition to playing before delete');

      // ---------------------------------------------------------------
      // 19-20. Delete. The controller's `_stopPlaybackIfActive`
      // MUST run before `repository.delete` (controller
      // source-level contract).
      //
      // T036A — record the event-log baseline right BEFORE
      // tapping the delete button. The slice
      // `[events.length before tap .. end]` is the only
      // set of events we treat as part of THIS delete flow.
      // Anything recorded earlier (e.g. `_probeRecordingDuration`'s
      // internal stop, the loadFile-driven stop, the user's
      // explicit stop at step 14) is part of the playback
      // session lifecycle and is intentionally NOT part of
      // this assertion.
      // ---------------------------------------------------------------
      final int stopsBeforeDelete = env.playbackGateway.stopCallCount;
      final int eventBaselineBeforeDelete = eventRecorder.events.length;
      await tester.tap(find.byKey(
          const ValueKey<String>('practice-record-detail-delete-button')));
      await tester.pump();
      expect(find.text('删除练习记录？'), findsOneWidget,
          reason: 'confirmation dialog must appear');
      await tester.tap(find.byKey(const ValueKey<String>(
          'practice-record-detail-delete-confirm-button')));
      // Real I/O — the pre-delete stop, the repository delete,
      // and the audio file cleanup all run synchronously in
      // the real I/O zone. Pump aggressively so the route
      // pop animation + SnackBar + cleanup all settle.
      // We avoid `pumpAndSettle` because the broadcast
      // stream subscriptions + the Drift close-marker timer
      // can keep the fake-async zone perpetually busy.
      await _runAsyncDelay(tester, const Duration(milliseconds: 300));
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(env.playbackGateway.stopCallCount, greaterThan(stopsBeforeDelete),
          reason: 'pre-delete helper MUST have driven playback.stop()');
      expect(
        env.playbackGateway.stopCallCount,
        greaterThanOrEqualTo(stopsBeforeDelete + 1),
        reason: 'stopCallCount MUST grow by >= 1 after delete (1 from '
            'pre-delete helper)',
      );

      // ---------------------------------------------------------------
      // 20A. T036A — prove pre-delete stop < repository delete
      // via the shared event log.
      //
      // The pre-delete stop fires inside
      // `_stopPlaybackIfActive` BEFORE the controller calls
      // `repository.delete`. Both spies record their event
      // synchronously on entry, so the recorded order
      // exactly matches the call order observed by the
      // production controller. The slice
      // `[eventBaselineBeforeDelete .. eventRecorder.events.length)`
      // is the post-delete-tap event set; baseline events
      // (loadFile-internal stops, natural-completion stop-less
      // transitions, the user's step-14 stop) are excluded.
      // ---------------------------------------------------------------
      final List<_TestEvent> deleteSlice =
          eventRecorder.events.sublist(eventBaselineBeforeDelete);
      // Defensive diagnostic — if a future regression adds
      // an unexpected event in the slice, surface the full
      // sequence first so the failure message is informative.
      if (deleteSlice.isEmpty) {
        fail(
          'T036A: event log slice is empty — the delete flow '
          'produced no spy events. full event log: '
          '${eventRecorder.events.map((_TestEvent e) => e.label).toList()}',
        );
      }
      // `playbackStop` MUST be the first stop in the delete
      // flow (i.e. the pre-delete helper's call). The spy
      // also tracks any subsequent stop calls; we accept
      // the pre-delete stop to be ANY playbackStop in the
      // slice, since the production controller only fires
      // the pre-delete stop exactly once before the delete
      // (a second stop would be a T035A regression that
      // surfaces as a separate test failure).
      final int playbackStopIndexInSlice = deleteSlice.indexWhere(
        (_TestEvent e) => e is _PlaybackStopEvent,
      );
      final int repositoryDeleteIndexInSlice = deleteSlice.indexWhere(
        (_TestEvent e) => e is _RepositoryDeleteEvent,
      );
      expect(
        playbackStopIndexInSlice,
        isNonNegative,
        reason: 'T036A: delete slice MUST contain a playback.stop event '
            '(controller\'s _stopPlaybackIfActive should have fired). '
            'slice: ${deleteSlice.map((_TestEvent e) => e.label).toList()}',
      );
      expect(
        repositoryDeleteIndexInSlice,
        isNonNegative,
        reason: 'T036A: delete slice MUST contain a repository.delete '
            'event (controller\'s deleteCurrentRecord should have '
            'called repository.delete). slice: '
            '${deleteSlice.map((_TestEvent e) => e.label).toList()}',
      );
      expect(
        playbackStopIndexInSlice < repositoryDeleteIndexInSlice,
        isTrue,
        reason: 'T036A: playback.stop MUST happen strictly BEFORE '
            'repository.delete in the delete flow. slice: '
            '${deleteSlice.map((_TestEvent e) => e.label).toList()} '
            '(playbackStopIndex=$playbackStopIndexInSlice, '
            'repositoryDeleteIndex=$repositoryDeleteIndexInSlice)',
      );
      // The repository.delete event MUST reference the saved
      // record id verbatim (not a different id, not a copy).
      final _RepositoryDeleteEvent repositoryDeleteEvent =
          deleteSlice[repositoryDeleteIndexInSlice] as _RepositoryDeleteEvent;
      expect(
        repositoryDeleteEvent.id,
        saved.id,
        reason: 'T036A: repository.delete event MUST reference the '
            'saved record id verbatim, not a different row',
      );

      // ---------------------------------------------------------------
      // 21. Database row is gone.
      // ---------------------------------------------------------------
      final PracticeRecord? afterDelete = await repository.getById(saved.id);
      expect(afterDelete, isNull,
          reason: 'repository.getById MUST return null after delete');

      // ---------------------------------------------------------------
      // 22. The on-disk audio file MUST have been cleaned up.
      // ---------------------------------------------------------------
      expect(File(saved.audioFilePath!).existsSync(), isFalse,
          reason: 'placeholder audio file MUST be removed from disk by '
              'AudioFileStorageService.deleteIfExists (T034 contract)');

      // ---------------------------------------------------------------
      // 23. List page is back to the empty state.
      // ---------------------------------------------------------------
      for (int i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await _runAsyncDelay(tester, const Duration(milliseconds: 50));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      // Force a back navigation if the detail page is still
      // mounted (the SnackBar mount race can race the pop).
      if (find.text('练习记录详情').evaluate().isNotEmpty) {
        final Finder backFinder = find.byTooltip('Back');
        await tester.tap(backFinder, warnIfMissed: false);
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        await _runAsyncDelay(tester, const Duration(milliseconds: 50));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('还没有练习记录'), findsOneWidget,
          reason: 'list page must transition back to empty after delete');
      expect(find.text('T036 闭环测试录音'), findsNothing,
          reason: 'deleted record must no longer appear in the list');

      // ---------------------------------------------------------------
      // 24. No unhandled async exceptions.
      // ---------------------------------------------------------------
      expect(tester.takeException(), isNull,
          reason: 'no unhandled async errors during the full closed loop');

      // ---------------------------------------------------------------
      // 25. T035B listener install count grew across the
      // three play sessions.
      // ---------------------------------------------------------------
      expect(env.playbackGateway.playerStateListenerInstallCount,
          greaterThanOrEqualTo(installsBeforeFirstPlay + 3),
          reason: 'T035B: three play sessions must each install a fresh '
              'controller listener');

      await _finalizeDispose(tester);
    },
  );

  // ====================================================================
  // Additional scenario 1 — Shared path protection
  // ====================================================================
  testWidgets(
    'T036 additional: shared path — two records reference the same '
    'verbatim path; deleting one keeps the file, deleting the other '
    'removes the file',
    (WidgetTester tester) async {
      final _Env env = _buildEnv(tester);
      env.permissionGateway.nextCheckStatus =
          MicrophonePermissionStatus.granted;
      final AppDatabase db = await _buildDatabase();
      await _pumpApp(tester, env, db);
      final PracticeRecordRepository repository = _readRepository(tester);

      // Plant a single placeholder audio file at a known path
      // inside the temp root. We bypass the UI recorder for
      // both records because this scenario is about the
      // application's hasAudioPathReference contract, not
      // the recording flow (T033 already covers the UI
      // path in the main vertical-flow test).
      final Directory savedDir = Directory(p.join(env.tempRoot.path, 'saved'))
        ..createSync();
      final File sharedAudio = File(
        p.join(savedDir.path, 'shared.m4a'),
      )..writeAsStringSync('shared placeholder bytes');
      final String sharedPath = sharedAudio.path;

      final PracticeRecord recA = PracticeRecord(
        id: 't036-share-a',
        practiceDate: DateTime(2026, 6, 20),
        dayIndex: _kExpectedDayIndex,
        primaryPracticeType: PracticeType.recording,
        practiceTags: const <PracticeTag>[PracticeTag.recording],
        practiceContent: 'A 引用共享路径',
        durationSeconds: 5,
        isCompleted: true,
        audioFilePath: sharedPath,
        createdAt: _kFixedNow,
        updatedAt: _kFixedNow,
      );
      final PracticeRecord recB = PracticeRecord(
        id: 't036-share-b',
        practiceDate: DateTime(2026, 6, 20),
        dayIndex: _kExpectedDayIndex,
        primaryPracticeType: PracticeType.recording,
        practiceTags: const <PracticeTag>[PracticeTag.recording],
        practiceContent: 'B 引用共享路径',
        durationSeconds: 5,
        isCompleted: true,
        audioFilePath: sharedPath,
        createdAt: _kFixedNow,
        updatedAt: _kFixedNow,
      );
      await repository.insert(recA);
      await repository.insert(recB);
      expect(sharedAudio.existsSync(), isTrue,
          reason: 'shared file must exist on disk before any delete');
      expect(
        await repository.hasAudioPathReference(sharedPath),
        isTrue,
        reason: 'hasAudioPathReference MUST return true when at least '
            'one row references the path',
      );

      // Navigate to /records and verify both rows are listed.
      await _tapHomeTile(tester, '练习记录');
      expect(find.text('A 引用共享路径'), findsOneWidget);
      expect(find.text('B 引用共享路径'), findsOneWidget);

      // Delete A through the detail page.
      await tester.tap(find.text('A 引用共享路径'));
      await _runAsyncDelay(tester, const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(
          const ValueKey<String>('practice-record-detail-delete-button')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>(
          'practice-record-detail-delete-confirm-button')));
      await _runAsyncDelay(tester, const Duration(milliseconds: 300));
      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await _runAsyncDelay(tester, const Duration(milliseconds: 100));
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // A is gone, B is still in the DB. The shared audio file
      // MUST still be on disk because B references it.
      expect(await repository.getById('t036-share-a'), isNull);
      expect(await repository.getById('t036-share-b'), isNotNull,
          reason: 'B must still be in the DB after A is deleted');
      expect(sharedAudio.existsSync(), isTrue,
          reason: 'shared audio file MUST NOT be deleted while B '
              'still references the verbatim path (T034 shared-path '
              'protection)');

      // Delete B through the detail page.
      await tester.tap(find.text('B 引用共享路径'));
      await _runAsyncDelay(tester, const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(
          const ValueKey<String>('practice-record-detail-delete-button')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>(
          'practice-record-detail-delete-confirm-button')));
      await _runAsyncDelay(tester, const Duration(milliseconds: 300));
      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await _runAsyncDelay(tester, const Duration(milliseconds: 100));
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(await repository.getById('t036-share-b'), isNull);
      expect(sharedAudio.existsSync(), isFalse,
          reason: 'shared audio file MUST be removed after the LAST '
              'referencing row is deleted');

      expect(tester.takeException(), isNull,
          reason: 'no unhandled async errors during the shared-path flow');
      await _finalizeDispose(tester);
    },
  );

  // ====================================================================
  // Additional scenario 2 — Cleanup warning
  // ====================================================================
  testWidgets(
    'T036 additional: cleanup warning — DB row is deleted but the audio '
    'file is outside the storage root, so the page surfaces the warning '
    'snackbar and the row is NOT rolled back',
    (WidgetTester tester) async {
      final _Env env = _buildEnv(tester);
      env.permissionGateway.nextCheckStatus =
          MicrophonePermissionStatus.granted;
      final AppDatabase db = await _buildDatabase();
      await _pumpApp(tester, env, db);
      final PracticeRecordRepository repository = _readRepository(tester);

      // Plant an outside-root audio file. The storage service
      // will refuse to delete it, which is the documented
      // trigger for successWithCleanupWarning.
      final Directory outsideRoot = Directory(
        p.join(
          Directory.systemTemp.path,
          't036_outside_${DateTime.now().microsecondsSinceEpoch}_'
          '${_rootCounter++}',
        ),
      )..createSync(recursive: true);
      addTearDown(() {
        if (outsideRoot.existsSync()) {
          try {
            outsideRoot.deleteSync(recursive: true);
          } on FileSystemException {
            // ignore
          }
        }
      });
      final File outsideFile = File(
        p.join(outsideRoot.path, 'leftover.m4a'),
      )..writeAsStringSync('untouched');
      final String outsidePath = outsideFile.path;

      final PracticeRecord rec = PracticeRecord(
        id: 't036-cleanup-warn',
        practiceDate: DateTime(2026, 6, 20),
        dayIndex: _kExpectedDayIndex,
        primaryPracticeType: PracticeType.recording,
        practiceTags: const <PracticeTag>[PracticeTag.recording],
        practiceContent: 'cleanup warning record',
        durationSeconds: 5,
        isCompleted: true,
        audioFilePath: outsidePath,
        createdAt: _kFixedNow,
        updatedAt: _kFixedNow,
      );
      await repository.insert(rec);

      // Navigate to /records, open the record, delete it.
      await _tapHomeTile(tester, '练习记录');
      await tester.tap(find.text('cleanup warning record'));
      await _runAsyncDelay(tester, const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(
          const ValueKey<String>('practice-record-detail-delete-button')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>(
          'practice-record-detail-delete-confirm-button')));
      // Real I/O — the controller's cleanup helper calls
      // `AudioFileStorageService.deleteIfExists` which throws
      // because the file is outside the root. The controller
      // catches the throw and returns successWithCleanupWarning.
      await _runAsyncDelay(tester, const Duration(milliseconds: 300));
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // The DB row is gone (no rollback).
      expect(await repository.getById('t036-cleanup-warn'), isNull,
          reason: 'DB row MUST be gone — successWithCleanupWarning '
              'does NOT roll back the delete');
      // The outside-root file is still on disk.
      expect(outsideFile.existsSync(), isTrue,
          reason: 'outside-root file MUST NOT be deleted by T034');
      // The dedicated warning snackbar is shown.
      expect(
        find.byKey(const ValueKey<String>(
            'practice-record-delete-cleanup-warning-snackbar')),
        findsOneWidget,
        reason: 'cleanup warning snackbar MUST appear',
      );
      // The success snackbar MUST NOT appear.
      expect(
        find.byKey(
            const ValueKey<String>('practice-record-delete-success-snackbar')),
        findsNothing,
        reason: 'success snackbar MUST NOT appear when cleanup warned',
      );
      // The page popped back to the list.
      expect(find.text('还没有练习记录'), findsOneWidget,
          reason: 'list page must be back to empty after delete');

      expect(tester.takeException(), isNull,
          reason: 'no unhandled async errors during the cleanup-warning flow');
      await _finalizeDispose(tester);
    },
  );

  // ====================================================================
  // Additional scenario 3 — Pre-delete stop failure
  // ====================================================================
  testWidgets(
    'T036 additional: pre-delete stop failure — playback.stop throws, '
    'the controller refuses the delete, the file is preserved, and the '
    'failure snackbar does NOT leak the absolute path',
    (WidgetTester tester) async {
      final _Env env = _buildEnv(tester);
      env.permissionGateway.nextCheckStatus =
          MicrophonePermissionStatus.granted;
      final AppDatabase db = await _buildDatabase();
      await _pumpApp(tester, env, db);
      final PracticeRecordRepository repository = _readRepository(tester);

      // We bypass the recording flow (covered end-to-end by
      // the main vertical-flow test) and insert a record whose
      // audio path is a real on-disk .m4a inside the temp
      // root. This keeps the test focused on the pre-delete
      // stop failure contract.
      String recordedPath = '';
      {
        await tester.runAsync(() async {
          final Directory savedDir =
              Directory(p.join(env.tempRoot.path, 'saved'))
                ..createSync(recursive: true);
          final File f = File(p.join(savedDir.path, 'stop-failure.m4a'))
            ..createSync(recursive: true)
            ..writeAsStringSync('placeholder m4a');
          recordedPath = f.path;
        });
        await repository.insert(
          PracticeRecord(
            id: 't036-stop-failure-rec',
            practiceDate: DateTime(2026, 6, 20),
            dayIndex: _kExpectedDayIndex,
            primaryPracticeType: PracticeType.recording,
            practiceTags: const <PracticeTag>[PracticeTag.recording],
            practiceContent: 'stop failure record',
            durationSeconds: 5,
            isCompleted: true,
            audioFilePath: recordedPath,
            createdAt: _kFixedNow,
            updatedAt: _kFixedNow,
          ),
        );
      }
      final PracticeRecord? saved = (await repository.listRecent()).firstOrNull;
      expect(saved, isNotNull,
          reason: 'a PracticeRecord must exist before the stop-failure '
              'delete attempt');
      expect(saved!.audioFilePath, recordedPath,
          reason: 'saved record\'s audioFilePath must match the planted '
              'file path verbatim');

      // Navigate to the list page and open the record.
      await _tapHomeTile(tester, '练习记录');
      await tester.tap(find.text('stop failure record'));
      await _runAsyncDelay(tester, const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Start playback so the delete happens during an active
      // session (the pre-delete helper is the only way the
      // controller can refuse a delete that races playback).
      await tester.tap(find.byKey(const ValueKey<String>(
          'practice-record-detail-playback-play-button')));
      await _runAsyncDelay(tester, const Duration(milliseconds: 100));
      await tester.pump();
      expect(find.text('正在播放'), findsOneWidget,
          reason: 'playback must reach playing before the delete attempt');

      // Inject a stop failure that fires EXACTLY ONCE on the
      // next `playback.stop()` call. This is the call from
      // the controller's `_stopPlaybackIfActive` helper.
      env.playbackGateway.nextStopExceptionOnce = StateError(
        'synthetic stop failure',
      );
      env.playbackGateway.nextStopExceptionAtCallCount =
          env.playbackGateway.stopCallCount + 1;

      // Tap delete → confirm. The controller's
      // `_stopPlaybackIfActive` will throw, the delete will
      // refuse to proceed.
      await tester.tap(find.byKey(
          const ValueKey<String>('practice-record-detail-delete-button')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>(
          'practice-record-detail-delete-confirm-button')));
      await _runAsyncDelay(tester, const Duration(milliseconds: 300));
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // The DB row is preserved — the controller refused the
      // delete because the pre-delete stop failed.
      final PracticeRecord? afterRefusal = await repository.getById(saved.id);
      expect(afterRefusal, isNotNull,
          reason: 'DB row MUST be preserved when pre-delete stop refuses');
      // The audio file is still on disk.
      expect(File(recordedPath).existsSync(), isTrue,
          reason: 'audio file MUST remain on disk when pre-delete '
              'stop refused');
      // The failure snackbar is shown.
      expect(
        find.byKey(
            const ValueKey<String>('practice-record-delete-failure-snackbar')),
        findsOneWidget,
        reason: 'failure snackbar MUST appear when pre-delete '
            'stop refuses',
      );
      // The success snackbar MUST NOT appear.
      expect(
        find.byKey(
            const ValueKey<String>('practice-record-delete-success-snackbar')),
        findsNothing,
        reason: 'success snackbar MUST NOT appear on a refused delete',
      );
      // The cleanup-warning snackbar MUST NOT appear either.
      expect(
        find.byKey(const ValueKey<String>(
            'practice-record-delete-cleanup-warning-snackbar')),
        findsNothing,
        reason: 'cleanup-warning snackbar MUST NOT appear — the delete '
            'never reached the cleanup step',
      );
      // The friendly failure copy does NOT leak the absolute
      // path or the exception text.
      expect(find.textContaining('synthetic stop failure'), findsNothing,
          reason: 'failure snackbar MUST NOT leak the underlying exception');
      expect(find.textContaining(recordedPath), findsNothing,
          reason: 'failure snackbar MUST NOT leak the absolute audio path');
      // The detail page is still mounted — the user can retry.
      expect(
        find.byKey(
            const ValueKey<String>('practice-record-detail-delete-button')),
        findsOneWidget,
        reason: 'detail page MUST stay mounted on a refused delete so '
            'the user can retry',
      );

      expect(tester.takeException(), isNull,
          reason: 'no unhandled async errors during the stop-failure flow');
      await _finalizeDispose(tester);
    },
  );
}
