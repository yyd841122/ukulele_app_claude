// Fake [MicrophonePermissionGateway] for unit tests (T031).
//
// Mirrors the `_FakeMicrophonePermissionGateway` pattern from
// `microphone_permission_service_test.dart` and the
// `FakeAudioRecorderGateway` / `FakeAudioPlaybackGateway` pattern
// from T029 / T030: pure Dart, no mocktail / mockito, no platform
// channel.
//
// Used by the recording controller test to drive every
// [MicrophonePermissionStatus] branch without ever triggering a
// real system permission dialog.

import 'package:ukulele_app/shared/services/microphone_permission_gateway.dart';
import 'package:ukulele_app/shared/services/microphone_permission_status.dart';

/// Fake gateway for unit tests.
///
/// All methods are async; `next*` pre-seed values control returned
/// values / thrown exceptions. Call counts / argument records let
/// tests assert "the controller called the gateway exactly once with
/// X" and "the controller did NOT call request() after a denied
/// status".
class FakeMicrophonePermissionGateway implements MicrophonePermissionGateway {
  FakeMicrophonePermissionGateway({
    this.nextCheckStatus = MicrophonePermissionStatus.denied,
    this.nextRequestStatus = MicrophonePermissionStatus.granted,
    this.nextOpenSettingsResult = true,
  });

  /// Pre-seeded value returned by [checkStatus].
  MicrophonePermissionStatus nextCheckStatus;

  /// Pre-seeded value returned by [requestPermission].
  MicrophonePermissionStatus nextRequestStatus;

  /// Pre-seeded value returned by [openSettings].
  bool nextOpenSettingsResult;

  /// Pre-seeded exception to throw from [checkStatus]. When set,
  /// takes precedence over [nextCheckStatus].
  Object? nextCheckException;

  /// Pre-seeded exception to throw from [requestPermission]. When
  /// set, takes precedence over [nextRequestStatus].
  Object? nextRequestException;

  /// Pre-seeded exception to throw from [openSettings]. When set,
  /// takes precedence over [nextOpenSettingsResult].
  Object? nextOpenSettingsException;

  int checkStatusCallCount = 0;
  int requestPermissionCallCount = 0;
  int openSettingsCallCount = 0;

  @override
  Future<MicrophonePermissionStatus> checkStatus() async {
    checkStatusCallCount += 1;
    if (nextCheckException != null) {
      throw nextCheckException!;
    }
    return nextCheckStatus;
  }

  @override
  Future<MicrophonePermissionStatus> requestPermission() async {
    requestPermissionCallCount += 1;
    if (nextRequestException != null) {
      throw nextRequestException!;
    }
    return nextRequestStatus;
  }

  @override
  Future<bool> openSettings() async {
    openSettingsCallCount += 1;
    if (nextOpenSettingsException != null) {
      throw nextOpenSettingsException!;
    }
    return nextOpenSettingsResult;
  }
}
