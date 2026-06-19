# ukulele_app - 尤克里里弹唱练习 App

## 项目简介

ukulele_app 是一款面向尤克里里初学者的练习打卡型移动应用，解决"不知道每天练什么"和"不清楚自己练得怎么样"两大核心痛点。

当前阶段为 MVP 前的项目文档与多 Agent 协作体系初始化，所有架构、PRD、Agent 角色、任务拆分均已文档化，为后续 Flutter 开发奠定基础。

## MVP 目标

在 MVP 阶段，应用专注于本地离线练习体系，提供以下核心功能：

- 今日练习计划展示
- 标准 GCEA 调音器
- 单音基础练习
- 基础和弦库与指法图
- 节拍器
- 录音、回放、自评
- 本地练习记录保存

**MVP 不做**：账号系统、云同步、联网 AI/API、商业化收费、完整歌曲练习。

## 当前阶段

- **Phase 0: 文档与多 Agent 体系**（当前）
- Phase 1: Flutter App Shell
- Phase 2: 基础练习体系
- Phase 3: 调音器与音频基础能力
- Phase 4: 节拍器、录音、回放、自评
- Phase 5: 本地练习记录
- Phase 6: MVP 打磨

## 技术栈概览

| 层级 | 技术选型 |
|------|----------|
| 框架 | Flutter 3.x / Dart |
| 状态管理 | Riverpod |
| 本地数据库 | Drift + SQLite |
| 路由 | go_router |
| 音频录制 | record |
| 音频播放 | just_audio |
| 数据序列化 | freezed + json_serializable |
| 测试 | flutter_test |
| 目标平台 | Android first, iOS reserved |

## 多 Agent 协作原则

本项目采用 ChatGPT 作为总架构师（Chief Architect），Claude / MiniMax 作为执行 Agent 的分工模式：

- **Chief Architect**: 技术边界定义、任务拆分、最终审核、防止范围膨胀
- **Product Manager**: PRD 维护、需求优先级、用户故事
- **Flutter Architect**: 技术架构、依赖边界、feature-first 目录设计
- **Mobile UI Engineer**: 移动端 UI 实现
- **Audio Engineer**: 音频录制、播放、调音器
- **Music Domain Expert**: 尤克里里专业知识、内容设计
- **Local Data Engineer**: 本地数据模型、数据库设计
- **QA Reviewer**: 测试策略、验收标准
- **Compliance Reviewer**: 隐私合规、内容版权

详见 [docs/MULTI_AGENT_WORKFLOW.md](docs/MULTI_AGENT_WORKFLOW.md)

## 文档目录

```
docs/
├── PRD.md                    # 产品需求文档
├── MVP_SCOPE.md              # MVP 明确边界
├── TECH_STACK.md             # 技术栈选择
├── ARCHITECTURE.md           # 架构设计
├── ROADMAP.md                # 阶段路线图
├── AUDIO_RECOGNITION_PLAN.md # 音频能力规划
├── COMPLIANCE.md              # 合规风险
├── CONTENT_POLICY.md          # 内容策略
├── DATA_MODEL_DRAFT.md        # 数据模型草稿
├── DEVELOPMENT_WORKFLOW.md    # 开发流程
├── MULTI_AGENT_WORKFLOW.md    # 多 Agent 协作
└── ADR/
    ├── ADR-001-choose-flutter.md
    ├── ADR-002-mvp-offline-first.md
    └── ADR-003-audio-capability-staging.md

agents/
├── AGENT_TEMPLATE.md         # Agent 文档模板
├── 00-chief-architect.md
├── 01-product-manager.md
├── 02-flutter-architect.md
├── 03-mobile-ui-engineer.md
├── 04-audio-engineer.md
├── 05-music-domain-expert.md
├── 06-local-data-engineer.md
├── 07-qa-reviewer.md
└── 08-compliance-reviewer.md

tasks/
├── TODO_INDEX.md             # 任务总索引
├── T000_INIT_PROJECT_DOCS_AND_AGENTS.md
├── PHASE_0_FOUNDATION.md
├── PHASE_1_MVP_PRODUCT.md
├── PHASE_2_FLUTTER_SHELL.md
├── PHASE_3_AUDIO_AND_TUNER.md
├── PHASE_4_PRACTICE_SYSTEM.md
├── PHASE_5_LOCAL_RECORDS.md
└── PHASE_6_MVP_POLISH.md

handoff/
├── HANDOFF_TEMPLATE.md
├── TASK_REPORT_TEMPLATE.md
└── AGENT_REVIEW_TEMPLATE.md

prompts/
├── PROMPT_STYLE_GUIDE.md
├── CLAUDE_TASK_TEMPLATE.md
└── MINIMAX_TASK_TEMPLATE.md

research/
├── FIRECRAWL_RESEARCH_PLAN.md
└── CONTEXT7_DOCS_PLAN.md
```

## 明确不做的功能

以下功能在 MVP 阶段**明确不做**，禁止任何 Agent 擅自扩展：

- ❌ 账号系统 / 登录注册
- ❌ 云同步
- ❌ 联网 AI / API 调用
- ❌ 商业化收费
- ❌ 社区、排行榜、好友、分享
- ❌ 完整歌曲练习
- ❌ 复杂 AI 自动评分
- ❌ AI 自动扒谱
- ❌ 多平台桌面端
- ❌ Low G 调弦支持
- ❌ 非 21 寸尤克里里支持

## 后期预留方向

以下功能为 MVP 后的演进方向，预留架构扩展点：

- ✅ iOS 支持
- ✅ 账号系统
- ✅ 云同步
- ✅ AI/API 服务抽象层
- ✅ AI 曲谱生成
- ✅ 歌曲和弦谱生成
- ✅ 完整歌曲练习
- ✅ 音高评分
- ✅ 节奏评分
- ✅ 和弦识别
- ✅ 扫弦方向识别
- ✅ 演奏完整度评分
- ✅ 订阅收费
- ✅ 商业化上架
- ✅ 社区/排行榜/分享
- ✅ Low G 调弦
- ✅ TAB 四线谱 / 五线谱 / 简谱 / 混合谱
- ✅ 其他尺寸尤克里里

## 音乐范围

- MVP 仅支持 21 寸尤克里里
- 标准 GCEA 调弦
- MVP 和弦歌词谱展示
- MVP 显示基础指法图
- 后期支持其他尺寸、Low G、更多谱面格式
