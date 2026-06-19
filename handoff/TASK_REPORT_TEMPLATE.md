# Task Report 模板

> 当一个 Agent 完成一个任务时，必须填写此报告并提交给 Chief Architect。

---

## Task Report 模板

```markdown
# Task Report: [Task ID]

## 基本信息

| 项目 | 内容 |
|------|------|
| Task ID | [Task ID] |
| Task Name | [任务名称] |
| Agent | [Agent 编号和名称] |
| 执行日期 | [YYYY-MM-DD] |
| 耗时 | [X 小时/Y 分钟] |

## Summary

[简要描述这个任务做了什么，1-3 句话]

## Files Created

[new]
- [文件路径 1]
- [文件路径 2]

## Files Modified

[changed]
- [文件路径 1]
- [文件路径 2]

## Commands Run

[执行的命令]

```bash
[命令 1]
[命令 2]
[命令 3]
```

## Validation

### 自检清单

- [ ] [检查项 1]
- [ ] [检查项 2]
- [ ] [检查项 3]

### 验证结果

**PASS** / **FAIL**

[如果 FAIL，描述问题]

## Risks

| 风险 | 影响 | 级别 | 缓解措施 |
|------|------|------|----------|
| [风险 1] | [影响] | [高/中/低] | [措施] |
| [风险 2] | [影响] | [高/中/低] | [措施] |

## Follow-up

### 后续任务

- [后续任务 1] (Task ID: [ID])
- [后续任务 2] (Task ID: [ID])

### 建议

[其他建议]

## Dependencies

- [依赖 1] - [状态: 已满足/未满足]
- [依赖 2] - [状态: 已满足/未满足]

## Blockers

- [阻塞因素 1]
- [阻塞因素 2]

## Approval

| 角色 | 审核人 | 状态 | 日期 |
|------|--------|------|------|
| Chief Architect | [姓名] | [APPROVED/REJECTED/PENDING] | [日期] |

### 审核意见

[Chief Architect 的反馈意见]

---

## 文档版本

| 版本 | 日期 | 修改内容 |
|------|------|----------|
| 0.1 | 2026-06-19 | 初始版本 |
```

---

## Task Report 填写指南

### 填写时机

在以下情况下必须填写 Task Report：
- 任务完成时
- 任务被阻塞时
- Chief Architect 要求时

### 填写要求

1. **Summary**：简洁明了，1-3 句话
2. **Files Created/Modified**：使用相对于项目根目录的路径
3. **Commands Run**：记录重要的命令执行
4. **Validation**：必须实际执行验证，不能只是"假设通过"
5. **Risks**：诚实评估风险，不要隐瞒
6. **Follow-up**：明确后续任务和负责人

### 提交方式

1. 填写此模板
2. 保存为 `handoff/task-report-[task-id].md`
3. 发送给 Chief Architect

---

## 文档版本

| 版本 | 日期 | 修改内容 |
|------|------|----------|
| 0.1 | 2026-06-19 | 初始版本 |
