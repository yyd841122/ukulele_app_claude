# ADR-011: Core Flutter Dependencies

## Status

**Accepted**

## Context

### Environment

- Flutter: **3.44.2** stable（2026-06-10）
- Dart: **3.12.2**
- Android SDK: 本机已配置
- 平台：**Android only**（iOS reserved）
- `minSdk = 23`（Android 6.0）
- `compileSdk` / `targetSdk` 由 Flutter Gradle 默认值决定（T006/T007 不再调整）

### Task Scope

T005 是 T004 创建 Flutter Android-only 工程空壳之后的第一个依赖配置任务。T005 任务范围严格限定为：

1. 添加 MVP 后续开发（T006-T014）所需的核心依赖；
2. 不实现任何业务功能代码；
3. 不创建路由、数据库表、调音器、录音、节拍器、练习记录；
4. 必须通过 `flutter pub get` 与 `flutter analyze`；
5. 必须新建一个 ADR 记录依赖版本决策。

### Historical Note

T005 初次尝试时由于 Flutter **3.24.5 / Dart 3.5.4** 与上游 TECH_STACK.md 中标注的 Riverpod 3.x / source_gen 2.x / analyzer 7.x 等依赖的 Dart SDK 约束冲突（这些依赖要求 Dart ≥ 3.6），版本解析失败。用户随后将本机 Flutter SDK 升级到 **3.44.2 / Dart 3.12.2**，并手动完成所有依赖的添加与 `flutter pub get` 验证。本 ADR 记录的是升级后的最终决策版本。

## Decision

### dependencies

| Package | Version | 用途 |
|---------|---------|------|
| flutter | sdk: flutter | Flutter SDK 绑定 |
| cupertino_icons | ^1.0.8 | Cupertino 风格图标（Flutter create 默认） |
| flutter_riverpod | ^3.3.2 | 响应式状态管理 runtime |
| riverpod_annotation | ^4.0.3 | `@riverpod` 注解 |
| go_router | ^17.3.0 | 声明式路由 |
| drift | ^2.34.0 | SQLite ORM |
| sqlite3_flutter_libs | ^0.6.0+eol | Flutter Android SQLite native 绑定 |
| path_provider | ^2.1.6 | App 私有目录（录音文件、SQLite 文件） |
| path | ^1.9.1 | 跨平台路径拼接 |
| record | ^7.1.0 | 麦克风录音（文件 + PCM 流） |
| just_audio | ^0.10.5 | 本地录音回放 |
| permission_handler | ^12.0.3 | 运行时麦克风权限申请 |
| freezed_annotation | ^3.1.0 | 不可变数据类注解 |
| json_annotation | ^4.12.0 | JSON 编解码注解 |
| intl | ^0.20.2 | 日期格式化 |

### dev_dependencies

| Package | Version | 用途 |
|---------|---------|------|
| flutter_test | sdk: flutter | 单元 + Widget 测试 |
| flutter_lints | ^6.0.0 | 官方推荐 lint 集合 |
| build_runner | ^2.15.0 | 代码生成入口（freezed / json / drift / riverpod） |
| riverpod_generator | ^4.0.4 | `@riverpod` 注解代码生成 |
| drift_dev | ^2.34.0 | Drift 表 + DAO 代码生成 |
| freezed | ^3.2.6-dev.1 | freezed 代码生成 |
| json_serializable | ^6.14.0 | json_serializable 代码生成 |

## Rationale

| Package | 为什么选择 |
|---------|----------|
| flutter_riverpod / riverpod_annotation | TECH_STACK.md §3 明确选定 Riverpod 3.x 风格，启用 `@riverpod` 代码生成（ADR-003） |
| riverpod_generator | 同上，与 `flutter_riverpod 3.x` + `riverpod_annotation 4.x` 链路对齐 |
| go_router | TECH_STACK.md §5 选定 `go_router`，不使用 ShellRoute / 登录 redirect / 深链接 |
| drift + sqlite3_flutter_libs | TECH_STACK.md §4 选定 Drift，schemaVersion = 1，预留 `MigrationStrategy`（ADR-004） |
| path_provider + path | Android 录音文件、SQLite 数据库文件存放在 `getApplicationDocumentsDirectory()` |
| record | TECH_STACK.md §6 选定 `record 7.x`，T009 调音器 Spike 使用 PCM 流路径 B |
| just_audio | TECH_STACK.md §6 选定 `just_audio 0.10.x`，MVP 不做后台播放（不引入 `just_audio_background`） |
| permission_handler | TECH_STACK.md §6 选定 `permission_handler`，运行时申请麦克风权限 |
| freezed_annotation + freezed | 数据模型（`PracticeRecord`、`UserSetting`、`SelfAssessment` 等）使用不可变数据类 |
| json_annotation + json_serializable | MVP 不涉及网络 JSON，但 `assets/exercises/*.json`（练习文案）需 JSON 解析 |
| intl | 日期格式化、`DateFormat.yMMMd()` 等本地化工具 |
| build_runner | 统一驱动 freezed / json_serializable / drift_dev / riverpod_generator |
| flutter_lints | Flutter 官方推荐 lint 集合（默认包含在 `analysis_options.yaml`） |

### 环境兼容理由

- Flutter **3.44.2** / Dart **3.12.2** 满足全部依赖的 Dart SDK 约束：
  - `source_gen 2.x`、`riverpod_generator 4.x`、`drift 2.34.x`、`analyzer 7.x+` 全部要求 Dart ≥ 3.6 → 当前 Dart 3.12.2 满足；
- `record 7.x` 要求 `minSdk 23` → 与 T004 已写好的 `minSdk = 23` 一致；
- `permission_handler 12.x` 与 `compileSdk` 当前值兼容；
- `flutter_riverpod 3.3.2` 与 `riverpod_annotation 4.0.3` + `riverpod_generator 4.0.4` 三方版本相互锁定，不会出现 1.x / 2.x 与 3.x / 4.x 混用导致的解析失败。

## Compatibility Notes

| 配置 | 实际值 | 兼容依据 |
|------|--------|----------|
| Flutter | 3.44.2 stable | Flutter SDK 当前 stable |
| Dart | 3.12.2 | 与 Flutter 3.44.2 绑定 |
| Android minSdk | 23 | `record 7.x` 要求；T004 已写入 `android/app/build.gradle` |
| Android targetSdk | flutter.targetSdkVersion | 由 Flutter Gradle Plugin 决定 |
| Android compileSdk | flutter.compileSdkVersion | 由 Flutter Gradle Plugin 决定 |
| Kotlin | Flutter Gradle Plugin 默认 | AGP 链路保持默认 |
| Java | JavaVersion.VERSION_1_8 | T004 已写入 |

注：`environment.sdk: ^3.5.4` 仍为 T004 默认值；由于 Dart 3.12.2 已能满足此约束范围，T005 不收紧此约束。后续如需收紧到 `^3.12.2`，可作为独立维护任务。

## Rejected Dependencies

T005 明确**拒绝**引入以下依赖，理由与上游 TECH_STACK.md §10、PRD §11.4 一致：

| 禁止项 | 拒绝理由 |
|--------|----------|
| `firebase_core` / `firebase_auth` / `firebase_analytics` / `firebase_crashlytics` / `cloud_firestore` | 联网 SDK，违反「无 INTERNET」原则（ADR-002 / PRD §11.4） |
| `sentry_flutter` / `bugly` / `umeng` | 联网 APM / 埋点 SDK |
| `google_mobile_ads` / `admob` | 广告 SDK |
| `openai` / `anthropic` / `google_ml_kit` / `tflite_flutter` | AI SDK（PRD §11.4 禁止 MVP 任何 AI 评分 / 节奏识别 / 和弦识别） |
| `supabase` / `amplify` / `cloud_kit` | Cloud Sync SDK，MVP 不同步 |
| `dio` / `http` / `retrofit` / `chopper` / `graphql` | 网络库，MVP 无联网 |
| `get_it` / `injectable` / `kiwi` | 复杂 DI 容器，MVP 简化 |
| `provider` / `flutter_bloc` / `get` (GetX) | 状态管理违反统一 Riverpod 选型 |
| `sqflite` | 与 Drift 冲突，统一 Drift |
| `audioplayers` | 与 `just_audio` 重复，统一 `just_audio` |
| `just_audio_background` | MVP 不做后台播放 |
| `flutter_sound` | 与 `record` 重复，统一 `record` |
| `flutter_local_notifications` | MVP 无后台服务 |
| `firebase_auth` / `google_sign_in` / `sign_in_with_apple` | MVP 无登录态 |

任何**需要 INTERNET 权限**的依赖自动禁止（TECH_STACK.md §10 硬约束）。

## Manifest Permission Impact

### 修改

- `android/app/src/main/AndroidManifest.xml` 新增：
  ```xml
  <uses-permission android:name="android.permission.RECORD_AUDIO" />
  ```
- 该权限为 MVP 必选（T006+ 的调音器与录音页会用到），仅在用户首次触发相关功能时申请，不会启动即申请（PRD §11.3 / TECH_STACK.md §7.3）。

### 未修改

- `android/app/src/debug/AndroidManifest.xml`：未添加任何权限（保持 T004 注释）；
- `android/app/src/profile/AndroidManifest.xml`：未添加任何权限（保持 T004 注释）。

### 明确禁止出现在 Manifest 的权限

T005 / MVP 阶段以下权限**禁止添加**：

- `android.permission.INTERNET`
- `android.permission.WRITE_EXTERNAL_STORAGE`
- `android.permission.READ_EXTERNAL_STORAGE`
- `android.permission.READ_MEDIA_AUDIO`
- `android.permission.WAKE_LOCK`
- `android.permission.FOREGROUND_SERVICE`
- `android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK`
- `android.permission.POST_NOTIFICATIONS`
- `android.permission.MODIFY_AUDIO_SETTINGS`（T009 评估蓝牙 / 音频路由时再考虑，本阶段不添加）

## Risks

| 风险 | 描述 | 缓解 |
|------|------|------|
| 依赖升级 | pub.dev 后续发布新版本可能要求更高 Dart SDK 或 Flutter SDK | 升级前走 ADR 流程，不允许私自变更（TECH_STACK.md §1.2） |
| 网络下载不稳定 | T005 初次尝试时 `drift` 等大包下载曾 timeout | 已通过手动 `flutter pub get` 成功完成；如未来 CI 重建遇网络问题，建议预热 pub.dev 缓存 |
| Flutter SDK 升级 | 本机从 3.24.5 升到 3.44.2 是大版本跨度 | T006+ 任务以新版本为准；任何对 Flutter 3.44.2 API 的兼容性差异需在对应任务中处理 |
| record / just_audio 真实设备能力 | 当前未在真机验证 PCM 流 + AAC m4a 编码 + 后台音频焦点行为 | T009 调音器 Spike、T011 录音 + 回放 任务需在真机验证；失败时按 ADR-006 / ADR-007 路径回退 |
| freezed 3.2.6-dev.1 预发布 | `freezed` 当前为 pre-release；正式 release 后可能 API 微调 | T006+ 升级到正式版前必须 `flutter pub get` + `flutter analyze` 验证 |
| 间接依赖中可能引入网络包 | 部分依赖（如 `just_audio`、`permission_handler`）可能间接依赖 `http` 库用于元数据获取 | `flutter pub deps` 输出已确认未引入联网 SDK；如果未来升级引入，需要追加 ADR |
| iOS 平台缺失 | 本任务不涉及 iOS，依赖未对 iOS 兼容性做验证 | iOS reserved 状态保持；进入 iOS 阶段时需重新评估所有依赖 |

## Review Conditions

以下任一条件触发时，需要重新评审本 ADR 并启动一次 ADR 流程：

1. Flutter SDK 主版本升级（如 3.44 → 3.50）；
2. 任意核心 dependencies / dev_dependencies 进行 major 版本升级（如 Riverpod 3.x → 4.x、Drift 2.x → 3.x）；
3. 引入任何需要 `INTERNET` 权限的依赖（自动禁止）；
4. 引入网络、云同步、AI、后台音频、iOS 平台；
5. `record` / `just_audio` 在真机验证失败，需要切换到其他录音 / 播放方案；
6. `freezed 3.2.6-dev.1` 升级到正式 release；
7. 升级 `permission_handler` 跨越 major 版本。

## Files Changed by T005

- `pubspec.yaml`：新增 dependencies + dev_dependencies；
- `pubspec.lock`：由 `flutter pub get` 生成；
- `android/app/src/main/AndroidManifest.xml`：新增 `<uses-permission android:name="android.permission.RECORD_AUDIO" />`；
- `docs/ADR/ADR-011-core-dependencies.md`：本文档。