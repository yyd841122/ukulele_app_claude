# TDD V2 — Product V2 Phase 1 技术设计与测试设计

> Task ID：`T048_PRODUCT_V2_PHASE1_TDD`
> 上游：`docs/PRD_v2.md` v0.3（已批准）/ `docs/architecture/SDD_V2.md` v0.4（已批准）
> 起始 HEAD：`4d3eed3` | 测试基线：744 | 文档长度目标：≤ 500 行
> 最后更新：2026-06-25 | 版本：1.0
> 状态：**TDD v1.0（仅设计；不实现任何功能；不修改生产代码 / 测试代码 / `pubspec.yaml` / Manifest / Drift schema）**
> 是否引入依赖 / 修改 Android 配置 / 运行 build_runner / 启动 T048A Spike：**否**
> 多 Agent 协作：Primary TDD Architect（主会话）/ Audio Test Strategy Reviewer `t048-audio-test-strategy-reviewer`（**Approved**）/ Flutter State Data Reviewer `t048-flutter-reviewer`（**Approved（带 F-1 修复）**）/ Product Alignment Reviewer `t048-product-alignment-reviewer`（**Approved**）；3/3 Reviewer 真实独立只读审查 **Approved**（0 Blocker，0 Approved with Conditions）

---

## 0. 文档目的

为 Product V2 Phase 1（P1 Foundation）定义：

- 范围（In / Deferred / Out）
- 领域模型与数据契约
- Lesson Session 状态机
- Timeline 与时钟契约
- Audio Spike（OP-1 A 方案）协议与决策门
- 接口 / 适配器契约
- 测试矩阵
- Drift 边界
- 候选工作包
- 开放问题与停止门

**不**复制 PRD / SDD 全文；**不**锁定具体算法；**不**实现代码；**不**启动 OP-1 真机 Spike；**不**预占最终 Task ID。

---

## 1. 需求追踪（PRD ↔ SDD ↔ Phase 1 契约 ↔ 验证层级）

| PRD § 需求 / 验收 | SDD § 模块 / 决策 | Phase 1 技术契约 | 验证层级 | 测试 / 真机证据 | Deferred |
|---|---|---|---|---|---|
| PRD §6 P1 = Foundation；P1 关闭 = **SDD §5.5 开放问题决议落地** + 4 项 §7.2 P0 补齐 + T009 调音器精度 spike 报告归档 | SDD §7.1-7.4 OP-1~OP-5；§3.2 P1 ADJUST 表；§3.7 P1 关键门 | OP-1 真机 Spike（仅协议设计，本任务不执行）+ 节拍器可听 + 7 和弦 + 7 单音 + 设置 + 深色 token + OP-2 调音器精度 spike 协议 | Audio Spike（设备 + 30 段录音）+ 单元 + Widget + 真机 | 候选工作包 §9.1-T1 OP-1 Spike；§9.1-T2 OP-2 Tuner Spike；§9.1-T5 / T6 / T7 静态资源；§9.1-T8 Settings；§9.1-T9 Dark theme | 9 步闭环 / 起音 / 节奏对齐 / 课程 Session 引擎 / Day 3+ 课程扩展（P2+） |
| PRD §7.2 L1 调音器 stub → P1 | SDD §3.2 `lib/features/tuner/` REFACTOR P1 | TunerPage 接入 `RealAudioRecorderService`（T029 既有）+ 频率 / 音高检测算法（不锁定） + ±10 cents 命中率 ≥ 70% on-device（初始目标） | 单元 + 真机验收 | §9.1-T3 Tuner 实时反馈 | 离线频率表降级（OP-2 spike 失败时） |
| PRD §7.2 L3 节拍器无声 → P1 | SDD §3.2 `lib/features/metronome/` ADJUST P1 | `MetronomeController` + 现有 `MetronomeSetting` 沿用（T010）+ CC0 click 音源（不引入新顶层依赖） + BPM 60-200 + 可听 | 单元 + 真机 | §9.1-T4 Metronome 可听 | 节奏型持久化（SDD §3.3 / PRD §4.4 静态 SVG 即可） |
| PRD §7.2 L5/L6 +G7/Dm/Em +B | SDD §3.2 `chord_library` / `single_note_practice` ADJUST P1 | `kBuiltInChords` 数组 + 3 项（G7/Dm/Em）；`kBuiltInSingleNotes` 数组 + 1 项（B） | 单元（不变量：fret 数组 / 手指 / 名称） | §9.1-T5 7 和弦；§9.1-T6 7 单音 | TAB / 五线谱（永久 Out） |
| PRD §7.2 L11 深色 token | SDD §3.2 `lib/app/theme.dart` ADJUST P1 | `ColorScheme.dark()` + `ThemeData.dark()` + 不开用户切换 toggle | Widget（深浅切换不爆） | §9.1-T9 Dark theme | 用户切换 toggle（Deferred） |
| PRD §7.2 L12 设置未暴露 | SDD §3.2 `lib/features/settings/` ADJUST P1 | `SettingsPage` 暴露 `defaultBpm` / `metronomeVolume` / 反馈项开关；持久化走 `UserSettingsRepository`（T013.2 Drift `user_settings` 表；P1 不新增列；P2 升级 v2→v3 时与 `scores` 一并落地） | Widget + 单元 | §9.1-T8 Settings UI | 反馈项默认值（与 P2 Session 引擎一起） |
| PRD §8.2 反馈延迟 150-300 ms wall-clock | SDD §3.6 四类时钟；§3.7 初始基线 ≤ 50 ms 相对漂移 | Phase 1 不实现反馈（**P2 才需**）；本任务**仅**记录初始基线 + 测量对象 + 失败处理 | — | （不写 P1 测试；T048A Spike 协议承担） | 实际反馈延迟（首次出现于 P2） |
| PRD §11 OP-1 / OP-2 | SDD §7.1-7.4 | OP-1 = A 方案作为"首选 Spike 验证候选"（**非已证明架构**）；OP-2 = 调音器算法 | 决策门 | §5 本 TDD 详细协议 | OP-3/OP-4/OP-5（P3+） |
| PRD §5.6 28/32 对齐初始基线 | SDD §3.7 初始基线标注 | **P1 不引入**；本任务**仅**在 TDD §4 / §10 记录为"待 P2 真机校准初始目标" | — | （P2 才写） | P2 9 步闭环 |
| PRD §5.2 切片强约束 | SDD §3.2 §8 P2 关键门 | **P1 不引入** | — | — | P2 |

**注**：表中"验证层级"列每项必须**有真机可见产物**（PRD §6 节奏铁律"任意连续 3 个开发任务必须产生真机可见成果"）。Phase 1 关闭时必须产出至少 1 段 APK 真机录屏 + 4 项 §7.2 P0 补齐 + OP-1 ADR。

---

## 2. Phase 1 领域模型与数据契约

### 2.1 持久化模型（**保持现状**）

- `PracticeRecord` / `UserSettings` / `CompletedTasks`（T013.1 / T032 既有）
- **`schemaVersion` 保持 2**（P1 不升级；P2 引入 `scores` 表时按 SDD v0.4 §3.8 累进式 `if (from < 3)` 升级到 v3；P4 处理 `practice_records.lessonId` 升级到 v4）
- **不**新增 Drift 表；**不**修改既有表列；**不**调用 `m.createAll()` 在 `beforeOpen` 静默建表

### 2.2 运行时模型（**Phase 1 实际需要**）

| 模型 | 来源 | 字段（不变量） | 备注 |
|---|---|---|---|
| `Lesson` | `lesson_constants.dart` T043 既有 | id / title / description / linkedTaskIds / strumPattern / steps（order 1..N 无空缺） | P1 **不**扩展 |
| `StrumPattern` | 同上 | id / name / beatsPerMeasure / direction / chordSequencePerBeat（length == beatsPerMeasure） | 不变 |
| `MetronomeSetting` | T010 既有 | bpm / minBpm / maxBpm / beatsPerBar / soundEnabled（minBpm ≤ bpm ≤ maxBpm；beatsPerBar ∈ allowedBeatsPerBar） | P1 ADJUST 仅**新增 Provider 注入**`MetronomeAudioSource`，**不**改 MetronomeSetting 字段（`volume` 与 `isPlaying` 不属于此值类型；P1 引入到 `MetronomeState`）；详见 §6.2.2 边界 |
| `MetronomeState` | T010 既有（Controller 持有的可变副本） | 副本 MetronomeSetting + `isPlaying` / `currentBeat` 等运行态（既有） | P1 ADJUST 增加 `volume`（∈ [0, 1]）字段 + `MetronomeAudioSource` 引用 |
| `TunerReading` | **P1 NEW** | detectedHz / targetHz / centsOffset / confidence ∈ [0, 1]（targetHz ∈ G4/C4/E4/A4 标准频率） | 算法不锁定；UI 仅显示 cents / 音名 |
| `BeatTick` | **P1 NEW**（T2 阶段） | beatIndex / barIndex / isDownbeat / sessionMonotonicMs（单调递增） | 详见 §4 |
| `OnsetEvent` | **P2 / DEFERRED** | frameIndex / timeFromStartMs / confidence | P1 不引入 |
| `LessonSessionState` | **P2 / DEFERRED** | current step / beat index / take id / feedback summary | P1 不引入 |

### 2.3 UI 展示模型（**Phase 1 实际需要**）

| 组件 | 模型 | 数据源 | 阶段 |
|---|---|---|---|
| `TunerPage` | `TunerReading` → "C / +12 cents / ↘" | `TunerEngine`（OP-2 算法不锁定） | T3 |
| `MetronomePage` | `MetronomeSetting`（沿用 T010） + 动画 tick | `MetronomeController`（T010 既有；T4 注入 `MetronomeAudioSource`） | T4 |
| `ChordLibraryPage` | `List<Chord>` | `kBuiltInChords` + 3 项 | T5 |
| `SingleNotePracticePage` | `List<SingleNote>` | `kBuiltInSingleNotes` + 1 项 | T6 |
| `SettingsPage` | `defaultBpm` / `metronomeVolume` / 反馈项开关 | `UserSettingsRepository`（T013.2 Drift `user_settings` 表） | T8 |

### 2.4 Spike 临时数据（**仅 OP-1 / OP-2 Spike 期间**）

- `RawAudioCapture`（双 `AudioRecorder` 实例 m4a + PCM 流；P1 不实现；T048A Spike 协议产生；非持久化）
- `TunerCalibrationLog`（OP-2 调音器精度 30 段录音 × ±10 cents 命中率；非持久化）

**铁律**：不提前引入 P2/P3 字段 / 模型 / 正式业务表。P1 不得在 `lesson_constants.dart` 增加 `Lesson.durationSeconds` / `Lesson.targetBpm` 等 P2 才需要字段（属 §3.2 Lesson Session Engine；P1 Lesson 沿用 T043）。**禁止引入**：`OnsetEvent` / `LessonSessionState` / `ScoreTimelineEngine` / `FeedbackEngine` / `PcmStreamAudioRecorderGateway`；这些属于 P2 启动后由独立 Implementation Plan 任务引入。P1 在这些类被引用前一律编译失败（编译期护栏）。

---

## 3. Lesson Session 状态机

> **范围声明**：P1 **不实现**完整 9 步 Session 引擎（属于 P2）。本节**仅**定义 P1 触及的子集 + P2 衔接契约，避免 P1 提前占用 P2 状态机空间。

### 3.1 P1 触及状态（已存在于现有页面）

| 现有页面 | 状态 | 状态机 | 拥有者 | 备注 |
|---|---|---|---|---|
| `TunerPage` | 静态指南 → 实时反馈 | 既有 T011 `TunerState`（`strings` / `confirmedStringNumbers`）**KEEP** + P1 NEW `TunerReading` 流（由 `TunerEngine` 派生） | `TunerController`（T011 既有，**REFACTOR**：扩展 `TunerEngine` 注入） | T3 阶段；与 `MicrophonePermissionService` 协同 |
| `MetronomePage` | 启动 / 停止 / BPM 调整 | 既有 T010 `MetronomeState`（bpm / beatsPerBar / soundEnabled / `isPlaying` / `currentBeat`）+ P1 NEW `volume` 字段 + P1 NEW `MetronomeAudioSource` 注入 | `MetronomeController`（T010 既有，**ADJUST**） | T4 阶段 |
| `RecordingPage` | 权限 / 录音 / 播放 / 保存 | 既有（T031-T038B 已落地） | `RecordingPracticeController`（既有） | **P1 不修改** |
| `LessonPage` | 课程静态展示 | 无状态机 | `LessonPage`（T044 既有） | **P1 不修改** |

### 3.2 P2 Session 状态机契约（**仅契约、不实现**）

P2 由独立 Implementation Plan 任务实现。本 TDD **仅**锁定衔接契约：

| 状态 | 触发 | 拥有者 | 失败路径 |
|---|---|---|---|
| `lessonLoading` | 进入 `LessonPage` | `LessonSessionController`（P2 NEW） | Repository miss → `lessonNotFound` |
| `lessonReady` | Lesson 加载完成 | 同上 | — |
| `countdownTick` | 用户按开始 | 同上 + `MetronomeAdapter` | 节拍器启动失败 → `audioStartFailed` |
| `playing` | 倒计时结束 | 同上 + `AudioCapture` | 录音启动失败 → `audioStartFailed`；权限吊销 → `permissionRevoked` |
| `paused` | 用户按暂停 | 同上 | — |
| `finished` | 32 拍全跑完 | 同上 + `FeedbackEngine` | Feedback 计算失败 → `feedbackFailed`（**不**写入 `Score`） |
| `disposed` | 页面退出 / 路由 pop | 同上 | 必须 stop 录音 / 停节拍器 / 取消 `BeatTick` 订阅（与 T031 录音契约一致） |

**唯一真相源铁律**：Lesson Session 状态**只**由 `LessonSessionController` 拥有。`MetronomeController` / `RecordingPracticeController` / `TunerController` / `ScoreTimelineEngine` **不得**持有 Session 状态字段（如 `currentStep` / `takeId`）；它们仅持有自身模块的运行态（如 `isRecording` / `isPlaying`）。

**dispose 责任**：`LessonSessionController.dispose()` 调 `AudioCapture.cancel()` + `MetronomeAdapter.stop()` + 取消所有 `Stream` 订阅；`RecordingPracticeController.dispose()` 沿用 T038B 既有契约（**遵循 T038B 不调 `service.dispose` 原则**——仅取消订阅 + 设置 `_disposed` 标记，**不**调 `AudioCapture.cancel` / `MetronomeAdapter.stop`，由 `LessonSessionController` 统一编排）；`MetronomeController.dispose()` 沿用 T010 既有。

### 3.3 失败路径与降级

| 失败 | 用户可见行为 | 降级 | 留痕 |
|---|---|---|---|
| 麦克风权限被拒 | 引导去系统设置 + 友好文案（沿用 T038B） | "无麦克风降级" | `permissionStatus = denied/permanentDenied` |
| 录音启动失败 | Toast 提示 + 重试按钮 | 不进入 P2 Session | log to stderr（不联网） |
| 页面退出 / app 进入后台 | 强制 stop 录音 + 停节拍器 | 录音文件标记为孤儿（tmp 不迁移） | T028 既有清理 |
| OP-1 Spike 失败 | A 未通过 → 回退 C 或 D | **不**回退 E（与 PRD §5.5 冲突） | ADR 落盘 `docs/architecture/OP1_ADR.md` |
| 调音器算法 OP-2 失败 | 接受 ±20 cents 显式"实验性"标签 | 调音器页面保留静态 GCEA 频率表 | 与 SDD §7.4 一致 |

---

## 4. Timeline 与时钟契约

> 来源：SDD v0.4 §3.6（四类时钟区分）。**铁律**：不把 PCM chunk 到达时间当作真实设备采集时间；5 分钟相对漂移 ≤ 50 ms 仅作为待真机校准的初始目标。

### 4.1 四类时钟区分（**Phase 1 仅协议**，实际 P2 才用）

| 类别 | 来源 | 单调性 | wall-clock | 阶段 | 备注 |
|---|---|---|---|---|---|
| (a) 会话单调时钟 | Dart `Stopwatch` 进程启动后累加毫秒 | ✅ 单调 | ❌ | P1（MetronomeController 用）+ P2 | T010 既有节拍器时钟沿用；T2 阶段产 `BeatTick.sessionMonotonicMs` |
| (b) PCM 样本计数推导 | `elapsedAudioMs = cumulativeSamples / sampleRate` | ✅ 仅在样本按序到达时 | ❌ | P2 | OP-1 = A 方案通过 T048A Spike 后才可用 |
| (c) PCM chunk 到达时间 | `Stream<Uint8List>` listener 内 `Stopwatch.elapsedMilliseconds` | ✅ | ❌ | P2 | **不**伪装成设备采集时间；仅作为 (a) 会话单调时钟事件标注 |
| (d) 设备采集时间戳 | `record ^7.1.0` API **未暴露** | **未证实** | **未证实** | T048A Spike 验证 | 当前 `record_platform_interface` 无可消费字段；**不得**预设可获得 |

### 4.2 BeatTick ↔ OnsetEvent 映射（**P2 协议**）

- P1 **不**实现 `OnsetEvent`；T2 阶段产 `BeatTick`（仅 (a) 会话单调时钟）
- P2 启动时按 SDD v0.4 §3.6 对齐策略：两类事件都打 (a) 会话单调时钟戳；音频时长用 (b) PCM 样本计数推导作为辅助交叉验证

### 4.3 倒计时到正式播放的零点

- 倒计时 N 拍 × 当前 BPM = `N * 60000 / bpm` ms（仅 (a) 会话单调时钟）
- 倒计时结束 = `(a) monotonicMs >= countdownStartMs + N * 60000 / bpm` 翻转 `isPlaying=true`
- 节拍器音频与视觉高亮同步：`BeatTick` 单 Stream 分发（共享同一会话单调时钟），UI 订阅 + Metronome Audio 调度共享同一时间基准

### 4.4 暂停 / 恢复 / 停止 / 页面退出

| 操作 | 行为 |
|---|---|
| Pause | 记录 `pauseMonotonicMs`；`BeatTick` 流停止发射；UI 高亮保留当前位置 |
| Resume | 计算 `pauseDuration = resumeStartMonotonicMs - pauseMonotonicMs`；`BeatTick` 流的 `sessionMonotonicMs` 减去 `pauseDuration`（**实际等价**于以 (a) 为基准，pause 期间不发 tick） |
| Stop | `BeatTick` 流完成（`Stream.done`）；录音强制 stop（T031 既有契约）；UI 翻 `finished` |
| 页面退出 | `Controller.dispose()` 触发 → BeatTick 取消订阅 + 节拍器 stop + 录音 cancel；与 T038B 录音契约 100% 一致 |

### 4.5 5 分钟相对漂移初始验收目标（**P2 真机校准**）

- **测量对象**：`OnsetEvent` ↔ `BeatTick` 在 5 分钟录音稳态下的**相对漂移**（**不**是 wall-clock 绝对漂移）
- **起止基准**：起 = Session start（`sessionStartMonotonicMs`）；止 = Session stop
- **初始目标**：≤ 50 ms（**初始验收目标，非永久常量**；P2 on-device 校准后由 P2 关闭门 review 重新协商）
- **降级规则**：若真机漂移 > 50 ms，`FeedbackEngine` 把"节奏漂移%"标为非阻断观察（与哑音切换同语义）；若 > 200 ms，回退 OP-1 = C（事后解码）以彻底避开实时对齐

---

## 5. Audio Spike（OP-1）测试设计

> **铁律**：A 方案保持"首选 Spike 验证候选（**非**已证明架构）"（SDD v0.4 §7.2）。**没有真机证据不得批准 A 方案进入正式实现**。**本任务不执行 Spike**；以下仅为**可执行但未执行**的协议设计。

### 5.1 Spike 协议（可执行 / 本任务不执行）

| 维度 | 协议 |
|---|---|
| 测试设备 | HUAWEI CDY-AN90（Android 10，v1.1.0 真机基线）+ 至少 1 台中端 Android 13+ 设备 |
| Android 版本记录 | OS version / build number / 厂商 ROM / 麦克风硬件型号 |
| 5s / 30s / 5min 三档断点 | 三档必须全部跑通；任一档失败 → A 方案不通过 |
| m4a 完整性 | 5min 后 `stop()` 返回的 m4a 文件可被 `just_audio` 正常解码 + 播放（沿用 T030 契约） |
| PCM 格式 | `startStream(PCM16bits)` 帧格式正确（44.1 kHz / mono / int16 LE）；不出现 0xFFFE / 0xFFFF 异常 |
| PCM 连续性 | chunk 帧序号连续无丢失 / 无重复 / 无乱序；帧序号在 5min 内单调 |
| 权限生命周期 | 两实例共享 `RECORD_AUDIO`；任一实例 start 期间另一个 cancel / dispose 不导致权限吊销 |
| start/stop 顺序 | 双实例 start 顺序：先 m4a 再 PCM 流；stop 反序（先 PCM 流 stop，再 m4a stop） |
| 停止回调归属 | `MethodChannel('record_android')` `onStop` / `onCancel` 回调能正确归属调用实例（不串台） |
| 资源释放 | 两实例 dispose 后音频焦点 / 麦克风占用完全释放，无后台进程残留 |
| 重复启动 | 同一对实例 A → stop → A → start 应幂等（不残留句柄） |
| 页面退出 | 模拟 `Controller.dispose()` → 双实例 stop → 释放 → 后续 page open 不报错 |
| 中断与失败恢复 | 来电 / 系统 kill app / 蓝牙耳机断开 / 第三方 App 占麦 → 双实例优雅失败，状态机回到 idle |
| 设备兼容矩阵 | 至少 2 设备 × 3 时长 = 6 次实验；每档至少 1 次完整通过 |
| 原始日志保存边界 | 保存到 `e2e/spike_logs/op1_<device>_<timestamp>.log`；**不**上传；**不**包含用户 PII |
| 产物保存边界 | m4a 录音保存到 `e2e/spike_logs/audio/`；**不**上传；本地生命周期 7 天后清理 |

### 5.2 候选方案判定矩阵

| 候选 | 通过条件 | 失败条件 | 决策门 | 降级方式 | 回滚方式 | 对 m4a 闭环保护 |
|---|---|---|---|---|---|---|
| **A 双 record 实例 + PCM 流 + m4a 并行**（首选验证候选） | 三档断点 + 7 项（5.1）+ 设备兼容矩阵全部通过 | 任何 1 项失败 | 通过 → ADR 批准为 P1 正式方案；未通过 → 不进入 P2 | C（事后解码）或 D（FFI） | T048A 期间所有改动回滚；`RealAudioRecorderService` 既有 T029 契约保留 | m4a 录音 + T030 播放契约 100% 保留 |
| **C 事后解码 m4a → 后台 isolate 检测** | 1) `just_audio` 0.10.5 API 暴露"纯解码到 PCM"入口；2) 解码 ≤ 5 秒 / 5min 录音；3) 后台 isolate 检测准确度 ≥ 80% | just_audio 不暴露纯解码 + ffmpeg_kit_flutter 弃用警告 | 通过 → P2 接受"会话结束反馈"语义 | A 方案重试 1 次（T048A 复测） | 关闭 P2 Session Engine 9 步闭环 7 步（仅保留 1/2/5/8/9），回退到"录 + 回放 + 自评" | m4a 完整保留 + T030 播放 + T031E LoopMode 保留 |
| **D Android `AudioRecord` JNI / FFI 直采** | FFI 编译通过 + 不与 `record` 包内 `AudioRecord` 实例冲突 + 准确度 ≥ 80% | FFI 编译失败或与 record 包冲突 | 通过 → P2 接受 FFI 复杂度代价 | C 方案兜底 | 移除 FFI 引入 + `record ^7.1.0` 既有契约保留 | 同上 |
| E 放弃实时分析 | （反推荐） | — | 不可批准 | — | — | — |

### 5.3 OP-2 调音器精度 Spike 协议

| 维度 | 协议 |
|---|---|
| 设备 | 同 5.1 HUAWEI CDY-AN90 + 1 台中端 Android 13+ |
| 数据 | 30 段录音 × G/C/E/A 四弦 × 1s / 3s / 5s 三档 |
| 测量 | 命中率（±10 cents 内占比） / 误报率 / 响应延迟 |
| 通过 | ±10 cents 命中率 ≥ 70% on-device（PRD §8.2 / SDD §7.4） |
| 失败 | 命中率 < 70% → 接受 ±20 cents 显式"实验性"标签；命中率 < 50% → 回退静态 GCEA 频率表 |

### 5.4 ADR 产出（**必须**）

任何 Spike 完成后必须产出 `docs/architecture/OP1_ADR.md`（A 方案） + `docs/architecture/OP2_ADR.md`（B 方案调音器），含：

- 设备 / 时长 / 数据
- 7 项必含清单结果
- 通过 / 失败证据
- 功耗 / 温度 / 内存数据
- 决策结论（**未**通过不得作为 P1 正式方案）

---

## 6. 接口和适配器契约

> **仅**定义接口、输入输出、错误、生命周期。**不**写生产实现。

### 6.1 现有 v1.1.0 处置映射

| 现有模块 | 处置 | 阶段 | 备注 |
|---|---|---|---|
| `lib/features/recording/` | **KEEP**（T031-T038B 既有） | — | P1 不修改；T2/T3 阶段可能接入真实 m4a（既有契约） |
| `lib/features/practice_records/` | **KEEP** | — | P1 schemaVersion 保持 2 |
| `lib/features/metronome/` | **ADJUST** | T4 | 加可听点击音；Controller / Setting 沿用 |
| `lib/features/tuner/` | **REFACTOR** | T3 | 静态指南 → 实时反馈（OP-2 算法） |
| `lib/features/chord_library/data/built_in_chords.dart` | **ADJUST** | T5 | + G7 / Dm / Em |
| `lib/features/single_note_practice/data/built_in_single_notes.dart` | **ADJUST** | T6 | + B |
| `lib/features/lesson_c_am_down_4x4/` | **KEEP** | — | P1 不扩展 LessonPage（Lesson Session 引擎属 P2） |
| `lib/features/settings/` | **ADJUST** | T8 | UI 暴露 defaultBpm / volume / 反馈项开关 |
| `lib/app/theme.dart` | **ADJUST** | T9 | 加深色 token；**不**开用户切换 toggle |
| `lib/app/router.dart` | **KEEP** | — | P1 不修改 |
| `lib/shared/services/microphone_*` | **KEEP** | — | T027 既有；T3 接入 |
| `lib/shared/services/real_audio_*` | **KEEP** | — | T029/T030 既有；T2 阶段 OP-1 Spike 协议使用 |
| `lib/shared/services/audio_file_storage_service` | **KEEP** | — | T028 既有 |
| `lib/core/constants/lesson_constants.dart` | **KEEP** | — | P1 不扩展（P2 才接 Session Engine） |
| `lib/core/constants/practice_plan_constants.dart` | **KEEP** | — | 7 天计划不动 |
| `lib/data/database/app_database.dart` | **KEEP** | — | schemaVersion 保持 2；P1 不升级 |

### 6.2 Phase 1 实际新增接口（**仅契约**）

#### 6.2.1 `TunerEngine` 抽象（T3 阶段）

```dart
abstract class TunerEngine {
  /// 启动时申请麦克风权限（与 MicrophonePermissionService 协同）。
  Future<void> start();

  /// 用户主动停止（页面退出 / dispose）。
  Future<void> stop();

  /// 实时读数流；P1 阶段为派生 (a) 会话单调时钟下的检测结果。
  /// 算法不锁定（OP-2 决议后由具体实现给出）。
  Stream<TunerReading> get readings;

  /// 释放资源；与 T038B 录音契约 100% 一致（不调底层 dispose 句柄）。
  Future<void> dispose();
}
```

**错误契约**：
- `TunerPermissionDeniedException` / `TunerAudioStartFailedException` / `TunerDisposedException`
- 不暴露绝对路径 / 异常类名 / PII（沿用 T038B 文案约束）

#### 6.2.2 `MetronomeAudioSource` 抽象（T4 阶段）

```dart
abstract class MetronomeAudioSource {
  /// 加载 CC0 click 音源（不引入新顶层依赖，沿用项目内 assets）。
  Future<void> ensureLoaded();

  /// 播放单次 click；accent 用于区分 downbeat（更大声）。
  Future<void> playClick({required bool isAccent});

  /// 释放资源。
  Future<void> dispose();
}
```

**实现选择**：`just_audio ^0.10.5`（T030 既有）+ 内置 `AssetSource` 播放 CC0 `.wav` / `.mp3`（沿用项目 assets 体系）。**不**引入新顶层依赖。

**与既有 `MetronomeController` 边界**（**重要**）：
- 既有 T010 `MetronomeController` **不**持有音频播放句柄；当前 T010 实现是纯逻辑（`Timer.periodic` + `Notifier<MetronomeState>` + `tickForTesting()` 测试入口），没有"播放 click"方法，也**不**发布 `BeatTick` 流
- `MetronomeAudioSource` 由 **T4 阶段新建 Provider**（`metronomeAudioSourceProvider`）持有，**不**嵌入 `MetronomeController`
- `MetronomeController` 通过 Provider 注入 `MetronomeAudioSource`（不在构造函数硬编码）；P1 ADJUST 增加 `volume` 字段（∈ [0, 1]）仅作用于 `MetronomeState`（Controller 可变副本），**不**改 `MetronomeSettings` 值类型字段（KEEP）；详见 §6.4
- `BeatTick` 流是 **P1 NEW T2 阶段**新增（§2.2）；由 `MetronomeController` 派生并发布，与 `MetronomeAudioSource` 解耦
- 这样 `MetronomeController` 与音频播放**解耦**：T4 阶段只新增 Provider + 修改 Controller 注入逻辑；T4 关闭后可独立替换实现（例如未来从 `just_audio` 切到 `flutter_sound`，**不**动 `MetronomeController`）

#### 6.2.3 `UserSettingsRepository` 扩展（T8 阶段）

> **修正**：既有 settings 持久化是 T013.2 落地的 **Drift-backed `UserSettingsRepository`**（位于 `lib/shared/repositories/user_settings_repository.dart` + `drift_user_settings_repository.dart`），背靠 `user_settings` 表（T013.1）。**不**存在 `shared_preferences` 依赖（pubspec.yaml 无声明）。**不**得引入新顶层依赖。

```dart
abstract class UserSettingsRepository {
  /// 既有 6 字段契约（T013.2）：保留 100%。
  Stream<MetronomeSettings> watchMetronomeSettings();
  Future<void> setMetronomeSettings(MetronomeSettings settings);

  Stream<InstallDate?> watchInstallDate();
  // ... 既有方法保留

  /// P1 ADJUST 新增：扩展 user_settings 表 + 既有 Repository。
  /// **新增字段**（通过 Drift MigrationStrategy.onUpgrade 累进式 `if (from < 3)`
  /// 升级，详见 §8 + SDD v0.4 §3.8；P1 不引入——延后到 P2：
  ///  - `metronome_volume REAL NOT NULL DEFAULT 1.0`
  ///  - `feedback_item_<key>_enabled INTEGER NOT NULL DEFAULT 1`（key = "节奏漂移%" / "哑音切换"）
  Stream<double> watchMetronomeVolume();
  Future<void> setMetronomeVolume(double volume);

  Stream<bool> watchFeedbackItemEnabled(String key);
  Future<void> setFeedbackItemEnabled(String key, bool enabled);
}
```

**P1 实际处置**：T8 阶段**仅在内存中**通过 `UserSettingsRepository` 包装层暴露 `metronomeVolume` / 反馈项开关 getter/setter；P1 **不**新增 Drift 列 / 不升级 schemaVersion（schemaVersion=2 保持，P2 引入 `scores` 时按累进式 `if (from < 3)` 一并升级 v2→v3，含本节所述列）。P1 期间 settings 不走 SharedPreferences（项目无 `shared_preferences` 依赖）；P2 升级 v2→v3 时新列与 `scores` 表一并落地，触发 §8.3 TDD 8 项硬门。

**P2 触发**：P2 `LessonSessionController` 启动时按 SDD v0.4 §3.8 累进式升级到 v3，本节字段随同 `scores` 表一并落地；测试矩阵触发 §8.3 TDD 8 项硬门。

### 6.3 Phase 1 **不**新建的接口（**防过度设计**）

- ❌ `LessonRepository`（沿用 T044 `lessonByIdProvider`；P1 不动）
- ❌ `ScoreTimelineEngine`（P2 引入）
- ❌ `LessonSessionController`（P2 引入）
- ❌ `FeedbackEngine`（P2 引入）
- ❌ `PcmStreamAudioRecorderGateway`（T048A Spike 通过后才落地）

### 6.4 既有契约保护

- **不**修改 `RecordingPracticeController`（T038B 既有契约 100% 保留；含 T031 录音/播放互斥、T031C mutex、T031E LoopMode、T031I 自然完成 stop、T032 schema 升级、T033 录音路径持久化、T034 删除联动清理、T035/T035A/T035B 详情页播放 lifecycle 全部沿用）
- **不**修改 `RealAudioRecorderService` / `RealAudioPlaybackService` 公共 API
- **不**修改 `AudioFileStorageService`（T028 既有安全契约保留：root 外不删、路径逃逸拒）
- **不**修改 `MicrophonePermissionService`（T027 既有 6 状态契约保留）
- **不**修改 `AudioPlaybackState` / `AudioRecorderState` enum
- **不**修改 `MetronomeSettings` 值类型字段（T010 既有：bpm / minBpm / maxBpm / beatsPerBar / soundEnabled 全部 KEEP）；P1 ADJUST 仅在 `MetronomeState`（Controller 持有的可变副本）新增 `volume` 字段 + 注入 `MetronomeAudioSource`；详见 §6.2.2 边界
- **不**修改 `UserSettingsRepository` 公共 API（T013.2 既有 6 字段契约保留）；P1 ADJUST 仅在内存包装层扩展 metronomeVolume / 反馈项开关 getter/setter；Drift 列新增延后到 P2 升级 v2→v3 时落地（详见 §6.2.3）
- **不**修改 `TunerController` 公共状态形状（T011 既有 `TunerState` 含 `strings` / `confirmedStringNumbers` 全部 KEEP）；P1 REFACTOR 仅在 Controller 内**新增** `TunerReading` 流（与既有 `TunerState` 并存，由 `TunerEngine` 派生）；详见 §6.2.1 + §3.1

### 6.5 P2 `LessonSessionController` 抽象契约（**P2 实现，本节仅契约**）

> P2 由独立 Implementation Plan 任务实现。本节**仅**锁定抽象形状，确保 P1 / T048+ 任务不越界。

```dart
abstract class LessonSessionController {
  /// 加载 Lesson（从 lessonByIdProvider）。
  Future<void> load(String lessonId);

  /// 启动 Session：进入 countdownTick 状态。
  Future<void> start();

  /// 暂停 / 恢复 / 停止。
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();

  /// 持有 takeId（录音文件路径）— 由 AudioCapture 注入，**不**由本类生成。
  String? get takeId;

  /// 持有当前 LessonSessionState（state 字段由本类独占）。
  LessonSessionState get state;

  /// dispose 时必须调 AudioCapture.cancel() + MetronomeAdapter.stop() +
  /// 取消所有 Stream 订阅（与 §3.2 dispose 责任契约对齐）。
  void dispose();
}
```

**唯一真相源护栏**：本类**只**持有 Session 状态字段（`currentStep` / `takeId` / `state`）；**不**持有 `isRecording` / `isPlaying` / 录音文件路径生成 / BPM / 音量 等子模块运行态（这些归对应模块 Controller）。

---

## 7. 测试设计

> **铁律**：不得通过只验证 Mock 调用次数代替用户可见行为验证。Fake 与真实组件边界必须清晰。

### 7.1 测试层级

| 层级 | 工具 | 范围 | Fake 边界 | 关键约束 |
|---|---|---|---|---|
| 纯 Dart 单元测试 | `flutter_test` | 纯函数 / 数据类 / Repository 包装 | 无 Flutter 依赖 | 运行 < 100ms / case |
| Riverpod / Controller 测试 | `flutter_test` + `ProviderContainer` | `TunerController` / `SettingsRepository` | `FakeTunerEngine` / `FakeSettingsRepository` | 验证状态翻转而非 mock 调用 |
| Widget 测试 | `flutter_test` + `WidgetTester` + `FakeAsync` | `TunerPage` / `MetronomePage` / `ChordLibraryPage` / `SingleNotePracticePage` / `SettingsPage` | 既有 `FakeAudioRecorderGateway` 风格 | 用户可见行为断言 |
| Router 测试 | `flutter_test` + `appRouter` | 路径跳转 + 参数解析 | 既有路由不变 | 9 路由 P1 不增不减 |
| 数据库迁移测试 | `flutter_test` + `AppDatabase.forTesting` | Drift schema 既有 3 表 + onUpgrade 1→2 no-op | `NativeDatabase.memory()` | **P1 不**写新测试（schemaVersion 不变） |
| 集成测试 | `integration_test` | 节拍器可听 / 调音器反馈可见 | 设备真机 | 走 T048A/T048B Spike 协议 |
| Android 真机 Spike | `record ^7.1.0` 双实例 + `just_audio ^0.10.5` | OP-1 7 项必含 + 设备兼容矩阵 | 真实设备 | 必产 ADR；无真机证据 = 未通过 |
| 人工产品验收 | 用户 | 7 和弦 / 7 单音 / 节拍器 80 BPM / 调音器反馈 | 真机 | 录屏 + 文字描述 |

### 7.2 P1 关键测试矩阵（**最少充分**）

> **注**：本表**仅**列 P1 实际执行 / 协议化的测试项；TC-15 是 P2 真机校准项（**P1 不执行**，仅作协议预留）。

| # | 被测行为 | 输入 / Fixture | 期望结果 | 失败信号 | Fake 边界 |
|---|---|---|---|---|---|
| TC-1 | 7 和弦常量不变量 | `kBuiltInChords` 数组 | 长度 = 7；包含 C/Am/F/G + G7/Dm/Em；每个 chordVoicing.fingers.length ≤ 4 | 不变量违例 | 纯 Dart；无 fake |
| TC-2 | 7 单音常量不变量 | `kBuiltInSingleNotes` 数组 | 长度 = 7；含 C/D/E/F/G/A + B；每条 `fret ∈ [0, 12]` | 不变量违例 | 纯 Dart；无 fake |
| TC-3 | Metronome BPM 边界 | `MetronomeController` 设 bpm=minBpm-1 / maxBpm+1 | minBpm-1 拒绝；maxBpm+1 拒绝 / clamp | 越界未拦截 | `FakeMetronomeAudioSource`（**P1 NEW**，与 §6.2.2 同步新建） |
| TC-4 | Settings 持久化往返（**P1 内存中**；P2 落盘） | `UserSettingsRepository.setMetronomeSettings(... bpm=80, volume=0.7)` | 读回一致（内存 mock） | 读回 ≠ 80 / 0.7 | `AppDatabase.forTesting` + `FakeUserSettingsRepository`（P1 仅内存；不写盘） |
| TC-5 | Dark theme 切换无 widget 崩溃 | `MaterialApp(theme: ThemeData.dark())` 渲染 HomePage | 不爆 | 抛异常 | 既有 `FakeHomeController` |
| TC-6 | TunerController 权限拒绝降级 | `MicrophonePermissionStatus.denied` | UI 引导去系统设置（沿用 T038B 引导文案） | 文案不出现 | `FakeMicrophonePermissionService` 返回 `denied` |
| TC-7 | TunerController 录音启动失败 | `RealAudioRecorderService.start()` 抛异常 | UI 显示重试按钮 + 友好文案 | Toast 异常类名泄露 | `FakeAudioRecorderGateway.start()` 抛 |
| TC-8 | TunerController dispose 幂等 | dispose() × 3 | 无抛错；资源不释放 2 次 | 二次 dispose 抛错 | `FakeTunerEngine` |
| TC-9 | 路由 9 条路径跳转 | 既有 router 9 路径 | 每条路径渲染对应 Page | 路由解析失败 | 既有 |
| TC-10 | Drift schemaVersion 保持 2 | `AppDatabase` 实例 | `schemaVersion == 2` | 任何 ≠ 2 | `AppDatabase.forTesting` |
| TC-11 | Drift onUpgrade 1→2 仍 no-op | 旧 v1 fixture（手动建表 + user_version=1）| 重开不抛；旧行 audio_file_path=NULL 保留 | 抛错 / 改写 | 沿用 T032 既有测试 |
| TC-12 | P1 不新增 Drift 表 | 既有 3 表 | 表集合不变 | 多出表 | schema dump |
| TC-13 | OP-1 Spike 设备兼容矩阵 | 2 设备 × 3 时长 = 6 实验 | 6/6 通过 | 任一失败 | 真机（不在本任务执行） |
| TC-14 | 调音器算法 OP-2 ±10 cents 命中率 | 30 段录音 × 4 弦 × 3 时长 | ≥ 70% on-device | < 70% | 真机 |
| TC-15 | 5 分钟相对漂移 ≤ 50ms 初始目标 | T048C 校准 60/80 BPM × 简单下扫 × C/Am × 30 段 | 相对漂移 ≤ 50ms | > 50ms | 真机（属 P2 校准） |

**测试数量估算**：单元 / Controller / Widget 约 30-50 项（不锁定精确值；由后续 Implementation Plan 决定）；真机 Spike 不计入 unit count。

### 7.3 不可验证 / 待证据项

- **5 分钟相对漂移 ≤ 50 ms**：仅作为初始验收目标；P2 真机校准后由 P2 关闭门 review 重新协商；**不**作为 P1 通过门
- **OP-1 A 方案是否被批准为 P1 正式方案**：需 T048A 真机 Spike 完成 + ADR 落盘
- **调音器命中率 ≥ 70% on-device**：需 OP-2 Spike 完成
- **反馈延迟 150-300 ms wall-clock**：P1 不实现反馈（P2 才需）

---

## 8. Drift 边界

### 8.1 现状

- `AppDatabase`（T013.1 + T032 既有）`schemaVersion = 2`
- `MigrationStrategy.onUpgrade` 1→2 显式 no-op（contract bump）
- 三表：`practice_records` / `user_settings` / `completed_tasks`
- `beforeOpen` **不**做 schema-version-managed 操作

### 8.2 Phase 1 行为

- **保持 `schemaVersion = 2`**（P1 不升级）
- **不**新增 Drift 表
- **不**修改既有表列
- **不**调用 `m.createAll()` 在 `beforeOpen` 静默建业务表
- **不**修改 `app_database.dart` / `app_database.g.dart` / `*.g.dart` 任何生成文件

### 8.3 TDD 任务移交的测试矩阵（**沿用 SDD v0.4 TDD 8 项硬门**）

| # | 验证项 | P1 状态 |
|---|---|---|
| 1 | 新安装走 `onCreate` 创建 v2 schema | 既有（T032 + T013.1 覆盖） |
| 2 | v1 fixture 升级到 v3 | **P2 触发**（schemaVersion 升级到 v3 时） |
| 3 | v2 fixture 升级到 v3 | **P2 触发** |
| 4 | v3 数据库重复打开 | **P2 触发** |
| 5 | `scores` 表 6 列 + 约束 + 索引三方一致 | **P2 触发**（P1 无 `scores` 表） |
| 6 | 注入迁移失败回滚 | **P2 触发** |
| 7 | fixture 来自真实历史 SQLite 文件或可信快照（**不**得用 `PRAGMA user_version` 伪造） | **P2 触发** |
| 8 | 每条升级路径验证旧表 / 旧数据保留 | **P2 触发** |

**P1 维护的最小 Drift 测试**（TC-10 / TC-11 / TC-12）：仅验证 schemaVersion=2 不变 + onUpgrade 1→2 no-op + 不新增表；**不**重复 SDD v0.4 TDD 8 项硬门（那属于 P2 任务）。

---

## 9. 候选工作包与实施顺序

> **TDD 仅提出候选工作包，不启动实施，不预占最终 Task ID**。最终 Task ID / 提交顺序 / 分批验证命令由后续 Implementation Plan 决定。

### 9.1 候选工作包（**约 9 个 / 每包单一核心目标**）

| 候选 ID | 核心目标 | 依赖 | 风险 | 验收证据 | 真机可见 |
|---|---|---|---|---|---|
| T048A-OP1 | OP-1 Audio Spike 协议 | 既有 T029 录音 | 5min 稳态 + 设备兼容 | ADR 落盘 + 7 项必含清单 | 真机 6 次实验 |
| T048B-OP2 | OP-2 调音器精度 Spike | 既有 T029 录音 | ±10 cents 命中率 < 70% | ADR 落盘 + 30 段录音命中率 | 真机 30 段 |
| T1-OP1-Decision | OP-1 ADR 决议 + 选择 A/C/D | T048A | 全部失败回退 E（不可） | 决策门 / 降级 / 回滚矩阵 | APK |
| T2-Metronome-Audio | 节拍器可听点击音 | T010 既有 | 引入资产 / 依赖 | 节拍器 80 BPM 听感 | APK |
| T3-Tuner-RealTime | 调音器实时反馈 | T1 OP-2 算法 | 算法命中率 / 误检 | ±10 cents 命中率 ≥ 70% | APK |
| T4-Metronome-ADJUST | 节拍器 ADJUST（沿用 T2） | T2 | 跨 Controller 一致性 | 节拍器可听 + 设置 defaultBpm | APK |
| T5-Chords-7 | +G7/Dm/Em | T008 既有 | 不变量违例 | 7 和弦全显示 | APK |
| T6-SingleNotes-7 | +B | T009 既有 | 不变量违例 | 7 单音全显示 | APK |
| T7-Theme-Dark | 深色 token | 既有 | widget 崩溃 | 深浅切换不爆 | APK |
| T8-Settings-UI | 设置页暴露 defaultBpm / volume / 反馈项开关 | T013.2 既有 `UserSettingsRepository`（P1 仅内存包装层；Drift 列新增延后 P2 升级 v2→v3） | 内存 getter/setter 往返；P2 关闭门走持久化往返 | APK |
| T9-Phase1-Gate | P1 关闭门（4 项 §7.2 P0 补齐 + OP-1 ADR + 真机录屏） | T1-T8 全部 | 关闭门不达标 → 不进入 P2 | APK 录屏 + 文档 | 真机录屏 |

### 9.2 顺序与依赖

```
T048A-OP1 + T048B-OP2 ─┐
                       ├─→ T1-OP1-Decision ─┬─→ T3-Tuner-RealTime ─┐
                       │                    │                       │
T2-Metronome-Audio ────┼─→ T4-Metronome-ADJUST ─────────────────────┤
                       │                                            ├─→ T9-Phase1-Gate
T5-Chords-7 ───────────┤                                            │
T6-SingleNotes-7 ──────┼────────────────────────────────────────────┤
T7-Theme-Dark ─────────┤                                            │
T8-Settings-UI ────────┴────────────────────────────────────────────┘
```

**节奏铁律**（PRD §6）：任意连续 3 个开发任务必须产生真机可见成果（APK 可装、用户能感知）。**显式分组**：

| Demo 组 | 包含任务 | 真机可见产物 |
|---|---|---|
| Demo A | T2-Metronome-Audio + T5-Chords-7 + T6-SingleNotes-7 | 装 APK → 节拍器可听 80 BPM + 7 和弦库 + 7 单音库 |
| Demo B | T7-Theme-Dark + T8-Settings-UI + T4-Metronome-ADJUST | 装 APK → 深色 UI + 设置页暴露 defaultBpm/volume + 节拍器接入 |
| Demo C | T1-OP1-Decision + T3-Tuner-RealTime + T9-Phase1-Gate | 装 APK → OP-1 ADR 落盘 + 调音器实时反馈 + P1 关闭门录屏 |

**门禁**：每个 Demo 组**必须** APK 装到真机 + 录屏 + 用户可感知；任一组失败 → 后续 Demo 不开始。

### 9.3 Spike 失败应对

| 失败场景 | 应对 |
|---|---|
| T048A-OP1 A 方案**不**通过 | T1-OP1-Decision 选 C 或 D；T3-Tuner-RealTime 同步调整（不依赖 A 方案的 PCM 流）；T9 仍可关闭（用 C/D 完成 P1 调音器） |
| T048A-OP1 A / C / D **全部**失败 | P1 关闭门不达标；P1 延长 1 个 sprint 重做 Spike；P2 不开门 |
| T048B-OP2 ±10 cents 命中率 < 70% | 接受 ±20 cents 显式"实验性"标签；T3 仍可关闭（降级路径） |
| T048B-OP2 命中率 < 50% | 回退静态 GCEA 频率表（T003 既有降级路径）；T3 仍可关闭 |

### 9.4 Day 3/5/6/7 课程冻结

> 来自 PRD §5.2 切片强约束 + SDD §8 P2 关键门："在第一互动切片真机验证前，不扩展 Day 3/5/6/7 课程数量"。

- Phase 1 不得修改 `lesson_constants.dart`（保持 T043 单 `c_am_down_4x4` 课程）
- Phase 1 不得修改 `practice_plan_constants.dart`（保持 v1.1.0 7 天计划）
- **触发条件**：P2 关键门通过（9 步闭环真机录屏 + 节奏/起音对齐初始校准完成）后才能扩展

---

## 10. 开放问题与停止门

### 10.1 开放问题

| # | 问题 | Owner | 最晚决策点 | 所需证据 | 默认降级方案 | 阻断范围 |
|---|---|---|---|---|---|---|
| OP-1 | A 方案是否被批准为 P1 正式方案 | 04-audio-engineer | P1 关闭门 | T048A 真机 Spike 7 项必含 + 设备兼容矩阵 | C（事后解码）或 D（FFI） | 阻断 P1 调音器 + P2 Session |
| OP-2 | 调音器算法（实时音高检测） | 04-audio-engineer | P1 关闭门 | T048B 30 段录音 ±10 cents 命中率 | ±20 cents 显式"实验性"标签 / 静态 GCEA 频率表 | 阻断 P1 调音器（降级路径仍可关闭） |
| OP-3 | 音高识别算法 | 04-audio-engineer | P3 启动前 | P3 spike | P3 延长 sprint | 阻断 P3 |
| OP-4 | 和弦识别算法 | 04-audio-engineer | P3 启动前 | P3 spike | P3 延长 sprint | 阻断 P3 |
| OP-5 | 哑音切换检测 | 04-audio-engineer | P2 启动前 | 与 OP-1 同 spike 范围 | 标"非阻断观察"+ 自评辅助 | **不**阻断 P2（不进入过关判定） |
| OP-6 | 节拍器点击音源资产（CC0） | 主会话 | T2 阶段 | CC0 仓库验证 + 试听 | 沿用项目内 assets | 阻断 T2 |
| OP-7 | 反馈项默认值（P2 触发） | 主会话 | P2 启动 | P2 关闭门 review | 全开 + 用户可关闭 | 阻断 P2（默认即可） |

### 10.2 停止门

| 门 | 触发条件 | 动作 |
|---|---|---|
| SD1 | OP-1 A 方案真机 Spike 失败 + C/D 失败 | P1 关闭门不达标；P1 延长 1 sprint；P2 不开门 |
| SD2 | 调音器命中率 < 50% on-device | 回退静态 GCEA 频率表；T3 仍可关闭 |
| SD3 | 节拍器音频播放引入新顶层依赖 | 立即停止；改用项目内 assets 替换 |
| SD4 | Drift schemaVersion 被无意修改 | 立即停止；回滚 + 写技术债 |
| SD5 | PRD/SDD/ROADMAP Phase 1 范围冲突 | 立即停止并报告（**不**自行选择其一） |
| SD6 | P1 引入 INTERNET 权限 / 联网模块 / 占位抽象接口 | 立即停止并报告 |
| SD7 | Day 3/5/6/7 课程数量被 P1 修改 | 立即停止并回滚（PRD §5.2 强约束） |
| SD8 | T047B Reviewer 留下的 2 项 Minor 被 P1 修复 | 由 Implementation Plan 独立处理，**不**在 P1 顺手修 |

### 10.3 T047B Reviewer 留下的 2 项 Minor 处理

| ID | 内容 | 影响 Phase 1 TDD？ | 处理方式 | 跟踪位置 |
|---|---|---|---|---|
| F-1 | `TASK_LEDGER.md` line 470（T047 既有条目）保留已废弃"`else if`"字样 | **不**影响（历史记录；TDD 范围外） | 留作未来独立 ledger audit 任务；**不**登记新 TECH_DEBT（**不**是新债） | `docs/dev/AGENT_QUALITY_METRICS.md` §4.Z T047B Scorecard Notes 已记录 |
| F-2 | `ROADMAP.md` P4 Curriculum 行写"Drift schemaVersion=2 → 3"与实际 P4 升级 3→4 冲突 | **不**影响 P1（P1 schemaVersion 不变；冲突属 P4 阶段） | 留作 ROADMAP cleanup 任务；**不**在 P1 顺手修；**不**登记新 TECH_DEBT（属 P4 / 不阻塞 P1） | `docs/dev/AGENT_QUALITY_METRICS.md` §4.Z T047B Scorecard Notes 已记录 |

**说明**：T047B Reviewer 明确这两项为"Pre-existing historical ledger entry retains deprecated wording" + "Pre-existing inconsistency from T047A"；**不**构成本 P1 TDD 阻断。F-2 ROADMAP 冲突**仅**在 P4 启动前需要解决（彼时 P1 已关闭），P1 阶段 0 影响。两项均已在 T047B Scorecard 留痕（不是新债，不重复登记 TD-NNN）。

### 10.4 真实真机证据原则

- 任何"已验证" / "通过" / "officially supported"措辞必须以**真机录屏 / 真机日志 / 真机配置文件**为证据
- 不得以模拟数据 / 假设场景 / Spike 协议 / 单元测试替代码真机证据
- ADR 必含 7 项必含清单结果 + 设备 + 时长 + 数据

---

## 11. 多 Agent 协作（3 名 Reviewer）

| 角色 | Agent ID | 关注点 | 裁决 |
|---|---|---|---|
| Audio Test Strategy Reviewer | `t048-audio-test-strategy-reviewer`（subagent `a9f2d2dd31d8fcd6b`） | Spike 可执行性 / 时钟 / 同步 / 失败降级 / OP-1 7 项必含 | **Approved**（0 Blocker，0 findings；12 项必含检查全部通过；详见 v1.0 Notes） |
| Flutter State Data Reviewer | `t048-flutter-reviewer` | 状态所有权 / 生命周期 / 测试隔离 / Drift 边界 / §6 接口契约 | **Approved（带 F-1 修复）**：r1 Blocker（F-1 SharedPreferences 不存在）+ 4 Major + 3 Minor；v1.0 修复后（§6.2.3 改用 T013.2 Drift-backed `UserSettingsRepository`；§2.2 MetronomeSetting 字段更正；§6.4 T031-T035B 完整引用；§6.2.2 TickEvent 更正；§3.1 TunerController REFACTOR）→ 0 Remaining Blocker |
| Product Alignment Reviewer | `t048-product-alignment-reviewer`（subagent `a7f4d64a749b97200`） | Phase 1 范围 / 用户可见成果 / 是否偏离 PRD / 9 路由 P1 不增不减 / Day 3+ 课程冻结 | **Approved**（0 Blocker，12 项检查全部通过；详见 v1.0 Notes） |

Reviewer 报告按 `docs/dev/AGENT_REVIEW_TEMPLATE.md` 模板填写 Scope Reviewed / Evidence Checked / Findings / Verdict；**不得**使用 "Approved with Conditions"；**不得**带 Blocker 提交；**不得**修改文件。

**v1.0 修复闭环摘要**：
- F-1 Blocker：§6.2.3 改用 T013.2 Drift-backed `UserSettingsRepository`（pubspec 无 `shared_preferences` 依赖）；§1 / §2.3 / §7.2 TC-4 / §9.1-T8 同步更新
- F-2 Major：§6.4 明确 `MetronomeSettings` 字段 KEEP + `MetronomeState` 仅扩展 `volume` 字段；KEEP/ADJUST 边界明确
- F-3 Major：§2.2 MetronomeSetting 字段更正（`bpm/minBpm/maxBpm/beatsPerBar/soundEnabled`，**不**含 `volume/isPlaying`）；`volume/isPlaying` 拆分到 `MetronomeState`
- F-4 Major：§6.4 既有契约保护完整列出 T031 / T031C / T031E / T031I / T032 / T033 / T034 / T035 / T035A / T035B / T038B
- F-5 Minor：§3.1 TunerController 标 REFACTOR（沿用 T011 既有 `TunerState`）+ §6.4 显式说明
- F-6 Minor：§7.2 TC-3 Fake 边界标 P1 NEW（与 §6.2.2 同步）
- F-7 Minor：§6.2.2 TickEvent 更正为 `(状态发布 + tickForTesting 测试入口)` + `BeatTick` 流是 P1 NEW T2 阶段
- F-8 Minor：§3.2 dispose 措辞软化（不调 `service.dispose` 原则，非"100% 一致"）

---

## 12. 引用

PRD v0.3 / SDD v0.4 / ROADMAP / TASK_LEDGER（T027-T047B）/ AGENT_QUALITY_METRICS / TECH_DEBT / REAL_AUDIO_MVP_SDD / REAL_AUDIO_MVP_TDD / REAL_AUDIO_DEPENDENCY_SPIKE / lesson_c_am_down_4x4 / T041_BEGINNER_LEARNING_PHASE_2_SCOPE / lesson_constants.dart / app_database.dart / router.dart / Context7 record / just_audio / permission_handler
