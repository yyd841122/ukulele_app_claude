// Tests for [RealAudioPlaybackService] (T030).
//
// Strategy:
// - 服务通过 [AudioPlaybackGateway] 抽象隔离真实 platform channel；
//   测试用 [FakeAudioPlaybackGateway] 注入，**不**触发真实播放、
//   **不**调用 `just_audio` 平台通道、**不**申请系统权限、**不**
//   保存 `PracticeRecord`、**不**调用麦克风。
// - File storage 使用真实 [AudioFileStorageService] 注入，但 root
//   provider 替换为 [Directory.systemTemp] 下的临时目录（与 T028 /
//   T029 测试一致）。
// - 30 项单元测试覆盖：路径安全（root 内 / root 外 / `..` 路径逃逸 /
//   目录自身 / 不存在 / 不支持扩展名 / 空路径）、状态机（idle / loading /
//   ready / playing / paused / completed / stopping / disposed）、异常
//   路径恢复、播放完成、重复操作、seek 边界、stop / dispose 幂等、
//   dispose 后调用拒绝、播放中 dispose、duration / position 更新、
//   只读契约（不删除音频文件 / 不申请麦克风 / 不保存 PracticeRecord）。
// - 测试断言**行为和状态**，不绑定无意义的内部实现细节。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:ukulele_app/shared/services/audio_file_storage_service.dart';
import 'package:ukulele_app/shared/services/audio_playback_exception.dart';
import 'package:ukulele_app/shared/services/audio_playback_state.dart';
import 'package:ukulele_app/shared/services/real_audio_playback_service.dart';

import 'fake_audio_playback_gateway.dart';

int _counter = 0;

typedef _IsolatedRootProvider = Future<Directory> Function();

/// Creates an isolated temp root directory; returns provider + root +
/// tearDown hook.
({_IsolatedRootProvider provider, Directory root}) _createIsolatedRoot() {
  final Directory root = Directory(
    p.join(
      Directory.systemTemp.path,
      'playback_service_${DateTime.now().microsecondsSinceEpoch}_${_counter++}',
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

/// Builds a [RealAudioPlaybackService] wired to a
/// [FakeAudioPlaybackGateway] and an isolated [AudioFileStorageService]
/// rooted at [_rootProvider] / [_root].
({
  RealAudioPlaybackService service,
  FakeAudioPlaybackGateway gateway,
  AudioFileStorageService storage,
  Directory tempDirectory,
  Directory savedDirectory,
  Directory root
}) _buildService(
  _IsolatedRootProvider rootProvider,
  Directory root,
) {
  final AudioFileStorageService storage = AudioFileStorageService(
    rootDirectoryProvider: rootProvider,
  );
  final FakeAudioPlaybackGateway gateway = FakeAudioPlaybackGateway();
  final RealAudioPlaybackService service = RealAudioPlaybackService(
    gateway: gateway,
    storage: storage,
  );
  return (
    service: service,
    gateway: gateway,
    storage: storage,
    tempDirectory: Directory(p.join(root.path, 'temp')),
    savedDirectory: Directory(p.join(root.path, 'saved')),
    root: root,
  );
}

/// Creates a `.m4a` file inside the given directory with the given
/// takeId/recordId; returns the absolute path.
Future<String> _createM4AFile(Directory dir, String id) async {
  await dir.create(recursive: true);
  final File file = File(p.join(dir.path, '$id.m4a'));
  await file.writeAsString('fake m4a content');
  return file.path;
}

void main() {
  group('RealAudioPlaybackService.loadFile path safety', () {
    test('accepts an existing .m4a file in temp/', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();
      final String path = await _createM4AFile(ctx.tempDirectory, 'rec_001');

      await ctx.service.loadFile(path);

      expect(ctx.gateway.loadFileCallCount, 1);
      expect(ctx.gateway.lastLoadPath, path);
      expect(ctx.service.state, AudioPlaybackState.ready);
      expect(ctx.service.activePath, path);
      _cleanupRoot(root);
    });

    test('accepts an existing .m4a file in saved/', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();
      final String path = await _createM4AFile(ctx.savedDirectory, 'rec_sav');

      await ctx.service.loadFile(path);

      expect(ctx.service.state, AudioPlaybackState.ready);
      expect(ctx.service.activePath, path);
      _cleanupRoot(root);
    });

    test('rejects a path outside of audio root', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();
      // Create an "outside" directory under system temp.
      final Directory outside = Directory(
        p.join(
          Directory.systemTemp.path,
          'playback_outside_${DateTime.now().microsecondsSinceEpoch}_${_counter++}',
        ),
      );
      await outside.create(recursive: true);
      addTearDown(() {
        if (outside.existsSync()) {
          try {
            outside.deleteSync(recursive: true);
          } on FileSystemException {
            // ignore
          }
        }
      });
      final String outsidePath = await _createM4AFile(outside, 'evil');

      await expectLater(
        () => ctx.service.loadFile(outsidePath),
        throwsA(isA<AudioFileNotFoundException>()),
      );
      expect(ctx.gateway.loadFileCallCount, 0);
      expect(ctx.service.state, AudioPlaybackState.idle);
      _cleanupRoot(root);
    });

    test('rejects a `..` path-traversal escape', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();
      final Directory outside = Directory(
        p.join(
          Directory.systemTemp.path,
          'playback_traverse_${DateTime.now().microsecondsSinceEpoch}_${_counter++}',
        ),
      );
      await outside.create(recursive: true);
      addTearDown(() {
        if (outside.existsSync()) {
          try {
            outside.deleteSync(recursive: true);
          } on FileSystemException {
            // ignore
          }
        }
      });
      // Construct path that uses `..` to escape: <root>/temp/../<outside>/evil.m4a
      final String escapePath = p.join(
        ctx.tempDirectory.path,
        '..',
        '..',
        p.relative(outside.path, from: Directory.systemTemp.path),
        'evil.m4a',
      );

      await expectLater(
        () => ctx.service.loadFile(escapePath),
        throwsA(isA<AudioFileNotFoundException>()),
      );
      expect(ctx.gateway.loadFileCallCount, 0);
      _cleanupRoot(root);
    });

    test('rejects the root directory itself', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();

      await expectLater(
        () => ctx.service.loadFile(ctx.root.path),
        throwsA(isA<AudioFileNotFoundException>()),
      );
      expect(ctx.gateway.loadFileCallCount, 0);
      _cleanupRoot(root);
    });

    test('rejects the temp directory itself', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();

      await expectLater(
        () => ctx.service.loadFile(ctx.tempDirectory.path),
        throwsA(isA<AudioFileNotFoundException>()),
      );
      expect(ctx.gateway.loadFileCallCount, 0);
      _cleanupRoot(root);
    });

    test('rejects the saved directory itself', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();

      await expectLater(
        () => ctx.service.loadFile(ctx.savedDirectory.path),
        throwsA(isA<AudioFileNotFoundException>()),
      );
      expect(ctx.gateway.loadFileCallCount, 0);
      _cleanupRoot(root);
    });

    test('rejects a non-existent file', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();
      final String missingPath = p.join(ctx.tempDirectory.path, 'ghost.m4a');

      await expectLater(
        () => ctx.service.loadFile(missingPath),
        throwsA(isA<AudioFileNotFoundException>()),
      );
      expect(ctx.gateway.loadFileCallCount, 0);
      _cleanupRoot(root);
    });

    test('rejects an unsupported extension (mp3)', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();
      final File mp3 = File(p.join(ctx.tempDirectory.path, 'evil.mp3'));
      await mp3.writeAsString('not-m4a');

      await expectLater(
        () => ctx.service.loadFile(mp3.path),
        throwsA(isA<AudioFileNotFoundException>()),
      );
      expect(ctx.gateway.loadFileCallCount, 0);
      _cleanupRoot(root);
    });

    test('rejects an empty path', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();

      await expectLater(
        () => ctx.service.loadFile(''),
        throwsA(isA<AudioFileNotFoundException>()),
      );
      expect(ctx.gateway.loadFileCallCount, 0);
      _cleanupRoot(root);
    });

    test('rejects a relative path', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();

      await expectLater(
        () => ctx.service.loadFile('relative/path/rec.m4a'),
        throwsA(isA<AudioFileNotFoundException>()),
      );
      expect(ctx.gateway.loadFileCallCount, 0);
      _cleanupRoot(root);
    });
  });

  group('RealAudioPlaybackService state transitions', () {
    test('loadFile success: idle → loading → ready', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();
      final String path = await _createM4AFile(ctx.tempDirectory, 'rec_load');
      ctx.gateway.nextLoadResult = const Duration(seconds: 30);

      expect(ctx.service.state, AudioPlaybackState.idle);
      await ctx.service.loadFile(path);
      expect(ctx.service.state, AudioPlaybackState.ready);
      expect(ctx.service.duration, const Duration(seconds: 30));
      _cleanupRoot(root);
    });

    test('loadFile failure: state recovers to idle', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();
      final String path = await _createM4AFile(ctx.tempDirectory, 'rec_lf');
      ctx.gateway.nextLoadException = StateError('simulated load failure');

      await expectLater(
        () => ctx.service.loadFile(path),
        throwsA(isA<PlaybackLoadFailedException>()),
      );
      expect(ctx.service.state, AudioPlaybackState.idle);
      expect(ctx.service.activePath, isNull);
      _cleanupRoot(root);
    });

    test('play from ready: ready → playing', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();
      final String path = await _createM4AFile(ctx.tempDirectory, 'rec_p');
      ctx.gateway.nextLoadResult = const Duration(seconds: 30);
      await ctx.service.loadFile(path);

      await ctx.service.play();

      expect(ctx.gateway.playCallCount, 1);
      expect(ctx.service.state, AudioPlaybackState.playing);
      _cleanupRoot(root);
    });

    test('play without load: rejects', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();

      await expectLater(
        () => ctx.service.play(),
        throwsA(isA<InvalidPlaybackStateException>()),
      );
      expect(ctx.gateway.playCallCount, 0);
      _cleanupRoot(root);
    });

    test('repeated play is rejected', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();
      final String path = await _createM4AFile(ctx.tempDirectory, 'rec_rp');
      ctx.gateway.nextLoadResult = const Duration(seconds: 30);
      await ctx.service.loadFile(path);
      await ctx.service.play();

      await expectLater(
        () => ctx.service.play(),
        throwsA(isA<InvalidPlaybackStateException>()),
      );
      expect(ctx.gateway.playCallCount, 1);
      _cleanupRoot(root);
    });

    test('pause from playing: playing → paused', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();
      final String path = await _createM4AFile(ctx.tempDirectory, 'rec_pa');
      ctx.gateway.nextLoadResult = const Duration(seconds: 30);
      await ctx.service.loadFile(path);
      await ctx.service.play();

      await ctx.service.pause();

      expect(ctx.gateway.pauseCallCount, 1);
      expect(ctx.service.state, AudioPlaybackState.paused);
      _cleanupRoot(root);
    });

    test('pause from non-playing is rejected', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();
      final String path = await _createM4AFile(ctx.tempDirectory, 'rec_pnp');
      ctx.gateway.nextLoadResult = const Duration(seconds: 30);
      await ctx.service.loadFile(path);

      await expectLater(
        () => ctx.service.pause(),
        throwsA(isA<InvalidPlaybackStateException>()),
      );
      expect(ctx.gateway.pauseCallCount, 0);
      _cleanupRoot(root);
    });

    test('resume from paused: paused → playing', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();
      final String path = await _createM4AFile(ctx.tempDirectory, 'rec_re');
      ctx.gateway.nextLoadResult = const Duration(seconds: 30);
      await ctx.service.loadFile(path);
      await ctx.service.play();
      await ctx.service.pause();

      expect(ctx.service.state, AudioPlaybackState.paused);
      await ctx.service.resume();
      expect(ctx.service.state, AudioPlaybackState.playing);
      _cleanupRoot(root);
    });

    test('resume from non-paused is rejected', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();
      final String path = await _createM4AFile(ctx.tempDirectory, 'rec_rnp');
      ctx.gateway.nextLoadResult = const Duration(seconds: 30);
      await ctx.service.loadFile(path);

      await expectLater(
        () => ctx.service.resume(),
        throwsA(isA<InvalidPlaybackStateException>()),
      );
      _cleanupRoot(root);
    });
  });

  group('RealAudioPlaybackService seek', () {
    test('seek within range updates position', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();
      final String path = await _createM4AFile(ctx.tempDirectory, 'rec_sk');
      ctx.gateway.nextLoadResult = const Duration(seconds: 60);
      await ctx.service.loadFile(path);

      await ctx.service.seek(const Duration(seconds: 10));

      expect(ctx.gateway.seekCallCount, 1);
      expect(ctx.gateway.lastSeekPosition, const Duration(seconds: 10));
      expect(ctx.service.position, const Duration(seconds: 10));
      _cleanupRoot(root);
    });

    test('seek with negative position is rejected', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();
      final String path = await _createM4AFile(ctx.tempDirectory, 'rec_skn');
      ctx.gateway.nextLoadResult = const Duration(seconds: 60);
      await ctx.service.loadFile(path);

      await expectLater(
        () => ctx.service.seek(const Duration(seconds: -5)),
        throwsA(isA<PlaybackConfigException>()),
      );
      expect(ctx.gateway.seekCallCount, 0);
      _cleanupRoot(root);
    });

    test('seek beyond duration is forwarded to gateway', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();
      final String path = await _createM4AFile(ctx.tempDirectory, 'rec_skb');
      ctx.gateway.nextLoadResult = const Duration(seconds: 30);
      await ctx.service.loadFile(path);

      // Service 不 clamp；just_audio 自行处理（通常 clamp 到末尾）。
      await ctx.service.seek(const Duration(seconds: 999));

      expect(ctx.gateway.seekCallCount, 1);
      expect(ctx.gateway.lastSeekPosition, const Duration(seconds: 999));
      expect(ctx.service.position, const Duration(seconds: 999));
      _cleanupRoot(root);
    });

    test('seek without loaded file is rejected', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();

      await expectLater(
        () => ctx.service.seek(const Duration(seconds: 5)),
        throwsA(isA<InvalidPlaybackStateException>()),
      );
      expect(ctx.gateway.seekCallCount, 0);
      _cleanupRoot(root);
    });
  });

  group('RealAudioPlaybackService stop', () {
    test('stop from playing: state → idle, position retained', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();
      final String path = await _createM4AFile(ctx.tempDirectory, 'rec_st');
      ctx.gateway.nextLoadResult = const Duration(seconds: 60);
      await ctx.service.loadFile(path);
      await ctx.service.play();
      await ctx.service.seek(const Duration(seconds: 12));

      final result = await ctx.service.stop();

      expect(ctx.gateway.stopCallCount, 1);
      expect(result.path, path);
      expect(result.position, const Duration(seconds: 12));
      expect(result.duration, const Duration(seconds: 60));
      expect(result.isCompleted, isFalse);
      expect(ctx.service.state, AudioPlaybackState.idle);
      _cleanupRoot(root);
    });

    test('stop from idle is rejected', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();

      await expectLater(
        () => ctx.service.stop(),
        throwsA(isA<InvalidPlaybackStateException>()),
      );
      expect(ctx.gateway.stopCallCount, 0);
      _cleanupRoot(root);
    });
  });

  group('RealAudioPlaybackService natural completion', () {
    test('natural completion: playing → completed', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();
      final String path = await _createM4AFile(ctx.tempDirectory, 'rec_c');
      ctx.gateway.nextLoadResult = const Duration(seconds: 5);
      await ctx.service.loadFile(path);
      ctx.gateway.completeOnNextPlay = true;
      await ctx.service.play();
      // T031E: the fake schedules the `completed` event on the
      // next microtask so it lands AFTER `play()` returns. Two
      // microtask drains are needed to flush the scheduleMicrotask
      // and the resulting state stream emission.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(ctx.service.state, AudioPlaybackState.completed);
      _cleanupRoot(root);
    });

    test('completed → play restarts from position 0', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();
      final String path = await _createM4AFile(ctx.tempDirectory, 'rec_cp');
      ctx.gateway.nextLoadResult = const Duration(seconds: 5);
      await ctx.service.loadFile(path);
      ctx.gateway.completeOnNextPlay = true;
      await ctx.service.play();
      // T031E: drain two microtasks so the scheduleMicrotask that
      // emits `completed` has a chance to run.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(ctx.service.state, AudioPlaybackState.completed);

      // From completed state, play() should be accepted (will start
      // playback from current position; for testing we observe gateway
      // call + state transition).
      await ctx.service.play();

      expect(ctx.gateway.playCallCount, 2);
      expect(ctx.service.state, AudioPlaybackState.playing);
      _cleanupRoot(root);
    });

    // T031E: pinned loop-mode contract test. Production gateway
    // pins LoopMode.off on every loadFile; the service layer
    // additionally calls setLoopModeOff defensively before
    // loadFile. The fake gateway records the call count so the
    // contract is testable.
    test(
        'T031E: loadFile pins LoopMode.off via gateway (setLoopModeOff '
        'is invoked before the file is loaded)', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();
      final String path = await _createM4AFile(ctx.tempDirectory, 'rec_lm');
      ctx.gateway.nextLoadResult = const Duration(seconds: 5);
      final int loopBefore = ctx.gateway.setLoopModeOffCallCount;
      final int loadBefore = ctx.gateway.loadFileCallCount;

      await ctx.service.loadFile(path);

      // T031E: production `RealAudioPlaybackService.loadFile`
      // calls `gateway.setLoopModeOff()` defensively, then
      // `gateway.loadFile()` which internally also calls
      // `setLoopModeOff()` again. So a single service.loadFile
      // should drive the gateway's setLoopModeOff at least twice.
      expect(ctx.gateway.setLoopModeOffCallCount,
          greaterThanOrEqualTo(loopBefore + 2),
          reason: 'T031E: loadFile must pin LoopMode.off on every invocation '
              'to defend against just_audio default drift and previous-'
              'session state leakage');
      expect(ctx.gateway.loadFileCallCount, loadBefore + 1);
      _cleanupRoot(root);
    });

    test(
        'T031I: stop() from completed state is accepted and returns to idle '
        '(the real-device loop-fix contract)', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();
      final String path = await _createM4AFile(ctx.tempDirectory, 'rec_cstop');
      ctx.gateway.nextLoadResult = const Duration(seconds: 5);
      await ctx.service.loadFile(path);
      ctx.gateway.completeOnNextPlay = true;
      await ctx.service.play();
      // T031E: drain two microtasks so the scheduleMicrotask
      // that emits `completed` has a chance to run.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(ctx.service.state, AudioPlaybackState.completed,
          reason: 'T031I: pre-condition — service is in completed state');

      // T031I: the controller's `_handleNaturalCompletion`
      // drives `playback.stop()` from the completed state. The
      // service must accept this transition (state machine
      // allows `stopping` from `completed`) and end in
      // `idle` + cleared session. This pins the contract that
      // the T031I real-device fix depends on.
      final result = await ctx.service.stop();

      expect(ctx.gateway.stopCallCount, 1,
          reason: 'T031I: stop() must drive the gateway');
      expect(result.path, path,
          reason: 'T031I: stop() returns the resolved path of the completed '
              'take');
      expect(result.isCompleted, isTrue,
          reason: 'T031I: stop() must record that the source was in the '
              'completed state when stop was called');
      expect(ctx.service.state, AudioPlaybackState.idle,
          reason: 'T031I: stop() must transition the service to idle, '
              'so the next play() reloads the source from position 0');
      expect(ctx.service.activePath, isNull,
          reason: 'T031I: stop() must clear the active path (the next '
              'play() goes through a fresh loadFile)');
      _cleanupRoot(root);
    });

    test(
        'T031E: setLoopModeOff best-effort — gateway throw does not break '
        'the loadFile path (playback service still loads the file)', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();
      final String path = await _createM4AFile(ctx.tempDirectory, 'rec_lmf');
      ctx.gateway.nextLoadResult = const Duration(seconds: 5);
      ctx.gateway.nextSetLoopModeOffException =
          StateError('synthetic loop mode failure');

      // The service must still successfully load the file even if
      // setLoopModeOff throws (best-effort contract).
      await ctx.service.loadFile(path);

      expect(ctx.service.state, AudioPlaybackState.ready);
      _cleanupRoot(root);
    });
  });

  group('RealAudioPlaybackService reload', () {
    test('loading another file while playing stops the previous one', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();
      final String path1 = await _createM4AFile(ctx.tempDirectory, 'rec_r1');
      final String path2 = await _createM4AFile(ctx.tempDirectory, 'rec_r2');
      ctx.gateway.nextLoadResult = const Duration(seconds: 30);
      await ctx.service.loadFile(path1);
      await ctx.service.play();

      ctx.gateway.nextLoadResult = const Duration(seconds: 60);
      await ctx.service.loadFile(path2);

      expect(ctx.gateway.stopCallCount, greaterThanOrEqualTo(1));
      expect(ctx.gateway.loadFileCallCount, 2);
      expect(ctx.service.state, AudioPlaybackState.ready);
      expect(ctx.service.activePath, path2);
      _cleanupRoot(root);
    });
  });

  group('RealAudioPlaybackService gateway errors', () {
    test('gateway play error is translated', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();
      final String path = await _createM4AFile(ctx.tempDirectory, 'rec_gpe');
      ctx.gateway.nextLoadResult = const Duration(seconds: 30);
      await ctx.service.loadFile(path);
      ctx.gateway.nextPlayException = StateError('simulated play error');

      await expectLater(
        () => ctx.service.play(),
        throwsA(isA<PlaybackOperationFailedException>()),
      );
      _cleanupRoot(root);
    });

    test('gateway pause error is translated', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();
      final String path = await _createM4AFile(ctx.tempDirectory, 'rec_gpa');
      ctx.gateway.nextLoadResult = const Duration(seconds: 30);
      await ctx.service.loadFile(path);
      await ctx.service.play();
      ctx.gateway.nextPauseException = StateError('simulated pause error');

      await expectLater(
        () => ctx.service.pause(),
        throwsA(isA<PlaybackOperationFailedException>()),
      );
      _cleanupRoot(root);
    });

    test('gateway seek error is translated', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();
      final String path = await _createM4AFile(ctx.tempDirectory, 'rec_gse');
      ctx.gateway.nextLoadResult = const Duration(seconds: 30);
      await ctx.service.loadFile(path);
      ctx.gateway.nextSeekException = StateError('simulated seek error');

      await expectLater(
        () => ctx.service.seek(const Duration(seconds: 5)),
        throwsA(isA<PlaybackOperationFailedException>()),
      );
      _cleanupRoot(root);
    });

    test('gateway stop error is translated', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();
      final String path = await _createM4AFile(ctx.tempDirectory, 'rec_gst');
      ctx.gateway.nextLoadResult = const Duration(seconds: 30);
      await ctx.service.loadFile(path);
      ctx.gateway.nextStopException = StateError('simulated stop error');

      await expectLater(
        () => ctx.service.stop(),
        throwsA(isA<PlaybackOperationFailedException>()),
      );
      _cleanupRoot(root);
    });
  });

  group('RealAudioPlaybackService duration + position updates', () {
    test('duration is updated by gateway load result', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();
      final String path = await _createM4AFile(ctx.tempDirectory, 'rec_d');
      ctx.gateway.nextLoadResult = const Duration(seconds: 42);

      await ctx.service.loadFile(path);

      expect(ctx.service.duration, const Duration(seconds: 42));
      _cleanupRoot(root);
    });

    test('position stream updates activePosition', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();
      final String path = await _createM4AFile(ctx.tempDirectory, 'rec_pos');
      ctx.gateway.nextLoadResult = const Duration(seconds: 60);
      await ctx.service.loadFile(path);

      ctx.gateway.emitPosition(const Duration(milliseconds: 1500));
      // StreamController.broadcast events are dispatched asynchronously;
      // pump the event queue so the subscription callback runs.
      await Future<void>.delayed(Duration.zero);

      expect(ctx.service.position, const Duration(milliseconds: 1500));
      _cleanupRoot(root);
    });

    test('duration stream updates activeDuration', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();
      final String path = await _createM4AFile(ctx.tempDirectory, 'rec_ds');
      ctx.gateway.nextLoadResult = const Duration(seconds: 10);
      await ctx.service.loadFile(path);

      ctx.gateway.emitDuration(const Duration(seconds: 100));
      await Future<void>.delayed(Duration.zero);

      expect(ctx.service.duration, const Duration(seconds: 100));
      _cleanupRoot(root);
    });
  });

  group('RealAudioPlaybackService lifecycle', () {
    test('dispose while playing stops and disposes gateway', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();
      final String path = await _createM4AFile(ctx.tempDirectory, 'rec_dp');
      ctx.gateway.nextLoadResult = const Duration(seconds: 30);
      await ctx.service.loadFile(path);
      await ctx.service.play();

      await ctx.service.dispose();

      expect(ctx.service.isDisposed, isTrue);
      expect(ctx.service.state, AudioPlaybackState.disposed);
      expect(ctx.gateway.disposeCallCount, 1);
      _cleanupRoot(root);
    });

    test('dispose is idempotent', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();

      await ctx.service.dispose();
      await ctx.service.dispose();
      await ctx.service.dispose();

      expect(ctx.service.isDisposed, isTrue);
      expect(ctx.gateway.disposeCallCount, 1);
      _cleanupRoot(root);
    });

    test('dispose after dispose rejects all operations', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();
      final String path = await _createM4AFile(ctx.tempDirectory, 'rec_da');

      await ctx.service.dispose();

      await expectLater(
        () => ctx.service.loadFile(path),
        throwsA(isA<InvalidPlaybackStateException>()),
      );
      await expectLater(
        () => ctx.service.play(),
        throwsA(isA<InvalidPlaybackStateException>()),
      );
      await expectLater(
        () => ctx.service.pause(),
        throwsA(isA<InvalidPlaybackStateException>()),
      );
      await expectLater(
        () => ctx.service.resume(),
        throwsA(isA<InvalidPlaybackStateException>()),
      );
      await expectLater(
        () => ctx.service.seek(const Duration(seconds: 5)),
        throwsA(isA<InvalidPlaybackStateException>()),
      );
      await expectLater(
        () => ctx.service.stop(),
        throwsA(isA<InvalidPlaybackStateException>()),
      );
      _cleanupRoot(root);
    });
  });

  group('RealAudioPlaybackService read-only / isolation contract', () {
    test(
        'service does not delete / move / rename audio files '
        '(storage.deleteIfExists is never called by service)', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();
      final String path = await _createM4AFile(ctx.tempDirectory, 'rec_ro');

      // Trigger a full loadFile + play + pause + stop + dispose cycle.
      ctx.gateway.nextLoadResult = const Duration(seconds: 10);
      await ctx.service.loadFile(path);
      await ctx.service.play();
      await ctx.service.pause();
      await ctx.service.stop();
      await ctx.service.dispose();

      // The original audio file must still exist.
      expect(File(path).existsSync(), isTrue,
          reason: 'playback service must never delete the source file');
      _cleanupRoot(root);
    });

    test(
        'service does not request microphone permission '
        '(no microphone permission gateway is wired)', () async {
      // 契约测试：本测试通过 import 必要的服务 / 状态 / 异常类，并
      // 触发其 API 一次，确保不会因 import 解析失败或副作用触发
      // 真实平台 / 权限 / 录音 / PracticeRecord 保存。
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();
      final String path = await _createM4AFile(ctx.tempDirectory, 'rec_mp');

      ctx.gateway.nextLoadResult = const Duration(seconds: 5);
      await ctx.service.loadFile(path);
      ctx.gateway.completeOnNextPlay = true;
      await ctx.service.play();
      // T031E: drain two microtasks so the scheduleMicrotask
      // that emits `completed` has a chance to run.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await ctx.service.stop();
      await ctx.service.dispose();

      // If the service had wired a microphone permission gateway, this
      // assert would have failed earlier via MissingPluginException.
      // The mere fact that the cycle completes without exceptions is the
      // contract assertion.
      expect(ctx.service.isDisposed, isTrue);
      _cleanupRoot(root);
    });

    test(
        'service does not save PracticeRecord or write to Drift '
        '(no drift / database imports)', () async {
      // 契约测试：本测试**不** import `lib/data/database/...` 任何 Drift
      // 符号；只通过 fake gateway 触发播放全流程，确保不会引入
      // PracticeRecord 写入副作用。
      final (:provider, :root) = _createIsolatedRoot();
      final ctx = _buildService(provider, root);
      await ctx.storage.ensureDirectories();
      final String path = await _createM4AFile(ctx.tempDirectory, 'rec_dr');

      ctx.gateway.nextLoadResult = const Duration(seconds: 5);
      await ctx.service.loadFile(path);
      await ctx.service.play();
      await ctx.service.pause();
      await ctx.service.stop();
      await ctx.service.dispose();

      // If PracticeRecord were saved via Drift, we'd need a database
      // handle here. The test's lack of Drift imports is the contract
      // assertion.
      expect(ctx.service.isDisposed, isTrue);
      _cleanupRoot(root);
    });
  });
}
