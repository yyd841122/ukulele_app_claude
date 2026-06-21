# 多 Agent 协作流程 (MULTI_AGENT_WORKFLOW)

## 0. 执行模式分级

本项目协作模式分三级，**当前处于 Level 1 → Level 2 过渡阶段**。

### 0.1 Level 1：人工调度（当前主模式）

| 步骤 | 角色 | 动作 |
|------|------|------|
| 1 | ChatGPT（首席架构师） | 拆任务、出具完整 Prompt |
| 2 | 用户 | 复制 Prompt 给 Claude / MiniMax |
| 3 | Agent | 执行任务，输出结果 |
| 4 | 用户 | 把执行报告发回 ChatGPT |
| 5 | ChatGPT | 审核报告，决定通过 / 打回 |

**特征**：
- 全程人工中转
- ChatGPT 决定任务拆分
- Agent 不直接通信

### 0.2 Level 2：半自动协作（当前过渡目标）

| 步骤 | 角色 | 动作 |
|------|------|------|
| 1 | Chief Architect / ChatGPT | 分配任务 |
| 2 | Agent | 读取对应 Agent md 文档 |
| 3 | Agent | 按 Task Spec 执行（输入/输出/验收标准固定） |
| 4 | Agent | 输出 Task Report（统一格式） |
| 5 | QA Reviewer / Compliance Reviewer | 介入审核 |
| 6 | Chief Architect | 最终审核 |

**特征**：
- 每个 Agent 使用对应 md 文档作为身份与流程依据
- 每个任务有固定输入 / 输出 / 验收标准
- 每次输出 Task Report
- QA / Compliance 介入审核
- 审核门禁明确（详见 agents/00-chief-architect.md）

### 0.3 Level 3：自动化调度（后期再考虑）

| 工具 / 方案 | 状态 |
|-------------|------|
| claude-octopus / codex-octopus | 调研中，暂不实现 |
| MCP（Model Context Protocol） | 调研中，暂不实现 |
| 本地 task runner | 调研中，暂不实现 |
| GitHub Issues 驱动 | 调研中，暂不实现 |

**说明**：Level 3 在 MVP 阶段**不急于实现**。先稳固 Level 1 / Level 2，避免过早自动化导致流程失控。

### 0.4 当前阶段判定

- **当前**：Level 1 → Level 2 过渡阶段
- **目标**：稳定进入 Level 2，所有 Agent 都有明确 md 文档、任务有 Task Report、QA / Compliance 审核介入
- **不做**：Level 3 自动化调度在 MVP 阶段实现

### 0.5 与第 5 节审核流程的映射

| 模式 | 对应审核流程 | 说明 |
|------|--------------|------|
| Level 1 | 5.1 Chief Architect 审核（人工） | ChatGPT 主脑代行 Chief Architect 审核职责 |
| Level 2 | 5.1 + 5.2 + 5.3 全套审核 | Chief Architect + QA Reviewer + Compliance Reviewer 三方介入 |
| Level 3 | 自动化审核（暂未实现） | 由 task runner / 自动化脚本替代人工审核 |

**当前阶段（Level 1 → Level 2 过渡）**：默认走 5.1 + 5.2 + 5.3，但执行频率和严格度由 ChatGPT 主脑按情况灵活控制。

---

## 1. Agent 角色总览

| Agent | Role | 职责 |
|-------|------|------|
| 00-chief-architect | Chief Architect | 技术架构、任务拆分、最终审核、范围守卫 |
| 01-product-manager | Product Manager | PRD、需求、用户故事、优先级 |
| 02-flutter-architect | Flutter Architect | Flutter 技术架构、依赖管理、feature 设计 |
| 03-mobile-ui-engineer | Mobile UI Engineer | UI 实现、Material 3 |
| 04-audio-engineer | Audio Engineer | 音频录制、播放、调音器 |
| 05-music-domain-expert | Music Domain Expert | 尤克里里知识、内容设计 |
| 06-local-data-engineer | Local Data Engineer | 本地数据库、持久化 |
| 07-qa-reviewer | QA Reviewer | 测试策略、验收、回归 |
| 08-compliance-reviewer | Compliance Reviewer | 合规、版权、隐私 |

## 2. Agent 分工与边界

### 2.1 Chief Architect (00-chief-architect)

**职责范围**：
- 定义技术边界和架构决策
- 拆分任务给其他 Agent
- 审核所有 Agent 的输出
- 防止范围膨胀
- 维护 ADR 文档

**不允许**：
- 不直接写业务代码（示例代码除外）
- 不越过 PRD 扩展功能
- 不忽视合规和测试

### 2.2 Product Manager (01-product-manager)

**职责范围**：
- 维护 PRD 文档
- 维护 MVP_SCOPE 文档
- 编写用户故事
- 维护 ROADMAP
- 需求优先级排序

**不允许**：
- 不直接实现代码
- 不修改技术架构
- 不越权审批 Scope 变更

### 2.3 Flutter Architect (02-flutter-architect)

**职责范围**：
- Flutter 项目结构设计
- Riverpod / Drift / go_router 架构
- Feature-first 目录规范
- 依赖版本管理
- 跨 feature 接口设计

**不允许**：
- 不决定产品功能
- 不编写 UI 细节代码
- 不绕过 MVP Scope

### 2.4 Mobile UI Engineer (03-mobile-ui-engineer)

**职责范围**：
- 实现 UI 页面和组件
- Material 3 样式
- 响应式布局
- 用户交互
- 动画效果

**不允许**：
- 不设计架构
- 不修改数据模型
- 不绕过 MVP Scope

### 2.5 Audio Engineer (04-audio-engineer)

**职责范围**：
- 麦克风权限处理
- 音频录制
- 音频播放
- 调音器频率检测
- 音频格式处理

**不允许**：
- 不实现 AI 评分（MVP）
- 不做网络音频传输
- 不绕过 MVP Scope

### 2.6 Music Domain Expert (05-music-domain-expert)

**职责范围**：
- 定义尤克里里练习路线
- 设计和弦库内容
- 编写练习指导
- 指法图内容
- 节奏练习设计

**不允许**：
- 不编写代码
- 不决定技术实现
- 不添加未授权内容

### 2.7 Local Data Engineer (06-local-data-engineer)

**职责范围**：
- Drift 数据库设计
- Repository 实现
- 数据迁移
- 备份恢复

**不允许**：
- 不设计产品功能
- 不绕过 MVP Scope 的离线限制

### 2.8 QA Reviewer (07-qa-reviewer)

**职责范围**：
- 测试策略制定
- 验收标准定义
- 测试用例评审
- 回归测试
- Agent 输出质量审查

**不允许**：
- 不直接修复 Bug
- 不绕过 MVP Scope

### 2.9 Compliance Reviewer (08-compliance-reviewer)

**职责范围**：
- 麦克风隐私合规
- 录音数据安全
- 歌曲版权审查
- 内置内容合规
- 上架政策

**不允许**：
- 不直接修复技术问题
- 不绕过 MVP Scope

## 3. Agent 协作流程

### 3.1 任务分配流程

```
ChatGPT (主脑)
  → 分析需求
  → 拆分为具体任务
  → 分配给对应 Agent
  → Agent 执行
  → 输出 Task Report
  → ChatGPT 审核
  → 通过/打回
```

### 3.2 Agent 领取任务

1. 读取 TODO_INDEX.md 中的任务
2. 确认任务的输入、输出、验收标准
3. 确认前置条件已满足
4. 开始执行

### 3.3 Agent 输出报告

每个任务完成后，必须填写 Task Report，包含：

- Task ID
- 执行 Agent
- Summary（做了什么）
- Files Created
- Files Modified
- Commands Run
- Validation（如何验证）
- Risks（风险点）
- Follow-up（后续建议）

## 4. Handoff 流程

### 4.1 Handoff 触发条件

以下情况需要 Handoff：
- 任务完成，需要交接给下一个 Agent
- 任务暂停，需要其他 Agent 继续
- 遇到阻塞，需要升级

### 4.2 Handoff 文档要求

每个 Handoff 必须包含：
- 当前任务状态
- 执行 Agent
- 输入上下文
- 已完成内容
- 修改文件
- 验证结果
- 未完成内容
- 风险点
- 下一步建议

### 4.3 Handoff 示例

```markdown
## Handoff: T007 首页开发

**执行 Agent**: 03-mobile-ui-engineer
**交接给**: -
**状态**: 进行中

### 输入上下文
- 前置任务 T006 已完成
- 路由已配置

### 已完成
- HomePage UI 骨架

### 未完成
- 今日练习卡片
- 快速操作入口

### 风险
- 暂无

### 下一步
- 完成今日练习卡片
```

## 5. 审核流程

### 5.1 Chief Architect 审核

所有 Agent 输出必须经过 Chief Architect 审核：
- 架构是否符合规范
- 是否在 MVP Scope 内
- 是否有风险
- 是否达到验收标准

### 5.2 QA Review 审核

代码实现需经过 QA Review：
- 测试覆盖是否足够
- 验收标准是否满足
- 边界条件是否处理

### 5.3 Compliance Review 审核

涉及以下内容需 Compliance Review：
- 新增权限
- 新增数据收集
- 新增内容
- 第三方服务接入

## 6. 冲突解决

### 6.1 Scope 冲突

如果 Agent 之间对 Scope 理解不一致：
1. 引用 MVP_SCOPE.md
2. 无法解决时升级到 Chief Architect

### 6.2 技术冲突

如果技术方案有分歧：
1. 列出备选方案
2. 说明各方案利弊
3. Chief Architect 最终决定

## 7. Agent 通信规范

### 7.1 报告格式

所有 Agent 报告使用统一格式：
- 使用 Markdown
- 中文为主
- 技术术语保留英文
- 避免歧义

### 7.2 禁止事项

- 禁止 Agent 之间直接讨论（通过 ChatGPT 中转）
- 禁止越权审批
- 禁止绕过 Handoff 直接交接

## 8. Release 阶段协作机制（T019 起追加）

本节是 T019 阶段在保留既有内容基础上追加的 **Release 工程化阶段**协作机制。任何 Release 阶段任务（T019-T024）必须遵循本节规则。

### 8.1 角色与边界（Release 阶段）

| 角色 | 角色定位 | 关键职责 | **不允许** |
| --- | --- | --- | --- |
| 用户 | 产品决策方 + 密钥保管方 + 真机验收方 | 决定是否生成正式 keystore；保管 keystore / key.properties / 密码；真机安装与冒烟；高风险操作确认 | 不替 Agent 完成实现；不替 Agent 填写真机验收"通过"结论；不在未批准时让 Agent push 或创建 Tag |
| GPT 首席架构师 | 范围 / 任务拆分 / 复审 / 阶段批准 | 拆分 Release 阶段任务；审核每一份 Task Report；批准进入下一任务 | 不直接写实现；不替用户保管密钥；不复审未提供证据的报告 |
| Release 执行 Agent（Claude） | 单任务实现 / 测试 / Commit / 结构化报告 | 在 SDD/TDD 允许范围内实现；执行定向 + 全量验证；按 TDD §8 Evidence Template 输出报告；Commit（**不 push**） | 不自行进入下一任务；不保存 / 回显密码；不擅自创建 Tag / push；不替用户勾选真机验收项 |
| QA / Review Agent | 只读审查 | 审查 diff 范围、测试证据、签名风险、范围合规 | 不修改文件；不复审未提供 Evidence 的报告 |
| 文档 / 追溯角色 | 维护 SDD / TDD / TASK_LEDGER / 验收记录 | 维护任务台账与技术债台账；汇总 MVP / Release 验收基线 | 不混入产品代码改动 |

### 8.2 协作铁律

> 本节与现有第 0 节"执行模式分级"协同使用。Release 阶段默认在 **Level 1 → Level 2** 模式下推进，GPT 首席架构师复审是必经关卡。

1. **同一工作树同一时间只允许一个写入 Agent**：禁止多个 Agent 并发修改 master。任何时刻若发现工作树被未授权修改，Agent 必须**立即停止**并上报用户。
2. **Reviewer 默认只读**：QA / Review Agent 不得直接修改文件；如发现问题必须以报告形式提交给用户与 GPT 首席架构师。
3. **每个 Agent 只能修改明确文件所有权**：
   - Release 执行 Agent 仅修改 `pubspec.yaml` 的 `version` 字段、`android/app/build.gradle`、`android/app/src/main/AndroidManifest.xml`（仅在不破坏 MVP 约束的前提下）、`.gitignore`、文档；
   - **不**修改产品代码、测试代码、数据库 schema、依赖列表；
   - 任何超出所有权范围的改动必须先取得 GPT 首席架构师书面授权。
4. **每个任务独立 Commit**：禁止把多个任务的改动合并为一个 commit。
5. **不允许 Agent 自行进入下一任务**：每个任务结束后 Agent 必须显式输出"等待 GPT 首席架构师复审"，由用户在复审通过后**手动复制下一个任务 Prompt**给 Agent。
6. **高风险操作需要用户确认**：
   - 生成 / 移动 / 删除正式 keystore
   - 写入 `key.properties`
   - push 任何分支或 Tag
   - 创建 / 移动 / 删除 `v0.1.0-mvp` 以外的 Tag
   - 提交到 Google Play / 任何应用商店
7. **测试失败不得 Commit**：包括 `flutter analyze` 警告、`flutter test` 失败、产物校验失败中任意一项。
8. **未经用户确认不得把真机项目写成通过**：Agent 在报告中只能写"待用户在 T023 验收"，不得代写"通过"。
9. **不得由 Agent 保存或回显密钥密码**：Agent 报告、SDD、TDD、任务台账中**严禁**出现真实密码 / keystore 内容 / 用户目录 / 本机代理配置。
10. **push 与 Tag 必须由任务明确授权**：Release 阶段所有 push 与 Tag 动作均由用户在 GPT 首席架构师复审通过后手动执行；Agent 仅产出本地 commit。
11. **发现未知改动立即停止**：Agent 开始任何 Release 任务前必须执行 `git status --short`、`git branch --show-current`、`git rev-parse --short HEAD`、`git log -1 --oneline`、`git remote -v`、`git tag -n1 --list v0.1.0-mvp` 基线核对；若工作树不 clean / 分支不是 master / HEAD 不匹配基线 / 出现未知改动，必须**立即停止**并报告用户。
12. **使用任务队列 + 交接报告 + GPT 复审关卡**：
    - 每个任务产出独立的"交接报告"（handoff）由下一个任务读取
    - 交接报告必须包含"未完成项 / 风险 / 下一步建议"
13. **三步反思继续作为强制要求**：与现有 `docs/DEVELOPMENT_WORKFLOW.md` 配合，每个 Agent 报告必须包含 `Initial Implementation` / `Self-Critique` / `Final Delivery` 三段。

### 8.3 Release 阶段责任表（简洁版）

| 阶段 / 任务 | 主责 Agent | 必须复核 | 关键交付 | 高风险动作 |
| --- | --- | --- | --- | --- |
| T019 设计阶段 | Claude（执行） | GPT 首席架构师 | SDD / TDD / MULTI_AGENT_WORKFLOW / TASK_LEDGER | 无（仅文档） |
| T020 签名与敏感文件保护 | Claude（执行） | QA Reviewer + GPT 首席架构师 + 用户 | `android/app/build.gradle` + `.gitignore` | ❌ **不生成** keystore / 不写 key.properties |
| T021 版本元数据 + Release 构建 | Claude（执行） | QA Reviewer + GPT 首席架构师 + 用户（执行构建命令） | `pubspec.yaml` + APK / AAB 产物 | Release 构建命令（用户授权） |
| T022 产物自动验证 | Claude（执行） | QA Reviewer + GPT 首席架构师 | 校验脚本 + `docs/dev/RELEASE_ARTIFACTS.md` | 无 |
| T023 真机安装与冒烟 | 用户（主导）+ Claude（产出验收模板） | GPT 首席架构师 | 真机验收报告 | 真机操作（用户） |
| T024 Release 验收与发布检查点 | Claude（执行） | GPT 首席架构师 + 用户 | `docs/dev/RELEASE_ACCEPTANCE.md` + TASK_LEDGER / TECH_DEBT 更新 | 无 |

### 8.4 Release 阶段任务流

```
用户 → 复审 T019 报告 → 决定是否进入 T020
   ↓
GPT 首席架构师 → 出具 T020 Prompt（明确 keystore / key.properties 决策）
   ↓
用户 → 确认决策 + （如必要）提供 keystore 摘要（密码不在 Prompt 内）
   ↓
Claude → T020 实现 → 定向验证 → 全量回归 → 自检 → Commit → 输出报告
   ↓
QA Reviewer → 只读审查 → 出具审查意见
   ↓
GPT 首席架构师 → 复审 → 通过 / 打回
   ↓
（通过后）用户 → 决定是否进入 T021
   ...（T021 → T024 循环）
   ↓
T024 通过后 → 用户手动 push + 创建 Tag（不在 Agent 范围）
```

> **不在本节引入自动化调度**：与现有 §0.3 一致，Level 3 自动化调度（claude-octopus / MCP / 本地 task runner / GitHub Issues 驱动）在 Release 阶段**不实现**，避免引入未验证的自动化风险。

### 8.5 与既有审核流程（§5）的衔接

| 既有审核流程 | Release 阶段额外要求 |
| --- | --- |
| 5.1 Chief Architect 审核 | **必须**包含 SDD/TDD 一致性、敏感文件未跟踪、Tag 未被修改、范围未越过 §8.2 第 3 条所有权 |
| 5.2 QA Review 审核 | **必须**包含 TDD §4 Signing Tests / §5 Artifact Tests / §7 Acceptance Gate 全部通过 |
| 5.3 Compliance Review 审核 | **必须**确认 Manifest 不出现新增权限、不引入第三方服务、不收集新增用户数据 |

## 9. 文档版本

| 版本 | 日期 | 修改内容 |
|------|------|----------|
| 0.1 | 2026-06-19 | 初始版本 |
| 0.2 | 2026-06-21 | T019 追加：Release 阶段协作机制（§8），明确角色 / 铁律 / 责任表 / 任务流；保留既有 Level 1 → Level 2 → Level 3 分级与 9 个 Agent 角色定义 |
