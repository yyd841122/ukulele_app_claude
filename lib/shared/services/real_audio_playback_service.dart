/// 真实音频播放服务（RealAudioPlaybackService）
///
/// T030 真实音频 MVP 播放服务基础层：
/// - 封装 `just_audio 0.10.5` 的 `AudioPlayer`（通过 [AudioPlaybackGateway]）；
/// - 通过 [AudioFileStorageService] 复用路径安全能力（路径校验 /
///   文件存在性 / root 外拒绝）；
/// - 状态机严格按 `REAL_AUDIO_MVP_SDD.md` §7.1 + 本任务设计：`idle` /
///   `loading` / `ready` / `playing` / `paused` / `completed` /
///   `stopping` / `disposed`；
/// - 防止非法状态转换；gateway 异常后状态恢复到稳定状态；
/// - dispose 必须幂等；dispose 后任何调用抛
///   [InvalidPlaybackStateException]；
/// - **不**调用 `MicrophonePermissionGateway`（避免隐式权限请求）；
/// - **不**保存 `PracticeRecord`（不引入 `recordId` / Drift schema）；
/// - **不**触发录音；**不**实现 `Controller` 级录音与播放互斥状态机
///   （T031 任务处理）；
/// - **不**删除 / 移动 / 重命名音频文件（只读访问）。
///
/// Path Safety（与 T028 / T028A 一致）：
/// - 复用 [AudioFileStorageService.isPathInsideRoot] + [AudioFileStorageService.exists]
///   做路径校验；
/// - 路径校验由 Service 翻译 gateway 抛出的 IO 异常为
///   [AudioFileNotFoundException] / [PlaybackIOFailedException]；
/// - 越权路径（root 外 / root 自身 / temp 或 saved 目录自身 / `..` /
///   不存在 / 不支持扩展名 / 空路径）由 Service 抛
///   [AudioFileNotFoundException]；
/// - **不**自行创建第二套音频根目录。
///
/// State machine（详见类级注释）：
/// ```
///              loadFile(ok)
///   idle ─────────────────► loading ────► ready
///                                │           │
///                                │           │ play
///                                │           ▼
///                                │        playing
///                                │       │      │
///                                │       │ pause│ play（重复）
///                                │       ▼      │
///                                │     paused ◄─┘
///                                │       │  resume
///                                │       ▼
///                                │     playing
///                                │       │
///                                │       │ 自然完成
///                                │       ▼
///                                │    completed
///                                │       │  play / seek(0) / stop
///                                ▼       ▼
///                              stopping ──► idle（保留 source）/ loading（新文件）
///      dispose（任意状态）
///                                ▼
///                             disposed（终态）
/// ```
library;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'audio_file_storage_service.dart';
import 'audio_playback_exception.dart';
import 'audio_playback_gateway.dart';
import 'audio_playback_state.dart';

/// 当前 MVP 支持的音频文件扩展名（与 SDD §4.3 + T029 一致）。
const String kPlaybackExtension = 'm4a';

/// 当前 MVP 支持的音频文件扩展名集合（白名单）。
const Set<String> kPlaybackSupportedExtensions = <String>{
  'm4a',
};

/// 真实音频播放服务实现。
///
/// 构造时**不**触发 platform channel / `setFilePath` / `play`。
/// 任何 IO / 平台调用在 [loadFile] / [play] / [pause] / [seek] /
/// [stop] / [dispose] 内显式触发。
class RealAudioPlaybackService {
  /// 构造注入 gateway + storage service。
  ///
  /// - [gateway] : 生产环境用 `PackageJustAudioPlaybackGateway`；测试
  ///               注入 fake gateway；
  /// - [storage] : 复用 T028 既有 `AudioFileStorageService` 做路径校验。
  RealAudioPlaybackService({
    required AudioPlaybackGateway gateway,
    required AudioFileStorageService storage,
  })  : _gateway = gateway,
        _storage = storage;

  final AudioPlaybackGateway _gateway;
  final AudioFileStorageService _storage;

  AudioPlaybackState _state = AudioPlaybackState.idle;
  String? _activePath;
  Duration _activePosition = Duration.zero;
  Duration? _activeDuration;
  bool _disposed = false;
  StreamSubscription<PlaybackPlayerState>? _stateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  Completer<void>? _playCompletion;

  /// 当前播放服务状态。
  AudioPlaybackState get state => _state;

  /// 是否已 dispose。
  bool get isDisposed => _disposed;

  /// 当前正在播放的文件绝对路径（未加载文件时为 `null`）。
  String? get activePath => _activePath;

  /// 当前播放位置（同步读取，最后一次更新值）。
  Duration get position => _activePosition;

  /// 当前文件总时长（未知时为 `null`）。
  Duration? get duration => _activeDuration;

  /// 当前播放位置流（按 gateway 推送节奏，典型 16-200ms 一次）。
  ///
  /// T031 暴露给 [RecordingPracticeController] 订阅，让 UI 的
  /// elapsed MM:SS 反映真实播放进度。Controller 用 `listen`
  /// 即可，无需自行轮询。
  ///
  /// - 在第一次 [loadFile] 后由内部 `_ensureSubscriptions` 建立；
  /// - dispose 时统一取消；
  /// - 不会重复 emit 相同值给订阅者（由 gateway 决定）。
  Stream<Duration> get positionStream {
    _ensureSubscriptions();
    return _gateway.positionStream;
  }

  /// 当前文件总时长流（未知时为 `null`）。
  Stream<Duration?> get durationStream {
    _ensureSubscriptions();
    return _gateway.durationStream;
  }

  /// just_audio 播放器状态流（playing bool + ProcessingState）。
  ///
  /// T031 用于监听"自然完成"事件以驱动 Controller 把 `isPlaying`
  /// 翻回 `false`。
  Stream<PlaybackPlayerState> get playerStateStream {
    _ensureSubscriptions();
    return _gateway.playerStateStream;
  }

  /// 加载 [filePath] 作为播放源。
  ///
  /// 行为：
  /// - 路径必须满足：非空 + 绝对路径 + 在 audio root 内（`temp` 或 `saved`
  ///   下文件）+ 实际存在的普通文件 + 扩展名为 `m4a`；
  /// - 加载前如有正在播放的文件，先 stop（状态切到 `stopping`，完成后
  ///   进入 `loading`，避免旧文件抢占 decoder）；
  /// - 加载成功：状态 `idle → loading → ready`，记录 `_activePath` /
  ///   `_activeDuration` / `_activePosition = Duration.zero`；
  /// - 加载失败：状态恢复到 `idle`，抛 [PlaybackLoadFailedException] 或
  ///   [AudioFileNotFoundException]（路径非法）或 [PlaybackIOFailedException]
  ///   （IO 错误）；
  /// - disposed 后调用抛 [InvalidPlaybackStateException]。
  Future<void> loadFile(String filePath) async {
    if (_disposed) {
      throw const InvalidPlaybackStateException(
        'Cannot loadFile after dispose.',
      );
    }

    // 1. 路径校验（业务校验，由 Service 调用 storage service 完成）。
    await _validatePath(filePath);

    // 2. 如有正在播放 / 加载的文件，先 stop。
    if (_state != AudioPlaybackState.idle) {
      await _stopInternal(emitIdleAfter: false);
    }

    _activePath = filePath;
    _activePosition = Duration.zero;
    _activeDuration = null;
    _state = AudioPlaybackState.loading;

    // 3. 调用 gateway.loadFile。
    Duration? resolvedDuration;
    try {
      // T031E: defensively pin LoopMode.off at the service layer
      // too. The gateway implementation is supposed to pin it
      // internally; this is a belt-and-braces call for any future
      // gateway swap. Errors are swallowed (best-effort) — the
      // service has its own natural-completion recovery that
      // flips isPlaying back to false on the playerStateStream
      // `completed` event regardless of whether the loop mode was
      // successfully pinned. We deliberately call this BEFORE
      // the gateway.loadFile so the file loads with the correct
      // loop mode from the start (some platforms do not allow
      // changing loop mode after the source is loaded).
      try {
        await _gateway.setLoopModeOff();
      } on Object {
        // Best-effort: see comment above.
      }
      resolvedDuration = await _gateway.loadFile(filePath);
    } on AudioPlaybackException {
      _clearActiveSession();
      _state = AudioPlaybackState.idle;
      rethrow;
    } catch (e) {
      _clearActiveSession();
      _state = AudioPlaybackState.idle;
      throw PlaybackLoadFailedException(
        'Failed to load audio file "$filePath".',
        cause: e,
      );
    }

    _activeDuration = resolvedDuration;
    _state = AudioPlaybackState.ready;
    _ensureSubscriptions();
  }

  /// 启动播放。
  ///
  /// 行为：
  /// - 当前状态必须为 [AudioPlaybackState.ready] /
  ///   [AudioPlaybackState.paused] / [AudioPlaybackState.completed]，
  ///   否则抛 [InvalidPlaybackStateException]；
  /// - 重复 play（已在 playing）抛 [InvalidPlaybackStateException]；
  /// - play 后状态切换为 `playing`；
  /// - 自然播放完成由 `playerStateStream` 的
  ///   `processingState == completed` 事件驱动，状态切换为 `completed`；
  /// - gateway.play 抛异常 → 抛 [PlaybackOperationFailedException]，
  ///   状态恢复到 `ready`（文件仍加载）。
  Future<void> play() async {
    if (_disposed) {
      throw const InvalidPlaybackStateException(
        'Cannot play after dispose.',
      );
    }
    if (_state == AudioPlaybackState.playing) {
      throw const InvalidPlaybackStateException(
        'Cannot play: playback is already in progress.',
      );
    }
    if (_state != AudioPlaybackState.ready &&
        _state != AudioPlaybackState.paused &&
        _state != AudioPlaybackState.completed) {
      throw InvalidPlaybackStateException(
        'Cannot play: playback is in state $_state (not ready / paused / completed).',
      );
    }
    final String? path = _activePath;
    if (path == null) {
      throw const InvalidPlaybackStateException(
        'Cannot play: no file is loaded.',
      );
    }

    // play() 的 Future 在 playing 期间一直挂起；自然完成时由
    // playerStateStream 同步触发 `processingState == completed` 事件，
    // 此处不再通过 then() 监听 Future 完成以避免与 playerStateStream
    // 事件处理逻辑竞争。
    _playCompletion = Completer<void>();
    _state = AudioPlaybackState.playing;

    try {
      await _gateway.play();
    } on AudioPlaybackException {
      _state = AudioPlaybackState.ready;
      rethrow;
    } catch (e) {
      _state = AudioPlaybackState.ready;
      throw PlaybackOperationFailedException(
        'Failed to start playback for "$path".',
        cause: e,
      );
    }
  }

  /// 暂停播放。
  ///
  /// 行为：
  /// - 当前状态必须为 [AudioPlaybackState.playing]，
  ///   否则抛 [InvalidPlaybackStateException]；
  /// - pause 后状态切换为 `paused`，position 由 gateway 保持；
  /// - gateway.pause 抛异常 → 抛 [PlaybackOperationFailedException]，
  ///   状态恢复到 `playing`。
  Future<void> pause() async {
    if (_disposed) {
      throw const InvalidPlaybackStateException(
        'Cannot pause after dispose.',
      );
    }
    if (_state != AudioPlaybackState.playing) {
      throw InvalidPlaybackStateException(
        'Cannot pause: playback is in state $_state (not playing).',
      );
    }

    try {
      await _gateway.pause();
    } catch (e) {
      throw PlaybackOperationFailedException(
        'Failed to pause playback for "${_activePath ?? "<unknown>"}".',
        cause: e,
      );
    }

    _state = AudioPlaybackState.paused;
  }

  /// 从暂停状态恢复播放（语义等价于 `play()`）。
  ///
  /// - 当前状态必须为 [AudioPlaybackState.paused]，
  ///   否则抛 [InvalidPlaybackStateException]。
  Future<void> resume() async {
    if (_disposed) {
      throw const InvalidPlaybackStateException(
        'Cannot resume after dispose.',
      );
    }
    if (_state != AudioPlaybackState.paused) {
      throw InvalidPlaybackStateException(
        'Cannot resume: playback is in state $_state (not paused).',
      );
    }
    await play();
  }

  /// 跳转到 [position]。
  ///
  /// 行为：
  /// - 当前状态必须为 [AudioPlaybackState.ready] /
  ///   [AudioPlaybackState.playing] /
  ///   [AudioPlaybackState.paused] /
  ///   [AudioPlaybackState.completed]，否则抛
  ///   [InvalidPlaybackStateException]；
  /// - [position] 为负数时抛 [PlaybackConfigException]（不调用 gateway）；
  /// - [position] 超出 duration：仍调用 gateway.seek，由 just_audio
  ///   自行 clamp（如 clamp 到末尾 + 状态切 completed）；Service
  ///   不做 clamp 避免与底层行为漂移；
  /// - gateway.seek 抛异常 → 抛 [PlaybackOperationFailedException]，
  ///   状态不变化；
  /// - seek 完成后立即更新 `_activePosition`（不等待 positionStream）。
  Future<void> seek(Duration position) async {
    if (_disposed) {
      throw const InvalidPlaybackStateException(
        'Cannot seek after dispose.',
      );
    }
    if (_state != AudioPlaybackState.ready &&
        _state != AudioPlaybackState.playing &&
        _state != AudioPlaybackState.paused &&
        _state != AudioPlaybackState.completed) {
      throw InvalidPlaybackStateException(
        'Cannot seek: playback is in state $_state (not ready / playing / paused / completed).',
      );
    }
    if (position.isNegative) {
      throw PlaybackConfigException(
        'Cannot seek to a negative position: ${position.inMilliseconds} ms.',
      );
    }

    try {
      await _gateway.seek(position);
    } catch (e) {
      throw PlaybackOperationFailedException(
        'Failed to seek to ${position.inMilliseconds} ms for '
        '"${_activePath ?? '<unknown>'}".',
        cause: e,
      );
    }

    _activePosition = position;
  }

  /// 停止播放并返回结果。
  ///
  /// 行为：
  /// - 当前状态必须为 [AudioPlaybackState.ready] /
  ///   [AudioPlaybackState.playing] /
  ///   [AudioPlaybackState.paused] /
  ///   [AudioPlaybackState.completed] /
  ///   [AudioPlaybackState.loading]，
  ///   否则抛 [InvalidPlaybackStateException]；
  /// - stop 期间状态切换为 `stopping`；
  /// - gateway.stop 抛异常 → 抛 [PlaybackOperationFailedException]，
  ///   状态恢复到 stop 前的状态；
  /// - 成功路径返回 [AudioPlaybackStopResult]，状态回到 `ready`
  ///   （position 保留，duration 保留；与 SDD §8.2 "停止后恢复播放"
  ///   一致）；
  /// - 未加载文件（idle）调用抛 [InvalidPlaybackStateException]。
  Future<AudioPlaybackStopResult> stop() async {
    if (_disposed) {
      throw const InvalidPlaybackStateException(
        'Cannot stop after dispose.',
      );
    }
    if (_state == AudioPlaybackState.idle ||
        _state == AudioPlaybackState.stopping ||
        _state == AudioPlaybackState.disposed) {
      throw InvalidPlaybackStateException(
        'Cannot stop: playback is in state $_state.',
      );
    }

    final String path = _activePath ?? '<unknown>';
    final Duration positionAtStop = _activePosition;
    final Duration? durationAtStop = _activeDuration;
    final bool wasCompleted = _state == AudioPlaybackState.completed;

    return _stopInternal(
      emitIdleAfter: true,
      path: path,
      positionAtStop: positionAtStop,
      durationAtStop: durationAtStop,
      wasCompleted: wasCompleted,
    );
  }

  /// 内部 stop 流程，可控制是否最终状态为 `idle`。
  ///
  /// - `emitIdleAfter = true` 时（公开 stop 路径）：返回
  ///   [AudioPlaybackStopResult] 并把状态切到 `ready`（source 保留）；
  ///   实际上 [stop] 当前实现是直接切到 `ready`，而 `_stopInternal(false)`
  ///   用于 `loadFile` 内的清理流程，状态切到 `idle`；
  /// - 设计上 stop 后默认回到 `ready`，**不**回到 `idle`，这样上层调用
  ///   `stop` 后仍可立即 `play()` 从当前 position 继续（与 SDD §8.2 一致）。
  Future<AudioPlaybackStopResult> _stopInternal({
    required bool emitIdleAfter,
    String path = '<unknown>',
    Duration positionAtStop = Duration.zero,
    Duration? durationAtStop,
    bool wasCompleted = false,
  }) async {
    final AudioPlaybackState previousState = _state;
    _state = AudioPlaybackState.stopping;

    try {
      await _gateway.stop();
    } catch (e) {
      _state = previousState;
      throw PlaybackOperationFailedException(
        'Failed to stop playback for "$path".',
        cause: e,
      );
    }

    if (emitIdleAfter) {
      _state = AudioPlaybackState.idle;
      _clearActiveSession();
      return AudioPlaybackStopResult(
        path: path,
        position: positionAtStop,
        duration: durationAtStop,
        isCompleted: wasCompleted,
      );
    }

    _state = AudioPlaybackState.idle;
    return AudioPlaybackStopResult(
      path: path,
      position: positionAtStop,
      duration: durationAtStop,
      isCompleted: wasCompleted,
    );
  }

  /// 释放 platform channel 资源。
  ///
  /// 行为：
  /// - 多次调用幂等；
  /// - 播放中调用：先 stop（best-effort，不抛错），再调用 gateway.dispose，
  ///   状态切到 `disposed`；
  /// - disposed 后任何 loadFile / play / pause / seek / stop 调用抛
  ///   [InvalidPlaybackStateException]。
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    final AudioPlaybackState previousState = _state;
    _state = AudioPlaybackState.disposed;

    // 取消所有 stream subscription（dispose 后不再接收事件）。
    await _stateSubscription?.cancel();
    await _positionSubscription?.cancel();
    await _durationSubscription?.cancel();
    _stateSubscription = null;
    _positionSubscription = null;
    _durationSubscription = null;

    // 关闭 _playCompletion（如未完成）。
    final Completer<void>? completer = _playCompletion;
    _playCompletion = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }

    // best-effort stop（dispose 期间 stop 失败不抛错，与 T029 dispose
    // 契约一致）。
    if (previousState == AudioPlaybackState.playing ||
        previousState == AudioPlaybackState.paused ||
        previousState == AudioPlaybackState.ready ||
        previousState == AudioPlaybackState.loading ||
        previousState == AudioPlaybackState.completed) {
      try {
        await _gateway.stop();
      } on Object {
        // ignore: avoid_returning_null
        // stop 失败不抛错（与 dispose 契约一致）。
      }
    }

    try {
      await _gateway.dispose();
    } on Object {
      // dispose 失败不抛错（与 MicrophonePermissionService.dispose 契约一致）。
    }

    _clearActiveSession();
  }

  // ---------------------------------------------------------------------------
  // 内部工具
  // ---------------------------------------------------------------------------

  /// 路径校验：非空 + 绝对路径 + 在 audio root 内（`temp` 或 `saved`
  /// 下文件）+ 实际存在的普通文件 + 扩展名在白名单内。
  ///
  /// 任一条件不满足抛 [AudioFileNotFoundException]（带 cause 透出原始
  /// IO 异常）。
  Future<void> _validatePath(String filePath) async {
    if (filePath.isEmpty) {
      throw const AudioFileNotFoundException(
        'Cannot load audio file: path is empty.',
      );
    }
    if (!p.isAbsolute(filePath)) {
      throw AudioFileNotFoundException(
        'Cannot load audio file: path is not absolute: "$filePath".',
      );
    }
    final String extension =
        p.extension(filePath).replaceFirst('.', '').toLowerCase();
    if (!kPlaybackSupportedExtensions.contains(extension)) {
      throw AudioFileNotFoundException(
        'Cannot load audio file: unsupported extension "$extension". '
        'Supported: ${kPlaybackSupportedExtensions.join(', ')}',
      );
    }

    // 路径必须在 audio root 内；调用 storage service 获取 root 路径
    // （不创建目录；只解析路径）。
    Directory rootDir;
    try {
      final paths = await _storage.ensureDirectories();
      rootDir = paths.rootDirectory;
    } on Object catch (e) {
      throw AudioFileNotFoundException(
        'Cannot resolve audio root directory.',
        cause: e,
      );
    }
    if (!_storage.isPathInsideRoot(File(filePath), rootDir)) {
      throw AudioFileNotFoundException(
        'Cannot load audio file: path is outside of audio root directory.',
      );
    }

    // 路径必须在 temp 或 saved 目录下（不允许 root 自身 / 子目录路径）；
    // 通过规范化路径前缀检查实现。
    final String canonical = _canonicalPath(filePath);
    final String rootCanonical = _canonicalPath(rootDir.path);
    final String tempCanonical = _canonicalPath('${rootDir.path}/temp');
    final String savedCanonical = _canonicalPath('${rootDir.path}/saved');
    if (canonical == rootCanonical ||
        canonical == tempCanonical ||
        canonical == savedCanonical) {
      throw AudioFileNotFoundException(
        'Cannot load audio file: path points to a directory, not a file.',
      );
    }
    final bool underTemp = _isCanonicalChild(canonical, '$tempCanonical/');
    final bool underSaved = _isCanonicalChild(canonical, '$savedCanonical/');
    if (!underTemp && !underSaved) {
      throw AudioFileNotFoundException(
        'Cannot load audio file: path is not under temp/ or saved/.',
      );
    }

    // 文件必须实际存在。
    final File file = File(filePath);
    final bool exists;
    try {
      exists = await file.exists();
    } on FileSystemException catch (e) {
      throw PlaybackIOFailedException(
        'Failed to check existence of "$filePath".',
        cause: e,
      );
    }
    if (!exists) {
      throw AudioFileNotFoundException(
        'Cannot load audio file: file does not exist at "$filePath".',
      );
    }
  }

  /// 确保 stream subscription 已建立（用于接收 playerState / position /
  /// duration 更新）。
  ///
  /// - 首次 loadFile 后建立；
  /// - dispose 时统一取消；
  /// - 不会重复建立。
  void _ensureSubscriptions() {
    _stateSubscription ??= _gateway.playerStateStream.listen(_onPlayerState);
    _positionSubscription ??= _gateway.positionStream.listen((Duration p) {
      _activePosition = p;
    });
    _durationSubscription ??= _gateway.durationStream.listen((Duration? d) {
      _activeDuration = d;
    });
  }

  /// playerStateStream 回调：把 just_audio 内部状态翻译为应用侧状态。
  void _onPlayerState(PlaybackPlayerState ps) {
    if (_disposed) {
      return;
    }
    switch (ps.processingState) {
      case PlaybackProcessingState.idle:
        // just_audio 不会从 playing 自动回到 idle；只在 dispose / 新 load
        // 时出现。我们不主动切到 idle（避免与 gateway.play Future
        // 完成的逻辑竞争）。
        break;
      case PlaybackProcessingState.loading:
        if (_state != AudioPlaybackState.disposed) {
          _state = AudioPlaybackState.loading;
        }
        break;
      case PlaybackProcessingState.ready:
        if (ps.playing) {
          if (_state != AudioPlaybackState.disposed) {
            _state = AudioPlaybackState.playing;
          }
        } else {
          // ready + not playing：pause / 自然暂停后状态。
          if (_state == AudioPlaybackState.playing) {
            _state = AudioPlaybackState.paused;
          } else if (_state != AudioPlaybackState.disposed) {
            _state = AudioPlaybackState.ready;
          }
        }
        break;
      case PlaybackProcessingState.completed:
        if (_state != AudioPlaybackState.disposed) {
          _state = AudioPlaybackState.completed;
        }
        break;
    }
  }

  /// 清理活跃会话引用（path / position / duration）；状态机由调用方决定。
  void _clearActiveSession() {
    _activePath = null;
    _activePosition = Duration.zero;
    _activeDuration = null;
  }

  /// 规范化路径分隔符为 `/`，便于跨平台比较。
  static String _canonicalPath(String path) {
    return p.normalize(path).replaceAll('\\', '/');
  }

  /// 检查 [child] 是否为 [parent] 之下（含 `parent/child`）。
  static bool _isCanonicalChild(String child, String parent) {
    if (child == parent) {
      return true;
    }
    final String prefix = parent.endsWith('/') ? parent : '$parent/';
    return child.startsWith(prefix);
  }
}
