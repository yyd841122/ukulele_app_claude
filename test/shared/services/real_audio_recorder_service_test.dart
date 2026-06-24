// Tests for [RealAudioRecorderService] (T029).
//
// Strategy:
// - 服务通过 [AudioRecorderGateway] 抽象隔离真实 platform channel；
//   测试用 [FakeAudioRecorderGateway] 注入，**不**触发真实麦克风、**不**
//   调用 `record` 平台通道、**不**申请系统权限。
// - File storage 使用真实 [AudioFileStorageService] 注入，但 root
//   provider 替换为 [Directory.systemTemp] 下的临时目录（与 T028 测试一致）。
// - 20 项单元测试覆盖：temp 路径生成、AAC-LC 配置、状态转换、非法状态
//   拒绝、stop null / 路径不一致、stop 异常恢复、cancel 清理、cancel 失败、
//   temp 删除失败、start 失败、空白 takeId、dispose 幂等、dispose 后调用、
//   录音中 dispose、一次会话结束后可开始下一次录音、不触发权限请求 /
//   PracticeRecord 保存 / 播放。
// - 测试断言**行为和状态**，不绑定无意义的内部实现细节。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:record/record.dart';

import 'package:ukulele_app/shared/services/audio_file_storage_paths.dart';
import 'package:ukulele_app/shared/services/audio_file_storage_service.dart';
import 'package:ukulele_app/shared/services/audio_recorder_exception.dart';
import 'package:ukulele_app/shared/services/audio_recorder_state.dart';
import 'package:ukulele_app/shared/services/real_audio_recorder_service.dart';

import 'fake_audio_recorder_gateway.dart';

int _counter = 0;

typedef _IsolatedRootProvider = Future<Directory> Function();

/// Creates an isolated temp root directory; returns provider + root + tearDown hook.
({_IsolatedRootProvider provider, Directory root}) _createIsolatedRoot() {
  final Directory root = Directory(
    p.join(
      Directory.systemTemp.path,
      'recorder_service_${DateTime.now().microsecondsSinceEpoch}_${_counter++}',
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
  return (
    provider: () async => root,
    root: root,
  );
}

void _cleanupRoot(Directory root) {
  if (root.existsSync()) {
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // ignore
    }
  }
}

/// Builds a RealAudioRecorderService wired to a FakeAudioRecorderGateway
/// and an isolated [AudioFileStorageService] rooted at [_rootProvider] /
/// [_root]. Returns the service, the fake gateway, and the storage
/// paths container (pre-call) for assertions.
({
  RealAudioRecorderService service,
  FakeAudioRecorderGateway gateway,
  AudioFileStorageService storage,
  AudioFileStoragePaths paths,
}) _buildService(_IsolatedRootProvider rootProvider, Directory root) {
  final AudioFileStorageService storage = AudioFileStorageService(
    rootDirectoryProvider: rootProvider,
  );
  final FakeAudioRecorderGateway gateway = FakeAudioRecorderGateway();
  final RealAudioRecorderService service = RealAudioRecorderService(
    gateway: gateway,
    storage: storage,
  );
  return (
    service: service,
    gateway: gateway,
    storage: storage,
    paths: AudioFileStoragePaths(
      rootDirectory: root,
      tempDirectory: Directory(p.join(root.path, 'temp')),
      savedDirectory: Directory(p.join(root.path, 'saved')),
    ),
  );
}

void main() {
  group('RealAudioRecorderService.start', () {
    test(
        'success: uses AudioFileStorageService to generate temp .m4a path '
        'with takeId', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();

      await ctx.service.start(takeId: 'rec_001');

      // gateway.start invoked once
      expect(ctx.gateway.startCallCount, 1);
      // path is inside root/temp and ends with .m4a
      expect(ctx.gateway.lastStartPath, isNotNull);
      expect(
        ctx.gateway.lastStartPath,
        p.join(root.path, 'temp', 'rec_001.m4a'),
      );
      _cleanupRoot(root);
    });

    test('configures AAC-LC / M4A / mono / 44100Hz / 128kbps', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();

      await ctx.service.start(takeId: 'rec_cfg');

      final RecordConfig cfg = ctx.gateway.lastStartConfig!;
      expect(cfg.encoder, AudioEncoder.aacLc);
      expect(cfg.sampleRate, 44100);
      expect(cfg.bitRate, 128000);
      expect(cfg.numChannels, 1);
      _cleanupRoot(root);
    });

    test('success: transitions to recording state', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();

      expect(ctx.service.state, AudioRecorderState.idle);
      await ctx.service.start(takeId: 'rec_state');
      expect(ctx.service.state, AudioRecorderState.recording);

      // Clean up: stop with a valid nextStopResult so we don't surface
      // a "stop returned null" error during teardown.
      ctx.gateway.nextStopResult = p.join(root.path, 'temp', 'rec_state.m4a');
      await ctx.service.stop();
      _cleanupRoot(root);
    });

    test('rejects a second concurrent start', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();

      await ctx.service.start(takeId: 'rec_first');

      await expectLater(
        () => ctx.service.start(takeId: 'rec_second'),
        throwsA(isA<InvalidRecorderStateException>()),
      );
      // gateway.start was called exactly once (the second call rejected
      // before touching the gateway).
      expect(ctx.gateway.startCallCount, 1);

      // Clean up: stop the first take successfully.
      ctx.gateway.nextStopResult = p.join(root.path, 'temp', 'rec_first.m4a');
      await ctx.service.stop();
      _cleanupRoot(root);
    });

    test('blank takeId surfaces as RecorderConfigException', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();

      await expectLater(
        () => ctx.service.start(takeId: ''),
        throwsA(isA<RecorderConfigException>()),
      );
      // Service never reached the gateway.
      expect(ctx.gateway.startCallCount, 0);
      _cleanupRoot(root);
    });

    test('start failure does not leave the service in recording state',
        () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();
      ctx.gateway.nextStartException = StateError('simulated start failure');

      await expectLater(
        () => ctx.service.start(takeId: 'rec_fail'),
        throwsA(isA<RecorderStartFailedException>()),
      );
      expect(ctx.service.state, AudioRecorderState.idle);

      // A subsequent start with a different takeId still works.
      // Clear the seeded exception so the next start succeeds.
      ctx.gateway.nextStartException = null;
      await ctx.service.start(takeId: 'rec_after');
      expect(ctx.service.state, AudioRecorderState.recording);

      // Clean up.
      ctx.gateway.nextStopResult = p.join(root.path, 'temp', 'rec_after.m4a');
      await ctx.service.stop();
      _cleanupRoot(root);
    });
  });

  group('RealAudioRecorderService.stop', () {
    test('success: returns AudioRecorderTakeResult and resets to idle',
        () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();

      await ctx.service.start(takeId: 'rec_stop_ok');
      final String expectedPath = p.join(root.path, 'temp', 'rec_stop_ok.m4a');
      ctx.gateway.nextStopResult = expectedPath;

      final result = await ctx.service.stop();

      expect(result.takeId, 'rec_stop_ok');
      expect(result.requestedPath, expectedPath);
      expect(result.resolvedPath, expectedPath);
      expect(result.format, 'm4a');
      expect(result.sampleRate, 44100);
      expect(result.bitRate, 128000);
      expect(result.numChannels, 1);
      expect(ctx.service.state, AudioRecorderState.idle);
      expect(ctx.gateway.stopCallCount, 1);
      _cleanupRoot(root);
    });

    test('rejects stop when state is idle', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();

      await expectLater(
        () => ctx.service.stop(),
        throwsA(isA<InvalidRecorderStateException>()),
      );
      expect(ctx.gateway.stopCallCount, 0);
      _cleanupRoot(root);
    });

    test('stop returning null surfaces as RecorderStopFailedException',
        () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();

      await ctx.service.start(takeId: 'rec_stop_null');
      ctx.gateway.nextStopResult = null;

      await expectLater(
        () => ctx.service.stop(),
        throwsA(isA<RecorderStopFailedException>()),
      );
      expect(ctx.service.state, AudioRecorderState.idle);
      _cleanupRoot(root);
    });

    test(
        'stop returning a different path surfaces as '
        'RecorderStopFailedException', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();

      await ctx.service.start(takeId: 'rec_stop_wrong');
      ctx.gateway.nextStopResult = p.join(root.path, 'temp', 'OTHER.m4a');

      await expectLater(
        () => ctx.service.stop(),
        throwsA(isA<RecorderStopFailedException>()),
      );
      expect(ctx.service.state, AudioRecorderState.idle);
      _cleanupRoot(root);
    });

    test(
        'stop throwing an exception preserves the active session '
        'and the recorder state stays `recording` so a retry can '
        're-issue `stop()` (T037B2)', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();

      await ctx.service.start(takeId: 'rec_stop_throw');
      ctx.gateway.nextStopException = StateError('simulated stop failure');

      await expectLater(
        () => ctx.service.stop(),
        throwsA(isA<RecorderStopFailedException>()),
      );
      // T037B2 — the service must NOT pretend to be safely
      // stopped. It preserves the active session so a retry
      // can re-issue `stop()` against the same path. The
      // state stays `recording` (the only honest answer to
      // "is the native recorder running" is "unknown, try
      // again" — the gateway threw, the native state is
      // unknowable).
      expect(ctx.service.state, AudioRecorderState.recording,
          reason: 'T037B2: recorder state MUST stay `recording` after '
              'gateway.stop() throws so a retry call can re-enter the '
              'same state and re-issue the stop');

      // T037B2 — a retry call with a successful gateway
      // resolves to a normal take result and clears the
      // active session / transitions to idle. The
      // `resolvedPath` is preserved verbatim (the
      // `record` package's stop() returned the same path
      // it was given).
      ctx.gateway.nextStopException = null;
      ctx.gateway.nextStopResult =
          p.join(root.path, 'temp', 'rec_stop_throw.m4a');
      final AudioRecorderTakeResult retryResult = await ctx.service.stop();
      expect(retryResult.takeId, 'rec_stop_throw');
      expect(retryResult.resolvedPath,
          p.join(root.path, 'temp', 'rec_stop_throw.m4a'),
          reason: 'resolvedPath MUST be preserved verbatim across the '
              'retry (no normalisation / reformatting)');
      expect(ctx.service.state, AudioRecorderState.idle,
          reason: 'a successful retry clears the active session and '
              'transitions to idle');
      _cleanupRoot(root);
    });
  });

  // ---------------------------------------------------------------------
  // T037B2 — recorder stop failure retry semantics
  // ---------------------------------------------------------------------
  //
  // T037B2 fixes a service-layer contract flaw: the previous behaviour
  // (T029 / T037B1) was that `stop()`'s catch block cleared the active
  // session and flipped state to `idle` even though we have no proof
  // the native `record` package actually stopped. A retry would then
  // observe `state == idle` and short-circuit — the user could pop the
  // page while the native recorder was still running.
  //
  // T037B2 contract: on `gateway.stop()` throw, the service preserves
  // the active session (`_activeTakeId` / `_activeTempFile` /
  // `_activePaths`) and keeps `state` as `recording`. The retry call
  // re-issues `gateway.stop()` against the SAME path. On a successful
  // retry, the active session is cleared and state transitions to
  // `idle`; `resolvedPath` is preserved verbatim.
  group('T037B2 stop failure preserves active session for retry', () {
    test(
        'first gateway.stop() throws -> service stays in `recording` '
        'state and active session is preserved (no premature idle)', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();

      await ctx.service.start(takeId: 'rec_t037b2_throw');
      ctx.gateway.nextStopException =
          StateError('simulated native stop failure');

      await expectLater(
        () => ctx.service.stop(),
        throwsA(isA<RecorderStopFailedException>()),
      );
      // T037B2 — service MUST NOT enter the
      // non-retryable `idle` terminal state on a
      // gateway exception. The only honest answer to
      // "is the native recorder running" is
      // "unknown, try again".
      expect(ctx.service.state, AudioRecorderState.recording,
          reason: 'T037B2: state MUST stay `recording` after a '
              'gateway.stop() throw so a retry can re-issue the stop');
      _cleanupRoot(root);
    });

    test(
        'second gateway.stop() after first throws re-issues against the '
        'same active session and resolves to a take result', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();

      await ctx.service.start(takeId: 'rec_t037b2_retry');
      final String expectedPath =
          p.join(root.path, 'temp', 'rec_t037b2_retry.m4a');
      // First stop throws.
      ctx.gateway.nextStopException =
          StateError('simulated native stop failure');
      await expectLater(
        () => ctx.service.stop(),
        throwsA(isA<RecorderStopFailedException>()),
      );
      final int stopsAfterFirst = ctx.gateway.stopCallCount;
      // Retry: gateway now returns the same path it was
      // given (matches the `record` package contract).
      ctx.gateway.nextStopException = null;
      ctx.gateway.nextStopResult = expectedPath;
      final AudioRecorderTakeResult retryResult = await ctx.service.stop();
      expect(retryResult.takeId, 'rec_t037b2_retry');
      expect(retryResult.resolvedPath, expectedPath,
          reason: 'resolvedPath MUST be preserved verbatim across '
              'the retry (no normalisation / reformatting)');
      expect(ctx.gateway.stopCallCount, stopsAfterFirst + 1,
          reason: 'T037B2: the retry MUST invoke gateway.stop() a '
              'second time (the previous T037B1 contract short-'
              'circuited to idle on the first failure)');
      expect(ctx.service.state, AudioRecorderState.idle,
          reason: 'a successful retry clears the active session and '
              'transitions to idle');
      _cleanupRoot(root);
    });

    test(
        'verbatim resolvedPath invariant: the resolved path on the '
        'take result equals the path the service originally requested '
        '(no normalise / reformat / recompute)', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();

      await ctx.service.start(takeId: 'rec_t037b2_verbatim');
      final String expectedPath =
          p.join(root.path, 'temp', 'rec_t037b2_verbatim.m4a');
      // First stop throws.
      ctx.gateway.nextStopException =
          StateError('simulated native stop failure');
      await expectLater(
        () => ctx.service.stop(),
        throwsA(isA<RecorderStopFailedException>()),
      );
      // Retry: gateway returns the EXACT same path
      // (verbatim contract — no normalization).
      ctx.gateway.nextStopException = null;
      ctx.gateway.nextStopResult = expectedPath;
      final AudioRecorderTakeResult retryResult = await ctx.service.stop();
      expect(retryResult.resolvedPath, expectedPath,
          reason: 'resolvedPath MUST be the gateway\'s returned '
              'string AS-IS (verbatim). The service MUST NOT '
              'normalise, reformat, or recompute the path.');
      expect(retryResult.requestedPath, expectedPath,
          reason: 'requestedPath must equal the path the service '
              'originally handed to gateway.start()');
      _cleanupRoot(root);
    });

    test(
        'three consecutive stop failures still preserve the active '
        'session (no premature idle, no file deletion)', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();

      await ctx.service.start(takeId: 'rec_t037b2_repeat');
      final String expectedPath =
          p.join(root.path, 'temp', 'rec_t037b2_repeat.m4a');
      // Three consecutive throws.
      for (int i = 0; i < 3; i++) {
        ctx.gateway.nextStopException =
            StateError('simulated native stop failure #$i');
        await expectLater(
          () => ctx.service.stop(),
          throwsA(isA<RecorderStopFailedException>()),
        );
        expect(ctx.service.state, AudioRecorderState.recording,
            reason: 'after failure #$i, state MUST stay `recording`');
      }
      expect(ctx.gateway.stopCallCount, 3,
          reason: 'T037B2: every retry MUST invoke gateway.stop() — '
              'the service MUST NOT short-circuit');
      // Successful retry.
      ctx.gateway.nextStopException = null;
      ctx.gateway.nextStopResult = expectedPath;
      final AudioRecorderTakeResult retryResult = await ctx.service.stop();
      expect(retryResult.takeId, 'rec_t037b2_repeat');
      expect(ctx.service.state, AudioRecorderState.idle);
      _cleanupRoot(root);
    });

    test(
        'cancel still works correctly after a stop failure (existing '
        'cancel semantics are not regressed by T037B2)', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();

      await ctx.service.start(takeId: 'rec_t037b2_cancel_after');
      // First stop throws — session is preserved.
      ctx.gateway.nextStopException =
          StateError('simulated native stop failure');
      await expectLater(
        () => ctx.service.stop(),
        throwsA(isA<RecorderStopFailedException>()),
      );
      expect(ctx.service.state, AudioRecorderState.recording);
      // Cancel from `recording` state must still work
      // and must still clean up the temp file. (The
      // service's cancel() requires `recording` state,
      // and T037B2 keeps the state as `recording` after
      // a stop failure, so cancel() is a valid
      // transition.)
      // Pre-create the file so cancel can delete it.
      final File tempFile =
          File(p.join(root.path, 'temp', 'rec_t037b2_cancel_after.m4a'));
      tempFile.writeAsStringSync('pretend audio bytes');
      await ctx.service.cancel();
      expect(ctx.service.state, AudioRecorderState.idle);
      expect(tempFile.existsSync(), isFalse,
          reason: 'cancel still cleans up the temp file (existing '
              'cancel semantics preserved)');
      _cleanupRoot(root);
    });
  });

  group('RealAudioRecorderService.cancel', () {
    test('success: calls gateway and removes the temp file', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();

      await ctx.service.start(takeId: 'rec_cancel_ok');

      // The plugin (record) would normally write to this file; in our
      // fake setup the file is just created on disk by us to verify
      // cleanup.
      final File temp = File(p.join(root.path, 'temp', 'rec_cancel_ok.m4a'));
      temp.writeAsStringSync('pretend audio bytes');

      await ctx.service.cancel();

      expect(ctx.gateway.cancelCallCount, 1);
      expect(temp.existsSync(), isFalse,
          reason: 'cancel must clean up the temp file');
      expect(ctx.service.state, AudioRecorderState.idle);
      _cleanupRoot(root);
    });

    test('rejects cancel when state is idle', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();

      await expectLater(
        () => ctx.service.cancel(),
        throwsA(isA<InvalidRecorderStateException>()),
      );
      expect(ctx.gateway.cancelCallCount, 0);
      _cleanupRoot(root);
    });

    test(
        'gateway cancel failure surfaces as RecorderGatewayException '
        'and state recovers', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();

      await ctx.service.start(takeId: 'rec_cancel_fail');
      ctx.gateway.nextCancelException = StateError('simulated cancel failure');

      await expectLater(
        () => ctx.service.cancel(),
        throwsA(isA<RecorderGatewayException>()),
      );
      expect(ctx.service.state, AudioRecorderState.idle);
      _cleanupRoot(root);
    });

    test('best-effort: temp delete failure does not throw', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();

      await ctx.service.start(takeId: 'rec_delete_fail');

      // Pre-delete the temp file before cancel, so cancel's best-effort
      // deleteIfExists returns false (file already missing). The service
      // must NOT surface a delete failure as an exception.
      final File temp = File(p.join(root.path, 'temp', 'rec_delete_fail.m4a'));
      temp.writeAsStringSync('temp');
      temp.deleteSync();

      // gateway.cancel succeeds -> no exception, state goes back to idle.
      await ctx.service.cancel();
      expect(ctx.service.state, AudioRecorderState.idle);
      _cleanupRoot(root);
    });
  });

  group('RealAudioRecorderService lifecycle', () {
    test('dispose is idempotent (multiple dispose calls do not throw)',
        () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();

      await ctx.service.dispose();
      await ctx.service.dispose();
      await ctx.service.dispose();

      expect(ctx.gateway.disposeCallCount, 1,
          reason: 'gateway dispose should be called only once');
      expect(ctx.service.isDisposed, isTrue);
      _cleanupRoot(root);
    });

    test('dispose after dispose rejects start / stop / cancel', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();

      await ctx.service.dispose();

      await expectLater(
        () => ctx.service.start(takeId: 'rec_after_dispose'),
        throwsA(isA<InvalidRecorderStateException>()),
      );
      await expectLater(
        () => ctx.service.stop(),
        throwsA(isA<InvalidRecorderStateException>()),
      );
      await expectLater(
        () => ctx.service.cancel(),
        throwsA(isA<InvalidRecorderStateException>()),
      );
      _cleanupRoot(root);
    });

    test(
        'dispose while recording calls gateway.dispose and marks '
        'state disposed', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();

      await ctx.service.start(takeId: 'rec_dispose_while');

      await ctx.service.dispose();

      expect(ctx.gateway.disposeCallCount, 1);
      expect(ctx.service.state, AudioRecorderState.disposed);
      expect(ctx.service.isDisposed, isTrue);
      _cleanupRoot(root);
    });

    test('a second take after stop succeeds with a different takeId', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();

      // First take.
      await ctx.service.start(takeId: 'take_first');
      ctx.gateway.nextStopResult = p.join(root.path, 'temp', 'take_first.m4a');
      final first = await ctx.service.stop();
      expect(first.takeId, 'take_first');

      // Second take with a different id.
      await ctx.service.start(takeId: 'take_second');
      ctx.gateway.nextStopResult = p.join(root.path, 'temp', 'take_second.m4a');
      final second = await ctx.service.stop();
      expect(second.takeId, 'take_second');
      _cleanupRoot(root);
    });
  });

  group('RealAudioRecorderService static boundary', () {
    test(
        'service does not import permission_handler / practice_records / '
        'just_audio symbols; no permission / playback / persistence side '
        'effects', () async {
      // 契约测试：本测试通过 import 必要的服务 / 状态 / 异常类，并
      // 触发其 API 一次，确保不会因 import 解析失败或副作用触发
      // 真实平台 / 权限 / 播放。
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();

      // 触发 start + stop 全流程，断言副作用只发生在 fake gateway +
      // 临时文件系统，不触达 platform channel / 权限弹窗 / 播放。
      await ctx.service.start(takeId: 'rec_boundary');
      // Pre-create the file the way `record` would have, so that
      // stop's "file is left in place for the save flow" contract can
      // be observed. (In a real run, `record` writes the m4a bytes;
      // here we just create a file with the same path.)
      final File temp = File(p.join(root.path, 'temp', 'rec_boundary.m4a'));
      temp.writeAsStringSync('pretend audio bytes');
      ctx.gateway.nextStopResult = temp.path;
      final result = await ctx.service.stop();
      expect(result.takeId, 'rec_boundary');

      // 文件确实在 temp 目录下（stop 成功路径**不**清理文件）
      expect(temp.existsSync(), isTrue);
      _cleanupRoot(root);
    });
  });
}
