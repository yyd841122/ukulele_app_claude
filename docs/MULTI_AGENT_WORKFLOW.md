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

## 8. 文档版本

| 版本 | 日期 | 修改内容 |
|------|------|----------|
| 0.1 | 2026-06-19 | 初始版本 |
