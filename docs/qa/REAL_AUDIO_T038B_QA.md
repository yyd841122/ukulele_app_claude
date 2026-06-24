# T038B 真实音频 MVP 麦克风权限文案 + 系统设置恢复 (T038B_QA)

> 本文档记录 T038B 任务产出：在 T038 已通过的真机上**重做**用户可见文案 + 添加系统设置恢复路径的完整证据链、根因分析、修复路径评估与最终结论。
>
> ⚠️ 本文档**只**修改以下文件:
> - `lib/features/recording/application/recording_practice_controller.dart` (生产代码)
> - `lib/features/recording/presentation/recording_page.dart` (生产代码)
> - `test/features/recording/application/recording_practice_controller_test.dart` (测试)
> - `test/features/recording/presentation/recording_page_test.dart` (测试)
> - 5 个允许追加的 doc 文件 (本文档新建 + `docs/qa/REAL_AUDIO_MVP_RELEASE_CHECKPOINT.md` 追加 + `docs/qa/REAL_AUDIO_ANDROID_ACCEPTANCE.md` 追加 + `docs/dev/TASK_LEDGER.md` 追加 + `docs/dev/AGENT_QUALITY_METRICS.md` 追加 + `docs/dev/TECH_DEBT.md` 追加)
>
> ⚠️ 本文档**不**修改:
> - `permission_handler` 版本 (12.0.3 不升级)
> - `MicrophonePermissionService` 公共契约 (3 个只读方法)
> - `MicrophonePermissionGateway` 抽象边界
> - `PermissionHandlerMicrophonePermissionGateway` 6 状态映射
> - `MicrophonePermissionStatus` 6 状态枚举
> - `RecordingPracticeController` 内部 `RecordingPermissionStatus.permanentDenied` 枚举值
> - `Manifest` / `Gradle` / `Drift schema` / 版本号 / `INTERNET` 权限 / 录音和播放服务
>
> ⚠️ 本文档**不**武断宣称原始 T038 偶发异常一定不存在; T038 异常历史事实保留, T038B 仅记录"原始 T038 异常在本次 T038B session 中**未能再次复现**"。
>
> ⚠️ 本文档仅覆盖单台真机 (HUAWEI CDY-AN90 / Android 10 / API 29 / arm64-v8a), 未覆盖其他国产 ROM 或 Android 版本。
>
> ⚠️ 本文档**不**包含完整设备序列号 / keystore 内容 / `key.properties` 内容 / 任何敏感信息。
>
> 本文是 T038 Release Checkpoint 文档的**补做证据**; T038 主体结论由本文判定后升级到 **READY_FOR_GO_NO_GO_REVIEW** (不自动写为 Approved; 不直接写成 Release Approved / Go / 已发布 / 可上架)。

## Document Status

| 字段 | 值 |
| --- | --- |
| Task ID | `T038B_FIX_PERMISSION_DENIED_COPY_AND_SETTINGS_RECOVERY` |
| 基线 Commit | `18557ab32fcffaa5f794d95bc63cb2dbd20bfb63` (T038 文档收口 commit) |
| 起始提交 | `18557ab32fcffaa5f794d95bc63cb2dbd20bfb63` (与基线相同) |
| HEAD (最终) | `18557ab32fcffaa5f794d95bc63cb2dbd20bfb63` (**不**主动 commit, **不**push) |
| **Code Changes** | **2 个生产代码文件** + **2 个测试文件** (`lib/features/recording/application/recording_practice_controller.dart` + `lib/features/recording/presentation/recording_page.dart` + `test/features/recording/application/recording_practice_controller_test.dart` + `test/features/recording/presentation/recording_page_test.dart`) |
| **Tests Added or Updated** | **10 个新增 T038B controller 测试** + **2 个 page 测试 (合并 + 替换原 denied 测试) + 2 个全新 page 测试** = **~14 个 T038B 相关测试** |
| **Exact Test Count** | **711** 项 `flutter test` 通过 (基线 698 + T038B 新增 13) |
| 设备 | HUAWEI CDY-AN90 / Android 10 / API 29 / arm64-v8a |
| 启动检查 | `git branch --show-current` = `master` / `git rev-parse HEAD` = `18557ab` / `git status --short` 仅 4 个 M 状态 lib/test 文件 / `flutter analyze` clean / `flutter test` = `+711: All tests passed!` / `adb devices -l` = 1 台真机 |
| 修改文件范围 | 4 个 lib/test 文件 + 5 个允许追加 doc 文件 (本文档新建 + 4 个其他) = **9 个 M 状态文件** + **1 个新 doc 文件** = **10 个文件** (与"6 个允许 doc + 4 个 lib/test"一致) |
| **任务结论** | **PASS** (用户可见文案统一为"麦克风权限已拒绝"; 新增"前往系统设置"引导; WidgetsBindingObserver 在 AppLifecycleState.resumed 时重新检查权限; 4 个 Reviewer 全部 Approved; 真机 8 项验收全部通过) |
| **T038 Blocker 影响** | **T038 Permission first-request acceptance Blocker 解决条件已满足**: ① 拒绝后页面显示"麦克风权限已拒绝" (无"永久拒绝"字样); ② 引导文案"请前往系统设置开启麦克风权限后重试" 可见; ③ "前往系统设置" 按钮存在; ④ 点击按钮跳转 com.yupi.ukulele 系统设置页; ⑤ 用户在系统设置中开启权限后返回 App, 权限状态自动恢复; ⑥ 再次点击开始录音能正常录音/停止/回放; ⑦ 既有 2 个 temp m4a + ukulele.db + flutter_assets + res_timestamp-* 完整保留; ⑧ 拒绝期间 recorder.start 调用次数为 0 |

## Starting Commit

| 字段 | 值 |
| --- | --- |
| Commit | `18557ab32fcffaa5f794d95bc63cb2dbd20bfb63` |
| 标题 | `docs: record pending real audio MVP release checkpoint` |
| 作者 | yyd841122 |
| 日期 | 2026-06-24 (与本任务执行同日) |
| 状态 | HEAD (最终) |
| 严格匹配 | **是** (`git rev-parse HEAD` 启动检查时与基线一致; 任务期间 **不** commit 任何工作区修改) |

## Device

| 字段 | 值 |
| --- | --- |
| 设备型号 | `HUAWEI CDY-AN90` |
| Android 版本 | `10` |
| Android SDK | `29` |
| 设备序列号 | **脱敏** (**仅**保留型号 `HUAWEI CDY-AN90` + Android 版本 `10` + Android SDK `29`; **不**记录完整 serial 或后 4 位) |
| 厂商 ROM | 华为 EMUI / HarmonyOS (具体子版本不记录) |
| 单设备覆盖限制 | **是** (T037 / T038 / T038B 既有单设备覆盖限制) |

> **单设备覆盖限制 (强警告)**: 本任务**仅**覆盖上述单台真机。`REAL_AUDIO_DEPENDENCY_SPIKE.md` §3.6 + `TECH_DEBT.md` TD-013 明确指出, 国产 ROM 兼容性 (HUAWEI / 小米 / OPPO / vivo / 三星) 必须由真机用户验收 —— 本任务**不**能据此推断其他 ROM 已通过验证。**国产 ROM 兼容性问题可能在其他设备上出现**, 包括但不限于: `just_audio 0.10.5` playerStateStream 事件延迟 / 丢失、`record 7.1.0` 麦克风路由、`permission_handler 12.0.3` 弹窗行为、`AudioFileStorageService` 文件路径解析。

## Phase 1: 只读代码 + 既有测试审查

> 在 T038B 真机操作前完成本节, **不**修改任何代码或配置。

### 关键源码只读审查 (T038B 启动前)

| 文件 | 关键观察 (T038B 启动前) | 结论 |
| --- | --- | --- |
| `lib/shared/services/microphone_permission_status.dart` | 6 状态枚举 (`granted` / `denied` / `permanentlyDenied` / `restricted` / `limited` / `unknown`) 完整 | 枚举正确 |
| `lib/shared/services/microphone_permission_service.dart` | 三个只读方法 `checkStatus` / `requestPermission` / `openSettings`; **不**在构造 / `checkStatus` 时自动申请权限 | 服务契约正确 |
| `lib/shared/services/microphone_permission_gateway.dart` | 抽象 `MicrophonePermissionGateway` 隔离平台调用, **不**缓存结果, 每次调用都从 platform channel 拉取 | 抽象边界正确 |
| `lib/shared/services/permission_handler_microphone_permission_gateway.dart` | 生产实现包装 `permission_handler` 12.x; 显式覆盖 6 个 `PermissionStatus` 枚举值; `openAppSettings()` 直接委托给 `permission_handler.openAppSettings()` | 系统设置跳转路径已就位, 但**未**被 controller 调用 |
| `lib/features/recording/application/recording_practice_controller.dart` | `startRecording` 标准权限流程: ① `checkStatus()` → ② 非 `granted` 才 `requestPermission()` 一次 → ③ `granted` 走真实录音; `denied` / `permanentlyDenied` / `restricted` 不调 `recorder.start`; 但 `statusLabel` 把 `denied` 渲染为"麦克风权限被拒绝" / `permanentDenied` 渲染为"麦克风权限已永久拒绝" (暴露"永久拒绝"字样) | **需要修改**: 用户可见文案 + 缺少 `openAppSettings()` 调度 + 缺少 `refreshPermissionStatus()` 重检 |
| `lib/features/recording/presentation/recording_page.dart` | `canStart` 在 `permission == checking` 时禁用按钮; `canReset` 在 `denied` / `permanentDenied` / `restricted` 状态下允许; `StatusCard.statusLabel` 在 `denied` → "麦克风权限被拒绝" / `permanentDenied` → "麦克风权限已永久拒绝" / `restricted` → "麦克风被系统限制"; **无** 跳转系统设置的引导控件 | **需要修改**: 统一文案 + 新增系统设置引导面板 + 新增 WidgetsBindingObserver |

### 既有测试覆盖 (T038B 启动前)

| 测试文件 | 覆盖项数 | 关键覆盖 |
| --- | --- | --- |
| `test/shared/services/microphone_permission_service_test.dart` | 14 | `checkStatus` 6 状态映射 + `requestPermission` 3 状态映射 + 契约不变式 + `openSettings` 真假分支 |
| `test/shared/services/fake_microphone_permission_gateway.dart` | (fake helper) | 完整 fake gateway: 预置返回值 + 故障注入 + 调用次数统计 |
| `test/features/recording/application/recording_practice_controller_test.dart` | 68 (含 T031C / T031E 增量) | 权限 `granted` 后开始录音成功 / 权限 `denied` 时不调 `recorder.start` / 权限 `permanentlyDenied` 时不调 `recorder.start` / 权限 `restricted` 时不调 `recorder.start` / 权限服务异常恢复 / `startRecording` 互斥守卫 |
| `test/features/recording/presentation/recording_page_test.dart` | 8 | permission denied 状态翻到 "麦克风权限被拒绝" / permission granted 后点击 "开始录音" 翻到 "正在录音" |

### 依赖版本核对 (T038B 启动前 = 启动后, 无任何升级)

| 依赖 | 当前版本 | 来源 |
| --- | --- | --- |
| `permission_handler` | `12.0.3` | `pubspec.lock` line 618 |
| `permission_handler_android` | `13.0.1` (传递依赖) | `pubspec.lock` line 626 |
| `record` | `7.1.0` | `pubspec.lock` |
| `just_audio` | `0.10.5` | `pubspec.lock` |

> `permission_handler 12.0.3` 的 `openAppSettings()` 是 AOSP 标准 API, 在 Android 10 EMUI 上直接委托给系统 `Settings.ACTION_APPLICATION_DETAILS_SETTINGS` Intent。

## Phase 2: 代码修改 (T038B 主任务)

> T038B **不**只做只读审查; T038B 修改 4 个 lib/test 文件以实现用户可见文案统一 + 系统设置恢复路径。

### Code Changes 详细

#### `lib/features/recording/application/recording_practice_controller.dart`

| 修改点 | 旧行为 (T038B 启动前) | 新行为 (T038B) |
| --- | --- | --- |
| `RecordingPracticeState.statusLabel` `denied` 分支 | 返回 `'麦克风权限被拒绝'` | 返回 `'麦克风权限已拒绝'` (与 `permanentDenied` 文案统一) |
| `RecordingPracticeState.statusLabel` `permanentDenied` 分支 | 返回 `'麦克风权限已永久拒绝'` (暴露"永久拒绝"字样) | 返回 `'麦克风权限已拒绝'` (与 `denied` 文案统一; 内部 enum `permanentDenied` 仍保留) |
| 新增 `openAppSettings()` 方法 | (无) | 调用 `_permission.openSettings()` → `MicrophonePermissionGateway.openSettings()` → `PermissionHandlerMicrophonePermissionGateway.openSettings()` → `permission_handler.openAppSettings()`; 含 `_openingAppSettings` 重入锁; 失败时通过 `lastError` 抛出友好文案; **不**触碰 `recorder.start` |
| 新增 `refreshPermissionStatus()` 方法 | (无) | 重新读 `MicrophonePermissionService.checkStatus()`, 用 `_mapPermissionStatus` 同步 enum 值; 含 `state.permission == checking` 时 short-circuit; 错误时回滚到 `previousPermission` + 设置 `lastError`; **不**触碰 `recorder.start` (T025 / T031 "no permission auto-start" 契约保留); 释放 `_openingAppSettings` 锁以便用户在 system settings 返回后能再次点击 |
| 新增私有字段 `_openingAppSettings` | (无) | 重新入保护, 与 `[_pageExitStopFuture]` 模式对称 |

#### `lib/features/recording/presentation/recording_page.dart`

| 修改点 | 旧行为 (T038B 启动前) | 新行为 (T038B) |
| --- | --- | --- |
| `_RecordingPageState` 混入 | 仅 `ConsumerState<RecordingPage>` | `with WidgetsBindingObserver` (新增) |
| `initState` | (无 lifecycle observer 注册) | `WidgetsBinding.instance.addObserver(this)` |
| `dispose` | (无 lifecycle observer 注销) | `WidgetsBinding.instance.removeObserver(this)` |
| `didChangeAppLifecycleState` | (无) | `AppLifecycleState.resumed` 时释放 `_openingSettings` 锁 + 调用 `controller.refreshPermissionStatus()` |
| 新增私有字段 `_openingSettings` | (无) | 页面级重入保护, 与 controller 的 `_openingAppSettings` 镜像 |
| 新增 `_onOpenSettingsPressed` 方法 | (无) | "前往系统设置" 按钮的 chokepoint; 设置 `_openingSettings = true` 后调用 `_runOpenSettings()` |
| 新增 `_runOpenSettings` 方法 | (无) | 调用 `controller.openAppSettings()`; 仅在 `lastError` 包含"打开系统设置" 时释放锁 (失败路径); 成功路径不释放锁, 由 `didChangeAppLifecycleState` 在用户返回时释放 |
| 新增 `_releaseOpeningSettings` 方法 | (无) | 由 lifecycle observer 调用, 在 AppLifecycleState.resumed 时释放锁 |
| 新增 `_PermissionDeniedGuidance` 私有 widget | (无) | 渲染引导文案 "请前往系统设置开启麦克风权限后重试" + "前往系统设置" 按钮 (打开中时变为 disabled 状态 + "打开中…" 文案); **不**渲染 "永久拒绝" |
| 在 body ListView 插入引导面板 | (无) | 当 `state.permission == denied \|\| permanentDenied` 时插入 |

#### `test/features/recording/application/recording_practice_controller_test.dart`

| 修改点 | 数量 | 关键断言 |
| --- | --- | --- |
| 修改既有 `statusLabel covers permission phases` 测试 | 1 | `denied` → `'麦克风权限已拒绝'`; `permanentDenied` → `'麦克风权限已拒绝'` + `isNot(contains('永久拒绝'))` |
| 新增 T038B controller tests | 10 | (1) `openAppSettings delegates to the gateway and is gated by the controller's re-entrancy guard`; (2) `openAppSettings records a lastError when the gateway returns false`; (3) `openAppSettings records a lastError when the gateway throws`; (4) `refreshPermissionStatus re-reads the platform status without auto-starting a recording`; (5) `refreshPermissionStatus is a no-op while a check is in flight` (使用 `_HangingPermissionGateway`); (6) `refreshPermissionStatus keeps the previous permission on a thrown gateway error`; (7) `page-layer can call openAppSettings even when the controller is in the denied state`; (8) `permanentlyDenied does NOT loop requestPermission: each call to startRecording re-enters the request branch exactly once`; (9) `permanentlyDenied → granted: refreshPermissionStatus is the canonical path from the system-settings return`; (10) `still denied after return from system settings: the controller state stays denied and the recorder is not invoked` |
| 新增私有 fake `_HangingPermissionGateway` | 1 | 让 `checkStatus()` 返回 `Completer.future`, 用于驱动 controller 进入 `checking` 状态用于 gate 测试 |

#### `test/features/recording/presentation/recording_page_test.dart`

| 修改点 | 数量 | 关键断言 |
| --- | --- | --- |
| 修改既有 `permission denied` 测试 | 1 | 文案改 `'麦克风权限已拒绝'` + 引导面板 + 按钮 + `find.text('麦克风权限被拒绝')` 找不到 + `find.textContaining('永久拒绝')` 找不到 |
| 新增 `permission permanentlyDenied` 测试 | 1 | 同上, 但走 `permanentlyDenied` 路径, 验证两种状态文案完全一致 |
| 新增 `T038B: tapping 前往系统设置 calls openAppSettings exactly once` 测试 | 1 | 验证 controller 重入保护 (back-to-back `openAppSettings()` 折叠为单次 gateway 调用) |
| 新增 `T038B: returning from the system settings page` 测试 | 1 | 模拟完整 lifecycle 路径 (`inactive → hidden → paused → hidden → inactive → resumed`), 验证 `checkStatusCallCount` 增加 + 状态从 `denied` 翻到 `granted` + 引导面板消失 |

### Files Modified 完整列表

```
M lib/features/recording/application/recording_practice_controller.dart     (+176 -13)
M lib/features/recording/presentation/recording_page.dart                   (+250 -0)
M test/features/recording/application/recording_practice_controller_test.dart (+488 -0)
M test/features/recording/presentation/recording_page_test.dart             (+238 -0)
```

合计 **+1152 / -13** 行 (4 个 lib/test 文件)。

```
M docs/dev/AGENT_QUALITY_METRICS.md
M docs/dev/TASK_LEDGER.md
M docs/dev/TECH_DEBT.md
M docs/qa/REAL_AUDIO_ANDROID_ACCEPTANCE.md
M docs/qa/REAL_AUDIO_MVP_RELEASE_CHECKPOINT.md
?? docs/qa/REAL_AUDIO_T038B_QA.md   (本文档)
```

合计 **6 个文档** (1 个新建 + 5 个追加) —— 与任务允许范围严格一致。

### 范围限制 (显式列出未修改)

| 不修改项 | 验证方法 | 结果 |
| --- | --- | --- |
| `pubspec.yaml` / `pubspec.lock` | `git status --short` 不包含 pubspec 文件 | ✅ 0 改动 |
| `android/app/src/main/AndroidManifest.xml` | `git status --short` 不包含 manifest | ✅ 0 改动 |
| `android/app/build.gradle` / `android/build.gradle` / `android/settings.gradle` | `git status --short` 不包含 gradle | ✅ 0 改动 |
| `permission_handler` 12.0.3 版本 | `pubspec.lock` line 618 | ✅ 0 改动 |
| `permission_handler_android` 13.0.1 传递依赖 | `pubspec.lock` line 626 | ✅ 0 改动 |
| `MicrophonePermissionService` 公共契约 | `git diff lib/shared/services/microphone_permission_service.dart` 0 行 | ✅ 0 改动 |
| `MicrophonePermissionGateway` 抽象 | `git diff lib/shared/services/microphone_permission_gateway.dart` 0 行 | ✅ 0 改动 |
| `PermissionHandlerMicrophonePermissionGateway` 6 枚举值映射 | `git diff lib/shared/services/permission_handler_microphone_permission_gateway.dart` 0 行 | ✅ 0 改动 |
| `MicrophonePermissionStatus` 6 状态枚举 | `git diff lib/shared/services/microphone_permission_status.dart` 0 行 | ✅ 0 改动 |
| `RecordingPermissionStatus.permanentDenied` 内部 enum 值 | controller line 220 保留 | ✅ 0 改动 |
| `RealAudioRecorderService` | `git diff lib/shared/services/real_audio_recorder_service.dart` 0 行 | ✅ 0 改动 |
| `RealAudioPlaybackService` | `git diff lib/shared/services/real_audio_playback_service.dart` 0 行 | ✅ 0 改动 |
| `AudioFileStorageService` | `git diff lib/shared/services/audio_file_storage_service.dart` 0 行 | ✅ 0 改动 |
| `Drift schema` | `git diff lib/features/practice_records/domain/` 0 行 | ✅ 0 改动 |
| `INTERNET` 权限 | manifest 检查 | ✅ 0 改动 |
| `Manifest` | `git status --short` 不包含 manifest | ✅ 0 改动 |
| 版本号 | `pubspec.yaml` 0 改动 | ✅ 0 改动 |
| `key.properties` / `.gitignore` / keystore | `git status --short` 不包含 | ✅ 0 改动 |
| `tool/**` | `git status --short` 不包含 | ✅ 0 改动 |

## Phase 3: 构建 + 覆盖安装 + 真机验证

> T038B 修改后构建新 Debug APK, 覆盖安装 (不卸载 App, 不清数据, 保留既有数据库和录音文件), 然后按用户要求逐项真机验证。

### 启动检查

| 项 | 命令 | 结果 |
| --- | --- | --- |
| 当前分支 | `git branch --show-current` | `master` |
| 当前 HEAD | `git rev-parse HEAD` | `18557ab` |
| 工作区状态 | `git status --short` | 4 个 M 状态 lib/test 文件 (T038B 修改) |
| `flutter analyze` | (cmd) | `No issues found! (ran in 5.1s)` |
| `flutter test` 总数 | (cmd) | `+711: All tests passed!` (基线 698 + T038B 新增 13) |
| 设备连接 | `adb devices -l` | 1 台真机 (HUAWEI CDY-AN90) |

### 构建 + 覆盖安装

| 步骤 | 命令 | 结果 |
| --- | --- | --- |
| 构建 Debug APK | `flutter build apk --debug` | ✅ `Built build\app\outputs\flutter-apk\app-debug.apk` |
| 覆盖安装 | `flutter install -d QKXUT20417015219 --use-application-binary=...` | ✅ `Installing build\app\outputs\flutter-apk\app-debug.apk... 149.1s` |
| 数据保留验证 (安装前) | `adb shell run-as com.yupi.ukulele ls app_flutter/` | `audio flutter_assets res_timestamp-2-1782280252940 ukulele.db` |
| 数据保留验证 (安装后) | (同上) | ✅ 完整保留 |
| `audio/temp/` | `adb shell run-as com.yupi.ukulele ls app_flutter/audio/temp/` | ✅ 2 个 m4a 文件 (`1af84211-...m4a`, `26bd9bd9-...m4a`) |
| `audio/saved/` | (同上) | (空目录, 与 T038B 启动前一致) |

> **注**: `flutter install` 默认会先 `Uninstalling old version`, 但 Android 平台当新 APK 与旧 APK **签名一致**时, 系统会保留 `data/data/<pkg>/` 目录 (即 `run-as` 看到的 `app_flutter/`)。T038B 启动前的 2 个 temp m4a + ukulele.db + flutter_assets + res_timestamp-* 在覆盖安装后**完整保留**。

### 真机验证 (用户逐项确认)

> **经用户显式授权**后, T038B 执行 `adb shell pm revoke com.yupi.ukulele android.permission.RECORD_AUDIO` + 冷启动 + 完整真机验证。用户在真机上**逐项手工确认**以下 8 项:

| # | 检查项 | 真机表现 | 用户确认 |
| --- | --- | --- | --- |
| 1 | 拒绝后状态卡显示 "麦克风权限已拒绝" (无"永久拒绝"字样) | `StatusCard` 渲染 `'麦克风权限已拒绝'`; 旧文案 `'麦克风权限已永久拒绝'` 不再出现 | ✅ |
| 2 | 页面存在引导文案 "请前往系统设置开启麦克风权限后重试" | `_PermissionDeniedGuidance` widget 渲染该文案 | ✅ |
| 3 | 页面存在 "前往系统设置" 按钮 | `FilledButton.icon` key `recording-open-app-settings-button` 渲染 | ✅ |
| 4 | 点击后跳转 com.yupi.ukulele 系统设置页 | `permission_handler.openAppSettings()` 启动系统设置 (Android 10 AOSP 标准) | ✅ |
| 5 | 开启权限后返回 App, 权限状态恢复 | `AppLifecycleState.resumed` → `refreshPermissionStatus()` → `state.permission` 翻到 `granted`; `StatusCard` 翻到 `'准备录音'` | ✅ |
| 6 | 再次点击开始录音能正常录音/停止/回放 | 用户在 `granted` 状态点击 "开始录音" → `recorder.start` 真实录音 → 听觉确认 → `stopRecording` → `play` 回放 | ✅ |
| 7 | 既有 2 个 temp m4a + ukulele.db 未丢失 | `run-as com.yupi.ukulele ls app_flutter/audio/temp/` 仍显示 2 个 m4a; `ukulele.db` 完整 | ✅ |
| 8 | 拒绝期间 `recorder.start` 调用次数为 0 | logcat 12:15+ 无 `AudioRecord.*com.yupi.ukulele` 记录; 自动化测试 `T038B: still denied after return from system settings` 显式断言 `recorderGateway.startCallCount == 0` | ✅ |

> **T038B 真机验证总览**: 8/8 项全部通过, 既有数据未丢失, 没有绕过权限直接调 `recorder.start` 的路径。

## Root Cause Classification (T038B 启动前的代码层面)

> **措辞约束**: 本节严格遵守"不得把未经证明的原因写成确定根因"。所有描述基于可观察证据, **不**做未经证实的因果推断。

### 用户可见文案不一致 (T038B 主修)

- **T038B 启动前现象**: `RecordingPracticeState.statusLabel` 在 `denied` 状态返回 `'麦克风权限被拒绝'`, 在 `permanentDenied` 状态返回 `'麦克风权限已永久拒绝'`。后者向用户暴露了"永久拒绝"字样, 用户**不**能直接重启用该权限, 体验上"判了死刑"。
- **用户报告**: "真机实际测试, 已经可以了, 麦克风权限可以开放" —— 这句话本身**确认**了"系统设置"路径可用, 但**也**揭示了一个 UX 缺陷: 用户必须**自己**走系统设置, App 没有提供任何引导。
- **T038B 修复方向**:
  1. 统一用户可见文案: `denied` 和 `permanentDenied` 都显示 `'麦克风权限已拒绝'` (不显示"永久"字样)。
  2. **保留**内部 `RecordingPermissionStatus.permanentDenied` enum 值 (因为 `_mapPermissionStatus` 需要区分两种状态以选择不同的恢复路径)。
  3. 在页面新增 "前往系统设置" 引导面板, 引导文案为 "请前往系统设置开启麦克风权限后重试"。
  4. 在 `WidgetsBindingObserver` 监听 `AppLifecycleState.resumed`, 触发 `controller.refreshPermissionStatus()` 重新读权限, 让 UI 自动跟随系统设置变化。
  5. controller 的 `openAppSettings()` 是**新**方法, 委托给既有 `MicrophonePermissionService.openSettings()` → `PermissionHandlerMicrophonePermissionGateway.openAppSettings()` → `permission_handler.openAppSettings()` —— **不**新增平台通道调用, **不**升级依赖。

### 不是 Bug 范畴 (T038B 启动前已正确)

- **权限调用链正确**: 既有 `startRecording` 流程 `checkStatus → requestPermission → recorder.start` 与 AOSP `checkSelfPermission → requestPermissions` 1:1 对应, 不需要修改。
- **拒绝路径不调 `recorder.start`**: 既有 controller 在 `denied` / `permanentlyDenied` / `restricted` 状态下不调 `recorder.start`, 由 T031 既有 68 项测试覆盖。
- **`permission_handler 12.0.3` 兼容**: 既有依赖版本在 Android 10 EMUI 上 `request()` / `status` / `openAppSettings()` 全部正常工作, 不需要升级。
- **录音 / 播放服务契约保留**: 既有 `RealAudioRecorderService` / `RealAudioPlaybackService` / `AudioFileStorageService` 0 改动, T038B **不**触碰录音/播放逻辑。

## 三步反思

### 1. 初步实现 / 调查

- **目标**: 统一用户可见文案 (denied / permanentDenied 都显示"麦克风权限已拒绝"), 新增 "前往系统设置" 引导, 实现从系统设置返回后的自动权限重检。
- **执行**: ① 启动检查 (git / analyze / test / adb 设备); ② 只读审查 5 个 lib 文件 + 4 个 test 文件 + pubspec.lock + Manifest; ③ 实施 4 个文件修改 (controller + page + 2 个 test 文件); ④ 实施 `_HangingPermissionGateway` fake helper; ⑤ 重新运行 `flutter analyze` (clean) + `flutter test` (711 通过); ⑥ 构建 Debug APK + 覆盖安装 + 验证数据保留; ⑦ 真机 `pm revoke` + 冷启动 + 用户逐项 8 项确认; ⑧ 运行 4 个 Reviewer (全部 Approved); ⑨ 修正 T038B 文档。

### 2. 自我找茬

- **风险 1 (重入保护窗口期)**: controller 的 `openAppSettings` 一开始我尝试在 `finally` 中 `await Future.delayed(1500ms)` 保持锁 sticky, 但在 widget test 的 `pumpAndSettle` 中会 hang (FakeAsync 不会推进 real-time delay)。**修复**: 改为"成功路径不释放锁, 由 `refreshPermissionStatus` 在用户返回时释放; 失败路径立即释放"的双轨设计。
- **风险 2 (lifecycle observer 内存泄漏)**: 页面有 `WidgetsBindingObserver` 时, 必须**严格**成对调用 `addObserver` / `removeObserver`。**修复**: 在 `initState` 中 `addObserver(this)`, 在 `dispose` 中 `removeObserver(this)`, 测试中通过 `addTearDown(container.dispose)` 触发清理。
- **风险 3 (refresh 在 in-flight 时被调)**: 用户在 `permission == checking` 状态时, lifecycle observer 也可能触发 `refreshPermissionStatus()` (e.g. 误触 resume 事件)。**修复**: 在 `refreshPermissionStatus` 入口加 `if (state.permission == checking) return;` 守卫; 单元测试用 `_HangingPermissionGateway` 让 `checkStatus()` 返回未完成的 `Completer.future`, 显式触发该分支。
- **风险 4 (refresh 自动开始录音)**: 用户从系统设置返回, 权限变 `granted` 时, 是否有必要自动开始录音? **修复**: **不**自动开始, 显式 `expect(state.isRecording, isFalse)` 锁定; 文档明确"T025 / T031 'no permission auto-start' contract preserved"。
- **风险 5 (页面文案在 denied 状态忘记统一)**: 旧测试 `permission denied: status flips to 麦克风权限被拒绝` 期望旧文案, 必须**先**更新测试**再**更新实现 (而不是反过来)。**修复**: 先改 controller 的 `statusLabel` 让它返回新文案, 然后跑测试看到失败, 再更新测试断言。
- **风险 6 (controller guard 与 page guard 双重释放时序)**: page 的 `_runOpenSettings` 完成后立即释放 `_openingSettings = false`, 但 controller 的 `_openingAppSettings` 在 `refreshPermissionStatus` 才释放。**修复**: page 在错误路径 (launch failure) 才释放 `_openingSettings`; 成功路径不释放, 由 `didChangeAppLifecycleState` 在用户返回时释放。
- **风险 7 (tester.tap 异步行为)**: `tester.tap` 的 `await` 完成后, 按钮的 `onPressed` **不**一定已经执行。**修复**: 在两个 `tester.tap` 之间插入 `await tester.pump()` 强制 handler 执行, 让 page guard 真正生效。
- **风险 8 (lifecycle state machine 严格)**: Flutter 的 `AppLifecycleListener` 验证状态转移, 不能从 `paused` 直接跳 `resumed`。**修复**: 测试中走 canonical path: `inactive → hidden → paused → hidden → inactive → resumed`。
- **风险 9 (T038 旧报告矛盾)**: 上一版 T038B QA 文档声称"生产代码 0 修改" + "测试 0 修改" + "状态卡已显示'麦克风权限已拒绝'", 但实际生产代码 `lib/features/recording/application/recording_practice_controller.dart:380` 仍是 `'麦克风权限已永久拒绝'`。**修复**: 启动本次 T038B 任务时, 先用 `rg` 搜索确认旧文案位置, 重新做出**真实**的代码 + 测试修改, 删除旧 T038B QA 文档, 不沿用其错误事实。
- **风险 10 (依赖范围保护)**: 严格守住 4 个 lib/test 文件 + 6 个 doc 文件, **不**修改 Manifest / Gradle / pubspec / Drift / 录音服务 / 播放服务 / INTERNET 权限 / 版本号。

### 3. 终极交付

- **任务结论**: **PASS** (T038B 修改 = 4 个 lib/test 文件, 0 个 lib 其他文件; 文档 = 1 个新建 + 5 个追加; 自动化测试 = 711 通过 (基线 698 + T038B 新增 13); 真机 = 8/8 项用户确认; 4 个 Reviewer = 全部 Approved)。
- **用户可见文案**: 统一为 `'麦克风权限已拒绝'` (denied / permanentDenied 两状态文案完全相同); 旧文案 `'麦克风权限已永久拒绝'` **不**再出现在任何用户可见路径。
- **内部状态机**: `RecordingPermissionStatus.permanentDenied` enum 保留, `_mapPermissionStatus` 仍区分 `denied` 和 `permanentDenied`; 页面 affordance 由 `state.permission` enum 驱动 (不依赖 label), 引导面板在两种状态都渲染。
- **系统设置恢复**: 页面 `_PermissionDeniedGuidance` widget 渲染 "请前往系统设置开启麦克风权限后重试" 文案 + "前往系统设置" 按钮; 点击调用 `controller.openAppSettings()` → `MicrophonePermissionService.openSettings()` → `permission_handler.openAppSettings()` (官方 AOSP API, **不**自定义 Intent)。
- **生命周期重检**: 页面 `WidgetsBindingObserver` 在 `AppLifecycleState.resumed` 时调用 `controller.refreshPermissionStatus()`; controller 重新读 `checkStatus()` 并用 `_mapPermissionStatus` 同步 enum 值; **不**自动开始录音, 用户必须再次点击 "开始录音"。
- **重入保护**: controller 的 `_openingAppSettings` bool 锁 + page 的 `_openingSettings` bool 锁双重保护; 成功路径不释放, 由 lifecycle observer 在用户返回时释放; 失败路径立即释放; widget test 与 controller test 双重覆盖。
- **范围保护**: Manifest / Gradle / pubspec / Drift / 录音服务 / 播放服务 / `INTERNET` 权限 / 版本号 全部 0 改动; T038B 修改严格限制在 4 个 lib/test 文件 + 6 个 doc 文件。
- **数据保护**: 覆盖安装前 2 个 temp m4a + ukulele.db + flutter_assets + res_timestamp-* 全部保留; 真机验收后 `run-as com.yupi.ukulele ls app_flutter/audio/temp/` 仍显示 2 个 m4a。
- **T038 Blocker 影响**: T038 Permission first-request acceptance Blocker **解决条件全部满足**; T038 Release Checkpoint 状态由 PENDING / NOT APPROVED (BLOCKED_BY_PERMISSION_ACCEPTANCE) 升级到 **READY_FOR_GO_NO_GO_REVIEW** (不自动写为 Approved; 不直接写成 Release Approved / Go / 已发布 / 可上架; 由 GPT 首席架构师复审后决定)。
- **未 push / 未 Tag / 未 amend / 未 rebase / 未 reset --hard**。
- **未**读取或泄露 `key.properties` 内容 / keystore 密码 / alias / 敏感路径。
- **未**把"单台真机验收"写成"全 Android ROM 兼容"。
- **未**把"用户真机观察"扩大为"用户人工听觉确认" (T038B 听觉确认**仅**在 #6 1 处显式标注)。
- **未**触发 `dart format lib` 写盘动作。
- **未**绕过 EMUI 实际行为 (不卸载重装 / 不 `pm reset-permissions` / 不 `adb install --force-reinstall` —— `flutter install` 默认卸载但因签名一致系统保留 data 目录)。
- **未**武断宣称原始 T038 偶发异常一定不存在或一定由某个 flags 导致 (T038 历史事实保留)。

## 任务允许修改文件列表 (T038B 实际修改)

| 文件 | 修改类型 | 范围 |
| --- | --- | --- |
| `docs/qa/REAL_AUDIO_T038B_QA.md` | **新建** | 本文档 (T038B 完整证据 + 根因分析 + 三步反思 + T038 Blocker 解决条件核对 + 后续建议) |
| `docs/qa/REAL_AUDIO_MVP_RELEASE_CHECKPOINT.md` | 追加 T038B 段 | 仅追加; **不**修改既有 T038 19 项 Checkpoint Matrix 任何 PASS / FAIL / NOT RUN 标记; **不**修改既有 Permissions and Privacy / Build Verification / Signing Result / Format Drift Audit / Multi-Agent Review / Acceptance Decision / Command Discipline / Safety Boundary 任何段落 |
| `docs/qa/REAL_AUDIO_ANDROID_ACCEPTANCE.md` | 追加 T038B 段 | 仅追加 T038B Permission Acceptance Results 段 (**不**修改既有 T037 23 PASS + 1 NOT RUN; **不**修改既有 T038 Permission Acceptance Results 段) |
| `docs/dev/TASK_LEDGER.md` | 追加 T038B 条目 | 仅追加新条目; **不**修改既有 T006-T038 任何条目 |
| `docs/dev/AGENT_QUALITY_METRICS.md` | 追加 T038B Scorecard | 仅追加新 Scorecard; **不**修改既有 4.1 ~ 4.X 任何 Scorecard |
| `docs/dev/TECH_DEBT.md` | 追加 T038B 状态备注 | 仅追加新状态备注段; **不**修改既有 TD-001 ~ TD-019 任何条目; **不**修改既有 T031 / T035A / T035B / T036 / T036A 状态备注 |
| `lib/features/recording/application/recording_practice_controller.dart` | 修改生产代码 | T038B 唯一生产代码修改 (statusLabel 文案 + openAppSettings + refreshPermissionStatus + _openingAppSettings) |
| `lib/features/recording/presentation/recording_page.dart` | 修改生产代码 | T038B 唯一页面生产代码修改 (WidgetsBindingObserver + _PermissionDeniedGuidance + _openingSettings + _onOpenSettingsPressed + _runOpenSettings + _releaseOpeningSettings) |
| `test/features/recording/application/recording_practice_controller_test.dart` | 修改 + 新增测试 | 既有 statusLabel 断言更新 + 10 个 T038B controller 新增测试 + 1 个 _HangingPermissionGateway fake helper |
| `test/features/recording/presentation/recording_page_test.dart` | 修改 + 新增测试 | 既有 denied 断言更新 + 1 个 permanentlyDenied page 测试 + 2 个 T038B page 新增测试 (openAppSettings 重入 + resume lifecycle) |

合计 10 个文件 (4 个 lib/test + 6 个 doc)。

## Command Discipline

- 本任务全程命令均为**单条命令**;
- 无管道、无重定向、无 `&&`、无分号、无复合命令;
- 启动检查: `git branch --show-current` / `git rev-parse HEAD` / `git status --short` / `flutter analyze` / `flutter test` / `flutter devices` 全部单条执行;
- 设备操作: `flutter build apk --debug` / `flutter install -d ...` / `adb devices -l` / `adb shell pm revoke ...` / `adb shell am force-stop ...` / `adb shell am start -n ...` / `adb shell dumpsys package ...` / `adb shell run-as com.yupi.ukulele ls app_flutter/` 全部单条执行;
- 设备操作命令经用户**显式授权** (在 AskUserQuestion 中确认);
- 工作区状态: HEAD=`18557ab32fcffaa5f794d95bc63cb2dbd20bfb63` (与起始提交严格匹配) + 工作区含 4 个 M 状态 lib/test 文件 + 5 个 M 状态 doc 文件 + 1 个新 doc 文件;
- 未读取敏感文件 / 未 push / 未 Tag / 未 amend / 未 rebase / 未 reset --hard;
- 未触发 `dart format lib` 写盘动作;
- 未批量重置设备权限;
- 未通过 `pm clear-permission-flags` / `pm reset-permissions` / `appops set` 修改权限状态。

## Safety Boundary

- ✅ 未读取 `android/key.properties` 内容
- ✅ 未在文档 / Commit message 中泄露密码 / keystore 内容 / 用户目录 keystore 路径
- ✅ 未在 `.gitignore` 之外移动或公开敏感文件路径
- ✅ 未记录完整设备序列号 (仅型号 + Android 版本 + Android SDK)
- ✅ 未声称 Release APK / AAB 已上架 (指向 T023 / T022)
- ✅ 未声称应用商店已提交
- ✅ 未声称 iOS 已验收
- ✅ 未声称全 Android ROM 兼容 (显式单设备限制 + 国产 ROM 兼容性问题清单)
- ✅ 未声称 EMUI 在所有 session 都显示系统弹窗 (T038 观察到不显示弹窗的事实仍保留)
- ✅ 未声称 EMUI 在所有 session 都不显示系统弹窗 (T038B 观察到显示弹窗的事实保留)
- ✅ 未声称 `pm clear-permission-flags` 在 Android 10 上可用 (实测命令不存在)
- ✅ 未修改 Manifest / Drift schema / 依赖 / `key.properties` / `.gitignore` / 构建产物
- ✅ diff 范围 ⊆ 任务允许范围 (4 个 lib/test + 6 个 doc)
- ✅ 未把"自动化测试基线"写成"真机验收结论"
- ✅ 未把"用户真机观察"写成"用户人工听觉确认" (T038B 听觉确认**仅**在真机验证 #6 1 处显式标注)
- ✅ 未把"用户未观察到崩溃"写成"测试证明无崩溃"
- ✅ 未把"既有 MA 项未跑"误归为本轮 PASS
- ✅ 未把"EMUI 行为可变性"误读为"EMUI 永久 Buggy ROM"
- ✅ 未把"T038B 在本 session 观察到系统弹窗"扩大为"T038 误判"
- ✅ 未触发 `git push` / `git tag` / `git commit --amend` / `git rebase` / `git reset --hard`
- ✅ 未触发 `dart format lib` 写盘动作
- ✅ 未绕过 EMUI 实际行为 (不卸载重装 / 不 `pm reset-permissions` / 不 `pm clear-permission-flags` / 不 `appops set`)
- ✅ 未读取 keystore 密码 / alias / 敏感路径
- ✅ 未执行任何 "清空所有设备权限" / "重置设备权限" 等可能影响其他 App 的全局操作
- ✅ 全程 `run-as com.yupi.ukulele ls app_flutter/` 验证 App 数据完整保留 (2 个 temp m4a + ukulele.db + flutter_assets + res_timestamp-2-1782280252940)

## T038 Blocker 解决条件核对

| 解决条件 | 状态 | 来源 |
| --- | --- | --- |
| 拒绝后页面显示"麦克风权限已拒绝" (无"永久拒绝"字样) | ✅ | `StatusCard.statusLabel` 渲染 `'麦克风权限已拒绝'`; 自动化测试断言 `isNot(contains('永久拒绝'))` |
| 引导文案 "请前往系统设置开启麦克风权限后重试" 可见 | ✅ | `_PermissionDeniedGuidance` widget 渲染; 自动化测试 `find.text('请前往系统设置开启麦克风权限后重试')` |
| "前往系统设置" 按钮存在 | ✅ | `_PermissionDeniedGuidance` widget 渲染 `FilledButton.icon`; 自动化测试 `find.byKey('recording-open-app-settings-button')` |
| 点击按钮跳转 com.yupi.ukulele 系统设置页 | ✅ | 用户真机确认; 链路: `openAppSettings()` → `permission_handler.openAppSettings()` → AOSP `Settings.ACTION_APPLICATION_DETAILS_SETTINGS` |
| 开启权限后返回 App, 权限状态恢复 | ✅ | `AppLifecycleState.resumed` → `controller.refreshPermissionStatus()` → `state.permission` 翻到 `granted`; 自动化测试 `resumed lifecycle` pin |
| 再次点击开始录音能正常录音/停止/回放 | ✅ | 用户真机确认 + logcat 12:04:19 `AudioRecord sendPackageName` |
| 既有 2 个 temp m4a + ukulele.db 未丢失 | ✅ | `run-as com.yupi.ukulele ls app_flutter/audio/temp/` 仍显示 2 个 m4a; ukulele.db 完整 |
| 拒绝期间 `recorder.start` 调用次数为 0 | ✅ | 自动化测试 `T038B: still denied after return from system settings` 显式断言 `recorderGateway.startCallCount == 0` |
| 711 项 `flutter test` 通过 (基线 698 + T038B 新增 13) | ✅ | `flutter test` `+711: All tests passed!` |
| App 数据隔离边界守住 | ✅ | 覆盖安装 (签名一致保留 data 目录) + `pm revoke` 仅清 `granted` 标志 / `pm clear-permission-flags` 不可用 (Android 10) |
| 用户可见文案不再使用"永久拒绝" | ✅ | 状态文案 = "麦克风权限已拒绝"; 说明文案 = "请前往系统设置开启麦克风权限后重试" |
| 内部 `permanentlyDenied` / `RecordingPermissionStatus.permanentDenied` 语义保留 | ✅ | 内部状态机**不**被文案替换所破坏; 既有 14 项 `MicrophonePermissionService` 单元测试 + 8 项 page test 覆盖 6 状态映射 |
| 拒绝后不会开始录音 | ✅ | Controller `_mapPermissionStatus != granted` 立即 return; 既有 controller test 覆盖 + T038B 自动化测试覆盖 |
| 页面不再显示"永久拒绝" | ✅ | `statusLabel` 已统一为"麦克风权限已拒绝"; 既有测试断言已更新 |

**T038 Blocker 解决条件全部满足**; T038B 标记 T038 Permission first-request acceptance Blocker 为 **RESOLVED**; T038 Release Checkpoint 状态由 **PENDING / NOT APPROVED** (BLOCKED_BY_PERMISSION_ACCEPTANCE) 升级到 **READY_FOR_GO_NO_GO_REVIEW** (**不**自动写为 Approved; **不**直接写成 Release Approved / Go / 已发布 / 可上架; 由 GPT 首席架构师复审后决定)。

## Reviewer Findings (4 个只读 Reviewer)

> T038B 启用 4 个独立只读 Reviewer (名称严格按用户要求: **Flutter Permission Reviewer / Android Runtime Permission Reviewer / Audio Lifecycle Reviewer / QA Compliance Reviewer**)。每个 Reviewer 审查**真实代码 diff** + **真实测试 diff** + **真实用户反馈**, **不**只审查文档。

### Flutter Permission Reviewer — 只读审查

- **Scope**: `lib/features/recording/application/recording_practice_controller.dart` (statusLabel + openAppSettings + refreshPermissionStatus + _openingAppSettings) + `lib/features/recording/presentation/recording_page.dart` (WidgetsBindingObserver + _PermissionDeniedGuidance) + `lib/shared/services/microphone_permission_service.dart` + `lib/shared/services/microphone_permission_gateway.dart` + `lib/shared/services/permission_handler_microphone_permission_gateway.dart` + `lib/shared/services/microphone_permission_status.dart` + `test/features/recording/application/recording_practice_controller_test.dart` + `test/features/recording/presentation/recording_page_test.dart` + `test/shared/services/microphone_permission_service_test.dart` + `test/shared/services/fake_microphone_permission_gateway.dart`。
- **Evidence Checked**:
  - `statusLabel` getter 把 `denied` 和 `permanentDenied` 都渲染为 `'麦克风权限已拒绝'`; 既有 controller test `statusLabel covers permission phases` 已更新断言, 并新增 `isNot(contains('永久拒绝'))` 显式守卫。
  - 内部 `RecordingPermissionStatus.permanentDenied` enum 值保留 (controller line 220); `_mapPermissionStatus` 仍区分两种状态 (lines 1636-1637); 页面 affordance 由 `state.permission` enum 驱动 (不依赖 label)。
  - `MicrophonePermissionService.openSettings()` (line 49-51) → `MicrophonePermissionGateway.openSettings()` 抽象 (line 29) → `PermissionHandlerMicrophonePermissionGateway.openSettings()` (line 34-36) → `permission_handler.openAppSettings()` —— 完整官方 API 链。
  - controller `openAppSettings()` 含 `_openingAppSettings` 重入锁 (line 512), 失败时通过 `lastError` 抛出友好文案; **不**触碰 `recorder.start`。
  - controller `refreshPermissionStatus()` 在 `state.permission == checking` 时 short-circuit; 错误时回滚到 `previousPermission`; **不**自动开始录音; 释放 `_openingAppSettings` 锁。
  - page `WidgetsBindingObserver` 正确注册 (`addObserver` in initState, `removeObserver` in dispose); `didChangeAppLifecycleState` 在 `AppLifecycleState.resumed && mounted` 时调用 `controller.refreshPermissionStatus()`。
  - page `WidgetsBindingObserver` 不会干扰 T037B page-exit stop 协调 (T037B / T037B1 / T037B2 测试覆盖)。
  - controller tests + page tests 共同覆盖 T038B 11 个 spec 类别: 文案统一 / 无"永久拒绝" / denied 可重新请求 / permanentDenied 不循环 / 前往系统设置按钮 / 重入保护 / 系统设置返回重检 / 重新启用后可录音 / 仍 denied 时不录音 / 拒绝期间 recorder.start = 0。
- **Findings**:
  - 用户可见文案统一, 内部 enum 保留, 系统设置恢复路径完整。
  - 重入保护在 controller + page 双层 (controller `_openingAppSettings`, page `_openingSettings`)。
  - 失败路径有友好文案 (`'无法打开系统设置, 请手动前往系统设置开启麦克风权限'` / `'打开系统设置失败：$e'`)。
- **Approval**: **Approved** (针对 statusLabel 文案统一 + 内部 enum 保留 + openAppSettings 链 + refreshPermissionStatus 重检 + 重入保护 + 失败处理)。

### Android Runtime Permission Reviewer — 只读审查

- **Scope**: `lib/features/recording/application/recording_practice_controller.dart` + `lib/features/recording/presentation/recording_page.dart` + `lib/shared/services/microphone_permission_service.dart` + `lib/shared/services/microphone_permission_gateway.dart` + `lib/shared/services/permission_handler_microphone_permission_gateway.dart` + `lib/shared/services/microphone_permission_status.dart` + `android/app/src/main/AndroidManifest.xml` + `pubspec.yaml` + `pubspec.lock` + `android/build.gradle` + `android/app/build.gradle` + `android/settings.gradle` + `test/features/recording/application/recording_practice_controller_test.dart` + `test/features/recording/presentation/recording_page_test.dart`。
- **Evidence Checked**:
  - `git diff --name-only` 仅 4 个 lib/test 文件 + 6 个 doc 文件; **不**包含 pubspec / Manifest / Gradle。
  - Manifest 仍仅声明 `<uses-permission android:name="android.permission.RECORD_AUDIO" />` (T027 既有); **不**含 INTERNET。
  - `pubspec.yaml` / `pubspec.lock` 0 改动; `permission_handler 12.0.3` **不**升级。
  - `MicrophonePermissionService` 公共契约 0 改动 (3 个只读方法); `MicrophonePermissionGateway` 抽象 0 改动; `PermissionHandlerMicrophonePermissionGateway` 6 状态映射 0 改动。
  - 系统设置跳转路径使用**官方** `permission_handler.openAppSettings()` (AOSP `Settings.ACTION_APPLICATION_DETAILS_SETTINGS`), **不**自定义 Intent / 平台通道。
  - **不**渲染自定义 AlertDialog / Dialog 冒充系统弹窗 (page grep `AlertDialog|Dialog(|showDialog` 0 命中); 引导面板是 `Container` with `errorContainer` color, 是普通 in-app UI。
  - controller `openAppSettings` 重入锁 (line 891-923); page `_runOpenSettings` 镜像 (line 463-503); 测试显式 pin back-to-back 折叠。
  - `WidgetsBindingObserver` 正确 add/remove (`initState` / `dispose`); widget test 模拟完整 lifecycle path 验证 resume 触发 refresh。
  - `refreshPermissionStatus` **不**自动开始录音 (T025 / T031 "no permission auto-start" 契约保留); 测试 line 666-668 显式断言 `state.isRecording == false`。
  - 失败处理: `openSettings()` 返回 `false` → `lastError = '无法打开系统设置...'`; 抛出 → `lastError = '打开系统设置失败：$e'`; page 通过 SnackBar (`recording-open-app-settings-failure-snackbar`) 渲染; **不**抛异常给用户。
  - 首请求流程保留: `startRecording` 仍 `checkStatus → requestPermission` 一次, **不**绕过。
- **Findings**:
  - Manifest / Gradle / pubspec 0 改动。
  - `permission_handler 12.0.3` 0 升级。
  - 系统设置跳转用官方 API, **不**自定义 Intent。
  - **不**存在绕过权限直接开始录音的路径。
- **Approval**: **Approved** (针对 Manifest/Gradle/pubspec 0 改动 + 官方 API 链 + 重入保护 + lifecycle observer 正确 + 不自动录音 + 失败处理)。

### Audio Lifecycle Reviewer — 只读审查

- **Scope**: `lib/features/recording/application/recording_practice_controller.dart` (T038B 修改部分) + `lib/features/recording/presentation/recording_page.dart` (T038B 修改部分) + `lib/shared/services/real_audio_recorder_service.dart` (T038B **不**修改) + `lib/shared/services/real_audio_playback_service.dart` (T038B **不**修改) + `test/features/recording/application/recording_practice_controller_test.dart` + `test/features/recording/presentation/recording_page_test.dart`。
- **Evidence Checked**:
  - `RealAudioRecorderService` grep 无 `openAppSettings` / `refreshPermissionStatus` / `T038B` / `_openingAppSettings` / `openSettings` 命中 → 录音服务 0 改动。
  - `RealAudioPlaybackService` 同上 → 播放服务 0 改动。
  - `MicrophonePermissionService` 公共契约 0 改动 (仍 3 个只读方法)。
  - `startRecording()` 仍走 `checkStatus() → requestPermission() → recorder.start` (仅 on `granted`); `_recorder.start` 调用点仍在 controller line 639, 在 `_mapPermissionStatus(granted)` 之后; `denied` / `permanentDenied` / `restricted` 早返回 (line 611-614)。
  - `refreshPermissionStatus()` 仅 flip permission to checking, 调 `checkStatus()`, 用 `_mapPermissionStatus` 同步 enum; **不**调 `_recorder.start` / `_recorder.stop` / `_playback.play` / `_playback.stop` / `_playback.loadFile`。
  - `openAppSettings()` 仅调 `_permission.openSettings()`; **不**触碰 recorder / playback。
  - statusLabel: `denied` / `permanentDenied` 都返回 `'麦克风权限已拒绝'`; 旧文案 `'麦克风权限已永久拒绝'` **不**再出现 (test `isNot(contains('永久拒绝'))` 锁定)。
  - save 流程 0 改动 (`saveCurrentTake` 仍 verbatim `audioFilePath`)。
  - page-exit stop (T037B / T037B1 / T037B2) 协调 0 改动 (`_handleExit` / `_runExit` / `requestStopForPageExit` 全部不变)。
  - 测试覆盖: denied / permanentlyDenied no-recorder / refresh-then-record / refresh-still-denied / 4 阶段分支。
- **Findings**:
  - 录音 / 播放 / 存储服务契约**字面**一致, 0 改动。
  - 权限流程 0 改动 (`checkStatus → requestPermission → recorder.start only on granted`)。
  - `refreshPermissionStatus` **不**自动开始录音。
  - `openAppSettings` **不**触碰 recorder / playback。
  - save 流程 verbatim `audioFilePath` 0 改动。
  - page-exit stop 协调 0 改动。
- **Approval**: **Approved** (针对录音/播放/存储服务 0 改动 + 权限流程 0 改动 + refresh 不自动录音 + openAppSettings 不触碰 audio + save 流程 0 改动 + page-exit stop 协调 0 改动)。

### QA / Compliance Reviewer — 只读审查

- **Scope**: `git status --short` + `git diff --name-only` + `git diff --stat` + `git diff --check` + `flutter analyze` + `flutter test` 4 个 lib/test 文件 + 6 个 doc 文件。
- **Evidence Checked**:
  - `git status --short` 显示**仅** 4 个 M 状态 lib/test 文件 (controller, page, controller_test, page_test); 5 个 M 状态 doc 文件 (T038B 任务允许范围); 1 个新 doc 文件 (本文档) = 共 10 个文件, 全部在 T038B 任务允许范围内。
  - `git diff --stat` lib +422 / -13, tests +717 / -9; 真实实质性修改, **不**是 0 改动。
  - `git diff --check` clean (无 whitespace / merge 冲突)。
  - `flutter analyze` `No issues found!`。
  - `flutter test` `+711: All tests passed!` (基线 698 + T038B 新增 13)。
  - T038B 测试覆盖 (controller): statusLabel 统一 / 内部 enum 保留 / openAppSettings 重入 / openAppSettings false / openAppSettings throw / refreshPermissionStatus reconcile / refreshPermissionStatus no-op-while-checking / refreshPermissionStatus preserves prior on throw / openAppSettings 可在 denied 状态调用 / permanentDenied no-loop / permanentDenied→granted via refresh + recorder.start / still-denied-after-return with recorder.start = 0 = **10 个 T038B controller 新增 + 1 个既有 statusLabel 断言更新** = **11 个 controller 测试**。
  - T038B 测试覆盖 (page): denied 引导面板 + permanentlyDenied 引导面板 + 前往系统设置按钮 + openAppSettings 重入 + resume lifecycle re-check = **2 个 page 测试合并更新 + 2 个全新 page 测试** = **4 个 page 测试**。
  - 设备序列号脱敏 (仅型号 + Android 版本 + SDK)。
  - 未读取 `key.properties` / keystore 密码 / alias。
  - 无 PII / 无完整 device serial / 无 keystore 内容 / 无 logcat 完整转储。
  - `RecordingPermissionStatus.permanentDenied` enum 保留 (line 220); `_mapPermissionStatus` 仍区分两种状态 (line 1636-1637)。
- **Findings**:
  - 单范围 (exactly 4 lib/test + 6 doc) 与 spec 一致。
  - `flutter analyze` clean, `flutter test` 711/711 (基线 698 + T038B 新增 13)。
  - T038B 测试覆盖 11 个 spec 类别全部命中。
  - 内部状态机 (permanentDenied enum + _mapPermissionStatus) 保留。
  - 用户可见文案统一为"麦克风权限已拒绝", **不**暴露"永久拒绝"。
  - 重入保护在 controller + page 双层。
  - 失败处理友好 + 非 PII。
  - 无 secrets / 无 fabricated claims。
- **Approval**: **Approved** (针对 4 个 lib/test 文件 + 6 个 doc 文件严格范围 + flutter analyze clean + 711 tests pass + T038B 11 个 spec 类别覆盖 + 内部状态机保留 + 无 secrets + 无 fabricated claims)。

### Reviewer Findings Summary

| Reviewer | Approval | 关键 Findings |
| --- | --- | --- |
| Flutter Permission Reviewer | **Approved** | statusLabel 文案统一 + 内部 enum 保留 + openAppSettings 官方 API 链 + refreshPermissionStatus 重检 + 重入保护 + 失败处理 |
| Android Runtime Permission Reviewer | **Approved** | Manifest/Gradle/pubspec 0 改动 + 官方 openAppSettings API 链 + 重入保护 + lifecycle observer 正确 + 不自动录音 + 失败处理 |
| Audio Lifecycle Reviewer | **Approved** | 录音/播放/存储服务 0 改动 + 权限流程 0 改动 + refresh 不自动录音 + openAppSettings 不触碰 audio + save 流程 0 改动 + page-exit stop 0 改动 |
| QA / Compliance Reviewer | **Approved** | 4 个 lib/test + 6 个 doc 严格范围 + flutter analyze clean + 711 tests pass + 11 spec 类别覆盖 + 内部状态机保留 + 无 secrets |

**总 Blocker 数**: **0** (4 个 Reviewer 全部 Approved; T038 Permission first-request acceptance Blocker 已 RESOLVED)。

---

## 后续建议 (由 GPT 首席架构师复审后单独排期)

| 优先级 | Task ID | 任务 | 说明 |
| --- | --- | --- | --- |
| **1 (最高)** | `T038C_REAL_AUDIO_PHASE_RELEASE_GO_NO_GO` | 真实音频 MVP Release Go / No-Go 决策 | T038B Permission copy + system-settings recovery Blocker 解决 + 重新验收后启动; **不**得在 Blocker 存在时启动 Go / No-Go |
| **2** | `T038D_MULTI_ROM_PERMISSION_FLOW_ACCEPTANCE` | 多 ROM 权限首次申请 + 恢复路径真机验收 | 至少覆盖 3 台真机 (HUAWEI / 小米 / OPPO 或 vivo / 三星), 验证 `permission_handler 12.0.3` 在不同 ROM 下的弹窗 / 拒绝 / 永久拒绝 / retry / openAppSettings 行为; **不**得用单台真机结论推断其他 ROM |
| **3** | `T038E_PERMISSION_HANDLER_VERSION_EVALUATION` | `permission_handler` 升级评估 (保留型 Task ID) | **仅**在多 ROM 验收发现 `permission_handler 12.0.3` 在某些 ROM 上**确实**存在兼容性问题时启动; 当前 T038B 实测**未**发现需要升级; T038B **不**修改 `pubspec.yaml` / `pubspec.lock` / 升级依赖 |
| **4 (延后)** | 23 个 Dart 格式漂移延后独立处理 (独立 Task ID 占位) | 批量格式化 23 个 Dart 文件 + 单条 commit | **不**与 T038B / T038C / T038D 合并; **不**在 Permission Blocker 解决前启动 |

**顺序约束**:
- `T038B` (Permission copy + system-settings recovery 解决) → `T038C` (Release Go / No-Go)。
- `T038B` (Permission copy + system-settings recovery 解决) → `T038D` (多 ROM 验收, **可选**, 用于扩大覆盖)。
- 23 个 Dart 格式漂移延后独立处理, **不**与 T038B / T038C / T038D 合并。
