/// 音频文件目录契约（AudioFileStoragePaths）
///
/// T028 真实音频 MVP 音频文件存储基础层：
/// - 不可变数据结构，描述音频文件根目录 / 临时目录 / 已保存目录 / 当日目录；
/// - 由 [AudioFileStorageService.ensureDirectories] 在创建时构造并返回；
/// - **不**暴露用户本机绝对路径到日志；**不**打印路径；
/// - 不依赖 Flutter UI / Riverpod / Codegen；纯 Dart 数据结构。
///
/// 目录契约（与 `REAL_AUDIO_MVP_SDD.md` §4.1 / §4.3 一致）：
/// - `rootDirectory`：app 私有音频根目录，默认 `<docs>/audio`；
/// - `tempDirectory`：录音中 / 未保存的临时文件目录；
/// - `savedDirectory`：已保存录音文件的根目录；
/// - `dayDirectory`：当日临时文件目录（保存到 `saved/YYYY-MM-DD` 之前的临时落地点）；
///
/// 与 `REAL_AUDIO_DEPENDENCY_SPIKE.md` §3.6 + `REAL_AUDIO_MVP_SDD.md` §4.1 一致：
/// - 不使用外部共享目录（`/storage/emulated/0/Music` 等）；
/// - 不使用公共 Downloads / Music / DCIM；
/// - 不申请 `READ/WRITE_EXTERNAL_STORAGE` / `READ_MEDIA_AUDIO`。
library;

import 'dart:io';

/// 不可变数据结构：描述音频文件目录契约。
///
/// 所有 `Directory` 引用在 [AudioFileStorageService.ensureDirectories] 内部
/// 完成 `createSync(recursive: true)`，调用方无需重复创建。
class AudioFileStoragePaths {
  const AudioFileStoragePaths({
    required this.rootDirectory,
    required this.tempDirectory,
    required this.savedDirectory,
    this.dayDirectory,
  });

  /// 音频根目录：所有音频文件都在此目录下。
  final Directory rootDirectory;

  /// 临时文件目录：录音中 / 未保存的临时文件。
  final Directory tempDirectory;

  /// 已保存文件目录：与 `PracticeRecord` 同生命周期的已保存录音文件。
  final Directory savedDirectory;

  /// 当日临时目录：保存到 `saved/YYYY-MM-DD` 之前的临时落地点。
  /// 为可空字段：当不需要按日期分子目录时为 `null`。
  final Directory? dayDirectory;
}