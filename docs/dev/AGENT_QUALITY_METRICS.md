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

### 4.4 T024 Scorecard（Release 验收检查点）

| 字段 | 值 |
| --- | --- |
| Task ID | `T024_RELEASE_DOCS_AND_CHECKPOINT` |
| Primary Agent | `00-chief-architect` |
| Review Agents | `07-qa-reviewer`、`08-compliance-reviewer` |
| High Risk Areas | 阶段结论夸大（把 Release 工程化写成应用商店发布）、未完成能力误写（把全新安装写成数据迁移通过 / 把单台真机写成多设备适配 / 把静态验证写成真机验收 / 把真实录音写成已完成）、敏感信息泄露（`key.properties` 内容 / 密码 / keystore 内容 / 用户目录 keystore 绝对路径）、Release / 真机证据一致性（构建产物 SHA-256 / 字节大小 / 证书指纹 / 18 项冒烟验收来源标注）、越权发布（push / Tag / amend / rebase / reset --hard） |
| Blockers Found | 0（QA Reviewer + Compliance Reviewer 均按 `AGENT_REVIEW_TEMPLATE.md` 只读审查，未发现阻断项；详见 `docs/dev/RELEASE_ACCEPTANCE.md` §Multi-Agent Evidence 节 Reviewer Findings 与 `TASK_LEDGER.md` T024 条目 Reviewer 报告段） |
| Blockers Valid | 0（无 Blockers） |
| Fix Commits Required | 0 |
| Tests Passed | 407（基线保持；新增 / 更新 / 删除 0 / 0 / 0；本任务不重新构建 APK / AAB、不修改生产代码 / 测试代码 / 依赖 / Android 配置） |
| Scope Clean | Yes（仅新建 `docs/dev/RELEASE_ACCEPTANCE.md`；仅修改 `docs/dev/TASK_LEDGER.md` 追加 T024 条目 + `docs/dev/TECH_DEBT.md` 校准 TD-002 / TD-004 状态 + `docs/dev/AGENT_QUALITY_METRICS.md` §4.4 追加 T024 Scorecard + §5 追加 Release 工程化阶段小结） |
| Command discipline violation | **No**（本任务全程命令均为单条命令：`git status --short` / `git branch --show-current` / `git rev-parse --short HEAD` / `git log -1 --oneline` / `git tag -n1 --list v0.1.0-mvp` / `git ls-files ...` / `dart run tool/verify_release_artifacts.dart` / `flutter analyze` / `flutter test` / `grep -c ...` / `Read` / `Write` / `Edit` 等只读或允许写命令；无管道、无重定向、无 `&&`、无分号、无复合命令） |
| Sensitive Files Checked | Yes（`git ls-files android/key.properties` / `*.jks` / `*.keystore` / `build/app/outputs/**` 四项均返回空；`v0.1.0-mvp` 仍指向 `d49ce4b` 未变；无 `key.properties` 内容被读取） |
| Build Artifacts Tracked | No（`git ls-files build/app/outputs/flutter-apk/app-release.apk` / `build/app/outputs/bundle/release/app-release.aab` 返回空） |
| Final Approval | 待 GPT 复审 |
| Collaboration Value | **Medium**（QA Reviewer 与 Compliance Reviewer 均按模板只读审查并给 Approved；本任务为文档收口，证据来自既有 `RELEASE_ARTIFACTS.md` §1-§3 与 `RELEASE_DEVICE_ACCEPTANCE.md` §Device / §User Smoke Acceptance，元信息已知，未发现重大缺陷；Reviewer 主要做规范性检查 + 范围守卫 + 证据一致性核对 + 未完成能力表述隔离 + 敏感信息未泄露确认，未拦截真实 Bug；与 T022 静态校验类似属于"偏流程化审查"，但仍是 Release 阶段必含 Reviewer 验收的一环；协作价值仍以"严格门禁 + 证据完整 + 范围清洁"为主要产出） |
| Notes | QA Reviewer 重点确认：① Release 证据完全来自 `RELEASE_ARTIFACTS.md` 与 `RELEASE_DEVICE_ACCEPTANCE.md` 而非编造；② 未把静态验证写成真机验收、未把全新安装写成数据迁移通过、未把单台真机写成多设备适配；③ 407 测试数与 `flutter test` 实际输出精确一致（基线 407，无新增 / 更新 / 删除测试）；④ T020-T023 任务链完整（T020 + 三条 FIX + T021 + T021A + T022 + T022A + T023）；⑤ T024 文档满足进入下一阶段条件（明确"不替代真实音频阶段设计" + 等待 GPT 首席架构师复审 + 不 push / 不创建 Tag）；Compliance Reviewer 重点确认：① 未读取 `key.properties` 内容、未记录密码 / keystore 内容 / 用户目录 keystore 绝对路径；② 未声称真实录音已实现、未声称麦克风权限已加入、未声称应用商店已提交；③ 未 push、未 Tag、未 amend / rebase / reset --hard；④ 权限表述准确（无 `RECORD_AUDIO` / 无 `INTERNET`，与 `aapt dump permissions` 一致）；本任务全程命令纪律严格执行，未触发 T022A 记录的命令纪律违规模式（管道 / 重定向 / 输出截断 helper / 复合），与 T023 表现一致；详见 `docs/dev/TASK_LEDGER.md` T024 条目 + `docs/dev/RELEASE_ACCEPTANCE.md` 全文 |

### 4.5 T025 Scorecard（真实音频 MVP SDD/TDD 设计）

| 字段 | 值 |
| --- | --- |
| Task ID | `T025_REAL_AUDIO_MVP_SDD_TDD_DESIGN` |
| Primary Agent | `04-audio-engineer`（音频架构 / 文件生命周期 / 依赖候选 / 状态机 / 错误处理设计主导） |
| Review Agents | `02-flutter-architect`（Flutter / Riverpod / Drift / Android 工程边界 / 依赖接入路径 / 任务拆分审查）、`06-local-data-engineer`（Drift schema 升级 / `audioFilePath` 契约 / 删除与文件清理一致性审查）、`08-compliance-reviewer`（RECORD_AUDIO 隐私 / 权限拒绝与永久拒绝 / 密钥发布边界 / 未完成能力表述审查）、`07-qa-reviewer`（测试策略 / 真机验收矩阵 / 回归范围 / 风险停止条件审查） |
| High Risk Areas | 权限（`RECORD_AUDIO` 加入时机 / 拒绝降级 / 永久拒绝 / 系统设置跳转）、隐私（文案准确 / 不误导为上传 / 不误导为分享）、音频文件生命周期（存储目录 / 临时文件 vs 已保存文件 / 命名规则 / 取消清理 / 保存失败清理 / 删除清理 / 孤儿文件）、依赖选型（`record` / `just_audio` / `permission_handler` / `path_provider` 候选评估，不直接决定引入旧依赖）、数据迁移（Drift `schemaVersion 1 → 2` 升级策略 / 旧模拟记录迁移 / `audioFilePath` 契约变化 / 新增字段默认值）、未完成能力误写（不得把"将引入"写成"已实现" / 不得把设计文档写成实现报告 / 不得把 Spike 跳过）、合规（无 `INTERNET` 原则保留 / iOS 预留 `NSMicrophoneUsageDescription` 文案）、命令纪律（单条命令 / 无管道 / 无重定向 / 无 `&&` / 无分号 / 无复合）、越权（push / Tag / amend / rebase / reset --hard 全部禁止） |
| Blockers Found | 0（四个 Reviewer 均按 `AGENT_REVIEW_TEMPLATE.md` 只读审查，未发现阻断项；详见下文 §4.5.1 ~ §4.5.4 Reviewer 报告段与 `TASK_LEDGER.md` T025 条目 Reviewer 报告段） |
| Blockers Valid | 0（无 Blockers） |
| Fix Commits Required | 0 |
| Tests Passed | 407（基线保持；新增 / 更新 / 删除 0 / 0 / 0；本任务不新增测试代码、不运行 build_runner、不构建 APK / AAB） |
| Scope Clean | Yes（仅新建 `docs/dev/REAL_AUDIO_MVP_SDD.md` + `docs/dev/REAL_AUDIO_MVP_TDD.md`；仅修改 `docs/dev/TASK_LEDGER.md` 追加 T025 条目 + `docs/dev/TECH_DEBT.md` 校准 TD-007 + 新增 TD-010 / TD-011 / TD-012 + `docs/dev/AGENT_QUALITY_METRICS.md` §4.5 追加 T025 Scorecard） |
| Command discipline violation | **No**（本任务全程命令均为单条命令：`git status --short` / `git branch --show-current` / `git rev-parse --short HEAD` / `git log -1 --oneline` / `git tag -n1 --list v0.1.0-mvp` / `git tag -n1 --list v1.0.0-release` / `git ls-files ...` / `flutter analyze` / `flutter test` / `Read` / `Write` / `Edit` 等只读或允许写命令；无管道、无重定向、无 `&&`、无分号、无复合命令） |
| Sensitive Files Checked | Yes（`git ls-files android/key.properties` / `*.jks` / `*.keystore` / `build/app/outputs/**` 四项均返回空；`v0.1.0-mvp` 仍指向 `d49ce4b` 未变；`v1.0.0-release` 仍指向 `703d2aa` 未变；无 `key.properties` 内容被读取；两份新文档均未记录密码 / keystore 内容 / 用户目录 keystore 绝对路径） |
| Build Artifacts Tracked | No（`git ls-files build/app/outputs/flutter-apk/app-release.apk` / `build/app/outputs/bundle/release/app-release.aab` 返回空） |
| SDD Compliance | Yes（`REAL_AUDIO_MVP_SDD.md` 含 Document Status / Product Scope / User Experience / Permission and Privacy / Audio File Lifecycle / Dependency Candidates / Data and Schema Design / Architecture / State Machine / Error Handling / Rollout Plan / References 等 11 节，所有"将引入"语句均为设计候选而非已实现声明） |
| TDD Compliance | Yes（`REAL_AUDIO_MVP_TDD.md` 含 Test Strategy / Test Matrix ≥30 条用例 / Manual Acceptance Checklist 22 项 / Regression Matrix 20 项 / Test Gaps / Testing Toolchain / Test Reporting 等 7 节；自动测试边界与真机验收边界明确隔离；不声称"自动测试可验证真实麦克风输入"） |
| Final Approval | 待 GPT 复审 |
| Collaboration Value | **Medium**（四个 Reviewer 均按模板只读审查并给 Approved；本任务为文档设计，证据来自既有 PRD / MVP_SCOPE / TECH_STACK / ARCHITECTURE / RELEASE_ACCEPTANCE 等元文档，未发现重大缺陷；Reviewer 主要做规范性检查 + 范围守卫 + 契约完整性核对 + 未完成能力表述隔离 + 敏感信息未泄露确认 + 依赖 Spike 必经性确认，未拦截真实 Bug；与 T022 / T024 类似属于"偏流程化 + 文档设计审查"，但仍是真实音频阶段必经的"设计门禁"，避免后续 T026+ 任务在无设计共识下启动；协作价值以"完整 SDD/TDD + 30+ 测试用例 + 22 项真机验收 + 12 项后续任务拆分 + 4 个 Reviewer 多视角"为主要产出） |
| Notes | Flutter Architect Reviewer 重点确认：① `REAL_AUDIO_MVP_SDD.md` §5 Dependency Candidates 仅列候选不直接决定引入、`pubspec.yaml` 未被修改、AndroidManifest 未被修改、`RECORD_AUDIO` 未被声明；② §10 Rollout Plan 拆分为 T026-T037 共 12 个子任务，每个任务 Primary / Reviewer / 关键交付清晰；③ T026 `T026_DEPENDENCY_RESEARCH_SPIKE` 明确必经，不允许跳过 Spike 直接进入实现；④ 架构边界遵循既有 `ARCHITECTURE.md`（`shared/services/` + `features/*/application/` + `features/*/data/` 三层结构 + Riverpod Provider 边界 + 跨 feature 通过 Provider 调用）。Local Data Reviewer 重点确认：① `audioFilePath` 契约变化（`null` = 模拟、真实路径 = 真实录音、非法路径 = Repository 拒绝）清晰且与 MVP 既有契约兼容；② Drift `schemaVersion 1 → 2` 迁移策略明确（旧记录保留 + 新增字段默认值）；③ 旧模拟记录迁移策略（不自动转换 + UI 标识 + 不删除旧记录）清楚；④ 删除记录与文件清理事务边界（先数据库后文件 + 文件删除失败不回滚）清楚；⑤ 数据库与文件不一致场景（孤儿文件 + 文件丢失）覆盖。Compliance Reviewer 重点确认：① 未读取 `key.properties` 内容、未记录密码 / keystore 内容 / 用户目录 keystore 绝对路径；② 未声称真实录音已实现、未声称麦克风权限已加入、未声称应用商店已提交；③ 权限拒绝与永久拒绝降级设计有专门段落（SDD §3.2 + TDD TC-P02~P05）；④ 无 `INTERNET` 原则保留（SDD §3.3 + TDD TC-CP02）；⑤ iOS `NSMicrophoneUsageDescription` 文案预留（SDD §3.5）；⑥ 隐私政策补充条款完整（SDD §3.6）；⑦ 未 push、未 Tag、未 amend / rebase / reset --hard。QA Reviewer 重点确认：① TDD §2 Test Matrix 至少 30 条测试用例（实际 31 条自动化 + 1 条真机验收），覆盖权限 / 录音 / 回放 / 保存 / 删除 / 迁移 / 文件系统 / 旧记录兼容 / 状态机 / 合规十个维度；② §3 Manual Acceptance Checklist 22 项真机手工验收项，来源标注明确（User confirmed / aapt / adb）；③ §4 Regression Matrix 20 项不能破坏既有 MVP / Release 工程化；④ §5 Test Gaps 明确自动测试无法验证的边界（真实麦克风输入 / 真实音频播放质量 / iOS 验收 / 多设备 / 永久拒绝弹窗 / 后台切换等）；⑤ 未把"将引入"写成"已实现"；本任务全程命令纪律严格执行，未触发 T022A 记录的命令纪律违规模式（管道 / 重定向 / 输出截断 helper / 复合），与 T023 / T024 表现一致；详见 `docs/dev/TASK_LEDGER.md` T025 条目 + `docs/dev/REAL_AUDIO_MVP_SDD.md` 全文 + `docs/dev/REAL_AUDIO_MVP_TDD.md` 全文 |

#### 4.5.1 Flutter Architect Reviewer（02-flutter-architect）只读审查

- **Reviewer Role**：`02-flutter-architect`
- **Scope Reviewed**：`docs/dev/REAL_AUDIO_MVP_SDD.md` §3 Permission and Privacy / §5 Dependency Candidates / §7 Architecture / §10 Rollout Plan；`docs/dev/REAL_AUDIO_MVP_TDD.md` §1 Test Strategy / §6 Testing Toolchain；既有 `docs/TECH_STACK.md` §6 / §10；既有 `docs/ARCHITECTURE.md` §3 / §5.3 / §7
- **Evidence Checked**：
  - `git status --short` 工作树（Commit 前）显示仅有允许文件改动；
  - `git diff --check` 无空白错误；
  - `pubspec.yaml` 未被修改（既有版本号 `1.0.0+2` 不变）；
  - `AndroidManifest.xml` 未被修改（既有 `RECORD_AUDIO` 未声明不变）；
  - `docs/dev/REAL_AUDIO_MVP_SDD.md` §5.1 - §5.7 依赖候选评估表完整列出 record / just_audio / permission_handler / path_provider / flutter_sound / audioplayers 的用途 / 优点 / 风险 / Spike 必要性；
  - §10 Rollout Plan 拆分 T026-T037 共 12 个子任务，每个子任务明确 Primary / Reviewer / 关键交付；
  - §7 Architecture 沿用既有 `ARCHITECTURE.md` 三层结构（`shared/services/` + `features/*/application/` + `features/*/data/`）+ Riverpod Provider 边界；
- **Findings**：
  - 所有依赖仅作为候选评估，未直接写入 `pubspec.yaml`；
  - T026 `T026_DEPENDENCY_RESEARCH_SPIKE` 明确必经，不允许跳过 Spike 直接进入实现；
  - 12 个子任务边界清晰，依赖关系正确（T026 → T027 → T028 → T029 → T030 → T031 → T032 → T033 → T034 → T035 → T036 → T037）；
  - 服务层边界（AudioRecorderService / AudioPlaybackService / PermissionService / AudioFileStorageService / PracticeRecordRepository 增强）与既有 `lib/shared/services/` 既有约定一致；
- **Blockers**：无
- **Non-blocking Suggestions**：
  - T032 Drift schema 迁移时建议在 §6.2 字段列表上加一栏"是否必填 / 是否 nullable / 默认值"决策矩阵，由 T032 任务最终敲定；本任务设计层暂以"候选字段 + 推荐倾向"形式保留足够灵活度；
- **Approval**：**Approved**

#### 4.5.2 Local Data Reviewer（06-local-data-engineer）只读审查

- **Reviewer Role**：`06-local-data-engineer`
- **Scope Reviewed**：`docs/dev/REAL_AUDIO_MVP_SDD.md` §4 Audio File Lifecycle / §6 Data and Schema Design / §7.1 服务边界；`docs/dev/REAL_AUDIO_MVP_TDD.md` §2.4 删除场景 / §2.5 数据迁移场景 / §2.6 文件系统场景 / §2.7 旧模拟记录兼容
- **Evidence Checked**：
  - §4 Audio File Lifecycle 包含存储目录候选 / 临时 vs 已保存文件 / 文件命名规则 / 取消清理 / 保存失败清理 / 删除清理 / 重启恢复 / 孤儿文件策略 / 最大时长 / 文件大小风险 / 音频格式候选十一个子节；
  - §6 Data and Schema Design 包含 `audioFilePath` 契约 / 新增字段候选 / schemaVersion 升级策略 / 旧记录迁移策略 / 删除与文件清理事务边界 / 文件存在但数据库不存在 / 数据库存在但文件丢失 / 测试隔离八个子节；
  - §2.5 数据迁移场景列出 TC-M01~M04 四条迁移测试用例；
  - §2.4 删除场景列出 TC-D01~D03 三条删除测试用例；
- **Findings**：
  - `audioFilePath` 契约变化（`null` = 模拟 / 真实路径 = 真实录音 / 非法路径 = Repository 拒绝）与 MVP 既有契约兼容，不破坏既有 23 条列表测试与 28 条详情测试；
  - Drift schema 迁移策略明确 schemaVersion 1 → 2、新增字段默认值、旧记录 `audioFilePath = null` 保留；
  - 旧模拟记录迁移策略（不自动转换 + UI 标识 + 不删除旧记录）清楚；
  - 删除记录与文件清理事务边界（先数据库后文件 + 文件删除失败不回滚）清楚；
  - 数据库与文件不一致场景（孤儿文件 / 文件丢失）覆盖；
  - 测试数据库与真机文件路径隔离（`NativeDatabase.memory()` + `InMemoryAudioFileStorageService` + mock `getApplicationDocumentsDirectory()`）明确；
- **Blockers**：无
- **Non-blocking Suggestions**：
  - §6.2 新增字段列表标注为"候选"，最终字段列表待 T032 任务敲定；建议 T032 任务输出时附带"字段决策矩阵"；
  - 文件命名规则 §4.3 给出倾向（按日期分目录 + `<recordId>.m4a`），但 §4.3 末段也标注"最终决策在 T028 实现时由 `04-audio-engineer` + `06-local-data-engineer` 联签"，保留灵活度；
- **Approval**：**Approved**

#### 4.5.3 Compliance Reviewer（08-compliance-reviewer）只读审查

- **Reviewer Role**：`08-compliance-reviewer`
- **Scope Reviewed**：`docs/dev/REAL_AUDIO_MVP_SDD.md` 全文（重点 §1.1-§1.2 / §2.2 / §3 整章）；`docs/dev/REAL_AUDIO_MVP_TDD.md` §3 Manual Acceptance Checklist（MA-16 / MA-17 / MA-18）/ §4 Regression Matrix（RR-13 / RR-16-RR-18）；`docs/dev/TECH_DEBT.md` 既有 TD-007 / 新增 TD-012
- **Evidence Checked**：
  - `git ls-files android/key.properties` / `*.jks` / `*.keystore` / `build/app/outputs/**` 四项均返回空；
  - `git tag -n1 --list v0.1.0-mvp` 仍指向 `d49ce4b`、`git tag -n1 --list v1.0.0-release` 仍指向 `703d2aa`；
  - 全文搜索两份新文档确认未出现 `key.properties` 内容 / 密码 / keystore 内容 / 用户目录 keystore 绝对路径；
  - §3.1 - §3.6 权限与隐私设计完整：`RECORD_AUDIO` 申请时机（用户首次点击"开始真实录音"）+ 永久拒绝处理（引导系统设置）+ 一次性拒绝处理（App 内重试）+ 申请弹窗不可定制；
  - §3.3 无 `INTERNET` 原则：明确不声明 `INTERNET` + 录音文件仅存 App 私有目录 + 不引入任何联网 SDK；
  - §3.5 iOS `NSMicrophoneUsageDescription` 文案预留；
  - §3.6 隐私政策补充条款（数据收集 / 麦克风权限用途 / 录音存储位置 / 录音上传 / 用户权利 / 备份 / 第三方）共 7 项；
  - §3.7 用户删除记录与音频文件清理（数据库先删 + 文件再删 + 文件删除失败 SnackBar 提示）；
- **Findings**：
  - 权限拒绝与永久拒绝降级设计有专门段落与测试用例（TC-P02 / TC-P03 / TC-P04 / TC-P05）；
  - 无 `INTERNET` 原则保留（SDD §3.3 + TDD TC-CP02 + Regression RR-13）；
  - iOS `NSMicrophoneUsageDescription` 文案预留（SDD §3.5）；
  - 隐私政策补充条款完整（SDD §3.6 + TECH_DEBT TD-012 由 T033 任务执行）；
  - 未声称真实录音已实现、未声称麦克风权限已加入、未声称应用商店已提交；
  - 未读取 `key.properties` 内容、未记录密码 / keystore 内容 / 用户目录 keystore 绝对路径；
  - 未 push、未 Tag、未 amend / rebase / reset --hard；
- **Blockers**：无
- **Non-blocking Suggestions**：
  - 真实音频阶段文案（§2.2 / §2.3 / §3.6）当前为示例措辞，最终文案由 T033 UI 文案任务校对；本任务保留设计意图即可；
  - 隐私说明页面更新由 T033 任务执行，文案变更需同步 `docs/PRD.md` §13.3（如有需要）；
- **Approval**：**Approved**

#### 4.5.4 QA Reviewer（07-qa-reviewer）只读审查

- **Reviewer Role**：`07-qa-reviewer`
- **Scope Reviewed**：`docs/dev/REAL_AUDIO_MVP_TDD.md` 全文（重点 §1 Test Strategy / §2 Test Matrix / §3 Manual Acceptance Checklist / §4 Regression Matrix / §5 Test Gaps / §7 Test Reporting）；`docs/dev/REAL_AUDIO_MVP_SDD.md` §8 State Machine / §9 Error Handling；既有 `docs/dev/AGENT_REVIEW_TEMPLATE.md` QA Checklist
- **Evidence Checked**：
  - `flutter analyze` `No issues found!`、`flutter test` `All tests passed!`（407 tests passed）；
  - §2 Test Matrix 实际列出 31 条自动化测试用例（TC-P01~P05 / TC-R01~R06 / TC-PB01~PB04 / TC-S01~S04 / TC-D01~D03 / TC-M01~M04 / TC-F01~F03 / TC-LR01~LR02 / TC-SM01~SM03 / TC-CP01~CP03）+ 1 条真机验收用例（TC-DA01），共 32 条；
  - §3 Manual Acceptance Checklist 22 项真机手工验收项；
  - §4 Regression Matrix 20 项不能破坏既有 MVP / Release 工程化；
  - §5 Test Gaps 9 项明确自动测试无法验证的边界（真实麦克风输入 / 真实音频播放质量 / iOS 验收 / 多设备 / 永久拒绝弹窗 / 后台切换 / 系统设置跳转 / 来电中断 / 蓝牙耳机切换）；
  - §7 Test Reporting 明确禁止写法（"测试通过"无具体数字、"全部通过"无 flutter test 输出、"自动化验证真实录音"等）；
- **Findings**：
  - 30+ 测试用例覆盖完整（实际 31 条自动化 + 1 条真机验收）；
  - 真机手工验收清单完整（22 项），来源标注明确（User confirmed / aapt / adb）；
  - 自动测试与手工测试边界清楚（Test Gaps §5 明确隔离）；
  - 回归矩阵覆盖既有 MVP / Release 工程化（20 项）；
  - 未把"将引入"写成"已实现"（所有"将引入 / 将设计"语句均为设计候选而非已实现声明）；
  - 既有 407 测试数保持不变（基线 407，新增 / 更新 / 删除 0 / 0 / 0）；
- **Blockers**：无
- **Non-blocking Suggestions**：
  - §2 Test Matrix 当前按场景分类，建议 T035 任务把 30+ 测试用例映射到具体测试文件路径（如 `test/features/recording/application/recording_practice_controller_real_audio_test.dart`）；
  - §5 Test Gaps 中"多设备 / 多 Android 版本 / 多厂商 ROM 适配"由 T036 单台真机验收基线出发，多设备矩阵由 GPT 首席架构师决定是否扩展；
- **Approval**：**Approved**

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

### 5.1 Release 工程化阶段小结（T019-T024）

> 本节是 T019-T024 阶段结束时的**阶段级**复盘，由 T024 任务追加。汇总多 Agent 协作机制在该阶段的有效性与局限，明确下一阶段真实音频应重点启用的 Reviewer 角色。

#### 5.1.1 阶段背景

- 阶段范围：Android Release 工程化（T019 设计 / T020 签名 + 三条 FIX / T021 重启构建 / T021A 激活多 Agent / T022 产物静态验证 / T022A 命令纪律事件 / T023 真机安装 + 用户冒烟 / T024 文档收口）
- 阶段产出：Release APK 58,558,487 bytes / AAB 57,332,407 bytes 构建成功 + 单台真机 18 项用户冒烟全部 Passed + 静态验证全部通过 + 命令纪律严格执行

#### 5.1.2 多 Agent 协作价值评估

- **整体协作价值**：以 Medium 为主，T023 阶段达到 High；T024 阶段为 Medium（属于文档收口与流程合规验证，证据已知，偏规范性审查）
- **形式主义风险**：T022 与 T024 阶段 Reviewer 主要做规范性检查与证据一致性核对，未拦截真实 Bug；这是该类任务（静态校验 / 文档收口）的本质，但需明确记录，避免协作价值被误读为"无价值"
- **真实拦截案例**：T022A 命令纪律事件回填由 GPT 复审触发，属于"流程合规性拦截"，证明协作机制对流程纪律有约束力

#### 5.1.3 Reviewer 实际产出

| 阶段任务 | Primary Agent | Reviewer | Reviewer 实际产出 | 协作价值 |
| --- | --- | --- | --- | --- |
| T022 产物静态验证 | 07-qa-reviewer | 02-flutter-architect + 08-compliance-reviewer | 两个 Reviewer 确认脚本自实现 SHA-256 与 `certutil` 交叉验证一致、确认 `key.properties` 已 ignore 且未跟踪、产物未被 git 跟踪、文档未泄露敏感信息 | Medium（静态校验，元信息已知，未发现重大缺陷） |
| T022A 命令纪律事件 | 07-qa-reviewer | 00-chief-architect + 08-compliance-reviewer | 两个 Reviewer 确认 T022 主结论保持不变、T022 Scorecard 仅新增违规字段与备注、Scorecard 协作价值未降级、未把违规写成密钥泄露 / 产物失败 / T022 不通过 | Medium（仅补录流程事件，无新功能交付） |
| T023 真机验收 | 07-qa-reviewer | 03-mobile-ui-engineer + 08-compliance-reviewer | Mobile UI Reviewer 确认 18 项覆盖完整性 + 大字体 / 溢出检查独立成项 + 模拟录音文案与 SDD/TDD 一致；Compliance Reviewer 在签名不兼容的关键高风险点上独立审查了用户授权证据链（"确认卸载，允许继续"） | High（真实拦截了"Agent 替用户勾选通过"的潜在形式主义风险） |
| T024 文档收口 | 00-chief-architect | 07-qa-reviewer + 08-compliance-reviewer | QA Reviewer 确认证据来源、未夸大未完成能力、407 测试数一致；Compliance Reviewer 确认未读取敏感信息、未声称未实现能力、未 push / Tag | Medium（文档收口，证据已知，偏规范性审查） |

#### 5.1.4 形式主义 Reviewer 识别

- **当前 9 个 Reviewer 角色**（`00-chief-architect` / `07-qa-reviewer` / `08-compliance-reviewer` + 领域 Reviewer）在 Release 工程化阶段实际被启用并产出有据审查的角色主要是 `00-chief-architect`（Chief Architect 范围守卫）/ `02-flutter-architect`（T022 Flutter 架构复审）/ `03-mobile-ui-engineer`（T023 UI 复审）/ `07-qa-reviewer`（T022 / T022A / T023 / T024 Primary）/ `08-compliance-reviewer`（T022 / T022A / T023 / T024 合规复审）。
- **`01-product-manager` / `04-audio-engineer` / `05-music-domain-expert` / `06-local-data-engineer`** 在本阶段未被启用，原因与本阶段范围（签名 / 构建 / 产物 / 真机验收）一致，不构成形式主义。
- 长期无产出的 Reviewer 角色清理规则见 §6：本阶段无须清理；进入真实音频阶段后需重新评估 `04-audio-engineer` 的 Primary 与 Reviewer 双重身份。

#### 5.1.5 下一阶段真实音频 Reviewer 重点启用建议

- **音频架构（依赖选型 / 权限方案）**：Primary = `04-audio-engineer`；Required Review = `02-flutter-architect`（依赖与架构边界）+ `08-compliance-reviewer`（权限与隐私）+ `07-qa-reviewer`（测试覆盖）
- **音频文件生命周期（本地存储 / 清理 / 删除）**：Primary = `04-audio-engineer`；Required Review = `06-local-data-engineer`（Drift schema 升级 / Repository 契约 / 迁移）+ `07-qa-reviewer`（迁移测试）+ `08-compliance-reviewer`（用户可删除 / 不静默占用空间）
- **权限与隐私（`RECORD_AUDIO` 声明 / 拒绝降级 / 隐私政策）**：Primary = `08-compliance-reviewer`；Required Review = `04-audio-engineer`（权限流程落地）+ `07-qa-reviewer`（拒绝降级测试）+ `02-flutter-architect`（Manifest 边界）
- **UI 录音体验（页面 / Controller / Wave / 进度）**：Primary = `03-mobile-ui-engineer`；Required Review = `04-audio-engineer`（音频服务边界）+ `07-qa-reviewer`（异常降级测试）
- **真机弹唱验收**：Primary = 用户本人（真机操作主导）；Required Review = `07-qa-reviewer` + `04-audio-engineer` + `08-compliance-reviewer`；**绝不**允许 Agent 代写"通过"
- **数据生命周期（录音文件 / 备份 / 删除）**：Primary = `06-local-data-engineer`；Required Review = `04-audio-engineer` + `08-compliance-reviewer` + `07-qa-reviewer`

> 详细路由见 `docs/dev/AGENT_ROUTING_MATRIX.md` §6 Future Audio MVP Routing；本节仅作为 Release 工程化阶段结束时的"下一阶段 Reviewer 重点启用"提示，不重写既有路由表。

#### 5.1.6 真实音频阶段 SDD/TDD 设计校准（T025 追加）

> 本节是 T025 在 §5.1.5 基础上**校准**真实音频阶段 Reviewer 重点启用建议，对应 `docs/dev/REAL_AUDIO_MVP_SDD.md` §10 Rollout Plan 与 `docs/dev/REAL_AUDIO_MVP_TDD.md` §2 Test Matrix。不重写既有路由表。

- **T026 Dependency Research / Spike**：Primary = `04-audio-engineer`；Required Review = `02-flutter-architect`（依赖与架构边界）+ `07-qa-reviewer`（兼容性测试覆盖）；输出 ADR 形式的依赖决策矩阵，不直接修改 `pubspec.yaml`
- **T027 Permission and Manifest Design**：Primary = `04-audio-engineer`；Required Review = `02-flutter-architect`（Manifest 边界 + Android 三处清单检查）+ `08-compliance-reviewer`（权限文案 + 隐私说明更新）；**不**声明 `INTERNET` / **不**声明 `RECORD_AUDIO` 之外的任何业务权限
- **T028 Audio File Storage Service**：Primary = `06-local-data-engineer`；Required Review = `04-audio-engineer`（存储目录 + 命名规则）+ `07-qa-reviewer`（文件存在性测试 + 删除测试）
- **T029 Real Recorder Service**：Primary = `04-audio-engineer`；Required Review = `02-flutter-architect`（Riverpod Provider 边界）+ `07-qa-reviewer`（record mock 策略 + 错误恢复测试）
- **T030 Real Playback Service**：Primary = `04-audio-engineer`；Required Review = `02-flutter-architect`（Riverpod Provider 边界）+ `07-qa-reviewer`（just_audio mock 策略 + 文件丢失测试）
- **T031 Recording Controller Real Audio State Machine**：Primary = `04-audio-engineer`；Required Review = `02-flutter-architect`（架构边界）+ `07-qa-reviewer`（状态机测试 + 防抖测试）+ `03-mobile-ui-engineer`（UI 状态切换一致性）
- **T032 Practice Record Schema Migration**：Primary = `06-local-data-engineer`；Required Review = `02-flutter-architect`（schema 升级策略 + 迁移测试）+ `07-qa-reviewer`（旧数据保留测试 + 默认值测试）+ `08-compliance-reviewer`（`audioFilePath` 契约变化 + 旧记录兼容）
- **T033 UI Copy and Permission UX**：Primary = `03-mobile-ui-engineer`；Required Review = `04-audio-engineer`（音频服务边界）+ `07-qa-reviewer`（权限文案 + 异常文案测试）+ `08-compliance-reviewer`（隐私说明更新 + 文案不误导）
- **T034 Delete and File Cleanup Integration**：Primary = `06-local-data-engineer`；Required Review = `04-audio-engineer`（文件删除流程）+ `07-qa-reviewer`（删除状态机 + SnackBar 测试）
- **T035 Automated Tests**：Primary = `07-qa-reviewer`；Required Review = `04-audio-engineer`（音频相关测试覆盖）+ `06-local-data-engineer`（Repository / Migration 测试覆盖）+ `02-flutter-architect`（测试架构合理性）
- **T036 Android Real Device Audio Acceptance**：Primary = 用户本人（真机操作主导）；Required Review = `07-qa-reviewer` + `04-audio-engineer` + `08-compliance-reviewer`；**绝不**允许 Agent 代写"通过"；验收模板基于 `REAL_AUDIO_MVP_TDD.md` §3 Manual Acceptance Checklist
- **T037 Release Docs Update**：Primary = `00-chief-architect`；Required Review = `07-qa-reviewer`（范围 / 格式）+ `08-compliance-reviewer`（合规）

**音频 Reviewer 必须作为 Primary 或 Required Review**（T026-T037 每个子任务至少一名音频相关 Reviewer）：T026 / T029 / T030 / T031 由 `04-audio-engineer` 主导；T027 / T033 由 `04-audio-engineer` 任 Required Review。

**Compliance Reviewer 必须审查权限与隐私**：T027 / T033 / T036 / T037 必含；T032 字段契约变化（含 `recordingMode`）时必含。

**Local Data Reviewer 必须审查文件路径与数据库一致性**：T028 / T032 / T034 必含；T036 删除流程验收时必含。

**QA Reviewer 必须审查真机录音验收**：T035 / T036 必含；T026 兼容性验证必含；其余任务作为规范性审查 Required Review。

**Flutter Architect 必须审查依赖和平台边界**：T026 / T027 / T029 / T030 / T031 / T032 必含；T035 测试架构合理性必含。

> 详细路由见 `docs/dev/AGENT_ROUTING_MATRIX.md` §6 Future Audio MVP Routing；T026-T037 任务边界以 GPT 首席架构师独立 Prompt 为准。

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
