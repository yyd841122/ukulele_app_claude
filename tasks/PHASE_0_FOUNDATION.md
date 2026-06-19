# PHASE_0_FOUNDATION

## 阶段概述

| 项目 | 说明 |
|------|------|
| Phase ID | Phase 0 |
| 名称 | 文档与多 Agent 体系 |
| 状态 | **当前阶段** |
| 主要交付物 | 完整的项目文档和 Agent 协作体系 |

---

## 阶段目标

1. 建立完整的项目文档体系
2. 定义 Agent 角色和协作流程
3. 创建任务拆分和 handoff 模板
4. 为后续开发奠定基础

---

## 包含任务

| Task ID | 任务名称 | 状态 |
|---------|----------|------|
| T000 | 初始化项目文档和 Agent 体系 | 进行中 |

---

## 前置条件

- 无（项目启动阶段）

---

## 完成标准

### 文档完成

- [ ] README.md 可说明项目目标
- [ ] PRD.md 包含用户故事和验收标准
- [ ] MVP_SCOPE.md 明确做/不做/预留
- [ ] TECH_STACK.md 确定技术选型
- [ ] ARCHITECTURE.md 定义代码结构
- [ ] ROADMAP.md 包含完整阶段规划
- [ ] AUDIO_RECOGNITION_PLAN.md 定义音频能力边界
- [ ] COMPLIANCE.md 包含隐私合规要求
- [ ] CONTENT_POLICY.md 包含版权策略
- [ ] DATA_MODEL_DRAFT.md 包含数据模型草稿
- [ ] DEVELOPMENT_WORKFLOW.md 定义开发流程
- [ ] MULTI_AGENT_WORKFLOW.md 定义 Agent 协作

### ADR 完成

- [ ] ADR-001: Flutter 选型决策
- [ ] ADR-002: 离线优先策略
- [ ] ADR-003: 音频能力分阶段

### Agent 文档完成

- [ ] AGENT_TEMPLATE.md 模板
- [ ] 00-chief-architect.md
- [ ] 01-product-manager.md
- [ ] 02-flutter-architect.md
- [ ] 03-mobile-ui-engineer.md
- [ ] 04-audio-engineer.md
- [ ] 05-music-domain-expert.md
- [ ] 06-local-data-engineer.md
- [ ] 07-qa-reviewer.md
- [ ] 08-compliance-reviewer.md

### 任务文档完成

- [ ] TODO_INDEX.md
- [ ] T000_INIT_PROJECT_DOCS_AND_AGENTS.md
- [ ] PHASE_0_FOUNDATION.md (本文档)
- [ ] PHASE_1_MVP_PRODUCT.md
- [ ] PHASE_2_FLUTTER_SHELL.md
- [ ] PHASE_3_AUDIO_AND_TUNER.md
- [ ] PHASE_4_PRACTICE_SYSTEM.md
- [ ] PHASE_5_LOCAL_RECORDS.md
- [ ] PHASE_6_MVP_POLISH.md

### 模板完成

- [ ] HANDOFF_TEMPLATE.md
- [ ] TASK_REPORT_TEMPLATE.md
- [ ] AGENT_REVIEW_TEMPLATE.md
- [ ] PROMPT_STYLE_GUIDE.md
- [ ] CLAUDE_TASK_TEMPLATE.md
- [ ] MINIMAX_TASK_TEMPLATE.md

### 研究计划完成

- [ ] FIRECRAWL_RESEARCH_PLAN.md
- [ ] CONTEXT7_DOCS_PLAN.md

---

## 风险点

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| 文档不够具体 | 后续开发无所适从 | 强调具体职责和边界 |
| Agent 职责重叠 | 协作混乱 | 明确 Scope 和 Out of Scope |
| 范围蔓延 | 文档越写越多 | MVP Scope 文档化，严格控制 |

---

## 交接要求

Phase 0 完成后，需要向 Phase 1 交接：

1. **交接文档**：
   - 所有已创建的文档
   - TODO_INDEX.md 明确后续任务
   - Phase 1 的前置条件

2. **交接确认**：
   - Chief Architect 审核通过
   - Product Manager 确认 PRD
   - 所有 Agent 文档已就绪

3. **下一步**：
   - T001: 研究竞品和文档
   - T002: 最终确定 MVP PRD
   - T003: 最终确定技术架构

---

## 文档版本

| 版本 | 日期 | 修改内容 |
|------|------|----------|
| 0.1 | 2026-06-19 | 初始版本 |
