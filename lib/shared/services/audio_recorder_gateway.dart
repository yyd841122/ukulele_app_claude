/// 录音服务 Gateway 抽象（AudioRecorderGateway）
///
/// T029 真实音频 MVP 录音服务基础层：
/// 通过轻量 wrapper / adapter 把 `record` 包的 `AudioRecorder`
/// （仅在 platform channel 可用）与应用侧 `AudioRecorderService`
/// 解耦，使得录音流程可在普通单元测试中以 fake gateway 形式验证。
///
/// 设计原则（与 `REAL_AUDIO_MVP_SDD.md` §7.1 + `REAL_AUDIO_DEPENDENCY_SPIKE.md`
/// §3.1 一致）：
/// 1. Gateway 不持有业务状态机；状态由 Service 持有；
/// 2. Gateway 不在构造时启动 platform channel；
/// 3. Gateway 不调用 `MicrophonePermissionGateway`（避免隐式权限请求）；
/// 4. Gateway 抛出的异常由 Service 翻译为应用侧
///    `AudioRecorderException` 子类；
/// 5. 测试用 fake gateway 注入即可覆盖 Service 全部状态转换分支。
///
/// `record ^7.1.0` 真实 API（Context7 验证）：
/// - `start(RecordConfig, {required String path}) -> Future<void>`
/// - `stop() -> Future<String?>`（可能为 `null`）
/// - `cancel() -> Future<void>`
/// - `dispose() -> Future<void>`
library;

import 'package:record/record.dart';

/// 录音 Gateway 抽象：封装 `record` 包的 `AudioRecorder`。
///
/// 由 Service 持有；构造时**不**触发 platform channel。
abstract class AudioRecorderGateway {
  /// 启动录音到 [path]（绝对路径）。
  ///
  /// - [config] 由调用方按 T025 §4.3 / T026 §3.1 构造（AAC-LC 44100Hz
  ///   128kbps 单声道）；
  /// - 启动失败抛原生异常（Service 翻译为
  ///   `RecorderStartFailedException`）；
  /// - **不**调用 `hasPermission()`（避免隐式权限请求）；
  /// - **不**调用 `MicrophonePermissionGateway`。
  Future<void> start(RecordConfig config, {required String path});

  /// 停止录音并返回实际写入的文件路径（可能为 `null`）。
  ///
  /// - 无活跃录音会话时返回 `null` 或抛异常（由 `record` 实现决定）；
  /// - Service 负责将 `null` 或与请求路径不一致的返回值翻译为
  ///   `RecorderStopFailedException`。
  Future<String?> stop();

  /// 停止录音并删除文件（`record` 内部删除）。
  ///
  /// - 无活跃录音会话时为 no-op 或抛异常（由 `record` 实现决定）；
  /// - Service 负责将异常翻译为 `RecorderGatewayException`。
  Future<void> cancel();

  /// 释放 platform channel 资源。
  ///
  /// - 多次调用安全（record 内部幂等）；
  /// - dispose 后 Gateway 实例不可再使用。
  Future<void> dispose();
}

/// 基于 `record ^7.1.0` 的生产 Gateway 实现
/// （PackageAudioRecorderGateway）。
///
/// T029 真实音频 MVP 录音服务基础层：
/// - 唯一接触 `record` 包 platform channel 的实现；
/// - 由 `RealAudioRecorderService` 通过构造注入；
/// - **不**在构造时启动 platform channel；
/// - **不**调用 `MicrophonePermissionGateway.hasPermission()`。
class PackageAudioRecorderGateway implements AudioRecorderGateway {
  PackageAudioRecorderGateway({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  @override
  Future<void> start(RecordConfig config, {required String path}) {
    return _recorder.start(config, path: path);
  }

  @override
  Future<String?> stop() {
    return _recorder.stop();
  }

  @override
  Future<void> cancel() {
    return _recorder.cancel();
  }

  @override
  Future<void> dispose() {
    return _recorder.dispose();
  }
}
