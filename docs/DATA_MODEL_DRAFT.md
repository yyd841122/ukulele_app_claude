# 数据模型草稿 (DATA_MODEL_DRAFT)

> 本文档是 T003 阶段最终定稿的数据模型，作为 T005、T013 等任务的直接参考。
>
> 上游依据：`docs/PRD.md`（T002 定稿）、`docs/MVP_SCOPE.md`、`docs/TECH_STACK.md`（T003）、`docs/ARCHITECTURE.md`（T003）。
>
> 本文档**修正了 T002 PRD 中 `practice_type` 逗号分隔字符串的设计**：PRD 中的 `practice_type` 字段是产品层表达，不是最终数据库设计。技术实现采用 `primaryPracticeType`（枚举）+ `practiceTagsJson`（JSON 字符串）拆分。
>
> 最后更新：2026-06-19 | 版本：1.0（T003）

---

## 1. 模型清单

MVP 数据模型按使用场景分类如下：

| 模型 | 类型 | 持久化 | 说明 |
|------|------|--------|------|
| `PracticeRecord` | 实体 | Drift SQLite | 练习记录主表 |
| `UserSetting` | 实体 | Drift SQLite / SharedPreferences | 用户设置 |
| `BuiltInPracticePlan` | 常量 | 代码内置常量 | 7 天循环练习计划 |
| `PracticeTask` | 常量 | 代码内置常量 | 每日练习任务 |
| `Chord` | 常量 | 代码内置常量 | 7 个基础和弦 |
| `ChordDiagram` | 资源 | `assets/chord_diagrams/` | 自绘指法图 |
| `TuningString` | 枚举 | 代码内置常量 | G/C/E/A 四弦 |
| `TunerState` | 状态 | 不持久化 | 调音器运行时状态 |
| `MetronomeSetting` | 实体 | Drift SQLite / SharedPreferences | 节拍器设置 |
| `RecordingFile` | 文件 | App 私有目录 | 录音 m4a 文件 |
| `SelfAssessment` | 枚举 | 嵌入 PracticeRecord | 三档自评 |

---

## 2. 练习记录相关

### 2.1 PracticeRecord（练习记录主表）

> **T003 关键决策**：将 T002 PRD §10.1 中的 `practice_type` 逗号分隔字符串，拆分为 `primaryPracticeType`（主类型枚举）+ `practiceTagsJson`（JSON 字符串标签列表）。

| 字段 | Dart 类型 | Drift 列类型 | 必填 | 说明 |
|------|-----------|--------------|------|------|
| `id` | String | TEXT PRIMARY KEY | ✅ | UUID v4 |
| `practiceDate` | DateTime | INTEGER | ✅ | 练习日期（本地时区，按"日"粒度） |
| `dayIndex` | int | INTEGER | ✅ | 1-7，关联 7 天循环计划 |
| `primaryPracticeType` | PracticeType | TEXT | ✅ | 主练习类型（枚举字符串） |
| `practiceTagsJson` | String | TEXT | ✅ | JSON 字符串数组，存放额外标签 |
| `practiceContent` | String | TEXT | ✅ | 练习内容描述（如 `"Day 4: C ↔ Am 转换"`） |
| `durationSeconds` | int | INTEGER | ✅ | 练习时长（秒） |
| `isCompleted` | bool | INTEGER（0/1） | ✅ | 是否完成 |
| `selfAssessment` | SelfAssessment? | TEXT NULLABLE | ❌ | 自评结果，可空 |
| `audioFilePath` | String? | TEXT NULLABLE | ❌ | 录音文件相对路径（App 私有目录），可空 |
| `createdAt` | DateTime | INTEGER | ✅ | 创建时间 |
| `updatedAt` | DateTime | INTEGER | ✅ | 最后修改时间 |

**freezed 模型示意**（T005 实际生成）：

```dart
@freezed
class PracticeRecord with _$PracticeRecord {
  const factory PracticeRecord({
    required String id,
    required DateTime practiceDate,
    required int dayIndex,
    required PracticeType primaryPracticeType,
    required String practiceTagsJson, // e.g. '["tuner","single_note","recording"]'
    required String practiceContent,
    required int durationSeconds,
    required bool isCompleted,
    SelfAssessment? selfAssessment,
    String? audioFilePath,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _PracticeRecord;
}
```

### 2.2 PracticeType（主练习类型枚举）

```dart
enum PracticeType {
  singleNote,    // 单音练习
  chord,         // 和弦练习
  metronome,     // 节拍器练习
  recording,     // 录音练习
  mixed,         // 混合类型（如：调音 + 单音 + 录音）
}
```

**与 PRD 枚举的差异**：
- PRD §9 提到 `tuner / single_note / chord / metronome / recording / self_assessment / mixed`；
- T003 调整为：`singleNote / chord / metronome / recording / mixed`；
- `tuner` 降级为 `practiceTagsJson` 中的标签（不作为主类型，因为调音是练习前准备，不是练习主体）；
- `selfAssessment` 不作为类型，是 `PracticeRecord.selfAssessment` 字段。

**调音（tuner）作为 PracticeRecord 的建模规则**：
- 单独调音不产生 PracticeRecord（调音是练习前的辅助动作）；
- 如果一次会话包含调音 + 练习单音 → `primaryPracticeType = singleNote`，`practiceTagsJson = '["tuner","single_note"]'`；
- 如果一次会话仅调音未做其他练习 → **不保存 PracticeRecord**（避免调音记录污染练习数据）。

### 2.3 PracticeTag（标签枚举）

```dart
enum PracticeTag {
  tuner,             // 调音器
  singleNote,        // 单音练习
  chord,             // 和弦练习
  metronome,         // 节拍器
  recording,         // 录音
  selfAssessment,    // 手动自评
}
```

**为什么用 JSON 而非逗号分隔**：

| 方案 | 优点 | 缺点 |
|------|------|------|
| 逗号分隔字符串（如 `"tuner,single_note,recording"`） | 简单 | 标签内不能含逗号；查询必须 LIKE；难以做聚合统计；迁移复杂 |
| **JSON 字符串（如 `'["tuner","single_note","recording"]'`）** | **MVP 推荐**：解析简单；标签内可含任意字符；未来拆子表/迁移成本低 | 需要 jsonDecode |
| 单独子表 practice_record_tags | 关系数据库规范 | MVP 过度设计；查询需 join |

**MVP 决策**：使用 JSON 字符串保存 tags；后期如需高级统计（如"本月 tuner 标签出现次数"）再拆子表。

### 2.4 SelfAssessment（自评枚举）

```dart
enum SelfAssessment {
  good,              // 好
  neutral,           // 一般
  needsImprovement,  // 需改进
}
```

**约束**：
- 三档手动选择；
- 不支持 AI 自动评分；
- 不支持事后修改（写入后 UI 不提供"编辑"按钮）；
- 可以为空（用户可能跳过自评）。

---

## 3. 内置常量（不入库）

### 3.1 BuiltInPracticePlan（7 天循环练习计划）

存储位置：`lib/core/constants/practice_plan_constants.dart`

| 字段 | 类型 | 说明 |
|------|------|------|
| `dayIndex` | int | 1-7 |
| `title` | String | 主题（如 "Day 1: 认识琴弦"） |
| `tasks` | List\<PracticeTask\> | 当日任务列表 |
| `estimatedMinutes` | int | 预计总时长（≤25 分钟） |

**轮换逻辑**：`Day N = (自安装起的天数 % 7) + 1`

- 安装日期需要本地保存（`SharedPreferences` 中保存 `installDate` 或写入 Drift UserSettings）；
- 未完成不惩罚，不影响第二天。

### 3.2 PracticeTask（练习任务）

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | String | 任务 ID（如 `"day1_tuner"`） |
| `title` | String | 任务标题 |
| `content` | String | 任务内容描述 |
| `targetType` | PracticeType | 关联主类型 |
| `targetTags` | List\<PracticeTag\> | 关联标签 |
| `order` | int | 显示顺序 |

**MVP 7 天计划内容**（PRD §9）：

| Day | 主题 | 任务列表 | 总时长 |
|-----|------|----------|--------|
| 1 | 认识琴弦 | 调音 G/C/E/A → 单音 C/E → 节拍器 80 BPM | 15 分钟 |
| 2 | 单音进阶 | 调音 → 单音 C/D/E/F/G → 节拍器 80 BPM | 15 分钟 |
| 3 | 第一个和弦 | 调音 → C 和弦 → 节拍器 80 BPM → 录音 1 段 → 自评 | 18 分钟 |
| 4 | 和弦转换 | 调音 → C ↔ Am → 节拍器 80 BPM → 录音 1 段 → 自评 | 18 分钟 |
| 5 | 更多和弦 | 调音 → F/G 和弦 → 节拍器 90 BPM → 录音 1 段 → 自评 | 20 分钟 |
| 6 | 综合练习 | 调音 → C-Am-F-G 循环 → 节拍器 100 BPM → 录音 1 段 → 自评 | 20 分钟 |
| 7 | 复习巩固 | 调音 → 任选和弦/单音组合 → 节拍器 90 BPM → 录音 1 段 → 自评 | 20 分钟 |

### 3.3 Chord（基础和弦）

存储位置：`lib/core/constants/chord_constants.dart`

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | String | 如 `"chord_c"` |
| `name` | String | 如 `"C"`、`"Am"`、`"G7"` |
| `root` | String | 根音 |
| `quality` | ChordQuality | major / minor / dominant7 |
| `frets` | List\<int\> | 4 个品格数（G/C/E/A 各一） |
| `diagramAssetPath` | String | `assets/chord_diagrams/c.png` |

**MVP 7 个和弦**：C / Am / F / G / G7 / Dm / Em

**不存放数据库的原因**：
- 和弦数量固定，无变动需求；
- 启动时直接读常量即可，避免一次额外查询；
- 后期如需运营修改和弦列表，再迁移到数据库。

### 3.4 ChordDiagram（和弦指法图）

存储位置：`assets/chord_diagrams/`（PNG/SVG）

| 字段 | 类型 | 说明 |
|------|------|------|
| `chordId` | String | 关联 Chord |
| `imageAssetPath` | String | 资源路径 |
| `width` | int | 图片宽度（用于布局） |
| `height` | int | 图片高度 |

---

## 4. 调音相关

### 4.1 TuningString（调音弦枚举）

存储位置：`lib/core/constants/tuner_constants.dart`（GCEA 频率）

| index | name | targetFrequency (Hz) | 名称 |
|-------|------|---------------------|------|
| 1 | A | 440.00 | A4 |
| 2 | E | 329.63 | E4 |
| 3 | C | 261.63 | C4 |
| 4 | G | 392.00 | G4 |

**约束**：
- 仅支持标准 GCEA；
- 不支持 Low G；
- 手动选择，不自动选弦；
- 参考频率 A4 = 440Hz。

### 4.2 TunerState（调音器运行时状态）

**不持久化**,仅作为 Riverpod state。

| 字段 | 类型 | 说明 |
|------|------|------|
| `currentString` | TuningString? | 当前选中弦 |
| `detectedFrequency` | double? | 当前检测频率（Hz） |
| `deviationCents` | double? | 偏差（cents） |
| `status` | TunerStatus | unknown / tooLow / accurate / tooHigh |
| `toleranceCents` | int | 容差（cents），从 `UserSetting.tuner.toleranceCents` 读取，默认 10；不作为 TunerState 持久化字段,而是计算 status 时实时读取 |
| `isListening` | bool | 是否正在监听 |
| `isDegraded` | bool | 是否降级（实验性调音器） |

```dart
enum TunerStatus {
  unknown,    // 未检测到有效频率（无声 / 噪声过低 / 未开始监听 / 检测失败）
  tooLow,     // 检测频率低于目标频率超过容差（deviationCents < -toleranceCents）
  accurate,   // 在 ±toleranceCents 范围内（|deviationCents| ≤ toleranceCents）
  tooHigh,    // 检测频率高于目标频率超过容差（deviationCents > toleranceCents）
}
```

**MVP 状态文案规则**：
- MVP 只展示"偏低 / 接近准确 / 偏高"三类用户文案，对应 `tooLow` / `accurate` / `tooHigh`；
- `unknown` 用于无声、噪声过低、未开始监听、检测失败等状态，UI 显示"未检测到音高，请拨弦"；
- `toleranceCents` 默认 **10 cents**，由 `UserSetting.tuner.toleranceCents` 决定；
- ±10 cents 是**体验目标**，不是专业精度承诺，UI 文案不应出现"精确调音"等绝对化表达；
- T005 / T013 不再使用旧的五档枚举（`tooLow` / `low` / `accurate` / `high` / `tooHigh`），避免与 `accurate` 范围重叠。

**MVP 决定**：调音记录**不保存**到数据库（T001 决策），仅实时显示。

---

## 5. 节拍器设置

### 5.1 MetronomeSetting（节拍器设置）

存储：Drift `user_settings` 表 或 SharedPreferences（key/value）

| key | value 类型 | 默认值 | 说明 |
|-----|-----------|--------|------|
| `metronome.defaultBpm` | int | 80 | 节拍器默认 BPM（50-200） |
| `metronome.volume` | double | 1.0 | 节拍器音量 |
| `metronome.beatsPerMeasure` | int | 4 | MVP 仅支持 4/4 |

**MVP 约束**：
- 仅 4/4 拍；
- BPM 范围 50-200；
- 不支持节奏型、鼓机、后台播放；
- 切页自动停止。

---

## 6. 录音文件

### 6.1 RecordingFile（录音文件）

存储位置：App 私有目录（`getApplicationDocumentsDirectory()/recordings/`）

| 字段 | 类型 | 说明 |
|------|------|------|
| `relativePath` | String | 如 `"recordings/1718800000000_a1b2c3d4.m4a"` |
| `absolutePath` | String | 运行时通过 `path_provider` 解析 |
| `durationSeconds` | int | 录音时长 |
| `fileNameFormat` | String | `<timestamp>_<uuid>.m4a` |
| `format` | String | AAC (m4a)，44.1kHz，单声道 |

**MVP 约束**：
- 最长 5 分钟（硬上限）；
- 4:30 UI 提示"还剩 30 秒"，5:00 自动停止；
- 命名不包含用户敏感信息；
- 默认不备份到云端；
- 不提供导出 / 分享 / 上传；
- 删除 PracticeRecord 时**级联删除**关联录音文件；
- 文件被外部删除时**保留数据库记录**，UI 隐藏回放按钮。

---

## 7. 用户设置

### 7.1 UserSetting（用户设置）

存储：Drift `user_settings` 表 或 SharedPreferences

| key | value 类型 | 默认值 | 说明 |
|-----|-----------|--------|------|
| `app.installDate` | DateTime | 首次启动写入 | 安装日期（用于 7 天轮换计算） |
| `metronome.defaultBpm` | int | 80 | 节拍器默认 BPM |
| `metronome.volume` | double | 1.0 | 节拍器音量 |
| `tuner.toleranceCents` | int | 10 | 调音器容差 |

**命名约定（必读，与 §13.2 一致）**：
- `UserSettingData` 是 **Drift 生成的数据类**（key/value 行记录）；
- `UserSetting` 是 **domain 值对象**，可在 freezed 或普通 class 中定义（视 T005 实际决定）；
- Repository 负责 `UserSettingData` ↔ `UserSetting` 转换；
- T005 / T013 实现时**不得**让 Drift 生成类与 domain 模型同名（同包同名会冲突）。

**installDate 重要**：
- 首次启动时写入；
- **存储格式**：ISO-8601 UTC 字符串（避免时区漂移），如 `"2026-06-19T00:00:00Z"`；
- **day_index 计算**：`dayIndex = ((todayLocalMidnight - installDateLocalMidnight).inDays % 7) + 1`；
- 即把 installDate 与 today 都规整到本地时区的"0 点"，再做天数差取模；
- 用户卸载 App 后数据全部清除。

---

## 8. 模型关系图

```text
BuiltInPracticePlan（常量）
  └── contains → PracticeTask[]

PracticeRecord（Drift）
  ├── has one → PracticeType（枚举）
  ├── has many → PracticeTag（JSON 数组）
  ├── has one? → SelfAssessment（枚举）
  └── references → RecordingFile（可选文件路径）

UserSetting（Drift / SharedPreferences）
  └── 含 installDate 用于 day_index 计算

Chord（常量）
  └── visualized by → ChordDiagram（assets）

TuningString（常量）
  └── 用于 TunerState（不持久化）

MetronomeSetting（UserSetting 的子集）
  └── defaultBpm / volume
```

---

## 9. MVP 持久化决策总结

| 模型 | MVP 持久化方式 | 是否可空 | 备注 |
|------|----------------|----------|------|
| `PracticeRecord` | Drift SQLite | 主记录非空；selfAssessment / audioFilePath 可空 | 主表 |
| `UserSetting` | Drift SQLite 或 SharedPreferences | 均可 | 简单设置优先 SharedPreferences |
| `BuiltInPracticePlan` | 代码内置常量 | - | 7 天计划不放数据库 |
| `PracticeTask` | 代码内置常量 | - | 任务不放数据库 |
| `Chord` | 代码内置常量 | - | 7 个和弦不放数据库 |
| `ChordDiagram` | `assets/chord_diagrams/` | - | 自绘 PNG/SVG |
| `TuningString` | 代码内置枚举 | - | GCEA 频率 |
| `TunerState` | 不持久化 | - | 运行时状态 |
| `MetronomeSetting` | UserSetting 表 | - | 4/4 + BPM 50-200 |
| `RecordingFile` | App 私有目录文件 | audioFilePath 可空 | m4a，5 分钟上限 |
| `SelfAssessment` | PracticeRecord 字段 | 可空 | 三档枚举 |

---

## 10. 后期扩展点（仅文档，不实现）

### 10.1 云同步预留字段（V1+）

```dart
// 同步相关字段（当前不需要）
- syncStatus: Enum // synced/pending/conflict
- syncedAt: DateTime?
- deviceId: String?
```

### 10.2 AI 评分预留字段（V1+）

```dart
// AI 评分结果（V1+）
- pitchScore: int?       // 0-100
- rhythmScore: int?      // 0-100
- overallScore: int?     // 0-100
- aiFeedback: String?
```

### 10.3 账号关联预留字段（V5）

```dart
- userId: String?
- anonymousId: String    // 本地匿名 ID（V1+ 启用云同步前生成）
```

---

## 11. 数据生命周期

| 数据 | 生命周期 | 删除行为 |
|------|----------|----------|
| `PracticeRecord` | 永久本地保存 | 用户可单条删除；卸载 App 全清 |
| `RecordingFile` | 与关联 PracticeRecord 同步 | 删除 PracticeRecord 时级联删除；卸载 App 全清 |
| `UserSetting` | 随 App 卸载 | 卸载 App 全清 |
| `BuiltInPracticePlan` | 代码常量 | 不删除 |
| `Chord` / `ChordDiagram` | 代码 / 资源 | 升级 App 时替换 |

---

## 12. 数据不上传原则

- 无任何后端服务；
- 无任何联网 API；
- 无任何第三方分析 SDK；
- 卸载 App = 数据全部清除；
- **不申请** Android 媒体权限（`READ_MEDIA_AUDIO`），MVP 不写公共目录，避免 Android 13+ 媒体权限复杂度；
- **不申请** `INTERNET` 权限，从源头杜绝网络数据外泄。

---

## 13. Drift 表定义（示意，T005 由 06-local-data-engineer 实现）

> 以下仅展示表结构，T005 任务由 06-local-data-engineer 编写实际 Drift 代码。

### 13.1 PracticeRecordsTable

> **命名约定（必读）**：
> - `PracticeRecordData` 是 **Drift 生成的数据类**（由 `@DataClassName` 声明）；
> - `PracticeRecord` 是 **domain / freezed 模型**（参见 §2.1），由 06-local-data-engineer 在 T005 / T013 编写 freezed 时定义；
> - Repository 层负责 `PracticeRecordData` ↔ `PracticeRecord` 的双向转换，UI / Controller 只与 `PracticeRecord` 交互；
> - T005 / T013 实现时**不得**让 Drift 生成类与 domain 模型同名（同包同名会冲突），必须保留 `Data` 后缀区分。

```dart
@DataClassName('PracticeRecordData')
class PracticeRecords extends Table {
  TextColumn get id => text()();
  DateTimeColumn get practiceDate => dateTime()();
  IntColumn get dayIndex => integer()();
  TextColumn get primaryPracticeType => text()();
  TextColumn get practiceTagsJson => text()();
  TextColumn get practiceContent => text()();
  IntColumn get durationSeconds => integer()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  TextColumn get selfAssessment => text().nullable()();
  TextColumn get audioFilePath => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
```

### 13.2 UserSettingsTable

> **命名约定（必读）**：
> - `UserSettingData` 是 **Drift 生成的数据类**（由 `@DataClassName` 声明）；
> - `UserSetting` 是 **domain 模型或设置值对象**（参见 §7），由 freezed / 普通 class 实现；
> - 同 `PracticeRecordData` 与 `PracticeRecord` 一样,Repository 负责转换,UI / Controller 只与 domain 模型交互；
> - T005 / T013 实现时**不得**让 Drift 生成类与 domain 模型同名。

```dart
@DataClassName('UserSettingData')
class UserSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}
```

### 13.3 AppDatabase

```dart
@DriftDatabase(tables: [PracticeRecords, UserSettings])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(FlutterQueryExecutor.shared);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async => m.createAll(),
        // MVP 不需要迁移；预留 onUpgrade 入口
        onUpgrade: (m, from, to) async {
          // TODO(T005+): 后续 schemaVersion 升级时实现
        },
      );
}
```

---

## 14. 文档版本

| 版本 | 日期 | 修改内容 | 审批 |
|------|------|----------|------|
| 0.1 | 2026-06-19 | T000 初始草稿 | T000 |
| 0.2 | T001 | 调整 PracticeTask / BuiltInExercise / TunerSession 模型 | T001 |
| 1.0 | 2026-06-19 | T003 定稿：拆分 practiceType 为 primaryPracticeType + practiceTagsJson；明确 PracticeType / PracticeTag / SelfAssessment 枚举；明确 installDate 用于 day_index 计算；明确 RecordingFile 命名规范；明确 Drift 表结构示意 | T003 |