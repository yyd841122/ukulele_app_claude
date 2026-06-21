/// 麦克风权限网关抽象（MicrophonePermissionGateway）
///
/// T027 真实音频 MVP 权限基础层：
/// 通过轻量 wrapper / adapter 把 `permission_handler` 的
/// `PermissionStatus` 枚举（仅在 platform channel 可用）与
/// `MicrophonePermissionStatus`（应用侧统一状态）解耦，
/// 使得映射逻辑可在普通单元测试中以 fake gateway 形式验证。
///
/// 设计原则（与 `REAL_AUDIO_MVP_SDD.md` §7.1 / `REAL_AUDIO_DEPENDENCY_SPIKE.md` §3.5 一致）：
/// 1. Gateway 不调用 `record` / `just_audio` / 任何音频 API；
/// 2. Gateway 不在构造时自动申请权限；
/// 3. Gateway 不持有 UI 依赖；
/// 4. Gateway 抛出的异常仅来自 permission_handler 平台通道，
///    Service 层负责异常转换。
library;

import 'microphone_permission_status.dart';

abstract class MicrophonePermissionGateway {
  /// 查询当前麦克风权限状态。**不**触发任何系统弹窗。
  Future<MicrophonePermissionStatus> checkStatus();

  /// 申请麦克风权限（系统弹窗由 Android 系统弹出，不可定制）。
  /// 申请结束后返回用户最新授权状态。
  Future<MicrophonePermissionStatus> requestPermission();

  /// 引导用户前往系统设置页面（用于永久拒绝场景）。
  /// 返回值：成功打开设置页返回 `true`，否则 `false`。
  Future<bool> openSettings();
}
