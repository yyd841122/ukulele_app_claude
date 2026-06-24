# 阶段路线图 (ROADMAP)

> 本文档定义项目从 Phase 0 到 V5 的完整演进路径。

## 0. 路线图总览

| 阶段 | 名称 | 核心交付物 | 预计顺序 |
|------|------|------------|----------|
| Phase 0 | 文档与多 Agent 体系 | 完整文档 + Agent 角色定义 | 当前 |
| Phase 1 | Flutter App Shell | 可运行的空壳 App | T004 |
| Phase 2 | 基础练习体系 | 首页 + 和弦库 + 指法图 | T007-T008 |
| Phase 3 | 调音器与音频基础 | 调音器 + 音频录制/播放 | T009-T011 |
| Phase 4 | 节拍器、录音、自评 | 节拍器 + 完整录音流程 | T010-T012 |
| Phase 5 | 本地练习记录 | 练习记录持久化 | T013 |
| Phase 6 | MVP 打磨 | QA + Polish | T014 |
| V1 | 音高评分 | AI 音高检测 | 后期 |
| V2 | 节奏评分 + 和弦反馈 | 节奏分析 + 和弦识别 | 后期 |
| V3 | 整曲练习 | 完整歌曲练习模式 | 后期 |
| V4 | AI 曲谱生成 | AI 服务集成 | 后期 |
| V5 | 账号 + 云同步 + 商业化 | 完整平台 | 后期 |

---

## Phase 0: 文档与多 Agent 体系

**状态**：当前阶段

**目标**：建立完整的项目文档、Agent 协作体系、任务拆分，为后续开发奠定基础。

**交付物**：
- [x] README.md
- [x] PRD.md
- [x] MVP_SCOPE.md
- [x] TECH_STACK.md
- [x] ARCHITECTURE.md
- [x] ROADMAP.md（本文档）
- [x] AUDIO_RECOGNITION_PLAN.md
- [x] COMPLIANCE.md
- [x] CONTENT_POLICY.md
- [x] DATA_MODEL_DRAFT.md
- [x] DEVELOPMENT_WORKFLOW.md
- [x] MULTI_AGENT_WORKFLOW.md
- [x] 3 个 ADR 文档
- [x] 9 个 Agent 角色文档
- [x] 任务索引和 Phase 文档
- [x] handoff/prompts 模板

**完成标准**：所有文档可读、可维护、可被新会话直接理解。

**前置条件**：无

---

## Phase 1: Flutter App Shell

**目标**：创建可运行的 Flutter 项目空壳，验证技术栈可行性。

**包含任务**：
- T004: 创建 Flutter 项目
- T005: 添加核心依赖
- T006: 构建路由和 App Shell

**交付物**：
- Flutter 项目结构
- pubspec.yaml 配置完成
- go_router 路由配置
- App Shell 可启动（首页空白页）

**完成标准**：
- APK 可编译并安装
- 冷启动无崩溃
- 路由跳转正常

**前置条件**：Phase 0 完成

---

## Phase 2: 基础练习体系

**目标**：构建首页、今日练习计划、和弦库、指法图展示。

**包含任务**：
- T007: 构建首页和今日练习

**交付物**：
- HomePage 展示
- 今日练习任务卡片
- 快速操作入口（调音器、节拍器、录音）
- ChordLibraryPage
- ChordDetailPage（指法图）

**完成标准**：
- 用户能浏览和弦列表
- 用户能查看单个和弦的指法图
- 今日练习任务可点击进入对应功能

**前置条件**：Phase 1 完成

---

## Phase 3: 调音器与音频基础能力

**目标**：实现标准 GCEA 调音器，验证音频采集和频率检测技术。

**包含任务**：
- T009: 调音器技术验证

**交付物**：
- TunerPage
- GCEA 四弦频率检测
- 音准显示（偏高/偏低/准确）
- 麦克风权限处理

**技术验证项**：
- 频率检测精度
- UI 响应延迟
- 功耗表现

**完成标准**：
- 能检测 G/C/E/A 四弦
- 显示当前频率和音名
- 能判断偏高/偏低/准确

**前置条件**：Phase 1 完成

---

## Phase 4: 节拍器、录音、回放、自评

**目标**：实现节拍器和完整录音流程。

**包含任务**：
- T010: 节拍器
- T011: 录音和回放
- T012: 自评

**交付物**：

**节拍器 (T010)**：
- MetronomePage
- BPM 可调（50-200）
- 基础节奏型（4/4, 3/4）
- 节拍声音

**录音和回放 (T011)**：
- RecordingPage
- 麦克风录制（最长 5 分钟）
- 录音列表
- PlaybackPage
- 播放控制（播放/暂停/停止）

**自评 (T012)**：
- SelfAssessmentDialog
- 三档自评（好/一般/需改进）
- 自评结果保存

**完成标准**：
- 节拍器按设定 BPM 发声
- 能录制并保存音频
- 能回放录音
- 能对录音进行自评

**前置条件**：Phase 3 完成

---

## Phase 5: 本地练习记录

**目标**：实现练习记录的持久化和查看。

**包含任务**：
- T013: 本地练习记录

**交付物**：
- PracticeRecordsPage
- 历史练习列表（按日期）
- 练习详情（时长、内容、自评）
- 录音回放入口
- Drift 数据库配置

**完成标准**：
- 练习记录保存到本地 SQLite
- 能查看历史练习日期和内容
- 能播放历史录音

**前置条件**：Phase 4 完成

---

## Phase 6: MVP 打磨

**目标**：QA 验收、Bug 修复、Polish、准备发布。

**包含任务**：
- T014: MVP QA 和打磨

**交付物**：
- 全流程测试
- Bug 修复
- 设置页完善
- 基础异常处理

**完成标准**：
- 所有 P0 功能可正常使用
- 无崩溃
- 离线流程完整
- 可提交 Google Play 内部测试

**前置条件**：Phase 5 完成

---

## V1: 基础音高评分

**目标**：引入 AI 音高检测能力。

**交付物**：
- 单音音高准确度评分
- 音高曲线可视化
- 评分反馈

**技术要求**：
- 音频频率分析
- 音高提取算法
- 评分模型（或简单阈值）

**前提**：Phase 6 完成，AI 技术验证

---

## V2: 节奏评分与和弦转换反馈

**目标**：增强评分能力和和弦识别。

**交付物**：
- 节奏准确度评分
- 节拍稳定性分析
- 和弦转换流畅度评估
- 扫弦方向识别（预留）

**技术要求**：
- 节奏检测算法
- 和弦识别模型
- 扫弦模式识别

**前提**：V1 完成

---

## V3: 整曲练习

**目标**：支持完整歌曲练习。

**交付物**：
- 整曲练习模式
- 歌曲和弦歌词谱
- 进度跟踪
- 练习统计

**内容要求**：
- 自制或授权歌曲
- 不内置未授权商业歌曲

**前提**：V2 完成，内容合规审查

---

## V4: AI 曲谱生成

**目标**：引入 AI 能力生成练习曲谱。

**交付物**：
- 哼唱/录音转和弦
- 节奏型建议
- 练习内容生成

**技术要求**：
- AI 服务抽象层
- 云端或本地 AI 模型
- API 集成

**前提**：V3 完成，AI 服务选型

---

## V5: 账号、云同步、商业化

**目标**：完整平台化。

**交付物**：
- 账号系统（手机号/Apple/Google）
- 云端练习记录同步
- 订阅收费
- App Store / Google Play 上架
- 社区/排行榜（可选）

**合规要求**：
- 各平台账号审核指南
- 隐私政策更新
- 订阅服务条款

**前提**：V4 完成，商业化准备

---

## 风险与依赖

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| 调音器频率检测精度不足 | Phase 3 阻塞 | T009 技术验证先行 |
| 音频录制延迟过高 | Phase 4 阻塞 | record 插件技术验证 |
| AI 评分技术方案不确定 | V1 延迟 | MVP 不做 AI，预留接口 |
| 版权问题 | V3 阻塞 | 坚持自制内容+公版 |
| iOS 审核被拒 | 发布延迟 | 提前了解 App Store 政策 |

## 阶段 2 后教学阶段（v1.1.0 之后）

> 真实音频 MVP v1.1.0 之后的初学者教学阶段 2 设计已落盘于 `tasks/T041_BEGINNER_LEARNING_PHASE_2_SCOPE.md`。
> 该文档**仅设计、不编码**；明确第一个垂直切片为 `C ↔ Am 4/4 下扫节奏`（Day 4 教学叠加层），不动 7 天计划 / 节拍器 domain / Drift schema / 既有 Controller。
> 后续实现任务（T042-T046）由 GPT 首席架构师出具独立 Prompt 后才能启动。

---

## Product V2 路线（T047 后）

> T047 (`T047_PRODUCT_V2_SYSTEM_DESIGN`) 已落盘 `docs/architecture/SDD_V2.md` v0.4（v0.1 → v0.2 由 3 位 Reviewer Approved with Conditions 修订；v0.2 → v0.3 由 T047A 二元裁决闭环 0 Blocker 修订；v0.3 → v0.4 由 T047B 二元裁决闭环 0 Blocker 修订）。
> 该 SDD 把 v2 长期对标功能（P1-P6）压缩为 10 个模块边界 + Drift 显式升级 schemaVersion: 2 → 3（P2 引入 `scores`，**累进式 cumulative `if (from < N)` 链**，覆盖 `from=1, to=3` 跨版本直接升级，**不**用 `else if` 精确分支对）+ 3 → 4（P4 处理 `practice_records.lessonId` 同样累进式追加）+ OP-1~OP-5 Spike 候选 + 9 步 mapping + 平台边界声明 + 不锁定算法 + 四类时钟区分 + 5 分钟漂移初始验收目标。
> **T047 / T047A / T047B 不进入 P1-P6 实现**；后续 T048 起按 SDD §10.2 风险缓解与 §3 模块边界逐步落地。

### Product V2 阶段门（SDD §8 + PRD §6 对齐）

| 阶段 | 名称 | SDD §8 关键约束 | TDD 启动信号 |
|------|------|----------------|--------------|
| **P1 Foundation** | 调音器实时反馈 + 节拍器可听 + 7 和弦 + 7 单音 + 设置 + 深色 token + **OP-1 Spike 决议** | OP-1 ~ OP-5 在 P1 内做 Spike 产出 ADR；不锁定具体算法 | T048A / T048B / T048C（T047 完成后启动） |
| **P2 Interactive Slice** | 9 步闭环第一课 + 起音/节奏反馈 + 真机录屏 | **P2 关键门 = 9 步闭环真机录屏 + 节奏/起音对齐初始校准完成 + Day 3/5/6/7 课程仍冻结** | T049+（P1 关闭门后启动） |
| P3 Audio Intelligence | 调音器精度 + 音高 + 和弦 + 哑音 | OP-3 / OP-4 在 P3 启动前 Spike；P2 不引入 | T050+ |
| P4 Curriculum | 课程地图 + 进度 + 复习 + 原创歌曲 | Drift schemaVersion=2 → 3（含 P2 `scores` 表列对齐）；P5 不在 P4 引入 | T051+ |
| P5 Personalization | 个性化推荐 + streak + 难度 | LocalProfile streak 字段 P5 启动时增列；schema 升级 | T052+ |
| P6 Platform | 账号 + 云同步 + CMS + 订阅 + iOS + 平板 | INTERNET 权限 + 合规前置（PRD §10）全部完成 | T053+；**不永久排除** iOS / 平板 / Low-G |

### SDD v0.3 关键决策摘要（v0.2 → v0.3 修订：与 ROADMAP §"Phase 1-6 / V1-V5" 对齐）

| SDD 章节 | v0.3 决策 | 对 ROADMAP 影响 |
|----------|----------|-----------------|
| §1.2 平台边界声明 | Android-first / common High-G GCEA 优先；iOS / 平板 / Low-G = Deferred + 前置条件（非永久 Out） | V1-V5 商业化路线不变；iOS 推迟到 P6+ 受合规前置约束 |
| §3.10 CMS/Account/Sync/Subscription 边界 | 严格 Deferred；P6 前不创建任何联网模块 / 抽象接口 / 占位 Dart 文件 | V5 商业化路线由 P6 阶段独立设计，不在 P1-P5 提前抽象 |
| §3.8 Drift schemaVersion 策略（**v0.4 勘误**） | **P2 引入 `scores` 表时显式升级 `schemaVersion: 2 → 3`**（v0.3 把"不升级 schemaVersion" + `beforeOpen` 静默 CREATE TABLE 写为已选定策略；v0.4 改为走 `MigrationStrategy.onUpgrade` + **累进式（cumulative）`if (from < N)` 链**（每个版本独立 `if` 块，互不互斥，**不**使用 `else if` 精确分支对，必须覆盖 `from=1, to=3` 跨版本直接升级）+ `@DriftDatabase(tables: [..., Scores])` + 类型化 `Into` 插入；`beforeOpen` **不得**用于创建正式业务表）；**P4 处理 `practice_records.lessonId` 关联字段时显式升级 `schemaVersion: 3 → 4`**（按累进式 `if (from < 4)` 追加，两个升级独立编号，**不**冲突） | T013 既有 schemaVersion=2 保持到 P2 启动前；P2 实际启动时第一次升级（v2→v3）；P4 第二次升级（v3→v4）；`app_database.dart` `onUpgrade` 必须**扩展为累进式 `if (from < N)` 链**——**禁止**使用 `else if` 精确分支对（处理 `from=1, to=3` 这种跨版本合法升级会落空） |
| §3.6 时间基准（**v0.3 修订**） | **四类时钟区分**（会话单调 / PCM 样本计数 / chunk 到达 / 设备采集）；明确不得把 chunk 到达时间伪装成设备采集时间；5 分钟稳态 ≤ 50 ms 改为**初始验收目标**（测量对象 = OnsetEvent ↔ BeatTick 相对漂移，非 wall-clock 绝对漂移，起止基准 = Session start / Session stop）；设备采集时间戳待 T048A Spike 验证 | T048 TDD 时间漂移测试语义明确；不依赖未证实的 record_android 内部单调时钟 |
| §7.2 A 方案（**v0.3 修订**） | **"首选 Spike 验证候选（非已证明架构）"**（v0.2 误写为"★★★ 推荐 P1 Spike"）；T048A 真机清单 7 项必含（5s/30s/5min 三档断点 + m4a 完整性 + PCM 连续性 + 权限生命周期 + 停止回调归属 + 资源释放 + 设备兼容矩阵）+ ADR 产出强制 | T048A 真机 Spike 必须通过 ADR 才允许成为 P1 正式方案；未通过则回退 C（事后解码）或 D（FFI），**不退回** E |
| §3.9 LocalProfile streak 字段 | P1-P5 不持有 streak 数据；P5 启动时再走 schema 升级（**注意**：P5 = `schemaVersion: 4 → 5` 或更高，P2 / P4 已占用 v3 / v4 名额） | P5 Personalization 阶段显式触发 streak schema 升级 |
| §8 P2 关键门 | 9 步闭环真机录屏 + 节奏/起音对齐初始校准完成 + Day 3/5/6/7 课程仍冻结 | T049+ 真机验收硬门 |
| §8 新依赖联签 | 任何 P1-P5 任务如需引入新依赖，必须经主会话 + Compliance Reviewer 联签 + ADR | V1-V5 路线新依赖走联签，不绕过 ROADMAP |

### ROADMAP 阶段门与 SDD v0.2 的引用关系

- **Phase 6 MVP Polish (T014)**：T016 已完成；T019-T024 Release 工程化完成；T025-T031E 真实音频 MVP 完成。
- **Product V2 Foundation (P1)** = T047 SDD v0.4 → **T048 TDD v1.0（已落盘 `docs/architecture/TDD_PRODUCT_V2_PHASE1.md`；3/3 Reviewer Approved；0 Blocker；0 Approved with Conditions；11 个候选工作包 / Demo A/B/C 三组真机可见分组；Drift schemaVersion=2 保持；Day 3/5/6/7 课程仍冻结）** → T048A OP-1 Spike → T048B OP-2 调音器精度 Spike → T048C 校准 → 9 步闭环 T049+ 实现。
- **SDD 是 ROADMAP 的"骨架"**：阶段门顺序不变；模块边界 / Drift 策略 / OP-1 决议 / 9 步 mapping / 平台边界 在 SDD v0.2 一次性锁定；T048+ TDD 任务按 SDD §3 + §4 + §6 落地。

> **不**修改本节前的 `Phase 0-6 / V1-V5` 任何条目；仅追加"Product V2 路线（T047 后）"章节作为 SDD v0.2 的 ROADMAP 引用层。

---

## 版本标签

| 标签 | 说明 |
|------|------|
| Phase 0-6 | MVP 开发阶段 |
| V1-V5 | MVP 后商业化阶段 |
| 当前 | Phase 0 进行中 |
