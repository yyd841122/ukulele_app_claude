/// 麦克风权限服务（MicrophonePermissionService）
///
/// T027 真实音频 MVP 权限基础层：
/// - 封装 `permission_handler` 的 `Permission.microphone`；
/// - 对外暴露 `checkStatus` / `requestPermission` / `openSettings` 三个只读方法；
/// - 通过 [MicrophonePermissionGateway] 抽象隔离真实平台调用，
///   单元测试以 fake gateway 注入即可覆盖全部状态映射分支；
/// - **不**在构造时自动申请权限；
/// - **不**在 `checkStatus` 时自动申请权限；
/// - **不**调用真实麦克风、**不**依赖 UI、**不**依赖 Riverpod codegen。
///
/// 与 `REAL_AUDIO_MVP_SDD.md` §3.1 / §3.2 / §7.1 一致：
/// - `checkStatus` 与 `requestPermission` 显式分离，避免误触发系统弹窗；
/// - 状态映射由 Gateway 完成；本 Service 仅做依赖注入与契约封装。
library;

import 'microphone_permission_gateway.dart';
import 'microphone_permission_status.dart';

class MicrophonePermissionService {
  /// 构造时注入 [MicrophonePermissionGateway] 抽象实现。
  /// 生产环境由 `PermissionHandlerMicrophonePermissionGateway` 提供；
  /// 测试环境可注入 fake gateway。
  const MicrophonePermissionService(this._gateway);

  final MicrophonePermissionGateway _gateway;

  /// 查询当前麦克风权限状态。**不**触发任何系统弹窗。
  ///
  /// 调用方应使用返回值判断：
  /// - [MicrophonePermissionStatus.granted] → 可进入录音；
  /// - [MicrophonePermissionStatus.denied] → App 内可重试；
  /// - [MicrophonePermissionStatus.permanentlyDenied] → 引导系统设置；
  /// - 其他状态按各自语义处理。
  Future<MicrophonePermissionStatus> checkStatus() {
    return _gateway.checkStatus();
  }

  /// 申请麦克风权限（系统弹窗由 Android 系统弹出，不可定制）。
  ///
  /// 申请结束后返回用户最新授权状态。
  /// 调用次数由 Controller 控制；本 Service 不做去重。
  Future<MicrophonePermissionStatus> requestPermission() {
    return _gateway.requestPermission();
  }

  /// 引导用户前往系统设置页面（用于永久拒绝场景）。
  /// 返回值：成功打开设置页返回 `true`，否则 `false`。
  Future<bool> openSettings() {
    return _gateway.openSettings();
  }
}
