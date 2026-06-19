# 架构设计文档 (ARCHITECTURE)

## 1. 架构概览

本项目采用 **Feature-First + Clean-ish Architecture** 的混合架构模式。

- **Feature-First**：按业务功能组织代码目录，而非按技术层组织
- **Clean-ish**：允许 MVP 阶段适度简化完整 Clean Architecture 的四层划分
- **不过度工程化**：不要求每个 Feature 都有完整的 presentation/application/domain/data 四层

## 2. 目录结构

```
lib/
  main.dart                    # App 入口
  app/
    app.dart                   # MaterialApp 配置
    router.dart                # go_router 路由配置
    theme.dart                 # ThemeData 配置
  core/
    constants/
      app_constants.dart       # 常量（音色频率、BPM 范围等）
      chord_constants.dart    # 和弦定义常量
    theme/
      app_theme.dart          # Material 3 主题
      app_colors.dart         # 颜色定义
      app_text_styles.dart    # 文本样式
    utils/
      audio_utils.dart        # 音频相关工具
      date_utils.dart         # 日期工具
    extensions/
      string_extensions.dart   # String 扩展
      datetime_extensions.dart # DateTime 扩展
  shared/
    widgets/
      loading_indicator.dart   # 通用加载组件
      error_display.dart       # 错误展示组件
      practice_card.dart      # 练习卡片组件
    services/
      audio_recorder_service.dart  # 录音服务
      audio_player_service.dart    # 播放服务
      permission_service.dart      # 权限服务
      storage_service.dart         # 本地存储服务
  features/
    home/
      presentation/
        home_page.dart
        home_controller.dart      # Riverpod Notifier
        widgets/
          today_practice_card.dart
          quick_actions.dart
      domain/
        practice_plan.dart
      data/
        practice_plan_repository.dart
    tuner/
      presentation/
        tuner_page.dart
        tuner_controller.dart
        widgets/
          tuner_display.dart
          string_selector.dart
      domain/
        tuning_state.dart
      data/
        tuning_repository.dart
    single_note_practice/
      presentation/
        single_note_page.dart
        single_note_controller.dart
      domain/
        note_practice.dart
      data/
        note_practice_repository.dart
    chord_library/
      presentation/
        chord_library_page.dart
        chord_detail_page.dart
        chord_controller.dart
      domain/
        chord.dart
        chord_diagram.dart
      data/
        chord_repository.dart
    metronome/
      presentation/
        metronome_page.dart
        metronome_controller.dart
      domain/
        metronome_settings.dart
    recording/
      presentation/
        recording_page.dart
        recording_controller.dart
      data/
        recording_repository.dart
    playback/
      presentation/
        playback_page.dart
        playback_controller.dart
    self_assessment/
      presentation/
        self_assessment_dialog.dart
        self_assessment_controller.dart
    practice_records/
      presentation/
        practice_records_page.dart
        practice_records_controller.dart
      domain/
        practice_record.dart
      data/
        practice_record_dao.dart
    settings/
      presentation/
        settings_page.dart
        settings_controller.dart
      domain/
        user_settings.dart
      data/
        user_settings_repository.dart
  data/
    database/
      app_database.dart       # Drift 数据库定义
      tables/
        practice_records_table.dart
        user_settings_table.dart
    repositories/
      # 跨 feature 的仓储实现
  domain/
    models/
      # 跨 feature 的领域模型
    services/
      # 跨 feature 的领域服务
```

## 3. 架构原则

### 3.1 Feature-First 组织

**原则**：每个 feature 是自包含的单元，包含自己的 presentation/domain/data。

```
features/tuner/
  presentation/   # UI + Controller
  domain/         # 业务模型 + 业务规则
  data/           # 数据访问（Repository）
```

**好处**：
- 添加新功能时只创建一个目录
- 功能代码内聚，易于删除或迁移
- 团队可以并行开发不同 feature

### 3.2 Clean-ish 简化原则

MVP 阶段允许以下简化：

| 完整 Clean Arch | MVP 简化 |
|----------------|----------|
| 每个 feature 都有完整的四层 | 可选：只使用需要的层 |
| UseCase 封装业务逻辑 | Controller (Riverpod Notifier) 直接调用 Repository |
| Repository 接口 + 实现分离 | 直接在 data/ 中实现 Repository |
| 领域模型与数据模型分离 | 可共用一个模型，用 freezed 生成 |

**不简化**：
- 数据库操作必须通过 Repository
- UI 状态必须通过 Riverpod 管理
- 跨 Feature 的调用必须通过定义好的接口

### 3.3 Riverpod 使用原则

**Provider 组织**：
- 每个 feature 有一个或多个 Notifier
- Notifier 持有状态和业务逻辑
- UI 通过 `ref.watch()` 监听状态变化

**示例**：

```dart
// tuner/tuner_controller.dart
@riverpod
class TunerController extends _$TunerController {
  @override
  AsyncValue<TunerState> build() {
    return const AsyncValue.loading();
  }

  Future<void> startTuning() async {
    state = const AsyncValue.loading();
    try {
      // 业务逻辑
      state = AsyncValue.data(TunerState());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
```

## 4. 数据流

### 4.1 用户操作数据流

```
用户操作
  → Widget 调用 ref.read(Controller.notifier)
  → Controller执 行业务逻辑
  → Controller 更新 state
  → UI 通过 ref.watch() 自动重建
```

### 4.2 数据读取数据流

```
Controller 请求数据
  → Repository 调用 DAO
  → DAO 执行 SQL
  → 返回数据模型
  → Controller 更新 state
  → UI 重建
```

### 4.3 音频录制数据流

```
用户点击录音
  → 检查麦克风权限
  → 启动 AudioRecorderService
  → 录音写入本地文件
  → 用户停止录音
  → 保存文件路径到数据库
```

## 5. 路由设计

### 5.1 路由表

| 路径 | 页面 | 说明 |
|------|------|------|
| `/` | HomePage | 首页/今日练习 |
| `/tuner` | TunerPage | 调音器 |
| `/single-note` | SingleNotePage | 单音练习 |
| `/chord-library` | ChordLibraryPage | 和弦库 |
| `/chord-library/:chordId` | ChordDetailPage | 和弦详情/指法图 |
| `/metronome` | MetronomePage | 节拍器 |
| `/recording` | RecordingPage | 录音页面 |
| `/recording/:recordId` | PlaybackPage | 回放页面 |
| `/records` | PracticeRecordsPage | 练习记录 |
| `/settings` | SettingsPage | 设置 |

### 5.2 go_router 配置

```dart
// app/router.dart
final goRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomePage(),
      routes: [
        GoRoute(
          path: 'tuner',
          builder: (context, state) => const TunerPage(),
        ),
        // ... 其他路由
      ],
    ),
  ],
);
```

## 6. 数据库设计

### 6.1 Drift 数据库

```dart
// data/database/app_database.dart
@DriftDatabase(tables: [PracticeRecordsTable, UserSettingsTable])
class AppDatabase extends _$AppDatabase {
  @override
  int get schemaVersion => 1;
}
```

### 6.2 表结构

**PracticeRecordsTable**：
- id (INTEGER PRIMARY KEY)
- practiceType (TEXT): 'single_note' | 'chord' | 'metronome' | 'free_practice'
- content (TEXT): 练习内容描述
- selfRating (INTEGER): 1=需改进, 2=一般, 3=好
- audioPath (TEXT, nullable): 录音文件路径
- duration (INTEGER): 练习时长（秒）
- createdAt (INTEGER): 时间戳

**UserSettingsTable**：
- id (INTEGER PRIMARY KEY)
- key (TEXT UNIQUE)
- value (TEXT)

## 7. 扩展性设计

### 7.1 添加新 Feature

1. 在 `features/` 下创建新目录
2. 按需创建 presentation/domain/data 子目录
3. 在 Router 中注册路由
4. 在需要的 Provider 中引用

### 7.2 后期 AI 集成

```dart
// 预留接口
abstract class PitchEvaluationService {
  Future<PitchResult> evaluate(String audioPath);
}

// MVP 实现：返回占位结果
class LocalPitchEvaluationService implements PitchEvaluationService {
  @override
  Future<PitchResult> evaluate(String audioPath) async {
    return PitchResult(score: 0, feedback: 'AI 评分待集成');
  }
}
```

### 7.3 后期云同步

```dart
// 预留接口
abstract class SyncService {
  Future<void> syncToCloud();
  Future<void> syncFromCloud();
}

// MVP 实现：空操作
class LocalOnlySyncService implements SyncService {
  @override
  Future<void> syncToCloud() async {}
  @override
  Future<void> syncFromCloud() async {}
}
```

## 8. MVP 阶段架构约束

| 约束 | 说明 |
|------|------|
| 不使用复杂 DI | 避免 injectable/ get_it 过度设计 |
| 不使用复杂状态机 | 避免 freezed_state_machine |
| 不分层过度 | presentation/domain/data 三层可选 |
| 不做抽象先行 | 先跑通再根据需要重构 |

**核心目标**：快速验证产品方向，不做过度架构投资。
