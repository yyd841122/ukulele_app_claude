// Fake [AudioRecorderGateway] for unit tests (T029).
//
// Strategy:
// - Mirrors the `_FakeMicrophonePermissionGateway` pattern from
//   `microphone_permission_service_test.dart`: pure Dart, no
//   mocktail / mockito, no platform channel.
// - Records every call (start / stop / cancel / dispose) with
//   its arguments and return value pre-seed.
// - Supports fault injection: a test can pre-seed
//   `nextStartException` / `nextStopException` / `nextCancelException`
//   to drive the service through every error branch.
// - Records the most recent `start` arguments
//   (`lastStartConfig` / `lastStartPath`) so tests can assert the
//   service passed the right `RecordConfig` and temp path.
// - Supports the canonical "stop returns null" and "stop returns
//   wrong path" cases via `nextStopResult`.

import 'package:record/record.dart';

import 'package:ukulele_app/shared/services/audio_recorder_gateway.dart';

/// Fake gateway for unit tests.
///
/// All methods are async; `next*` pre-seed values control returned
/// values / thrown exceptions. Call counts / argument records let
/// tests assert "the service called gateway exactly once with X".
class FakeAudioRecorderGateway implements AudioRecorderGateway {
  FakeAudioRecorderGateway();

  // ---- pre-seed values (controls) ----

  /// Value returned by [stop]. Use `null` to simulate "stop returns
  /// null" (Service must throw `RecorderStopFailedException`).
  String? nextStopResult;

  /// If set, [start] throws this exception instead of completing.
  Object? nextStartException;

  /// If set, [stop] throws this exception instead of returning.
  Object? nextStopException;

  /// If set, [cancel] throws this exception instead of completing.
  Object? nextCancelException;

  /// If set, [dispose] throws this exception instead of completing.
  Object? nextDisposeException;

  // ---- recorded calls (assertions) ----

  int startCallCount = 0;
  int stopCallCount = 0;
  int cancelCallCount = 0;
  int disposeCallCount = 0;

  RecordConfig? lastStartConfig;
  String? lastStartPath;

  // ---- gateway contract ----

  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    startCallCount += 1;
    lastStartConfig = config;
    lastStartPath = path;
    if (nextStartException != null) {
      throw nextStartException!;
    }
  }

  @override
  Future<String?> stop() async {
    stopCallCount += 1;
    if (nextStopException != null) {
      throw nextStopException!;
    }
    return nextStopResult;
  }

  @override
  Future<void> cancel() async {
    cancelCallCount += 1;
    if (nextCancelException != null) {
      throw nextCancelException!;
    }
  }

  @override
  Future<void> dispose() async {
    disposeCallCount += 1;
    if (nextDisposeException != null) {
      throw nextDisposeException!;
    }
  }
}
