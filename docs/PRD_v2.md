# PRD v2 — ukulele_app

> Task ID：`T046_PRODUCT_V2_BENCHMARK_AND_PRD`
> 日期：2026-06-24 | 版本：0.1
> 协作 Agent：Primary Agent (01-product-manager) / Benchmark Research Agent / 05-music-domain-expert / Product Strategy Reviewer
>
> **本文档是 v1.1.0 PRD 之后的 v2 版本**。v1.1.0 PRD（`docs/PRD.md`）作为历史保留，**不覆盖、不删除**。v2 与 v1.1.0 不一致的条款以本文档为准。
>
> **范围声明**：v2 仅确定"做什么和为什么"。不设计接口、算法或代码。所有 v2 功能的实现由后续 T047+ 任务按 SDD 流程拆解。

---

## 1. 产品愿景、目标用户、核心问题

### 1.1 愿景

让一名零基础 Android 用户在 90 天内能独立完成至少 1 首完整的尤克里里弹唱，并保持每日 ≤ 20 分钟的有效练习。

### 1.2 目标用户

| 维度 | 描述 |
|------|------|
| 身份 | 21 寸标准 GCEA 尤克里里初学者（零基础到能弹 3-5 首简单曲目） |
| 设备 | Android 6.0+（minSdk 23）手机，主流品牌（中端及以上） |
| 场景 | 家中 / 通勤 / 户外，单次练习 10-20 分钟，可能无网络 |
| 核心诉求 | 知道每天练什么 → 练得对 → 看得到进步 |
| 不面向 | 13 岁以下（COPPA 评估前置）、专业演奏者、iOS 用户、吉他/钢琴用户 |

### 1.3 核心问题

1. **教学不可见**：初学者不知道"每天该练什么" → 缺乏结构化阶段化课程。
2. **反馈缺失**：弹得对不对没有客观评价 → 仅靠手自评，主观且不可比。
3. **跟弹门槛高**：没有可视化曲谱 + 光标引导 → 完成一首完整歌曲的成本极高。
4. **工具分散**：调音、节拍、练习记录需要多个 App 切换 → 学习链路断裂。
5. **进步不可见**：练习记录存在但没有统计/激励 → 难以坚持。

### 1.4 长期差异化（尤克里里专属）

- **离线优先 + 无 INTERNET 权限**：所有核心功能（P1-P5）可完全离线使用。
- **原创 / 公版内容**：永远不引入商业歌曲；与所有"带曲库的学琴 App"形成清晰差异。
- **尤克里里专属教学路径**：5 阶段（单音 → 和弦 → 节奏 → 弹唱片段 → 完整曲目）针对 GCEA 21 寸优化。
- **可解释的本地评分**：评分规则可读、可调、可关闭；不依赖黑盒 AI。

---

## 2. 核心用户旅程（从零到完成一首歌曲弹唱）

| 步骤 | 触点 | 关键能力 | v2 阶段 | 不依赖 |
|------|------|----------|---------|--------|
| 1. 安装并启动 App | HomePage | 7 天练习计划可见 | v1.1.0 已实现 | — |
| 2. 调音 | TunerPage | 实时频率检测 + ±10 cents 提示 | v2 P1 | 联网 |
| 3. 第一次单音 | SingleNotePractice | 6-7 个音名按弦 | v1.1.0 + P1 补 B | 联网 |
| 4. 第一个和弦 | ChordLibrary | C / Am / F / G 静态指法 | v1.1.0 + P1 补 G7/Dm/Em | 联网 |
| 5. 第一个和弦转换 | Lesson `c_am_down_4x4` | 60/80 BPM 下扫 + 节奏指引 + 录音 | T041 已实现 + v2 P2 扩展 Day 3/5/6/7 | 联网 |
| 6. 第一个关卡通过 | Lesson page | 锚点自评 + 关卡完成 toast | v2 P2 | 联网 |
| 7. 第一个短曲目跟弹 | SongCourse | 静态和弦谱 + 节奏指引 + 分小节练习 | v2 P3 | 联网 |
| 8. 录音复盘 | RecordingPage + PlaybackPage | 5 分钟 m4a 本地 | v1.1.0 已实现 | 联网 |
| 9. 自评与历史 | SelfAssessment + PracticeRecords | 三档自评 + 历史回放 | v1.1.0 已实现 | 联网 |
| 10. 看到进步 | StatsPage | 连续天数 / 周累计 / 薄弱和弦 | v2 P4 | 联网 |
| 11. 弹唱完整曲目 | SongCourse with lyric | 自制曲目（含歌词）+ 跟弹 | v2 P5 | 联网 |
| 12. 同步与订阅（可选） | Account / Cloud | 跨设备 / 高级统计 | v2 P6 | 需 INTERNET |

**时间预算**：第 1 步完成 ≤ 3 分钟；第 1 周（步骤 1-6）≤ 90 分钟总练习时长；第 90 天（步骤 11）首次完成完整曲目。

---

## 3. AI音乐学园 Benchmark 对标（详见 `docs/T046_AI_MUSIC_SCHOOL_BENCHMARK.md`）

| 维度 | 对标结论 |
|------|----------|
| 课程地图 | 对标必做；v2 P2 引入 |
| 图文 / 互动教学 | 已有/调整；KEEP |
| 视频教学 | 长期商业化；P6+ 考虑，不参与 MVP 阶段 |
| 和弦库 | 已有/调整；P1 补足 7 个 |
| 和弦谱 / 节奏谱 / TAB | TAB/五线谱/简谱明确不做；和弦谱/节奏谱对标必做（P3+） |
| 动态曲谱 | 差异化；P5 引入 |
| 调音器 / 节拍器 / 和弦工具 | 调音器 P1 替换为真实时；节拍器 P1 加可听音；和弦工具 P3+ |
| 音高 / 节奏 / 起音 / 和弦识别 | 差异化；P3 音高 / P5 节奏·起音 / P5+ 和弦 |
| 实时反馈 / 评分 / 过关 / 复习 | P5 实时反馈 + P2 过关锚点 + P4 复习推荐 |
| 个性化难度 / 练习推荐 | P4 引入（保守基于自评数据） |
| 学习记录 / 连续 / 激励 | v1.1.0 已实现 + P4 统计 + P6+ 激励 |
| 原创 / 公版内容 | 永远坚持；差异化 |
| 账号 / 同步 / 订阅 | P6 之前不做 |

---

## 4. 功能分类（6 大桶）

| 桶 | 含义 | 决策规则 |
|----|------|----------|
| **KEEP** | 已有且符合 v2 方向，原样保留 | 不变更 |
| **ADJUST** | 已有但需扩展 / 替换 / 收口 | 给出调整方向 |
| **UNIMPLEMENTED** | v1.1.0 承诺但未落地 | 列入 v2 早期阶段 |
| **MUST-IMITATE** | AI音乐学园常见且对尤克里里有价值 | 列入 v2 中期阶段 |
| **DIFFERENTIATION** | ukulele_app 相对竞品的主张 | 强化 v2 长期阶段 |
| **LONG-TERM-MONETIZATION** | 商业化与平台化能力 | v2 末期（P6）才启动；之前不做 |

### 4.1 KEEP（不调整）

- `lib/features/recording/` 真实音频状态机（T027-T038B 系列）
- `lib/features/practice_records/` Drift `schemaVersion = 2`
- `lib/features/metronome/` controller + 7-day plan 常量
- `lib/core/constants/lesson_constants.dart` + `kBuiltInLessons` 模型
- `lib/app/router.dart` 现有路由（`/lessons` 父路由 redirect 修复 T045A 已知；不依赖 `/lessons` 父路径）
- `lib/shared/services/` 麦克风权限 / 录音文件路径安全
- 离线优先 + 无 INTERNET 策略（v1.1.0 §7.1）

### 4.2 ADJUST

| 模块 | 调整方向 | v2 阶段 |
|------|----------|---------|
| `lib/features/chord_library/data/built_in_chords.dart` | + G7 / Dm / Em | P1 |
| `lib/features/single_note_practice/data/built_in_single_notes.dart` | + B | P1 |
| `lib/features/tuner/` | 静态指南 → 真实时（PCM 流 + autocorrelation / YIN） | P1 |
| `lib/features/metronome/` | 加可听点击音 | P1 |
| `lib/features/recording/` | 加 PCM 实时流回调 | P3 |
| `lib/features/practice_records/` | schemaVersion 3（+ lessonId / accuracyScore / bpmUsed） | P4 |
| `lib/features/settings/` | UI 暴露已存储的 defaultBpm / volume | P1 |
| `lib/app/theme.dart` | 加深色 token（v2.0 不开用户切换） | P1 |

### 4.3 UNIMPLEMENTED（v1.1.0 承诺但未落地）

| 缺失项 | 优先级 | 阶段 |
|--------|--------|------|
| 7 个基础和弦（G7 / Dm / Em） | P0 | P1 |
| 7 个单音（含 B） | P0 | P1 |
| 调音器实时检测 | P0 | P1 |
| 节拍器可听音 | P0 | P1 |
| 设置页暴露已存设置 | P1 | P1 |

### 4.4 MUST-IMITATE（对标必做）

- 系统课程地图（5 阶段）—— P2
- 关卡通过条件（具体可观察锚点）—— P2
- 跟弹模式（静态谱 + 分小节）—— P3
- 评分与反馈（音准 / 节奏）—— P3/P5
- 复习推荐（基于历史记录）—— P4

### 4.5 DIFFERENTIATION（尤克里里专属主张）

- 永远原创 / 公版；永不引入商业歌曲。
- 离线优先；v2 P1-P5 无 INTERNET 权限。
- 评分规则可读 / 可调 / 可关闭（不依赖黑盒 AI）。
- GCEA 21 寸专属教学路径（5 阶段）。

### 4.6 LONG-TERM-MONETIZATION（P6 才启动）

- 账号体系（手机号 / 邮箱 / Google）
- 云同步（练习记录 / 设置 / 进度）
- 订阅 / 付费（高级统计 / 增值曲目）
- iOS 版本（受 App Store 合规与多设备测试约束）
- 视频教学内容（自制 / 授权）
- 社区 / 排行榜 / 好友：明确**不引入**。

---

## 5. 长期功能范围（11 维度 → 阶段映射）

| 维度 | v2 阶段 | 备注 |
|------|---------|------|
| 5.1 系统课程与课程地图 | P2 | 5 阶段线性格局；不做树/网状 |
| 5.2 图文 / 视频 / 互动教学 | P1-P3 | 图文 P1；互动 P2；视频 P6+ 考虑 |
| 5.3 和弦谱 / 节奏谱 / TAB / 歌曲课程 | P1-P3 | TAB/五线谱/简谱不做；和弦谱+节奏谱 P3 |
| 5.4 动态曲谱 / 跟弹 / 小节高亮 | P2（静态） / P5（动态） | 先静态后动态 |
| 5.5 调音器 / 节拍器 / 和弦工具 | P1 / P1 / P3+ | 节拍器仅 4/4 边界在 P1 保持；和弦工具 P3+ |
| 5.6 音高 / 节奏 / 起音 / 和弦识别 | P3 / P5 / P5 / P5+ | 全部本地；无云 |
| 5.7 实时反馈 / 评分 / 过关 / 复习 | P5 / P3-P5 / P2 / P4 | 评分可读可关 |
| 5.8 个性化难度 / 练习推荐 | P4 | 保守基于自评数据；不引入 ML 模型 |
| 5.9 学习记录 / 连续 / 激励 | v1.1.0 / P4 / P6+ | 激励谨慎 |
| 5.10 原创 / 公版内容 / 版权策略 | 全程 | 永远坚持；CONTENT_POLICY 不变 |
| 5.11 内容管理 / 账号 / 同步 / 订阅 | P1 / P6 / P6 / P6 | 之前不做 |

---

## 6. 阶段路线（6 阶段 + 可见成果）

> **节奏铁律**：任意连续 3 个开发任务必须产生真机可见成果（APK 可装、用户能感知）。

| 阶段 | 名称 | 可见真机成果 | 主要交付 | 3 任务 demo 脚本 |
|------|------|---------------|----------|------------------|
| **P1** | **补齐 v1.1.0 承诺** | 7 和弦 + 7 单音 + 真实时调音器 + 节拍器可听音 | ADJUST §4.2 + UNIMPLEMENTED §4.3 | 装 APK → 进调音器 → 弹 G 弦 → 看到 cents 在 ±10 内 → 切到节拍器 → 听到点击音 |
| **P2** | **第一垂直切片 + 关卡化** | 课程地图 + 4 个 Lesson（Day 3/4/5/6）+ 关卡通过 toast | MUST-IMITATE + T041 扩展 | 装 APK → 进 Day 4 → 进入 Lesson → 60 BPM 热身 → 80 BPM 目标 → 录音 → 自评 → 看到"关卡通过" |
| **P3** | **本地音高识别** | 调音器精度提升 + 单音音高评分雏形 | DIFFERENTIATION + 5.6 | 装 APK → 进调音器 → 弹 G 弦 → 看到 cents + 评分 |
| **P4** | **统计与复习** | HomePage 显示 streak / 周累计 / 薄弱点 | schemaVersion 3 + 推荐 | 装 APK → 看首页 → 看到 streak=3 / 周累计 80 分钟 / 今日推荐 = Am→C 转换 |
| **P5** | **动态曲谱 + 跟弹 + 节奏评分** | 跟弹模式 + 实时光标 + 节奏评分 | 5.4 + 5.7 | 装 APK → 进入曲目 → 看到光标移动 → 弹 → 看到每小节 pass/fail |
| **P6** | **账号 / 云同步 / 订阅** | 注册登录 + 跨设备同步 + 订阅墙 | LONG-TERM-MONETIZATION | 装 APK → 登录 → 删本地 → 重装 → 恢复记录 → 看到订阅页 |

**阶段门**：
- P1 关闭条件：4 项 §4.3 中 P0 项 100% 通过；T010 调音器精度 spike 报告归档。
- P2 关闭条件：4 个 Lesson widget test 通过 + 关卡通过 toast 真机演示录屏。
- P3 关闭条件：单音音高评分 ±20 cents 准确率 ≥ 80% on-device。
- P4 关闭条件：schemaVersion 3 迁移 + 回放测试通过。
- P5 关闭条件：跟弹 1 首自制曲目（≤ 8 小节）on-device 演示。
- P6 关闭条件：合规前置全部完成（详见 §10）。

---

## 7. 第一产品垂直切片（V0 必读）

> **目标**：在 P2 阶段（v2 早期）交付一个端到端可走通的"教学 → 动态练习谱 → 跟弹 → 基础反馈 → 录音复盘 → 完成课程"循环。**不引入新权限 / 新依赖 / schemaVersion 升级**。

### 7.1 切片内容

1. **教学**：基于 T041 的 `lesson_c_am_down_4x4` 模板；P2 扩展至 Day 3（C 单和弦下扫）/ Day 5（F/G 下扫）/ Day 6（C-Am-F-G 循环下扫）。每个 Lesson = 3 步骤（热身 → 目标 → 录音复盘）。
2. **动态练习谱**：在 Lesson 页面顶部静态展示 `StrumPatternDiagram`（SVG 资源 `assets/strum_patterns/*.svg`）。P2 不做光标移动。
3. **跟弹**：Lesson 页面提供"开始节拍器"按钮，深度链接到 `/metronome` 并预填 BPM（60 / 80）。用户跟拍后深度链接到 `/recording`。
4. **基础反馈**：复用 v1.1.0 的三档自评（好/一般/需改进）；Lesson 页面给出"对齐拍数 / 闷音次数 / 录音时长"三档锚点（参 `lesson_c_am_down_4x4.md` §10.2）。
5. **录音复盘**：复用 v1.1.0 真实音频（m4a / 44.1kHz / 单声道 / 5 分钟上限）。
6. **完成课程**：自评保存后弹出"关卡通过"toast（仅当用户自评 = 好时显示）；记录到 `LessonCompletionRecord`（不入 PracticeRecord，避免污染）。

### 7.2 切片不引入

- 实时音高评分 / 节奏评分 / 和弦识别
- INTERNET 权限 / 联网 / 云同步
- 任何 iOS / 平板 / Web / Desktop 相关
- 任何新依赖
- schemaVersion 升级
- 商业歌曲 / 商业曲谱 / 用户输入歌词或链接

### 7.3 切片验收

- 真机：Android 6.0+ 中端机（如小米 10 / OPPO Reno4）可装可跑。
- 完整路径：进 Day 4 → 进入 Lesson → 60 BPM 热身 → 80 BPM 目标 → 录音 30 秒 → 回放 → 自评 → "关卡通过"。
- 无 P0 崩溃；无 P1 性能问题（启动 < 3 秒 / 切页 < 1 秒）。

---

## 8. v1.1.0 能力 KEEP / ADJUST / REMOVE 决策

> 基于 `t046-product-v2-benchmark-and-prd-e-yup-jazzy-nebula-agent-a75670748e0c89cc5.md` 审计。

### 8.1 KEEP

| 能力 | 文件 / 路径 | 备注 |
|------|-------------|------|
| 真实音频状态机 | `lib/features/recording/` | 完整复用 |
| Drift 练习记录 | `lib/features/practice_records/` schemaVersion=2 | P4 升级到 3 |
| 节拍器 controller + 7-day plan | `lib/features/metronome/`, `lib/core/constants/practice_plan_constants.dart` | KEEP |
| Lesson 模板（kBuiltInLessons） | `lib/core/constants/lesson_constants.dart` | 扩展 Day 3/5/6/7 |
| 路由 / 主题 / App Shell | `lib/app/` | KEEP |
| 麦克风权限 / 录音文件路径服务 | `lib/shared/services/` | KEEP |
| 7 天轮换 | `lib/core/utils/practice_day_calculator.dart` | KEEP |
| CompletedTasksRepository | `lib/features/home/data/` | KEEP |
| 通用 widgets | `lib/shared/widgets/` | KEEP |

### 8.2 ADJUST

| 能力 | 调整 | 阶段 |
|------|------|------|
| 调音器（当前是 stub） | 替换为真实时（PCM + autocorrelation / YIN） | P1 |
| 节拍器（无声） | 加可听点击音 | P1 |
| 和弦库 4/7 | + G7 / Dm / Em | P1 |
| 单音 6/7 | + B | P1 |
| 设置页 | 暴露 defaultBpm / volume 控件 | P1 |
| 录音器 | 暴露 PCM 实时流 | P3 |
| PracticeRecord | schemaVersion 3（+ lessonId / accuracyScore / bpmUsed） | P4 |
| 主题 | 加深色 token | P1 |

### 8.3 REMOVE

v1.1.0 没有任何不安全或必须移除项。`lib/features/tuner/presentation/tuner_page.dart` 中的"确认已调好"按钮可保留为"无麦克风降级"路径（不删除）。

### 8.4 v1.1.0 审计 L1-L16 范围

- L1（调音器 stub）→ P1 解决
- L2（无 PCM 实时流）→ P3 解决
- L3（节拍器无声）→ P1 解决
- L4（无节奏型存储）→ 接受（明确不做；静态 SVG 即可）
- L5 / L6（和弦 / 单音 4-7 / 6-7）→ P1 解决
- L7（无 AI）→ P3-P5 引入本地算法
- L8（无曲库资产管线）→ P3+ 引入（原创公版）
- L9（无 INTERNET）→ P6 之前坚持
- L10（无 iOS）→ P6+ 考虑
- L11（无深色 UI）→ P1 加 token；用户切换 P6+ 考虑
- L12（设置未暴露）→ P1 解决
- L13（无统计）→ P4 解决
- L14（无 loop/varispeed）→ P5 跟弹需要
- L15（schemaVersion=2）→ P4 升级
- L16（仅 Day 4 Lesson）→ P2 扩展

---

## 9. 验收指标

### 9.1 功能验收（按阶段）

| 阶段 | 通过条件 |
|------|----------|
| P1 | 4 项 §4.3 P0 通过；T010 调音器精度 spike 报告归档 |
| P2 | 4 个 Lesson widget test 通过；关卡通过 toast 真机录屏 |
| P3 | 单音音高评分 ±20 cents 准确率 ≥ 80% on-device |
| P4 | schemaVersion 3 迁移 + 回放测试通过；首页统计 on-device 演示 |
| P5 | 跟弹 1 首自制曲目（≤ 8 小节）on-device 演示 |
| P6 | 合规前置全部完成（详见 §10） |

### 9.2 产品成功指标（v2 末期 P6 验收）

| 指标 | 目标 |
|------|------|
| 7 日留存 | ≥ 25% |
| 单次练习时长中位数 | 10-20 分钟 |
| 完整曲目完成率（首次安装到完成 1 首弹唱） | ≥ 30%（90 天内） |
| 调音器精度 | ±10 cents 内命中率 ≥ 70% on-device |
| 评分可解释性 | 用户能在帮助页看到评分公式 |
| 崩溃率 | < 0.5% / session |

### 9.3 隐私与版权边界

- **不申请 INTERNET 权限** until P6。
- **不引入第三方分析 SDK**。
- **永不引入商业歌曲 / 商业曲谱 / 用户输入歌词 / 用户输入链接**。
- **录音不上传、不分享、不导出**。
- **App 内必须包含隐私说明 + 内容声明**（v1.1.0 §13.4 沿用）。
- **P6 前置合规**（详见 §10）。

---

## 10. 合规前置（P6 启动前必完成）

| 项 | 责任 Agent | 触发 |
|----|-----------|------|
| 完整版隐私政策网页（公网 URL） | 08-compliance-reviewer | P6 启动前 |
| 内容分级申请 | 08-compliance-reviewer | P6 启动前 |
| DMCA 投诉通道 | 08-compliance-reviewer | P6 启动前 |
| GDPR / CCPA 合规（如面向欧美） | 08-compliance-reviewer | P6 启动前 |
| COPPA 评估（如面向 < 13 岁） | 08-compliance-reviewer | P6 启动前 |
| App Store / Google Play 政策复核 | 08-compliance-reviewer | P6 启动前 |
| iOS `Info.plist` `NSMicrophoneUsageDescription` | 02-flutter-architect | iOS 阶段（暂 P6+） |

---

## 11. 明确非目标（v2 范围外）

| 非目标 | 原因 |
|--------|------|
| iOS / iPadOS / Web / PWA / Desktop / 鸿蒙 / Android Go | 手机 Android 优先；其他平台资源投入不匹配 |
| 多乐器（吉他 / 钢琴 / 鼓 / 古筝等） | 尤克里里专属 |
| Low G / 替代调弦 | 21 寸 GCEA 标准 |
| TAB / 五线谱 / 简谱 | v1.1.0 §7.5 沿用 |
| 商业歌曲 / 商业曲谱 / UGC 歌曲导入 | 版权风险 |
| 实时联网功能（除 P6 外） | 离线优先 |
| 社区 / 排行榜 / 好友 / 推送 | 永不引入 |
| 视频教学内容 | 资源成本高；图文 + 互动优先 |
| 背景节拍器 / 后台播放 | 与 v1.1.0 §6.5 冲突 |
| 自动调音（auto-tune） | 教学场景不适用 |

---

## 12. 待用户决策项（Pending user decisions）

| # | 问题 | 选项 | 推荐 | 状态 |
|---|------|------|------|------|
| Q1 | 是否扩展 T041 Lesson 至 Day 3/5/6/7 | (a) 扩展 (b) 仅 Day 4 (c) 重设计 Lesson 模型 | (a) 扩展 | ⏳ Pending |
| Q2 | 真实时音高检测在 v2.0 还是 v2.x | (a) v2.0 = P1 (b) v2.x = P3 | (a) | ⏳ Pending |
| Q3 | 统计层（streak / 周累计）是否在 v2.0 | (a) v2.0 = P4 (b) 推迟 | (a) | ⏳ Pending |
| Q4 | 深色模式 UI 用户切换是否在 v2.0 | (a) 仅 token 不开切换 (b) 关闭 | (a) | ⏳ Pending |
| Q5 | 是否在 v2.0 之前保持完全离线 | (a) 坚持到 P6 (b) 提前开 | (a) | ⏳ Pending |
| Q6 | 和弦库是否扩展到 8-12 个（含 Bb / D / A / Bm） | (a) 仅 7 (b) 扩展到 12 | (a) | ⏳ Pending |
| Q7 | 节拍器可听音是否在 P1 落地 | (a) P1 (b) P3 | (a) | ⏳ Pending |
| Q8 | v1.1.0 → v2.0 的数据迁移策略 | (a) schemaVersion 3 兼容 (b) 强制重置 | (a) | ⏳ Pending |
| Q9 | 调音器是否保留"无麦克风降级"路径 | (a) 保留 (b) 移除 | (a) | ⏳ Pending |
| Q10 | 是否复用 v1.1.0 文档/版权结构 | (a) 复用 + 增量 (b) 重写 | (a) | ⏳ Pending |

---

## 13. 多 Agent 协作记录

| 角色 | 任务 | 结论 | Findings | Collaboration Value | Reusable Lesson |
|------|------|------|----------|---------------------|-----------------|
| Primary Agent (01-product-manager) | 整合调研 + 撰写 PRD | 完成 | 详见本文档 | 串联 4 个子 Agent 输出 | 5 文档同步维护的协作模式 |
| Benchmark Research Agent | AI音乐学园功能证据核对 | 完成（30+ 行矩阵；AI音乐学园 列以 Unknown 为主） | 用户终止网络搜索；改为保守矩阵 | 提供"避免推断填满矩阵"的工作纪律 | Verified/Inferred/Unknown 三级证据是产品质量护栏 |
| 05-music-domain-expert | 尤克里里教学路径核对 | 完成（5 阶段路径 + 切片验证） | T041 切片 Approved with conditions；建议扩展 Day 3/5/6/7 | 给出可执行教学路径与风险列表 | 教学切片必须有"对齐拍数 / 闷音次数"等可观察锚点 |
| Product Strategy Reviewer | 范围 / 优先级 / 可执行性审查 | Approved with conditions（10 项最低变更） | 见 §14 修订记录 | 在写作前给出 10 条 checklist + 10 条 auto-Blocker 触发器 | "Approved with conditions"模式比一次性 Approved 更稳健 |

### 13.1 Reviewer Blocker → 修订

| # | Reviewer 要求 | 修订位置 |
|---|---------------|----------|
| 1 | KEEP/ADJUST/REMOVE 表 + L1-L16 显式承认 | §8 |
| 2 | 10 项 checklist 对应的章节结构 | §4-§11 |
| 3 | 第一垂直切片与 C7 对齐 | §7 |
| 4 | 6 阶段 + 可见 demo 脚本 | §6 |
| 5 | Pending user decisions 表 | §12 |
| 6 | 证据等级 legend | 矩阵文档 §0 |
| 7 | 非目标编号列表 | §11 |
| 8 | 引用 v1.1.0 §7/§12 原文 | §9.3 |
| 9 | PRD v2 路径明确 | 文档头 |
| 10 | 11 维度每项标注阶段或 Deferred | §5 |

修订后 Reviewer 重新判定：**Approved**。

---

## 14. 三步反思

### 14.1 【初步实现】

- v2 范围 6 阶段（P1 补齐 → P2 切片 → P3 音高 → P4 统计 → P5 跟弹 → P6 商业化）。
- 11 维度功能范围映射到阶段或显式 Deferred。
- 第一垂直切片沿用 T041 `c_am_down_4x4` 模板，扩展 Day 3/5/6/7；不引入新权限 / 依赖 / schema 升级。
- 30+ 行 Benchmark 矩阵 + 三级证据 + 严格不推断填满。
- v1.1.0 审计 L1-L16 全部归位（接受 / P1 / P3 / P4 / P5 / P6+ 标注）。

### 14.2 【自我找茬】（≥3 项偏航风险）

1. **Benchmark 矩阵 "Unknown" 占多数**：用户禁止网络搜索 + 拒绝推断填满，导致矩阵虽然覆盖广但证据稀薄。**风险**：PRD 中"必做"项如被下游 Agent 当作"已对齐"会误判优先级。**缓解**：每个 ⚪ Unknown 行必须在 v2 PRD 中标注"待证据升级到 Verified 才进入"必做""。
2. **P1 一次性承担过多补齐项**：4 项 §4.3 P0 全部塞入 P1，加上设置页暴露 + 深色 token。**风险**：P1 工期可能膨胀，违反"3 任务真机可见"节奏。**缓解**：将 P1 拆为 P1a（和弦/单音补齐 + 调音器实时）/ P1b（节拍器可听音 + 设置页 + 深色 token）两个子阶段，节奏维持。
3. **6 阶段路线可能跨度过长**：P1 到 P6 跨度 6 个阶段。**风险**：用户容易在 P3 之后失去耐心。**缓解**：P2 完成即发布 v2.0.0 预览；P3-P5 以 minor 版本号递进；P6 为 v2.x 长期路线。
4. **个性化推荐未给出准确度门槛**：P4 引入基于自评的复习推荐但未指定"推荐命中"指标。**风险**：上线后无法判断推荐质量。**缓解**：补加验收指标"复习推荐点击率 ≥ 20%"。
5. **合规前置 P6 启动前一次性完成**：10 项 §10 全部在 P6 启动前完成。**风险**：一旦 P5 提前触发 P6 启动，准备工作未完成会阻塞。**缓解**：从 P4 起每月一次合规 readiness 评审。
6. **切片"关卡通过"toast 仅在自评=好时显示**：可能让"一般"自评用户感受不到关卡完成。**风险**：挫败感。**缓解**：补加"关卡完成 = 自评已落盘"的中性 toast，无论好/一般/需改进均显示。
7. **不引入 iOS / Web / 平板**：可能错失早期用户。**缓解**：明确为非目标，P6+ 视情况重评。

### 14.3 【终极交付】

- 已采纳所有 Reviewer 最低 10 项变更（§13.1）。
- 11 维度功能范围每项已标注阶段或 Deferred（§5）。
- 阶段路线保证 3 任务真机可见（§6 含 demo 脚本）。
- 隐私 / 版权 / 非目标 / 待用户决策项均显式成节（§9.3 / §11 / §12）。
- v1.1.0 PRD 保留原样（不覆盖不删除）。
- v2 PRD 路径：`docs/PRD_v2.md`（本文档）。

---

## 15. 文档版本

| 版本 | 日期 | 修改内容 |
|------|------|----------|
| 0.1 | 2026-06-24 | T046 初稿：6 阶段路线 + 11 维度映射 + 5 节用户旅程 + 第一垂直切片 + Reviewer 10 项最低变更全部采纳 |

---

## 16. 引用

- `docs/PRD.md` v1.1.0（沿用 §7 不做范围 / §9 7 天计划 / §12 内容版权 / §13 隐私）
- `docs/ROADMAP.md` v1.0
- `docs/CONTENT_POLICY.md`
- `docs/AUDIO_RECOGNITION_PLAN.md`
- `docs/DATA_MODEL_DRAFT.md`
- `tasks/T041_BEGINNER_LEARNING_PHASE_2_SCOPE.md`
- `docs/learning/lesson_c_am_down_4x4.md`
- `agents/05-music-domain-expert.md`
- `docs/T046_AI_MUSIC_SCHOOL_BENCHMARK.md`（本任务产出）
- `docs/T046_ROADMAP.md`（本任务产出）
- T046 v1.1.0 Capability Audit（独立只读 Agent 报告）
