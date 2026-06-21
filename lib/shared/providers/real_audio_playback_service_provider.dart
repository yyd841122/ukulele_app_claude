// Shared real audio playback service provider (T030).
//
// Provides the single Riverpod provider for [RealAudioPlaybackService].
// The default implementation wires:
// - `PackageJustAudioPlaybackGateway` (production `just_audio ^0.10.5` adapter);
// - `AudioFileStorageService` (T028 storage service with default
//   `path_provider` root provider).
//
// Provider 边界：
// - 构造时**不**访问麦克风 / 触发任何权限请求；
// - 构造时**不**调用 `AudioFileStorageService.ensureDirectories`；
// - 构造时**不**创建 `AudioPlayer` 之外的 platform channel / **不**加载
//   任何音频文件；
// - 构造时**不**触发 `just_audio` 的 `setFilePath` / `play` / `dispose`。
//
// 播放任务必须显式通过 Riverpod scope override 或测试 Provider
// 注入 fake gateway / fake storage 才能测试；本 Provider 不会被
// `RecordingPracticeController` 接入（本任务**不**接 UI）。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ukulele_app/shared/providers/audio_file_storage_service_provider.dart';
import 'package:ukulele_app/shared/services/audio_file_storage_service.dart';
import 'package:ukulele_app/shared/services/audio_playback_gateway.dart';
import 'package:ukulele_app/shared/services/real_audio_playback_service.dart';

/// Provider for the application-wide [RealAudioPlaybackService].
///
/// 默认构造生产实现（`PackageJustAudioPlaybackGateway` + `AudioFileStorageService`）。
/// Tests typically override this provider with a fake gateway + a
/// temp-rooted `AudioFileStorageService` so the service talks to
/// in-memory fakes only.
final Provider<RealAudioPlaybackService> realAudioPlaybackServiceProvider =
    Provider<RealAudioPlaybackService>((Ref ref) {
  final AudioFileStorageService storage = ref.watch(
    audioFileStorageServiceProvider,
  );
  final AudioPlaybackGateway gateway = PackageJustAudioPlaybackGateway();
  return RealAudioPlaybackService(
    gateway: gateway,
    storage: storage,
  );
});
