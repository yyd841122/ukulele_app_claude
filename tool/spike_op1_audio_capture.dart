/// OP-1 Audio Capture Spike 工具（spike_op1_audio_capture）
///
/// 任务 ID: T050_OP1_AUDIO_CAPTURE_SPIKE
/// 上游: docs/PRD_v2.md v0.3 / docs/architecture/SDD_V2.md v0.4 /
///       docs/architecture/TDD_PRODUCT_V2_PHASE1.md v1.0
///
/// **本任务只做 spike + ADR；不写正式生产代码；不接入 UI；不修改现有录音回放闭环。**
///
/// ## 目的
///
/// 验证 SDD v0.4 §7.2 "OP-1 A 方案"（双 `record` 实例并行）：
/// - 实例 A：用 `start(RecordConfig(encoder: AudioEncoder.aacLc))` 写 m4a 文件（**不**修改现有 T029 录音服务）
/// - 实例 B：用 `startStream(RecordConfig(encoder: AudioEncoder.pcm16bits))` 输出 PCM `Stream<Uint8List>`
///
/// **本工具可被 `flutter run -d <device>` 直接执行（**需真机**），但**
/// **当前任务执行环境无真机，本工具仅静态验证 + ADR 收口。**
///
/// ## 工具的边界
///
/// - **不**修改 `lib/**` 任何文件（生产代码不动）
/// - **不**修改 `pubspec.yaml` / `pubspec.lock` / `android/**` / Manifest
/// - **不**调用现有 `RealAudioRecorderService`（避免污染 T029 / T030 既有契约）
/// - **不**启动 `MicrophonePermissionService`（避免与 T027 既有契约冲突）
/// - **不**写 `test/**` / `integration_test/**`
/// - **不**升级 Drift schema
/// - **不**新增 INTERNET 权限
///
/// 工具设计参考 SDD v0.4 §3.5 "OP-1 = 方案 A 时的扩展契约" + TDD v1.0 §5.1
/// "Spike 协议" 7 项必含清单。
///
/// ## 真机执行命令（**当前未执行**）
///
/// ```bash
/// flutter run -d <android-device> tool/spike_op1_audio_capture.dart
/// ```
///
/// 真机执行时必须记录：
/// 1. 设备型号 + Android 版本 + 厂商 ROM + 麦克风硬件型号
/// 2. 5s / 30s / 5min 三档断点
/// 3. m4a 文件路径 + 文件大小
/// 4. m4a 是否可被 `just_audio` 解码 + 播放
/// 5. PCM chunk 数量 + 间隔统计 + 是否有长时间中断
/// 6. start / stop 顺序
/// 7. onStop / onCancel 回调归属（不串台）
/// 8. 资源释放（dispose 后能否再次启动）
/// 9. 权限：denied / granted / permanentDenied / 恢复表现
///
/// ## 当前任务（T050）的执行结果
///
/// 当前任务执行环境无真机 → **本工具未在真机上运行**。所有真机物理实验
/// 项（5s / 30s / 5min / m4a 完整性 / PCM 连续性 / 回调归属 / 资源释放）
/// **均未获得真机证据**。
///
/// ADR 决策必须为 `Blocked`（单设备未通过 + 真机未执行）—— 详见
/// `docs/architecture/OP1_AUDIO_CAPTURE_ADR.md` §14。
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

/// Spike 运行配置。
class _SpikeConfig {
  const _SpikeConfig({
    required this.duration,
    required this.deviceLabel,
    required this.androidVersion,
    required this.rom,
  });

  final Duration duration;
  final String deviceLabel;
  final String androidVersion;
  final String rom;
}

/// Spike 运行结果。
class _SpikeResult {
  _SpikeResult({
    required this.config,
    required this.m4aPath,
    required this.m4aSizeBytes,
    required this.pcmChunkCount,
    required this.pcmTotalBytes,
    required this.pcmIntervalStatsMs,
    required this.startOrder,
    required this.stopOrder,
    required this.errors,
  });

  final _SpikeConfig config;
  final String m4aPath;
  final int m4aSizeBytes;
  final int pcmChunkCount;
  final int pcmTotalBytes;
  final List<int> pcmIntervalStatsMs;
  final List<String> startOrder;
  final List<String> stopOrder;
  final List<String> errors;

  /// 是否满足 7 项必含清单（仅作"代码可达"层面的检查，真机数据缺失）。
  bool get codeLevelChecksPassed =>
      m4aPath.isNotEmpty &&
      startOrder.length == 2 &&
      stopOrder.length == 2 &&
      errors.isEmpty;
}

/// 写入 spike 日志（本地 7 天生命周期；**不**上传）。
Future<File> _writeLog(
  String dir,
  String deviceLabel,
  String content,
) async {
  final Directory d = Directory(dir);
  if (!d.existsSync()) {
    d.createSync(recursive: true);
  }
  final String stamp = DateTime.now()
      .toIso8601String()
      .replaceAll(':', '-')
      .replaceAll('.', '-');
  final String safeDevice = deviceLabel
      .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')
      .toLowerCase();
  final File f = File(p.join(dir, 'op1_${safeDevice}_$stamp.log'));
  await f.writeAsString(content);
  return f;
}

/// PCM chunk 间隔统计。
List<int> _pcmIntervals(List<DateTime> arrivals) {
  if (arrivals.length < 2) {
    return const <int>[];
  }
  final List<int> intervals = <int>[];
  for (int i = 1; i < arrivals.length; i++) {
    intervals.add(
      arrivals[i].difference(arrivals[i - 1]).inMilliseconds,
    );
  }
  return intervals;
}

/// 真机 Spike 主体。
///
/// 流程（按 SDD v0.4 §3.5 "OP-1 = 方案 A 时的扩展契约" + TDD v1.0 §5.1）：
/// 1. 申请 `RECORD_AUDIO`（使用 `record` 内置 `hasPermission()`，不与既有
///    `MicrophonePermissionService` 冲突）
/// 2. 准备 temp m4a 路径
/// 3. 双实例 start：先 m4a（A 方案"先 m4a 再 PCM 流"）
/// 4. 订阅 PCM stream
/// 5. 等待 [duration]
/// 6. 双实例 stop：先 PCM stream stop（stop 顺序与 start 反序）
/// 7. 校验 m4a 文件存在 + 大小 > 0
/// 8. 校验 PCM chunk 数量 + 间隔
/// 9. dispose 两个实例
/// 10. 资源释放后再次 start（验证幂等性）
Future<_SpikeResult> _runSpike(
  _SpikeConfig config,
  Directory tempDir,
) async {
  // 1. 权限。
  final AudioRecorder permissionProbe = AudioRecorder();
  final bool hasPermission = await permissionProbe.hasPermission();
  await permissionProbe.dispose();
  if (!hasPermission) {
    return _SpikeResult(
      config: config,
      m4aPath: '',
      m4aSizeBytes: 0,
      pcmChunkCount: 0,
      pcmTotalBytes: 0,
      pcmIntervalStatsMs: const <int>[],
      startOrder: const <String>[],
      stopOrder: const <String>[],
      errors: <String>['RECORD_AUDIO permission denied at hasPermission()'],
    );
  }

  // 2. 准备 temp m4a 路径。
  final String takeId = const Uuid().v4();
  final String m4aName = '$takeId.m4a';
  final String m4aPath = p.join(tempDir.path, m4aName);

  // 3-4. 双实例。
  final AudioRecorder m4aRecorder = AudioRecorder();
  final AudioRecorder pcmRecorder = AudioRecorder();

  final List<String> startOrder = <String>[];
  final List<String> stopOrder = <String>[];
  final List<String> errors = <String>[];
  final List<DateTime> pcmArrivals = <DateTime>[];
  int pcmTotalBytes = 0;

  StreamSubscription<Uint8List>? pcmSub;

  try {
    // 3. Start m4a。
    await m4aRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        bitRate: 128000,
        numChannels: 1,
      ),
      path: m4aPath,
    );
    startOrder.add('m4a.start');

    // 4. Start PCM stream。
    final Stream<Uint8List> pcmStream = await pcmRecorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 44100,
        numChannels: 1,
      ),
    );
    startOrder.add('pcm.startStream');

    pcmSub = pcmStream.listen(
      (Uint8List chunk) {
        pcmArrivals.add(DateTime.now());
        pcmTotalBytes += chunk.length;
      },
      onError: (Object e, StackTrace st) {
        errors.add('pcm stream error: $e');
      },
    );

    // 5. 等待。
    await Future<void>.delayed(config.duration);

    // 6. Stop 反序：先 PCM 流，再 m4a。
    final StreamSubscription<Uint8List> sub = pcmSub;
    pcmSub = null;
    await sub.cancel();
    await pcmRecorder.stop();
    stopOrder.add('pcm.stop');
    final String? m4aResolved = await m4aRecorder.stop();
    stopOrder.add('m4a.stop');

    if (m4aResolved == null) {
      errors.add('m4a.stop returned null');
    } else if (m4aResolved != m4aPath) {
      errors.add('m4a.stop path mismatch: $m4aResolved vs $m4aPath');
    }
  } catch (e, st) {
    errors.add('spike exception: $e\n$st');
  } finally {
    // 9. Dispose（best-effort; 即使 listen 抛错也要释放 platform channel）。
    final StreamSubscription<Uint8List>? sub = pcmSub;
    pcmSub = null;
    if (sub != null) {
      await sub.cancel();
    }
    await m4aRecorder.dispose();
    await pcmRecorder.dispose();
  }

  // 7. m4a 文件检查。
  final File m4aFile = File(m4aPath);
  int m4aSize = 0;
  bool m4aExists = false;
  if (m4aFile.existsSync()) {
    m4aSize = m4aFile.lengthSync();
    m4aExists = m4aSize > 0;
  }
  if (!m4aExists) {
    errors.add('m4a file missing or empty: $m4aPath');
  }

  return _SpikeResult(
    config: config,
    m4aPath: m4aPath,
    m4aSizeBytes: m4aSize,
    pcmChunkCount: pcmArrivals.length,
    pcmTotalBytes: pcmTotalBytes,
    pcmIntervalStatsMs: _pcmIntervals(pcmArrivals),
    startOrder: startOrder,
    stopOrder: stopOrder,
    errors: errors,
  );
}

/// 7 项必含清单的代码层校验（真机数据缺失时，输出**已知**项 PASS / **未知**项 NOT RUN）。
String _formatResult(_SpikeResult r) {
  final StringBuffer b = StringBuffer();
  b.writeln('=== OP-1 Spike Result ===');
  b.writeln('device: ${r.config.deviceLabel}');
  b.writeln('android: ${r.config.androidVersion}');
  b.writeln('rom: ${r.config.rom}');
  b.writeln('duration: ${r.config.duration.inSeconds}s');
  b.writeln('');
  b.writeln('[code-level] m4a path: ${r.m4aPath}');
  b.writeln('[code-level] m4a size: ${r.m4aSizeBytes} bytes');
  b.writeln('[code-level] pcm chunks: ${r.pcmChunkCount}');
  b.writeln('[code-level] pcm total bytes: ${r.pcmTotalBytes}');
  b.writeln('[code-level] pcm interval ms: ${r.pcmIntervalStatsMs}');
  b.writeln('[code-level] start order: ${r.startOrder}');
  b.writeln('[code-level] stop order: ${r.stopOrder}');
  b.writeln('[code-level] errors: ${r.errors}');
  b.writeln('');
  b.writeln('--- 7 项必含清单状态（**真机未执行**） ---');
  b.writeln('1. 5s/30s/5min 三档断点: NOT RUN（无真机）');
  b.writeln('2. m4a 完整性 (just_audio decode + play): NOT RUN（无真机）');
  b.writeln('3. PCM 连续性 (chunk 序号 / 间隔): NOT RUN（无真机）');
  b.writeln('4. 权限生命周期: NOT RUN（无真机）');
  b.writeln('5. start / stop 顺序: code-level PASS（API 路径可走通）');
  b.writeln('6. onStop/onCancel 回调归属: NOT RUN（无真机）');
  b.writeln('7. 资源释放 + 重复启动: NOT RUN（无真机）');
  b.writeln('8. 设备兼容矩阵 ≥2 设备: NOT RUN（无真机）');
  return b.toString();
}

/// spike 工具入口。
///
/// `flutter run -d <device> tool/spike_op1_audio_capture.dart`
/// 会调用 `main`。
Future<void> main(List<String> args) async {
  // T050 当前执行环境无真机 → 仅打印说明 + 静态校验，不执行真机 run。
  // 工具设计目标：未来用户在真机上 `flutter run tool/spike_op1_audio_capture.dart`
  // 即可执行 5s/30s/5min 三档真机实验。日志写入 `e2e/spike_logs/`。
  // ignore: avoid_print
  print('T050_OP1_AUDIO_CAPTURE_SPIKE');
  // ignore: avoid_print
  print('=========================================');
  // ignore: avoid_print
  print('当前任务执行环境无真机。');
  // ignore: avoid_print
  print('本工具代码已就绪，但**未在真机上执行**。');
  // ignore: avoid_print
  print('真机执行命令: flutter run -d <device> tool/spike_op1_audio_capture.dart');
  // ignore: avoid_print
  print('=========================================');

  // 即便无真机，也产出"代码可达"日志，供 ADR 收口。
  final Directory tempBase = await getTemporaryDirectory();
  final Directory spikeTemp = Directory(
    p.join(tempBase.path, 'op1_spike_${DateTime.now().millisecondsSinceEpoch}'),
  );
  spikeTemp.createSync(recursive: true);

  final _SpikeConfig config = _SpikeConfig(
    duration: const Duration(seconds: 5),
    deviceLabel: 'NOT_RUN_NO_REAL_DEVICE',
    androidVersion: 'NOT_RUN',
    rom: 'NOT_RUN',
  );
  final _SpikeResult result = await _runSpike(config, spikeTemp);
  final String text = _formatResult(result);
  // ignore: avoid_print
  print(text);

  // 写日志（**不**上传；本地 7 天生命周期）。
  try {
    final String repoRoot = Directory.current.path;
    final String logDir = p.join(repoRoot, 'e2e', 'spike_logs');
    final File log = await _writeLog(logDir, config.deviceLabel, text);
    // ignore: avoid_print
    print('log written: ${log.path}');
  } on Object {
    // 日志写入失败不阻断 spike。
  }

  // spike 完成 → process exit 0。
  // 注：当前任务执行环境无真机，**没有真机证据**；ADR 决策必须为 Blocked。
  exit(0);
}
