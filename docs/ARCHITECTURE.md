# 架构设计文档 (ARCHITECTURE)

> 本文档是 T003 阶段最终定稿的架构设计，作为 T004-T013 任务执行的直接参考。
>
> 上游依据：`docs/PRD.md`（T002 定稿）、`docs/MVP_SCOPE.md`、`docs/TECH_STACK.md`（T003 定稿）、`docs/DATA_MODEL_DRAFT.md`（T003 定稿）、`research/T001_RESEARCH_SUMMARY.md`。
>
> 最后更新：2026-06-19 | 版本：1.0（T003）

---

## 1. 架构概览

本项目采用 **Feature-First + Clean-ish Architecture** 的混合架构模式：

- **Feature-First**：按业务功能组织代码目录，而非按技术层组织；
- **Clean-ish**：允许 MVP 阶段适度简化完整 Clean Architecture 的四层划分；
- **不过度工程化**：不要求每个 Feature 都有完整的 presentation / application / domain / data 四层；按 feature 实际复杂度选用；
- **本地优先**：所有数据本地存储，无任何联网依赖；
- **MVP 不为未来预留过度接口**：V1+ 阶段的 AuthService / SyncService / AIService 等仅在本文档 §11 中以**文字说明**形式记录扩展方向，**代码层一律不创建**对应 Dart 文件、不写空实现接口、不加相关依赖（详见 §11 硬约束）。

---

## 2. 架构原则

### 2.1 Feature-First 组织

每个 feature 是自包含单元：

```
features/<feature_name>/
  presentation/   # 页面、Widget、UI 状态
  application/    # Riverpod Controller / Notifier
  domain/         # 实体、枚举、业务规则（按需）
  data/           # Repository、DAO、本地数据源（按需）
```

### 2.2 Clean-ish 简化原则

| 完整 Clean Arch | MVP 简化 |
|----------------|----------|
| 每个 feature 都有完整的四层 | 只使用需要的层（如 settings 不需要 data/） |
| UseCase 封装业务逻辑 | Controller（Riverpod Notifier）直接调用 Repository |
| Repository 接口 + 实现分离 | 直接在 data/ 中实现 Repository |
| 领域模型与数据模型分离 | 可共用一个模型（freezed） |

**不简化**：
- 数据库操作必须通过 Repository / DAO；
- UI 状态必须通过 Riverpod 管理；
- 跨 Feature 的调用必须通过 Provider 接口，避免直接依赖内部实现。

### 2.3 Riverpod 使用原则

- 每个 feature 有一个或多个 Notifier；
- Notifier 持有状态和业务逻辑；
- UI 通过 `ref.watch()` 监听状态变化；
- 跨 feature 调用通过 Provider 引用，禁止直接 new 实例；
- MVP 推荐使用 `@riverpod` 代码生成，但允许简单 feature 手写 Notifier。

---

## 3. 目录结构（最终推荐）

```text
ukulele_app/
  android/                              # Flutter create 自动生成；T005 检查权限
  lib/
    main.dart                           # App 入口，runApp(ProviderScope(child: App()))
    app/
      app.dart                          # MaterialApp.router 配置
      router.dart                       # go_router 路由表 + errorBuilder
      theme.dart                        # ThemeData (Material 3 + seed color)
    core/
      constants/
        app_constants.dart              # App 级别常量（路径、时长等）
        audio_constants.dart            # GCEA 频率、容差、采样率、录音时长上限
        chord_constants.dart            # 7 个基础和弦数据
        practice_plan_constants.dart    # 7 天循环练习计划（内置常量，不入数据库）
        tuner_constants.dart            # 调音器状态枚举、cents 阈值
      errors/
        app_exception.dart              # 自定义异常类型
      utils/
        date_utils.dart                 # 日期工具（day index 计算）
        cents_calculator.dart           # 频率与 cents 互转
      extensions/
        duration_extensions.dart
        datetime_extensions.dart
    shared/
      widgets/
        primary_button.dart
        empty_state.dart
        error_display.dart
        loading_indicator.dart
        practice_task_card.dart
      services/
        permission_service.dart         # 麦克风权限申请
        audio_recorder_service.dart     # record 包装：start/stop + PCM 流
        audio_player_service.dart       # just_audio 包装：play/pause/stop
        app_storage_service.dart        # 录音文件路径生成、级联删除
        audio_file_resolver.dart        # 检查录音文件是否仍存在
    features/
      home/
        presentation/
          home_page.dart                # 今日练习首页
          widgets/
            today_practice_card.dart
            quick_actions.dart
        application/
          today_practice_controller.dart  # Riverpod AsyncNotifier
      tuner/
        presentation/
          tuner_page.dart
          tuner_controller.dart
          widgets/
            tuner_display.dart
            string_selector.dart
            tuner_degraded_banner.dart   # 实验性调音器提示
        domain/
          tuner_state.dart              # current freq / cents / status
          tuning_string.dart            # 枚举 G/C/E/A + 目标频率
        data/
          pitch_algorithm.dart          # T009 调音器 Spike：自相关/YIN
          pitch_result.dart
      single_note_practice/
        presentation/
          single_note_practice_page.dart
          single_note_practice_controller.dart
        domain/
          note_practice.dart            # 单音练习模型
        data/
          note_repository.dart
      chord_library/
        presentation/
          chord_library_page.dart
          chord_detail_page.dart
          chord_controller.dart
        domain/
          chord.dart
          chord_diagram.dart
        data/
          chord_repository.dart         # 从 chord_constants 读取
      metronome/
        presentation/
          metronome_page.dart
          metronome_controller.dart
        application/
          metronome_settings_controller.dart
        domain/
          metronome_settings.dart
        data/
          metronome_tick.dart           # 节拍音播放
      recording/
        presentation/
          recording_page.dart
          recording_controller.dart
        application/
          recording_session_controller.dart
        data/
          recording_repository.dart     # 录音文件路径生成、删除
      playback/
        presentation/
          playback_controls.dart        # 嵌入 PracticeRecordDetailPage
        application/
          playback_controller.dart
        domain/
          playback_state.dart
      self_assessment/
        presentation/
          self_assessment_sheet.dart    # 底部弹出选择三档
        application/
          self_assessment_controller.dart
        domain/
          self_assessment.dart          # good/neutral/needsImprovement
      practice_records/
        presentation/
          practice_records_page.dart
          practice_record_detail_page.dart
          practice_records_controller.dart
        application/
          practice_record_form_controller.dart  # 创建/更新表单
        domain/
          practice_record.dart          # freezed model
          practice_type.dart            # 枚举
          practice_tag.dart             # 枚举
        data/
          practice_record_repository.dart
          practice_record_dao.dart      # Drift DAO
      settings/
        presentation/
          settings_page.dart
          about_page.dart
          privacy_notice_page.dart
          content_notice_page.dart
          settings_controller.dart
        application/
          user_settings_controller.dart
        domain/
          user_setting.dart
        data/
          user_settings_repository.dart
          user_settings_dao.dart
    data/
      database/
        app_database.dart               # @DriftDatabase(schemaVersion: 1)
        tables/
          practice_records_table.dart
          user_settings_table.dart
      repositories/
        # 跨 feature 仓储实现（如有需要；目前主要在各 feature/data/）
    config/
      app_config.dart                   # build flavor / debug flag 等
  assets/
    chord_diagrams/                     # 自绘和弦指法图 PNG/SVG
    exercises/                          # 练习文案 JSON
    audio/
      metronome_click.wav               # 节拍器音（自制/CC0）
  test/                                 # 单元 + Widget 测试
  integration_test/                     # E2E 测试（后期）
  pubspec.yaml                          # T005 写入版本
```

---

## 4. 分层说明

| 层 | 职责 | MVP 是否必备 |
|----|------|--------------|
| **presentation** | 页面、Widget、UI 状态展示 | 必备（所有 feature） |
| **application** | Riverpod Controller / Notifier，编排业务逻辑 | 必备（所有 feature） |
| **domain** | 实体、枚举、业务规则 | 按需（复杂 feature 必备；settings / metronome 等可省略） |
| **data** | Repository、DAO、本地数据源 | 按需（涉及持久化的 feature 必备；纯常量 feature 如 chord_library / single_note_practice 可省略） |
| **shared/services** | 跨 feature 的录音、播放、权限、存储服务 | 必备 |

**feature 目录可省略子层的规则**：
- 无需持久化、无复杂业务规则的简单 feature → 可省略 `domain/` 与 `data/`；
- 仅引用 `core/constants/` 内置常量的 feature（如 chord_library） → 可省略 `data/`，直接从 `chord_constants` 读取；
- 仅做 UI 设置的 feature（如 about / privacy_notice） → 可省略 `domain/`、`data/`。

**绝对避免**：
- 引入 get_it / injectable；
- 引入复杂 DI 容器；
- 引入 Clean Architecture 完整 usecase 层；
- 为未来云同步提前建复杂接口；
- 在 feature 之间直接 import 内部实现（应通过 Provider 接口）。

---

## 5. 数据流

### 5.1 用户操作数据流

```text
用户操作
  → Widget 调用 ref.read(controller.notifier)
  → Controller 执行业务逻辑
  → Controller 调用 Repository / Service
  → Controller 更新 state
  → UI 通过 ref.watch() 自动重建
```

### 5.2 数据读取数据流

```text
Controller 请求数据
  → Repository 调用 DAO（Drift）
  → DAO 执行 SQL
  → 返回数据模型（freezed）
  → Controller 包装为 AsyncValue<T>
  → UI 渲染
```

### 5.3 音频录制数据流

```text
用户点击录音
  → Controller 请求 PermissionService
  → 麦克风权限通过 → AudioRecorderService.start()
  → 录音写入 App 私有目录
  → Controller 监听进度 → UI 倒计时显示
  → 用户停止 / 5 分钟自动停止
  → AudioRecorderService.stop() 返回路径
  → Controller 通知 SelfAssessment
  → 用户选择三档 → PracticeRecordRepository.insert
  → 数据库写入 + 录音文件保留
```

### 5.4 录音回放数据流

```text
用户进入 PracticeRecordDetailPage
  → Controller 加载记录 + AudioFileResolver 检查文件是否存在
  → 文件存在 → 显示回放控件 + AudioPlayerService
  → 文件不存在 → 隐藏回放控件，仅显示记录信息
```

---

## 6. 路由表（MVP）

### 6.1 完整路由表

| 路径 | 页面 | 入口来源 | 说明 |
|------|------|----------|------|
| `/` | HomePage | App 启动默认 | 今日练习 |
| `/tuner` | TunerPage | 首页 / 单音练习页入口 | 调音器 |
| `/single-note` | SingleNotePracticePage | 首页任务卡 | 单音练习 |
| `/chords` | ChordLibraryPage | 首页入口 | 和弦库 |
| `/chords/:chordId` | ChordDetailPage | ChordLibraryPage 点击 | 和弦指法图 |
| `/metronome` | MetronomePage | 首页 / 练习页入口 | 节拍器 |
| `/recording` | RecordingPage | 练习页 → 开始录音 | 录音页 |
| `/records` | PracticeRecordsPage | 首页底部入口 | 练习记录列表 |
| `/records/:recordId` | PracticeRecordDetailPage | PracticeRecordsPage 点击 | 记录详情 + 回放控件（playback feature 嵌入） |
| `/settings` | SettingsPage | 首页底部入口 | 设置 |
| `/settings/about` | AboutPage | SettingsPage → 关于 | 关于 |
| `/settings/privacy` | PrivacyNoticePage | SettingsPage → 隐私说明 | 隐私说明 |
| `/settings/content` | ContentNoticePage | SettingsPage → 内容声明 | 内容声明 |

### 6.2 路由约束

- 使用 `MaterialApp.router(routerConfig: _router)`；
- **不使用 `ShellRoute`**（MVP 无底部 Tab / 抽屉需求）；
- **不使用登录 redirect**（无登录态）；
- **不使用深链接 / Web URL Strategy**；
- 路由深度 ≤ 2 层；
- 提供统一 `errorBuilder` 渲染 NotFoundPage；
- 路由表集中在 `app/router.dart`。

---

## 7. 权限边界

### 7.1 AndroidManifest 权限

**MVP 必选**：

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

**MVP 可选**：

```xml
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
```

**MVP 明确禁止**：

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
```

**核心承诺**：MVP 不申请 INTERNET 权限，从源头杜绝任何联网行为。

> ⚠️ T004/T005 必须检查 **main / debug / profile 三个** `AndroidManifest.xml`，如存在 `INTERNET` / `STORAGE` / `MEDIA` / `FOREGROUND_SERVICE` / `WAKE_LOCK` 等权限，**必须删除或说明来源并等待 Chief Architect 审核**。如 Flutter 模板默认生成 `INTERNET` 权限（debug 常见），**默认要求删除**，不得默认保留。

### 7.2 权限申请时机

| 场景 | 申请时机 | 拒绝降级方案 |
|------|----------|--------------|
| 调音器 | 用户首次点击"开始调音" | 标记"实验性调音器"，同屏保留 GCEA 频率表 + 手动调音说明 |
| 录音 | 用户首次点击"开始录音" | 录音按钮置灰 + 引导前往系统设置 |

**禁止**：
- App 启动时立即申请麦克风权限；
- 在用户未点击相关功能前申请。

### 7.3 T004 / T005 检查清单

- [ ] T004 `flutter create --org com.yupi.ukulele --platforms=android ukulele_app`；
- [ ] **必须**逐一检查以下三个 `AndroidManifest.xml`：
  - `android/app/src/main/AndroidManifest.xml`
  - `android/app/src/debug/AndroidManifest.xml`
  - `android/app/src/profile/AndroidManifest.xml`
- [ ] 删除任何 `INTERNET` / `WRITE_EXTERNAL_STORAGE` / `READ_EXTERNAL_STORAGE` / `READ_MEDIA_AUDIO` / `FOREGROUND_SERVICE` / `WAKE_LOCK` 权限；
- [ ] 只保留 `RECORD_AUDIO` + 可选 `MODIFY_AUDIO_SETTINGS`；
- [ ] 如 Flutter 模板默认生成 `INTERNET` 权限（debug 常见），**默认要求删除**，不得默认保留；如确需仅调试态保留，必须经 Chief Architect 审批并写入 ADR；
- [ ] 修改 `applicationId` 与 `namespace` 为 `com.yupi.ukulele`；
- [ ] 修改 `minSdk = 23`；
- [ ] T005 根据实际 SDK 写入 `targetSdk` / `compileSdk`。

---

## 8. 数据存储边界

### 8.1 SQLite（Drift）— `data/database/`

- `app_database.dart`：`schemaVersion = 1`，预留 `MigrationStrategy`；
- `practice_records_table.dart`：练习记录主表（详见 `DATA_MODEL_DRAFT.md`）；
- `user_settings_table.dart`：用户设置表（key/value）；
- 文件路径：`getApplicationDocumentsDirectory()`。

### 8.2 录音文件 — `getApplicationDocumentsDirectory()/recordings/`

- 文件名格式：`<timestamp>_<uuid>.m4a`；
- 单声道 AAC（m4a），44100Hz，128kbps；
- 最多关联 1 段录音 / 1 条练习记录；
- 删除练习记录时**级联删除**关联录音文件；
- 录音文件被外部删除时**保留数据库记录**，UI 隐藏回放按钮。

### 8.3 SharedPreferences — 用户设置

- `defaultBpm`（int，默认 80）；
- `metronomeVolume`（double，默认 1.0）；
- MVP 简单设置项放在 SharedPreferences；如未来需要复杂查询再迁移到 Drift。

### 8.4 内置常量（不入库）

| 常量 | 位置 | 说明 |
|------|------|------|
| 7 天循环练习计划 | `core/constants/practice_plan_constants.dart` | 不放数据库，便于调整 |
| GCEA 频率参考表 | `core/constants/audio_constants.dart` | 不放数据库 |
| 7 个基础和弦数据 | `core/constants/chord_constants.dart` | 不放数据库 |
| 和弦指法图（PNG/SVG） | `assets/chord_diagrams/` | 不放数据库 |
| 节拍器音 | `assets/audio/metronome_click.wav` | 不放数据库 |

---

## 9. 跨 Feature 调用规范

- 跨 feature 调用必须通过 Provider 接口；
- 禁止直接 `import 'features/xxx/.../internal_xxx.dart'`；
- 共享服务放在 `shared/services/`，所有 feature 通过 Provider 引用；
- 例外：feature 间的 presentation 可以直接组合（如 HomePage 内嵌 QuickActions 引用其他 feature 的卡片），但**业务逻辑必须通过 Provider**。

---

## 10. MVP 阶段架构约束

| 约束 | 说明 |
|------|------|
| 不使用复杂 DI | 避免 get_it / injectable / kiwi |
| 不使用复杂状态机 | 避免 freezed_state_machine / fsm |
| 不分层过度 | presentation / application / domain / data 四层可选 |
| 不做抽象先行 | 先跑通再根据需要重构 |
| 不预留云端实现 | AuthService / SyncService / AIService 等仅在 §11 中文字记录，代码层不写（详见 §11 硬约束） |
| 不做 iOS 平台 | T004 不创建 ios/ 目录 |
| 不做深色模式 UI | 但 ThemeData 设计预留切换能力 |
| 不做平板 UI | MVP 仅适配手机 |

**核心目标**：快速验证产品方向，不做过度架构投资。

---

## 11. 后期扩展点（仅文档，不实现）

> ⚠️ **硬约束（MVP 阶段不得提前实现）**：
> 以下 `AuthService` / `SyncService` / `PitchEvaluationService` / `StrummingRecognitionService` / `ContentService` **只作为路线说明**，记录未来 V1+ 的扩展方向。
>
> **MVP 阶段（T004-T014）严禁**：
> - 不得创建对应 Dart 文件；
> - 不得实现 no-op / `throw UnsupportedError` 占位类；
> - 不得加入相关依赖（如 firebase_auth / cloud_sync / ai_sdk 等）；
> - 不得为了"预留扩展"提前写 `abstract class` 接口、空实现、或 `TODO` 注释代码；
> - 除非后续任务（T015+）明确要求，否则不允许补齐。
>
> 上述抽象**代码层一律不存在**，仅以文字说明形式留在本文档中，以防止后续 Agent 过度架构、写出永远跑不到的空类。

### 11.1 AuthService

```dart
abstract class AuthService {
  Future<User?> getCurrentUser();
  Future<User> signInAnonymously();
  Future<void> signOut();
  Future<bool> isSignedIn();
}
```

MVP 阶段：返回 `null` / 抛 `UnsupportedError`。**注意**：本段仅作为未来实现参考，**代码中不允许创建此 abstract class**。

### 11.2 SyncService

```dart
abstract class SyncService {
  Future<void> uploadRecords(List<PracticeRecord> records);
  Future<List<PracticeRecord>> downloadRecords();
  Future<bool> hasPendingSync();
}
```

MVP 阶段：所有方法空实现（no-op）。**注意**：本段仅作为未来实现参考，**代码中不允许创建此 abstract class**。

### 11.3 PitchEvaluationService

```dart
abstract class PitchEvaluationService {
  Future<PitchResult> evaluate({required String audioPath, required String expectedNote});
}
```

MVP 阶段：抛 `UnsupportedError`。**注意**：本段仅作为未来实现参考，**代码中不允许创建此 abstract class**。

### 11.4 StrummingRecognitionService

```dart
abstract class StrummingRecognitionService {
  Future<StrummingPattern> recognize(String audioPath);
}
```

MVP 阶段：抛 `UnsupportedError`。**注意**：本段仅作为未来实现参考，**代码中不允许创建此 abstract class**。

### 11.5 ContentService

```dart
abstract class ContentService {
  Future<List<Song>> fetchSongs();
  Future<List<ChordProgression>> fetchChordProgression();
}
```

MVP 阶段：抛 `UnsupportedError`。**注意**：本段仅作为未来实现参考，**代码中不允许创建此 abstract class**。

---

## 12. 文档版本

| 版本 | 日期 | 修改内容 | 审批 |
|------|------|----------|------|
| 0.1 | 2026-06-19 | T000 初始架构 | T000 |
| 0.2 | T001 | 调整 router / shared services | T001 |
| 1.0 | 2026-06-19 | T003 定稿：路由表完整化、目录结构最终化、AndroidManifest 权限明确化、跨 feature 调用规范、后期扩展点约束 | T003 |