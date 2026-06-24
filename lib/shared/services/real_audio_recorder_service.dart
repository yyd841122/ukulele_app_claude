/// 真实录音服务（RealAudioRecorderService）
///
/// T029 真实音频 MVP 录音服务基础层：
/// - 封装 `record ^7.1.0` 的 `AudioRecorder`（通过 [AudioRecorderGateway]）；
/// - 通过 [AudioFileStorageService] 生成 temp `.m4a` 路径并执行 cancel
///   时的 best-effort 文件清理；
/// - 状态机严格按 `REAL_AUDIO_MVP_SDD.md` §8 设计：`idle` /
///   `recording` / `stopping` / `cancelling` / `disposed`；
/// - 防止并发 start 与非法状态转换；
/// - stop / cancel / dispose 异常处理遵循各自语义（T037B2 修复后）：
///   - `stop` 抛错 → 状态从 `stopping` 回退到 `recording`（**不**进
///     `idle`），**保留**活跃会话（takeId / temp file / paths）让调用方
///     可基于同一路径重试 [stop]；native 录音是否真的停止由 plugin /
///     platform channel 决定，service 不得伪装成"已停止"；
///   - `cancel` 抛错 → best-effort 清理 temp 文件（删除失败**不**抛错），
///     状态恢复 `idle`；
///   - `dispose` 抛错 → 状态保持 `disposed`，**不**抛错（non-cooperative
///     safety net）；
/// - dispose 必须幂等；dispose 后任何调用抛
///   `InvalidRecorderStateException`；
/// - **不**调用 `MicrophonePermissionGateway`（避免隐式权限请求）；
/// - **不**保存 `PracticeRecord`（不引入 `recordId` / Drift schema）；
/// - **不**触发播放；**不**实现 seek / pause / resume（MVP 不需要）。
/// - `cancel` 与 `stop` 语义不同：`stop` 保留 take 文件供 save / retry；
///   `cancel` 清理 temp 文件（不期望继续使用 take）。
///
/// Recorder Configuration（与 `REAL_AUDIO_MVP_SDD.md` §4.3 +
/// `REAL_AUDIO_DEPENDENCY_SPIKE.md` §3.1 一致）：
/// - `AudioEncoder.aacLc`
/// - `sampleRate = 44100` Hz
/// - `bitRate = 128000` bps
/// - `numChannels = 1`（单声道；SDD §4.3 推荐 + Android 广泛兼容）
/// - 输出扩展名 `m4a`（与 [AudioFileStorageService] 默认扩展名一致）
///
/// Path Safety（与 T028 / T028A 一致）：
/// - 复用 [AudioFileStorageService.createTempFile] 生成路径（**不**
///   自行拼接音频根目录）；
/// - cancel 时调用 [AudioFileStorageService.deleteIfExists]（**不**
///   绕过 `isPathInsideRoot` 校验）；
/// - 越权调用由 storage service 抛 `ArgumentError`，Service 翻译为
///   `RecorderConfigException`；
/// - **不**删除 saved 文件；**不**删除 root 自身。
///
/// State machine（详见类级注释）：
/// ```
///   start(good)              stop               cancel
/// idle ────────► recording ─────────► idle ────────────► idle
///                    │                                  （清理 temp）
///                    │ dispose（任意状态）              │
///                    ▼                                  ▼
///                 disposed                            disposed
/// ```
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:record/record.dart';

import 'audio_file_storage_paths.dart';
import 'audio_file_storage_service.dart';
import 'audio_recorder_exception.dart';
import 'audio_recorder_gateway.dart';
import 'audio_recorder_state.dart';

/// AAC-LC 录音配置：单声道、44100Hz、128kbps、扩展名 m4a。
///
/// 与 `REAL_AUDIO_MVP_SDD.md` §4.3 + `REAL_AUDIO_DEPENDENCY_SPIKE.md` §3.1
/// 推荐值一致。Android 设备广泛兼容；不引入 `audio_session`。
class RealAudioRecorderConfig {
  const RealAudioRecorderConfig({
    this.sampleRate = 44100,
    this.bitRate = 128000,
    this.numChannels = 1,
    this.extension = 'm4a',
  });

  final int sampleRate;
  final int bitRate;
  final int numChannels;
  final String extension;
}

/// 真实录音服务实现。
///
/// 构造时**不**触发 platform channel / 麦克风 / 权限请求。
/// 任何 IO / 平台调用在 [start] / [stop] / [cancel] / [dispose] 内
/// 显式触发。
class RealAudioRecorderService {
  /// 构造注入 gateway + storage service + 可选配置。
  ///
  /// - [gateway] : 生产环境用 `PackageAudioRecorderGateway`；测试
  ///               注入 fake gateway；
  /// - [storage] : 复用 T028 既有 `AudioFileStorageService`；
  /// - [config]  : 录音参数（默认 AAC-LC 44100Hz 128kbps mono m4a）。
  RealAudioRecorderService({
    required AudioRecorderGateway gateway,
    required AudioFileStorageService storage,
    RealAudioRecorderConfig config = const RealAudioRecorderConfig(),
  })  : _gateway = gateway,
        _storage = storage,
        _config = config;

  final AudioRecorderGateway _gateway;
  final AudioFileStorageService _storage;
  final RealAudioRecorderConfig _config;

  AudioRecorderState _state = AudioRecorderState.idle;
  String? _activeTakeId;
  File? _activeTempFile;
  AudioFileStoragePaths? _activePaths;
  bool _disposed = false;

  /// 当前录音服务状态。
  AudioRecorderState get state => _state;

  /// 是否已 dispose。
  bool get isDisposed => _disposed;

  /// 启动一次新录音会话。
  ///
  /// 行为：
  /// - 当前状态必须为 [AudioRecorderState.idle]，否则抛
  ///   [InvalidRecorderStateException]；
  /// - **不**隐式调用 `MicrophonePermissionGateway`（Controller 在
  ///   `start` 前显式 `requestPermission`，与 T025 §8.2 一致）；
  /// - [takeId] 由调用方生成（UUID v4）；空 takeId 由 storage service
  ///   抛 `ArgumentError`，Service 翻译为 [RecorderConfigException]；
  /// - 启动失败抛 [RecorderStartFailedException]（带 cause），
  ///   状态恢复到 [AudioRecorderState.idle]；
  /// - 启动成功状态切换为 [AudioRecorderState.recording]。
  Future<void> start({required String takeId}) async {
    if (_disposed) {
      throw const InvalidRecorderStateException(
        'Cannot start after dispose.',
      );
    }
    if (_state != AudioRecorderState.idle) {
      throw InvalidRecorderStateException(
        'Cannot start: recorder is in state $_state.',
      );
    }
    if (_state == AudioRecorderState.recording) {
      throw const InvalidRecorderStateException(
        'A recording is already in progress.',
      );
    }

    // 1. 确保目录就绪并生成 temp 路径。
    late final AudioFileStoragePaths paths;
    late final File tempFile;
    try {
      paths = await _storage.ensureDirectories();
      tempFile = await _storage.createTempFile(
        takeId: takeId,
        extension: _config.extension,
        tempDirectory: paths.tempDirectory,
      );
    } on ArgumentError catch (e) {
      throw RecorderConfigException(
        'Invalid takeId / extension: ${e.message}',
        cause: e,
      );
    } catch (e) {
      throw RecorderStartFailedException(
        'Failed to prepare temp file for take "$takeId".',
        cause: e,
      );
    }

    // 2. 启动 gateway 录音。
    try {
      await _gateway.start(
        RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: _config.sampleRate,
          bitRate: _config.bitRate,
          numChannels: _config.numChannels,
        ),
        path: tempFile.path,
      );
    } catch (e) {
      // 启动失败不遗留 recording 状态；清理已分配的内部状态。
      throw RecorderStartFailedException(
        'Failed to start audio recorder for take "$takeId".',
        cause: e,
      );
    }

    // 3. 发布录音中状态。
    _state = AudioRecorderState.recording;
    _activeTakeId = takeId;
    _activeTempFile = tempFile;
    _activePaths = paths;
  }

  /// 停止当前录音并返回结果。
  ///
  /// 行为：
  /// - 当前状态必须为 [AudioRecorderState.recording]，否则抛
  ///   [InvalidRecorderStateException]；
  /// - stop 期间状态切换为 [AudioRecorderState.stopping]；
  /// - gateway.stop 抛异常 → 抛 [RecorderStopFailedException]（带 cause），
  ///   **保留**活跃会话（`_activeTakeId` / `_activeTempFile` /
  ///   `_activePaths`），状态回退到 [AudioRecorderState.recording]——
  ///   native 录音是否真的停止仍是黑盒，service 不得假装成"安全
  ///   stopped"，调用方可基于同一 `_activeTempFile.path` 重新
  ///   调用 [stop] 进行重试（T037B2 修复）；
  /// - gateway.stop 返回 `null` 或与请求路径不一致 → 抛
  ///   [RecorderStopFailedException]；活跃会话被清除（这条分支
  ///   表示 gateway 明确确认 stop 完成 → native 不再录音，无重试
  ///   必要），状态回到 idle；temp 文件**不**清理（让 Controller /
  ///   后续 save 流程决定）；
  /// - 成功路径返回 [AudioRecorderTakeResult]，状态恢复 idle。
  Future<AudioRecorderTakeResult> stop() async {
    if (_disposed) {
      throw const InvalidRecorderStateException(
        'Cannot stop after dispose.',
      );
    }
    if (_state != AudioRecorderState.recording) {
      throw InvalidRecorderStateException(
        'Cannot stop: recorder is in state $_state (not recording).',
      );
    }
    final String takeId = _activeTakeId!;
    final String requestedPath = _activeTempFile!.path;

    _state = AudioRecorderState.stopping;

    String? resolved;
    try {
      resolved = await _gateway.stop();
    } catch (e) {
      // T037B2 — gateway.stop threw. We have NO proof the
      // native recorder actually stopped; the platform-channel
      // exception is the only signal we have. Preserve the
      // active session so a retry call can re-issue
      // `gateway.stop()` against the same path. Revert the
      // state to `recording` so the controller / page can
      // observe a stoppable recorder and so a retry sees a
      // valid pre-state. Do NOT report the recorder as
      // safely idle — the service is the source of truth for
      // "is the native recorder running" and the only honest
      // answer here is "unknown, try again".
      _state = AudioRecorderState.recording;
      throw RecorderStopFailedException(
        'Failed to stop audio recorder for take "$takeId".',
        cause: e,
      );
    }

    if (resolved == null) {
      // T037B2 — gateway.stop returned null. The native
      // recorder explicitly reported "no path" which (per the
      // `record` package contract) means the platform side
      // considers the session over. There is no useful retry
      // here — the gateway will keep returning null for
      // subsequent stop() calls. Clear the active session and
      // surface a hard failure to the caller. The temp file
      // is preserved on disk so the controller can still
      // surface it for a save attempt.
      _clearActiveSession();
      _state = AudioRecorderState.idle;
      throw RecorderStopFailedException(
        'Recorder returned null path for take "$takeId".',
      );
    }
    if (!_pathsEqual(resolved, requestedPath)) {
      _clearActiveSession();
      _state = AudioRecorderState.idle;
      throw RecorderStopFailedException(
        'Recorder returned path "$resolved" but requested "$requestedPath".',
      );
    }

    final AudioRecorderTakeResult result = AudioRecorderTakeResult(
      takeId: takeId,
      requestedPath: requestedPath,
      resolvedPath: resolved,
      format: _config.extension,
      sampleRate: _config.sampleRate,
      bitRate: _config.bitRate,
      numChannels: _config.numChannels,
    );
    _clearActiveSession();
    _state = AudioRecorderState.idle;
    return result;
  }

  /// 取消当前录音并清理 temp 文件。
  ///
  /// 行为：
  /// - 当前状态必须为 [AudioRecorderState.recording]，否则抛
  ///   [InvalidRecorderStateException]；
  /// - cancel 期间状态切换为 [AudioRecorderState.cancelling]；
  /// - gateway.cancel 抛异常 → 抛 [RecorderGatewayException]（带 cause），
  ///   仍 best-effort 清理 temp 文件，状态恢复 idle；
  /// - temp 文件清理失败**不**抛错（与 T028 §6.5 一致）；
  /// - 成功路径状态恢复 idle。
  Future<void> cancel() async {
    if (_disposed) {
      throw const InvalidRecorderStateException(
        'Cannot cancel after dispose.',
      );
    }
    if (_state != AudioRecorderState.recording) {
      throw InvalidRecorderStateException(
        'Cannot cancel: recorder is in state $_state (not recording).',
      );
    }
    final String? takeId = _activeTakeId;
    final File? tempFile = _activeTempFile;
    final AudioFileStoragePaths? paths = _activePaths;

    _state = AudioRecorderState.cancelling;

    Object? gatewayError;
    try {
      await _gateway.cancel();
    } catch (e) {
      gatewayError = e;
    }

    // Best-effort 清理 temp 文件（删除失败不抛错）。
    if (tempFile != null && paths != null) {
      try {
        await _storage.deleteIfExists(
          tempFile,
          rootDirectory: paths.rootDirectory,
        );
      } on Object {
        // 清理失败不抛错（与 T028 §6.5 一致）。
      }
    }

    _clearActiveSession();
    _state = AudioRecorderState.idle;

    if (gatewayError != null) {
      throw RecorderGatewayException(
        'Failed to cancel audio recorder for take "$takeId".',
        cause: gatewayError,
      );
    }
  }

  /// 释放 platform channel 资源。
  ///
  /// 行为：
  /// - 多次调用幂等；
  /// - 录音中调用：先调用 gateway.dispose（best-effort），状态切到
  ///   disposed，**不**抛错；
  /// - disposed 后任何 start / stop / cancel 调用抛
  ///   [InvalidRecorderStateException]。
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _state = AudioRecorderState.disposed;
    try {
      await _gateway.dispose();
    } on Object {
      // dispose 失败不抛错（与 MicrophonePermissionService.dispose 契约一致）。
    }
    _clearActiveSession();
  }

  /// 清理活跃会话引用（takeId / temp file / paths）；状态机由调用方
  /// 决定。
  void _clearActiveSession() {
    _activeTakeId = null;
    _activeTempFile = null;
    _activePaths = null;
  }

  /// 跨平台路径等价比较（Windows / POSIX 反斜杠 vs 正斜杠 +
  /// Windows 盘符大小写不敏感）。
  static bool _pathsEqual(String a, String b) {
    if (a == b) {
      return true;
    }
    if (p.normalize(a) == p.normalize(b)) {
      return true;
    }
    // Windows 平台：盘符大小写不敏感 + 路径分隔符不敏感。
    if (Platform.isWindows) {
      return a.toLowerCase() == b.toLowerCase() ||
          p.normalize(a).toLowerCase() == p.normalize(b).toLowerCase();
    }
    return false;
  }
}
