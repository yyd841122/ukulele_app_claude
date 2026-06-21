# 真实音频依赖研究 Spike (REAL_AUDIO_DEPENDENCY_SPIKE)

> 本文档是 ukulele_app **真实录音与回放 MVP 阶段**的依赖研究 / Spike 报告。
>
> ⚠️ 本文档**只做依赖调研**，**不修改 `pubspec.yaml` / `pubspec.lock` / AndroidManifest.xml / Drift schema / Dart 生产代码 / 测试代码**。
> ⚠️ 本文档**不**新增依赖、**不**申请 `RECORD_AUDIO`、**不**接入真实麦克风、**不**实现录音 / 播放、**不**运行 build_runner、不构建 APK / AAB、不 push、不创建 Tag。
> ⚠️ 本文档**不**代表依赖已添加；所有版本号仅作为"研究候选"，最终 `pubspec.yaml` 变更必须由 GPT 首席架构师出具独立 Prompt（建议 T027 起，按 T027 / T029 / T030 拆分）后启动。
> ⚠️ 本文档不记录 `key.properties` 内容 / 密码 / keystore 内容 / 用户目录 keystore 绝对路径。

## Document Status

| 字段 | 值 |
| --- | --- |
| Task ID | `T026_REAL_AUDIO_DEPENDENCY_RESEARCH_SPIKE` |
| 基线 Commit | `9848d31` |
| Release Tag | `v1.0.0-release` → `703d2aa` |
| 当前版本 | `1.0.0+2`（versionName=`1.0.0`, versionCode=`2`） |
| 状态 | **依赖研究完成，未实现** |
| 是否修改生产代码 | **否** |
| 是否新增依赖 | **否** |
| 是否修改 `pubspec.yaml` | **否** |
| 是否修改 `AndroidManifest.xml` | **否** |
| 是否申请 `RECORD_AUDIO` | **否** |
| 是否接入真实麦克风 | **否** |
| 是否运行 `flutter analyze` | **是**（仅验证既有基线） |
| 是否运行 `flutter test` | **是**（仅验证既有基线） |
| 是否运行 build_runner | **否** |
| 是否构建 APK / AAB | **否** |
| 是否 push | **否** |
| 是否创建 Tag | **否** |
| 本文档是否代表依赖已添加 | **否**（仅研究结论） |
| 下一步建议 | `T027_PERMISSION_AND_MANIFEST_DESIGN`（如 Spike 通过） |

## 1. Current Project Baseline

### 1.1 工具链版本（实测）

| 项 | 值 | 来源 |
| --- | --- | --- |
| Flutter | `3.44.2`（stable，channel stable，Framework revision `c9a6c48423`，2026-06-10） | `flutter --version` 实测 |
| Dart | `3.12.2`（stable，2026-06-09） | `dart --version` 实测 |
| `pubspec.yaml` `environment.sdk` | `^3.5.4` | `pubspec.yaml` 第 22 行 |
| `pubspec.yaml` `environment.flutter` | **未声明** | `pubspec.yaml`（Dart 3.5.4 隐含支持 Flutter 3.24+；实测 Flutter 3.44.2 满足） |

> ⚠️ `pubspec.yaml` 当前**未声明** `environment.flutter` 字段，意味着采用 SDK 隐含约束。真实音频阶段如需锁定 Flutter 版本，需在 T027 / T029 / T030 任务中评估是否补充该字段。

### 1.2 Android 平台配置（来自既有 Release 产物 + `TECH_STACK.md`）

| 项 | 值 | 来源 |
| --- | --- | --- |
| `minSdk` | `24` | `RELEASE_ARTIFACTS.md` §1（`aapt dump badging sdkVersion` = 24） |
| `targetSdk` | `36` | `RELEASE_ARTIFACTS.md` §1 |
| `compileSdk` | `36` | `RELEASE_ARTIFACTS.md` §1 |
| native-code ABI | `arm64-v8a`, `armeabi-v7a`, `x86_64` | `RELEASE_ARTIFACTS.md` §1 |
| AGP / Gradle / Kotlin | 既有：Gradle 8.7 / AGP 8.6.0 / Kotlin Gradle Plugin 2.1.0 / JDK 17 | `TECH_DEBT.md` TD-005 |

> 注意：`TECH_STACK.md` §7.1 既有候选是 `minSdk = 23` / `targetSdk = 34-35` / `compileSdk ≥ 33`；T021 阶段实际落地值 `minSdk = 24` / `targetSdk = 36` / `compileSdk = 36`，本文档以**实测值**为准。

### 1.3 现有 `pubspec.yaml` 依赖（截至 `9848d31`）

```yaml
dependencies:
  flutter: { sdk: flutter }
  cupertino_icons: ^1.0.8
  flutter_riverpod: ^3.3.2
  riverpod_annotation: ^4.0.3
  go_router: ^17.3.0
  drift: ^2.34.0
  path_provider: ^2.1.6
  path: ^1.9.1
  freezed_annotation: ^3.1.0
  json_annotation: ^4.12.0
  intl: ^0.20.2
  uuid: ^4.5.3

dev_dependencies:
  flutter_test: { sdk: flutter }
  flutter_lints: ^6.0.0
  build_runner: ^2.15.0
  riverpod_generator: ^4.0.4
  drift_dev: ^2.34.0
  freezed: ^3.2.6-dev.1
  json_serializable: ^6.14.0
```

### 1.4 关键事实

| 事实 | 值 |
| --- | --- |
| `path_provider` 是否已引入 | **是**（`^2.1.6`） |
| `record` / `just_audio` / `permission_handler` / `audio_session` / `audioplayers` / `flutter_sound` 是否已引入 | **否**（`pubspec.yaml` 不含） |
| `RECORD_AUDIO` 权限是否声明 | **否**（`aapt dump permissions` 仅含 `com.yupi.ukulele.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`） |
| `INTERNET` 权限是否声明 | **否** |
| 当前是否为模拟录音 | **是**（`RecordingPracticeController` 硬编码 `audioFilePath: null`，见 `TECH_DEBT.md` TD-007） |
| 当前 `flutter test` 通过数 | `407`（T024 阶段锁定，本任务实测复核通过） |
| 当前 `flutter analyze` 结果 | `No issues found!`（本任务实测复核通过） |
| 当前工作树是否 clean | **Yes** |
| HEAD 是否为 `9848d31` | **Yes** |
| `v0.1.0-mvp` 是否仍指向 `d49ce4b` | **Yes** |
| `v1.0.0-release` 是否仍指向 `703d2aa` | **Yes** |
| `7038d2aa` 是否在仓库出现 | **否**（已通过 `git grep "7038d2aa"` 验证，0 命中） |

## 2. Research Sources

> 本节列出每个候选依赖的查询来源、是否成功、最新稳定版本与已知限制。
> 所有未通过 Context7 / pub.dev 实际查询成功的项目均显式标注，不得伪造证据。

### 2.1 Context7 查询结果总览

| 候选 | Context7 Library ID | 查询结果 | 是否成功 | 备注 |
| --- | --- | --- | --- | --- |
| `record` | `/llfbandit/record` + `/websites/pub_dev_packages_record` | 双向验证：master 分支 `record/pubspec.yaml` version = `7.0.1`；pub.dev 当前稳定 = `7.1.0`；README 确认 `minSdk = 23`；amrNb/amrWb 需要 `minSdk = 26`、Opus 需要 `minSdk = 29`；当前项目 `minSdk = 24` 满足 AAC-LC 但不满足 Opus | **成功** | 已有上下文清晰 |
| `just_audio` | `/ryanheise/just_audio` + `/websites/pub_dev_just_audio_0_10_5` | pub.dev 当前稳定 = `^0.10.5`；CHANGELOG 确认 0.10.0 引入新 playlist API 并 bump min Flutter = 3.27.0、AGP = 8.5.2；本项目 Flutter 3.44.2 / AGP 8.6.0 满足；README 显示 `INTERNET` 权限用于在线播放，本项目仅播放本地 m4a，**不**声明 `INTERNET` | **成功** | 已有上下文清晰 |
| `permission_handler` | `/baseflow/flutter-permission-handler` + `/websites/pub_dev_permission_handler` | pub.dev 当前稳定 = `^12.0.3`；README 确认自 3.1.0 起要求 `compileSdk ≥ 33`，推荐 `compileSdk = 35`；当前项目 `compileSdk = 36` 已满足；`Permission.microphone` 是受支持常量；`isPermanentlyDenied` + `openAppSettings()` 可处理永久拒绝 | **成功** | 已有上下文清晰 |
| `path_provider` | `/websites/pub_dev_path_provider` | pub.dev 当前稳定 = `^2.1.6`（5 天前发布）；`getApplicationDocumentsDirectory()` 是推荐 API；**已**在当前 `pubspec.yaml` 引入 | **成功** | 已存在 |
| `audioplayers` | `/bluefireteam/audioplayers` | pub.dev 当前稳定 = `^6.7.1`；feature parity table 确认 `audioplayers_android` 是默认 Android 实现，ExoPlayer 版可选；Feature parity table 标注 `minSdk 23` 是 team 保证的最低测试 SDK | **成功** | 既有决策排除；只做对照参考 |
| `flutter_sound` | `/canardoux/flutter_sound` | pub.dev 当前稳定 = `^9.30.0`；README 标注 `minSdk = 21`；兼容 Flutter ≥ 3.3 / Dart ≥ 3.7；功能完整（录音 + 播放 + 波形），但包体积较大 | **成功** | 既有决策不首选；只做对照参考 |
| `audio_session` | `/ryanheise/audio_session` | pub.dev 当前稳定 = `^0.2.3`（3 个月前发布）；同作者为 `just_audio` 作者 ryanheise；用于 iOS AVAudioSession / Android AudioManager 音频焦点管理；MVP 场景可暂不引入 | **成功** | 已有上下文清晰 |

### 2.2 pub.dev 交叉验证（WebFetch）

每个候选在 WebFetch 上再次独立验证最新稳定版本与平台要求：

| 候选 | WebFetch 结果 | 与 Context7 一致 | 备注 |
| --- | --- | --- | --- |
| `record` | 最新 `7.1.0`；minSdk = 23 | **一致** | 同一天 `master` 仓库显示 7.0.1、pub.dev 显示 7.1.0；以 pub.dev 为准 |
| `just_audio` | 最新 `^0.10.5` | **一致** | — |
| `permission_handler` | 最新 `^12.0.3`；compileSdk 推荐 `35` | **一致** | — |
| `path_provider` | 最新 `^2.1.6`（5 天前） | **一致** | — |
| `audioplayers` | 最新 `^6.7.1` | **一致** | — |
| `flutter_sound` | 最新 `^9.30.0`；minSdk = 21 | **一致** | — |
| `audio_session` | 最新 `^0.2.3`（3 个月前） | **一致** | — |

### 2.3 查询限制（透明披露）

| 限制 | 说明 |
| --- | --- |
| Context7 离线缓存 | Context7 返回的内容基于其索引时间点的快照，可能滞后于最新发布；本任务同时用 WebFetch 在 pub.dev 做交叉验证 |
| 真实设备 Spike | 本任务**未**在真机上启动任何依赖进行实际录音 / 播放验证；所有候选 API 行为均依赖 Context7 / pub.dev 文档 + 既有 MVP `RecordingPracticeController` 经验 |
| 真机 ROM 兼容性 | 本任务**未**覆盖 HUAWEI CDY-AN90 / 小米 / OPPO / vivo 等国产 ROM 的兼容性；T036 真机验收必须由用户本人在真机上完成 |
| CI 自动化 | 本项目当前**不**接入 CI（详见 `MULTI_AGENT_WORKFLOW.md` §0.3 Level 3 暂不实现）；所有 Spike 验证均在 Windows 本地命令行完成 |
| Windows 开发环境 | 真实音频阶段**不**在 Windows 开发环境中验证录音 / 播放；Flutter desktop 音频插件能力不在本任务范围 |

## 3. Candidate Evaluation Table

> 候选评估遵循 MVP 简单性、Android 优先、离线本地、测试可控、依赖风险、扩展性六大原则。

### 3.1 record（录音）

| 项 | 内容 |
| --- | --- |
| Purpose | Android / iOS 麦克风录音（AAC-LC m4a / WAV / PCM 流 / Opus / FLAC） |
| Current candidate version / range | `^7.1.0`（pub.dev 最新稳定；Context7 同时确认 `master` 分支显示 `7.0.1`；以 pub.dev `7.1.0` 为推荐基线） |
| Pros | 与既有 `TECH_STACK.md` §6.1 / `REAL_AUDIO_MVP_SDD.md` §5.1 候选决策一致；活跃维护；`isEncoderSupported()` 可在 T029 实现时校验当前设备是否支持 AAC-LC；支持 PCM 流（`AudioEncoder.pcm16bits`）为调音器 / 后续 AI 评分预留；Context7 README 提供 `hasPermission()` + `start()` + `stop()` + `cancel()` 完整生命周期 |
| Risks | 7.x `AudioEncoder.aacLc` 重命名（4.x 引入，向前不兼容）；必须通过 `isEncoderSupported()` 在 T029 启动时校验当前设备是否支持 AAC-LC；record 内部状态枚举 `RecordState { pause, record, stop }`，与本项目 `RecordingState` 设计层枚举映射由 Controller 负责；与 `permission_handler` 必须协同（record 自带 `hasPermission()` 但应使用项目统一的 `PermissionService` 入口） |
| Android requirements | `minSdk = 23`（满足）；AAC-LC 在所有 Android 6.0+ 设备可用；`MODIFY_AUDIO_SETTINGS` 仅当蓝牙耳机路由需要；无需 ProGuard R8 规则 |
| iOS requirements | `minSdk = 12.0`；Info.plist 必须加 `NSMicrophoneUsageDescription`（已由 `REAL_AUDIO_MVP_SDD.md` §3.5 预留文案） |
| Extra config | AndroidManifest.xml 三处清单（main / debug / profile）必须含 `<uses-permission android:name="android.permission.RECORD_AUDIO" />`；可选 `MODIFY_AUDIO_SETTINGS`（T027 决定是否启用） |
| Test impact | 单元测试必须 mock `record` 接口（推荐 `MockAudioRecorderService` 由 T035 实现）；`AudioRecorderService` 必须抽象成接口，测试中可替换为 `FakeAudioRecorderService`；自动测试**不**触发真实麦克风（与 `REAL_AUDIO_MVP_TDD.md` §5 Test Gaps 一致） |
| MVP recommendation | **Recommended for MVP** |
| Next action | T029 由 `04-audio-engineer` 在隔离 spike（`record_hello_world` 空壳工程）实测 `AudioEncoder.aacLc` + `sampleRate = 44100` + `bitRate = 128000` 输出 m4a 实际参数；T030 同理 |

### 3.2 just_audio（播放）

| 项 | 内容 |
| --- | --- |
| Purpose | 本地音频播放（M4A / MP3 / WAV / 流媒体）；本项目**仅**使用本地文件播放能力 |
| Current candidate version / range | `^0.10.5`（pub.dev 最新稳定；CHANGELOG 确认 0.10.0 bump Flutter ≥ 3.27.0、AGP ≥ 8.5.2） |
| Pros | 与既有 `TECH_STACK.md` §6.1 / `REAL_AUDIO_MVP_SDD.md` §5.3 候选决策一致；README 推荐 M4A 作为"可嵌入精确 seek table"的格式（与 SDD §4.11 音频格式决策一致）；支持 file:// / asset:// / https:// 多源；本项目**仅**使用 file:// 路径播放本地 m4a |
| Risks | README 提到 `INTERNET` 用于在线播放（本项目不声明 `INTERNET`）；MVP 阶段**不**实现 seek；0.10.x playlist API 与 LoopingAudioSource 已弃用（项目仅单文件播放，无影响）；若多个插件使用不同 ExoPlayer 版本需在 `android/app/build.gradle` 显式指定 `exoplayer_version`（项目当前仅 `just_audio` 使用 ExoPlayer，无冲突） |
| Android requirements | 无显式 minSdk 限制（依赖 ExoPlayer 库）；本项目 `minSdk = 24` 满足；无需 ProGuard R8 规则；无需 AndroidManifest 权限（仅播放本地文件） |
| iOS requirements | `AVAudioSession` 在 iOS 端自动管理；无需额外 Info.plist 权限（仅播放不录音） |
| Extra config | 无（仅播放本地文件无需 INTERNET、无需 cleartext traffic、无需 network security config） |
| Test impact | 单元测试必须 mock `AudioPlayer` 接口（推荐 `FakeAudioPlaybackService`）；自动测试**不**触发真实播放；真机 MA-07 / MA-11 由 T036 用户确认音质 |
| MVP recommendation | **Recommended for MVP** |
| Next action | T030 由 `04-audio-engineer` 在隔离 spike 实测 `setFilePath()` + `play()` + `pause()` + `stop()` 完整生命周期；与 record 7.1.0 输出 m4a 配套验证 |

### 3.3 audioplayers（播放备选）

| 项 | 内容 |
| --- | --- |
| Purpose | 轻量音频播放（多源 / 多实例） |
| Current candidate version / range | `^6.7.1`（pub.dev 最新稳定；Android 通过 `audioplayers_android` 默认实现，可选 ExoPlayer 版 `audioplayers_android_exo`） |
| Pros | 社区成熟；多实例播放能力（项目仅单实例，无收益）；API 与 `just_audio` 类似 |
| Risks | **既有决策排除**：`TECH_STACK.md` §6.1 / §10 + `REAL_AUDIO_MVP_SDD.md` §5.4 明确不引入 `audioplayers`；引入需 Chief Architect 推翻既有 ADR |
| Android requirements | `minSdk ≥ 23`（满足） |
| iOS requirements | 无 |
| Extra config | 同 `just_audio` |
| Test impact | 同 `just_audio`（但仅作为对照参考） |
| MVP recommendation | **Not recommended for MVP**（既有决策排除） |
| Next action | 无；仅在 `just_audio` 不可用时由 GPT 首席架构师重新评估 |

### 3.4 flutter_sound（录音/播放合并备选）

| 项 | 内容 |
| --- | --- |
| Purpose | 麦克风录音 + 播放 + 波形可视化；底层封装 native API |
| Current candidate version / range | `^9.30.0`（pub.dev 最新稳定；要求 Flutter ≥ 3.3 / Dart ≥ 3.7，本项目满足） |
| Pros | 功能完整；支持波形可视化；`isEncoderSupported()` 同样可用；`Codec.aacADTS` / Opus / FLAC 等多格式 |
| Risks | **与 `record` 选型冲突**：`REAL_AUDIO_MVP_SDD.md` §5.2 明确"必须二选一"；既有 `TECH_STACK.md` §6.1 候选是 `record`；包体积较大（多个 native 实现 + Dart 包装层）；`flutter pub` 依赖树复杂度更高 |
| Android requirements | `minSdk = 21`（满足） |
| iOS requirements | 无显式限制 |
| Extra config | 与 `record` 类似：需 `RECORD_AUDIO` 权限 + iOS `NSMicrophoneUsageDescription` |
| Test impact | 同 `record` / `just_audio` |
| MVP recommendation | **Not recommended for MVP**（既有决策排除；仅作为 `record` 不可用时的备选） |
| Next action | 无；仅在 `record` 与 Flutter SDK 3.44.2 / Dart 3.12.2 / Android API 24-36 兼容性失败时由 GPT 首席架构师重新评估 |

### 3.5 permission_handler（运行时权限）

| 项 | 内容 |
| --- | --- |
| Purpose | Android / iOS / 跨平台运行时权限申请与状态查询 |
| Current candidate version / range | `^12.0.3`（pub.dev 最新稳定） |
| Pros | 与既有 `TECH_STACK.md` §6.1 / `REAL_AUDIO_MVP_SDD.md` §5.5 候选决策一致；支持 `Permission.microphone` 常量；`onGrantedCallback` / `onDeniedCallback` / `onPermanentlyDeniedCallback` 回调链；`openAppSettings()` 处理永久拒绝；3.1.0+ 要求 `compileSdk ≥ 33`（本项目 `compileSdk = 36` 满足）；无需 `coreLibraryDesugaring`；无需 ProGuard R8 规则 |
| Risks | 12.x 较 11.x API 变化（建议 T027 任务由 `04-audio-engineer` 在隔离 spike 中实测 `Permission.microphone.request()` + 永久拒绝路径）；`Permission.storage` 在 Android 13+ 已弃用（本项目不使用外部存储，无影响）；`Permission.audio` 仅用于 Android 13+ 媒体权限（本项目不读取媒体库，仅使用麦克风，无影响） |
| Android requirements | `compileSdk ≥ 33`（推荐 35+；本项目 `compileSdk = 36` 已满足）；无显式 minSdk 限制 |
| iOS requirements | 无显式限制 |
| Extra config | AndroidManifest.xml 三处清单（main / debug / profile）必须含 `<uses-permission android:name="android.permission.RECORD_AUDIO" />`（与 `record` 共用，由 T027 统一处理） |
| Test impact | 单元测试必须 mock `permission_handler` 接口（推荐 `FakePermissionService`）；自动测试**不**触发真实系统权限弹窗；`Permission.microphone.request()` 的 denied / permanentlyDenied / restricted / granted / limited 五种状态由 mock 覆盖（与 `REAL_AUDIO_MVP_TDD.md` §2.1 TC-P01~P05 一致） |
| MVP recommendation | **Recommended for MVP** |
| Next action | T027 由 `04-audio-engineer` 在隔离 spike 实测 `Permission.microphone` 在 Android 10 / SDK 29（HUAWEI CDY-AN90）的弹窗行为 + 永久拒绝路径；T033 由 `03-mobile-ui-engineer` 在权限文案上集成 |

### 3.6 path_provider（App 私有目录）

| 项 | 内容 |
| --- | --- |
| Purpose | 跨平台获取 App 私有目录（`getApplicationDocumentsDirectory()` 等） |
| Current candidate version / range | `^2.1.6`（pub.dev 最新稳定；**已**在当前 `pubspec.yaml` 引入） |
| Pros | 与既有 `TECH_STACK.md` §6.1 / `REAL_AUDIO_MVP_SDD.md` §5.6 候选决策一致；Flutter 官方包（`flutter.dev` publisher）；`getApplicationDocumentsDirectory()` 是推荐 API；`MissingPlatformDirectoryException` 异常语义明确；卸载 App 时 Android 自动清除（与 SDD §3.7 一致） |
| Risks | 与既有 Drift 数据库路径冲突风险（数据库默认在 `getApplicationDocumentsDirectory()` 下子目录，音频文件目录若与数据库目录冲突可能影响备份；最终路径命名由 T028 决定） |
| Android requirements | 无（基础 Flutter 平台通道） |
| iOS requirements | 无 |
| Extra config | 无 |
| Test impact | 测试中 mock `getApplicationDocumentsDirectory()` 返回 `Directory.systemTemp.createTempSync()`；`AudioFileStorageService` 抽象成接口（与 `REAL_AUDIO_MVP_TDD.md` §1.1 Repository tests 一致） |
| MVP recommendation | **Recommended for MVP**（已存在） |
| Next action | T028 由 `06-local-data-engineer` 实现 `AudioFileStorageService` 并决定路径命名（候选：`<docs>/recordings/<yyyy-MM-dd>/<recordId>.m4a`） |

### 3.7 audio_session（音频焦点管理，可选）

| 项 | 内容 |
| --- | --- |
| Purpose | iOS `AVAudioSession` + Android `AudioManager` 音频焦点与路由管理；与 `just_audio` 同作者 ryanheise |
| Current candidate version / range | `^0.2.3`（pub.dev 最新稳定，3 个月前发布） |
| Pros | 处理"录音时其他 App 音频暂停" / "电话来电时暂停录音" / "蓝牙耳机切换"等场景；与 `just_audio` 集成度高；提供 `AudioSessionConfiguration.music()` / `.speech()` 等预设 |
| Risks | 项目 MVP 阶段不引入：① 当前 `RecordingState` 已包含 `appPaused` / 来电中断处理（详见 `REAL_AUDIO_MVP_SDD.md` §9）；② 蓝牙耳机切换属 Test Gaps（`REAL_AUDIO_MVP_TDD.md` §5）；③ 引入增加依赖与文档维护成本；④ MVP 用户基线为单台真机，国产 ROM 兼容性未验证 |
| Android requirements | 无显式限制；通过 `AndroidAudioManager` 包装 |
| iOS requirements | iOS 13+ 推荐 |
| Extra config | iOS 端需要在 `Info.plist` 配合（具体字段由 iOS 阶段决定） |
| Test impact | 与 `just_audio` / `record` 集成后增加 mock 复杂度 |
| MVP recommendation | **Recommended as fallback**（**不**进入 MVP 主路径；如 T036 真机验收发现音频焦点冲突 / 来电中断问题，再由 GPT 首席架构师评估是否引入） |
| Next action | T036 真机验收后由 GPT 首席架构师决定是否引入；本任务**不**写入 `pubspec.yaml` |

### 3.8 flutter_sound vs record vs audio_session 关系图

```text
录音链路:
  Controller → AudioRecorderService → record 7.1.0（首选）
                                      └─ flutter_sound 9.30.0（备选，禁用）
  Controller → PermissionService    → permission_handler 12.0.3

回放链路:
  Controller → AudioPlaybackService → just_audio 0.10.5
                  └─ audio_session 0.2.3（可选，仅当 T036 验证需要时）

存储链路:
  Controller → AudioFileStorageService → path_provider 2.1.6（已存在）
                                       → dart:io File API
```

## 4. Recommended Dependency Direction

> 本节给出推荐方向，但**不**修改 `pubspec.yaml`；最终 `pubspec.yaml` 变更必须由 GPT 首席架构师出具独立 Prompt 后启动。

### 4.1 MVP 推荐组合

| 用途 | 候选 | 推荐版本范围 | 推荐度 | 理由 |
| --- | --- | --- | --- | --- |
| 录音 | `record` | `^7.1.0` | **首选** | 与既有决策一致；minSdk 满足；活跃维护；支持 AAC-LC；可输出 PCM 流 |
| 播放 | `just_audio` | `^0.10.5` | **首选** | 与既有决策一致；M4A seek table 嵌入；本地文件播放无需 INTERNET |
| 运行时权限 | `permission_handler` | `^12.0.3` | **首选** | 与既有决策一致；`Permission.microphone` 支持；永久拒绝路径完整；compileSdk 满足 |
| 文件路径 | `path_provider` | `^2.1.6` | **首选** | 已存在；Flutter 官方包；`getApplicationDocumentsDirectory()` 语义清晰 |
| 音频焦点 | `audio_session` | `^0.2.3` | **暂不引入** | MVP 不需要；T036 真机验收后按需评估 |

### 4.2 推荐方向的关键理由

| 原则 | 对应候选组合如何满足 |
| --- | --- |
| **MVP 简单性** | 4 个候选均为既有 `TECH_STACK.md` / `REAL_AUDIO_MVP_SDD.md` 决策，不引入新方向；不引入 `audio_session` 等可选项 |
| **Android 优先** | 4 个候选均已验证 `minSdk = 24` / `compileSdk = 36` 兼容；iOS 预留文案已在 SDD §3.5 落盘 |
| **离线本地** | `just_audio` 本项目仅使用 file:// 路径；`record` 输出本地 m4a；`path_provider` 仅访问 App 私有目录；**不**引入 `INTERNET` 权限 |
| **测试可控** | 4 个候选均有官方支持 / mock 推荐做法；`AudioRecorderService` / `AudioPlaybackService` / `PermissionService` 全部抽象成接口；自动测试**不**触发真实麦克风 |
| **依赖风险** | 4 个候选均为活跃维护的官方 / 主流包；record 7.1.0 是 10 天前发布，permission_handler 12.0.3 / just_audio 0.10.5 / path_provider 2.1.6 均为近 3-5 天 / 3 个月内稳定版 |
| **未来扩展性** | `record` PCM 流为调音器 / 后续 AI 评分预留；`just_audio` 支持流媒体（未来如需音频内容可扩展）；`audio_session` 保留为"如 T036 真机需要"的后备方案 |

### 4.3 备选 / 排除组合

| 用途 | 备选 | 决策 |
| --- | --- | --- |
| 录音 | `flutter_sound` 9.30.0 | **排除**（既有决策锁定 `record`；仅作为对照参考） |
| 播放 | `audioplayers` 6.7.1 | **排除**（既有决策锁定 `just_audio`） |
| 录音合并 | `flutter_sound` 同时承担录音 + 播放 | **排除**（与 `record` + `just_audio` 双选型冲突） |

## 5. Permission Impact

### 5.1 依赖本身 vs 权限声明

| 候选 | 引入依赖是否自动声明 `RECORD_AUDIO` | 是否需要修改 AndroidManifest.xml |
| --- | --- | --- |
| `record` 7.1.0 | **否**（仅在 Android 端通过平台插件加载 native 代码；权限由开发者显式声明） | **是**（T027 任务在 `android/app/src/main/AndroidManifest.xml` + `debug` + `profile` 三处清单加入 `<uses-permission android:name="android.permission.RECORD_AUDIO" />`） |
| `just_audio` 0.10.5 | **否** | **否**（仅播放本地 m4a 文件无需权限） |
| `permission_handler` 12.0.3 | **否** | **否**（仅查询 / 申请权限，不自动声明） |
| `path_provider` 2.1.6 | **否** | **否**（无权限需求） |
| `audio_session` 0.2.3 | **否** | **否** |

> **结论**：引入依赖**不等于**声明权限；`RECORD_AUDIO` 必须在 T027 任务中由 Primary Agent 显式写入 AndroidManifest.xml 三处清单（沿用既有 `TECH_STACK.md` §7.4 检查清单）。

### 5.2 运行时权限申请时机

| 时机 | 行为 |
| --- | --- |
| App 启动 | **不**触发任何权限弹窗（与既有 MVP 行为一致） |
| 首页 / 今日练习 / 设置页 | **不**触发任何权限弹窗 |
| 调音器页面（`/tuner`） | **不**触发麦克风权限弹窗（既有 MVP 设计：仅手动调音辅助） |
| 录音页（`/recording`）首次进入 | 显示 "需要麦克风权限" 状态 + "申请权限并开始" 按钮 |
| 用户首次点击 "开始真实录音" | **触发** `Permission.microphone.request()` 弹窗（系统默认，不可定制） |
| 用户拒绝（一次性） | 显示 "重新申请权限" 按钮，App 内可重试 |
| 用户永久拒绝（勾选"不再询问"） | 显示 "前往系统设置" 按钮，调用 `openAppSettings()` |

### 5.3 iOS Info.plist 预留文案（不在本任务范围）

> iOS 适配不在 T026-T037 验收范围，仅预留文案。

```xml
<!-- ios/Runner/Info.plist 待 iOS 阶段补充 -->
<key>NSMicrophoneUsageDescription</key>
<string>ukulele_app 需要使用麦克风录制你的练习音频；音频仅保存在本机 App 私有目录，不会上传到任何服务器。</string>
```

> 此文案已在 `REAL_AUDIO_MVP_SDD.md` §3.5 落盘；T026 不重复声明。

### 5.4 无 INTERNET 原则保留

- 真实音频 MVP **不得**声明 `android.permission.INTERNET`；
- `just_audio` 0.10.5 README 提到 `INTERNET` 用于在线播放；本项目**仅**使用 `setFilePath()` 播放本地 m4a，**不**声明 `INTERNET`；
- `record` 7.1.0 不引入联网能力；
- `permission_handler` 12.0.3 不引入联网能力；
- 真实音频阶段**不**修改"无 INTERNET"原则（与 `REAL_AUDIO_MVP_SDD.md` §3.3 一致）。

### 5.5 隐私政策更新

| 时机 | 任务 |
| --- | --- |
| T033 UI 文案 | 更新 `PrivacyNoticePage` 文案，加入"麦克风权限用途 / 录音本地存储 / 不上传"三段（与 `REAL_AUDIO_MVP_SDD.md` §3.6 + `TECH_DEBT.md` TD-012 一致） |
| T037 Release 文档收口 | 同步 `docs/PRD.md` §13.3（如有需要） |

### 5.6 真实音频阶段合规清单

| 项 | 状态 | 来源 |
| --- | --- | --- |
| 不读取 `android/key.properties` 内容 | Yes（本任务严格遵守） | 本任务 |
| 不记录密码 / keystore 内容 / 用户目录 keystore 绝对路径 | Yes | 本任务 |
| 不申请 `RECORD_AUDIO` | Yes（仅研究，未实现） | 本任务 |
| 不申请 `INTERNET` | Yes | 本任务 |
| 不声称真实录音已实现 | Yes（本文档明确"未实现"） | 本任务 |
| 不声称麦克风权限已加入 | Yes | 本任务 |
| 不声称应用商店已提交 | Yes | 本任务 |

## 6. Build / Platform Risk

### 6.1 Gradle / AGP / Kotlin

| 风险 | 评估 | 缓解 |
| --- | --- | --- |
| AGP 8.6.0 与 `just_audio` 0.10.x（0.10.0 bump AGP ≥ 8.5.2）兼容性 | **低风险**（本项目 AGP 8.6.0 满足） | 无需缓解 |
| Kotlin Gradle Plugin 2.1.0 与 `permission_handler` 12.x | **低风险**（Kotlin 2.1.0 与 Java 17 兼容） | 无需缓解 |
| ExoPlayer 版本冲突（`just_audio` 内部） | **极低风险**（项目当前仅 `just_audio` 使用 ExoPlayer） | 如未来引入其他 ExoPlayer 依赖，由 `02-flutter-architect` 评估是否显式指定 `exoplayer_version` |
| Gradle 8.7 与 record 7.1.0 / permission_handler 12.0.3 | **低风险** | 无需缓解 |
| AndroidX / Jetifier | `permission_handler` 12.0.3 README 强调需 `android.useAndroidX=true` 与 `android.enableJetifier=true` | T027 任务执行前 `02-flutter-architect` 必须复核 `android/gradle.properties` 当前设置 |

### 6.2 Android minSdk 风险

| 风险 | 评估 | 缓解 |
| --- | --- | --- |
| `record` 7.1.0 `minSdk = 23` vs 当前 `minSdk = 24` | **无风险**（当前 `minSdk = 24` 满足） | 无 |
| `permission_handler` 12.0.3 推荐 `compileSdk = 35` vs 当前 `compileSdk = 36` | **无风险**（满足） | 无 |
| `just_audio` 0.10.5 无显式 minSdk 限制（依赖 ExoPlayer） | **无风险** | 无 |
| `flutter_sound` 9.30.0 `minSdk = 21` vs 当前 `minSdk = 24` | **无风险**（本任务不引入 flutter_sound） | 不适用 |
| `path_provider` 2.1.6 无 minSdk 限制 | **无风险** | 无 |

### 6.3 Java / JDK 风险

| 风险 | 评估 | 缓解 |
| --- | --- | --- |
| 当前项目使用 JDK 17 | **低风险**（record 7.1.0 / just_audio 0.10.5 / permission_handler 12.0.3 均支持 JDK 17） | 无 |
| `flutter` 3.44.2 自带 JDK 17 检测 | **低风险** | 无 |

### 6.4 Native Plugin 风险

| 风险 | 评估 | 缓解 |
| --- | --- | --- |
| `record` 7.1.0 Android 端使用 Android `MediaRecorder` API | **低风险** | T029 由 `04-audio-engineer` 在隔离 spike 中实测 |
| `just_audio` 0.10.5 Android 端使用 ExoPlayer（Media3） | **低风险** | T030 由 `04-audio-engineer` 在隔离 spike 中实测 |
| `permission_handler` 12.0.3 Android 端使用 `androidx.core.content.PermissionChecker` | **低风险** | 无 |
| `audio_session` 0.2.3 Android 端使用 `AudioManager` | **低风险**（暂不引入） | 不适用 |

### 6.5 R8 / ProGuard 风险

| 风险 | 评估 | 缓解 |
| --- | --- | --- |
| `record` 7.1.0 是否需要 ProGuard R8 规则 | pub.dev 与 README 均未要求 | T029 任务验证 release build 是否需要 `proguard-rules.pro` 追加 `-keep class com.llfbandit.record.** { *; }` |
| `just_audio` 0.10.5 是否需要 ProGuard R8 规则 | pub.dev 与 README 均未要求 | 同上验证 |
| `permission_handler` 12.0.3 是否需要 ProGuard R8 规则 | pub.dev 与 README 均未要求 | 同上验证 |
| `path_provider` 2.1.6 | 无需 | 无 |

> **保守策略**：T029 / T030 任务在 release 构建时如发现 R8 报错（如 native class 被裁剪），由 `02-flutter-architect` 评估是否在 `android/app/proguard-rules.pro` 追加 keep 规则。

### 6.6 iOS 编译风险

| 风险 | 评估 | 缓解 |
| --- | --- | --- |
| iOS Runner 配置不在 T026-T037 范围 | **不适用本任务** | iOS 阶段由独立任务处理 |
| Info.plist 缺失 `NSMicrophoneUsageDescription` | **不适用**（iOS 阶段处理） | 不适用 |

### 6.7 Windows 开发环境风险

| 风险 | 评估 | 缓解 |
| --- | --- | --- |
| 本地 Windows 环境无法验证 Android 录音 / 播放 | **不适用本任务** | 真机验收由 T036 用户在 HUAWEI CDY-AN90 完成 |
| Flutter desktop 音频插件能力 | **不适用本任务**（Android only MVP） | 不适用 |

### 6.8 CI / future automation 风险

| 风险 | 评估 | 缓解 |
| --- | --- | --- |
| 项目当前**不**接入 CI | **不适用本任务** | 真实音频阶段 CI 自动化由独立任务评估 |
| 依赖更新可能引入回归 | **低风险**（`flutter pub outdated` 由 T029 / T030 任务定期检查） | T029 / T030 任务在 `pubspec.yaml` 引入依赖后定期执行 `flutter pub outdated` |

## 7. Testing Impact

### 7.1 测试分层与依赖隔离

| 测试层 | 范围 | 依赖隔离策略 | 工具 |
| --- | --- | --- | --- |
| Pure unit tests | 路径生成规则 / 错误类型映射 / Provider 边界 | 不依赖 Flutter binding / 不调用 `record` / `just_audio` / `permission_handler` | `flutter_test`（纯 Dart VM） |
| Controller tests | `RecordingPracticeController` 状态机 / `PracticeRecordDetailController` 删除流程 | 通过 `ProviderContainer.overrides` 注入 `FakeAudioRecorderService` / `FakeAudioPlaybackService` / `FakePermissionService` | `flutter_test` + `ProviderContainer` |
| Repository tests | `PracticeRecordRepository` 写入校验 / Drift CRUD | Drift `NativeDatabase.memory()` + `InMemoryAudioFileStorageService` | `flutter_test` + Drift in-memory |
| Drift migration tests | `schemaVersion = 1 → 2` 迁移 | Drift `Migrator` | `flutter_test` + Drift `Migrator` |
| File storage tests | `AudioFileStorageService` 路径生成 / 存在性检查 / 删除 | `path_provider` mock → `Directory.systemTemp.createTempSync()` | `flutter_test` + mock |
| Permission behavior tests | `PermissionService` 状态映射 | mock `permission_handler` 接口（denied / permanentlyDenied / granted / restricted） | `flutter_test` + 自定义 mock |
| Widget tests | 录音页 / 详情页 UI 状态切换 | `ProviderScope.overrides` 注入 fake 服务 | `flutter_test` |
| Integration tests | 完整录音 → 保存 → 回放 → 删除流程 | **不**进入本阶段 CI；真机手动验收优先 | `integration_test`（可选） |
| Android real-device manual acceptance | 真机录音 / 权限 / 厂商 ROM 兼容 | 用户手动 + adb | 用户本人真机 |

### 7.2 真实麦克风隔离（关键边界）

> 自动测试**必须不**触发真实麦克风；真实音频输入质量 / 真实音频播放质量由 T036 真机用户验收。

| 测试场景 | 是否使用真实麦克风 | 是否使用真实播放 |
| --- | --- | --- |
| Pure unit tests | 否 | 否 |
| Controller tests | 否（fake service） | 否（fake service） |
| Repository tests | 否 | 否 |
| Drift migration tests | 否 | 否 |
| File storage tests | 否（临时目录） | 否 |
| Permission behavior tests | 否（mock permission_handler） | 否 |
| Widget tests | 否（fake service） | 否（fake service） |
| Integration tests（不进 CI） | **是**（dev 环境允许） | **是** |
| T036 真机验收（MA-05 / MA-07 / MA-11） | **是**（用户手动） | **是**（用户手动） |

### 7.3 T035 自动测试设计原则

- 30+ 自动化测试用例（详见 `REAL_AUDIO_MVP_TDD.md` §2 Test Matrix）；
- 每个用例**必须**通过 fake service 注入，**不**调用真实 `record` / `just_audio` / `permission_handler`；
- 真实设备 / 真实音频输入质量 / 来电中断 / 系统设置跳转等边界由 T036 真机验收（详见 `REAL_AUDIO_MVP_TDD.md` §3 Manual Acceptance Checklist 22 项 + §5 Test Gaps 9 项）；
- 测试失败**不**得 Commit（包括 `flutter analyze` 警告、`flutter test` 失败）；
- 测试数必须 ≥ 既有 407（基线 T024 锁定；T035 不得下降）。

### 7.4 回归矩阵（20 项）

完整 20 项回归矩阵详见 `REAL_AUDIO_MVP_TDD.md` §4 Regression Matrix。本任务**不**修改任何测试代码、不修改任何依赖，**不**影响既有 407 项测试；新增依赖后 T029 / T030 任务必须验证既有 407 项测试仍 100% 通过。

## 8. Decision

> 每个候选必须有明确 Decision。Decision 选项：
> - **Recommended for MVP**：进入 MVP 主路径；
> - **Recommended as fallback**：不进入 MVP 主路径，作为后备方案（如 T036 验证需要时启用）；
> - **Not recommended for MVP**：不进入 MVP（既有决策排除或风险过高）；
> - **Needs further validation**：需要进一步 Spike 验证。

| 候选 | Decision | 理由 |
| --- | --- | --- |
| `record` 7.1.0 | **Recommended for MVP** | 既有决策一致；minSdk 满足；活跃维护；与 `permission_handler` 协同路径清晰；T029 隔离 spike 验证 |
| `just_audio` 0.10.5 | **Recommended for MVP** | 既有决策一致；M4A seek table 嵌入；本地播放无需 INTERNET；T030 隔离 spike 验证 |
| `audioplayers` 6.7.1 | **Not recommended for MVP** | 既有决策明确排除（`TECH_STACK.md` §10） |
| `flutter_sound` 9.30.0 | **Not recommended for MVP** | 既有决策明确排除（与 `record` 选型冲突）；包体积较大；仅作对照参考 |
| `permission_handler` 12.0.3 | **Recommended for MVP** | 既有决策一致；`compileSdk = 36` 满足；永久拒绝路径完整；T027 隔离 spike 验证 |
| `path_provider` 2.1.6 | **Recommended for MVP** | 已存在；Flutter 官方包；`getApplicationDocumentsDirectory()` 语义清晰 |
| `audio_session` 0.2.3 | **Recommended as fallback**（**不**进入 MVP 主路径） | MVP 不需要；T036 真机验收后按需评估；保留作为音频焦点 / 来电中断后备方案 |

## 9. Follow-up Tasks

> 本节映射到 T027-T037。T026 不启动任何 T027+ 任务；下表仅为后续任务的依赖决策提供依据。

| 任务 ID | 任务名 | 与 T026 推荐的依赖关系 |
| --- | --- | --- |
| `T027_PERMISSION_AND_MANIFEST_DESIGN` | 权限与 Manifest 设计 | 引入 `permission_handler: ^12.0.3`；在 AndroidManifest.xml 三处清单加入 `RECORD_AUDIO`；不引入其他依赖 |
| `T028_AUDIO_FILE_STORAGE_SERVICE` | 音频文件存储服务 | 不引入新依赖（`path_provider` 已存在）；实现 `AudioFileStorageService` |
| `T029_REAL_RECORDER_SERVICE` | 真实录音服务 | 引入 `record: ^7.1.0`；实现 `AudioRecorderService` |
| `T030_REAL_PLAYBACK_SERVICE` | 真实回放服务 | 引入 `just_audio: ^0.10.5`；实现 `AudioPlaybackService` |
| `T031_RECORDING_CONTROLLER_REAL_AUDIO_STATE_MACHINE` | 录音 Controller 状态机 | 不引入新依赖；扩展既有 `RecordingPracticeController` |
| `T032_PRACTICE_RECORD_SCHEMA_MIGRATION` | Drift schema 迁移 | 不引入新依赖；`schemaVersion = 1 → 2` 迁移脚本 |
| `T033_UI_COPY_AND_PERMISSION_UX` | UI 文案与权限体验 | 不引入新依赖；更新 `PrivacyNoticePage` 文案 |
| `T034_DELETE_AND_FILE_CLEANUP_INTEGRATION` | 删除与文件清理整合 | 不引入新依赖 |
| `T035_AUTOMATED_TESTS` | 自动化测试 | 不引入新依赖；编写 fake service + Widget / Controller / Repository / Drift migration 测试 |
| `T036_ANDROID_REAL_DEVICE_AUDIO_ACCEPTANCE` | Android 真机录音验收 | 用户本人在 HUAWEI CDY-AN90 真机验收；**不**自动测试；如发现音频焦点 / 来电中断问题，由 GPT 首席架构师评估是否引入 `audio_session` |
| `T037_RELEASE_DOCS_UPDATE` | 真实音频阶段文档收口 | 不引入新依赖；新建 `REAL_AUDIO_MVP_ACCEPTANCE.md` + 更新台账 + 技术债 |

> **依赖引入节奏建议**：
> - T027（权限与 Manifest）→ 引入 `permission_handler: ^12.0.3`；
> - T028（存储服务）→ 不引入新依赖；
> - T029（录音服务）→ 引入 `record: ^7.1.0`；
> - T030（播放服务）→ 引入 `just_audio: ^0.10.5`；
> - 上述 4 个任务（T027 / T029 / T030 三个真正引入新依赖）**不**合并到同一 commit；每次依赖变更必须独立验证；
> - T036 真机验收后如需 `audio_session` → 由 GPT 首席架构师下发独立 Prompt（T036A？）。

## 10. References

- `docs/PRD.md` §6.6 / §6.7 / §10 / §11.4 / §13
- `docs/MVP_SCOPE.md` §2.1 / §2.2.1 / §6.6
- `docs/TECH_STACK.md` §6 / §7 / §10
- `docs/ARCHITECTURE.md` §3 / §5.3 / §7
- `docs/dev/REAL_AUDIO_MVP_SDD.md`：真实音频 MVP 软件设计文档
- `docs/dev/REAL_AUDIO_MVP_TDD.md`：真实音频 MVP 测试驱动开发计划
- `docs/dev/RELEASE_ACCEPTANCE.md`：Release 工程化验收基线
- `docs/dev/RELEASE_ARTIFACTS.md`：Release 产物元信息
- `docs/dev/RELEASE_DEVICE_ACCEPTANCE.md`：Release 真机验收基线
- `docs/dev/MVP_ACCEPTANCE.md`：MVP 验收基线
- `docs/dev/TASK_LEDGER.md`：任务台账
- `docs/dev/TECH_DEBT.md` TD-007 / TD-010 / TD-011 / TD-012
- `docs/dev/AGENT_ROUTING_MATRIX.md` §4.7 / §6
- `docs/dev/AGENT_REVIEW_TEMPLATE.md`：报告模板
- `docs/dev/AGENT_QUALITY_METRICS.md`
- `docs/MULTI_AGENT_WORKFLOW.md`
- `agents/04-audio-engineer.md` / `agents/02-flutter-architect.md` / `agents/06-local-data-engineer.md` / `agents/07-qa-reviewer.md` / `agents/08-compliance-reviewer.md`
- Context7 Library IDs（详见 §2.1）：
  - `/llfbandit/record`
  - `/websites/pub_dev_packages_record`
  - `/ryanheise/just_audio`
  - `/websites/pub_dev_just_audio_0_10_5`
  - `/baseflow/flutter-permission-handler`
  - `/websites/pub_dev_permission_handler`
  - `/websites/pub_dev_path_provider`
  - `/bluefireteam/audioplayers`
  - `/canardoux/flutter_sound`
  - `/ryanheise/audio_session`
- pub.dev WebFetch（详见 §2.2）：`https://pub.dev/packages/{record,just_audio,permission_handler,path_provider,audioplayers,flutter_sound,audio_session}`