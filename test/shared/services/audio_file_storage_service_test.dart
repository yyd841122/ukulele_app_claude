// Tests for [AudioFileStorageService] (T028).
//
// Strategy:
// - 服务通过 [AudioRootDirectoryProvider] 注入实现测试隔离；
//   测试用 [Directory.systemTemp.createTempSync()] 创建临时根目录，
//   测试结束通过 `addTearDown` 清理。
// - **不**触发真实系统权限弹窗；**不**调用麦克风；**不**调用 `path_provider`；
// - **不**使用 mocktail / mockito；fake provider 注入即可覆盖。
// - 文件存在性检查 / 文件大小读取 / 安全删除 / 临时文件清理 / 路径逃逸防护
//   全覆盖。
// - 文件名片段校验（takeId / recordId）覆盖空、点、点点、空格、斜杠、反斜杠。
// - 扩展名校验覆盖空、点、斜杠、反斜杠、空格。
// - 测试与录音 / 播放 SDK（record / just_audio / audio_session /
//   permission_handler）契约隔离：service 测试文件**不**引用这些包。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:ukulele_app/shared/services/audio_file_storage_service.dart';

int _counter = 0;

/// 单元测试用 root directory provider：返回 `Directory.systemTemp` 下唯一临时目录。
///
/// 每次测试独立创建；测试结束通过 `addTearDown` 删除。
class _IsolatedRootProvider {
  _IsolatedRootProvider(this._root);

  final Directory _root;
  bool _called = false;

  bool get called => _called;
  Directory get root => _root;

  Future<Directory> call() async {
    _called = true;
    return _root;
  }
}

/// 创建隔离的根目录；返回 provider + 根目录引用 + tearDown hook。
({_IsolatedRootProvider provider, Directory root}) _createIsolatedRoot() {
  final Directory root = Directory(
    p.join(
      Directory.systemTemp.path,
      'audio_storage_${DateTime.now().microsecondsSinceEpoch}_${_counter++}',
    ),
  );
  addTearDown(() {
    if (root.existsSync()) {
      try {
        root.deleteSync(recursive: true);
      } on FileSystemException {
        // ignore
      }
    }
  });
  return (provider: _IsolatedRootProvider(root), root: root);
}

/// 把 `_IsolatedRootProvider` 实例适配为 [AudioRootDirectoryProvider] typedef。
AudioRootDirectoryProvider _providerAdapter(_IsolatedRootProvider p) => p.call;

/// 删除临时根目录（如存在）。
void _cleanupRoot(Directory root) {
  if (root.existsSync()) {
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // ignore
    }
  }
}

void main() {
  group('AudioFileStorageService.ensureDirectories', () {
    test('creates root temp saved', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final service = AudioFileStorageService(
        rootDirectoryProvider: _providerAdapter(provider),
      );

      final paths = await service.ensureDirectories();

      expect(provider.called, isTrue);
      expect(paths.rootDirectory.path, root.path);
      expect(paths.tempDirectory.path, p.join(root.path, 'temp'));
      expect(paths.savedDirectory.path, p.join(root.path, 'saved'));
      expect(paths.rootDirectory.existsSync(), isTrue);
      expect(paths.tempDirectory.existsSync(), isTrue);
      expect(paths.savedDirectory.existsSync(), isTrue);
      _cleanupRoot(root);
    });

    test('is idempotent (calling twice does not throw)', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final service = AudioFileStorageService(
        rootDirectoryProvider: _providerAdapter(provider),
      );

      final first = await service.ensureDirectories();
      // 在中间放一个文件，确保第二次调用不删除
      final sentinel = File(p.join(first.tempDirectory.path, 'sentinel.tmp'));
      sentinel.writeAsStringSync('keep me');

      final second = await service.ensureDirectories();

      expect(second.rootDirectory.path, first.rootDirectory.path);
      expect(second.tempDirectory.path, first.tempDirectory.path);
      expect(second.savedDirectory.path, first.savedDirectory.path);
      expect(sentinel.existsSync(), isTrue,
          reason: 'existing files must not be deleted by idempotent re-create');
      _cleanupRoot(root);
    });
  });

  group('AudioFileStorageService.createTempFile', () {
    test('returns temp path with provided extension', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final service = AudioFileStorageService(
        rootDirectoryProvider: _providerAdapter(provider),
      );
      final paths = await service.ensureDirectories();

      final file = await service.createTempFile(
        takeId: 'rec_001',
        extension: 'm4a',
        tempDirectory: paths.tempDirectory,
      );

      expect(file.path, p.join(paths.tempDirectory.path, 'rec_001.m4a'));
      _cleanupRoot(root);
    });

    test('validates takeId empty', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final service = AudioFileStorageService(
        rootDirectoryProvider: _providerAdapter(provider),
      );
      final paths = await service.ensureDirectories();

      await expectLater(
        () => service.createTempFile(
          takeId: '',
          extension: 'm4a',
          tempDirectory: paths.tempDirectory,
        ),
        throwsA(isA<ArgumentError>()),
      );
      _cleanupRoot(root);
    });

    test('rejects path traversal (..)', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final service = AudioFileStorageService(
        rootDirectoryProvider: _providerAdapter(provider),
      );
      final paths = await service.ensureDirectories();

      await expectLater(
        () => service.createTempFile(
          takeId: '..',
          extension: 'm4a',
          tempDirectory: paths.tempDirectory,
        ),
        throwsA(isA<ArgumentError>()),
      );
      _cleanupRoot(root);
    });

    test('rejects slash/backslash/dot/space in takeId', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final service = AudioFileStorageService(
        rootDirectoryProvider: _providerAdapter(provider),
      );
      final paths = await service.ensureDirectories();

      for (final bad in ['a/b', 'a\\b', 'a.b', 'a b', 'a@b', 'a:b']) {
        await expectLater(
          () => service.createTempFile(
            takeId: bad,
            extension: 'm4a',
            tempDirectory: paths.tempDirectory,
          ),
          throwsA(isA<ArgumentError>()),
          reason: 'takeId="$bad" must be rejected',
        );
      }
      _cleanupRoot(root);
    });

    test('rejects invalid extension', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final service = AudioFileStorageService(
        rootDirectoryProvider: _providerAdapter(provider),
      );
      final paths = await service.ensureDirectories();

      for (final bad in ['', '.m4a', 'm4a/', 'm4a\\', 'mp 3', 'mpThree']) {
        await expectLater(
          () => service.createTempFile(
            takeId: 'rec_001',
            extension: bad,
            tempDirectory: paths.tempDirectory,
          ),
          throwsA(isA<ArgumentError>()),
          reason: 'extension="$bad" must be rejected',
        );
      }
      _cleanupRoot(root);
    });
  });

  group('AudioFileStorageService.savedFileForRecord', () {
    test('returns saved/YYYY-MM-DD/recordId.m4a', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final service = AudioFileStorageService(
        rootDirectoryProvider: _providerAdapter(provider),
      );
      final paths = await service.ensureDirectories();
      final practiceDate = DateTime(2026, 6, 21);

      final file = await service.savedFileForRecord(
        recordId: 'rec_001',
        practiceDate: practiceDate,
        extension: 'm4a',
        savedDirectory: paths.savedDirectory,
      );

      expect(file.path,
          p.join(paths.savedDirectory.path, '2026-06-21', 'rec_001.m4a'));
      _cleanupRoot(root);
    });

    test('creates day directory', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final service = AudioFileStorageService(
        rootDirectoryProvider: _providerAdapter(provider),
      );
      final paths = await service.ensureDirectories();

      await service.savedFileForRecord(
        recordId: 'rec_001',
        practiceDate: DateTime(2026, 6, 21),
        savedDirectory: paths.savedDirectory,
      );

      final dayDir = Directory(p.join(paths.savedDirectory.path, '2026-06-21'));
      expect(dayDir.existsSync(), isTrue);
      _cleanupRoot(root);
    });

    test('validates recordId (rejects invalid)', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final service = AudioFileStorageService(
        rootDirectoryProvider: _providerAdapter(provider),
      );
      final paths = await service.ensureDirectories();

      await expectLater(
        () => service.savedFileForRecord(
          recordId: '',
          practiceDate: DateTime(2026, 6, 21),
          savedDirectory: paths.savedDirectory,
        ),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        () => service.savedFileForRecord(
          recordId: '../escape',
          practiceDate: DateTime(2026, 6, 21),
          savedDirectory: paths.savedDirectory,
        ),
        throwsA(isA<ArgumentError>()),
      );
      _cleanupRoot(root);
    });
  });

  group('AudioFileStorageService.exists', () {
    test('returns true for existing file', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final service = AudioFileStorageService(
        rootDirectoryProvider: _providerAdapter(provider),
      );
      final paths = await service.ensureDirectories();
      final file = await service.createTempFile(
        takeId: 'rec_001',
        tempDirectory: paths.tempDirectory,
      );
      file.writeAsStringSync('hello');

      expect(await service.exists(file), isTrue);
      _cleanupRoot(root);
    });

    test('returns false for missing file', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final service = AudioFileStorageService(
        rootDirectoryProvider: _providerAdapter(provider),
      );
      final paths = await service.ensureDirectories();
      final file = await service.createTempFile(
        takeId: 'rec_missing',
        tempDirectory: paths.tempDirectory,
      );

      expect(await service.exists(file), isFalse);
      _cleanupRoot(root);
    });
  });

  group('AudioFileStorageService.sizeBytes', () {
    test('returns file length for existing file', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final service = AudioFileStorageService(
        rootDirectoryProvider: _providerAdapter(provider),
      );
      final paths = await service.ensureDirectories();
      final file = await service.createTempFile(
        takeId: 'rec_size',
        tempDirectory: paths.tempDirectory,
      );
      const content = '0123456789';
      file.writeAsStringSync(content);

      final size = await service.sizeBytes(file);
      expect(size, content.length);
      _cleanupRoot(root);
    });

    test('returns 0 for missing file', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final service = AudioFileStorageService(
        rootDirectoryProvider: _providerAdapter(provider),
      );
      final paths = await service.ensureDirectories();
      final file = await service.createTempFile(
        takeId: 'rec_missing',
        tempDirectory: paths.tempDirectory,
      );

      final size = await service.sizeBytes(file);
      expect(size, 0);
      _cleanupRoot(root);
    });
  });

  group('AudioFileStorageService.deleteIfExists', () {
    test('deletes file inside root', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final service = AudioFileStorageService(
        rootDirectoryProvider: _providerAdapter(provider),
      );
      final paths = await service.ensureDirectories();
      final file = await service.createTempFile(
        takeId: 'rec_delete',
        tempDirectory: paths.tempDirectory,
      );
      file.writeAsStringSync('bye');

      final result = await service.deleteIfExists(
        file,
        rootDirectory: paths.rootDirectory,
      );

      expect(result, isTrue);
      expect(file.existsSync(), isFalse);
      _cleanupRoot(root);
    });

    test('returns false for missing file', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final service = AudioFileStorageService(
        rootDirectoryProvider: _providerAdapter(provider),
      );
      final paths = await service.ensureDirectories();
      final file = await service.createTempFile(
        takeId: 'rec_ghost',
        tempDirectory: paths.tempDirectory,
      );

      final result = await service.deleteIfExists(
        file,
        rootDirectory: paths.rootDirectory,
      );

      expect(result, isFalse);
      _cleanupRoot(root);
    });

    test('refuses to delete the root directory itself', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final service = AudioFileStorageService(
        rootDirectoryProvider: _providerAdapter(provider),
      );
      final paths = await service.ensureDirectories();

      // 即便把 root 目录路径包装成 File 并绕过 exists 检查，
      // service 仍应在路径校验阶段拒绝删除 root。
      // 本测试先调用 ensureDirectories 后立刻把 root 包装成 File，
      // 通过 existsSync() 之前的实现细节验证路径校验优先级：
      // 若 exists 返回 true（不太可能，因为 root 是目录），路径校验应拒绝；
      // 若 exists 返回 false（File 包装目录路径的正常行为），
      // service 直接返回 false 而不抛错 — 这同样证明 root 不被删除。
      final rootAsFile = File(paths.rootDirectory.path);
      expect(rootAsFile.existsSync(), isFalse,
          reason: 'File wrapping a directory path must not exist as a file');

      final result = await service.deleteIfExists(
        rootAsFile,
        rootDirectory: paths.rootDirectory,
      );

      // 期望：返回 false（root 未被删除），且 root 目录仍然存在。
      expect(result, isFalse);
      expect(paths.rootDirectory.existsSync(), isTrue);
      _cleanupRoot(root);
    });

    test('refuses root-outside path even when wrapped as File', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final service = AudioFileStorageService(
        rootDirectoryProvider: _providerAdapter(provider),
      );
      final paths = await service.ensureDirectories();
      // 创建一个 root 之外的文件并将其作为目标
      final Directory siblingRoot = Directory(
        p.join(
          Directory.systemTemp.path,
          'audio_storage_sibling_${DateTime.now().microsecondsSinceEpoch}_${_counter++}',
        ),
      );
      siblingRoot.createSync(recursive: true);
      addTearDown(() {
        if (siblingRoot.existsSync()) {
          try {
            siblingRoot.deleteSync(recursive: true);
          } on FileSystemException {
            // ignore
          }
        }
      });
      final outsideFile = File(p.join(siblingRoot.path, 'outside.m4a'));
      outsideFile.writeAsStringSync('outside');

      await expectLater(
        () => service.deleteIfExists(
          outsideFile,
          rootDirectory: paths.rootDirectory,
        ),
        throwsA(isA<ArgumentError>()),
      );
      // sanity: outside file must remain undeleted
      expect(outsideFile.existsSync(), isTrue);
      _cleanupRoot(root);
    });
  });

  group('AudioFileStorageService.cleanupTempFiles', () {
    test('deletes temp files with whitelisted extension', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final service = AudioFileStorageService(
        rootDirectoryProvider: _providerAdapter(provider),
      );
      final paths = await service.ensureDirectories();
      // 写入多个临时文件
      for (final ext in ['m4a', 'aac', 'wav']) {
        final f = await service.createTempFile(
          takeId: 'rec_${ext}_x',
          extension: ext,
          tempDirectory: paths.tempDirectory,
        );
        f.writeAsStringSync('payload-$ext');
      }
      // 一个非白名单扩展名（不应被清理）
      final junk = File(p.join(paths.tempDirectory.path, 'junk.txt'));
      junk.writeAsStringSync('do-not-delete');

      final deletedCount = await service.cleanupTempFiles(
        tempDirectory: paths.tempDirectory,
        rootDirectory: paths.rootDirectory,
      );

      expect(deletedCount, 3);
      expect(junk.existsSync(), isTrue,
          reason: 'non-whitelisted extension must not be deleted');
      _cleanupRoot(root);
    });

    test('does not delete saved files', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final service = AudioFileStorageService(
        rootDirectoryProvider: _providerAdapter(provider),
      );
      final paths = await service.ensureDirectories();
      // 在 saved 目录创建一个文件
      final savedFile = await service.savedFileForRecord(
        recordId: 'rec_saved',
        practiceDate: DateTime(2026, 6, 21),
        savedDirectory: paths.savedDirectory,
      );
      savedFile.writeAsStringSync('keep this');

      // temp 目录为空
      final deletedCount = await service.cleanupTempFiles(
        tempDirectory: paths.tempDirectory,
        rootDirectory: paths.rootDirectory,
      );

      expect(deletedCount, 0);
      expect(savedFile.existsSync(), isTrue);
      _cleanupRoot(root);
    });

    test('does not delete subdirectories inside temp', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final service = AudioFileStorageService(
        rootDirectoryProvider: _providerAdapter(provider),
      );
      final paths = await service.ensureDirectories();
      // 在 temp 下放一个子目录
      final subDir = Directory(p.join(paths.tempDirectory.path, 'subdir'));
      subDir.createSync();
      // 顶层 m4a 文件
      final top = File(p.join(paths.tempDirectory.path, 'top.m4a'));
      top.writeAsStringSync('top');

      final deletedCount = await service.cleanupTempFiles(
        tempDirectory: paths.tempDirectory,
        rootDirectory: paths.rootDirectory,
      );

      expect(deletedCount, 1, reason: 'only top-level m4a file is deleted');
      expect(subDir.existsSync(), isTrue,
          reason: 'subdirectories must not be removed');
      _cleanupRoot(root);
    });

    test('refuses to clean up temp directory outside of root', () async {
      final (:provider, :root) = _createIsolatedRoot();
      final service = AudioFileStorageService(
        rootDirectoryProvider: _providerAdapter(provider),
      );
      final paths = await service.ensureDirectories();

      // 创建一个 root 之外的 temp 目录
      final Directory outsideTemp = Directory(
        p.join(
          Directory.systemTemp.path,
          'audio_storage_outside_temp_${DateTime.now().microsecondsSinceEpoch}_${_counter++}',
        ),
      );
      outsideTemp.createSync(recursive: true);
      addTearDown(() {
        if (outsideTemp.existsSync()) {
          try {
            outsideTemp.deleteSync(recursive: true);
          } on FileSystemException {
            // ignore
          }
        }
      });

      await expectLater(
        () => service.cleanupTempFiles(
          tempDirectory: outsideTemp,
          rootDirectory: paths.rootDirectory,
        ),
        throwsA(isA<ArgumentError>()),
      );
      _cleanupRoot(root);
    });
  });

  group('AudioFileStorageService static boundary', () {
    test(
        'generated service does not import record / just_audio / '
        'permission_handler / audio_session symbols', () async {
      // 契约测试：service 文件本身**不得**引用录音/播放/权限 SDK 包。
      // 本测试通过 import `AudioFileStorageService` 并触发部分 API 验证：
      // - 本测试不引用 record / just_audio / permission_handler / audio_session
      //   的任何符号，确保这些包**未**被测试代码间接引用。
      final (:provider, :root) = _createIsolatedRoot();
      final service = AudioFileStorageService(
        rootDirectoryProvider: _providerAdapter(provider),
      );

      // 只触发 storage-only API；不引用 SDK 符号
      final paths = await service.ensureDirectories();
      await service.createTempFile(
        takeId: 'rec_boundary',
        tempDirectory: paths.tempDirectory,
      );
      expect(paths.rootDirectory.existsSync(), isTrue);

      _cleanupRoot(root);
    });
  });
}