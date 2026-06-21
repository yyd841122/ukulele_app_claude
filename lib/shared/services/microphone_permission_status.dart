/// 麦克风权限状态模型（MicrophonePermissionStatus）
///
/// T027 真实音频 MVP 权限基础层：定义应用侧统一的权限状态枚举。
///
/// 设计原则：
/// 1. 跨平台语义保留：保留 `limited` / `restricted` 两个 iOS 平台常见状态，
///    即便当前 MVP 范围仅在 Android 真机验收（`REAL_AUDIO_MVP_SDD.md` §3.2），
///    未来扩展到 iOS 阶段（`REAL_AUDIO_MVP_SDD.md` §3.5）时无需破坏既有契约。
/// 2. 未知状态兜底：permission_handler 可能在旧版本 / 罕见 OEM ROM 上返回
///    未识别枚举值；`unknown` 用作 fallback，避免 Controller 收到 null。
/// 3. UI 决策映射（与 `REAL_AUDIO_MVP_SDD.md` §2.2 / §3.2 一致）：
///    - `granted` → 可直接进入录音；
///    - `denied` → App 内可重试；
///    - `permanentlyDenied` → 引导用户前往系统设置；
///    - `restricted` → 系统级限制（家长控制 / MDM），与 permanentlyDenied
///      类似但文案不同；
///    - `limited` → iOS 平台专用，App 内可继续使用但功能受限；
///    - `unknown` → 默认按 denied 处理，但保留原始信息以便诊断。
enum MicrophonePermissionStatus {
  /// 用户已授予麦克风权限。
  granted,

  /// 用户一次性拒绝麦克风权限（App 内可重试）。
  denied,

  /// 用户永久拒绝（勾选"不再询问"），需引导系统设置。
  permanentlyDenied,

  /// 系统级限制（例如家长控制、MDM）。
  restricted,

  /// 部分授予（iOS 专用；当前 Android MVP 不会返回该值）。
  limited,

  /// 未知状态（permission_handler 返回未识别枚举值时的兜底）。
  unknown,
}
