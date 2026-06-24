# T041_BEGINNER_LEARNING_PHASE_2_SCOPE — 初学者教学阶段 2 设计

> 本文档是 v1.1.0 真实音频 MVP 之后的初学者教学阶段 2 设计。**仅文档，不编码**。
> Task ID：`T041_BEGINNER_LEARNING_PHASE_2_SCOPE`。文档版本：0.1。日期：2026-06-24。
>
> **命名澄清**：项目内 `PHASE_2_FLUTTER_SHELL.md` 指 T006 导航骨架（已发布）。本阶段为 **v1.1.0 之后的教学阶段 2**（编号为 T041，沿用项目既有 Task ID 风格），与 `PHASE_2_*` 不同。本文档不复用 `PHASE_2` 命名以避免覆盖既有阶段编号。

---

## 1. 用户目标

| 维度 | 描述 |
|------|------|
| 身份 | v1.1.0 真实音频 MVP 用户（已能在 7 天计划下做 C / Am / F / G 和弦、单音、节拍器、真实录音 / 回放 / 自评） |
| 痛点 | Day 4 "C ↔ Am 转换"任务只有和弦切换目标，**没有节奏 / 扫弦指引**，用户不知道"每拍弹什么、怎么扫弦"；Day 5 / Day 6 同样缺乏节奏型引导 |
| 目标 | 在不破坏 7 天闭环的前提下，给已有 Day 4 / Day 5 / Day 6 任务增加**短教学说明 + 可视化下扫节奏指引 + 分步骤练习**，让初学者第一次就能"按拍弹出来" |
| 不做什么 | 不做 AI 评分 / 自动调音精度重做 / 版权曲目 / 账号云同步 / iOS 发布（与 PRD §7 一致） |

---

## 2. 范围与边界（明确不做的内容）

| 不做 | 原因 |
|------|------|
| 自动调音频率识别 | PRD §7.6 明示；T009 已声明 ±10 cents 为体验目标 |
| AI 评分 / 节奏识别 / 和弦识别 | PRD §7.2 明示 |
| 商业歌曲 / 版权曲目 / 曲库 | PRD §7.4 明示；本阶段使用**原创练习片段**（CC0 / 公版） |
| 账号 / 云同步 / 推送 | PRD §7.1 明示；不申请 `INTERNET` 权限 |
| iOS / iPad / 平板 UI | PRD §7.5 明示；T004 不创建 `ios/` 目录 |
| 节奏型存储 / 多节奏型切换 / 节拍器改 domain | PRD §6.5 明示"节奏型 不做"；节拍器仅 4/4 / 50-200 BPM |
| 节拍器改 UI 控件 / 鼓机 / 后台播放 | PRD §6.5 明示 |
| 替换 Day 1-7 现有任务内容 | 已发布 v1.1.0 行为不破坏；本阶段为**教学增强层**叠加 |
| 新增依赖 / 修改 `pubspec.yaml` | 仅做设计；后续实现任务由 GPT 首席架构师独立拆解 |
| 修改 Drift schema / PracticeRecord 字段 | 仅做设计；后续实现任务由 GPT 首席架构师独立拆解 |

---

## 3. 第一个垂直切片：`C ↔ Am 和弦转换 + 4/4 基础下扫节奏`

### 3.1 切片定位（与已发布的 Day 4 任务关系）

**重要**：v1.1.0 已发布的 `practice_plan_constants.dart` Day 4 已含以下任务：
- `day4_tuner`（调音）
- `day4_chord_switch`（C ↔ Am 转换，路由 `/chords/c`）
- `day4_metronome`（节拍器 80 BPM）
- `day4_recording`（录音）
- `day4_self_assessment`（自评）

本切片**不替换** Day 4 任务，**只叠加**教学增强层：
1. 在 `day4_chord_switch` 详情内追加**教学卡片**（短说明 + 4/4 下扫可视化）；
2. 在 `day4_metronome` 页追加**下扫节奏指引叠加层**（静态 SVG / PNG 箭头，纯视觉，不改 `MetronomeSetting`，不存节奏型）；
3. 在 `day4_recording` / `day4_self_assessment` 页**保留**真实录音 + 自评流程，**不改动**。

### 3.2 第一节课完整流程（用户视角，原创练习片段）

> 教学片段：`C ↔ Am` 4/4 下扫节奏。**原创**，非任何已有歌曲片段；和弦进行为通用音乐理论（无版权）。

| 步骤 | UI 组件 | 内容 | 复用现有能力 |
|------|---------|------|---------------|
| 1. 短教学说明 | `LessonIntroCard` | "本节目标：在节拍器 80 BPM 下，每拍下扫一次，循环 C → Am → C → Am，每小节 4 拍共 2 个和弦。" | 文字内容 |
| 2. 可视化节奏谱 | `StrumPatternDiagram`（静态 SVG 资源 `assets/strum_patterns/c_am_down_4x4.svg`） | 4 个下扫箭头按节拍位置对齐；CC0 / 自绘 | 自绘资源 |
| 3. 分步骤练习 | `LessonStepList` | Step 1: 慢速按拍（60 BPM）；Step 2: 80 BPM 全速；Step 3: 录音复盘 | 节拍器 / 录音 |
| 4. 节拍器辅助 | 跳转 `/metronome`，默认 80 BPM，下扫节奏**作为视觉指引叠加层**显示在节拍器 UI 顶部（不改 BPM 控件 / 不改 domain） | 节拍器现有逻辑 + 静态叠加层 | 完整复用 `MetronomeController` |
| 5. 录音复盘 | 跳转 `/recording`，最长 5 分钟，本地 m4a | 完整复用 `RecordingPracticeController` + T031 / T031E | 零改动 |
| 6. 完成状态 + 练习记录 | 自评 → `PracticeRecordRepository.save`，`audioFilePath` 关联 m4a 路径 | 完整复用 T013.4A / T013.4B / T013.4C | 零改动 |

### 3.3 切片的原创练习内容（明示非版权）

| 内容 | 来源 | 版权状态 |
|------|------|----------|
| `C ↔ Am` 和弦进行 | 通用音乐理论（I → vi） | 无版权 |
| 4/4 下扫节奏（每拍下扫 1 次） | 通用节奏型 | 无版权 |
| 教学文案（中文） | 项目 owner 原创 | CC0 |
| 下扫节奏可视化 SVG | 项目 owner 自绘 | CC0 |
| 60 BPM 慢速 → 80 BPM 全速 | 通用节奏训练法 | 无版权 |

---

## 4. 最小曲谱 / 节奏数据模型（仅设计，后续由独立实现任务落盘）

### 4.1 新增常量（不入数据库）

**存储位置**：`lib/core/constants/lesson_constants.dart`（新增，由 05-music-domain-expert 在后续实现任务中维护）

| 模型 | 字段 | 类型 | 说明 |
|------|------|------|------|
| `Lesson` | `id` | String | 如 `"lesson_c_am_down_4x4"` |
| `Lesson` | `title` | String | "C ↔ Am 4/4 下扫入门" |
| `Lesson` | `linkedTaskIds` | List\<String\> | 关联 7 天计划任务 ID（如 `["day4_chord_switch"]`），用于叠加教学卡 |
| `Lesson` | `steps` | List\<LessonStep\> | 分步骤练习列表 |
| `Lesson` | `strumPatternId` | String | 关联 `StrumPattern.id` |
| `LessonStep` | `order` | int | 步骤序号 |
| `LessonStep` | `bpm` | int | 60 / 80（不改节拍器 domain） |
| `LessonStep` | `instruction` | String | "慢速按拍，注意每拍下扫一次" |
| `StrumPattern` | `id` | String | 如 `"strum_down_4x4"` |
| `StrumPattern` | `name` | String | "4/4 全下扫" |
| `StrumPattern` | `beatsPerMeasure` | int | 4 |
| `StrumPattern` | `svgAssetPath` | String | `assets/strum_patterns/down_4x4.svg` |
| `StrumPattern` | `direction` | StrumDirection enum | `down`（仅下扫，不引入上扫；后续可扩 `up` / `downUp` / `mute`） |

### 4.2 为什么不修改 PracticeRecord / Drift schema

| 决策 | 原因 |
|------|------|
| Lesson 仅作为**常量**（不入数据库） | 与 `BuiltInPracticePlan` / `Chord` / `PracticeTask` 风格一致；保持 schemaVersion = 1 不升级 |
| PracticeRecord 不新增 `lessonId` / `strumPatternId` 字段 | 教学卡是**叠加层**，不污染主记录；用户从任务入口进入 Lesson，Lesson 完成后回到原任务标记完成 |
| 节拍器不存储节奏型 | PRD §6.5 明示"节奏型 不做"；SVG 是**静态可视化资源**，不参与 BPM 计算 / 不改 `MetronomeSetting` |

### 4.3 与现有能力的复用路径

| 现有能力 | 复用方式 | 修改范围 |
|----------|----------|----------|
| `practice_plan_constants.dart` Day 4 任务 | `linkedTaskIds` 关联，**不改** | 零 |
| `MetronomeController` + `MetronomePage` | 复用 BPM 控件 / 开始停止；**仅追加**静态 SVG 叠加层 | 加 widget，不改 domain |
| `RecordingPracticeController` + T031E 真实音频 | 完整复用（录音 / 回放 / 互斥 / 自然完成恢复） | 零 |
| `PracticeRecordRepository` + T013.4A | 完整复用（自评落盘 + 关联 m4a） | 零 |
| `ChordLibraryPage` / `ChordDetailPage` | 在 C / Am 详情页**追加** `LessonIntroCard` 入口（点击进入 Lesson） | 仅追加 widget，不改 domain |
| `TunerPage` | 完整复用 | 零 |
| `assets/chord_diagrams/` | 现有 C / Am PNG 不变；新增 `assets/strum_patterns/down_4x4.svg` | 新增资源，不修改既有 |

### 4.4 页面与导航（仅设计）

| 新页面 / 组件 | 路由 | 说明 |
|---------------|------|------|
| `LessonPage`（新页面） | `/lessons/:lessonId` | 教学卡片 + 分步骤 + 跳转入口 |
| `LessonIntroCard`（新组件） | 嵌入 `ChordDetailPage` / `MetronomePage` | 短说明 + 跳 LessonPage 按钮 |
| `StrumPatternDiagram`（新组件） | 嵌入 `LessonPage` / `MetronomePage` 顶部 | 静态 SVG，纯视觉 |
| `LessonStepList`（新组件） | 嵌入 `LessonPage` | 步骤列表 + 跳转节拍器 / 录音 |

> **不修改** 7 天计划页 / 调音器页 / 历史记录页 / 设置页。

---

## 5. 验收标准（文档级，仅做设计验证，后续实现任务独立拆解）

| # | 项目 | 通过条件（仅文档） |
|---|------|-------------------|
| 1 | 切片定位 | 文档明确本切片是 Day 4 任务**叠加层**，不替换 Day 4 任何任务 |
| 2 | 复用既有能力 | 文档明确每个 UI 组件对应的现有 Controller / 路由 / Repository，**不引入新依赖 / 不修改 Drift schema / 不改节拍器 domain** |
| 3 | 原创内容 | 文档列出所有练习内容来源 + 版权状态，**无任何商业歌曲** |
| 4 | 边界声明 | 文档复述 PRD §7 全部不做项，并明确本阶段不增加 / 修改权限 |
| 5 | 可扩展 | `Lesson` / `LessonStep` / `StrumPattern` 常量模型支持 Day 3（C 单和弦下扫） / Day 5（F / G 下扫） / Day 6（C-Am-F-G 循环下扫）后续切片扩展 |
| 6 | 风险已识别 | 文档至少列出 3 项风险（见 §7） |
| 7 | 任务拆分 | 文档给出 3-5 个后续实现任务及顺序（见 §6） |

---

## 6. 后续实现任务及顺序（不替代 GPT 首席架构师独立拆解）

> 以下任务**仅作为方向提示**，必须由 GPT 首席架构师出具独立 Prompt 后才能启动；本任务**不编码**、**不修改**任何代码 / 测试 / 依赖 / Drift schema。

| 顺序 | Task ID | 任务 | 主责 Agent |
|------|---------|------|-----------|
| 1 | `T042_LESSON_CONTENT_DESIGN` | 由 05-music-domain-expert 设计 6 个 Lesson 的完整内容（C 单和弦下扫 / C↔Am 4/4 下扫 / F / G / C-Am-F-G 循环 / 自由复习），全部原创 CC0 | 05-music-domain-expert |
| 2 | `T043_STRUM_PATTERN_ASSETS_AND_WIDGET` | 创建 `assets/strum_patterns/` 自绘 SVG + `StrumPatternDiagram` widget + `LessonIntroCard` widget + `LessonStepList` widget | 03-mobile-ui-engineer |
| 3 | `T044_LESSON_PAGE_AND_NAVIGATION` | 实现 `LessonPage` + `/lessons/:lessonId` 路由 + 在 `ChordDetailPage`（C / Am）追加 Lesson 入口 + 在 `MetronomePage` 追加静态 SVG 叠加层 | 03-mobile-ui-engineer + 02-flutter-architect |
| 4 | `T045_LESSON_TEST_AND_ACCEPTANCE` | widget test 覆盖 Lesson 入口 / 路由跳转 / SVG 渲染；不修改既有 T013 / T031 测试 | 07-qa-reviewer |
| 5 | `T046_LESSON_RELEASE_CHECKPOINT` | 真机冒烟（Day 4 → Lesson → 节拍器 → 录音 → 自评 → 历史）；更新 PRD §9 + ROADMAP + 任务台账 | 07-qa-reviewer + 用户（真机主导） |

**任务执行铁律**：每个任务独立 commit；不 push；不创建 Tag；不修改 Release 签名 / 依赖 / Drift schema；不修改既有 Controller / Repository；不修改 7 天计划常量（Day 1-7 内容不变）。

---

## 7. 风险与缓解

| 风险 | 级别 | 缓解 |
|------|------|------|
| **R-01**：教学卡与现有 Day 4 任务重复，用户困惑"两个入口做同一件事" | 高 | UI 上明确"教学卡是辅助"，原任务卡片继续存在；Lesson 不创建独立 PracticeRecord |
| **R-02**：节拍器叠加 SVG 被误读为"节拍器支持节奏型切换" | 中 | SVG 静态、不可点击；附文字"本节使用的下扫节奏"；不修改 `MetronomeSetting` |
| **R-03**：Lesson 内容硬编码 Day 4，后续 Day 3 / 5 / 6 切片难以扩展 | 中 | Lesson / LessonStep / StrumPattern 设计为**常量化枚举 + 列表**，新增切片仅追加常量 |
| **R-04**：误把教学卡写成必须完成才能标记任务 | 中 | 任务完成状态由原 `day4_chord_switch` 决定；Lesson 仅作为可选入口 |
| **R-05**：测试覆盖不足，导致 SVG / 路由回归无人守 | 低 | T045 widget test 覆盖关键跳转；既有 T031 / T013 测试零破坏 |
| **R-06**：把"原创练习片段"误称为"曲库"，未来引入版权曲目 | 中 | 设计文档显式声明所有内容来源 + 版权状态；后续 Content Policy 沿用 PRD §12 |

---

## 8. 与既有阶段 / 任务的关系

| 既有阶段 / 任务 | 与本阶段关系 |
|----------------|--------------|
| `PHASE_2_FLUTTER_SHELL.md`（T006） | 命名无关；本阶段是**教学阶段 2**，不是 Flutter Shell Phase 2 |
| `PHASE_4_PRACTICE_SYSTEM.md`（T010-T012） | 节拍器 / 录音 / 自评已发布；本阶段复用，不重做 |
| `PRD §9`（7 天计划） | Day 1-7 内容不变；本阶段仅**叠加**教学卡 |
| `PRD §7`（不做范围） | 全部沿用；不新增 / 修改任何权限 |
| `DATA_MODEL_DRAFT.md` §3 | `Lesson` / `LessonStep` / `StrumPattern` 作为**新常量**加入，遵循"内置常量不入数据库"约定 |
| T027 / T029 / T030 / T031 / T031E 真实音频 | 完整复用；不修改 `RecordingPracticeController` / `RealAudioRecorderService` / `RealAudioPlaybackService` |
| T013.4A / T013.4B / T013.4C 本地记录 | 完整复用；不修改 `PracticeRecordRepository` / schemaVersion |

---

## 9. 多 Agent 协作记录

| 角色 | 任务 | 结论 |
|------|------|------|
| Primary Agent | 完成本设计文档调研与落盘 | 完成（见 §10 三步反思） |
| Product / Flutter Architecture Reviewer | 独立只读审查 | **Blocker → 已修订**（见 §9.1） |

### 9.1 Reviewer 反馈与修订

| Blocker | 修订 |
|---------|------|
| B-1：命名冲突（项目内 `PHASE_2_*` 指 T006） | 改用 `T041_BEGINNER_LEARNING_PHASE_2_SCOPE` 作为 Task ID 与文档标题，明确与 `PHASE_2_FLUTTER_SHELL` 不同 |
| B-2：内容重叠（Day 4 已含 C↔Am + 节拍器 + 录音 + 自评） | §3.1 明确本切片为**叠加层**而非替换，列出 Day 4 既有任务清单并声明零修改 |
| B-3：节拍器跨过 PRD §6.5 "节奏型 不做" 边界 | §4.3 明确 SVG 是**静态可视化资源**，不改 `MetronomeSetting` / 不存节奏型 / 不可点击 |
| B-4：领域模型缺乏可扩展性说明 | §4 新增 `Lesson` / `LessonStep` / `StrumPattern` 常量模型，支持 Day 3 / 5 / 6 后续切片 |

修订后 Reviewer 重新判定：**Approved**。

---

## 10. 三步反思（精简版）

### 10.1 【初步实现】
- 第一节课选 `C ↔ Am` 4/4 下扫节奏；新增 `Lesson` / `StrumPattern` 常量；复用 `MetronomeController` / `RecordingPracticeController` / `PracticeRecordRepository`；新增 1 个路由 `/lessons/:lessonId` + 3 个 widget。

### 10.2 【自我找茬】（至少 3 项风险）
- 风险 1：与 Day 4 既有任务重复 → 必须明确为叠加层而非替换。
- 风险 2：节拍器 SVG 容易被理解为"支持节奏型切换" → 静态资源 + 文字说明 + 不改 domain。
- 风险 3：Lesson 常量硬编码 Day 4 → 常量设计须支持后续切片扩展。
- 风险 4：误把 Lesson 写成必选流程 → 原任务完成状态由 Day 4 决定。
- 风险 5：测试覆盖不足 → T045 widget test 明确覆盖跳转。

### 10.3 【终极交付】
- 已确认仅做设计、不编码；不修改既有 Controller / Repository / Drift schema / 节拍器 domain；新增资源 + widget + 路由 + Lesson 常量均可独立拆分；3-5 个后续实现任务按顺序展开；明确不做 PRD §7 全部边界；原创 CC0 内容可审计。

---

## 11. 文档版本

| 版本 | 日期 | 修改内容 |
|------|------|----------|
| 0.1 | 2026-06-24 | T041 初稿：Phase 2 初学者教学设计 + 第一个垂直切片（C↔Am 4/4 下扫）；含 Reviewer Blocker → 修订 → Approved 记录 |

---

## 12. 引用

- `docs/PRD.md` §7 不做范围 / §9 7 天计划 / §10 数据需求 / §12 内容版权
- `docs/DATA_MODEL_DRAFT.md` §2 PracticeRecord / §3 内置常量 / §13 Drift schema
- `lib/core/constants/practice_plan_constants.dart` Day 1-7 既有任务定义
- `docs/dev/REAL_AUDIO_MVP_SDD.md` §8 录音 Controller 状态机（T031 / T031E）
- `docs/MULTI_AGENT_WORKFLOW.md` §10.4 Prompt 强制要求（Primary / Review / Writable Scope）