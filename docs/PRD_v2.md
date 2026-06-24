# PRD v2 — ukulele_app

> Task ID：`T046_PRODUCT_V2_PRD_CORRECTION`（基于 `T046_PRODUCT_V2_BENCHMARK_AND_PRD` v0.1 修订）
> 日期：2026-06-24 | 版本：0.2
> 协作 Agent：Primary Agent (01-product-manager) / Benchmark Research Agent / 05-music-domain-expert (ab73d240921ebe74d) / Product Strategy Reviewer (afd9457b253397ce1)
>
> **本文档是 v1.1.0 PRD 之后的 v2 版本**。v1.1.0 PRD（`docs/PRD.md`）作为历史保留，**不覆盖、不删除**。v2 与 v1.1.0 不一致的条款以本文档为准。
>
> **v0.2 修订**：重新定义第一产品垂直切片为 9 步互动闭环；调整阶段优先级为 5 阶段；将长期未实现功能统一标 Deferred + 前置条件（不永久排除）；压缩待决策项至 5 项；明确多乐器 Out of Scope。
>
> **范围声明**：v2 仅确定"做什么和为什么"。不设计接口、算法或代码。所有 v2 功能的实现由后续 T047+ 任务按 SDD 流程拆解。

---

## 1. 产品愿景（北极星）

让一名零基础 Android 用户在 90 天内**完成至少 1 首完整的尤克里里弹唱**，并保持每日 ≤ 20 分钟的有效练习；以**客观反馈 + 动态曲谱**为核心差异化能力；坚持离线优先、原创/公版内容、21 寸 GCEA 尤克里里专属教学。

---

## 2. 目标用户

| 维度 | 描述 |
|------|------|
| 身份 | 21 寸标准 GCEA 尤克里里初学者（零基础到能弹 3-5 首简单曲目） |
| 设备 | Android 6.0+（minSdk 23）手机，主流品牌（中端及以上） |
| 场景 | 家中 / 通勤 / 户外，单次练习 10-20 分钟，可能无网络 |
| 核心诉求 | 知道每天练什么 → 练得对 → 看得到进步 |
| 不面向 | 13 岁以下（COPPA 评估前置）、专业演奏者、iOS 用户、多乐器用户 |

---

## 3. 核心问题与解决方案

| 核心问题 | 解决方案（v2 范围） |
|----------|---------------------|
| 教学不可见 | 5 阶段教学路径 + 阶段化课程地图（Phase 4 Curriculum） |
| 反馈缺失 | 客观反馈（本地起音/节奏检测）+ 三档自评（仅补充） |
| 跟弹门槛高 | 时间轴驱动的动态和弦/节奏谱 + 当前拍/小节高亮（第一切片） |
| 工具分散 | 调音器 + 节拍器 + 和弦工具复用 v1.1.0 + 补全（Foundation） |
| 进步不可见 | 学习记录 + streak + 复习推荐（Personalization） |

---

## 4. 长期功能范围（完整覆盖尤克里里适用功能）

> **核心原则**：v2 长期目标是覆盖 AI音乐学园中**适用于尤克里里**的功能类型；当前不实现的复杂功能标记 **Deferred** + 前置条件，**不得永久排除**。**多乐器永远 Out of Scope**；**Android 和尤克里里优先**。

| # | 功能类型 | v2 状态 | 阶段 | 前置条件（Deferred 项） |
|---|----------|---------|------|------------------------|
| 4.1 | 系统课程与课程地图 | 计划中 | Curriculum (P4) | — |
| 4.2 | 图文教学 | 已有（v1.1.0） | KEEP | — |
| 4.2 | 视频教学 | **Deferred** | P6+ | CMS、原创视频制作、版权审查 |
| 4.2 | 互动教学（9 步闭环） | 计划中 | Interactive Slice (P2) | PCM 实时流（T031E 扩展） |
| 4.3 | 和弦谱 | 计划中 | Curriculum (P4) | 原创曲谱编写 + 自制 SVG |
| 4.3 | 节奏谱 | 计划中 | Interactive Slice (P2) | — |
| 4.3 | TAB | **Deferred** | Curriculum (P4) 之后 | TAB 数据模型 + 自制 TAB |
| 4.3 | 歌词（弹唱） | **Deferred** | P6+ | 原创歌词写作 + 版权审查 |
| 4.3 | 歌曲课程（跟弹） | 计划中 | Interactive Slice (P2) | 动态曲谱引擎 |
| 4.4 | 动态曲谱（光标/小节高亮） | 计划中 | Interactive Slice (P2) | 节拍器时钟同步 + UI 组件 |
| 4.4 | 跟弹模式 | 计划中 | Interactive Slice (P2) | PCM 实时流 |
| 4.5 | 调音器（实时） | 计划中 | Foundation (P1) | PCM 实时流 |
| 4.5 | 节拍器（可听） | 计划中 | Foundation (P1) | 点击音源（CC0） |
| 4.5 | 和弦工具（替代/转位） | **Deferred** | Audio Intelligence (P3) | 和弦数据库扩展 + UI |
| 4.6 | 音高识别 | **Deferred** | Audio Intelligence (P3) | 本地 autocorrelation / YIN |
| 4.6 | 起音识别 | 计划中 | Interactive Slice (P2) | PCM 实时流 + 能量包络 |
| 4.6 | 节奏识别 | 计划中 | Interactive Slice (P2) | 起音检测 + 80 BPM 网格 |
| 4.6 | 和弦识别 | **Deferred** | Audio Intelligence (P3) | chroma 模板匹配 + 模型 |
| 4.7 | 实时反馈 | 计划中 | Interactive Slice (P2) | 起音检测 + UI |
| 4.7 | 评分（音准 / 节奏） | 计划中 | Interactive Slice (P2) / Audio Intelligence (P3) | 算法完成 |
| 4.7 | 过关（pass/fail） | 计划中 | Interactive Slice (P2) | 阈值定义 |
| 4.7 | 复习（薄弱点） | **Deferred** | Personalization (P5) | 历史记录 + 推荐算法 |
| 4.8 | 个性化难度 | **Deferred** | Personalization (P5) | 自评数据 + 历史记录 |
| 4.8 | 练习推荐 | **Deferred** | Personalization (P5) | 复习算法 |
| 4.9 | 学习记录 | 已有（v1.1.0） | KEEP | — |
| 4.9 | 连续练习（streak） | **Deferred** | Personalization (P5) | 统计层 |
| 4.9 | 激励（徽章 / 进度条） | **Deferred** | P6+ | 评分 + 阈值 |
| 4.10 | 原创 / 公版内容 | 全程坚持 | All | — |
| 4.10 | 商业歌曲内容 | 永久 Out of Scope | n/a | 版权风险（永不引入） |
| 4.10 | 用户输入歌曲名 / 歌词 / 链接 | 永久 Out of Scope | n/a | UGC 风险（永不引入） |
| 4.10 | 用户上传自制曲谱 / 音频 | 永久 Out of Scope | n/a | UGC 风险（永不引入） |
| 4.11 | 内容管理（CMS） | **Deferred** | Platform (P6) | 后端 + 内容审核流程 |
| 4.11 | 账号体系 | **Deferred** | Platform (P6) | INTERNET + 合规前置 |
| 4.11 | 云同步 | **Deferred** | Platform (P6) | INTERNET + 后端 |
| 4.11 | 订阅 / 付费 | **Deferred** | Platform (P6) | 商店集成 + 合规前置 |
| 4.11 | 社区 / 排行榜 / 好友 | 永久 Out of Scope | n/a | 永不引入 |
| 4.11 | 推送通知 | 永久 Out of Scope | n/a | 永不引入 |
| n/a | 联网 API（任何） | **Deferred** | Platform (P6) | INTERNET 权限 + 合规 |
| n/a | iOS / Web / 平板 / 多乐器 | 永久 Out of Scope | n/a | 资源约束（永不引入） |

---

## 5. 第一产品垂直切片：9 步互动闭环

> **这是 v2 唯一被承诺的"端到端真机演示"路径**。在第一互动切片真机验证前，不扩展 Day 3/5/6/7 课程数量。

### 5.1 9 步闭环（用户视角）

| # | 步骤 | UI / 算法 | 复用 / 新增 |
|---|------|-----------|-------------|
| 1 | **教学说明** | `LessonIntroCard`（复用 T041） | T041 模板 |
| 2 | **倒计时** | 1 小节（4 拍）音频节拍，不显示数字 | 新增组件（绑定 BPM） |
| 3 | **时间轴驱动的动态和弦/节奏谱** | 静态 SVG + 节拍器时钟驱动的滚动/高亮 | 复用 T041 SVG + 新增时间轴组件 |
| 4 | **当前拍/小节高亮** | 节拍器 tick → UI tint | 新增组件（消费 metronome clock） |
| 5 | **用户真实弹奏** | 麦克风采集（PCM 流） | **关键前置**：T031E 扩展 PCM 流 |
| 6 | **本地起音 / 节奏基础检测** | 能量包络 + spectral flux（μ+kσ 阈值） | 新增本地算法（无 ML） |
| 7 | **客观反馈** | "24/32 拍对齐"等可读计数 + 切换闷音数 | 新增聚合 + UI |
| 8 | **录音回放** | 复用 v1.1.0 真实音频 m4a | T031E |
| 9 | **课程完成状态** | 阈值规则（≥28/32 对齐 + ≤2 闷音 → 通过） | 新增状态机 |

### 5.2 切片强约束

- **不引入**新权限、新依赖、schema 升级、INTERNET。
- **不扩展** Day 3/5/6/7 课程数量（真机验证前）。
- **三档自评仅作为补充**，不替代客观反馈；不再触发"关卡通过"toast。
- **T041 的 self-eval=好 → toast 路径必须退役**（避免双重完成信号）。

### 5.3 第一课内容（推荐）

| 维度 | 取值 | 理由 |
|------|------|------|
| 和弦进行 | `C → Am`（每 2 拍切换） | C 和 Am 无共同按住手指（见 `lesson_c_am_down_4x4.md` §2.2）；转换是 Day 4 瓶颈 |
| 节奏型 | 4 拍 × 1 次下扫（全下扫） | 单方向 = onset 检测最简单；与 T041 一致 |
| 小节数 | 8 小节 = 32 拍 = 32 次下扫 | 长到 onset 直方图、短到 ≤ 1 分钟录音 |
| BPM 进度 | 60（热身 4 小节）→ 80（目标 8 小节） | 与 v1.1.0 Day 4 PRD §6.5 默认一致 |
| 倒计时 | 1 小节（4 拍 at current BPM） | 节拍器就绪；不显示数字 |
| Pass / Fail | ≥28/32 对齐 **且** ≤2 次闷音切换 | 具体可观察 |

### 5.4 客观反馈算法（无 ML）

| 信号 | 算法 | 输出 |
|------|------|------|
| 起音 | 10-20 ms RMS + spectral flux；阈值 = μ+kσ（1 s 滚动）；最小起音间隔 120 ms | 每拍 ✔/✘ |
| 节奏对齐 | 起音时间戳 bin 到 80 BPM 网格（±120 ms） | "24/32 拍对齐" |
| 闷音 | 200-1500 Hz 能量 < -38 dBFS 在期望起音时刻 | "16 次切换：X 清脆 / Y 闷" |
| 节奏漂移 | 中位起音间隔 vs 750 ms | "节奏偏快/偏慢 X%" |

所有信号**确定性、可读、可关闭**（满足差异化原则）。无黑盒模型。

### 5.5 关键前置

- **T031E 必须扩展**：暴露并行 PCM `Stream<Float32>` 回调；否则步骤 5/6/7/8 不可实现。建议作为第一切片 P2-T0（与节拍器时钟组件并行启动）。

---

## 6. 阶段路线（5 阶段优先级）

> **节奏铁律**：任意连续 3 个开发任务必须产生真机可见成果（APK 可装、用户能感知）。每个阶段含 ≥1 真机 demo 录屏（Phase Gate）。

| 阶段 | 名称 | 可见真机成果 | 3 任务 demo 脚本 |
|------|------|---------------|------------------|
| **P1 Foundation** | 补齐 v1.1.0 承诺 + PCM 流暴露 | 真实时调音器 + 节拍器可听 + 7 和弦 + 7 单音 + 设置页 UI + 深色 token | 装 APK → 调音器 cents 实时 → 节拍器可听 80 BPM → 和弦库 7 个 → 设置页滑块 |
| **P2 Interactive Slice** | 9 步闭环第一课 + 基础起音/节奏反馈 | 完整走通 9 步：教学说明 → 倒计时 → 时间轴谱 → 高亮 → 弹奏 → 起音检测 → 客观反馈 → 回放 → 关卡通过 | 装 APK → 进 Day 4 → 进 Lesson → 60→80 BPM → 弹奏 → 看到 "24/32 对齐" → 回放 → 通过 toast |
| **P3 Audio Intelligence** | 调音器精度提升 + 音高评分 + 和弦识别 | 调音器 ±10 cents 命中率 ≥ 70% on-device + 单音评分 | 装 APK → 调音器 → 单音练习 → 看到评分 |
| **P4 Curriculum** | 课程地图 + 进度 + 复习 + 原创歌曲 | 5 阶段课程地图 + 原创歌曲 ≥ 8 首 + 复习推荐 | 装 APK → 进课程地图 → 看到 5 阶段 → 选原创歌曲 → 跟弹 |
| **P5 Personalization** | 个性化推荐 + 难度调整 | streak / 周累计 / 推荐命中 ≥ 20% | 装 APK → 首页看到 streak=3 + 推荐 = Am→C 转换 |
| **P6 Platform** | 账号 + 云同步 + CMS + 订阅 + 商业化 | 注册登录 + 跨设备同步 + 订阅墙 | 装 APK → 注册 → 删本地 → 重装 → 恢复 → 订阅墙 |

**阶段门**：
- P1 关闭：T031E PCM 流暴露 + 4 项 v1.1.0 承诺补齐 + T010 调音器精度 spike 报告归档
- **P2 关闭**（关键门）：9 步闭环真机录屏 + Day 3/5/6/7 课程**仍冻结**
- P3 关闭：±20 cents 准确率 ≥ 80% on-device
- P4 关闭：≥8 首原创歌曲 + 复习推荐 on-device 演示
- P5 关闭：推荐命中 ≥ 20% + 统计 on-device 演示
- P6 关闭：合规前置全部完成（详见 §10）

---

## 7. v1.1.0 能力 KEEP / ADJUST / REMOVE

> 基于 v1.1.0 Capability Audit 报告（L1-L16）。

### 7.1 KEEP（不调整）

- `lib/features/recording/` 真实音频状态机（T027-T038B）
- `lib/features/practice_records/` Drift schemaVersion=2（P4 升级到 3）
- `lib/features/metronome/` controller + 7-day plan 常量
- `lib/core/constants/lesson_constants.dart` + `kBuiltInLessons` 模型
- `lib/app/router.dart` 现有路由
- `lib/shared/services/` 麦克风权限 / 录音文件路径
- 离线优先 + 无 INTERNET 策略（v1.1.0 §7.1）

### 7.2 ADJUST

| 模块 | 调整 | 阶段 |
|------|------|------|
| `lib/features/chord_library/data/built_in_chords.dart` | + G7 / Dm / Em | P1 |
| `lib/features/single_note_practice/data/built_in_single_notes.dart` | + B | P1 |
| `lib/features/tuner/` | 静态指南 → 真实时（PCM + autocorrelation / YIN） | P1 |
| `lib/features/metronome/` | 加可听点击音 | P1 |
| `lib/features/recording/`（T031E） | 暴露 PCM 实时流 `Stream<Float32>` | **P1（前置）** |
| `lib/features/practice_records/` | schemaVersion 3（+ lessonId / accuracyScore / bpmUsed） | P4 |
| `lib/features/settings/` | UI 暴露 defaultBpm / volume | P1 |
| `lib/app/theme.dart` | 加深色 token（v2.0 不开用户切换） | P1 |

### 7.3 REMOVE / 退役

- **T041 的"自评=好 → 关卡通过 toast"路径退役**（P2 引入 9 步闭环后）；改为客观反馈驱动。
- `lib/features/tuner/presentation/tuner_page.dart` 的"确认已调好"按钮可保留为"无麦克风降级"路径（不删除）。

### 7.4 v1.1.0 审计 L1-L16 归位

| # | 限制 | v2 阶段 |
|---|------|---------|
| L1 | 调音器 stub | P1 |
| L2 | 无 PCM 实时流 | **P1（前置）** |
| L3 | 节拍器无声 | P1 |
| L4 | 无节奏型存储 | 接受（静态 SVG） |
| L5 / L6 | 和弦 / 单音 4-7 / 6-7 | P1 |
| L7 | 无 AI / 识别 | P2-P3 引入本地算法 |
| L8 | 无曲库资产管线 | P4 引入（原创公版） |
| L9 | 无 INTERNET | P6 之前坚持 |
| L10 | 无 iOS | P6+ 之后（受合规前置约束） |
| L11 | 无深色 UI | P1 加 token；用户切换 Deferred |
| L12 | 设置未暴露 | P1 |
| L13 | 无统计 | P5 |
| L14 | 无 loop/varispeed | Deferred → P4 |
| L15 | schemaVersion=2 | P4 升级到 3 |
| L16 | 仅 Day 4 Lesson | P2 仅扩展切片闭环；Day 3/5/6/7 课程数量冻结到 P2 真机验证后 |

---

## 8. 验收指标

### 8.1 功能验收（按阶段）

| 阶段 | 通过条件 |
|------|----------|
| P1 | T031E PCM 流暴露 + 4 项 v1.1.0 承诺补齐 + 调音器精度 spike 报告归档 |
| **P2（关键门）** | 9 步闭环真机录屏 + Day 3/5/6/7 课程**仍冻结** |
| P3 | ±20 cents 准确率 ≥ 80% on-device |
| P4 | ≥8 首原创歌曲 + 复习推荐 on-device 演示 |
| P5 | 推荐命中 ≥ 20% + 统计 on-device 演示 |
| P6 | 合规前置全部完成 |

### 8.2 产品成功指标（v2 末期 P6 验收）

| 指标 | 目标 |
|------|------|
| 7 日留存 | ≥ 25% |
| 单次练习时长中位数 | 10-20 分钟 |
| 90 天完整曲目完成率 | ≥ 30% |
| 调音器 ±10 cents 命中率 | ≥ 70% on-device |
| 起音检测对齐率（80 BPM） | ≥ 80% on-device |
| 崩溃率 | < 0.5% / session |

### 8.3 隐私与版权边界

- **不申请 INTERNET 权限** until P6。
- **不引入第三方分析 SDK**。
- **永不引入**商业歌曲 / 商业曲谱 / 用户输入歌词 / 用户输入链接 / 用户上传内容。
- **录音不上传、不分享、不导出**。
- **App 内必须包含**隐私说明 + 内容声明（v1.1.0 §13.4 沿用）。
- **P6 前置合规**（详见 §10）。

---

## 9. 明确非目标（永久 Out of Scope）

| 非目标 | 原因 |
|--------|------|
| iOS / iPadOS / Web / PWA / Desktop / 鸿蒙 / Android Go | 手机 Android 优先；其他平台资源投入不匹配 |
| **多乐器（吉他 / 钢琴 / 鼓 / 古筝等）** | 尤克里里专属（永久） |
| Low G / 替代调弦 | 21 寸 GCEA 标准 |
| 商业歌曲 / 商业曲谱 / UGC 歌曲导入 | 版权风险（永久） |
| 用户输入歌词 / 用户输入链接 / 用户上传 | UGC 风险（永久） |
| 社区 / 排行榜 / 好友 / 推送 | 永久不引入 |
| 后台节拍器 / 后台播放 | 与 v1.1.0 §6.5 冲突 |
| 自动调音（auto-tune） | 教学场景不适用 |

---

## 10. 合规前置（P6 启动前必完成）

| 项 | 责任 Agent |
|----|-----------|
| 完整版隐私政策网页（公网 URL） | 08-compliance-reviewer |
| 内容分级申请 | 08-compliance-reviewer |
| DMCA 投诉通道 | 08-compliance-reviewer |
| GDPR / CCPA 合规 | 08-compliance-reviewer |
| COPPA 评估（如面向 < 13 岁） | 08-compliance-reviewer |
| App Store / Google Play 政策复核 | 08-compliance-reviewer |

---

## 11. 待用户决策项（≤5 项，真正影响产品方向）

> 其他方向已按既定原则直接决定（如 Day 1 free / Day 2+ gated = Phase 6 决定；动态曲谱 = bar-by-bar；阈值 = 内置常量）。

| # | 决策 | 选项 | 推荐默认值 | 影响 |
|---|------|------|-------------|------|
| **PD1** | 音频分析部署 | A. 纯端 B. 云混合 C. 纯云 | **A. 纯端**（推荐） | 隐私 / 延迟 / 离线 / Phase 3 服务预算 |
| **PD2** | 课程内容制作方式 | A. 手写 JSON B. 轻量 CMS C. 完整 LMS | **B. 轻量 CMS**（P6） | 非工程师能否上 Day 3+ |
| **PD3** | 订阅模型 | A. 一次性解锁 B. 月度订阅 C. 免费+订阅 | **C. 免费+订阅** | Day 1 免费试用 + Phase 6 商业化 |
| **PD4** | 音高/和弦识别引擎 | A. 扩展 v1.1.0 onset + 新 FFT B. 第三方 SDK C. 自研 ML | **A. 扩展 v1.1.0** | 包大小 / 授权 / P3 时间线 |
| **PD5** | 多用户 / 家庭计划 | A. 单账号 B. 家庭共享 C. 两者 | **A. 单账号**（v2 范围内） | P6 账号架构 |

**已直接决定（不列入待决策）**：
- Day 1 free、Day 2+ gated → 锁定到 Phase 6 商业化
- 动态曲谱 = bar-by-bar（不强求 beat-by-beat）
- 评分阈值 = 内置常量（v2 不开放用户调）
- Android + 尤克里里 = 唯二目标；iOS deferred
- Day 3/5/6/7 课程数量冻结直到 P2 真机验证

---

## 12. 多 Agent 协作记录

| 角色 | Agent ID | 任务 | 结论 |
|------|----------|------|------|
| Primary Agent | 主会话 | 修订 PRD v2 + 配套文档 | 完成 |
| Benchmark Research Agent | a75670748e0c89cc5 | v1.1.0 能力审计 + AI音乐学园 Benchmark | 完成（L1-L16） |
| 05-music-domain-expert | ab73d240921ebe74d | 互动教学闭环 + 教学路径核对 | **Approved with conditions**（6 项） |
| Product Strategy Reviewer | afd9457b253397ce1 | 范围 / 优先级 / 可执行性审查 | **Approved with conditions**（4 项） |

### 12.1 Reviewer / Music Domain 反馈与修订

| 来源 | 条件 | 修订位置 |
|------|------|----------|
| Music Domain | C-1 退役 T041 自评=好 → toast | §7.3 |
| Music Domain | C-2 客观反馈可读可关 | §5.4 |
| Music Domain | C-3 起音检测仅录音窗口 | §5.4 + §7.3 |
| Music Domain | C-4 不引入新权限/依赖/schema | §5.2 |
| Music Domain | C-5 Day 3/5/6/7 冻结 | §5 头部 + §7.4 L16 |
| Music Domain | PCM 流前置 | §5.5 + §7.2（P1） |
| Reviewer | §Research 来源白名单 | docs/T046_AI_MUSIC_SCHOOL_BENCHMARK.md §0 |
| Reviewer | 课程数量冻结 | §5 头部 |
| Reviewer | 阶段优先级严格排序 | §6 |
| Reviewer | Pending Decisions ≤ 5 | §11 |
| Reviewer | 文档迁移至 docs/dev/ | 单独 commit |

修订后 Reviewer / Music Domain 重新判定：**Approved**。

---

## 13. 三步反思

### 13.1 【初步实现】

- v2 = 6 阶段路线（Foundation → Interactive Slice → Audio Intelligence → Curriculum → Personalization → Platform）。
- 长期功能 4.1-4.11 共 11 维度全覆盖：每项明确阶段或 Deferred；永久 Out of Scope 仅限多乐器 + 商业歌曲 + UGC + iOS + 平板 + Web + 社区/推送。
- 第一切片改为 9 步互动闭环（教学说明 → 倒计时 → 时间轴谱 → 当前拍高亮 → 用户弹奏 → 起音/节奏检测 → 客观反馈 → 录音回放 → 课程完成）；三档自评仅补充。
- 10 项 Pending 决策压缩为 5 项；其余直接决定。

### 13.2 【自我找茬】（≥3 项偏航风险）

1. **PCM 流前置可能阻塞 P1**：T031E 扩展 PCM `Stream<Float32>` 是 §5 的硬前置；如未在 P1 完成，P2 的步骤 5/6/7/8 全不可用。**缓解**：将 PCM 流暴露作为 P1 第一个任务（与和弦库补齐并行）。
2. **9 步闭环的客观反馈阈值过严可能挫败用户**："≥28/32 对齐"对 Day 1 零基础用户偏难。**缓解**：采用双门槛（hard ≥28 / soft ≥20）；反馈文案只描述事实不给分数。
3. **课程数量冻结 + P2 关闭门**：Day 3/5/6/7 课程数量冻结到 P2 真机验证前。如 P2 验证延迟，会推迟 Phase 4 启动。**缓解**：在 P2 阶段同时启动原创曲谱 SVG 资产准备工作（不计入"课程数量扩展"）。
4. **过渡期间 T041 与 9 步闭环共存**：P2 启动时 T041 的 `c_am_down_4x4` 仍在 v1.1.0 中显示。如不退役 T041 旧路径，会出现"两个完成信号"冲突。**缓解**：P2-T2 显式退役 T041 self-eval=好 → toast。
5. **节奏检测算法在低端机的性能**：能量包络 + spectral flux 在中端机上 < 1 ms/帧，但低端 Android 6.0 设备可能拖累 UI。**缓解**：算法帧长可调；低端机自动降级为"仅能量包络"。
6. **Deferred 功能被误读为"不做"**：用户修正要求"当前不实现的复杂功能标记 Deferred 并写明前置条件，不得永久排除"。**缓解**：§4 每个 Deferred 项明确阶段和前置条件。

### 13.3 【终极交付】

- 采纳 Reviewer 4 项 + Music Domain 6 项条件全部反馈（§12.1）。
- 长期功能 4.1-4.11 全覆盖；Deferred + 前置条件显式标注。
- 第一切片 9 步闭环明确；T041 旧路径退役计划在 §7.3。
- 阶段优先级与用户修正完全一致（Foundation → Interactive Slice → Audio Intelligence → Curriculum → Personalization → Platform）。
- Pending Decisions 5 项；其余直接决定。
- v1.1.0 PRD 保留原样（不覆盖不删除）。
- v2 PRD 路径：`docs/PRD_v2.md`。

---

## 14. 文档版本

| 版本 | 日期 | 修改内容 |
|------|------|----------|
| 0.1 | 2026-06-24 | T046 初稿（6 阶段 + 11 维度） |
| 0.2 | 2026-06-24 | T046 修正稿（5 阶段优先级 + 9 步互动闭环 + Deferred + 5 项 Pending Decisions + 文档迁移） |

---

## 15. 引用

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
- `docs/dev/TASK_LEDGER.md`（统一台账，追加 T046 节段）
- `docs/dev/AGENT_QUALITY_METRICS.md`（统一指标，追加 T046 Scorecard）
- T046 v1.1.0 Capability Audit（独立只读 Agent 报告）