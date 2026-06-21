/// 真实音频播放服务状态模型（AudioPlaybackState）
///
/// T030 真实音频 MVP 播放服务基础层：定义应用侧统一的播放服务状态枚举
/// 与最小结果契约。
///
/// 设计原则（与 `REAL_AUDIO_MVP_SDD.md` §7.1 / §8 + `T029` 录音状态机
/// 设计一致）：
/// 1. 状态机由本枚举驱动；Service 持有状态唯一所有权；UI 通过
///    [RealAudioPlaybackService.state] getter 读取；
/// 2. 任何状态转换由 Service 内部完成并显式发布；
/// 3. [disposed] 为终态；进入后任何方法调用抛
///    [InvalidPlaybackStateException]（见
///    `audio_playback_exception.dart`）；
/// 4. 与 just_audio 0.10.5 内置的 `PlayerState` / `ProcessingState`
///    是两层模型：本枚举只暴露"应用侧业务状态"，`PlayerState` 的
///    解析由 `AudioPlaybackGateway` / `PackageJustAudioPlaybackGateway`
///    完成；不把 just_audio 内部 enum 透出到应用侧。
library;

/// 真实音频播放服务状态枚举。
///
/// - [idle]        : 未加载文件；可调用 [RealAudioPlaybackService.loadFile]；
/// - [loading]     : 加载中（`AudioSource` 正在解码 / 缓冲）；
/// - [ready]       : 加载完成、可播放；
/// - [playing]     : 播放中；可调用 pause / stop / seek；
/// - [paused]      : 已暂停，position 保留；可调用 resume / stop / seek；
/// - [completed]   : 播放自然到达文件末尾；可调用 stop / seek / play
///                   （play 后从 position 0 重新开始，与 SDD §8.2 一致）；
/// - [stopping]    : stop 进行中（等待 gateway 返回）；
/// - [disposed]    : 终态；任何调用抛 `InvalidPlaybackStateException`。
enum AudioPlaybackState {
  idle,
  loading,
  ready,
  playing,
  paused,
  completed,
  stopping,
  disposed,
}

/// 一次成功 `stop` 后返回给调用方的最小结果契约（保留位置以便 UI 区分）。
///
/// - [path]              : 本次播放对应的文件绝对路径；
/// - [position]          : stop 触发时刻的播放位置；
/// - [duration]          : 文件总时长（未知时为 `null`）；
/// - [isCompleted]       : stop 前是否已自然到达末尾。
class AudioPlaybackStopResult {
  const AudioPlaybackStopResult({
    required this.path,
    required this.position,
    required this.duration,
    required this.isCompleted,
  });

  final String path;
  final Duration position;
  final Duration? duration;
  final bool isCompleted;
}
