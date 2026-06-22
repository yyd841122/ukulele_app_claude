// Microphone permission service provider (T031).
//
// Provides the single Riverpod provider for [MicrophonePermissionService].
// The default implementation wires:
// - `PermissionHandlerMicrophonePermissionGateway` (production
//   `permission_handler ^12.0.3` adapter, T027 引入);
// - 由 Provider 构造时**不**触发任何 platform channel / 系统弹窗:
//   `MicrophonePermissionService` 仅持有 gateway 引用，真实权限调用
//   全部延迟到 Controller 在用户点击"开始真实录音"时显式触发。
//
// Provider 边界：
// - 构造时**不**访问麦克风 / 录音 / 播放任何 SDK；
// - 构造时**不**调用 `checkStatus` / `requestPermission` /
//   `openSettings`（避免隐式权限请求，与 T025 §8.2 / T027 权限基础层
//   契约一致）；
// - 构造时**不**依赖 Riverpod codegen（沿用项目约定）。
//
// Tests override this provider with a `MicrophonePermissionService`
// wrapping a fake gateway (`FakeMicrophonePermissionGateway`) so the
// controller can drive every `MicrophonePermissionStatus` branch
// without hitting the real permission_handler platform channel.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ukulele_app/shared/services/microphone_permission_gateway.dart';
import 'package:ukulele_app/shared/services/microphone_permission_service.dart';
import 'package:ukulele_app/shared/services/permission_handler_microphone_permission_gateway.dart';

/// Provider for the application-wide [MicrophonePermissionService].
///
/// 默认构造生产实现（`PermissionHandlerMicrophonePermissionGateway`）。
/// Tests typically override this provider with a fake gateway so the
/// controller never triggers a real system permission dialog.
final Provider<MicrophonePermissionService>
    microphonePermissionServiceProvider =
    Provider<MicrophonePermissionService>((Ref ref) {
  const MicrophonePermissionGateway gateway =
      PermissionHandlerMicrophonePermissionGateway();
  return MicrophonePermissionService(gateway);
});
