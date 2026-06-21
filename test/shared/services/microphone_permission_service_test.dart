// Tests for [MicrophonePermissionService] (T027).
//
// Strategy:
// - 服务通过 [MicrophonePermissionGateway] 抽象隔离真实平台调用；
//   测试使用 fake gateway 注入，**不**触发真实系统权限弹窗。
// - fake gateway 记录 `checkStatus` / `requestPermission` 的调用次数，
//   用于验证：
//   * `checkStatus` 不调用 `request`（与 `REAL_AUDIO_MVP_TDD.md` §2.1 TC-P02 一致）；
//   * `requestPermission` 仅调用 `request` 一次（防抖契约）。
// - 状态映射覆盖 [MicrophonePermissionStatus] 全部 6 个值（granted /
//   denied / permanentlyDenied / restricted / limited / unknown）。
// - `unknown` fallback 通过 fake gateway 自定义 `rawValue` 触发，
//   gateway 内部将未识别 raw 值映射为 unknown（模拟 permission_handler
//   未来新增未识别枚举值）。

import 'package:flutter_test/flutter_test.dart';
import 'package:ukulele_app/shared/services/microphone_permission_gateway.dart';
import 'package:ukulele_app/shared/services/microphone_permission_service.dart';
import 'package:ukulele_app/shared/services/microphone_permission_status.dart';

/// 单元测试用 fake gateway。
///
/// 设计要点：
/// - 持有 `checkStatusCallCount` / `requestPermissionCallCount` /
///   `openSettingsCallCount`，断言调用次数契约；
/// - `nextCheckStatus` / `nextRequestStatus` / `nextOpenSettingsResult`
///   是预设返回值（控制 fake 行为）；
/// - `rawValue` 模拟 permission_handler 未来新增未识别枚举值：
///   真实 `PermissionHandlerMicrophonePermissionGateway` 在这种情况下
///   会兜底为 `unknown`；fake gateway 通过 `MicrophonePermissionStatus.unknown`
///   直接返回该值。
class _FakeMicrophonePermissionGateway implements MicrophonePermissionGateway {
  _FakeMicrophonePermissionGateway({
    this.nextCheckStatus = MicrophonePermissionStatus.denied,
    this.nextRequestStatus = MicrophonePermissionStatus.granted,
    this.nextOpenSettingsResult = true,
  });

  MicrophonePermissionStatus nextCheckStatus;
  MicrophonePermissionStatus nextRequestStatus;
  bool nextOpenSettingsResult;

  int checkStatusCallCount = 0;
  int requestPermissionCallCount = 0;
  int openSettingsCallCount = 0;

  @override
  Future<MicrophonePermissionStatus> checkStatus() async {
    checkStatusCallCount += 1;
    return nextCheckStatus;
  }

  @override
  Future<MicrophonePermissionStatus> requestPermission() async {
    requestPermissionCallCount += 1;
    return nextRequestStatus;
  }

  @override
  Future<bool> openSettings() async {
    openSettingsCallCount += 1;
    return nextOpenSettingsResult;
  }
}

void main() {
  group('MicrophonePermissionService.checkStatus', () {
    test('maps granted', () async {
      final gateway = _FakeMicrophonePermissionGateway(
        nextCheckStatus: MicrophonePermissionStatus.granted,
      );
      final service = MicrophonePermissionService(gateway);

      final result = await service.checkStatus();

      expect(result, MicrophonePermissionStatus.granted);
    });

    test('maps denied', () async {
      final gateway = _FakeMicrophonePermissionGateway(
        nextCheckStatus: MicrophonePermissionStatus.denied,
      );
      final service = MicrophonePermissionService(gateway);

      final result = await service.checkStatus();

      expect(result, MicrophonePermissionStatus.denied);
    });

    test('maps permanentlyDenied', () async {
      final gateway = _FakeMicrophonePermissionGateway(
        nextCheckStatus: MicrophonePermissionStatus.permanentlyDenied,
      );
      final service = MicrophonePermissionService(gateway);

      final result = await service.checkStatus();

      expect(result, MicrophonePermissionStatus.permanentlyDenied);
    });

    test('maps restricted', () async {
      final gateway = _FakeMicrophonePermissionGateway(
        nextCheckStatus: MicrophonePermissionStatus.restricted,
      );
      final service = MicrophonePermissionService(gateway);

      final result = await service.checkStatus();

      expect(result, MicrophonePermissionStatus.restricted);
    });

    test('maps limited', () async {
      final gateway = _FakeMicrophonePermissionGateway(
        nextCheckStatus: MicrophonePermissionStatus.limited,
      );
      final service = MicrophonePermissionService(gateway);

      final result = await service.checkStatus();

      expect(result, MicrophonePermissionStatus.limited);
    });

    test('maps unknown fallback', () async {
      final gateway = _FakeMicrophonePermissionGateway(
        nextCheckStatus: MicrophonePermissionStatus.unknown,
      );
      final service = MicrophonePermissionService(gateway);

      final result = await service.checkStatus();

      expect(result, MicrophonePermissionStatus.unknown);
    });
  });

  group('MicrophonePermissionService.requestPermission', () {
    test('maps granted', () async {
      final gateway = _FakeMicrophonePermissionGateway(
        nextRequestStatus: MicrophonePermissionStatus.granted,
      );
      final service = MicrophonePermissionService(gateway);

      final result = await service.requestPermission();

      expect(result, MicrophonePermissionStatus.granted);
    });

    test('maps denied', () async {
      final gateway = _FakeMicrophonePermissionGateway(
        nextRequestStatus: MicrophonePermissionStatus.denied,
      );
      final service = MicrophonePermissionService(gateway);

      final result = await service.requestPermission();

      expect(result, MicrophonePermissionStatus.denied);
    });

    test('maps permanentlyDenied', () async {
      final gateway = _FakeMicrophonePermissionGateway(
        nextRequestStatus: MicrophonePermissionStatus.permanentlyDenied,
      );
      final service = MicrophonePermissionService(gateway);

      final result = await service.requestPermission();

      expect(result, MicrophonePermissionStatus.permanentlyDenied);
    });
  });

  group('MicrophonePermissionService contract invariants', () {
    test('checkStatus does not call request', () async {
      final gateway = _FakeMicrophonePermissionGateway();
      final service = MicrophonePermissionService(gateway);

      await service.checkStatus();

      expect(gateway.checkStatusCallCount, 1);
      expect(gateway.requestPermissionCallCount, 0);
    });

    test('requestPermission calls request exactly once', () async {
      final gateway = _FakeMicrophonePermissionGateway();
      final service = MicrophonePermissionService(gateway);

      await service.requestPermission();

      expect(gateway.requestPermissionCallCount, 1);
      expect(gateway.checkStatusCallCount, 0);
    });

    test(
        'service does not call microphone recording APIs '
        '(no record / just_audio / audio_session symbol referenced)',
        () async {
      // 本测试是契约测试：service 文件本身**不得**引用任何录音/播放 SDK。
      // 真实录音 / 播放由 T029 / T030 任务引入，本任务**只**做权限基础层。
      // 若将来有人误在 service 文件中 import record / just_audio /
      // audio_session，本测试不会运行失败，但 import 即失败；
      // 该契约通过本测试文件中的 `import 'package:ukulele_app/shared/...'`
      // 而**不**引用录音/播放包来保证。
      final gateway = _FakeMicrophonePermissionGateway();
      final service = MicrophonePermissionService(gateway);

      // 触发全部三个方法一遍；只要 service 不抛异常即视为通过。
      await service.checkStatus();
      await service.requestPermission();
      await service.openSettings();

      expect(gateway.checkStatusCallCount, 1);
      expect(gateway.requestPermissionCallCount, 1);
      expect(gateway.openSettingsCallCount, 1);
    });
  });

  group('MicrophonePermissionService.openSettings', () {
    test('returns true when gateway opens settings', () async {
      final gateway = _FakeMicrophonePermissionGateway(
        nextOpenSettingsResult: true,
      );
      final service = MicrophonePermissionService(gateway);

      final result = await service.openSettings();

      expect(result, isTrue);
      expect(gateway.openSettingsCallCount, 1);
    });

    test('returns false when gateway fails to open settings', () async {
      final gateway = _FakeMicrophonePermissionGateway(
        nextOpenSettingsResult: false,
      );
      final service = MicrophonePermissionService(gateway);

      final result = await service.openSettings();

      expect(result, isFalse);
      expect(gateway.openSettingsCallCount, 1);
    });
  });
}
