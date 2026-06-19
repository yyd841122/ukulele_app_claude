# Prompt 风格指南 (PROMPT_STYLE_GUIDE)

> 本指南定义了向 Claude/MiniMax 等 Agent 发送任务时的 Prompt 书写规范。

## 1. Prompt 书写原则

### 1.1 自包含原则

每个 Prompt 必须是**自包含**的：

- 不依赖"之前文档已说明"
- 不依赖"根据上下文理解"
- 新会话打开 Prompt 即能理解任务

### 1.2 明确性原则

每个 Prompt 必须**明确**：

- 明确项目路径
- 明确当前任务
- 明确输入/输出
- 明确验收标准

### 1.3 边界性原则

每个 Prompt 必须**明确边界**：

- 明确禁止事项
- 明确 Out of Scope
- 明确 Git 边界

---

## 2. Prompt 必含要素

每个任务 Prompt 必须包含：

```markdown
## Context
[项目背景和上下文]

## Project Path
[项目路径]

## Current State
[当前状态]

## Goal
[任务目标]

## Scope
### In Scope
- [在范围内的内容 1]
- [在范围内的内容 2]

### Out of Scope
- [不在范围内的内容 1]
- [不在范围内的内容 2]

## Required Files
- [必须使用的文件 1]
- [必须使用的文件 2]

## Constraints
- [约束 1]
- [约束 2]

## Commands Policy
- [命令执行规则]

## Validation
[如何验证结果]

## Git Policy
- [Git 策略]

## Final Report
[最终报告格式]

## Mandatory Three-Step Reflection
[三步反思要求]
```

---

## 3. 禁止事项

### 3.1 禁止使用

- ❌ `cd ... && ...`（复合命令）
- ❌ 分号串联命令
- ❌ 省略代码（`// ...`）
- ❌ 依赖上一会话上下文
- ❌ "后续再补"等占位

### 3.2 允许使用

- ✅ 逐条执行命令
- ✅ 完整代码
- ✅ 具体验收标准
- ✅ 明确文件路径

---

## 4. 项目路径使用

### 4.1 路径格式

在 Windows PowerShell 环境下：

```bash
# 正确
cd /e/yupi-Projects/ukulele_app

# 错误
cd E:\yupi-Projects\ukulee_app
```

### 4.2 命令执行

- 每条命令单独执行
- 等待上一条完成后执行下一条
- 不使用 `&&` 串联

---

## 5. 验收标准规范

### 5.1 必须包含

每个任务必须定义**可测试的验收标准**：

```markdown
### Acceptance Criteria

- [ ] [验收项 1] - [如何验证]
- [ ] [验收项 2] - [如何验证]
```

### 5.2 验收标准特征

- 可观察
- 可测试
- 不模糊（如"功能正常"不如"能录制 5 分钟音频"）

---

## 6. 三步反思机制

### 6.1 要求

每个任务的最终回复必须包含三步：

**Step 1: Initial Implementation**
[先完成第一版]

**Step 2: Self-Critique**
[至少指出 3 个潜在问题]

**Step 3: Final Delivery**
[修正后的最终交付]

### 6.2 Self-Critique 要点

至少指出 3 个：

- 潜在边界条件漏洞
- 逻辑严谨性问题
- 性能隐患
- 遗漏点

---

## 7. Git 规范

### 7.1 提交规范

```bash
# 每次提交做一件事
git add [files]
git commit -m "type: description"
```

### 7.2 禁止

- ❌ 不 push
- ❌ 不强制 push
- ❌ 不在 main 分支直接开发

---

## 8. Agent 输出规范

### 8.1 报告格式

任务完成后必须报告：

```markdown
## Task Report: [Task ID]

**Agent**: [Agent 名称]
**Summary**: [简要说明]
**Files Created**: [列表]
**Files Modified**: [列表]
**Validation**: [验证结果]
**Risks**: [风险]
**Follow-up**: [后续]
```

### 8.2 风险报告

遇到问题时必须报告：

```markdown
## Risk Report

**风险**: [描述]
**影响**: [影响]
**建议**: [建议]
```

---

## 9. 文档版本

| 版本 | 日期 | 修改内容 |
|------|------|----------|
| 0.1 | 2026-06-19 | 初始版本 |
