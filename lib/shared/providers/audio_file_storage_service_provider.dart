// Shared audio file storage service provider.
//
// T029 introduced this provider so that
// `realAudioRecorderServiceProvider` can pull a default
// `AudioFileStorageService` through the Riverpod scope.
//
// Notes:
// - The provider is intentionally minimal: it just wires the
//   default production `AudioFileStorageService` with
//   `defaultAudioRootDirectoryProvider`. No Riverpod codegen
//   is used, matching the project convention
//   (`install_date_service_provider.dart` /
//   `app_clock_provider.dart`).
// - Tests override the provider via
//   `ProviderScope(overrides: [audioFileStorageServiceProvider
//   .overrideWithValue(...)])` to inject a temp-rooted
//   `AudioFileStorageService` for isolation.
// - This file does NOT modify T028's
//   `lib/shared/services/audio_file_storage_service.dart`; it
//   only adds a new provider surface that the recorder service
//   can depend on.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ukulele_app/shared/services/audio_file_storage_service.dart';

/// Provider for the application-wide [AudioFileStorageService].
///
/// 默认使用 `defaultAudioRootDirectoryProvider()`（基于
/// `path_provider.getApplicationDocumentsDirectory()/audio`）。
/// Tests override this provider with a fake / temp-rooted
/// implementation.
final Provider<AudioFileStorageService> audioFileStorageServiceProvider =
    Provider<AudioFileStorageService>((Ref ref) {
  return AudioFileStorageService(
    rootDirectoryProvider: defaultAudioRootDirectoryProvider,
  );
});
