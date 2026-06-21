# Agent 协作质量度量 (AGENT_QUALITY_METRICS)

> 本文档定义多 Agent 协作的**质量度量**与**复盘节奏**，用于判断多 Agent 机制是否产生真实价值、是否沦为形式主义。
> 是 `docs/MULTI_AGENT_WORKFLOW.md` 定义的协作流程的**效果评估层**落地。

## 1. Document Status

| 字段 | 值 |
| --- | --- |
| Task ID | `T021A_ACTIVATE_MULTI_AGENT_ROLE_SYSTEM` |
| 基线 Commit | `d7bac44` |
| 当前状态 | 协作机制（轻量级） |
| 是否引入自动化度量平台 | 否（人工台账 + 主观等级） |
| 是否修改生产代码 | 否 |
| 是否修改 `agents/*.md` 角色原文 | 否 |

## 2. Why Measure

度量目的：

1. **判断多 Agent 是否真有价值**：区分"拦截真实缺陷的协作"与"只走流程的形式主义"。
2. **区分有效审查与形式主义**：通过 `Blockers Valid` / `Blockers Found` 比值衡量 Reviewer 的实际产出。
3. **为后续项目复用机制**：积累可移植的多 Agent 协作经验与失败教训。
4. **驱动角色清理**：长期无产出的 Reviewer 必须删除；高产出 Reviewer 必须保留并明确职责。

> 原则：先做轻量台账，不引入复杂自动化度量平台。任何"为了度量而度量"的指标必须删除。

## 3. Metrics

> 不追求复杂仪表盘；先以"每任务一行台账"形式记录。

### 3.1 缺陷拦截类（按拦截来源分类）

| 指标 | 含义 | 数据来源 |
| --- | --- | --- |
| Defects caught by GPT review | GPT 首席架构师复审拦截的缺陷 | GPT 复审记录 |
| Defects caught by QA Reviewer | QA Reviewer 拦截的缺陷 | Reviewer 报告 + 后续修复 commit |
| Defects caught by Compliance Reviewer | Compliance Reviewer 拦截的缺陷 | Reviewer 报告 + 后续修复 commit |
| Defects caught by domain-specific Reviewer | 领域 Reviewer（如 Flutter Architect、Audio Engineer）拦截的缺陷 | Reviewer 报告 + 后续修复 commit |
| Total defects caught by reviewers | 上述四类之和 | 上述加总 |

### 3.2 流程类

| 指标 | 含义 | 数据来源 |
| --- | --- | --- |
| Rework count | 任务被打回 / 重做的次数 | GPT 复审结论 / 任务台账 |
| Prompt violations | 违反 Prompt 规则（如未声明 Primary Agent、未声明 Review Agents） | 任务报告 |
| Command discipline violations | 违反命令纪律（管道 / 重定向 / `&&` / 复合命令 / 强 push / amend） | 任务报告与 `git log` 校对 |
| Scope violations | 修改了任务未明确允许的文件 | `git diff --stat` 与任务允许范围比对 |
| Test count accuracy | 报告测试计数与实际 `flutter test` 是否一致 | 任务报告与 `flutter test` 输出校对 |
| False confidence incidents | 报告把"用户手工验收"写成"自动通过"或类似 | 任务报告与实际 `TASK_LEDGER` 校对 |

### 3.3 Reviewer 质量类

| 指标 | 含义 | 数据来源 |
| --- | --- | --- |
| Reviewer blocker accuracy | Reviewer 给出的 Blockers 中实际成立的比例 | 后续修复 commit 与 Blockers 比对 |
| Reviewer report completeness | Reviewer 报告是否包含 Scope Reviewed / Evidence Checked / Findings / Blockers / Approval | 任务报告 |
| Time / complexity overhead | 多 Agent 协作带来的时间与复杂度开销（先以主观等级 Low / Medium / High 记录） | 任务报告中的实际耗时与流程步骤数 |

### 3.4 数据纪律

- 所有数据来自**任务报告 / Commit 历史 / `flutter test` / `git diff`** 的可验证事实。
- 任何字段无可靠来源时写"待补录"，不得猜测。
- `Time / complexity overhead` 先用主观等级，不引入计时工具。

## 4. Per-Task Scorecard

> 每个任务完成后，在任务报告中追加以下表格（也可在 `TASK_LEDGER` 中维护）。

| 字段 | 说明 |
| --- | --- |
| Task ID | 任务编号 |
| Primary Agent | 主执行 Agent |
| Review Agents | 实际审查的 Agent 列表 |
| High Risk Areas | 本任务触达的高风险面（密钥 / 权限 / schema / 版本号 / 构建产物） |
| Blockers Found | Reviewer 报告中的 Blockers 总数 |
| Blockers Valid | 实际成立、被后续修复或修改解决的 Blockers 数 |
| Fix Commits Required | 修复 Blockers 需要的额外 commit 数 |
| Tests Passed | 实际 `flutter test` 通过数 |
| Scope Clean | 是否仅修改允许文件（Yes / No） |
| Final Approval | GPT 首席架构师复审结论（通过 / 打回 / 待复审） |
| Collaboration Value | Low / Medium / High（主观评估） |
| Notes | 其他观察（如"Reviewer 报告证据不足"） |

> 评估 `Collaboration Value` 的简易规则：
> - **High**：Reviewer 拦截了真实缺陷，且未显著拖慢任务进度。
> - **Medium**：Reviewer 报告完整但未发现重大问题，仅做规范性检查。
> - **Low**：Reviewer 报告缺失 / 模糊 / 形式主义，或 Reviewer 自身引入偏差。

### 4.1 T022 Scorecard（首个 Per-Task 实例）

| 字段 | 值 |
| --- | --- |
| Task ID | `T022_RELEASE_ARTIFACT_AUTOMATED_VERIFICATION` |
| Primary Agent | `07-qa-reviewer` |
| Review Agents | `02-flutter-architect`、`08-compliance-reviewer` |
| High Risk Areas | 签名证书指纹、构建产物元信息、Manifest 权限声明、`key.properties` / `*.jks` / `*.keystore` 跟踪状态、Release vs Debug 证书区分 |
| Blockers Found | 0（Flutter Architect Reviewer + Compliance Reviewer 均给 `Approved`，未发现阻断项） |
| Blockers Valid | 0（无 Blockers） |
| Fix Commits Required | 0 |
| Tests Passed | 407（基线保持；新增 / 更新 / 删除 0 / 0 / 0） |
| Scope Clean | Yes（仅新建 `tool/verify_release_artifacts.dart`、`docs/dev/RELEASE_ARTIFACTS.md`；仅修改 `docs/dev/TASK_LEDGER.md`、`docs/dev/AGENT_QUALITY_METRICS.md`） |
| Command discipline violation | **Yes**（见下方备注；不构成 Blocker，但须如实记录） |
| Violation types | `redirection`（`2>&1`）、`pipe`（`|`）、`output truncation helper`（`head`） |
| Violation scope | 仅出现在只读环境探测命令（如 `where flutter 2>&1 | head -5`、`ls /c/flutter/flutter/ 2>&1 | head -20`、`ls /d/Software/ 2>&1 | head -20`） |
| Impact assessment | no known file modification；no known `key.properties` content read；no known secret exposure；no artifact verification impact；no Release artifact correctness impact |
| Severity | Process issue；non-blocking for release artifact correctness；recorded and to be avoided in future tasks |
| Final Approval | 待 GPT 复审 |
| Collaboration Value | Medium（Flutter Architect + Compliance Reviewer 报告完整、证据具体，但本任务为静态校验脚本，元信息已知，未发现重大缺陷；Reviewer 主要做规范性检查，未拦截真实 Bug。**备注**：本次复盘中识别出 T022 执行过程存在命令纪律违规——Reviewer 报告证据充分度提升（命令结构、参数、SHA-256 / 元信息等核心证据明确），但命令纪律执行仍有改进空间；该违规为流程问题，不改变 T022 产物验证通过结论） |
| Notes | Flutter Architect Reviewer 确认脚本自实现 SHA-256 与 `certutil` 输出交叉验证一致；Compliance Reviewer 确认 `android/key.properties` 已 ignore 且未跟踪、产物未被 git 跟踪、文档未泄露敏感信息；两个 Reviewer 均按 `AGENT_REVIEW_TEMPLATE.md` 模板填写 `Scope Reviewed` / `Evidence Checked` / `Findings` / `Blockers` / `Approval`，无"已通过"模糊表述；本任务不进行真机验收，T023 仍由用户执行。**命令纪律违规补记（T022A）**：T022 执行过程中曾使用 `where flutter 2>&1 | head -5` 等组合命令探测 Flutter / 资源管理器目录，违反"禁止管道 / 重定向 / 输出截断 helper / 复合命令"的固定命令纪律；GPT 首席架构师曾要求最终报告如实记录该违规但 T022 主报告未记录，本次回填。违规命令经核查属只读环境探测，未发现文件修改、未读取 `android/key.properties` 内容、未泄露密码、不影响产物验证结果；本任务仍按"通过（待 GPT 复审）"归档，但命令纪律约束必须在后续任务（T023 起）严格执行，逐条执行单条命令、禁止管道 / 重定向 / `&&` / 分号 / 复合命令 |

### 4.2 T022A Scorecard（命令纪律事件补录）

| 字段 | 值 |
| --- | --- |
| Task ID | `T022A_RECORD_COMMAND_DISCIPLINE_INCIDENT` |
| Primary Agent | `07-qa-reviewer` |
| Review Agents | `00-chief-architect`、`08-compliance-reviewer` |
| High Risk Areas | 工作流命令纪律、文档事实准确性、未把流程违规夸大为安全事故、未淡化为"无问题" |
| Blockers Found | 0（Chief Architect Reviewer + Compliance Reviewer 均给 `Approved`，未发现阻断项） |
| Blockers Valid | 0（无 Blockers） |
| Fix Commits Required | 0 |
| Tests Passed | 407（基线保持；新增 / 更新 / 删除 0 / 0 / 0） |
| Scope Clean | Yes（仅修改 `docs/dev/AGENT_QUALITY_METRICS.md` §4.1 T022 Scorecard 备注 + §4.2 新增 T022A Scorecard；`docs/dev/TASK_LEDGER.md` 追加 T022A 条目） |
| Command discipline violation | N/A（本任务执行过程遵守命令纪律：仅单条 `git status --short` / `git branch --show-current` / `git rev-parse --short HEAD` / `git log -1 --oneline` / `git ls-files` 等只读命令，无管道 / 重定向 / 复合） |
| Final Approval | 待 GPT 复审 |
| Collaboration Value | Medium（仅补录流程事件，无新功能交付；Reviewer 主要验证事实准确性、是否夸大 / 淡化、是否越界修改） |
| Notes | Chief Architect Reviewer 确认 T022 主结论（产物静态验证通过、APK/AAB 元信息已落盘）保持不变、T022 Scorecard 仅新增违规字段与备注、Scorecard 协作价值未降级；Compliance Reviewer 确认本任务未读取 `android/key.properties` 内容、未记录密码 / keystore 内容 / 用户目录 keystore 路径、未把违规写成密钥泄露 / 产物失败 / T022 不通过、未修改生产代码 / 测试 / 验证脚本 / Release 产物 / 签名配置；详见 `docs/dev/TASK_LEDGER.md` T022A 条目 |

### 4.3 T023 Scorecard（Release 真机安装与冒烟验收）

| 字段 | 值 |
| --- | --- |
| Task ID | `T023_RELEASE_DEVICE_INSTALL_AND_SMOKE` |
| Primary Agent | `07-qa-reviewer` |
| Review Agents | `03-mobile-ui-engineer`、`08-compliance-reviewer` |
| High Risk Areas | 真机安装（签名冲突 / 卸载授权 / 数据清除 / 设备型号识别）、用户手工冒烟验收真实性（18 项是否真正由用户逐项确认）、权限弹窗（无 `RECORD_AUDIO` / 无 `INTERNET`）、模拟录音文案不得误导为真实录音、`key.properties` / keystore 路径 / 密码泄露、push / Tag / amend / rebase 越权发布 |
| Blockers Found | 0（Mobile UI Reviewer + Compliance Reviewer 均给 `Approved`，未发现阻断项） |
| Blockers Valid | 0（无 Blockers） |
| Fix Commits Required | 0 |
| Tests Passed | 407（基线保持；新增 / 更新 / 删除 0 / 0 / 0） |
| Scope Clean | Yes（仅新建 `docs/dev/RELEASE_DEVICE_ACCEPTANCE.md`；仅修改 `docs/dev/TASK_LEDGER.md` 追加 T023 条目 + `docs/dev/AGENT_QUALITY_METRICS.md` §4.3 新增 T023 Scorecard） |
| Command discipline violation | **No**（本任务全程命令均为单条命令；`where adb` 失败后用 `ls /d/Program\ Files\ \(x86\)/Android/android-sdk/platform-tools/adb.exe`（单条命令，shell 转义空格括号，非管道 / 非重定向）成功定位 adb；卸载两次返回码异常如实记录，未伪造证据；安装失败 → 安装成功 → 启动验证 → 用户手工验收顺序严格按 T023 Prompt；无管道、无重定向、无 `&&`、无分号、无复合命令） |
| Device | model=`HUAWEI CDY-AN90`、Android `10` / SDK `29`、serial 后 4 位 `5219`（华为 EMUI 设备，已存在 user 0 / user 128 双用户环境） |
| Install Mode | 卸载后全新安装（首次 `adb install -r` 报 `INSTALL_FAILED_UPDATE_INCOMPATIBLE: signatures do not match` —— 与 T022 一致；用户在第二轮明确回复"确认卸载，允许继续"；卸载两次返回码异常但 `pm list packages` / `pm path` 已查不到包，新 APK 路径与旧路径不同证明卸载生效；后续 `adb install -r` `Success`） |
| User Uninstall Approval | Yes（用户在 T023 第二轮交互中明确回复"确认卸载，允许继续"） |
| Release APK Installed | Yes（APK 路径 `build/app/outputs/flutter-apk/app-release.apk`、SHA-256 `3af73cafba05de89d88843075d33d5fe0c5425c129c54c7226a152910a90753b`、58,558,487 bytes、applicationId=`com.yupi.ukulele` / versionName=`1.0.0` / versionCode=`2`、Release 证书 SHA-256 `e88687e53b272c86d20611c1045fc00d2fd4ca321672b1eec180d7543dc28591`） |
| App Launch Verified | Yes（`mResumedActivity = com.yupi.ukulele/.MainActivity`、`state=RESUMED`、`nowVisible=true`、`pidof com.yupi.ukulele = 5051`、无 ANR / crash） |
| User Smoke Acceptance | Passed（18 项全部由用户在真机上**逐项确认**：1-17 Passed；18 确认为全新安装；详见 `RELEASE_DEVICE_ACCEPTANCE.md` §User Smoke Acceptance） |
| Permissions Dialog | None（User confirmed 项 #2、#8；aapt 静态证据仅含 AGP 自动注入的 `com.yupi.ukulele.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`，**未**声明 `RECORD_AUDIO` / `INTERNET`） |
| Data Clearing Occurred | Yes（卸载会清除 `/data/user/0/com.yupi.ukulele` 私有数据目录；用户在第二轮授权时已接受数据被清除；本次验收**不**证明旧 Debug 数据可迁移到 Release） |
| Sensitive Files Checked | Yes（`git ls-files android/key.properties` / `*.jks` / `*.keystore` 三项均返回空） |
| Build Artifacts Tracked | No（`git ls-files build/app/outputs/**` 返回空） |
| Final Approval | 待 GPT 复审 |
| Collaboration Value | **High**（Mobile UI Reviewer 确认 18 项覆盖完整性 + 大字体 / 溢出检查独立成项 + 模拟录音文案与 SDD/TDD 一致；Compliance Reviewer 在签名不兼容的关键高风险点上独立审查了用户授权证据链（"确认卸载，允许继续"），确认未读取 `key.properties` 内容、未记录 keystore 路径 / 密码、未 push / Tag / amend / rebase / reset --hard；两个 Reviewer 报告均按 `AGENT_REVIEW_TEMPLATE.md` 模板填写 `Scope Reviewed` / `Evidence Checked` / `Findings` / `Blockers` / `Approval`，无"已通过"模糊表述；协作机制把"用户手工验收"严格隔离为 `User confirmed` 来源、把"启动 / 安装"隔离为 `adb observed` 来源，避免 Agent 代写"通过"；Chief Architect 范围守卫确认 diff 仅含允许文件） |
| Notes | Mobile UI Reviewer 重点确认冒烟项 #3-#14 覆盖首页 / 和弦 / 单音 / 节拍器 / 调音器 / 录音 / 记录 / 设置等主要页面、冒烟项 #15 独立要求用户确认大字体 / 溢出检查、模拟录音文案与 SDD/TDD 一致未误导为真实录音；Compliance Reviewer 重点确认用户在签名不兼容时已明确授权（"确认卸载，允许继续"）、卸载在授权后执行、未自动卸载或清除数据、未读取 `key.properties` 内容、未记录 keystore 路径 / 密码、未声称真实录音已实现、未 push / Tag / amend / rebase / reset --hard；T023 涉及的高风险命令纪律项（卸载 / 安装 / 启动验证 / 用户验收）均严格执行单条命令纪律，未触发 T022A 记录的命令纪律违规模式（管道 / 重定向 / 输出截断 helper / 复合）；详见 `docs/dev/TASK_LEDGER.md` T023 条目 + `docs/dev/RELEASE_DEVICE_ACCEPTANCE.md` 全文 |

## 5. Initial Historical Backfill

> 仅回填**有可靠来源**的历史事实，不虚构未知内容。
> 来源限定：`git log` / `TASK_LEDGER.md` / 任务报告原文。

| 任务 / 阶段 | Reviewer / 来源 | 拦截内容 | 后续修复 | 协作价值评估 |
| --- | --- | --- | --- | --- |
| T020_RELEASE_SIGNING_AND_SENSITIVE_FILE_GUARD 期间 debug signing fallback | GPT 复审 | `buildTypes.release.signingConfig` 残留 `signingConfigs.debug` 回退 | T020_FIX_REMOVE_DEBUG_SIGNING_FALLBACK 移除 debug 回退 + 任务图守卫 | High |
| T020 期间 aggregate signing path bug | GPT 复审 | 聚合任务（`build` / `assemble` / `check`）可绕过 `gradle.startParameter.taskNames` 检查 | T020_FIX_REMOVE_DEBUG_SIGNING_FALLBACK 新增 `gradle.taskGraph.whenReady` 守卫 | High |
| T020 期间 absolute path / Groovy DSL 敏感泄露风险 | 任务验证发现 | 闭包内 `String.metaClass.call` 拦截导致密码值出现在 Gradle 异常日志 | T020_FIX_RELEASE_SIGNING_ABSOLUTE_STORE_FILE_PATH 改为显式方法调用 + 路径解析 helper | High |
| T021 期间 | Reviewer 证据 | Release 构建成功，但多 Agent 报告的 Reviewer 证据不完整 | 本任务（T021A）建立 Review Template 标准化 | Medium |
| 早期权限 / 音频依赖清理 | 历史 commit | 移除无实际使用的音频依赖与权限声明（见历史 Task） | 通过 commit 历史可追溯 | Medium |
| 早期 Release assert、UUID、Android embedding 等问题 | 历史 commit | 多处 `assert` / UUID / Android embedding 修复 | 通过 commit 历史可追溯 | Medium |

> 后续每完成 5 个任务或每个阶段结束，必须追加新的回填行。

## 6. Review Cadence

> 不追求每周复盘；以"每 5 个任务 + 每个阶段结束"为节奏。

1. **每 5 个任务复盘一次**：
   - 检查 `Per-Task Scorecard` 中 `Collaboration Value = Low` 的比例。
   - 检查 `Blockers Valid` / `Blockers Found` 比值，淘汰低于阈值的 Reviewer 角色。
   - 检查 `Time / complexity overhead` 是否过高，决定是否简化流程。

2. **每个阶段结束复盘一次**：
   - 阶段示例：MVP 验收阶段、T019-T024 Release 工程化阶段、未来 Audio MVP 阶段。
   - 复盘报告追加到 `AGENT_QUALITY_METRICS.md` 的"Initial Historical Backfill"小节。

3. **角色清理规则**：
   - 长期无产出（连续 5 个任务以上 Blockers Found = 0 且未发现规范性问题）→ 删除或合并。
   - 高产出（持续发现真实问题）→ 明确职责并保留。

4. **不删除** `00-chief-architect`（GPT 复审职责是协作模式核心）、`07-qa-reviewer`（必含 Reviewer）、`08-compliance-reviewer`（高风险任务必含 Reviewer）。

## 7. Anti-Patterns（必须主动识别并避免）

| 反模式 | 表现 | 应对 |
| --- | --- | --- |
| 形式主义 Reviewer | Reviewer 报告只写"已审查、未发现问题"无证据 | 强制使用 `AGENT_REVIEW_TEMPLATE.md`，要求 `Scope Reviewed` / `Evidence Checked` 必须具体 |
| 把"未审查"当"通过" | Reviewer 跳过审查直接给 Approval | 在 `Final Decision Block` 增加"Reviewer 缺失证据"判定为 `Blocked` |
| 一人多角 | Primary Agent 同时充当多个 Reviewer | `Multi-Agent Roles Used` 必须显式声明 Review Agents 数量 |
| 角色膨胀 | 为"多 Agent 感"加无意义 Reviewer | 严格遵循 `AGENT_ROUTING_MATRIX.md`，新增角色必须能产生可观察证据 |
| 自动化承诺 | 声称已接入 Octopus / MCP / CI 自动 Reviewer | 仓库实现为准；未实现不得声称 |
| 把用户验收写成自动通过 | Agent 在报告中写"真机验收通过" | 强制模板中 `User Approval Required` + 单独"用户真机确认"小节 |

## 8. References

- `docs/MULTI_AGENT_WORKFLOW.md`：多 Agent 协作流程总览
- `docs/dev/AGENT_ROUTING_MATRIX.md`：任务路由矩阵
- `docs/dev/AGENT_REVIEW_TEMPLATE.md`：任务报告与审查模板
- `docs/dev/TASK_LEDGER.md`：任务台账（Per-Task Scorecard 来源）
