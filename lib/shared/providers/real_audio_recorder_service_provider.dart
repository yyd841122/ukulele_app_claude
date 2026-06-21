// Shared real audio recorder service provider (T029).
//
// Provides the single Riverpod provider for [RealAudioRecorderService].
// The default implementation wires:
// - `PackageAudioRecorderGateway` (production `record ^7.1.0` adapter);
// - `AudioFileStorageService` (T028 storage service with default
//   `path_provider` root provider).
//
// Provider 边界：
// - 构造时**不**访问麦克风；
// - 构造时**不**触发 `MicrophonePermissionGateway.hasPermission()`
//   / `requestPermission()`（避免隐式权限请求，与 T025 §8.2 一致）；
// - 构造时**不**创建 temp 文件 / 调用 `ensureDirectories`；
// - 构造时**不**触发 `record` 包的 platform channel；
//
// Recording 任务必须显式通过 Riverpod scope override 或测试 Provider
// 注入 fake gateway / fake storage 才能测试；本 Provider 不会被
// `RecordingPracticeController` 接入（本任务**不**接 UI）。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ukulele_app/shared/providers/audio_file_storage_service_provider.dart';
import 'package:ukulele_app/shared/services/audio_file_storage_service.dart';
import 'package:ukulele_app/shared/services/audio_recorder_gateway.dart';
import 'package:ukulele_app/shared/services/real_audio_recorder_service.dart';

/// Provider for the application-wide [RealAudioRecorderService].
///
/// 默认构造生产实现（`PackageAudioRecorderGateway` + `AudioFileStorageService`）。
/// Tests typically override this provider with a fake gateway + a
/// temp-rooted `AudioFileStorageService` so the service talks to
/// in-memory fakes only.
final Provider<RealAudioRecorderService> realAudioRecorderServiceProvider =
    Provider<RealAudioRecorderService>((Ref ref) {
  final AudioFileStorageService storage = ref.watch(
    audioFileStorageServiceProvider,
  );
  final AudioRecorderGateway gateway = PackageAudioRecorderGateway();
  return RealAudioRecorderService(gateway: gateway, storage: storage);
});
