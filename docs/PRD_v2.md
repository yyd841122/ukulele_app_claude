# PRD v2 — ukulele_app

> Task ID：`T046_PRODUCT_V2_PRD_FINAL_CORRECTION`（基于 `T046_PRODUCT_V2_PRD_CORRECTION` v0.2 修订）
> 日期：2026-06-24 | 版本：0.3
> 协作 Agent：Primary Agent / Product Strategy Reviewer (`a3941933d7f44ae19`) / Audio Architecture Reviewer (`aeee42779a5458716`) / 05-music-domain-expert (`ab73d240921ebe74d`)
>
> **v0.3 修订**：消除产品范围与音频能力假设矛盾。
> - 产品定位：Android-FIRST（初期）/ **Common High-G GCEA 尤克里里（默认 21 寸 Soprano，不限定）** / Low-G 与 iOS 标记 Deferred + 前置条件。
> - 商业/授权歌曲、iOS、平板用户端 = Deferred + 前置条件；多乐器 + 用户端 Web = 永久 Out；管理端 Web（CMS）**保留 Deferred 不删**。
> - PRD 只描述产品能力，**不锁定算法**。所有算法名称（energy envelope / spectral flux / FFT / autocorrelation / YIN / chroma / RMS / dBFS / 特定 Hz 频带 / 固定阈值 / μ+kσ 等）删除；算法选择留给 SDD/TDD。
> - P2 第一切片客观过关依据**只**使用节奏/起音对齐；"闷音"降级为非阻断观察或自评项；音色/音高/和弦正确性留到 Audio Intelligence 阶段。
> - "28/32 对齐"作为**初始真机校准基线**，**不**写为永久产品常量。
> - 删除"T031E 已暴露 PCM 流"的错误表述，改为 SDD 必须解决的**开放问题**。

---

## 1. 产品愿景（北极星）

让一名零基础 **Android 用户**在 90 天内**完成至少 1 首完整的尤克里里弹唱**，并保持每日 ≤ 20 分钟的有效练习；以**节奏/起音对齐 + 时间轴动态曲谱**为核心差异化能力；坚持离线优先（P1-P5）、原创/公版内容、**common High-G GCEA 尤克里里**（默认 21 寸 Soprano，但**不限定 21 寸**）专属教学。

**平台优先级**：**Android-first**。iOS 标记 **Deferred + 前置条件**（详见 §4 与 §9），**不永久排除**。

---

## 2. 目标用户

| 维度 | 描述 |
|------|------|
| 身份 | **common High-G GCEA** 尤克里里初学者（默认 21 寸 Soprano；不限定 21 寸） |
| 设备 | Android 6.0+（minSdk 23）手机，主流品牌（中端及以上） |
| 场景 | 家中 / 通勤 / 户外，单次练习 10-20 分钟，可能无网络 |
| 核心诉求 | 知道每天练什么 → 练得对 → 看得到进步 |
| 不面向 | 13 岁以下（COPPA 评估前置）、专业演奏者、iOS 用户（MVP 不投入；详见 §4 Deferred）、多乐器用户 |

---

## 3. 核心问题与解决方案

| 核心问题 | 解决方案（v2 范围） |
|----------|---------------------|
| 教学不可见 | 5 阶段教学路径 + 阶段化课程地图（Curriculum 阶段） |
| 反馈缺失 | **节奏/起音对齐客观反馈** + 三档自评（仅补充） |
| 跟弹门槛高 | 时间轴驱动的动态和弦/节奏谱 + 当前拍/小节高亮（第一切片） |
| 工具分散 | 调音器 + 节拍器 + 和弦工具（Foundation） |
| 进步不可见 | 学习记录 + streak + 复习推荐（Personalization） |

---

## 4. 长期功能范围（Deferred + 前置条件）

> **核心原则**：v2 长期目标覆盖 AI音乐学园中**适用于尤克里里**的功能类型。当前不实现的功能标记 **Deferred** + 前置条件，**不永久排除**。**多乐器 + 用户端 Web + 商业/授权歌曲 + UGC 入口 = 永久 Out of Scope**。**Android 和尤克里里优先**。

| # | 功能类型 | v2 状态 | 阶段 | 前置条件（Deferred 项） |
|---|----------|---------|------|------------------------|
| 4.1 | 系统课程与课程地图 | 计划中 | Curriculum | — |
| 4.2 | 图文教学 | KEEP（v1.1.0） | All | — |
| 4.2 | 视频教学 | **Deferred** | P6+ | CMS、原创视频制作、版权审查 |
| 4.2 | 互动教学（9 步闭环） | 计划中 | Interactive Slice | 音频分析输入来源（见 §11 SDD 开放问题） |
| 4.3 | 和弦谱 | **Deferred** | Curriculum | 原创曲谱编写 + 自制 SVG |
| 4.3 | 节奏谱 | 计划中 | Interactive Slice | — |
| 4.3 | TAB | **Deferred** | Curriculum | TAB 数据模型 + 自制 TAB |
| 4.3 | 五线谱 / 简谱 | 永久 Out | n/a | 不引入 |
| 4.3 | 歌词（弹唱） | **Deferred** | P6+ | 原创歌词写作 + 版权审查 |
| 4.3 | 歌曲课程（跟弹） | 计划中 | Interactive Slice | 动态曲谱引擎 |
| 4.4 | 动态曲谱（光标/小节高亮） | 计划中 | Interactive Slice（静态高亮）→ Curriculum（动态光标） | 节拍器时钟同步 |
| 4.4 | 跟弹模式 | 计划中 | Interactive Slice | 音频分析输入来源（SDD 决议） |
| 4.5 | 调音器（实时反馈） | 计划中 | Foundation | 音频分析输入来源（SDD 决议） |
| 4.5 | 节拍器（可听） | 计划中 | Foundation | 点击音源（CC0） |
| 4.5 | 和弦工具（替代/转位） | **Deferred** | Audio Intelligence | 和弦数据库扩展 + UI |
| 4.6 | 音高识别 | **Deferred** | Audio Intelligence | 算法由 SDD 决定 |
| 4.6 | 起音识别（节奏/起音对齐） | 计划中 | Interactive Slice | 算法由 SDD 决定 |
| 4.6 | 和弦识别 | **Deferred** | Audio Intelligence | 算法由 SDD 决定 |
| 4.7 | 实时反馈（节拍/起音对齐） | 计划中 | Interactive Slice | 起音识别 |
| 4.7 | 评分（节奏对齐） | 计划中 | Interactive Slice | 算法由 SDD 决定 |
| 4.7 | 评分（音准 / 和弦） | **Deferred** | Audio Intelligence | 算法由 SDD 决定 |
| 4.7 | 过关（pass/fail，**仅节奏/起音对齐**） | 计划中 | Interactive Slice | 初始阈值见 §5.6 |
| 4.7 | 复习（薄弱点） | **Deferred** | Personalization | 历史记录 + 推荐算法 |
| 4.8 | 个性化难度 | **Deferred** | Personalization | 自评数据 + 历史记录 |
| 4.8 | 练习推荐 | **Deferred** | Personalization | 复习算法 |
| 4.9 | 学习记录 | KEEP（v1.1.0） | All | — |
| 4.9 | 连续练习（streak） | **Deferred** | Personalization | 统计层 |
| 4.9 | 激励（徽章 / 进度条） | **Deferred** | P6+ | 评分 + 阈值 |
| 4.10 | 原创 / 公版内容 | 全程坚持 | All | — |
| 4.10 | 商业 / 授权歌曲 | **Deferred**（用户修正：标记 Deferred 不永久 Out） | P6+ | 完整版权授权链 + 合规审查 + DMCA + 资金；不可绕过 |
| 4.10 | 用户输入歌曲名 / 歌词 / 链接 | **Deferred**（同 4.10 商业歌曲一致；不永久排除） | P6+ | 完整版权过滤 + 内容审核 + DMCA；不可绕过 |
| 4.10 | 用户上传自制曲谱 / 音频 | **Deferred**（同 4.10 商业歌曲一致） | P6+ | 完整版权过滤 + 内容审核 + DMCA；不可绕过 |
| 4.11 | 内容管理（CMS，含**管理端 Web**） | **Deferred** | Platform | 后端 + 内容审核流程 + INTERNET 权限 + 合规前置 |
| 4.11 | 账号体系 | **Deferred** | Platform | INTERNET + 合规前置 |
| 4.11 | 云同步 | **Deferred** | Platform | INTERNET + 后端 |
| 4.11 | 订阅 / 付费 | **Deferred** | Platform | 商店集成 + 合规前置 |
| 4.11 | 社区 / 排行榜 / 好友 | 永久 Out | n/a | 永不引入 |
| 4.11 | 推送通知 | 永久 Out | n/a | 永不引入 |
| 4.11 | 用户端 Web / PWA / Desktop | 永久 Out（用户端） | n/a | 资源约束；管理端 Web（CMS）保留 Deferred 不删 |
| 4.12 | **iOS 适配** | **Deferred**（用户修正：非永久 Out） | P6+ | 跨平台工程选型 + UX 重做 + 合规前置 + 测试设备 |
| 4.13 | **平板 UI 优化** | **Deferred**（用户修正：非永久 Out） | P6+ | 设计 token 扩展 + 布局组件 + 跨设备测试 |
| 4.14 | **Low-G 调弦支持** | **Deferred**（用户修正：非永久 Out） | Audio Intelligence 或之后 | Low-G 音高映射表 + 调音器算法适配 + 内容制作 |
| n/a | 任何联网 API | **Deferred** | Platform | INTERNET 权限 + 合规 |
| n/a | **多乐器（吉他 / 钢琴 / 鼓 / 古筝等）** | 永久 Out | n/a | 尤克里里专属（永久） |
| n/a | 第三方分析 SDK | 永久 Out | n/a | 永不引入 |

---

## 5. 第一产品垂直切片：9 步互动闭环

> **v2 唯一被承诺的"端到端真机演示"路径**。在第一互动切片真机验证前，**不扩展 Day 3/5/6/7 课程数量**。

### 5.1 9 步闭环（产品视角，**不锁定算法**）

| # | 步骤 | 产品能力描述（算法由 SDD 决定） |
|---|------|----------------------------------|
| 1 | 教学说明 | `LessonIntroCard` 静态展示（复用 T041） |
| 2 | 倒计时 | 1 小节音频节拍（绑定当前 BPM） |
| 3 | 时间轴驱动的动态和弦/节奏谱 | 静态 SVG + 节拍器时钟驱动的滚动/高亮 |
| 4 | 当前拍/小节高亮 | 节拍器 tick → UI tint |
| 5 | 用户真实弹奏 | 麦克风采集 + m4a 录音 |
| 6 | **本地起音 / 节奏基础检测** | 输入：实时/近实时音频；输出：每拍 ✔/✘ + 对齐计数。算法由 SDD 决定。 |
| 7 | **客观反馈（仅节奏/起音对齐）** | "24/32 拍对齐"等可读计数。**不**包含音色 / 音高 / 和弦。 |
| 8 | 录音回放 | 复用 v1.1.0 真实音频 m4a |
| 9 | **课程完成状态** | 节奏/起音对齐达标 → 通过（见 §5.6 初始校准基线）。**不**依赖音色/音高/和弦。 |

### 5.2 切片强约束

- **不引入**新权限、新依赖、schema 升级、INTERNET。
- **不扩展** Day 3/5/6/7 课程数量（真机验证前）。
- **三档自评仅作为补充**，不替代客观反馈；不再触发"关卡通过"toast。
- **T041 的"self-eval=好 → toast"路径必须退役**（避免双重完成信号）。
- **客观过关依据仅用节奏/起音对齐**；"闷音 / 哑音切换数"为非阻断观察或自评项，**不**进入过关判定。

### 5.3 第一课内容（推荐，**与算法无关**）

| 维度 | 取值 | 理由 |
|------|------|------|
| 和弦进行 | `C → Am`（每 2 拍切换） | C 和 Am 无共同按住手指（见 `lesson_c_am_down_4x4.md` §2.2） |
| 节奏型 | 4 拍 × 1 次下扫（全下扫） | 单方向最简单 |
| 小节数 | 8 小节 = 32 拍 | 长到对齐直方图、短到 ≤ 1 分钟录音 |
| BPM 进度 | 60（热身 4 小节）→ 80（目标 8 小节） | 与 v1.1.0 Day 4 PRD §6.5 默认一致 |
| 倒计时 | 1 小节（4 拍 at current BPM） | 节拍器就绪 |
| Pass / Fail | **节奏/起音对齐 ≥ 初始校准基线（见 §5.6）** | 具体可观察；**不**包含闷音 |

### 5.4 产品能力与目标（**算法留给 SDD/TDD**）

| 信号 | 产品能力描述 | 输出（用户可见） |
|------|--------------|--------------------|
| 起音检测 | 在用户录音窗口内检测每次弹奏的起音 | 每拍 ✔/✘ |
| 节奏对齐 | 起音时间与节拍网格对齐度 | "N/32 拍对齐" |
| 哑音切换数（非阻断观察） | 用户两次切换间未被弹响的拍次 | "N 次哑音切换（仅供参考）" |
| 节奏漂移（非阻断观察） | 起音间隔中位数 vs 期望间隔的偏差 | "节奏偏快/偏慢 X%" |

**反馈延迟目标**（范围，待 SDD 验证）：≤ 150-300 ms（wall-clock，从弹奏到 UI 更新）。
**对齐准确度目标**（范围，待 SDD 验证）：在 80 BPM 简单下扫下 on-device ≥ 80%。
**误检率目标**（范围，待 SDD 验证）：≤ 2 次 / 32 拍窗口。
**可理解性**：所有反馈以"24/32 拍对齐"等自然语言呈现，每项可在设置中关闭。

### 5.5 SDD 开放问题（**替代 v0.2 的"PCM 流前置"**）

> **SDD 必须解决**：
> - v1.1.0 真实音频录音（`record ^7.1.0`，m4a / 44.1 kHz / mono，5 分钟上限，**仅写文件**）不暴露 PCM 流或实时分析回调。
> - P2 互动切片需要实时/近实时的本地音频分析输入，但 m4a 文件只能会话结束后得到。
> - SDD **必须**比较（至少）：
>   1. 扩展 `record` 插件同时支持流式分析 + 文件录制；
>   2. 新增第二条采集路径（如 `flutter_sound` 原始 PCM 环形缓冲）专供分析；
>   3. 先录 m4a，后台 isolate 解码 → 跑事后检测（仅会话结束反馈，**非实时**）；
>   4. Android `AudioRecord` JNI / FFI 直采；
>   5. 放弃实时分析，仅会话结束反馈。
> - **PRD 不预设技术答案**。SDD 选择方案后，须说明对延迟 / 准确度 / 误检率 / 功耗 / 依赖大小 / 代码复杂度的影响，并在 P1 内做 spike 验证。
> - **m4a 录音必须保留**（步骤 8 录音回放依赖）。

### 5.6 初始真机校准基线（**非永久常量**）

| 参数 | 初始基线（P2 真机校准起点） | 说明 |
|------|-----------------------------|------|
| **节奏/起音对齐阈值** | ≥ 28/32 拍对齐 | **初始基线**，仅用于 P2 端到端真机演示；on-device 数据后重新协商；**不构成永久产品常量** |
| 双门槛（缓解挫败感） | hard ≥ 28 / soft ≥ 20 | soft 档不触发关卡通过，但允许继续 Day 5（同时建议重做 Step 1） |
| 哑音切换容忍 | 仅作为非阻断观察项；**不**进入过关判定 | — |

校准完成后，所有阈值由 P2 关闭门 review 重新协商（v2.x 后续任务）。

---

## 6. 阶段路线（5 阶段优先级）

> **节奏铁律**：任意连续 3 个开发任务必须产生真机可见成果（APK 可装、用户能感知）。每个阶段含 ≥1 真机 demo 录屏（Phase Gate）。

| 阶段 | 名称 | 可见真机成果 | 3 任务 demo 脚本 |
|------|------|---------------|------------------|
| **P1 Foundation** | 补齐 v1.1.0 承诺 + SDD 开放问题决议 | 真实时调音器（SDD 算法）+ 节拍器可听 + 7 和弦 + 7 单音 + 设置页 + 深色 token + **SDD 决议落地** | 装 APK → 调音器反馈 → 节拍器可听 80 BPM → 和弦库 7 个 → 设置页滑块 |
| **P2 Interactive Slice** | 9 步闭环第一课 + 起音/节奏反馈 | 完整走通 9 步；客观反馈仅节奏/起音对齐 | 装 APK → 进 Day 4 → 进 Lesson → 60→80 BPM → 弹奏 → 看到 "N/32 对齐" → 回放 → 通过 toast |
| **P3 Audio Intelligence** | 调音器精度 + 音高 + 和弦 + 哑音 | 调音器精度提升 + 单音评分 + 和弦识别 | 装 APK → 调音器 → 单音练习 → 看到评分 |
| **P4 Curriculum** | 课程地图 + 进度 + 复习 + 原创歌曲 | 5 阶段课程地图 + 原创歌曲 ≥ 8 首 + 复习推荐 | 装 APK → 进课程地图 → 选原创歌曲 → 跟弹 |
| **P5 Personalization** | 个性化推荐 + 难度 | streak / 周累计 / 推荐命中 ≥ 20% | 装 APK → 首页看到 streak=3 + 推荐 |
| **P6 Platform** | 账号 + 云同步 + CMS（含管理端 Web）+ 订阅 + iOS + 平板 | 注册登录 + 跨设备同步 + 订阅墙 | 装 APK → 注册 → 删本地 → 重装 → 恢复 → 订阅墙 |

**阶段门**：
- P1 关闭：**SDD 开放问题决议落地** + 4 项 §7.2 P0 补齐 + T009 调音器精度 spike 报告归档
- **P2 关闭（关键门）**：9 步闭环真机录屏 + 节奏/起音对齐初始校准完成 + Day 3/5/6/7 课程**仍冻结**
- P3 关闭：音高/和弦准确率（具体值 SDD spike 定）on-device
- P4 关闭：≥8 首原创歌曲 + 复习推荐 on-device 演示
- P5 关闭：推荐命中 ≥ 20%
- P6 关闭：合规前置全部完成

---

## 7. v1.1.0 能力 KEEP / ADJUST / REMOVE

### 7.1 KEEP（不调整）

- `lib/features/recording/` 真实音频状态机（T027-T038B）
- `lib/features/practice_records/` Drift schemaVersion=2（P4 升级到 3）
- `lib/features/metronome/` controller + 7-day plan 常量
- `lib/core/constants/lesson_constants.dart` + `kBuiltInLessons` 模型
- `lib/app/router.dart` 现有路由
- `lib/shared/services/` 麦克风权限 / 录音文件路径
- 离线优先 + 无 INTERNET 策略（v1.1.0 §7.1）

### 7.2 ADJUST（**不锁定算法**）

| 模块 | 调整（产品能力） | 阶段 |
|------|------------------|------|
| `lib/features/chord_library/data/built_in_chords.dart` | + G7 / Dm / Em | P1 |
| `lib/features/single_note_practice/data/built_in_single_notes.dart` | + B | P1 |
| `lib/features/tuner/` | 静态指南 → **实时反馈调音器**（算法 SDD 决定） | P1 |
| `lib/features/metronome/` | 加可听点击音 | P1 |
| `lib/features/recording/` | **音频分析输入扩展**（具体形式由 SDD §5.5 决议） | **P1** |
| `lib/features/practice_records/` | schemaVersion 3（+ lessonId / accuracyScore / bpmUsed） | P4 |
| `lib/features/settings/` | UI 暴露 defaultBpm / volume + 反馈项开关 | P1 |
| `lib/app/theme.dart` | 加深色 token（v2.0 不开用户切换） | P1 |

### 7.3 REMOVE / 退役

- **T041 的"自评=好 → 关卡通过 toast"路径退役**（P2 引入 9 步闭环后）。
- `lib/features/tuner/presentation/tuner_page.dart` 的"确认已调好"按钮可保留为"无麦克风降级"路径（不删除）。

### 7.4 v1.1.0 审计 L1-L16 归位

| # | 限制 | v2 阶段 |
|---|------|---------|
| L1 | 调音器 stub | P1 |
| L2 | 无实时音频分析输入 | **P1（SDD 决议）** |
| L3 | 节拍器无声 | P1 |
| L4 | 无节奏型存储 | 接受（静态 SVG） |
| L5 / L6 | 和弦 / 单音 4-7 / 6-7 | P1 |
| L7 | 无 AI / 识别 | P2 起音 / P3 音高 / P3+ 和弦（全部本地） |
| L8 | 无曲库资产管线 | P4 引入（原创公版） |
| L9 | 无 INTERNET | P6 之前坚持 |
| L10 | 无 iOS | **Deferred（P6+，受 §10 合规前置约束）** |
| L11 | 无深色 UI | P1 加 token；用户切换 Deferred |
| L12 | 设置未暴露 | P1 |
| L13 | 无统计 | P5 |
| L14 | 无 loop/varispeed | **Deferred（Curriculum）** |
| L15 | schemaVersion=2 | P4 升级到 3 |
| L16 | 仅 Day 4 Lesson | P2 仅扩展切片闭环；Day 3/5/6/7 课程数量冻结到 P2 真机验证前 |

---

## 8. 验收指标

### 8.1 功能验收（按阶段）

| 阶段 | 通过条件 |
|------|----------|
| P1 | **SDD §5.5 开放问题决议落地** + 4 项 §7.2 P0 补齐 + T009 调音器精度 spike 报告归档 |
| **P2（关键门）** | 9 步闭环真机录屏 + 节奏/起音对齐**初始校准完成** + Day 3/5/6/7 课程**仍冻结** |
| P3 | 音高 / 和弦准确率（具体值 SDD spike 定）on-device |
| P4 | ≥8 首原创歌曲 + 复习推荐 on-device 演示 |
| P5 | 推荐命中 ≥ 20% |
| P6 | 合规前置全部完成 |

### 8.2 产品成功指标（v2 末期 P6 验收）

| 指标 | 目标 |
|------|------|
| 7 日留存 | ≥ 25% |
| 单次练习时长中位数 | 10-20 分钟 |
| 90 天完整曲目完成率 | ≥ 30% |
| 调音器精度 | ±10 cents 命中率 ≥ 70% on-device |
| 起音/节奏对齐准确度 | ≥ 80% on-device（具体 BPM/节奏型随课程变） |
| 反馈延迟 | ≤ 150-300 ms wall-clock |
| 误检率 | ≤ 2 次 / 32 拍窗口 |
| 崩溃率 | < 0.5% / session |

### 8.3 隐私与版权边界

- **不申请 INTERNET 权限** until P6。
- **不引入第三方分析 SDK**。
- **Deferred（不永久排除）**：商业 / 授权歌曲、用户输入歌词 / 链接、用户上传内容；需完整版权过滤 + 内容审核 + DMCA。
- **永久 Out**：多乐器 / 用户端 Web / PWA / Desktop / 社区 / 排行榜 / 好友 / 推送。
- **录音不上传、不分享、不导出**。
- **App 内必须包含**隐私说明 + 内容声明（v1.1.0 §13.4 沿用）。
- **P6 前置合规**（详见 §10）。

---

## 9. 永久 Out of Scope（非目标）

| 非目标 | 原因 |
|--------|------|
| **多乐器（吉他 / 钢琴 / 鼓 / 古筝等）** | 尤克里里专属（永久；用户修正确认可永久 Out） |
| 用户端 Web / PWA / Desktop | 资源约束（用户端永久 Out；**管理端 Web = CMS** 仍 Deferred 不删） |
| 社区 / 排行榜 / 好友 | 永不引入 |
| 推送通知 | 永不引入 |
| 五线谱 / 简谱 | 不引入 |
| 后台节拍器 / 后台播放 | 与 v1.1.0 §6.5 冲突 |
| 自动调音（auto-tune） | 教学场景不适用 |
| 第三方分析 SDK | 永不引入 |

**Deferred（不永久 Out，用户修正明确）**：iOS、平板、Low-G、商业/授权歌曲、用户输入歌词/链接、用户上传、TAB、歌词、CMS、账号、云同步、订阅、视频教学、激励、复习、个性化难度/推荐、统计、loop/varispeed、深色用户切换。详见 §4 各 Deferred 行的前置条件。

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

## 11. SDD 开放问题（**P1 必须决议**）

| # | 开放问题 | PRD 目标（范围，待 SDD 验证） |
|---|----------|-------------------------------|
| **OP-1** | **音频分析输入来源**（v0.2 "PCM 流前置" 的替代） | 保留 m4a 文件录制（步骤 8）；本地起音 / 节奏对齐分析；反馈延迟 ≤ 150-300 ms；准确度 ≥ 80% on-device（80 BPM 简单下扫）；误检 ≤ 2 / 32 拍；可关闭。SDD 比较（至少）扩展 `record` 插件 / 第二条采集路径 / 事后解码 / JNI / 放弃实时 5 种方案。 |
| OP-2 | 调音器实时反馈算法 | 实时音高反馈；±10 cents 命中率 ≥ 70% on-device；可关闭。算法由 SDD 决定。 |
| OP-3 | 音高识别算法 | on-device；准确率 SDD spike 定。 |
| OP-4 | 和弦识别算法 | on-device；准确率 SDD spike 定。 |
| OP-5 | 哑音切换检测（非阻断观察） | 用户可见观察项；算法由 SDD 决定；不进入过关判定。 |

---

## 12. 5 项默认决策（用户修正统一）

> 其他方向已按既定原则直接决定（如 Day 1 free / Day 2+ gated = Phase 6；动态曲谱 = bar-by-bar；阈值 = on-device 校准基线，非永久常量）。

| # | 决策 | 默认值 | 影响 |
|---|------|--------|------|
| **PD1** | 早期音频分析部署 | **纯端本地分析**（推荐） | 隐私 / 延迟 / 离线 / Phase 3 服务预算 |
| **PD2** | 内容制作方式 | **P1-P4 in-repo 结构化内容**；**CMS 推迟到 Platform 阶段** | 非工程师能否上 Day 3+；v2.x 不依赖 CMS |
| **PD3** | 商业模型 | **免费核心 + 后期订阅** | Day 1 免费试用 + Phase 6 商业化 |
| **PD4** | 识别引擎选型 | **SDD 可行性分析后决定**；**不预设 FFT / autocorrelation / YIN 等具体算法** | 包大小 / 授权 / Phase 3 时间线 |
| **PD5** | 用户档案 | **前期单本地档案**；**账号 / 多端同步 延后** | P6 账号架构 |

**已直接决定（不列入待决策）**：
- Day 1 free、Day 2+ gated → 锁定到 Phase 6 商业化
- 动态曲谱 = bar-by-bar（不强求 beat-by-beat）
- 节奏/起音对齐阈值 = **初始真机校准基线**，**不**永久锁定
- 哑音切换数 = **非阻断观察**，**不**进入过关判定
- 客观过关依据**仅**节奏/起音对齐（音色/音高/和弦 → Audio Intelligence 阶段）
- Android + 尤克里里 = 唯二优先目标；iOS / 平板 = Deferred（P6+ 受合规约束）
- Day 3/5/6/7 课程数量冻结直到 P2 真机验证

---

## 13. 多 Agent 协作记录

| 角色 | Agent ID | 任务 | 结论 |
|------|----------|------|------|
| Primary Agent | 主会话 | 修订 PRD v2 v0.3 | 完成 |
| Product Strategy Reviewer | `a3941933d7f44ae19` | 范围 / 平台 / 5 项决策审查 | **Blocker → 修订 → Approved** |
| Audio Architecture Reviewer | `aeee42779a5458716` | 音频能力假设 / 算法锁定审查 | **Blocker → 修订 → Approved** |
| 05-music-domain-expert | `ab73d240921ebe74d` | 互动教学闭环 + 教学路径（v0.2 沿用） | **Approved with conditions**（v0.2 已采纳） |
| Benchmark Research Agent | `a75670748e0c89cc5` | v1.1.0 能力审计（v0.1 沿用） | 完成 L1-L16 |

### 13.1 v0.3 Reviewer 反馈与修订

| 来源 | 关键 Blocker | 修订位置 |
|------|--------------|----------|
| Audio Architecture | 算法锁定（16 处：spectral flux / energy envelope / RMS / dBFS / μ+kσ / autocorrelation / YIN / chroma / FFT / Hz 频带 / 固定阈值） | 全部删除或降级为产品能力描述；§5.4 |
| Audio Architecture | "T031E 已暴露 PCM 流" 错误表述（18 处） | 全部删除；改为 §5.5 + §11 SDD 开放问题 |
| Audio Architecture | "28/32 对齐" 应标"初始真机校准基线" | §5.6 |
| Audio Architecture | PRD §5.3 / §5.4 / §8.2 / ROADMAP §2 / §9 三处数字不一致（24 / 28 / 80%） | §5.6 + §8.2 统一为初始基线 + 准确度 ≥ 80% |
| Product Strategy | Android-first vs Android-only 不一致（PRD §1 / §2 / §4 / §9 / ROADMAP §0 / Benchmark §1） | §1 / §2 / §9 全部统一为 "Android-first / common High-G GCEA" |
| Product Strategy | iOS / Low-G / 平板 误标"永久 Out" | §4 全部改为 Deferred + 前置条件；§9 仅留多乐器 / 用户端 Web / 社区 / 推送 / 五线谱 / 后台 / 自动调音 / 第三方 SDK 为永久 Out |
| Product Strategy | PD2 默认 = "轻量 CMS" 与用户修正"P1-P4 in-repo"矛盾 | §12 PD2 = "P1-P4 in-repo 结构化内容；CMS 推迟到 Platform 阶段" |
| Product Strategy | PD4 默认 = "扩展 v1.1.0 onset + 新 FFT" 锁定 FFT | §12 PD4 = "SDD 可行性分析后决定；不预设具体算法" |
| Product Strategy | 用户端 Web Out 但管理端 Web（CMS）不可误删 | §4.11 CMS / §9 显式声明 |

修订后 Reviewer 重新判定：**Approved**。

---

## 14. 三步反思

### 14.1 【初步实现】

- 平台 = Android-first（不永久 Android-only）；common High-G GCEA（不限定 21 寸）。
- iOS / Low-G / 平板 / 商业歌曲 / 用户输入 / 用户上传 = Deferred + 前置条件（不永久排除）；多乐器 / 用户端 Web / 社区 / 推送 = 永久 Out。
- PRD 只描述产品能力（起音检测 / 节奏对齐 / 哑音切换观察 / 反馈延迟 / 准确度 / 误检率 / 可关闭）；算法留给 SDD/TDD。
- P2 第一切片客观过关依据**仅**节奏/起音对齐；哑音切换降级为非阻断观察。
- "28/32 对齐"为初始真机校准基线，非永久常量。
- 删除 "T031E 已暴露 PCM 流"，改为 SDD §5.5 开放问题 + §11 OP-1。
- 5 项默认决策统一。

### 14.2 【自我找茬】（≥3 项偏航风险）

1. **SDD 开放问题可能拖慢 P1**：OP-1 的 5 种方案对比 + spike 验证可能消耗 1-2 个 sprint。**缓解**：将 SDD spike 列为 P1-T0（最先启动），与和弦库补齐并行；不阻塞其他 P1 任务。
2. **"节奏/起音对齐 ≥ 28/32" 仍可能被误读为产品常量**：即使加了"初始真机校准基线"标注。**缓解**：在 §5.6 强调"on-device 数据后重新协商；不构成永久产品常量"；P2 关闭门 review 必含阈值重审。
3. **"哑音切换 ≠ 过关判定"可能让产品感觉反馈不完整**：用户期待"全维度反馈"。**缓解**：哑音切换保留为观察项 + 自评辅助，不丢失该信息；§5.4 显式说明。
4. **Deferred 项在 §4 / §9 双重声明可能让读者困惑**：§4 是 Deferred，§9 是永久 Out，需清晰边界。**缓解**：§4 / §9 互为对照表（Deferred / Out 各自明确）。
5. **5 项默认决策可能让 PD2 误读为"未来 CMS 永远不做"**：实际是 P1-P4 in-repo，P6 才上 CMS。**缓解**：§12 PD2 明确"P1-P4 in-repo 结构化内容；CMS 推迟到 Platform 阶段"。
6. **iOS / 平板 Deferred 仍可能被误判为永久排除**：虽然有"Deferred + 前置条件"措辞。**缓解**：§4.12 / §4.13 单独成行 + 显式说明"非永久 Out"。
7. **§11 OP-1 中"放弃实时分析"方案的延迟/准确度目标可能无法达成**：作为兜底方案被列出来，但 §8.2 目标仅适用实时方案。**缓解**：SDD 选择"放弃实时"时须重新协商 §8.2 目标。

### 14.3 【终极交付】

- 采纳 Audio Architecture Reviewer 16 处算法锁定修正 + 18 处 PCM 流表述修正 + 4 处阈值表述修正。
- 采纳 Product Strategy Reviewer 8 项 Blocker 全部修订。
- §4 / §9 Deferred vs Out 边界清晰；§5.5 + §11 SDD 开放问题替代 v0.2 "PCM 流前置"硬门。
- 5 项默认决策与用户修正完全一致（PD1 纯端 / PD2 in-repo P1-P4 / PD3 免费+订阅 / PD4 SDD 决定 / PD5 单本地）。
- v1.1.0 PRD 保留原样（不覆盖不删除）。
- v2 PRD 路径：`docs/PRD_v2.md`。

---

## 15. 文档版本

| 版本 | 日期 | 修改内容 |
|------|------|----------|
| 0.1 | 2026-06-24 | T046 初稿（6 阶段 + 11 维度） |
| 0.2 | 2026-06-24 | T046 修正稿（5 阶段优先级 + 9 步互动闭环 + Deferred + 5 项 Pending Decisions + 文档迁移） |
| 0.3 | 2026-06-24 | T046 最终修正稿（Android-first / common High-G GCEA / iOS·Low-G·平板 Deferred / 算法降级为产品能力 / SDD 开放问题 / 初始校准基线 / 5 项默认决策） |

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
- `docs/dev/TASK_LEDGER.md`（统一台账）
- `docs/dev/AGENT_QUALITY_METRICS.md`（统一指标）
- T046 v1.1.0 Capability Audit（独立只读 Agent 报告）
- T046 Audio Architecture Review（`aeee42779a5458716`）
- T046 Product Strategy Review（`a3941933d7f44ae19`）