/// 播放服务 Gateway 抽象（AudioPlaybackGateway）
///
/// T030 真实音频 MVP 播放服务基础层：
/// 通过轻量 wrapper / adapter 把 `just_audio 0.10.5` 的 `AudioPlayer`
/// （仅在 platform channel 可用）与应用侧 `RealAudioPlaybackService`
/// 解耦，使得播放流程可在普通单元测试中以 fake gateway 形式验证。
///
/// 设计原则（与 `REAL_AUDIO_MVP_SDD.md` §7.1 + `REAL_AUDIO_DEPENDENCY_SPIKE.md`
/// §3.2 一致）：
/// 1. Gateway 不持有业务状态机；状态由 Service 持有；
/// 2. Gateway 不在构造时启动 platform channel / `setFilePath` / `play`；
/// 3. Gateway **不**负责路径安全校验（路径校验由 Service 调用
///    `AudioFileStorageService` 完成，gateway 仅接受"已校验过的路径"）；
/// 4. Gateway **不**调用 `MicrophonePermissionGateway`（避免隐式权限请求）；
/// 5. Gateway **不**声明 / 触发 `INTERNET` 权限（仅本地 file:// 路径播放）；
/// 6. Gateway 抛出的异常由 Service 翻译为应用侧
///    `AudioPlaybackException` 子类；
/// 7. 测试用 fake gateway 注入即可覆盖 Service 全部状态转换分支。
///
/// `just_audio 0.10.5` 真实 API（Context7 验证）：
/// - `setFilePath(String) -> Future<Duration?>`（preload 默认 true）
/// - `play() -> Future<void>`（Future 在播放完成 / 暂停 / 停止时 complete）
/// - `pause() -> Future<void>`（未播放时 no-op）
/// - `seek(Duration?) -> Future<void>`
/// - `stop() -> Future<void>`（停止后 audio source 状态保留，可恢复）
/// - `dispose() -> Future<void>`（释放所有资源，幂等）
/// - `playerStateStream -> Stream<PlayerState>`（playing + ProcessingState）
/// - `positionStream -> Stream<Duration>`（每 16-200ms 推送）
/// - `durationStream -> Stream<Duration?>`（未知时长时为 null）
/// - `duration -> Duration?`（同步读取当前时长，未知时为 null）
/// - `position -> Duration`（同步读取当前位置）
///
/// 本 Gateway 仅暴露应用侧需要的 5 个核心方法 + 2 个 stream getter +
/// 2 个值 getter；其余 just_audio 能力（volume / speed / loopMode /
/// playlist 等）由后续任务按需追加，避免本任务范围扩张。
library;

import 'dart:async';

import 'package:just_audio/just_audio.dart';

/// 播放 Gateway 抽象：封装 `just_audio 0.10.5` 的 `AudioPlayer`。
///
/// 由 Service 持有；构造时**不**触发 platform channel。
abstract class AudioPlaybackGateway {
  /// 加载本地音频文件 [filePath]（绝对路径）作为播放源。
  ///
  /// - [filePath] 必须是已经过 Service 路径校验的"绝对路径 + 在 audio
  ///   root 内 + `.m4a` 扩展名 + 实际存在"的合法路径；
  /// - 加载完成返回 `Duration?`（文件总时长，未知时为 `null`），用于
  ///   Service 校验加载是否成功；
  /// - 加载失败抛 just_audio 原生异常（Service 翻译为
  ///   `PlaybackLoadFailedException`）；
  /// - **不**自动播放（与 SDD §7.1 "生产 Gateway 不得在构造或 Provider
  ///   初始化时自动播放文件"一致）；
  /// - **不**调用 `MicrophonePermissionGateway`；
  /// - **不**声明 / 触发 `INTERNET` 权限（仅本地 file:// 路径）。
  /// - **必须**显式 `setLoopMode(LoopMode.off)` 以保证
  ///   "播放一次、到达末尾自然停止、不循环"契约（详见 T031E）。
  Future<Duration?> loadFile(String filePath);

  /// 显式设置 `LoopMode.off`（不循环）— T031E 强制契约。
  ///
  /// - 调用方可以在 `loadFile` 之外显式调用以重置之前的状态；
  /// - 默认实现内部用 `setLoopMode(LoopMode.off)`；
  /// - 失败被吞掉（best-effort），但调用方应保证在加载时已
  ///   显式调用了一次。
  Future<void> setLoopModeOff();

  /// 启动播放；如未加载文件则抛异常。
  ///
  /// - 返回的 `Future` 在播放"自然完成 / pause / stop / 异常"时 complete；
  /// - Service 监听此 Future 即可捕获"自然完成"事件（无需监听
  ///   `playerStateStream.processingState == completed`）；
  /// - 已播放时调用为 no-op（Future 立即 complete）。
  Future<void> play();

  /// 暂停播放；未播放时为 no-op。
  Future<void> pause();

  /// 跳转到 [position]；[position] 为 null 时不实际跳转。
  ///
  /// - 跳转到当前位置超出 duration 时由 just_audio 自行处理（通常 clamp
  ///   到文件末尾）；
  /// - 跳转失败抛 just_audio 原生异常（Service 翻译为
  ///   `PlaybackOperationFailedException`）。
  Future<void> seek(Duration? position);

  /// 停止播放（释放 decoder / native resource，audio source 状态保留）。
  ///
  /// - 停止后 `play()` 可从当前位置恢复（与 SDD §8.2 一致）；
  /// - 如需"完全卸载 + position 归零"，由 Service 调用 `loadFile` 重新
  ///   加载或 `seek(Duration.zero)` 后再播放；
  /// - 未播放时为 no-op。
  Future<void> stop();

  /// 释放 platform channel 资源。
  ///
  /// - 多次调用安全（just_audio 内部幂等）；
  /// - dispose 后 Gateway 实例不可再使用。
  Future<void> dispose();

  /// 播放器当前状态流（playing bool + ProcessingState）。
  ///
  /// - Service 监听此 stream 把 just_audio 内部状态翻译为应用侧
  ///   `AudioPlaybackState`；
  /// - 测试 fake gateway 可注入可控 stream 以驱动状态转换分支。
  Stream<PlaybackPlayerState> get playerStateStream;

  /// 当前播放位置流（每 16-200ms 推送一次）。
  Stream<Duration> get positionStream;

  /// 当前文件总时长流（未知时为 `null`）。
  Stream<Duration?> get durationStream;

  /// 当前播放位置（同步读取）。
  Duration get position;

  /// 当前文件总时长（未知时为 `null`，同步读取）。
  Duration? get duration;
}

/// just_audio `PlayerState` 在应用侧的最小投影。
///
/// - 仅保留 Service 状态机真正使用的两个维度：
///   `playing`（bool）+ `processingState`（4 值）：
///   `idle` / `loading` / `ready` / `completed`；
/// - just_audio 内部还有 `buffering` 值；Service 在 `loading` / `ready`
///   之间按需区分（暂合并为 `loading`）。
class PlaybackPlayerState {
  const PlaybackPlayerState({
    required this.playing,
    required this.processingState,
  });

  final bool playing;
  final PlaybackProcessingState processingState;
}

/// just_audio `ProcessingState` 在应用侧的最小投影。
enum PlaybackProcessingState {
  /// 无 source / 已 dispose；Service 视为 `idle`。
  idle,

  /// 加载中（首次 setFilePath 或 seek 后预加载）；Service 视为 `loading`。
  loading,

  /// 已加载、可播放；Service 视为 `ready` / `playing` / `paused`。
  ready,

  /// 自然到达末尾；Service 视为 `completed`。
  completed,
}

/// 基于 `just_audio 0.10.5` 的生产 Gateway 实现
/// （PackageJustAudioPlaybackGateway）。
///
/// T030 真实音频 MVP 播放服务基础层：
/// - 唯一接触 `just_audio` 包 platform channel 的实现；
/// - 由 `RealAudioPlaybackService` 通过构造注入；
/// - **不**在构造时启动 platform channel / `setFilePath` / `play`；
/// - **不**调用 `MicrophonePermissionGateway`；
/// - **不**触发 `INTERNET` 权限（仅本地 file:// 路径播放）。
class PackageJustAudioPlaybackGateway implements AudioPlaybackGateway {
  /// 构造时注入 `just_audio` 的 `AudioPlayer` 实例。
  ///
  /// - 生产环境由本构造的默认参数 `AudioPlayer()` 提供；
  /// - 测试环境可注入自定义 `AudioPlayer`（目前 fake gateway 模式
  ///   不需要）；
  /// - 构造时 `AudioPlayer()` 仅创建 Dart 包装对象，**不**触发
  ///   platform channel（与 `record 7.1.0` 的 `AudioRecorder()` 行为
  ///   类似）。
  PackageJustAudioPlaybackGateway({AudioPlayer? player})
      : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<Duration?> loadFile(String filePath) async {
    // T031E: explicitly pin LoopMode.off on every load. just_audio
    // defaults to LoopMode.off, but: (a) we MUST NOT rely on a
    // default that lives in a third-party package, (b) some
    // platforms / earlier sessions may leave the player in
    // LoopMode.one. Pinning it here makes the "play once, stop at
    // the end" contract explicit and testable. Errors from
    // setLoopMode are non-fatal — if it fails the file is still
    // loaded and the natural-completion recovery in the controller
    // will still flip isPlaying to false on the completed event.
    try {
      await _player.setLoopMode(LoopMode.off);
    } on Object {
      // Best-effort: see comment above.
    }
    return _player.setFilePath(filePath);
  }

  @override
  Future<void> setLoopModeOff() async {
    try {
      await _player.setLoopMode(LoopMode.off);
    } on Object {
      // Best-effort: see comment above.
    }
  }

  @override
  Future<void> play() {
    return _player.play();
  }

  @override
  Future<void> pause() {
    return _player.pause();
  }

  @override
  Future<void> seek(Duration? position) {
    return _player.seek(position);
  }

  @override
  Future<void> stop() {
    return _player.stop();
  }

  @override
  Future<void> dispose() {
    return _player.dispose();
  }

  @override
  Stream<PlaybackPlayerState> get playerStateStream {
    return _player.playerStateStream.map(_mapPlayerState);
  }

  @override
  Stream<Duration> get positionStream {
    return _player.positionStream;
  }

  @override
  Stream<Duration?> get durationStream {
    return _player.durationStream;
  }

  @override
  Duration get position => _player.position;

  @override
  Duration? get duration => _player.duration;

  /// 把 just_audio 的 `PlayerState` 翻译为应用侧的 [PlaybackPlayerState]。
  ///
  /// - just_audio 的 `PlayerState` 包含 `playing`（bool）+ `processingState`
  ///   （5 值：`idle` / `loading` / `buffering` / `ready` / `completed`）；
  /// - 应用侧把 `buffering` 合并到 `loading`（Service 状态机不区分
  ///   `buffering` vs `loading`，由 UI 层按需进一步细分）。
  static PlaybackPlayerState _mapPlayerState(PlayerState playerState) {
    final PlaybackProcessingState mapped;
    switch (playerState.processingState) {
      case ProcessingState.idle:
        mapped = PlaybackProcessingState.idle;
        break;
      case ProcessingState.loading:
      case ProcessingState.buffering:
        mapped = PlaybackProcessingState.loading;
        break;
      case ProcessingState.ready:
        mapped = PlaybackProcessingState.ready;
        break;
      case ProcessingState.completed:
        mapped = PlaybackProcessingState.completed;
        break;
    }
    return PlaybackPlayerState(
      playing: playerState.playing,
      processingState: mapped,
    );
  }
}
