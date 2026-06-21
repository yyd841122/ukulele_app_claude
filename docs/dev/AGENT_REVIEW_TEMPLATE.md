# Agent 审查模板 (AGENT_REVIEW_TEMPLATE)

> 本文档是 `ukulele_app` 项目**所有任务最终报告**必须包含的审查模板。Task 报告必须按本模板填写，未填写视为报告不完整，不进入 GPT 复审。
> 是 `docs/MULTI_AGENT_WORKFLOW.md` 定义的协作流程的**报告协议层**落地。

## 1. Document Status

| 字段 | 值 |
| --- | --- |
| Task ID | `T021A_ACTIVATE_MULTI_AGENT_ROLE_SYSTEM` |
| 基线 Commit | `d7bac44` |
| 当前状态 | 协作机制（轻量级） |
| 是否覆盖所有未来任务 | 是（T022 起所有任务） |
| 是否修改 `agents/*.md` 角色原文 | 否 |
| 是否修改生产代码 | 否 |

## 2. 使用说明

1. 每个任务的最终报告**必须**包含本模板的全部章节。
2. `Multi-Agent Roles Used` / `Reviewer Blockers Resolved` / `Final Decision Block` 必须显式填写。
3. 任何字段缺失或写"待执行"但本任务已结束，必须在报告"已知局限"中说明。
4. Reviewer 报告必须基于**实际证据**（命令输出、diff、测试结果、文件路径），不得凭印象填写。
5. Reviewer 默认只读；任何文件修改必须由 Primary Agent 在 `Files Modified` 中显式记录。

## 3. 任务报告模板（Primary + Reviewers）

> 复制以下模板到任务报告原文中，按本任务实际填写。

```markdown
## 任务执行报告

### Task ID
<TASK_ID>

### 摘要（Summary）
<本任务做了什么；不超过 6 行；含"未做什么">

### Multi-Agent Roles Used

- **Primary Agent**：<00-chief-architect | 02-flutter-architect | ...>
- **Review Agents**：<必填；至少 1 个；高风险任务必须含 07-qa-reviewer + 08-compliance-reviewer>
- **User Approval Required**：<Yes / No；高风险操作如 push / Tag / 密钥 / 真机验收必须 Yes>
- **High Risk Areas**：<列出本任务触达的高风险面，如密钥、权限、schema、版本号、构建产物>
- **Writable Scope**：<本任务允许修改的文件路径列表；不超出此范围>
- **Readonly Review Scope**：<Reviewer 实际审查的范围，如 diff、测试输出、产物元信息>

### Primary Agent Findings

#### Implementation Summary
- <做了什么；点列>

#### Files Changed
- **Files Created**：<绝对路径列表>
- **Files Modified**：<绝对路径 + 修改摘要>
- **Files Deleted**：<如有>

#### Validation Performed
| 项 | 命令 / 操作 | 实际输出 / 结果 | 通过条件 | 实际是否通过 |
| --- | --- | --- | --- | --- |
| <编号> | <命令> | <实际> | <条件> | ✅ / ❌ |

#### Known Limitations
- <本任务已知的局限、未实现部分、外部依赖>

#### Open Questions
- <需要用户或 GPT 首席架构师决策的项；无则写"无">

### Reviewer Report

#### Reviewer 1：07-qa-reviewer（或具体角色）

- **Reviewer Role**：<角色名>
- **Scope Reviewed**：<审查的范围>
- **Evidence Checked**：<实际查看的命令输出、文件、测试报告>
- **Findings**：<观察到的关键事实>
- **Blockers**：<阻断项；无则写"无">
- **Non-blocking Suggestions**：<非阻断建议>
- **Approval**：<Approved / Blocked / Needs Chief Architect Decision>

#### Reviewer 2：08-compliance-reviewer（或具体角色）

- **Reviewer Role**：<角色名>
- **Scope Reviewed**：<审查的范围>
- **Evidence Checked**：<实际查看的命令输出、文件、测试报告>
- **Findings**：<观察到的关键事实>
- **Blockers**：<阻断项；无则写"无">
- **Non-blocking Suggestions**：<非阻断建议>
- **Approval**：<Approved / Blocked / Needs Chief Architect Decision>

> 如有更多 Reviewer，按相同结构追加。Reviewer 数量由 `AGENT_ROUTING_MATRIX.md` 决定。

### Compliance / Safety Checklist

- [ ] 未读取 `android/key.properties` / `key.properties` 内容
- [ ] 未在报告、文档、Commit message 中泄露密码 / keystore 内容 / 真实 alias
- [ ] 未在 `.gitignore` 之外的位置移动或公开敏感文件路径
- [ ] 未修改 Manifest 权限清单（除任务明确允许）
- [ ] 未修改 Drift `schemaVersion`（除任务明确允许）
- [ ] 未触碰发布行为（未 push、未创建 Tag、未 amend、未 rebase、未 reset --hard）
- [ ] 未越界修改（diff 范围 ⊆ 任务允许范围）
- [ ] 未把"用户手工验收"写成"自动通过"
- [ ] 未声称已接入 Octopus / MCP / CI 自动 Reviewer（除非仓库确有实现）
- [ ] 未把已忽略的 `android/key.properties` 加入跟踪

### QA Checklist

- [ ] 测试计数（基线 407）<实际值>
- [ ] 新增 / 更新 / 删除测试：<数>
- [ ] `flutter analyze` 结果：<No issues found / 列出问题>
- [ ] `flutter build` 结果：<仅在任务范围内执行>
- [ ] diff 范围仅包含允许文件
- [ ] 构建产物未被 `git ls-files` 跟踪
- [ ] 关键回归矩阵项已勾选
- [ ] 不存在未关闭资源（如 `StreamSubscription` / `Timer` / `TextEditingController`）
- [ ] 不存在 `sleep` 类脆弱测试（除非任务明确允许）

### Git Commit Hash
<commit hash；如未 Commit 写"待 Commit">

### Git Status
<clean / dirty>

### Push Performed
No

### Tag Created
No

### Reviewer Blockers Resolved
- <逐条说明每个 Blockers 如何被解决；引用具体 commit / 文件 / 验证证据>
- 无 Blockers 时写"无"

### Remaining Blockers
- <如有>
- 无则写"无"

### Ready for Chief Architect Review
<Yes / No；必须配合"等待 GPT 首席架构师复审"语句>

### 待用户决策项（User Decisions Required Before Next Task）
- <列表；若无则写"无">

### 风险（Risks）
- <列表；含缓解建议>

### 三步反思（Self-Critique）
1. **Initial Implementation**：<做了什么>
2. **Self-Critique Findings**：<至少 3 个潜在问题 / 边界条件 / 性能隐患>
3. **Final Delivery**：<结合 Self-Critique 修正后的最终方案>
```

## 4. Prompt Snippet（可复用的下游 Prompt 模板）

> 在 GPT 首席架构师出具的下游 Prompt 中，可直接复用本片段强制执行报告结构。

```text
# Multi-Agent 角色与报告结构

## Roles

- **Primary Agent**：<00-chief-architect | 02-flutter-architect | 03-mobile-ui-engineer | 04-audio-engineer | 05-music-domain-expert | 06-local-data-engineer | 07-qa-reviewer>
- **Required Review Agents**：<至少 1 个；高风险任务必须含 07-qa-reviewer + 08-compliance-reviewer>
- **User Approval Required**：<Yes / No>

## 报告强制结构

请按 `docs/dev/AGENT_REVIEW_TEMPLATE.md` 输出最终报告，必须显式包含以下小节：

1. Multi-Agent Roles Used
2. Primary Agent Findings（Implementation Summary / Files Changed / Validation Performed / Known Limitations / Open Questions）
3. Reviewer Report（每个 Reviewer 一段，含 Scope Reviewed / Evidence Checked / Findings / Blockers / Non-blocking Suggestions / Approval）
4. Compliance / Safety Checklist（全部勾选或显式说明例外）
5. QA Checklist（含测试计数、analyze、build、diff 范围、产物跟踪、回归勾选）
6. Final Decision Block（Reviewer Blockers Resolved / Remaining Blockers / Ready for Chief Architect Review）
7. 三步反思（Initial Implementation / Self-Critique Findings / Final Delivery）

## 强制停止条件

- 工作树不 clean / HEAD ≠ 基线 → 立即停止
- 敏感文件被跟踪 / 出现密码字面量 → 立即停止
- Reviewer 报告缺失或仅写"已通过"无证据 → 立即停止
- 把"用户手工验收"写成"自动通过" → 立即停止

## 提交纪律

- 完成后输出 commit hash 与 git status
- 不 push、不创建 Tag、不 amend、不 rebase
- 等待 GPT 首席架构师复审
```

## 5. Reviewer 报告填写守则

1. **Scope Reviewed**：必须具体到文件、commit、命令、测试名；不得写"已审查全部改动"这种模糊描述。
2. **Evidence Checked**：必须列出实际查看的命令输出、文件路径、测试名；不得只写"已验证"。
3. **Findings**：观察到的客观事实；不含"应该"、"可能"。
4. **Blockers**：会直接阻断任务通过的具体缺陷；每条 Blockers 必须可定位到文件 / 行 / 命令输出。
5. **Non-blocking Suggestions**：可改进但不影响通过的建议；显式标注为"建议"。
6. **Approval**：仅 `Approved` / `Blocked` / `Needs Chief Architect Decision` 三选一；不得用"基本通过"等模糊表述。

## 6. Final Decision Block 填写规则

- **Reviewer Blockers Resolved**：每条 Blockers 必须能在 commit / 文件 / 验证证据中找到对应解决方式；无 Blockers 时显式写"无"。
- **Remaining Blockers**：必须与上一节"Reviewer Report"中的 Blockers 对应；不得出现新 Blockers。
- **Ready for Chief Architect Review**：只有当所有 Reviewer 给 `Approved` 或 `Needs Chief Architect Decision` 时才填 `Yes`；任一 Reviewer 给 `Blocked` 且未解决时填 `No`。

## 7. References

- `docs/MULTI_AGENT_WORKFLOW.md`：多 Agent 协作流程总览
- `docs/dev/AGENT_ROUTING_MATRIX.md`：任务路由矩阵
- `docs/dev/AGENT_QUALITY_METRICS.md`：协作质量度量
- `docs/dev/RELEASE_ENGINEERING_TDD.md §8`：Evidence Template（T02x 任务专用）
