/// 真实录音服务状态模型（AudioRecorderState）
///
/// T029 真实音频 MVP 录音服务基础层：定义应用侧统一的录音服务状态枚举。
///
/// 设计原则（与 `REAL_AUDIO_MVP_SDD.md` §7.1 / §8 一致）：
/// 1. 状态机严格按 SDD §8 定义：`idle` / `recording` / `stopping` /
///    `cancelling` / `disposed`。
/// 2. Service 持有状态唯一所有权；UI 通过 `state` getter 读取；
///    任何状态转换由 Service 内部完成并显式发布。
/// 3. `disposed` 为终态；进入后任何方法调用抛
///    [InvalidRecorderStateException]。
library;

/// 真实录音服务状态枚举。
///
/// - [idle]         : 无活跃录音会话；可调用 [RealAudioRecorderService.start]；
/// - [recording]    : 录音中；可调用 stop / cancel；
/// - [stopping]     : stop 进行中（等待 gateway 返回）；
/// - [cancelling]   : cancel 进行中（等待 gateway 返回 + 文件清理）；
/// - [disposed]     : 终态；任何调用抛 `InvalidRecorderStateException`。
enum AudioRecorderState {
  idle,
  recording,
  stopping,
  cancelling,
  disposed,
}

/// 一次成功 stop 后返回给调用方的最小结果契约。
///
/// 承载后续保存流程所需信息（takeId + 路径 + 格式参数），**不**
/// 包含 `PracticeRecord` 字段（避免与 Drift schema 耦合）。
///
/// - [takeId]         : 本次录音 takeId（UUID v4 风格）；
/// - [requestedPath]  : 录音前请求的目标文件绝对路径；
/// - [resolvedPath]   : 录音后 gateway 实际写入的文件绝对路径；
///                      与 [requestedPath] 应一致（当前 `record`
///                      实现就是按请求路径写入）；
/// - [format]         : 输出容器格式字符串（`m4a`）；
/// - [sampleRate]     : 实际采样率（Hz）；
/// - [bitRate]        : 实际码率（bps）；
/// - [numChannels]    : 实际声道数（1 = mono, 2 = stereo）。
class AudioRecorderTakeResult {
  const AudioRecorderTakeResult({
    required this.takeId,
    required this.requestedPath,
    required this.resolvedPath,
    required this.format,
    required this.sampleRate,
    required this.bitRate,
    required this.numChannels,
  });

  final String takeId;
  final String requestedPath;
  final String resolvedPath;
  final String format;
  final int sampleRate;
  final int bitRate;
  final int numChannels;
}
