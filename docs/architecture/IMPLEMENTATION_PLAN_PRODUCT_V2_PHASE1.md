# Product V2 Phase 1 Implementation Plan

> Task ID：`T049_PRODUCT_V2_PHASE1_IMPLEMENTATION_PLAN`
> 上游：`docs/PRD_v2.md` v0.3（已批准）/ `docs/architecture/SDD_V2.md` v0.4（已批准）/ `docs/architecture/TDD_PRODUCT_V2_PHASE1.md` v1.0（已批准）
> 起始 HEAD：`e1080f7` | 测试基线：744 | 文档长度目标：≤ 500 行
> 最后更新：2026-06-25 | 版本：1.1
> 状态：**Implementation Plan（仅规划；不实现任何生产代码；不修改测试；不执行 OP-1 / OP-2 Spike；不升级 Drift schema；不修改 Manifest / pubspec / AppDatabase）**
> 是否引入依赖 / 修改 Android 配置 / 运行 build_runner / 启动 Spike：**否**
> 多 Agent 协作：Primary Plan Architect（主会话）/ Implementation Plan Reviewer `t049-implementation-plan-reviewer`（**Pending**）；TDD v1.0 三 Reviewer 已落盘（T048）；SDD v0.4 二元裁决闭环；T047B Flutter Data Architecture Reviewer 二元裁决闭环；不重复运行 Product Alignment Reviewer（不改变 PRD 范围）。
>
> **v1.1 修订**（三步反思后）：① T1 / T2 显式区分"真机实验主体"与"ADR 收口产物"，避免被误读为"写 ADR 文档"任务；② T9 显式 P1/P2 边界（内存包装层 vs P2 v2→v3 升级时扩列），避免被误读为"已开始 Drift 升级"；③ T11 显式降级路径 PASS 语义（±20 cents 实验性 / 静态表 / OP-1 C/D 都属于 PASS 但 PHASE1_GATE.md 必须显式标注）；④ §3.2 并行约束现实化（Reviewer 池限制 + 单真机 Spike 占用 + 主会话注意力约束）；⑤ §4 Demo C 时间窗警告（1-2 sprint，不承诺 3 任务周期内完成）。

---

## 0. 文档目的与范围声明

把 TDD v1.0 §9 的候选工作包整理为**可执行、可验证、低风险**的任务序列，并明确每个任务的输入、输出、边界、验证方式、是否需要真机验收。本 Implementation Plan **不**写生产代码；**不**启动 OP-1 / OP-2 真机 Spike；**不**升级 Drift schemaVersion；**不**修改 Manifest / pubspec / AppDatabase。后续 Implementation Task（T050+）启动必须由主会话出具独立 Prompt。

**P1 边界铁律（与 PRD §6 + SDD §8 + TDD §0 一致）**：
1. P1 是 Foundation，不是第一互动切片完整实现。
2. P1 不扩展 Day 3/5/6/7 课程（PRD §5.2 + SDD §8）。
3. P1 不实现 P2 LessonSessionController 完整闭环（属 P2 任务）。
4. P1 不把双 record 实例并行作为已证明架构（SDD §7.2：A 方案 = **首选 Spike 验证候选**，**未**通过 T048A 真机 Spike + ADR **前不**作为 P1 正式方案）。
5. P1 不锁定最终音频算法（SDD §3.6 / §6 / TDD §2）。
6. P1 不提前引入 `INTERNET` 权限（PRD §8.3 + SDD §8）。
7. P1 默认保持 Drift schemaVersion=2；P2 引入 `scores` 时按 SDD v0.4 §3.8 累进式 `if (from < N)` 链升级 v2→v3。

---

## 1. 总体执行原则

### 1.1 节奏铁律

PRD §6 + TDD §9.2：任意连续 3 个开发任务必须产生真机可见成果（APK 可装、用户能感知）。Implementation Plan 拆为 **3 个 Demo 组 + 1 个 P1 关闭门**，每组 APK 真机录屏作为用户可感知证据。

### 1.2 Spike 优先

OP-1（A 方案真机 Spike）与 OP-2（调音器精度 Spike）是 P1 调音器实时反馈与 P2 互动闭环的前置。**两个 Spike 在 P1 启动时立即并行**（不串行），与和弦库 / 单音库补齐任务并行；其结论（ADR）决定 T3-Tuner-RealTime 与 T1-OP1-Decision 的实施边界。

### 1.3 风险分级

- **低风险**：纯静态资源 / 内存包装层 / widget 级 — Primary + 1 Reviewer。
- **中风险**：跨 Controller 协调 / Provider 注入 / Widget Test — Primary + 2 Reviewer。
- **高风险**：音频架构 / 实时信号链 / 跨服务生命周期 / Drift schemaVersion 边界 / Release 工程化 — Primary + 最多 3 Reviewer。

Reviewer 全部**只读**，不修改文件；裁决**仅**二选一：`Approved` / `Blocker`。**禁止** `Approved with Conditions` / `Blocker equivalent` / 模糊裁决。`Blocker` 必须修复并复审；**不能带 Blocker 提交**。

### 1.4 契约护栏

P1 实施时**不**修改以下既有契约：
- `RecordingPracticeController` / `RealAudioRecorderService` / `RealAudioPlaybackService` / `AudioFileStorageService` / `MicrophonePermissionService` 公共 API（T027 / T029 / T030 / T031 / T031C / T031E / T031I / T032 / T033 / T034 / T035 / T035A / T035B / T037B / T037B1 / T037B2 / T038B 既有契约）。
- `MetronomeSettings` 值类型字段（T010：`bpm` / `minBpm` / `maxBpm` / `beatsPerBar` / `soundEnabled` KEEP）。
- `UserSettingsRepository` 公共 API（T013.2 既有 6 字段契约）。
- `TunerController` 公共状态形状（T011 既有 `TunerState` 含 `strings` / `confirmedStringNumbers` KEEP）。
- `AudioPlaybackState` / `AudioRecorderState` enum。
- `router.dart`（9 路由 P1 不增不减）。
- `lesson_constants.dart`（P1 不扩展 Lesson；P2 才接 Session Engine）。
- `practice_plan_constants.dart`（7 天计划不动）。
- `AppDatabase`（schemaVersion=2 保持；onUpgrade 1→2 no-op 保留；不调 `m.createAll` 在 `beforeOpen` 静默建业务表）。

---

## 2. 任务拆分（11 个正式实施任务）

> TDD §9.1 候选工作包映射到 11 个正式任务（T1-T11）。每个任务必须有 Task ID / 目标 / 输入文档 / 可修改文件范围 / 禁止事项 / 关键边界 / 测试要求 / 真机需求 / Reviewer 配置 / 完成定义（DoD）/ 失败回滚 / 是否允许 commit 12 项。Reviewer ID 在每次启动任务时由主会话分派，本表给出**类型**而非 ID。

### T1 OP-1 Audio Capture Spike（真机实验 + ADR 落盘）

| 字段 | 内容 |
|------|------|
| **Task ID** | `T049A_OP1_AUDIO_CAPTURE_SPIKE` |
| **目标** | **真机实验主体**：用 `record ^7.1.0` 双 `AudioRecorder` 实例跑 A 方案真机 Spike（SDD §7.2）。**ADR 落盘**：基于实验证据产出 OP-1 ADR（决策门）。 |
| **任务定位（显式区分）** | (a) **真机实验** = 任务主体（必须执行，占任务 80%+ 工作量）；(b) **ADR 落盘** = 任务收口（产物之一，非任务本身）。阅读者**不**得把此任务理解为"写 ADR 文档"；如未来仅"补 ADR 文档"应单独立项（如 T049A-ADR-LINKAGE）。 |
| **输入文档** | SDD v0.4 §7.1 / §7.2 / §7.4 + TDD §5.1 / §5.2 / §5.4 + `docs/dev/REAL_AUDIO_DEPENDENCY_SPIKE.md` §3.6 |
| **可修改文件范围** | `docs/architecture/OP1_ADR.md`（新建）+ `docs/dev/TASK_LEDGER.md`（追加 Spike 条目）+ `docs/dev/AGENT_QUALITY_METRICS.md`（追加 Scorecard）+ `e2e/spike_logs/`（新建，保存日志 / m4a / PCM 流原始数据，**不**上传）+ `tool/spike_op1_*.dart`（新建 spike 工具，**仅**测试目录） |
| **禁止事项** | 不写 `lib/` 生产代码 / 不修改 `pubspec.yaml` / 不修改 Manifest / 不升级 Drift / 不修改 `RealAudioRecorderService` 公共 API / 不动录音回放链路（T038B 既有闭环）/ 不创建占位抽象接口 |
| **关键边界** | (1) 5s / 30s / 5min 三档断点必须全部跑通；(2) m4a 完整性 = 5min 后 `stop()` 返回文件可被 `just_audio` 正常解码 + 播放；(3) PCM 连续性 = chunk 帧序号连续无丢失 / 重复 / 乱序；(4) 权限生命周期 = 双实例共享 `RECORD_AUDIO`；(5) 停止回调归属 = `MethodChannel('record_android')` `onStop` / `onCancel` 不串台；(6) 资源释放 = 双实例 dispose 后音频焦点完全释放；(7) 设备兼容矩阵 ≥ 2 设备 × 3 时长 = 6 实验；(8) ADR 必含设备 / 时长 / 数据 / 7 项必含清单结果 / 功耗 / 温度 / 内存 / 决策结论 |
| **测试要求** | 仅在测试设备上跑；**不**写自动化测试；产物保存到 `e2e/spike_logs/op1_<device>_<timestamp>.log` + `audio/`（本地生命周期 7 天） |
| **真机需求** | **必须真机**（HUAWEI CDY-AN90 / Android 10 + 至少 1 台中端 Android 13+） |
| **Reviewer 配置** | 高风险（音频架构） — Primary + **3 Reviewer**（Audio Architecture + Flutter Data + Android QA） |
| **完成定义** | (1) ADR 落盘且 `Approved`（0 Blocker）；(2) 6/6 Spike 实验通过 + 7 项必含清单全部 PASS；(3) TASK_LEDGER + AGENT_QUALITY_METRICS 同步更新 |
| **失败回滚** | A 方案失败 → 选 C（事后解码）或 D（FFI）；A / C / D 全失败 → P1 延长 1 sprint；P2 不开门；m4a 录音 + T030 播放 + T031E LoopMode 全部保留 |
| **是否允许 commit** | 允许（仅文档 + 测试 spike 工具 + `e2e/spike_logs/`，**不**含 `lib/`） |

### T2 OP-2 Tuner Accuracy Spike（真机实验 + ADR 落盘）

| 字段 | 内容 |
|------|------|
| **Task ID** | `T049B_OP2_TUNER_ACCURACY_SPIKE` |
| **目标** | **真机实验主体**：调音器实时反馈算法真机 Spike。**ADR 落盘**：基于实验证据产出 OP-2 ADR（决策门）。 |
| **任务定位（显式区分）** | 同 T1：真机实验是任务主体（80%+ 工作量），ADR 是收口产物。 |
| **输入文档** | SDD v0.4 §7.3 + TDD §5.3 + `docs/dev/REAL_AUDIO_DEPENDENCY_SPIKE.md` §3.6 |
| **可修改文件范围** | `docs/architecture/OP2_ADR.md`（新建）+ `docs/dev/TASK_LEDGER.md` + `docs/dev/AGENT_QUALITY_METRICS.md` + `e2e/spike_logs/` + `tool/spike_op2_*.dart`（测试 spike 工具） |
| **禁止事项** | 不写 `lib/` 生产代码 / 不修改 `pubspec.yaml` / 不修改 Manifest / 不动 T011 既有 `TunerState` 形状 / 不锁定 FFT / YIN / autocorrelation / spectral flux 等具体算法（仅评估，由 ADR 决定） |
| **关键边界** | (1) 30 段录音 × G/C/E/A 四弦 × 1s / 3s / 5s 三档；(2) 测量指标 = 命中率（±10 cents 内占比）+ 误报率 + 响应延迟；(3) 通过 = ±10 cents 命中率 ≥ 70% on-device（PRD §8.2）；(4) 失败 = 接受 ±20 cents 显式"实验性"标签 / < 50% 回退静态 GCEA 频率表 |
| **测试要求** | 仅在测试设备上跑；**不**写自动化测试；产物保存边界同 T1 |
| **真机需求** | **必须真机**（同 T1 设备） |
| **Reviewer 配置** | 高风险（音频架构） — Primary + **3 Reviewer** |
| **完成定义** | (1) ADR 落盘且 `Approved`；(2) 30 段录音命中率 ≥ 70% 或接受降级路径；(3) TASK_LEDGER + AGENT_QUALITY_METRICS 同步 |
| **失败回滚** | < 70% → ±20 cents 显式"实验性"标签；< 50% → 静态 GCEA 频率表（T003 既有降级路径）；T3-Tuner-RealTime 仍可关闭 |
| **是否允许 commit** | 允许（仅文档 + 测试 spike 工具 + spike 日志） |

### T3 OP-1 / OP-2 Decision Gate

| 字段 | 内容 |
|------|------|
| **Task ID** | `T049C_OP1_OP2_DECISION_GATE` |
| **目标** | 依据 T1 + T2 ADR 产出，决议 OP-1 = A / C / D 与 OP-2 降级策略；更新 P1 正式方案边界。 |
| **输入文档** | T1 ADR + T2 ADR + SDD §7.4 失败回退表 + TDD §9.3 |
| **可修改文件范围** | `docs/architecture/OP1_ADR.md`（追加决策段）+ `docs/architecture/OP2_ADR.md`（追加决策段）+ `docs/dev/TASK_LEDGER.md` + `docs/dev/AGENT_QUALITY_METRICS.md` |
| **禁止事项** | 不写 `lib/` / 不修改既有 ADR 内容（仅追加决策段） / 不修改 SDD / TDD |
| **关键边界** | (1) OP-1 = A 通过 → 选 A；A 失败 → C 或 D；A/C/D 全失败 → P1 延长；(2) OP-2 命中率 ≥ 70% → 走 ±10 cents；< 70% → ±20 cents 实验性；< 50% → 静态表；(3) Decision 必为二元裁决（Approved / Blocker） |
| **测试要求** | 无（仅决策收口） |
| **真机需求** | 否（决策收口任务） |
| **Reviewer 配置** | 中风险（架构决策） — Primary + **2 Reviewer**（Audio Architecture + Flutter Data） |
| **完成定义** | (1) 决策段落盘；(2) 所有 Blocker 已修复或接受降级；(3) 后续 T5 / T6 / T8 任务可基于决策段启动 |
| **失败回滚** | Blocker → 回到 T1 / T2 修复 |
| **是否允许 commit** | 允许 |

### T4 Metronome Audible Sound Source（CC0 click 音源）

| 字段 | 内容 |
|------|------|
| **Task ID** | `T050_METRONOME_AUDIBLE_SOUND_SOURCE` |
| **目标** | 引入 CC0 click 音源 + `MetronomeAudioSource` 抽象 + Provider；节拍器可听。 |
| **输入文档** | TDD §6.2.2 + SDD §3.4 |
| **可修改文件范围** | `assets/audio/metronome_click_*.wav`（CC0 资产，**仅**追加，**不**删除既有资产）+ `lib/features/metronome/audio/`（新建：`metronome_audio_source.dart` 抽象 + `just_audio_metronome_audio_source.dart` 实现 + `metronome_audio_source_provider.dart` Provider）+ `lib/features/metronome/application/metronome_controller.dart`（**仅**通过 Provider 注入 `MetronomeAudioSource`，**不**改既有字段）+ `test/features/metronome/`（新增 fake + widget 测试）+ `docs/dev/TASK_LEDGER.md` + `docs/dev/AGENT_QUALITY_METRICS.md` |
| **禁止事项** | **不**引入新顶层依赖（沿用 `just_audio ^0.10.5` T030 既有 + 项目 assets 体系）/ **不**修改 `MetronomeSettings` 值类型字段 / **不**修改 T010 既有 `MetronomeController` 公共 API（仅内部注入）/ **不**修改录音页 / 详情页 / 路由 / Manifest |
| **关键边界** | (1) CC0 资产必须合法来源 + 试听验证；(2) `MetronomeAudioSource` 由独立 Provider 持有，**不**嵌入 `MetronomeController` 构造；(3) `MetronomeController` 通过 Provider 注入（**不**硬编码）；(4) `volume` 字段（∈ [0, 1]）仅作用于 `MetronomeState`（Controller 可变副本），**不**改 `MetronomeSettings` 值类型；(5) `BeatTick` 流是 P1 NEW（与 TDD §2.2 / §6.2.2 同步） |
| **测试要求** | 单元（Fake `MetronomeAudioSource`）+ Widget（MetronomePage 可听反馈）+ Controller（BPM 边界 TC-3） |
| **真机需求** | **必须真机**（节拍器可听是用户感知信号） |
| **Reviewer 配置** | 中风险（音频 + Controller） — Primary + **2 Reviewer**（Audio Architecture + Flutter Architect） |
| **完成定义** | (1) 80 BPM 4/4 拍可听 + accent 区分 downbeat；(2) Fake `MetronomeAudioSource` 单元测试 PASS；(3) BPM 边界 TC-3 PASS；(4) 自动化测试通过 + 测试基线恒等或净增；(5) Reviewer `Approved` |
| **失败回滚** | CC0 资产不可用 → 沿用项目内既有 assets 替换；测试不通过 → 修复 Fake 或 Controller 注入路径 |
| **是否允许 commit** | 允许（lib / test / assets / doc） |

### T5 Metronome P1 Adjustment（Controller 扩展 + BeatTick 流 + 4/3 子节奏）

| 字段 | 内容 |
|------|------|
| **Task ID** | `T051_METRONOME_P1_ADJUSTMENT` |
| **目标** | P1 ADJUST 注入 `MetronomeAudioSource`（沿用 T4 既有 Provider）+ 发布 `BeatTick` 流 + `volume` 字段。 |
| **输入文档** | TDD §6.2.2 + §6.4 + SDD §3.4 |
| **可修改文件范围** | `lib/features/metronome/application/metronome_controller.dart`（ADJUST：注入 `MetronomeAudioSource` + 派生 `BeatTick` 流 + `MetronomeState` 增加 `volume`）+ `lib/features/metronome/application/metronome_controller_provider.dart`（既有 Provider 扩展）+ `lib/features/metronome/presentation/metronome_page.dart`（绑定音量 UI）+ `test/features/metronome/`（扩展 Controller / Widget 测试） |
| **禁止事项** | **不**改 `MetronomeSettings` 值类型字段 / **不**改 T010 既有 `MetronomeController` 公共方法签名（仅扩展）/ **不**存储节奏型（PRD §4.4 接受静态 SVG） / **不**引入新顶层依赖 |
| **关键边界** | (1) `BeatTick` 含 `beatIndex` / `barIndex` / `isDownbeat` / `sessionMonotonicMs`（会话单调时钟 = Dart `Stopwatch`，**不**用 `DateTime.now`）；(2) `volume` 仅作用于 `MetronomeState`；(3) BPM 边界 = `minBpm ≤ bpm ≤ maxBpm` 不变 |
| **测试要求** | Controller（BeatTick 派生 + 边界 + dispose 幂等）+ Widget（音量 slider 联动） |
| **真机需求** | **必须真机**（用户可见行为：可听 + 音量调节） |
| **Reviewer 配置** | 中风险（Controller + 音频） — Primary + **2 Reviewer** |
| **完成定义** | (1) MetronomePage 绑定 `volume` 字段且 UI 联动；(2) `BeatTick` 流单元测试 PASS；(3) Reviewer `Approved` |
| **失败回滚** | 注入冲突 → 回退到 T4 既有 Provider 路径；测试不通过 → 修复 Controller |
| **是否允许 commit** | 允许 |

### T6 Chord Library Expansion to 7 Chords（+G7/Dm/Em）

| 字段 | 内容 |
|------|------|
| **Task ID** | `T052_CHORD_LIBRARY_EXPANSION_TO_7` |
| **目标** | `kBuiltInChords` 数组追加 G7 / Dm / Em 共 7 个和弦（C / Am / F / G + G7 / Dm / Em）。 |
| **输入文档** | TDD §1（PRD §7.2 L5）+ §2.2 + §7.2 TC-1 + SDD §3.1 |
| **可修改文件范围** | `lib/features/chord_library/data/built_in_chords.dart`（追加 3 项）+ `test/features/chord_library/`（扩展 TC-1）+ `docs/dev/TASK_LEDGER.md` + `docs/dev/AGENT_QUALITY_METRICS.md` |
| **禁止事项** | **不**新增和弦字段 / **不**修改既有 4 个和弦 / **不**引入 SVG 资源（T043 既有静态资产不动）/ **不**扩展路由 / **不**改 `Chord` 域模型 |
| **关键边界** | TC-1 不变量：`kBuiltInChords.length == 7`；包含 `C / Am / F / G + G7 / Dm / Em`；每个 `chordVoicing.fingers.length ≤ 4` |
| **测试要求** | 单元 TC-1（纯 Dart；不变量断言） |
| **真机需求** | 是（7 和弦库全显示） |
| **Reviewer 配置** | 低风险（纯静态常量） — Primary + **1 Reviewer**（Product Alignment） |
| **完成定义** | (1) 7 和弦全显示；(2) TC-1 PASS；(3) Reviewer `Approved` |
| **失败回滚** | 不变量违例 → 修正和弦指法 |
| **是否允许 commit** | 允许 |

### T7 Single Note Expansion to 7 Notes（+B）

| 字段 | 内容 |
|------|------|
| **Task ID** | `T053_SINGLE_NOTE_EXPANSION_TO_7` |
| **目标** | `kBuiltInSingleNotes` 数组追加 B 单音，共 7 个音名（C / D / E / F / G / A + B）。 |
| **输入文档** | TDD §1（PRD §7.2 L6）+ §2.2 + §7.2 TC-2 + SDD §3.1 |
| **可修改文件范围** | `lib/features/single_note_practice/data/built_in_single_notes.dart`（追加 1 项）+ `test/features/single_note_practice/`（扩展 TC-2）+ `docs/dev/TASK_LEDGER.md` + `docs/dev/AGENT_QUALITY_METRICS.md` |
| **禁止事项** | **不**修改既有 6 个单音 / **不**扩展路由 / **不**改 `SingleNote` 域模型 |
| **关键边界** | TC-2 不变量：`kBuiltInSingleNotes.length == 7`；含 `C / D / E / F / G / A + B`；每条 `fret ∈ [0, 12]` |
| **测试要求** | 单元 TC-2（纯 Dart） |
| **真机需求** | 是（7 单音库全显示） |
| **Reviewer 配置** | 低风险（纯静态常量） — Primary + **1 Reviewer** |
| **完成定义** | (1) 7 单音全显示；(2) TC-2 PASS；(3) Reviewer `Approved` |
| **失败回滚** | 不变量违例 → 修正 fret / 指法 |
| **是否允许 commit** | 允许 |

### T8 Tuner Real-Time Feedback Implementation（依赖 OP-2 决策）

| 字段 | 内容 |
|------|------|
| **Task ID** | `T054_TUNER_REAL_TIME_FEEDBACK` |
| **目标** | `TunerController` REFACTOR：注入 `TunerEngine` + 派生 `TunerReading` 流（与既有 `TunerState` 并存，**不**替换）。 |
| **输入文档** | TDD §6.2.1 + §6.4 + §3.1 + SDD §3.2 + T2 OP-2 ADR（已落盘） |
| **可修改文件范围** | `lib/features/tuner/`（REFACTOR：新增 `tuner_engine.dart` 抽象 + 实现 + Provider + `tuner_reading.dart` 值类型 + Controller REFACTOR 注入 + UI 适配显示 cents / 音名）+ `test/features/tuner/`（扩展 Fake + Controller + Widget）+ `docs/dev/TASK_LEDGER.md` + `docs/dev/AGENT_QUALITY_METRICS.md` |
| **禁止事项** | **不**替换 `TunerState` 形状（既有 `strings` / `confirmedStringNumbers` KEEP，新增 `TunerReading` 流并存） / **不**引入新顶层依赖（沿用 `record ^7.1.0` T029 既有）/ **不**实现音高识别 / 和弦识别 / 评分（属 P3） / **不**实现 ±10 cents 之外精度提升（属 P3） / **不**改 `MicrophonePermissionService` 公共契约（T027 既有） |
| **关键边界** | (1) `TunerEngine` 抽象按 TDD §6.2.1 契约；(2) 算法实现由 OP-2 ADR 决定（**不**在 TDD / SDD / Implementation Plan 锁定 FFT / YIN / autocorrelation 等）；(3) 错误契约 = `TunerPermissionDeniedException` / `TunerAudioStartFailedException` / `TunerDisposedException`；(4) 文案不暴露绝对路径 / 异常类名 / PII；(5) `dispose()` 不调底层 service dispose（沿用 T038B 契约）；(6) 命中率 < 70% → 走 ±20 cents 显式"实验性"标签；(7) 命中率 < 50% → 静态 GCEA 频率表（T003 既有） |
| **测试要求** | TC-6（权限拒绝降级）+ TC-7（录音启动失败）+ TC-8（dispose 幂等）+ Fake `TunerEngine` + Controller + Widget（c / 音名显示） |
| **真机需求** | **必须真机**（调音器实时反馈是 P1 核心可见信号） |
| **Reviewer 配置** | 高风险（实时音频 + Controller + Widget） — Primary + **3 Reviewer**（Audio Architecture + Flutter Architect + Android QA） |
| **完成定义** | (1) ±10 cents 命中率 ≥ 70% on-device（OP-2 ADR 通过则强制 / 否则 ±20 cents 实验性）；(2) TC-6 / TC-7 / TC-8 PASS；(3) Reviewer `Approved` |
| **失败回滚** | 命中率 < 50% → 静态表路径（不引入新依赖 / 不破坏 T003 既有页面）；Controller dispose 路径异常 → 沿用 T038B dispose 契约 |
| **是否允许 commit** | 允许 |

### T9 Settings Repository / Settings UI Path（P1 仅内存包装层；P2 升级 v2→v3 时再扩 Drift 列）

| 字段 | 内容 |
|------|------|
| **Task ID** | `T055_SETTINGS_UI_AND_REPOSITORY_MEMORY` |
| **目标** | `SettingsPage` 暴露 `defaultBpm` / `metronomeVolume` / 反馈项开关；P1 仅在 `UserSettingsRepository` 内存包装层扩展 getter/setter（**不**新增 Drift 列）。 |
| **P1 / P2 边界（显式）** | (1) **本任务（P1）范围 = 内存包装层扩展 + SettingsPage UI**：**不**新增 Drift 列；**不**升级 `AppDatabase`；schemaVersion=2 保持；(2) **P2 升级 v2→v3 时的新增列**（`metronome_volume REAL NOT NULL DEFAULT 1.0` + `feedback_item_<key>_enabled INTEGER NOT NULL DEFAULT 1`）由 P2 Implementation Plan 决定，**不**在本任务越界做、不预先在 `app_database.dart` 写 ALTER 占位、不预先在 `UserSettingsRepository` 留 `// P2:` 注释暗示未来扩展；(3) P2 实施时再走 SDD v0.4 §3.8 累进式 `if (from < 3)` 链 + `m.addColumn`（**不**走 `beforeOpen` 静默建表）+ 类型化 `Into` 插入，触发 SDD v0.4 §3.8 TDD 8 项硬门（P1 **不**触发该 8 项硬门）。 |
| **输入文档** | TDD §6.2.3 + §6.4 + §7.2 TC-4 + SDD §3.9 |
| **可修改文件范围** | `lib/features/settings/`（SettingsPage 暴露三个开关 + Slider）+ `lib/shared/repositories/user_settings_repository.dart`（内存包装层扩展 3 个 getter/setter：metronomeVolume / 反馈项开关）+ `lib/shared/repositories/drift_user_settings_repository.dart`（内存 fallback，仅 P1 落 `InMemoryUserSettingsRepository` 路径，**不**改 Drift 列） + `test/shared/repositories/` + `test/features/settings/` + `docs/dev/TASK_LEDGER.md` + `docs/dev/AGENT_QUALITY_METRICS.md` |
| **禁止事项** | **不**新增 Drift 列（schemaVersion=2 保持）/ **不**升级 `AppDatabase` / **不**改 `UserSettingsRepository` 既有 6 字段公共 API（仅扩展 getter/setter） / **不**引入 `shared_preferences` 依赖（pubspec 无声明） / **不**修改 T013.2 既有 Drift-backed 路径 / **不**扩展路由 |
| **关键边界** | (1) Drift 列新增延后 P2 升级 v2→v3 时落地（与 `scores` 表一并）；(2) P1 仅在内存包装层暴露，**不**持久化；(3) TC-4 = `setMetronomeSettings(bpm=80, volume=0.7)` 读回一致（内存 mock） |
| **测试要求** | TC-4（内存往返）+ Fake `UserSettingsRepository` + Widget（SettingsPage 三开关） |
| **真机需求** | 是（设置页可见） |
| **Reviewer 配置** | 中风险（Repository + UI） — Primary + **2 Reviewer**（Flutter Data + Product Alignment） |
| **完成定义** | (1) SettingsPage 暴露三开关；(2) TC-4 PASS；(3) Drift 列未新增（schemaVersion 仍为 2）；(4) Reviewer `Approved` |
| **失败回滚** | 内存包装层冲突 → 移除扩展 getter/setter；Drift 路径误改 → 回滚 |
| **是否允许 commit** | 允许 |

### T10 Dark Theme Token Path

| 字段 | 内容 |
|------|------|
| **Task ID** | `T056_DARK_THEME_TOKEN` |
| **目标** | `lib/app/theme.dart` 加深色 token；**不**开用户切换 toggle。 |
| **输入文档** | TDD §1（PRD §7.2 L11）+ §7.2 TC-5 + SDD §2 |
| **可修改文件范围** | `lib/app/theme.dart`（追加 `ColorScheme.dark()` + `ThemeData.dark()` + 不开 toggle）+ `test/app/`（TC-5：深浅切换不爆）+ `docs/dev/TASK_LEDGER.md` + `docs/dev/AGENT_QUALITY_METRICS.md` |
| **禁止事项** | **不**开用户切换 toggle（Deferred 到 P5+ 或 P6+）/ **不**引入新顶层依赖 / **不**修改 HomePage / 路由 / 任何 `lib/features/**` UI / **不**改既有 token 命名空间 |
| **关键边界** | TC-5 = `MaterialApp(theme: ThemeData.dark())` 渲染 HomePage 不爆；既有 light token KEEP |
| **测试要求** | TC-5（Widget：渲染不抛） |
| **真机需求** | 是（深色 UI 用户可见） |
| **Reviewer 配置** | 低风险（theme 扩展） — Primary + **1 Reviewer**（Product Alignment） |
| **完成定义** | (1) 深色 token 生效；(2) TC-5 PASS；(3) Reviewer `Approved` |
| **失败回滚** | 渲染抛异常 → 修复 token / `ThemeData.dark()` |
| **是否允许 commit** | 允许 |

### T11 Phase 1 Integration Gate（含降级路径显式标注）

| 字段 | 内容 |
|------|------|
| **Task ID** | `T057_PHASE1_INTEGRATION_GATE` |
| **目标** | P1 关闭门收口：4 项 PRD §7.2 P0 补齐验证 + OP-1 / OP-2 ADR 落盘 + 真机录屏 + 文档同步。 |
| **降级路径显式标注（铁律）** | P1 关闭门 PASS 语义**包含**降级路径：① **调音器命中率 < 70%** 但 ≥ 50% → 接受 ±20 cents 显式"实验性"标签，**仍** PASS，但 PHASE1_GATE.md **必须**显式标注"调音器走 ±20 cents 实验性路径，不达 ±10 cents 初始目标"；② **调音器命中率 < 50%** → 回退静态 GCEA 频率表（T003 既有降级路径），**仍** PASS，但 PHASE1_GATE.md **必须**显式标注"调音器走静态表降级路径，不达 ±10 cents 也不达 ±20 cents"；③ **OP-1 A 方案失败** → 走 C 或 D 方案，**仍** PASS（用 C/D 完成 P1 调音器），但 PHASE1_GATE.md **必须**显式标注"OP-1 走 C/D 降级方案"；④ **OP-1 / OP-2 任一 Spike 失败 + 全部回退路径失败** → P1 关闭门**不**达（SD1 停止门触发），**不**写 PASS；⑤ **PHASE1_GATE.md 不得混淆"降级路径 PASS"与"完整能力 PASS"**——任何降级都必须显式文字记录；⑥ P2 关闭门 review 时**必须**重新审视降级路径（避免 P2 在降级基础上再降级）。 |
| **输入文档** | TDD §7.2 TC-1~TC-12 + SDD §8 + PRD §6 P1 关闭条件 |
| **可修改文件范围** | `docs/architecture/PHASE1_GATE.md`（新建 P1 关闭门文档）+ `docs/dev/TASK_LEDGER.md` + `docs/dev/AGENT_QUALITY_METRICS.md` + 真机录屏 / 截图（如归档需要，存放到 `docs/qa/phase1/`） |
| **禁止事项** | **不**写 `lib/` 实现代码 / **不**扩展 `lib/` / `test/` / **不**修改 Manifest / pubspec / Drift / 既有契约 |
| **关键边界** | (1) TC-1~TC-12 全部 PASS 或显式标注"待 P2 校准"；(2) OP-1 ADR + OP-2 ADR 双双 Approved；(3) 真机录屏覆盖 Demo A / B / C 三组；(4) 4 项 §7.2 P0 = 调音器实时反馈 + 节拍器可听 + 7 和弦 + 7 单音；(5) Drift schemaVersion=2 保持；(6) Manifest 无 INTERNET 权限；(7) Day 3/5/6/7 课程数量仍冻结；(8) 测试基线 ≥ 744（恒等或净增，**不**得减少） |
| **测试要求** | 重新跑全量自动化测试基线（**不**声称重新通过 744，**仅**记录"保持 744，未重跑"）；真机录屏 + 文字描述 |
| **真机需求** | **必须真机**（P1 关闭门录屏） |
| **Reviewer 配置** | 高风险（关闭门） — Primary + **3 Reviewer**（Flutter Architect + Audio Architecture + Product Alignment） |
| **完成定义** | (1) PHASE1_GATE.md 落盘；(2) 4 项 §7.2 P0 全部显式 PASS；(3) Demo A / B / C 三组录屏归档；(4) Reviewer `Approved`（0 Blocker） |
| **失败回滚** | Blocker → 回到对应任务修复；Demo A 失败 → 回退 T4 / T6 / T7；Demo B 失败 → 回退 T5 / T9 / T10；Demo C 失败 → 回退 T1 / T2 / T8 |
| **是否允许 commit** | 允许（仅 doc + 真机录屏归档） |

---

## 3. 依赖顺序

```
T1 OP-1 Spike ────────────┐
                          ├─→ T3 OP-1/OP-2 Decision ──────┐
T2 OP-2 Spike ────────────┘                                │
                                                            ├─→ T8 Tuner Real-Time ─┐
T4 Metronome Sound ───→ T5 Metronome P1 ADJUST ────────────┤                        │
                                                            │                        ├─→ T11 Phase 1 Gate
T6 Chords 7 ────────────────────────────────────────────────┤                        │
T7 Single Notes 7 ──────────────────────────────────────────┤                        │
                                                            │                        │
T9 Settings UI ─────────────────────────────────────────────┤                        │
                                                            │                        │
T10 Dark Theme ─────────────────────────────────────────────┘                        │
                                                                                     │
                              Demo A: T4 + T6 + T7 ──────────────────────────────────┤
                              Demo B: T10 + T9 + T5 ──────────────────────────────────┤
                              Demo C: T1 + T2 + T3 → T8 + T11 ───────────────────────┘
```

### 3.1 关键依赖约束

- **OP-1 ADR 通过前，不得把双 record 实例并行作为正式方案写入生产实现任务**：T8 Tuner Real-Time 必须依赖 T1 + T3 ADR；T3 未通过 → T8 走 C 或 D 方案或静态表降级。
- **OP-2 ADR 通过前，不得承诺调音器准确率达标**：T8 命中率阈值由 T2 + T3 ADR 决定。
- **Tuner real-time feedback 必须依赖 OP-2 决策**：T8 = T2 + T3 前置。
- **录音 m4a 闭环不得被 OP-1 Spike 破坏**：T1 必须 100% 保留 m4a 录音 + T030 播放 + T031E LoopMode + T038B 既有契约；任何破坏触发 P1 延长。
- **Day 3/5/6/7 课程冻结直到 P2 真机闭环通过**：T6 / T7 仅扩展和弦库 / 单音库常量，**不**动 `lesson_constants.dart` / `practice_plan_constants.dart`；T11 关闭门前 7 天计划保持 v1.1.0 不动。

### 3.2 并行可能性（现实化）

- **T1 + T2 + T4 + T6 + T7 + T10 可并行启动**（互不依赖；不同文件路径；不同 Reviewer 池）。
- **现实约束**：(a) T1 / T2 真机 Spike 需 3 名 Reviewer（Audio Architecture + Flutter Architect/Data + Android QA）；T4 需 2 名；T6 / T7 / T10 各需 1 名——Reviewer 池**不**无限，T1 / T2 启动时其他高风险任务须让位；(b) 单台真机同一时刻**只能**跑 1 个真机 Spike；T1 / T2 须在两台真机上**串行**或在不同时间窗口跑；(c) 主会话注意力有限，同一时刻**建议** ≤ 2 个高风险任务并行（其他 4 个低/中风险可继续并行）；(d) T1 / T2 完成 → 立即触发 T3 决策收口（不得拖延，否则 T8 无法启动）。
- T5 / T8 / T9 / T11 必须在 T1-T4 + T6-T7 至少完成 Demo A / B 后启动。
- T3 必须在 T1 + T2 完成后启动；T8 必须在 T3 完成后启动。

---

## 4. Demo 节奏（PRD §6 + TDD §9.2）

每 3 个开发任务形成 1 个用户可见真机 Demo。每 Demo 必须 APK 装到真机 + 录屏 + 用户可感知；任一失败 → 后续 Demo 不开始。

| Demo 组 | 任务 | 真机可见产物 | 验证命令 | 时间窗 |
|---------|------|--------------|----------|--------|
| **Demo A** | T4 + T6 + T7 | 装 APK → 节拍器可听 80 BPM 4/4 + 7 和弦库 + 7 单音库 | `flutter build apk --debug` + 真机装 + 录屏 | 短（3 任务互相独立） |
| **Demo B** | T10 + T9 + T5 | 装 APK → 深色 UI + 设置页暴露 defaultBpm / 音量 + 节拍器接入 settings.volume | 同上 | 短（3 任务互相独立） |
| **Demo C** | T1 + T2 + T3 → T8 + T11 | 装 APK → OP-1 / OP-2 ADR 落盘 + 调音器实时反馈（±10 cents 命中率 ≥ 70% 或 ±20 cents 显式"实验性"）+ P1 关闭门录屏 | 同上 + 真机调音测试 | **长**（T1+T2 真机 Spike + 3 Reviewer 审阅可能跨 sprint；T8 需等 T3 决策；T11 必须等 T8 通过） |

**Demo C 时间窗警告**：Demo C 包含真机 Spike（设备占用）+ 多次 3-Reviewer 审阅（异步延迟）+ 决策收口（T3）+ 实现（T8）+ 关闭门（T11）。**不**承诺 Demo C 在 3 个开发任务周期内完成；现实估计 **1-2 个 sprint**（4-8 周）。TDD §9.2 Demo C 节奏仅为**逻辑分组**，不约束 wall-clock 时间。

---

## 5. 多 Agent 风险分级与 Reviewer 裁决

### 5.1 风险分级汇总

| 任务 | 风险 | Primary | Reviewer 数量 | Reviewer 类型 |
|------|------|---------|---------------|---------------|
| T1 OP-1 Spike | 高（音频架构） | 主会话 | 3 | Audio Architecture + Flutter Data + Android QA |
| T2 OP-2 Spike | 高（音频架构） | 主会话 | 3 | Audio Architecture + Flutter Architect + Android QA |
| T3 Decision Gate | 中（架构决策） | 主会话 | 2 | Audio Architecture + Flutter Data |
| T4 Metronome Sound | 中（音频 + Controller） | 主会话 | 2 | Audio Architecture + Flutter Architect |
| T5 Metronome P1 ADJUST | 中（Controller + 音频） | 主会话 | 2 | Audio Architecture + Flutter Architect |
| T6 Chords 7 | 低（纯静态） | 主会话 | 1 | Product Alignment |
| T7 Single Notes 7 | 低（纯静态） | 主会话 | 1 | Product Alignment |
| T8 Tuner Real-Time | 高（实时音频 + Controller） | 主会话 | 3 | Audio Architecture + Flutter Architect + Android QA |
| T9 Settings UI | 中（Repository + UI） | 主会话 | 2 | Flutter Data + Product Alignment |
| T10 Dark Theme | 低（theme） | 主会话 | 1 | Product Alignment |
| T11 Phase 1 Gate | 高（关闭门） | 主会话 | 3 | Flutter Architect + Audio Architecture + Product Alignment |

### 5.2 Reviewer 裁决铁律

- Reviewer 只读；不修改文件。
- 裁决**仅**二选一：`Approved` / `Blocker`。
- **禁止** `Approved with Conditions` / `Blocker equivalent` / 模糊裁决。
- `Blocker` 必须修复并复审；**不能带 Blocker 提交**。
- Reviewer 报告按 `docs/dev/AGENT_REVIEW_TEMPLATE.md` 模板填写 Scope Reviewed / Evidence Checked / Findings / Verdict。
- T049 Implementation Plan Reviewer（`t049-implementation-plan-reviewer`）作为文档级 Reviewer（与 TDD 三 Reviewer 维度区分），主要审计任务拆分合理性 / 依赖顺序 / 节奏 / T047B Minor 处理 / 与 PRD / SDD / TDD 一致性。

---

## 6. T047B 遗留 Minor 处理

T047B Reviewer 留下 2 项非阻断 Minor（详见 `docs/dev/AGENT_QUALITY_METRICS.md` §4.Z T047B Scorecard）：

| ID | 内容 | 处理决策 |
|----|------|----------|
| F-1 | `TASK_LEDGER.md` line 470（T047 既有条目）保留已废弃 `else if` 字样 | **不**在本任务顺手修（属 T047 历史 ledger 措辞遗留，**不**是新债）；**不**登记新 TECH_DEBT（已在 T047B Scorecard 留痕）；本 Implementation Plan 不引用 `else if` 措辞 |
| F-2 | `ROADMAP.md` P4 Curriculum 行写"Drift schemaVersion=2 → 3"与实际 P4 升级 3→4 冲突 | **不**在本任务顺手修（属 P4 / 不阻塞 P1）；**不**登记新 TECH_DEBT（已在 T047B Scorecard 留痕）；P1 关闭门（T11）不依赖 ROADMAP P4 schemaVersion 行 |

**铁律**：T049 Implementation Plan 引用 SDD / TDD 时，**不**复制 `else if` 措辞（统一为"累进式 `if (from < N)` 链"）；引用 ROADMAP schemaVersion 时，统一用 SDD v0.4 编号（P2 = 2→3 / P4 = 3→4）。任何后续 Implementation Task 启动前必须读 T047B Scorecard + 本 Implementation Plan §6。

---

## 7. P1 关闭门（Phase 1 Gate）验收条件

### 7.1 自动化测试范围

- 单元 / Controller / Widget 测试基线 ≥ 744（**保持 744，未重跑**）。
- TC-1（7 和弦常量不变量）/ TC-2（7 单音常量不变量）/ TC-3（Metronome BPM 边界）/ TC-4（Settings 持久化往返，**P1 内存**）/ TC-5（Dark theme 切换无 widget 崩溃）/ TC-6（TunerController 权限拒绝降级）/ TC-7（TunerController 录音启动失败）/ TC-8（TunerController dispose 幂等）/ TC-9（路由 9 条路径跳转）/ TC-10（Drift schemaVersion 保持 2）/ TC-11（Drift onUpgrade 1→2 仍 no-op）/ TC-12（P1 不新增 Drift 表）全部 PASS。
- TC-13（OP-1 Spike 设备兼容矩阵）/ TC-14（调音器算法 OP-2 ±10 cents 命中率）/ TC-15（5 分钟相对漂移 ≤ 50ms 初始目标）属 P2 真机校准，**不**作为 P1 通过门。

### 7.2 真机验收范围

- Demo A 录屏：节拍器 80 BPM 4/4 可听 + 7 和弦 + 7 单音。
- Demo B 录屏：深色 UI + SettingsPage 三开关 + 节拍器接入 settings.volume。
- Demo C 录屏：OP-1 / OP-2 ADR 落盘 + 调音器实时反馈（±10 cents 命中率 ≥ 70% 或 ±20 cents 显式"实验性"）。
- 单设备覆盖（HUAWEI CDY-AN90 / Android 10 + 1 台中端 Android 13+），**不**外推到其他 ROM。

### 7.3 用户人工验收项

- 节拍器可听且音量调节生效。
- 调音器对 G/C/E/A 四弦反馈与静态表一致。
- 设置页三个开关 UI 联动正确。
- 深色 UI 无视觉异常。

### 7.4 文档同步项

- `docs/architecture/OP1_ADR.md` 落盘。
- `docs/architecture/OP2_ADR.md` 落盘。
- `docs/architecture/PHASE1_GATE.md` 落盘。
- `docs/dev/TASK_LEDGER.md` 追加 T049 / T049A-T / T050-T057 全部条目。
- `docs/dev/AGENT_QUALITY_METRICS.md` 追加 T049 Scorecard + 各任务 Scorecard。
- `docs/ROADMAP.md` P1 行追加关闭门状态。

### 7.5 Git 状态要求

- HEAD 必须为 T11 提交 commit；working tree clean。
- 默认**不 push**；默认**不 tag**。
- **不** amend / rebase / reset --hard / force push。

### 7.6 不修改 Manifest INTERNET 权限

- `android/app/src/{main,debug,profile}/AndroidManifest.xml` **无** `INTERNET` 权限（仅 `RECORD_AUDIO`）；T11 关闭门必须静态检查确认。

### 7.7 不提交 build 产物

- `build/` / `*.apk` / `*.aab` / `*.jks` / `key.properties` 全部 `gitignore` 覆盖；T11 关闭门必须 `git status --ignored` 确认。

### 7.8 Drift schemaVersion 保持 2

- `lib/data/database/app_database.dart:92` `int get schemaVersion => 2;` 不动。
- T11 关闭门必须静态检查确认。

### 7.9 Day 3/5/6/7 课程仍冻结

- `lib/core/constants/lesson_constants.dart` 不动（T043 单 `c_am_down_4x4` 课程）。
- `lib/core/constants/practice_plan_constants.dart` 不动（v1.1.0 7 天计划）。

---

## 8. 后续任务方向（不启动）

T11 P1 关闭门通过后，下一阶段建议方向（必须由 GPT 首席架构师出具独立 Prompt 后才能启动）：

1. **P2 Interactive Slice Implementation Plan**（T058+）：9 步闭环第一课 + 起音 / 节奏反馈 + 真机录屏 + 节奏/起音对齐初始校准；Drift 升级 schemaVersion 2 → 3（累进式 `if (from < 3)` 块）。
2. **iOS TestFlight 闭环**（TD-003）：需跨平台工程选型 + UX 重做 + 合规前置 + 测试设备，受 PRD §10 合规前置约束。
3. **国产 ROM 兼容性补测**（TD-013）：小米 / OPPO / vivo / 三星真机验收。
4. **23 个 Dart 格式漂移**（T038 记录）：独立 `T038A_FIX_DART_FORMAT_DRIFT_BATCH_FORMAT`。
5. **`.gitignore` 追加 `*.apk` + `*.aab` 显式模式**（T038C Reviewer 提示）：作为防御纵深。

---

## 9. 文档版本

| 版本 | 日期 | 修改内容 |
|------|------|----------|
| 1.0 | 2026-06-25 | T049 初稿：11 个正式实施任务（T1-T11）+ 3 个 Demo 组 + P1 关闭门 + T047B 2 项 Minor 不顺手修策略 + 风险分级 + Reviewer 裁决铁律 + Drift schemaVersion=2 保持 + Manifest INTERNET 禁令 + Day 3/5/6/7 课程冻结 + 不启动 OP-1 / OP-2 / P2 |
| 1.1 | 2026-06-25 | 三步反思修订：① T1 / T2 显式区分真机实验主体 vs ADR 收口产物；② T9 显式 P1/P2 边界（内存包装层 vs P2 v2→v3 升级）；③ T11 显式降级路径 PASS 语义（±20 cents 实验性 / 静态表 / OP-1 C/D 都属 PASS 但必须显式标注）；④ §3.2 并行约束现实化；⑤ §4 Demo C 时间窗警告 |

---

## 10. 引用

- `docs/PRD_v2.md` v0.3（已批准）
- `docs/architecture/SDD_V2.md` v0.4（已批准）
- `docs/architecture/TDD_PRODUCT_V2_PHASE1.md` v1.0（已批准）
- `docs/T046_ROADMAP.md` v0.3 / `docs/ROADMAP.md`（v2 路线段）
- `docs/dev/TASK_LEDGER.md`（T027 / T029 / T030 / T031 / T031C / T031E / T031I / T032 / T033 / T034 / T035 / T035A / T035B / T037B / T037B1 / T037B2 / T038B / T041-T048 条目）
- `docs/dev/AGENT_QUALITY_METRICS.md` §4.Z T047B Scorecard / §4 T048 Scorecard
- `docs/dev/TECH_DEBT.md`（TD-001 ~ TD-022）
- `docs/dev/REAL_AUDIO_DEPENDENCY_SPIKE.md` §3.6
- `docs/learning/lesson_c_am_down_4x4.md`
- `llfbandit/record` README + `record_platform_interface/lib/src/types/record_config.dart`（Context7）
- `pub.dev/packages/record` / `pub.dev/packages/record_android`（Context7）
