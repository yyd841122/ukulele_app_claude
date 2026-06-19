# 数据模型草稿 (DATA_MODEL_DRAFT)

> 本文档是数据模型的初步设计草案，不包含代码实现。模型将随着开发推进逐步细化和调整。

## 1. 练习计划相关模型

### 1.1 PracticePlan (练习计划)

| 字段 | 类型 | 用途 | MVP 必须 | 后期扩展 |
|------|------|------|----------|----------|
| id | String (UUID) | 唯一标识 | 是 | - |
| title | String | 计划标题 | 是 | - |
| description | String | 计划描述 | 否 | - |
| difficulty | Enum | 难度等级 | 是 | beginner/intermediate/advanced |
| targetMinutes | int | 目标时长(分钟) | 是 | - |
| tasks | List\<PracticeTask> | 包含的任务 | 是 | - |
| createdAt | DateTime | 创建时间 | 是 | - |
| updatedAt | DateTime | 更新时间 | 是 | - |

### 1.2 PracticeTask (练习任务)

| 字段 | 类型 | 用途 | MVP 必须 | 后期扩展 |
|------|------|------|----------|----------|
| id | String (UUID) | 唯一标识 | 是 | - |
| type | Enum | 任务类型 | 是 | single_note/chord/metronome/free |
| title | String | 任务标题 | 是 | - |
| content | String | 任务内容描述 | 是 | 如"C 大调音阶练习" |
| targetReps | int | 目标次数 | 否 | 如"练习 10 遍" |
| order | int | 显示顺序 | 是 | - |
| exerciseData | JSON | 类型特定数据 | 否 | 存放音名/和弦等 |

**type 枚举**：
- `single_note`: 单音练习
- `chord`: 和弦练习
- `metronome`: 节拍器练习
- `free`: 自由练习

**exerciseData 示例 (单音练习)**：
```json
{
  "note": "C",
  "string": 3,
  "frets": [0, 1, 0]
}
```

**exerciseData 示例 (和弦练习)**：
```json
{
  "chordName": "C",
  " BPM": 60,
  "duration": 30
}
```

## 2. 练习记录相关模型

### 2.1 PracticeSession (练习会话)

| 字段 | 类型 | 用途 | MVP 必须 | 后期扩展 |
|------|------|------|----------|----------|
| id | String (UUID) | 唯一标识 | 是 | - |
| taskId | String | 关联的任务ID | 是 | - |
| taskType | Enum | 任务类型 | 是 | 同 PracticeTask.type |
| startedAt | DateTime | 开始时间 | 是 | - |
| endedAt | DateTime | 结束时间 | 否 | - |
| durationSeconds | int | 练习时长(秒) | 是 | - |
| selfRating | Enum | 自评结果 | 是 | good/okay/need_improvement |
| notes | String | 用户备注 | 否 | - |
| createdAt | DateTime | 创建时间 | 是 | - |

### 2.2 PracticeRecord (练习记录 - 单次录音)

| 字段 | 类型 | 用途 | MVP 必须 | 后期扩展 |
|------|------|------|----------|----------|
| id | String (UUID) | 唯一标识 | 是 | - |
| sessionId | String | 关联的会话ID | 是 | - |
| practiceType | Enum | 练习类型 | 是 | single_note/chord/metronome/recording |
| content | String | 练习内容描述 | 是 | 如"练习 C 和弦" |
| selfRating | Enum | 自评结果 | 是 | good/okay/need_improvement |
| audioPath | String | 录音文件路径 | 否 | 本地路径 |
| durationSeconds | int | 录音时长(秒) | 否 | - |
| createdAt | DateTime | 创建时间 | 是 | - |

## 3. 和弦相关模型

### 3.1 Chord (和弦)

| 字段 | 类型 | 用途 | MVP 必须 | 后期扩展 |
|------|------|------|----------|----------|
| id | String | 唯一标识 | 是 | - |
| name | String | 和弦名 | 是 | 如"C"、"Am"、"G7" |
| root | String | 根音 | 是 | C/D/E/F/G/A/B |
| quality | Enum | 音质量 | 是 | major/minor/dominant/diminished... |
| strings | List\<int> | 每根弦按的品格 | 是 | 0 表示空弦，-1 表示不按 |
| fingers | List\<int> | 手指编号 | 否 | 1-4 表示食指到小指 |

**strings 示例 (C 和弦)**：
```
G(4弦) C(3弦) E(2弦) A(1弦)
   0      3      2      1
→ [0, 3, 2, 1]
```

### 3.2 ChordDiagram (和弦指法图)

| 字段 | 类型 | 用途 | MVP 必须 | 后期扩展 |
|------|------|------|----------|----------|
| id | String | 唯一标识 | 是 | - |
| chordId | String | 关联的和弦ID | 是 | - |
| type | Enum | 显示类型 | 是 | static_image/dynamic_svg |
| imagePath | String | 图片路径 | 否 | assets/chord_diagrams/c.png |
| startFret | int | 起始品格 | 是 | 1-12 |
| barreInfo | JSON | 封闭信息 | 否 | 如第1品封闭 |

**指法图显示要求**：
- 显示四根弦（G-C-E-A）
- 显示品格位置（X/0/数字）
- 显示手指编号（可选）
- MVP 静态图片即可

## 4. 调音相关模型

### 4.1 TuningString (调音弦)

| 字段 | 类型 | 用途 | MVP 必须 | 后期扩展 |
|------|------|------|----------|----------|
| index | int | 弦序号(1-4) | 是 | 1=G, 2=C, 3=E, 4=A |
| name | String | 弦名 | 是 | G/C/E/A |
| targetFrequency | double | 目标频率(Hz) | 是 | 如 440.0 |
| tolerance | double | 容差(cents) | 是 | 默认 10 |

**标准 GCEA 频率**：
| 弦 | 名称 | 频率 (Hz) |
|----|------|-----------|
| 4 | G | 392.00 |
| 3 | C | 261.63 |
| 2 | E | 329.63 |
| 1 | A | 440.00 |

### 4.2 TunerSession (调音会话)

| 字段 | 类型 | 用途 | MVP 必须 | 后期扩展 |
|------|------|------|----------|----------|
| id | String (UUID) | 唯一标识 | 是 | - |
| stringIndex | int | 当前弦序号 | 是 | 1-4 |
| detectedFrequency | double | 检测到的频率 | 是 | - |
| deviationCents | double | 偏差(cents) | 是 | - |
| status | Enum | 调音状态 | 是 | too_low/low/accurate/high/too_high |
| createdAt | DateTime | 创建时间 | 是 | - |

**MVP 决定**：调音记录是否保存？
- **建议 MVP 不保存 TunerSession**，仅实时显示
- 后期如需调音历史，可单独设计

## 5. 节拍器相关模型

### 5.1 MetronomeSetting (节拍器设置)

| 字段 | 类型 | 用途 | MVP 必须 | 后期扩展 |
|------|------|------|----------|----------|
| id | String | 唯一标识 | 是 | 固定值"default" |
| bpm | int | 节拍速度 | 是 | 50-200 |
| beatsPerMeasure | int | 每小节拍数 | 是 | 3/4/6等 |
| accentFirstBeat | bool | 首拍重音 | 否 | 默认 true |

## 6. 内置练习内容

### 6.1 BuiltInExercise (内置练习)

| 字段 | 类型 | 用途 | MVP 必须 | 后期扩展 |
|------|------|------|----------|----------|
| id | String | 唯一标识 | 是 | - |
| type | Enum | 练习类型 | 是 | single_note/chord/rhythm/song |
| title | String | 练习标题 | 是 | - |
| description | String | 练习描述 | 是 | - |
| difficulty | Enum | 难度 | 是 | beginner/intermediate/advanced |
| durationMinutes | int | 预计时长 | 是 | - |
| content | JSON | 练习内容 | 是 | - |

**content 示例 (单音练习)**：
```json
{
  "notes": [
    {"note": "C", "string": 3, "fret": 0},
    {"note": "D", "string": 3, "fret": 2},
    {"note": "E", "string": 3, "fret": 4}
  ]
}
```

## 7. 用户设置

### 7.1 UserSetting (用户设置)

| 字段 | 类型 | 用途 | MVP 必须 | 后期扩展 |
|------|------|------|----------|----------|
| key | String | 设置项 key | 是 | - |
| value | String | 设置值 | 是 | - |
| updatedAt | DateTime | 更新时间 | 是 | - |

**MVP 保留的设置项**：

| key | 类型 | 默认值 | 说明 |
|-----|------|--------|------|
| defaultBpm | int | 80 | 节拍器默认 BPM |
| tunerTolerance | int | 10 | 调音器容差(cents) |
| metronomeSound | String | "click" | 节拍器声音 |
| practiceReminder | bool | false | 练习提醒（后期） |

## 8. 后期扩展点

### 8.1 云同步预留

```dart
// 同步相关字段（当前不需要）
- syncStatus: Enum // synced/pending/conflict
- syncedAt: DateTime
- deviceId: String
```

### 8.2 AI 评分预留

```dart
// AI 评分结果（V1+）
- pitchScore: int? // 0-100
- rhythmScore: int? // 0-100
- overallScore: int? // 0-100
- aiFeedback: String?
```

### 8.3 账号关联预留

```dart
// 账号相关（V5）
- userId: String?
- anonymousId: String // 本地匿名ID
```

## 9. 模型关系图

```
PracticePlan (练习计划)
  └── contains → PracticeTask (练习任务)

PracticeSession (练习会话)
  └── contains → PracticeRecord (练习记录)
  └── references → PracticeTask

PracticeRecord
  └── has → AudioFile (录音文件)

Chord (和弦)
  └── visualized by → ChordDiagram (指法图)

UserSetting (用户设置)
  └── tuning → MetronomeSetting (节拍器设置)
```

## 10. MVP 数据持久化决策

| 模型 | MVP 持久化方式 | 后期迁移 |
|------|----------------|----------|
| PracticeSession | Drift SQLite | 添加 sync 字段 |
| PracticeRecord | Drift SQLite | 添加 cloud 字段 |
| UserSetting | SharedPreferences 或 Drift | 统一到 Drift |
| Chord | 代码内置数据 | 或迁移到数据库 |
| BuiltInExercise | 代码内置数据 | 或迁移到数据库 |
| TunerSession | **不保存** | 如需保存再设计 |

## 11. 文档版本

| 版本 | 日期 | 修改内容 |
|------|------|----------|
| 0.1 | 2026-06-19 | 初始数据模型草稿 |
