import 'package:permission_handler/permission_handler.dart';

import 'microphone_permission_gateway.dart';
import 'microphone_permission_status.dart';

/// 基于 `permission_handler` 的麦克风权限 Gateway 实现
/// （PermissionHandlerMicrophonePermissionGateway）。
///
/// T027 真实音频 MVP 权限基础层：
/// - 唯一接触 `permission_handler` platform channel 的实现；
/// - 把 `PermissionStatus` 枚举映射到应用侧 [MicrophonePermissionStatus]；
/// - 覆盖 `permission_handler` 12.x 全部已知枚举（含 iOS 平台 `limited`
///   与 `restricted`），未识别值兜底为 [MicrophonePermissionStatus.unknown]；
/// - **不**做缓存（每次调用都从 platform channel 拉取最新状态）；
/// - **不**在 `checkStatus` 时调用 `request`（与 `REAL_AUDIO_MVP_TDD.md`
///   §2.1 TC-P02 一致，避免误触发系统弹窗）。
class PermissionHandlerMicrophonePermissionGateway
    implements MicrophonePermissionGateway {
  const PermissionHandlerMicrophonePermissionGateway();

  @override
  Future<MicrophonePermissionStatus> checkStatus() async {
    final status = await Permission.microphone.status;
    return _mapStatus(status);
  }

  @override
  Future<MicrophonePermissionStatus> requestPermission() async {
    final status = await Permission.microphone.request();
    return _mapStatus(status);
  }

  @override
  Future<bool> openSettings() {
    return openAppSettings();
  }

  /// `PermissionStatus` → `MicrophonePermissionStatus` 映射。
  ///
  /// 显式覆盖 permission_handler 12.x 全部已知枚举值；
  /// 未来 permission_handler 新增枚举时，未识别值兜底为
  /// [MicrophonePermissionStatus.unknown]，避免 Service 层收到 `null`
  /// 或抛异常。
  static MicrophonePermissionStatus _mapStatus(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
      case PermissionStatus.provisional: // iOS 临时授权：视作 granted
        return MicrophonePermissionStatus.granted;
      case PermissionStatus.denied:
        return MicrophonePermissionStatus.denied;
      case PermissionStatus.permanentlyDenied:
        return MicrophonePermissionStatus.permanentlyDenied;
      case PermissionStatus.restricted:
        return MicrophonePermissionStatus.restricted;
      case PermissionStatus.limited:
        return MicrophonePermissionStatus.limited;
    }
    // 兜底：未来 permission_handler 新增未知枚举值时按 unknown 处理。
    // 当前 12.x 版本 switch 已穷尽，Dart 3.7+ 会报告 dead code；保留
    // 是为了 forward-compat：未来 permission_handler 升级时这一行立即生效。
    // ignore: dead_code
    return MicrophonePermissionStatus.unknown;
  }
}
