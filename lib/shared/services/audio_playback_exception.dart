/// 真实音频播放服务异常层次（AudioPlaybackException）
///
/// T030 真实音频 MVP 播放服务基础层：定义应用侧统一的播放异常类型。
///
/// 设计原则（与 `T029` 录音异常设计一致，但不复用录音专属异常）：
/// 1. 使用 sealed class 区分语义；不允许 catch-all 后丢弃语义；
/// 2. 每个异常携带根因 [message] + 可选 [cause]（原始异常）；
/// 3. **不**依赖 `just_audio` 包的私有异常类型；Service 翻译 gateway
///    抛出的原生异常为这些类型；
/// 4. Controller 负责翻译为 UI 可消费的 `error` 状态（与 T025 §9 一致）；
/// 5. **不**引入复杂异常体系（仅 6 个具体类型）。
///
/// 错误类型与 `REAL_AUDIO_MVP_SDD.md` §7.5 一致：
/// - `PlaybackFailedException` 对应 `PlaybackFailedException`
///   （解码错误 / 加载错误 / 播放平台错误）；
/// - `AudioFileNotFoundException` 用于 `loadFile` 收到 root 外路径、
///   不存在文件、目录自身、空路径、不支持扩展名等；
/// - `InvalidPlaybackStateException` 用于 disposed 后调用 / 非法状态
///   转换（pause 非 playing / resume 非 paused 等）。
library;

/// 播放服务异常基类。
///
/// - 所有子类携带 [message]（业务可读错误描述）+ 可选 [cause]（原始异常）；
/// - UI 层 catch 此基类即可获取所有播放相关错误，但建议 catch 具体子类
///   以区分错误类别。
sealed class AudioPlaybackException implements Exception {
  const AudioPlaybackException(this.message, {this.cause});

  /// 业务可读错误描述。
  final String message;

  /// 原始异常（通常为 `just_audio` 包底层异常 / `IOException` /
  /// `FileSystemException`）。
  final Object? cause;

  @override
  String toString() {
    final String causeStr = cause == null ? '' : ' (cause: $cause)';
    return '$runtimeType: $message$causeStr';
  }
}

/// 加载文件失败（gateway 抛异常 / 解码错误 / 文件 IO 异常）。
class PlaybackLoadFailedException extends AudioPlaybackException {
  const PlaybackLoadFailedException(super.message, {super.cause});
}

/// 播放 / 暂停 / seek / stop 操作失败（gateway 抛异常 / 平台错误）。
class PlaybackOperationFailedException extends AudioPlaybackException {
  const PlaybackOperationFailedException(super.message, {super.cause});
}

/// 文件路径非法 / 不存在 / 不在 audio root 内 / 不支持扩展名。
class AudioFileNotFoundException extends AudioPlaybackException {
  const AudioFileNotFoundException(super.message, {super.cause});
}

/// 非法状态转换（disposed 后调用 / pause 非 playing / resume 非 paused /
/// seek 时未加载文件 / loadFile 期间调用 play 等）。
class InvalidPlaybackStateException extends AudioPlaybackException {
  const InvalidPlaybackStateException(super.message, {super.cause});
}

/// 加载 / 播放期间出现 `PathTooLongException` / `FileSystemException` 等
/// IO 异常（区别于解码错误，便于上层区分错误类型）。
class PlaybackIOFailedException extends AudioPlaybackException {
  const PlaybackIOFailedException(super.message, {super.cause});
}

/// 配置 / 参数错误（空路径 / 路径不是绝对路径 / 扩展名非法等 — 由
/// Service 路径校验阶段抛 `ArgumentError` 后翻译为此类型）。
class PlaybackConfigException extends AudioPlaybackException {
  const PlaybackConfigException(super.message, {super.cause});
}
