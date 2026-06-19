# MiniMax Task 模板 (MINIMAX_TASK_TEMPLATE)

> 当向 MiniMax 等其他 Agent 发送任务时使用此模板。

---

## MiniMax Task 模板

```markdown
# MiniMax Task: [任务名称]

## Context

[项目背景]

你是 [Agent 角色名称]，负责 [职责描述]。

## Assigned Role

[Agent 编号]: [Agent 名称]

## Project Path

```
/e/yupi-Projects/ukulele_app
```

## Goal

[明确的任务目标]

## Inputs

### 输入文档

- [文档 1]
- [文档 2]

### 输入说明

[描述这些输入的内容和如何使用]

## Required Output

### 输出文件

- [输出文件 1]
- [输出文件 2]

### 输出格式

[描述输出文件的格式要求]

## Review Criteria

### 质量标准

- [ ] [标准 1]
- [ ] [标准 2]
- [ ] [标准 3]

### 完成标准

- [ ] 所有必含内容已包含
- [ ] 无占位符或"待完善"
- [ ] 符合文档格式规范

## Forbidden Actions

### 禁止事项

- ❌ 不要省略内容（不使用 `// ...` 等占位）
- ❌ 不要超出 MVP Scope
- ❌ 不要修改未授权的文件
- ❌ 不要在 MVP Scope 外添加功能

### 边界约束

- [约束 1]
- [约束 2]

## Final Response Format

任务完成后，报告：

```markdown
## Task Report: [Task ID]

**Agent**: [Agent 编号] - [Agent 名称]
**Date**: [YYYY-MM-DD]
**Summary**: [简要说明]

### Output Files

**Created**:
- [文件 1]
- [文件 2]

**Modified**:
- [文件 1]

### Quality Checklist

- [ ] [检查项 1] - PASS/FAIL
- [ ] [检查项 2] - PASS/FAIL
- [ ] [检查项 3] - PASS/FAIL

### Risks & Recommendations

**Risks**:
| 风险 | 影响 | 建议 |
|------|------|------|
| [风险 1] | [影响] | [建议] |

**Recommendations**:
- [建议 1]
- [建议 2]

### Next Steps

1. [下一步 1]
2. [下一步 2]
```

## Mandatory Three-Step Reflection

### Step 1: Initial Implementation

[先完成第一版内容]

### Step 2: Self-Critique

[至少指出 3 个潜在问题、遗漏点或边界风险]

1. **问题/遗漏 1**: [描述]
2. **问题/遗漏 2**: [描述]
3. **问题/遗漏 3**: [描述]

### Step 3: Final Delivery

[根据自检结果修正，输出最终版本]

---

## 使用说明

1. 复制此模板
2. 填写所有 `[占位符]`
3. 确保 Goal 和 Required Output 清晰
4. 发送给 MiniMax Agent 执行

---

## 文档版本

| 版本 | 日期 | 修改内容 |
|------|------|----------|
| 0.1 | 2026-06-19 | 初始版本 |
```
