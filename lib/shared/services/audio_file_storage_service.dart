/// 音频文件存储服务（AudioFileStorageService）
///
/// T028 真实音频 MVP 音频文件存储基础层：
/// - 提供注入式根目录（默认使用 `path_provider.getApplicationDocumentsDirectory()`）；
/// - 创建并管理 root / temp / saved 目录；
/// - 生成临时文件路径（`createTempFile`）与已保存文件路径（`savedFileForRecord`）；
/// - 提供文件存在性检查、文件大小读取、安全删除、临时文件清理；
/// - 严格阻止路径逃逸（`..` / 绝对路径 / 外部目录）；
/// - Windows / POSIX 路径兼容；
/// - DateTime 本地日期格式 `YYYY-MM-DD`；
/// - **不**记录绝对路径日志；**不**打印路径；
/// - **不**引用 record / just_audio / permission_handler / audio_session；
/// - **不**调用麦克风；**不**播放音频；
/// - **不**修改 Drift schema；**不**保存真实录音记录。
///
/// 与 `REAL_AUDIO_MVP_SDD.md` §4 / §7.1 一致：
/// - 临时文件：`root/temp/`；
/// - 已保存文件：`root/saved/YYYY-MM-DD/<recordId>.m4a`；
/// - 不使用外部共享目录；卸载 App 时 Android 自动清除（与 SDD §3.7 一致）；
/// - 测试隔离：构造时注入 `rootDirectoryProvider` 返回临时目录。
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'audio_file_storage_paths.dart';

/// 默认音频根目录子目录名（位于 `getApplicationDocumentsDirectory()` 下）。
const String kDefaultAudioRootDirectoryName = 'audio';

/// 临时文件目录子目录名。
const String kTempSubdirectoryName = 'temp';

/// 已保存文件目录子目录名。
const String kSavedSubdirectoryName = 'saved';

/// takeId / recordId 字符串片段最大长度。
const int kIdSegmentMaxLength = 80;

/// 允许的 takeId / recordId 字符串片段字符集（`a-z A-Z 0-9 _ -`）。
final RegExp _idSegmentRegExp = RegExp(r'^[A-Za-z0-9_-]+$');

/// 允许的扩展名字符集（小写 `a-z 0-9`，3-4 字符）。
final RegExp _extensionRegExp = RegExp(r'^[a-z0-9]{2,4}$');

/// 文件大小读取默认实现：使用 `File.lengthSync()` 的同步形式。
///
/// 测试可通过构造时注入 `sizeOf` 替换。
typedef AudioFileSizeOf = int Function(File file);

/// `AudioFileStorageService` 默认生产构造所需的"根目录 provider"。
///
/// 生产环境默认返回 `getApplicationDocumentsDirectory()/audio`。
/// 测试可通过构造时注入返回 `Directory.systemTemp.createTempSync()` 实现隔离。
typedef AudioRootDirectoryProvider = Future<Directory> Function();

/// 默认生产 root provider：基于 `path_provider` 的
/// `getApplicationDocumentsDirectory()` + `audio` 子目录。
Future<Directory> defaultAudioRootDirectoryProvider() async {
  final Directory documentsDir = await getApplicationDocumentsDirectory();
  final Directory audioRoot = Directory(
    p.join(documentsDir.path, kDefaultAudioRootDirectoryName),
  );
  return audioRoot;
}

/// 音频文件存储服务。
///
/// **生命周期**：
/// - 构造时**不**触发任何 IO；仅保存 provider 与 size 委托；
/// - [ensureDirectories] 负责创建 root/temp/saved 目录；
/// - 其他 API 假设目录已创建；调用方应在使用前先调用 `ensureDirectories`。
class AudioFileStorageService {
  /// 构造时注入 root provider；测试中可注入临时目录。
  AudioFileStorageService({
    required AudioRootDirectoryProvider rootDirectoryProvider,
    AudioFileSizeOf? sizeOf,
  })  : _rootDirectoryProvider = rootDirectoryProvider,
        _sizeOf = sizeOf ?? _defaultSizeOf;

  final AudioRootDirectoryProvider _rootDirectoryProvider;
  final AudioFileSizeOf _sizeOf;

  static int _defaultSizeOf(File file) => file.lengthSync();

  /// 创建并返回 [AudioFileStoragePaths]。
  ///
  /// - 调用 [AudioRootDirectoryProvider] 获取根目录；
  /// - 创建 root / temp / saved 三个目录（`createSync(recursive: true)`）；
  /// - 幂等：目录已存在时不会抛异常；
  /// - **不**删除已有文件；**不**清理目录内容。
  Future<AudioFileStoragePaths> ensureDirectories() async {
    final Directory root = await _rootDirectoryProvider();
    final Directory temp = Directory(p.join(root.path, kTempSubdirectoryName));
    final Directory saved = Directory(p.join(root.path, kSavedSubdirectoryName));

    if (!root.existsSync()) {
      root.createSync(recursive: true);
    }
    if (!temp.existsSync()) {
      temp.createSync(recursive: true);
    }
    if (!saved.existsSync()) {
      saved.createSync(recursive: true);
    }

    return AudioFileStoragePaths(
      rootDirectory: root,
      tempDirectory: temp,
      savedDirectory: saved,
    );
  }

  /// 返回 temp 目录下安全文件路径，**不**实际写入内容。
  ///
  /// 调用方拿到路径后可由真实录音服务（未来 T029 实现）写入内容。
  /// 当前 T028 任务仅生成路径契约。
  ///
  /// [takeId] 必须满足：
  /// - 非空；
  /// - 仅允许 `a-z A-Z 0-9 _ -`；
  /// - 最大长度 [kIdSegmentMaxLength]；
  /// - 禁止 `/` `\` `.` 空格；
  /// - 禁止 `..`。
  ///
  /// [extension] 必须满足：
  /// - 非空；
  /// - 默认 `m4a`；
  /// - 允许 `m4a` / `aac` / `wav`；
  /// - 禁止带 `.`；禁止路径分隔符；禁止空格。
  ///
  /// 违反规则抛 [ArgumentError]。
  Future<File> createTempFile({
    required String takeId,
    String extension = 'm4a',
    required Directory tempDirectory,
  }) {
    _validateIdSegment(takeId, 'takeId');
    _validateExtension(extension);

    final String fileName = '$takeId.$extension';
    final String absolutePath = p.join(tempDirectory.path, fileName);
    return Future.value(File(absolutePath));
  }

  /// 返回 `saved/YYYY-MM-DD/<recordId>.m4a` 路径，并创建日期目录。
  ///
  /// - **不**覆盖已有文件；
  /// - 日期目录按 `practiceDate` 本地午夜构造 `YYYY-MM-DD` 格式；
  /// - [recordId] 校验与 [createTempFile] takeId 一致；
  /// - 校验失败抛 [ArgumentError]；路径解析失败抛 [FileSystemException]。
  Future<File> savedFileForRecord({
    required String recordId,
    required DateTime practiceDate,
    String extension = 'm4a',
    required Directory savedDirectory,
  }) {
    _validateIdSegment(recordId, 'recordId');
    _validateExtension(extension);

    final String daySubdirectory = _formatLocalDay(practiceDate);
    final Directory dayDir =
        Directory(p.join(savedDirectory.path, daySubdirectory));
    if (!dayDir.existsSync()) {
      dayDir.createSync(recursive: true);
    }

    final String fileName = '$recordId.$extension';
    final String absolutePath = p.join(dayDir.path, fileName);
    final File file = File(absolutePath);

    // 不覆盖已有文件：调用方负责在写入前决定是否替换。
    // 本方法仅提供路径生成；写入由 T029 录音服务或 T031 Controller 负责。
    return Future.value(file);
  }

  /// 文件存在性检查。
  Future<bool> exists(File file) async {
    return file.exists();
  }

  /// 文件大小读取；不存在返回 `0`，方便 UI 降级（与 `REAL_AUDIO_MVP_SDD.md` §6.7 一致）。
  ///
  /// 设计选择：返回 `0` 而非抛异常的理由：
  /// - UI 隐藏回放按钮（沿用 MVP 既有行为）+ 标记 `audioDeletedAt`（待 T032 确认）；
  /// - 避免 Controller 在文件丢失时异常分支过度；
  /// - 调用方如需区分"文件存在但大小为 0"与"文件不存在"两种情况，可先调用
  ///   [exists] 再调用 [sizeBytes]。
  Future<int> sizeBytes(File file) async {
    if (!await file.exists()) {
      return 0;
    }
    return _sizeOf(file);
  }

  /// 文件存在则删除并返回 `true`；不存在返回 `false`。
  ///
  /// **安全规则**：
  /// - 仅允许删除 [rootDirectory] 之下的文件；
  /// - 阻止路径逃逸（`..` / 绝对路径）；
  /// - 目录路径不得删除（必须是 `File`）；
  /// - **不**删除 [rootDirectory] 本身；
  /// - 文件不存在返回 `false`，不抛异常。
  ///
  /// 越权调用抛 [ArgumentError]。
  Future<bool> deleteIfExists(File file, {required Directory rootDirectory}) async {
    if (!await file.exists()) {
      return false;
    }

    if (!_isPathInsideRoot(file.path, rootDirectory.path)) {
      throw ArgumentError(
        'Refusing to delete file outside of audio root directory.',
      );
    }

    await file.delete();
    return true;
  }

  /// 删除 temp 下普通文件；**不**删除 saved 下文件；**不**删除目录。
  ///
  /// 返回删除数量。仅清理扩展名为 `m4a` / `aac` / `wav` 的文件，避免误删。
  ///
  /// **安全规则**：
  /// - 扫描范围：[tempDirectory] 下顶层条目；
  /// - 仅删除 `File` 且扩展名在白名单内的项；
  /// - 任何目录（含子目录）**不**递归删除；
  /// - 仅删除 [rootDirectory] 路径下的条目；
  /// - 越权条目跳过（计数不计）。
  Future<int> cleanupTempFiles({
    required Directory tempDirectory,
    required Directory rootDirectory,
  }) async {
    if (!tempDirectory.existsSync()) {
      return 0;
    }
    final String tempRootCanonical = _canonicalPath(rootDirectory.path);
    final String tempCanonical = _canonicalPath(tempDirectory.path);
    if (!_isCanonicalChild(tempCanonical, tempRootCanonical)) {
      throw ArgumentError(
        'Refusing to clean up temp directory outside of audio root directory.',
      );
    }

    int deletedCount = 0;
    await for (final FileSystemEntity entity in tempDirectory.list()) {
      if (entity is! File) {
        // 目录（含子目录）不递归删除
        continue;
      }
      final String entityCanonical = _canonicalPath(entity.path);
      if (!_isCanonicalChild(entityCanonical, tempCanonical)) {
        // 路径逃逸防御：不在 temp 下的条目直接跳过
        continue;
      }
      if (!_isWhitelistedExtension(entity.path)) {
        // 非白名单扩展名跳过
        continue;
      }
      try {
        await entity.delete();
        deletedCount += 1;
      } on FileSystemException {
        // 单文件删除失败不阻断其他文件清理
        continue;
      }
    }
    return deletedCount;
  }

  /// 检查 [entity] 路径是否在 [rootDirectory] 之下（含 root 本身）。
  ///
  /// 公开方法：Controller / Repository 删除流程可主动调用以做防御性校验。
  bool isPathInsideRoot(
    FileSystemEntity entity,
    Directory rootDirectory,
  ) {
    return _isPathInsideRoot(entity.path, rootDirectory.path);
  }

  // ---------------------------------------------------------------------------
  // 内部工具
  // ---------------------------------------------------------------------------

  /// 校验 ID 字符串片段（takeId / recordId）。
  ///
  /// 规则：
  /// - 非空；
  /// - 长度 ≤ [kIdSegmentMaxLength]；
  /// - 仅允许 `a-z A-Z 0-9 _ -`；
  /// - 禁止 `.` `..`；
  /// - 路径分隔符已被字符集规则覆盖（`_idSegmentRegExp`）。
  static void _validateIdSegment(String value, String name) {
    if (value.isEmpty) {
      throw ArgumentError('$name must not be empty.');
    }
    if (value.length > kIdSegmentMaxLength) {
      throw ArgumentError(
        '$name length must be <= $kIdSegmentMaxLength characters.',
      );
    }
    if (value == '..' || value.contains('.')) {
      throw ArgumentError(
        '$name must not contain "." or be exactly "..".',
      );
    }
    if (value.contains(' ') ||
        value.contains('/') ||
        value.contains('\\')) {
      throw ArgumentError(
        '$name must not contain spaces or path separators.',
      );
    }
    if (!_idSegmentRegExp.hasMatch(value)) {
      throw ArgumentError(
        '$name may only contain [A-Za-z0-9_-] characters.',
      );
    }
  }

  /// 校验扩展名。
  ///
  /// 规则：
  /// - 非空；
  /// - 默认 `m4a`；
  /// - 仅允许 `a-z 0-9` 且长度 2-4；
  /// - 禁止 `.` / 路径分隔符 / 空格（已被正则覆盖）。
  static void _validateExtension(String extension) {
    if (extension.isEmpty) {
      throw ArgumentError('extension must not be empty.');
    }
    if (extension.contains('.') ||
        extension.contains('/') ||
        extension.contains('\\') ||
        extension.contains(' ')) {
      throw ArgumentError(
        'extension must not contain "." / path separators / spaces.',
      );
    }
    if (!_extensionRegExp.hasMatch(extension)) {
      throw ArgumentError(
        'extension must match [a-z0-9]{2,4}; got "$extension".',
      );
    }
  }

  /// 格式化本地日期为 `YYYY-MM-DD`。
  ///
  /// 使用本地午夜而非 UTC（与 `REAL_AUDIO_MVP_SDD.md` §6.2 一致）。
  static String _formatLocalDay(DateTime dateTime) {
    final DateTime local = dateTime.isUtc ? dateTime.toLocal() : dateTime;
    final String yyyy = local.year.toString().padLeft(4, '0');
    final String mm = local.month.toString().padLeft(2, '0');
    final String dd = local.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }

  /// 检查 [path] 是否在 [rootPath] 之下。
  ///
  /// 同时处理 Windows 反斜杠与 POSIX 正斜杠，跨平台一致。
  static bool _isPathInsideRoot(String path, String rootPath) {
    final String canonicalPath = _canonicalPath(path);
    final String canonicalRoot = _canonicalPath(rootPath);
    if (canonicalPath == canonicalRoot) {
      // root 本身不允许删除
      return false;
    }
    return _isCanonicalChild(canonicalPath, canonicalRoot);
  }

  /// 规范化路径分隔符为 `/`，便于跨平台比较。
  static String _canonicalPath(String path) {
    final String normalized = p.normalize(path);
    return normalized.replaceAll('\\', '/');
  }

  /// 检查 [child] 是否为 [parent] 之下（含 `parent/child`）。
  static bool _isCanonicalChild(String child, String parent) {
    if (child == parent) {
      return true;
    }
    final String prefix = parent.endsWith('/') ? parent : '$parent/';
    return child.startsWith(prefix);
  }

  /// 检查扩展名是否在白名单（`m4a` / `aac` / `wav`）。
  static bool _isWhitelistedExtension(String path) {
    final String ext = p.extension(path).replaceFirst('.', '').toLowerCase();
    if (ext.isEmpty) {
      return false;
    }
    return ext == 'm4a' || ext == 'aac' || ext == 'wav';
  }
}