# Agent Review 模板

> 当 Chief Architect 或 QA Reviewer 审查 Agent 输出时使用此模板。

---

## Agent Review 模板

```markdown
# Agent Review: [Task ID]

## 基本信息

| 项目 | 内容 |
|------|------|
| Review ID | [Review ID] |
| Task ID | [被审查的 Task ID] |
| Reviewer | [审查人] |
| 审查日期 | [YYYY-MM-DD] |
| 审查类型 | [Initial/Follow-up/Final] |

## Review Target

[被审查的内容]

**执行 Agent**: [Agent 名称]

---

## Scope Check (范围检查)

### MVP Scope 符合性

| 检查项 | 结果 | 说明 |
|--------|------|------|
| [检查项 1] | PASS/FAIL | [说明] |
| [检查项 2] | PASS/FAIL | [说明] |

### 检查结论

**PASS** / **FAIL** / **CONDITIONAL PASS**

[详细说明]

---

## Quality Check (质量检查)

### 代码质量

| 检查项 | 结果 | 说明 |
|--------|------|------|
| [检查项 1] | PASS/FAIL | [说明] |
| [检查项 2] | PASS/FAIL | [说明] |

### 文档质量

| 检查项 | 结果 | 说明 |
|--------|------|------|
| [检查项 1] | PASS/FAIL | [说明] |
| [检查项 2] | PASS/FAIL | [说明] |

### 检查结论

**PASS** / **FAIL** / **CONDITIONAL PASS**

[详细说明]

---

## Risk Check (风险检查)

| 风险 | 级别 | 检查结果 | 建议 |
|------|------|----------|------|
| [风险 1] | [高/中/低] | [存在/不存在] | [建议] |
| [风险 2] | [高/中/低] | [存在/不存在] | [建议] |

---

## Missing Items (遗漏项)

### 必须修复

- [ ] [遗漏项 1]
- [ ] [遗漏项 2]

### 建议补充

- [ ] [建议项 1]
- [ ] [建议项 2]

---

## Required Fixes (必须修复)

如果检查结论为 FAIL 或 CONDITIONAL PASS，列出必须修复的内容：

### Fix 1

**问题**：[描述问题]
**位置**：[文件/代码位置]
**修复建议**：[如何修复]

### Fix 2

**问题**：[描述问题]
**位置**：[文件/代码位置]
**修复建议**：[如何修复]

---

## Approval Status (审批状态)

| 状态 | 说明 |
|------|------|
| **APPROVED** | 可以继续下一步 |
| **REJECTED** | 需要修改后重新提交 |
| **CONDITIONAL PASS** | 需要修复指定问题 |
| **PENDING** | 等待更多信息 |

---

## Feedback (反馈)

### 给执行 Agent

[给 Agent 的具体反馈]

### 给 Chief Architect

[给 Chief Architect 的信息]

---

## Review Summary

[总结这次审查的关键发现]

### 优点

- [优点 1]
- [优点 2]

### 问题

- [问题 1]
- [问题 2]

### 下一步

1. [步骤 1]
2. [步骤 2]

---

## 文档版本

| 版本 | 日期 | 修改内容 |
|------|------|----------|
| 0.1 | 2026-06-19 | 初始版本 |
```

---

## Review 流程

```
Agent 完成任务
    ↓
提交 Task Report
    ↓
Chief Architect 审查
    ↓
├─ APPROVED → 继续下一步
├─ REJECTED → Agent 修复后重新提交
├─ CONDITIONAL PASS → 修复指定问题
└─ PENDING → 获取更多信息
```

---

## 审查要点

### Scope Check

- 是否在 MVP Scope 内
- 是否超出边界
- 是否有范围蔓延风险

### Quality Check

- 代码是否可读
- 是否有硬编码
- 是否有 TODO
- 异常处理是否完善

### Risk Check

- 是否有技术风险
- 是否有合规风险
- 是否有性能风险

---

## 文档版本

| 版本 | 日期 | 修改内容 |
|------|------|----------|
| 0.1 | 2026-06-19 | 初始版本 |
