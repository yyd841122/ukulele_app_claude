# 技术栈文档 (TECH_STACK)

> 本文档是 T003 阶段最终定稿的技术栈，作为 T004-T013 任务执行的直接参考。
>
> 上游依据：`docs/PRD.md`（T002 定稿）、`docs/MVP_SCOPE.md`、`research/T001_RESEARCH_SUMMARY.md`、`research/flutter_docs_notes.md`、`research/audio_tech_notes.md`、`research/compliance_policy_notes.md`。
>
> **重要**：本文档**不锁死具体版本号**，T004 不创建工程不写 pubspec.yaml，T005 阶段通过 `flutter --version`、Context7、pub.dev、本机 Android SDK 实际确认版本后再写入 pubspec.yaml，并在 ADR 中记录决策依据。
>
> 最后更新：2026-06-19 | 版本：1.0（T003）

---

## 1. 技术选型总览

### 1.1 主技术栈（候选范围，最终版本由 T005 确认）

| 层级 | 技术选型 | 候选范围 | 用途 |
|------|----------|----------|------|
| 框架 | Flutter | 3.24+ 候选 | Android 跨平台移动开发 |
| 语言 | Dart | 3.5+ 候选 | Flutter 官方语言 |
| 平台 | Android only | minSdk 23 / targetSdk 34-35 / compileSdk ≥33 | MVP 主平台；iOS reserved |
| 状态管理 | Riverpod | 3.x 候选（`flutter_riverpod` 3.3.2 主线） | 响应式状态管理 |
| 本地数据库 | Drift | 2.x 候选 | SQLite ORM |
| SQLite native | sqlite3_flutter_libs | 0.5.x 候选 | Flutter Android SQLite 绑定 |
| 路由 | go_router | 14.x+ 候选 | 声明式路由 |
| 音频录制 | record | 7.x 候选 | 麦克风录音（文件 + PCM 流） |
| 音频播放 | just_audio | 0.10.x 候选 | 本地录音回放 |
| 权限处理 | permission_handler | 11.x+ 候选 | 运行时权限 |
| 数据类 | freezed | 3.x 候选 | 不可变数据类 |
| JSON 序列化 | json_serializable | 6.x 候选 | JSON 编解码 |
| 国际化 | intl | 0.19.x 候选 | 日期格式化 |
| 路径 | path_provider / path | 2.x / 1.x 候选 | App 私有目录 |
| 代码生成 | build_runner | 2.x 候选（dev_dependency） | freezed / json / drift / riverpod 代码生成 |
| 测试 | flutter_test | SDK | 单元/组件测试 |
| 集成测试 | integration_test | SDK | E2E 测试（后期） |

> **T005 必须复核的版本差异**（基于 T001 研究）：
> - Riverpod 候选从 T000 的 2.x → **3.x**；
> - record 候选从 T000 的 5.x → **7.x**（要求 minSdk 23）；
> - just_audio 候选从 T000 的 0.6.x → **0.10.x**；
> - permission_handler 3.1+ 要求 `compileSdk ≥ 33`，建议 35。
>
> 所有上述版本调整在 T005 通过 Context7 + pub.dev 实际查询后再写入。

### 1.2 版本策略

| 阶段 | 版本处理方式 |
|------|--------------|
| T003（当前） | 仅给出候选范围，不写入 pubspec.yaml |
| T004 | 不添加任何业务依赖，仅创建空壳 Flutter 工程 |
| T005 | 通过 `flutter --version` + Context7 + pub.dev + 本机 Android SDK 最终确认版本，写入 pubspec.yaml，并在 `docs/ADR/` 下新建 ADR-XXX 记录每个版本决策依据（ADR 流程） |
| T005 之后 | 升级必须走 ADR 流程，不允许私自变更 |

**禁止行为**：
- T003 在 pubspec.yaml 中写入具体版本号（pubspec.yaml 在 T004 阶段还不存在）；
- 把候选范围误认为已锁定版本；
- 在未通过 Context7/pub.dev 验证前承诺兼容版本；
- 锁死 `record 7.x` / `just_audio 0.10.x` 等具体小版本（必须由 T005 写）。

---

## 2. 框架选择

### 2.1 为什么选择 Flutter

| 优势 | 说明 |
|------|------|
| 跨平台 | 一套代码支持 Android / iOS（iOS reserved），减少未来扩展成本 |
| 性能 | 编译为原生 ARM 代码，性能接近原生 |
| 生态 | Riverpod / Drift / go_router / record / just_audio / permission_handler 全部活跃维护 |
| 工具链 | `flutter --version`、`flutter doctor`、`flutter pub` 工具链稳定 |

### 2.2 为什么不选 Kotlin 原生 / React Native / Web

- **Kotlin 原生**：MVP 阶段 iOS 预留，Flutter 单一代码库成本更低；
- **React Native**：Dart 静态类型 + Flutter 渲染性能优于 RN runtime；
- **Web / PWA / Capacitor**：音频延迟、离线能力、麦克风 API 稳定性不足。

---

## 3. 状态管理：Riverpod

### 3.1 决策

**MVP 使用 Riverpod 3.x 风格。**

- 推荐启用 `@riverpod` 代码生成（`flutter_riverpod` + `riverpod_annotation` + `riverpod_generator` + `build_runner`）；
- 允许简单 feature 先手写 Notifier，避免过度复杂；
- 不使用已废弃的 `StateNotifier`（已被 `AsyncNotifier` 取代）；
- MVP 不引入 get_it / injectable 等 DI 框架，避免过度设计。

### 3.2 T005 添加的依赖（占位，T005 写入具体版本）

| 依赖 | 用途 |
|------|------|
| flutter_riverpod | Riverpod runtime |
| riverpod_annotation | `@riverpod` 注解 |
| riverpod_generator | 代码生成（dev_dependency） |
| build_runner | 代码生成入口（dev_dependency） |

### 3.3 推荐写法（Riverpod 3.x）

```dart
// 手写 Notifier（简单 feature）
class MetronomeBpmNotifier extends Notifier<int> {
  @override
  int build() => 80;
  void setBpm(int bpm) => state = bpm;
}

final metronomeBpmProvider =
    NotifierProvider<MetronomeBpmNotifier, int>(MetronomeBpmNotifier.new);
```

```dart
// @riverpod 注解（复杂 feature）
@riverpod
class PracticeRecordsController extends _$PracticeRecordsController {
  @override
  Future<List<PracticeRecord>> build() async {
    final repo = ref.read(practiceRecordRepositoryProvider);
    return repo.getAll();
  }
}
```

---

## 4. 数据库：Drift

### 4.1 决策

- MVP 使用 **Drift + sqlite3_flutter_libs**；
- `schemaVersion = 1`；
- MVP 不需要迁移脚本，但**必须预留 `MigrationStrategy`**，未来 schemaVersion 升级有入口；
- **不混用 sqflite**（避免 SQLite 实例不一致）；
- 推荐 `FlutterQueryExecutor.shared`（默认设置，简化路径管理）；
- 后续如需 `stepByStep` 迁移或 `make-migrations` 命令，由对应任务评估。

### 4.2 T005 添加的依赖（占位）

| 依赖 | 用途 |
|------|------|
| drift | SQLite ORM |
| sqlite3_flutter_libs | Flutter Android SQLite native 绑定 |
| drift_dev | Drift 代码生成（dev_dependency） |

---

## 5. 路由：go_router

### 5.1 决策

- MVP 使用 `MaterialApp.router(routerConfig: _router)` 模式；
- **不使用 `ShellRoute`**（无底部 Tab / 抽屉需求）；
- **不使用登录 redirect**（MVP 无登录态）；
- 提供 `errorBuilder` 或统一 `NotFoundPage`；
- MVP 不做深链接、不做 Web URL Strategy；
- 路由深度 ≤ 2 层。

### 5.2 MVP 路由表（简略概览）

> **完整路由表与目录映射以 `docs/ARCHITECTURE.md` §6 为准**，本节仅作为概览参考。任何路由新增 / 修改必须同步更新 ARCHITECTURE.md，避免两份文档不一致。

| 路径 | 页面 | 说明 |
|------|------|------|
| `/` | HomePage | 首页 / 今日练习 |
| `/tuner` | TunerPage | 调音器 |
| `/single-note` | SingleNotePracticePage | 单音练习 |
| `/chords` | ChordLibraryPage | 和弦库 |
| `/chords/:chordId` | ChordDetailPage | 和弦详情 / 指法图 |
| `/metronome` | MetronomePage | 节拍器 |
| `/recording` | RecordingPage | 录音 |
| `/records` | PracticeRecordsPage | 练习记录列表 |
| `/records/:recordId` | PracticeRecordDetailPage | 练习记录详情（含回放） |
| `/settings` | SettingsPage | 设置 |
| `/settings/about` | AboutPage | 关于 |
| `/settings/privacy` | PrivacyNoticePage | 隐私说明 |
| `/settings/content` | ContentNoticePage | 内容声明 |

---

## 6. 音频技术选型

### 6.1 决策矩阵

| 功能 | 推荐 | 备选 | MVP 决策 |
|------|------|------|----------|
| 录音 | record 7.x | flutter_sound | **record** |
| 回放 | just_audio 0.10.x | audioplayers | **just_audio** |
| 麦克风权限 | permission_handler 11.x+ | 原生 API | **permission_handler** |
| 调音器（T009 Spike） | record PCM 流 + Dart 自相关 | Android 原生 / FFI | **首选 PCM 流 + 自相关**，失败后评估 Android 原生 |

### 6.2 音频边界

**MVP 允许**：
- 调音器所需的基础频率检测（手动选弦 + 单帧/短窗 PCM + 与目标频率比较 + 方向提示）；
- 录音（最长 5 分钟，AAC m4a / 44100Hz / 单声道）；
- 本地回放（播放/暂停/停止）；
- 手动自评（好/一般/需改进）。

**MVP 禁止**：
- AI 自动音高评分；
- AI 节奏分析；
- AI 和弦识别；
- AI 扒谱；
- 多弦同时检测；
- 专业级调音精度承诺；
- 后台录音 / 后台播放；
- 录音导出 / 分享 / 上传。

### 6.3 调音器算法路径（与 `audio_tech_notes.md` 一致）

| 路径 | 方案 | MVP 推荐度 |
|------|------|-----------|
| **路径 B** | record PCM 流 + Dart 自相关 | **高（首选）** |
| 路径 A | 纯 Dart FFT 插件（如 `fftea` / `pitch_detector`） | 中（备选） |
| 路径 C | Android 原生 TarsosDSP / FFI | 低（T009 失败才评估） |

- T009 调音器 Spike 之前**不写音高算法代码**；
- T003 仅在文档中预留 `features/tuner/data/pitch_algorithm.dart` 位置。

---

## 7. Android 平台配置

### 7.1 SDK 版本（PRD §11.2 与 T001 决策一致）

| 配置项 | MVP 规格 | 说明 |
|--------|----------|------|
| `minSdk` | **23**（Android 6.0） | record 7.x 要求；T001 评估覆盖率损失 < 1% |
| `targetSdk` | 34（推荐 35） | Google Play 当前要求；T005 实际确认 |
| `compileSdk` | ≥ 33（建议 35） | permission_handler 3.1+ 要求 ≥ 33 |

**minSdk 决策原因**：
- T001 发现 `record` 7.x 要求 Android minSdk 23；
- 优先保证录音、PCM 音频流、调音器稳定；
- minSdk 23 覆盖率数字待 T001B_FIRECRAWL_RECHECK 复核，不阻塞 T003/T004/T005；
- T005 实际验证后如发现可降低，由 Chief Architect 评估。

### 7.2 AndroidManifest 权限

**MVP 必选**：

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

**MVP 可选**（蓝牙耳机路由支持）：

```xml
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
```

**MVP 明确禁止**（不写入 AndroidManifest.xml）：

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

**核心承诺**：MVP 不申请 INTERNET 权限，从源头保证无联网行为。T004/T005 必须检查 **main / debug / profile 三个** `AndroidManifest.xml`，如存在 `INTERNET` / `STORAGE` / `MEDIA` / `FOREGROUND_SERVICE` / `WAKE_LOCK` 等权限，**必须删除或说明来源并等待 Chief Architect 审核**。

> ⚠️ **注意**：如果 Flutter `flutter create` 模板自动生成 `INTERNET` 权限（debug 构建默认有），也不能默认保留。**默认要求删除**，如确需仅调试态保留，必须在 ADR 中显式记录并经 Chief Architect 批准。

### 7.3 权限申请时机

- **不在 App 启动时申请**麦克风权限；
- 用户首次点击"开始调音"或"开始录音"时才申请；
- 拒绝后提供友好降级文案（"实验性调音器" / 调音参考表）。

### 7.4 T004 / T005 检查清单

- [ ] `flutter create --org com.yupi.ukulele --platforms=android ukulele_app` 生成后，**必须**逐一检查以下三个 `AndroidManifest.xml`：
  - `android/app/src/main/AndroidManifest.xml`
  - `android/app/src/debug/AndroidManifest.xml`
  - `android/app/src/profile/AndroidManifest.xml`
- [ ] 删除任何 `INTERNET` / `WRITE_EXTERNAL_STORAGE` / `READ_EXTERNAL_STORAGE` / `READ_MEDIA_AUDIO` / `FOREGROUND_SERVICE` / `WAKE_LOCK` 权限；
- [ ] 确认只保留 `RECORD_AUDIO` + 可选 `MODIFY_AUDIO_SETTINGS`；
- [ ] 如 Flutter 模板默认生成了 `INTERNET` 权限（debug 常见），**不得默认保留**，按"默认要求删除"原则处理，必要时通过 ADR 申请仅调试态保留；
- [ ] 修改 `applicationId = "com.yupi.ukulele"` 与 `namespace = "com.yupi.ukulele"`；
- [ ] 修改 `minSdk = 23`、`targetSdk = 34`、`compileSdk = 35`（T005 确认）。

---

## 8. iOS 预留

| 项目 | MVP 状态 | 说明 |
|------|----------|------|
| `ios/` 目录 | **T004 不创建** | 未来进入 iOS 阶段时再 `flutter create --platforms=ios .` |
| iOS Info.plist | T004 不写 | 未来需补充 `NSMicrophoneUsageDescription` |
| iOS Podfile | T004 不写 | 未来补充 |
| iOS 签名证书 | 不配置 | 商业化前评估 |
| iOS CI | 不配置 | 商业化前评估 |

**iOS reserved 是产品和架构预留，不是工程目录预留。**

---

## 9. pubspec.yaml 结构（仅结构示意，T005 最终确认版本）

> 以下只展示依赖类别和结构，具体版本号由 T005 通过 Context7 + pub.dev + Flutter 官方文档确认最新稳定兼容版本后再写入。**禁止直接复制此处的版本占位符**。

```yaml
name: ukulele_app
description: 尤克里里练习 App（Android MVP）
publish_to: 'none'
version: 0.1.0+1

environment:
  sdk: ">=3.5.0 <4.0.0"   # T005 按 Flutter 最新稳定 SDK 调整到合适 caret 范围
  flutter: ">=3.24.0"    # T005 按 Flutter 最新稳定版调整

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod:    <T005-confirmed>
  riverpod_annotation: <T005-confirmed>
  go_router:           <T005-confirmed>
  drift:               <T005-confirmed>
  sqlite3_flutter_libs:<T005-confirmed>
  path_provider:       <T005-confirmed>
  path:                <T005-confirmed>
  record:              <T005-confirmed>
  just_audio:          <T005-confirmed>
  permission_handler:  <T005-confirmed>
  freezed_annotation:  <T005-confirmed>
  json_annotation:     <T005-confirmed>
  intl:                <T005-confirmed>

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints:        <T005-confirmed>
  build_runner:         <T005-confirmed>
  freezed:              <T005-confirmed>
  json_serializable:    <T005-confirmed>
  drift_dev:            <T005-confirmed>
  riverpod_generator:   <T005-confirmed>

flutter:
  uses-material-design: true
  assets:
    - assets/chord_diagrams/
    - assets/exercises/
    - assets/audio/
```

---

## 10. 禁止技术（硬规则）

T003 明确禁止在 MVP 中引入以下技术。任何 Agent 不得擅自添加：

| 禁止项 | 原因 |
|--------|------|
| Firebase / Crashlytics / Analytics（`firebase_core` / `firebase_crashlytics` / `firebase_analytics` 等任意子包） | 联网 SDK，违反无 INTERNET 原则 |
| Sentry / Bugly / 任何 APM（`sentry_flutter` / `bugly` 等） | 联网 SDK |
| Google Analytics / 友盟 / 任何埋点 | 联网 SDK |
| 任何 Cloud Sync SDK（`cloud_kit` / `aws Amplify` / `supabase_flutter` / `firebase_database` / `firebase_storage` 等） | MVP 不同步 |
| 任何 AI SDK（OpenAI / Anthropic / `google_ml_kit` / `tflite_flutter` / 本地模型推理服务） | MVP 不做 AI |
| 任何广告 SDK（AdMob / Pangle / `unity_ads` / `facebook_audience_network`） | MVP 无广告 |
| `get_it` / `injectable` / `kiwi` | MVP 简化 DI |
| `flutter_sound` 子包（如不需要） | 增加包大小，无收益 |
| `sqflite` | 与 Drift 冲突 |
| `provider` / `flutter_bloc` / `GetX` | 不符合状态管理选型 |
| `audioplayers`（已选 just_audio） | 重复依赖 |
| `firebase_auth` / `google_sign_in` / `sign_in_with_apple` | MVP 无登录态；任何 Auth 实现依赖均为预留扩展，禁止提前引入 |
| `flutter_local_notifications` | MVP 无后台服务，无需通知 |

**任何需要 INTERNET 权限的依赖自动禁止**。

**与 §12 后期扩展点的关系**:§12 列出的 AuthService / SyncService / AIService 等预留抽象**也不得通过任何替代实现库**绕道引入(如 `firebase_auth` 当 AuthService 的替代实现),统一按 §12 硬约束执行。

---

## 11. 测试策略

### 11.1 单元测试（flutter_test）

- Riverpod Provider / Notifier 测试；
- 数据模型 freezed 序列化测试；
- Repository CRUD 测试（Drift in-memory）；
- 调音器频率换算、cents 计算工具函数测试。

### 11.2 Widget 测试（flutter_test）

- 调音器页面弦切换、状态显示；
- 节拍器 BPM 调节、启动 / 暂停 / 停止；
- 自评三档选择；
- 练习记录列表 / 详情页渲染。

### 11.3 集成测试（integration_test，后期）

- 完整流程：调音 → 单音 → 节拍 → 录音 → 自评 → 保存 → 查看历史；
- 飞行模式全功能可用；
- 录音文件丢失场景。

### 11.4 音频功能手动验证清单

- [ ] 麦克风权限被拒绝时，调音器降级为"实验性调音器"，仍显示 GCEA 频率表；
- [ ] 录音到 4:30 提示"还剩 30 秒"，到 5:00 自动停止；
- [ ] 录音文件路径写入数据库，回放按钮可正常播放；
- [ ] 删除练习记录时关联录音文件一并删除；
- [ ] 录音文件被外部删除时，回放按钮自动隐藏。

---

## 12. 后期预留扩展点

> ⚠️ **硬约束（MVP 阶段不得提前实现）**：
> 以下 `AuthService` / `SyncService` / `AIService` / `PitchEvaluationService` / `StrummingRecognitionService` / `ContentService` **只作为路线说明**，记录未来 V1+ 的扩展方向。
>
> **MVP 阶段（T004-T014）严禁**：
> - 不得创建对应 Dart 文件；
> - 不得实现 no-op / `throw UnsupportedError` 占位类；
> - 不得加入相关依赖（如 firebase_auth / cloud_sync / ai_sdk 等）；
> - 不得为了"预留扩展"提前写 `abstract class` 接口、空实现、或 `TODO` 注释代码；
> - 除非后续任务（T015+）明确要求，否则不允许补齐。
>
> 上述抽象仅在本文档中以文字说明形式存在，**代码层一律不存在**，以防止后续 Agent 过度架构、写出永远跑不到的空类。

### 12.1 Auth Service 抽象

```dart
abstract class AuthService {
  Future<User?> getCurrentUser();
  Future<User> signInAnonymously();
  Future<void> signOut();
}
```

MVP 实现：返回 `null` / 抛 `UnsupportedError`。

### 12.2 Sync Service 抽象

```dart
abstract class SyncService {
  Future<void> uploadRecords(List<PracticeRecord> records);
  Future<List<PracticeRecord>> downloadRecords();
  Future<bool> hasPendingSync();
}
```

MVP 实现：空操作（no-op）。

### 12.3 AI Service 抽象

```dart
abstract class PitchEvaluationService {
  Future<PitchResult> evaluate(String audioPath);
}
```

MVP 实现：抛 `UnsupportedError` 或返回占位结果。

---

## 13. 决策记录（ADR 摘要）

| ADR | 决策 | 决策依据 |
|-----|------|----------|
| ADR-001 | MVP Android only，iOS reserved | PRD §11.1，T002 D-01 |
| ADR-002 | minSdkVersion = 23 | PRD §11.2，T001 record 7.x 要求 |
| ADR-003 | Riverpod 3.x 风格 + 启用 @riverpod 代码生成 | T001 flutter_docs_notes.md §Riverpod |
| ADR-004 | Drift + sqlite3_flutter_libs，schemaVersion = 1 | T001 flutter_docs_notes.md §Drift |
| ADR-005 | go_router 14.x+，不使用 ShellRoute / redirect | T001 flutter_docs_notes.md §go_router |
| ADR-006 | record 7.x + just_audio 0.10.x | T001 audio_tech_notes.md |
| ADR-007 | 调音器首选路径 B（record PCM + Dart 自相关） | T001 audio_tech_notes.md §3 |
| ADR-008 | MVP 不申请 INTERNET 权限 | PRD §11.4，T002 D-30 |
| ADR-009 | practiceType 改为 primaryPracticeType + practiceTagsJson | PRD §10.1 + T003 数据模型重构 |
| ADR-010 | T005 通过 Context7 + pub.dev 写入版本号 | T003 版本策略 |

---

## 14. 文档版本

| 版本 | 日期 | 修改内容 | 审批 |
|------|------|----------|------|
| 0.1 | 2026-06-19 | T000 初始候选范围 | T000 |
| 0.2 | T001 | 增加 T001 研究结论，调整候选范围 | T001 |
| 1.0 | 2026-06-19 | T003 定稿：版本范围同步 T001 研究、明确 ADR、新增禁止技术、minSdk 23、AndroidManifest 权限明确 | T003 |