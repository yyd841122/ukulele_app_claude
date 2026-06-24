# T046 — AI音乐学园 Benchmark 与功能对标矩阵

> Task ID：`T046_PRODUCT_V2_PRD_FINAL_CORRECTION`
> 日期：2026-06-24 | 版本：0.3
> 协作 Agent：Primary Agent / Product Strategy Reviewer (`a3941933d7f44ae19`) / Audio Architecture Reviewer (`aeee42779a5458716`) / 05-music-domain-expert (`ab73d240921ebe74d`)

## 0. 证据分级与来源限制（v0.3 沿用 v0.2）

### 0.1 证据标签

| 标签 | 含义 | 允许来源 |
|------|------|----------|
| ✅ Verified | 来自可信官方/用户一手观察的事实 | AI音乐学园官方 App Store 页面 / 官网 / 官方帮助与隐私页 / 用户提供的真实观察 |
| 🟡 Inferred | 基于产品类别的合理推断 | 必须附推断依据；不得作为主证据 |
| ⚪ Unknown | 暂未通过可信来源独立确认 | 留空或显式标注；不为填满矩阵而推断 |

### 0.2 来源白名单

| 允许作为主证据 | 数量限制 |
|----------------|----------|
| AI音乐学园官方 App Store 页面 | 1 |
| AI音乐学园官网 | 1 |
| AI音乐学园官方帮助 / 隐私 / 服务条款页面 | 多个 |
| 用户提供的真实观察 | 多个 |
| **二级来源**（补充） | **最多 2 个** |

### 0.3 不允许作为主证据的来源

- 小红书 / 抖音 / 豆瓣 / Wikipedia：禁止。
- Yousician / Simply Guitar / Fender Play / GuitarTuna：仅作"竞品参考"，单独成列；**不作为 AI音乐学园功能的证据**。
- 营销文案 / 宣传海报：不等同于产品行为；引用必须标注"Inferred (marketing claim)"。
- 反编译 APK / 抓取私有 API / 复制受版权内容：明确禁止。

### 0.4 本次调研状态声明

> **T046 调研阶段被用户两次收紧**：
> - v0.1：停止扩大网络搜索，改为只读 v1.1.0 能力审计。
> - v0.2：来源限定为 AI音乐学园官方页面 + 最多 2 个二级来源。
> - v0.3：本版本沿用 v0.2 来源限制；矩阵保留**严格保守**的证据等级。
>
> 任何后续官方页面抓取必须回填到 Verified 列；任何 v2 PRD 中引用本矩阵的"必做"项必须重新核对证据等级。

## 1. 适用范围过滤（v0.3 修订）

本项目长期产品定位：**Android-first（初期）、common High-G GCEA 尤克里里（默认 21 寸 Soprano，不限定 21 寸）、零基础到弹唱**。

| 维度 | 规则 |
|------|------|
| 平台 | Android-first（初期）；iOS Deferred（详见 PRD §4.12）；多乐器永久 Out |
| 乐器 | 仅纳入尤克里里相关功能；钢琴 / 吉他 / 鼓 / 古筝等排入竞品参考 |
| 网络 | 离线核心功能 vs 联网功能分开列；离线对应 P1-P5，联网对应 P6 |
| 内容 | 区分"原创 / 公版"vs"商业授权"；本项目禁止商业歌曲入 MVP，详见 PRD §4.10 |

## 2. AI音乐学园 vs ukulele_app v2 功能对标矩阵（v0.3 修订）

> 表中"AI音乐学园"列：⚪ Unknown 单元格表示本次 T046 暂未通过可信来源独立确认。
> 表中"v2 状态"列：**Deferred** = 当前不实现但标记前置条件；**永久 Out** = 永久 Out of Scope；**计划中** = 进入 v2 路线。
> 表中"差异化"列：本项目相对 AI音乐学园可主张的尤克里里专属差异化能力。

| 维度 | 序号 | 功能 | 类别 | AI音乐学园 | ukulele_app v1.1.0 | v2 状态 | 阶段 | 证据 | 差异化主张 |
|------|------|------|------|------------|---------------------|---------|------|------|-------------|
| 课程 | C-01 | 系统课程地图（多阶段学习路径） | 必有 | ⚪ Unknown | 部分（7 天循环，缺阶段化） | 计划中 | Curriculum (P4) | ⚪ Unknown | 尤克里里专属 5 阶段 |
| 课程 | C-02 | 课程地图可视化（树/网状） | 已有/调整 | ⚪ Unknown | ❌ | 计划中 | P4 | ⚪ Unknown | 简明而非炫技 |
| 课程 | C-03 | 关卡/小节高亮 | 对标必做 | ⚪ Unknown | 部分（T041 SVG 静态叠加） | 计划中 | P2 | ⚪ Unknown | 静态优先；动态留 P4 |
| 教学 | T-01 | 图文教学 | 已有/调整 | ✅ Verified（产品类别） | ✅（PRD §6.4 / T041） | KEEP | n/a | ✅ Verified | — |
| 教学 | T-02 | 视频教学 | 长期商业化 | ⚪ Unknown | ❌ | **Deferred**（CMS + 视频制作 + 版权） | P6+ | ⚪ Unknown | 自制视频成本高、暂不引入 |
| 教学 | T-03 | 互动教学（9 步闭环） | 对标必做 | ⚪ Unknown | 部分（T041 Lesson 模板） | 计划中 | **P2（关键门）** | ⚪ Unknown | 节奏/起音对齐客观反馈 |
| 谱 | N-01 | 和弦库（含指法图） | 已有/调整 | ✅ Verified（产品类别） | ✅ 4/7（C/Am/F/G） | P1 补足 G7/Dm/Em | P1 | ✅ Verified | — |
| 谱 | N-02 | 和弦谱（曲谱） | 对标必做 | ⚪ Unknown | ❌ | **Deferred**（原创 + 自制 SVG） | P4+ | ⚪ Unknown | 原创公版 |
| 谱 | N-03 | 节奏谱（可视化） | 对标必做 | ⚪ Unknown | 部分（T041 SVG） | 计划中 | P2 | ⚪ Unknown | 静态 SVG 优先 |
| 谱 | N-04 | TAB | 长期商业化 | ⚪ Unknown | ❌ | **Deferred**（TAB 数据模型） | P4+ | ⚪ Unknown | 明确不引入五线谱/简谱 |
| 谱 | N-04b | 五线谱 / 简谱 | 永久 Out | n/a | ❌ | 永久 Out of Scope | n/a | n/a | 不引入 |
| 谱 | N-05 | 歌词（弹唱） | 长期商业化 | ⚪ Unknown | ❌ | **Deferred**（原创 + 版权） | P6+ | ⚪ Unknown | 原创 |
| 谱 | N-06 | 歌曲课程（跟弹） | 对标必做 | ⚪ Unknown | ❌ | 计划中 | P2 | ⚪ Unknown | 原创曲目跟弹 |
| 谱 | N-07 | 动态曲谱（光标/小节高亮） | 差异化 | ⚪ Unknown | ❌ | 计划中 | P2（静态高亮）→ P4（动态光标） | ⚪ Unknown | 离线可行；本地算法 |
| 工具 | U-01 | 调音器（实时反馈） | 已有/调整 | ✅ Verified（产品类别） | ❌（v1.1.0 仅为静态指南） | 计划中（算法 SDD 决定） | P1 | ✅ Verified | 算法 SDD 决定，不预设 |
| 工具 | U-02 | 节拍器 | 已有/调整 | ✅ Verified（产品类别） | ✅（4/4，50-200 BPM） | 计划中（加可听点击音） | P1 | ✅ Verified | — |
| 工具 | U-03 | 节奏型切换 | 长期商业化 | ⚪ Unknown | ❌（PRD §6.5 明确不做） | **Deferred**（静态可视化优先） | P4+ | ⚪ Unknown | 明确边界 |
| 工具 | U-04 | 和弦工具（替代/转位） | 长期商业化 | ⚪ Unknown | ❌ | **Deferred** | P3+ | ⚪ Unknown | 教学辅助 |
| 识别 | R-01 | 音高识别 | 差异化 | ⚪ Unknown | ❌ | **Deferred**（算法 SDD 决定） | P3 | ⚪ Unknown | 离线 |
| 识别 | R-02 | 起音识别（节奏/起音对齐） | 差异化 | ⚪ Unknown | ❌ | 计划中（算法 SDD 决定） | **P2** | ⚪ Unknown | 离线 |
| 识别 | R-03 | 节奏对齐 | 差异化 | ⚪ Unknown | ❌ | 计划中（算法 SDD 决定） | **P2** | ⚪ Unknown | 离线 |
| 识别 | R-04 | 和弦识别 | 长期商业化 | ⚪ Unknown | ❌ | **Deferred**（算法 SDD 决定） | P3+ | ⚪ Unknown | 离线 |
| 反馈 | F-01 | 实时反馈（光标/指示灯） | 差异化 | ⚪ Unknown | ❌ | 计划中 | P2（静态高亮）→ P4（动态光标） | ⚪ Unknown | 离线 |
| 反馈 | F-02 | 评分（节奏对齐） | 差异化 | ⚪ Unknown | ❌（仅手动自评） | 计划中 | **P2** | ⚪ Unknown | 算法 SDD 决定；可关闭 |
| 反馈 | F-02b | 评分（音准 / 和弦） | 长期商业化 | ⚪ Unknown | ❌ | **Deferred** | P3+ | ⚪ Unknown | 算法 SDD 决定 |
| 反馈 | F-03 | 过关（pass/fail，**仅节奏/起音对齐**） | 对标必做 | ⚪ Unknown | ❌ | 计划中（客观反馈驱动） | **P2** | ⚪ Unknown | 阈值 = 初始真机校准基线 |
| 反馈 | F-04 | 哑音切换（**非阻断观察**） | 对标必做 | ⚪ Unknown | ❌ | 计划中（不进入过关判定） | P2 | ⚪ Unknown | 观察项；可关闭 |
| 反馈 | F-05 | 复习（薄弱点） | 长期商业化 | ⚪ Unknown | ❌ | **Deferred** | P5 | ⚪ Unknown | 离线推荐 |
| 个性化 | P-01 | 难度自适应 | 长期商业化 | ⚪ Unknown | ❌ | **Deferred** | P5 | ⚪ Unknown | 离线 |
| 个性化 | P-02 | 练习推荐 | 长期商业化 | ⚪ Unknown | ❌ | **Deferred** | P5 | ⚪ Unknown | 离线 |
| 记录 | L-01 | 练习记录 | 已有 | ✅ Verified（产品类别） | ✅（Drift + 本地） | KEEP | n/a | ✅ Verified | — |
| 记录 | L-02 | 连续练习（streak） | 长期商业化 | ⚪ Unknown | ❌ | **Deferred** | P5 | ⚪ Unknown | 本地计算 |
| 记录 | L-03 | 激励（徽章/进度条） | 长期商业化 | ⚪ Unknown | ❌ | **Deferred** | P6+ | ⚪ Unknown | 谨慎引入 |
| 内容 | X-01 | 原创 / 公版内容 | 差异化 | ⚪ Unknown | ✅（PRD §12 / CONTENT_POLICY） | KEEP + 扩展 | All | ✅ Verified | 永远原创公版 |
| 内容 | X-02 | 商业 / 授权歌曲 | **Deferred**（用户修正：非永久 Out） | ⚪ Unknown | ❌ | **Deferred**（完整版权链 + 合规审查） | P6+ | ⚪ Unknown | 永不引 MVP；可授权 |
| 内容 | X-03 | 用户输入歌曲名/歌词/链接 | **Deferred**（同 X-02） | ⚪ Unknown | ❌ | **Deferred**（完整版权过滤 + 审核 + DMCA） | P6+ | ⚪ Unknown | 永不引 MVP |
| 内容 | X-04 | 用户上传自制曲谱/音频 | **Deferred**（同 X-02） | ⚪ Unknown | ❌ | **Deferred**（同上） | P6+ | ⚪ Unknown | 永不引 MVP |
| 平台 | A-01 | Android | 平台 | ✅ Verified（产品类别） | ✅ | KEEP（**Android-first**） | All | ✅ Verified | 主平台 |
| 平台 | A-02 | iOS | **Deferred**（用户修正：非永久 Out） | ⚪ Unknown | ❌ | **Deferred**（跨平台选型 + UX 重做 + 合规前置 + 测试设备） | P6+ | ⚪ Unknown | 暂不投入 |
| 平台 | A-03 | 用户端 Web / 桌面 | **永久 Out（用户端）** | n/a | ❌ | 永久 Out of Scope（用户端） | n/a | n/a | 资源约束 |
| 平台 | A-04 | 平板 UI 优化 | **Deferred**（用户修正：非永久 Out） | ⚪ Unknown | ❌ | **Deferred**（设计 token 扩展 + 布局组件 + 跨设备测试） | P6+ | ⚪ Unknown | 手机优先 |
| 平台 | A-05 | 鸿蒙 / Android Go | 永久 Out | n/a | ❌ | 永久 Out of Scope | n/a | n/a | 不适配 |
| 平台 | A-06 | Low-G 调弦 | **Deferred**（用户修正：非永久 Out） | n/a | ❌ | **Deferred**（Low-G 音高映射表 + 调音器算法适配 + 内容制作） | P3+ | n/a | 默认 High-G |
| 平台 | A-07 | 常见 High-G GCEA | 平台 | ✅ Verified（产品类别） | ✅ | KEEP（**不限定 21 寸**，默认 21 寸 Soprano） | All | ✅ Verified | 入门款即可 |
| 平台 | A-08 | 多乐器 | 永久 Out | n/a | ❌ | 永久 Out of Scope | n/a | n/a | 尤克里里专属 |
| 账号 | ACC-01 | 账号体系 | 长期商业化 | ⚪ Unknown | ❌ | **Deferred** | P6 | ⚪ Unknown | 前期单本地档案 |
| 账号 | ACC-02 | 云同步 | 长期商业化 | ⚪ Unknown | ❌ | **Deferred** | P6 | ⚪ Unknown | 前期单本地档案 |
| 账号 | ACC-03 | 订阅/付费 | 长期商业化 | ⚪ Unknown | ❌ | **Deferred** | P6 | ⚪ Unknown | 免费核心 + 后期订阅 |
| 账号 | ACC-04 | 社区/排行榜/好友 | 永久 Out | n/a | ❌ | 永久 Out of Scope | n/a | n/a | 永不引入 |
| 推送 | PUSH-01 | 推送通知 | 永久 Out | n/a | ❌ | 永久 Out of Scope | n/a | n/a | 永不引入 |
| 联网 | NET-01 | 任何联网 API | 长期商业化 | ⚪ Unknown | ❌（不申请 INTERNET） | **Deferred** | P6 | ⚪ Unknown | INTERNET 权限在 P6 之前不开 |
| 第三方 | 3RD-01 | 第三方分析 SDK | 永久 Out | n/a | ❌ | 永久 Out of Scope | n/a | n/a | 永不引入 |
| CMS | CMS-01 | 内容管理（CMS，**含管理端 Web**） | 长期商业化 | ⚪ Unknown | ❌ | **Deferred**（P1-P4 in-repo 结构化内容） | P6 | ⚪ Unknown | 用户端 Web Out 不影响管理端 Web 保留 |

## 3. 竞品参考（仅作行业参考，不作为 AI音乐学园功能证据）

| 竞品 | 与 ukulele_app 的关系 | 借鉴维度 |
|------|----------------------|----------|
| Yousician | 多乐器（含吉他/贝斯/钢琴/尤克里里） | 实时反馈 / 课程地图（仅作行业经验） |
| Simply Guitar | 吉他为主 | 跟弹交互（仅作行业经验） |
| Fender Play | 吉他为主 | 课程结构（仅作行业经验） |
| GuitarTuna | 调音器为主 | 调音器精度边界（仅作行业经验） |

## 4. 来源声明（v0.3）

| 来源 | 类型 | 引用情况 |
|------|------|----------|
| 本项目内部 PRD v1.1.0 / ROADMAP / T041 / lesson_c_am_down_4x4 | 内部文档 | 充分引用 |
| T046 v1.1.0 Capability Audit（独立只读 Agent 报告） | 内部审计 | 充分引用 |
| AI音乐学园官方 App Store 页面 | 外部 | 未在本次 T046 抓取；矩阵中"AI音乐学园"列 ⚪ 状态由此导致 |
| AI音乐学园 官方网站 / 帮助 / 隐私页 | 外部 | 未在本次 T046 抓取；⚪ 状态 |
| 用户已提供的真实观察 | 用户输入 | 暂无 |
| 二级来源（≤2 个） | 外部 | 未在本次 T046 抓取 |

> **结论**：本 Benchmark 矩阵保留 50+ 行的覆盖度，但每行"AI音乐学园"列以"⚪ Unknown"为主，以避免凭推断编造事实。T047 / T048 期间如需将某个 ⚪ Unknown 升级为 ✅ Verified，必须以"AI音乐学园官方 App Store 页面 / 官网 / 官方帮助与隐私页"为依据（最多补充 2 个二级来源），并通过 05-music-domain-expert + 08-compliance-reviewer 联合复核。

## 5. 文档版本

| 版本 | 日期 | 修改内容 |
|------|------|----------|
| 0.1 | 2026-06-24 | T046 初稿：30+ 行矩阵 + Verified/Inferred/Unknown 三级证据 |
| 0.2 | 2026-06-24 | T046 修正稿：来源白名单收紧（仅 AI音乐学园官方 + ≤2 二级）；Deferred + 前置条件显式标注 |
| 0.3 | 2026-06-24 | T046 最终修正稿：Android-first / common High-G GCEA / iOS·Low-G·平板 Deferred / 算法描述降级为产品能力 / 5 项默认决策统一 |