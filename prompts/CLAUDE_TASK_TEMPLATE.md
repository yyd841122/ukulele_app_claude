# Claude Task 模板 (CLAUDE_TASK_TEMPLATE)

> 当向 Claude Code 发送任务时使用此模板。

---

## Claude Task 模板

```markdown
# Claude Task: [任务名称]

## Context

[项目背景]

你是 [Agent 角色名称]，负责 [职责描述]。

## Project Path

```
/e/yupi-Projects/ukulele_app
```

## Current State

[当前项目状态，描述已有的内容和待完成的内容]

## Goal

[明确的任务目标，1-2 句话]

## Scope

### In Scope

- [在范围内的任务 1]
- [在范围内的任务 2]
- [在范围内的任务 3]

### Out of Scope

- [不在范围内的任务 1]
- [不在范围内的任务 2]

## Required Files

### 必须读取

- [文件 1]
- [文件 2]

### 必须创建/修改

- [文件 1]
- [文件 2]

## Constraints

### 技术约束

- [约束 1]
- [约束 2]

### 流程约束

- [约束 1]
- [约束 2]

### 禁止事项

- ❌ 不使用 `cd ... && ...`
- ❌ 不省略代码
- ❌ 不 push 到远程
- ❌ 不在 MVP Scope 外添加功能

## Commands Policy

1. 每条命令单独执行
2. 等待命令完成后执行下一条
3. 使用 PowerShell/Bash 语法

## Validation

### 验收标准

- [ ] [标准 1] - 验证方式：[如何验证]
- [ ] [标准 2] - 验证方式：[如何验证]
- [ ] [标准 3] - 验证方式：[如何验证]

### 验证命令

```bash
[验证命令 1]
[验证命令 2]
```

## Git Policy

- 本地提交即可，不 push
- 提交消息格式：`type: description`
- 示例：`feat: add tuner page`

## Final Report

任务完成后，报告：

```markdown
## Task Report: [Task ID]

**Agent**: [Agent 名称]
**Summary**: [简要说明完成了什么]

**Files Created**:
- [文件 1]
- [文件 2]

**Files Modified**:
- [文件 1]

**Commands Run**:
- [命令 1]
- [命令 2]

**Validation**:
- [ ] [验收项 1] - PASS/FAIL
- [ ] [验收项 2] - PASS/FAIL

**Risks**:
| 风险 | 影响 | 缓解 |
|------|------|------|
| [风险 1] | [影响] | [缓解] |

**Follow-up**:
- [后续任务 1]
- [后续任务 2]
```

## Mandatory Three-Step Reflection

### Step 1: Initial Implementation

[先完成第一版实现]

### Step 2: Self-Critique

[至少指出 3 个潜在问题]

1. **问题 1**: [描述] - [影响]
2. **问题 2**: [描述] - [影响]
3. **问题 3**: [描述] - [影响]

### Step 3: Final Delivery

[根据自检结果修正，输出最终版本]

---

## 使用说明

1. 复制此模板
2. 填写所有 `[占位符]`
3. 确保 Scope 和 Constraints 清晰
4. 发送给 Claude 执行

---

## 文档版本

| 版本 | 日期 | 修改内容 |
|------|------|----------|
| 0.1 | 2026-06-19 | 初始版本 |
```
