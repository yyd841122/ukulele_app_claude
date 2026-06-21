/// 真实录音服务异常层次（AudioRecorderException）
///
/// T029 真实音频 MVP 录音服务基础层：定义应用侧统一的录音异常类型。
///
/// 设计原则：
/// 1. 使用 sealed class 区分语义；不允许 catch-all 后丢弃语义；
/// 2. 每个异常携带根因 [message] + 可选 [cause]（原始异常）；
/// 3. **不**依赖 `record` 包的私有异常类型；Service 翻译 gateway
///    抛出的原生异常为这些类型；
/// 4. Controller 负责翻译为 UI 可消费的 `error` 状态（与 T025 §9 一致）；
/// 5. **不**引入复杂异常体系（仅 5 个具体类型）。
library;

/// 录音服务异常基类。
///
/// - 所有子类携带 [message]（业务可读错误描述）+ 可选 [cause]（原始异常）；
/// - UI 层 catch 此基类即可获取所有录音相关错误，但建议 catch 具体子类
///   以区分错误类别。
sealed class AudioRecorderException implements Exception {
  const AudioRecorderException(this.message, {this.cause});

  /// 业务可读错误描述。
  final String message;

  /// 原始异常（通常为 `record` 包底层异常）。
  final Object? cause;

  @override
  String toString() {
    final String causeStr = cause == null ? '' : ' (cause: $cause)';
    return '$runtimeType: $message$causeStr';
  }
}

/// start 失败（gateway.start 抛异常 / ensureDirectories 失败 / IO 错误）。
class RecorderStartFailedException extends AudioRecorderException {
  const RecorderStartFailedException(super.message, {super.cause});
}

/// stop 失败（gateway.stop 抛异常 / stop 返回 null / 路径不一致）。
class RecorderStopFailedException extends AudioRecorderException {
  const RecorderStopFailedException(super.message, {super.cause});
}

/// cancel / dispose 抛异常（gateway 翻译层错误）。
class RecorderGatewayException extends AudioRecorderException {
  const RecorderGatewayException(super.message, {super.cause});
}

/// 非法状态转换（idle 时 stop / disposed 后调用 / 重复 start 等）。
class InvalidRecorderStateException extends AudioRecorderException {
  const InvalidRecorderStateException(super.message, {super.cause});
}

/// 配置 / 参数错误（takeId 空 / 扩展名非法等 — 由
/// `AudioFileStorageService._validateIdSegment` 抛 `ArgumentError`，
/// Service 翻译为该类型）。
class RecorderConfigException extends AudioRecorderException {
  const RecorderConfigException(super.message, {super.cause});
}
