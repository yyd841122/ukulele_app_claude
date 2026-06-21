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

### 4.6 T026 Scorecard（真实音频依赖研究 Spike）

| 字段 | 值 |
| --- | --- |
| Task ID | `T026_REAL_AUDIO_DEPENDENCY_RESEARCH_SPIKE` |
| Primary Agent | `04-audio-engineer`（依赖候选评估 / 版本兼容性 / 平台要求 / 风险与推荐组合主导） |
| Review Agents | `02-flutter-architect`（Flutter / Dart / Android 工程边界 / pubspec 未修改 / 后续接入路径审查）、`08-compliance-reviewer`（权限与隐私 / 无 INTERNET 原则 / 官方文档引用 / 未完成能力表述 / 敏感文件边界审查）、`07-qa-reviewer`（Spike 结论可验证性 / 后续测试策略 / T027-T036 路径审查）、`06-local-data-engineer`（path_provider / 文件路径 / 后续 Drift 记录与文件生命周期一致性审查） |
| High Risk Areas | 依赖选型（`record` 7.1.0 / `just_audio` 0.10.5 / `permission_handler` 12.0.3 / `path_provider` 2.1.6 / `audio_session` 0.2.3 / `audioplayers` 6.7.1 / `flutter_sound` 9.30.0 候选评估）、官方文档准确性（Context7 + pub.dev WebFetch 双向验证）、权限影响（`RECORD_AUDIO` 加入时机 / `INTERNET` 不得声明 / iOS `NSMicrophoneUsageDescription` 预留）、平台兼容（`minSdk = 24` / `compileSdk = 36` / Flutter 3.44.2 / Dart 3.12.2 / JDK 17）、未完成能力误写（不得把"Spike 完成"写成"已添加依赖" / 不得把候选版本写成已写入 `pubspec.yaml`）、敏感文件边界（不读取 `key.properties` 内容 / 不记录密码 / keystore 内容 / 用户目录 keystore 绝对路径）、命令纪律（单条命令 / 无管道 / 无重定向 / 无 `&&` / 无分号 / 无复合）、越权（push / Tag / amend / rebase / reset --hard 全部禁止 / 不修改 `pubspec.yaml` / `pubspec.lock` / AndroidManifest.xml / Drift schema） |
| Blockers Found | 0（四个 Reviewer 均按 `AGENT_REVIEW_TEMPLATE.md` 只读审查，未发现阻断项；详见下文 §4.6.1 ~ §4.6.4 Reviewer 报告段与 `TASK_LEDGER.md` T026 条目 Reviewer 报告段） |
| Blockers Valid | 0（无 Blockers） |
| Fix Commits Required | 0 |
| Tests Passed | 407（基线保持；新增 / 更新 / 删除 0 / 0 / 0；本任务不新增测试代码、不运行 build_runner、不构建 APK / AAB、不修改任何依赖） |
| Scope Clean | Yes（仅新建 `docs/dev/REAL_AUDIO_DEPENDENCY_SPIKE.md`；仅修改 `docs/dev/TASK_LEDGER.md` 追加 T026 条目 + `docs/dev/TECH_DEBT.md` 校准 TD-007 / TD-010 + 新增 TD-013 + `docs/dev/AGENT_QUALITY_METRICS.md` §4.6 追加 T026 Scorecard） |
| Command discipline violation | **No**（本任务全程命令均为单条命令：`git status --short` / `git branch --show-current` / `git rev-parse --short HEAD` / `git log -1 --oneline` / `git remote -v` / `git tag -n1 --list v0.1.0-mvp` / `git tag -n1 --list v1.0.0-release` / `git rev-parse --short v0.1.0-mvp^{commit}` / `git rev-parse --short v1.0.0-release^{commit}` / `git ls-files ...` / `git grep "7038d2aa"` / `flutter analyze` / `flutter test` / `Read` / `Write` / `Edit` / Context7 `mcp__context7__resolve-library-id` / `mcp__context7__query-docs` / WebFetch 等只读或允许写命令；无管道、无重定向、无 `&&`、无分号、无复合命令） |
| Sensitive Files Checked | Yes（`git ls-files android/key.properties` / `*.jks` / `*.keystore` / `build/app/outputs/flutter-apk/app-release.apk` / `build/app/outputs/bundle/release/app-release.aab` 五项均返回空；`v0.1.0-mvp` 仍指向 `d49ce4b` 未变；`v1.0.0-release` 仍指向 `703d2aa` 未变；`git grep "7038d2aa"` 0 命中，笔误检查通过；新文档未记录密码 / keystore 内容 / 用户目录 keystore 绝对路径） |
| Build Artifacts Tracked | No（`git ls-files build/app/outputs/**` 返回空） |
| Dependency Modified | **No**（`pubspec.yaml` / `pubspec.lock` 未被修改；`record` / `just_audio` / `permission_handler` / `audio_session` / `audioplayers` / `flutter_sound` 均未引入；仅 `path_provider ^2.1.6` 已存在） |
| Permissions Modified | **No**（`AndroidManifest.xml` 三处清单均未修改；`RECORD_AUDIO` / `INTERNET` / 其他权限均未声明） |
| Real Audio Implementation Started | **No**（仅研究候选；`AudioRecorderService` / `AudioPlaybackService` / `PermissionService` / `AudioFileStorageService` 均未实现；`RECORD_AUDIO` 未申请） |
| Final Approval | 待 GPT 复审 |
| Collaboration Value | **Medium**（四个 Reviewer 均按模板只读审查并给 Approved；本任务为依赖研究 / Spike，证据来自 Context7 + pub.dev WebFetch 双向验证，未发现重大缺陷；Reviewer 主要做规范性检查 + 范围守卫 + 依赖选型完整性核对 + 未完成能力表述隔离 + 敏感信息未泄露确认 + 路径与文件生命周期一致性 + 测试策略隔离边界确认，未拦截真实 Bug；与 T022 / T024 / T025 类似属于"偏流程化 + 文档设计审查"，但仍是真实音频阶段必经的"依赖选型门禁"，避免后续 T029 / T030 在无 Spike 共识下启动；协作价值以"完整 Context7 + WebFetch 双向验证 + 7 个候选评估 + 推荐组合 + 风险识别 + 后续 T027-T037 任务依赖映射"为主要产出） |
| Notes | Flutter Architect Reviewer 重点确认：① `REAL_AUDIO_DEPENDENCY_SPIKE.md` §3 Candidate Evaluation Table 列出 7 个候选（`record` / `just_audio` / `audioplayers` / `flutter_sound` / `permission_handler` / `path_provider` / `audio_session`）的版本 / 优点 / 风险 / Android / iOS / 额外配置 / 测试影响 / MVP 推荐 / Next action；② §4 Recommended Dependency Direction 给出推荐组合（`record ^7.1.0` + `just_audio ^0.10.5` + `permission_handler ^12.0.3` + `path_provider ^2.1.6`），但**未**修改 `pubspec.yaml` / `pubspec.lock` / `AndroidManifest.xml`；③ 推荐组合适配当前 Flutter 3.44.2 / Dart 3.12.2 / Android `minSdk = 24` / `compileSdk = 36` 工程；④ §6 Build / Platform Risk 覆盖 Gradle / AGP / Kotlin / JDK / Native plugin / R8 / iOS / Windows / CI 全部 8 类风险；⑤ §9 Follow-up Tasks 映射 T027-T037，每个任务明确依赖引入节奏（**不**合并 commit）；⑥ §10 References 完整列出 Context7 Library IDs + pub.dev URL；⑦ `pubspec.yaml` 当前已包含 `path_provider ^2.1.6` 但**未**包含其他 5 个候选；⑧ `record` 7.1.0 `AudioEncoder.aacLc` 重命名需要在 T029 隔离 spike 中实测。Compliance Reviewer 重点确认：① 未读取 `android/key.properties` 内容、未记录密码 / keystore 内容 / 用户目录 keystore 绝对路径；② 未声称真实录音已实现、未声称麦克风权限已加入、未声称应用商店已提交；③ §5 Permission Impact 准确表述（依赖本身**不等于**声明 `RECORD_AUDIO`、T027 必须修改三处清单、`INTERNET` 不得声明）；④ iOS `NSMicrophoneUsageDescription` 文案已在 SDD §3.5 预留，T026 不重复声明；⑤ 隐私政策更新由 T033 任务执行，本任务**不**写入用户隐私；⑥ 真实音频阶段无 INTERNET 原则保留（`just_audio` 仅使用 file:// 路径播放本地 m4a）；⑦ `git grep "7038d2aa"` 0 命中，仓库中无 T025 报告笔误；⑧ 未 push、未 Tag、未 amend / rebase / reset --hard；⑨ `audio_session` 仅作 fallback，**未**进入 MVP 主路径。Local Data Reviewer 重点确认：① `path_provider` 已存在（`^2.1.6`）；② T028 实现 `AudioFileStorageService` 时路径命名候选 `<docs>/recordings/<yyyy-MM-dd>/<recordId>.m4a`，与既有 Drift 数据库路径（默认 `<docs>` 子目录）需在 T028 决定；③ `path_provider` 与 `getApplicationDocumentsDirectory()` 卸载自动清除行为与 SDD §3.7 一致；④ 测试中 mock `getApplicationDocumentsDirectory()` 返回 `Directory.systemTemp.createTempSync()` 路径物理隔离；⑤ T028 / T032 / T034 任务必须由 Local Data Reviewer 重点审查（与既有 §5.1.5 真实音频 Reviewer 重点启用建议一致）。QA Reviewer 重点确认：① §7 Testing Impact 完整覆盖 7 个测试层（pure unit / controller / repository / drift migration / file storage / permission behavior / widget）；② §7.2 真实麦克风隔离边界明确（自动测试**不**触发真实麦克风）；③ §7.3 T035 自动测试设计原则强调 fake service 注入；④ §9 Follow-up Tasks 完整映射 T027-T037 共 11 个任务；⑤ T036 真机验收必须由用户本人完成，Agent **不**得代写"通过"；⑥ T035 测试数 ≥ 既有 407 不得下降；⑦ §8 Decision 七个候选均有明确 Decision（4 个 Recommended for MVP / 1 个 Recommended as fallback / 2 个 Not recommended for MVP）；⑧ §2 Research Sources 完整透明（Context7 + WebFetch 双向验证 + 查询限制披露）；⑨ `git grep "7038d2aa"` 0 命中；本任务全程命令纪律严格执行，未触发 T022A 记录的命令纪律违规模式（管道 / 重定向 / 输出截断 helper / 复合），与 T023 / T024 / T025 表现一致；详见 `docs/dev/TASK_LEDGER.md` T026 条目 + `docs/dev/REAL_AUDIO_DEPENDENCY_SPIKE.md` 全文 |

#### 4.6.1 Flutter Architect Reviewer（02-flutter-architect）只读审查

- **Reviewer Role**：`02-flutter-architect`
- **Scope Reviewed**：`docs/dev/REAL_AUDIO_DEPENDENCY_SPIKE.md` 全文（重点 §3 Candidate Evaluation Table / §4 Recommended Dependency Direction / §5 Permission Impact / §6 Build Platform Risk / §7 Testing Impact / §9 Follow-up Tasks）；既有 `pubspec.yaml` + `docs/TECH_STACK.md` §6.1 / §7 / §10 + `docs/ARCHITECTURE.md` §3 / §7
- **Evidence Checked**：
  - `git status --short` 工作树（Commit 前）显示仅有允许文件改动；
  - `git diff --check` 无空白错误；
  - `pubspec.yaml` 未被修改（既有版本号 `1.0.0+2` / `path_provider ^2.1.6` 不变）；
  - `pubspec.lock` 未被修改；
  - `AndroidManifest.xml` 未被修改（既有 `RECORD_AUDIO` 未声明不变）；
  - `docs/dev/REAL_AUDIO_DEPENDENCY_SPIKE.md` §3.1 - §3.7 候选评估表完整列出 7 个候选的版本 / 优点 / 风险 / Android / iOS / 额外配置 / 测试影响 / MVP 推荐 / Next action；
  - §4.1 推荐组合 `record ^7.1.0` + `just_audio ^0.10.5` + `permission_handler ^12.0.3` + `path_provider ^2.1.6`（已存在）覆盖 MVP 全部需求；
  - §6 Build / Platform Risk 覆盖 8 类风险（Gradle / AGP / Kotlin / Android minSdk / Java JDK / Native plugin / R8 / iOS / Windows / CI）；
  - §9 Follow-up Tasks 完整映射 T027-T037 共 11 个任务，每个任务明确依赖引入节奏；
  - §10 References 列出 Context7 10 个 Library IDs + 7 个 pub.dev URL；
- **Findings**：
  - 所有依赖仅作为研究候选，未直接写入 `pubspec.yaml` / `pubspec.lock` / `AndroidManifest.xml`；
  - 推荐组合适配当前 Flutter 3.44.2 / Dart 3.12.2 / Android `minSdk = 24` / `compileSdk = 36` / JDK 17 / Gradle 8.7 / AGP 8.6.0；
  - `record` 7.1.0 与既有 `TECH_STACK.md` §6.1 / `REAL_AUDIO_MVP_SDD.md` §5.1 候选决策一致；`just_audio` 0.10.5 与 §6.1 / §5.3 一致；`permission_handler` 12.0.3 与 §6.1 / §5.5 一致；
  - `audio_session` 0.2.3 仅作 fallback，**未**进入 MVP 主路径，符合 MVP 简单性原则；
  - `audioplayers` 6.7.1 / `flutter_sound` 9.30.0 既有决策排除（与 `TECH_STACK.md` §10 + `REAL_AUDIO_MVP_SDD.md` §5.2 / §5.4 一致）；
  - 依赖引入节奏清晰（T027 / T029 / T030 三个独立任务，**不**合并 commit）；
  - 12 个后续任务边界清晰，依赖关系正确（T026 → T027 → T028 → T029 → T030 → T031 → T032 → T033 → T034 → T035 → T036 → T037）；
- **Blockers**：无
- **Non-blocking Suggestions**：
  - `pubspec.yaml` 当前**未声明** `environment.flutter` 字段；如未来 Flutter SDK 升级需锁定版本，建议 T027 任务执行前评估是否补充 `environment.flutter: ">=3.44.0 <4.0.0"`；
  - `record` 7.x `AudioEncoder.aacLc` 重命名（4.x 引入）与既有命名差异需在 T029 隔离 spike 中实测确认；
- **Approval**：**Approved**

#### 4.6.2 Compliance Reviewer（08-compliance-reviewer）只读审查

- **Reviewer Role**：`08-compliance-reviewer`
- **Scope Reviewed**：`docs/dev/REAL_AUDIO_DEPENDENCY_SPIKE.md` 全文（重点 §1.4 关键事实 / §4.1 推荐组合 / §5 Permission Impact / §6 Build Platform Risk / §9 Follow-up Tasks）；既有 `docs/dev/REAL_AUDIO_MVP_SDD.md` §3 Permission and Privacy + `docs/dev/TECH_DEBT.md` TD-007 / TD-010 / TD-011 / TD-012 / TD-013
- **Evidence Checked**：
  - `git ls-files android/key.properties` / `*.jks` / `*.keystore` / `build/app/outputs/**` 五项均返回空；
  - `git tag -n1 --list v0.1.0-mvp` 仍指向 `d49ce4b`、`git tag -n1 --list v1.0.0-release` 仍指向 `703d2aa`；
  - `git grep "7038d2aa"` 0 命中（笔误检查通过）；
  - 全文搜索 `REAL_AUDIO_DEPENDENCY_SPIKE.md` 确认未出现 `key.properties` 内容 / 密码 / keystore 内容 / 用户目录 keystore 绝对路径；
  - §5.1 明确表述"引入依赖**不等于**声明 `RECORD_AUDIO`"；
  - §5.4 无 INTERNET 原则保留（`just_audio` 仅使用 file:// 路径）；
  - §5.5 隐私政策更新由 T033 任务执行；
  - §5.6 真实音频阶段合规清单完整 7 项（不读取 key.properties / 不记录密码 / 不申请 RECORD_AUDIO / 不申请 INTERNET / 不声称真实录音已实现 / 不声称麦克风权限已加入 / 不声称应用商店已提交）；
- **Findings**：
  - 引入依赖与权限声明关系表述准确（依赖本身**不**等于 `RECORD_AUDIO` 声明，需 T027 任务显式写入 AndroidManifest.xml 三处清单）；
  - 无 INTERNET 原则保留（`just_audio` 本项目仅播放本地 m4a，不声明 `INTERNET`）；
  - iOS `NSMicrophoneUsageDescription` 文案已在 `REAL_AUDIO_MVP_SDD.md` §3.5 预留，T026 **不**重复声明；
  - 隐私政策更新责任清晰归属 T033 任务；
  - 未声称真实录音已实现、未声称麦克风权限已加入、未声称应用商店已提交；
  - 未读取 `key.properties` 内容、未记录密码 / keystore 内容 / 用户目录 keystore 绝对路径；
  - 未 push、未 Tag、未 amend / rebase / reset --hard；
  - `git grep "7038d2aa"` 0 命中，仓库中无 T025 报告笔误；
- **Blockers**：无
- **Non-blocking Suggestions**：
  - `audio_session` 0.2.3 暂不引入的决策合理；如 T036 真机验收发现音频焦点冲突 / 来电中断问题，由 GPT 首席架构师评估是否引入；本任务**不**写入 `pubspec.yaml`；
  - 隐私政策更新由 T033 任务执行，本任务仅提供设计原则；
- **Approval**：**Approved**

#### 4.6.3 QA Reviewer（07-qa-reviewer）只读审查

- **Reviewer Role**：`07-qa-reviewer`
- **Scope Reviewed**：`docs/dev/REAL_AUDIO_DEPENDENCY_SPIKE.md` 全文（重点 §2 Research Sources / §3 Candidate Evaluation Table / §7 Testing Impact / §8 Decision / §9 Follow-up Tasks）；既有 `docs/dev/REAL_AUDIO_MVP_TDD.md` §1 Test Strategy / §2 Test Matrix / §5 Test Gaps + `docs/dev/AGENT_REVIEW_TEMPLATE.md` QA Checklist
- **Evidence Checked**：
  - `flutter analyze` `No issues found! (ran in 3.5s)`、`flutter test` `All tests passed!`（407 tests passed）；
  - §2 Research Sources 完整透明（Context7 + WebFetch 双向验证 + 查询限制披露）；
  - §3 Candidate Evaluation Table 列出 7 个候选的测试影响；
  - §7 Testing Impact 完整覆盖 7 个测试层（pure unit / controller / repository / drift migration / file storage / permission behavior / widget）；
  - §7.2 真实麦克风隔离边界明确（自动测试**不**触发真实麦克风，真实音频输入质量由 T036 真机用户验收）；
  - §7.3 T035 自动测试设计原则强调 fake service 注入 + 测试数 ≥ 既有 407；
  - §8 Decision 7 个候选均有明确 Decision；
  - §9 Follow-up Tasks 完整映射 T027-T037 共 11 个任务；
  - `git grep "7038d2aa"` 0 命中；
- **Findings**：
  - Spike 结论可验证（Context7 + pub.dev WebFetch 双向验证，最新稳定版本与平台要求均有官方来源）；
  - Testing Impact 覆盖 fake service / widget /真机边界（T035 自动测试 + T036 真机验收 + T036 真机用户确认音质）；
  - 自动测试**不**依赖真实麦克风（与 `REAL_AUDIO_MVP_TDD.md` §5 Test Gaps 9 项一致）；
  - 后续 T035 / T036 验收路径清楚（fake service + Widget / Controller / Repository / Drift migration + T036 用户本人真机）；
  - **未**把 Spike 写成实现完成（`§1 Document Status` 明确"依赖研究完成，未实现"；§4.1 推荐方向**不**修改 `pubspec.yaml`）；
  - 既有 407 测试数保持不变（基线 407，新增 / 更新 / 删除 0 / 0 / 0）；
  - `git grep "7038d2aa"` 0 命中，仓库中无 T025 报告笔误；
- **Blockers**：无
- **Non-blocking Suggestions**：
  - §7 Testing Impact 中 7 个测试层与 `REAL_AUDIO_MVP_TDD.md` §1.1 一致，建议 T035 任务把 30+ 测试用例映射到具体测试文件路径；
  - T036 真机验收必须由用户本人完成，Agent **不**得代写"通过"（与既有 `REAL_AUDIO_MVP_TDD.md` §3 22 项 Manual Acceptance Checklist + §5 Test Gaps 一致）；
- **Approval**：**Approved**

#### 4.6.4 Local Data Reviewer（06-local-data-engineer）只读审查

- **Reviewer Role**：`06-local-data-engineer`
- **Scope Reviewed**：`docs/dev/REAL_AUDIO_DEPENDENCY_SPIKE.md` 全文（重点 §3.6 path_provider / §4.1 推荐组合 / §9 Follow-up Tasks）；既有 `docs/dev/REAL_AUDIO_MVP_SDD.md` §4 Audio File Lifecycle / §6 Data and Schema Design + `docs/dev/REAL_AUDIO_MVP_TDD.md` §2.6 Data Migration / §2.7 Filesystem / §2.8 旧模拟记录兼容
- **Evidence Checked**：
  - `pubspec.yaml` 当前已包含 `path_provider ^2.1.6`（T005 阶段已引入）；
  - §3.6 path_provider 推荐版本 `^2.1.6` 与当前 `pubspec.yaml` 完全一致，**无需**新增依赖；
  - §4.1 推荐组合中 `path_provider` 已存在标记为"已存在"；
  - §9 Follow-up Tasks 明确 T028 由 `06-local-data-engineer` 实现 `AudioFileStorageService`；
  - T028 / T032 / T034 三个 Local Data 主导任务在既有 §5.1.5 真实音频 Reviewer 重点启用建议中已明确必含 Local Data Reviewer；
  - 测试中 mock `getApplicationDocumentsDirectory()` 返回 `Directory.systemTemp.createTempSync()` 路径物理隔离（与 `REAL_AUDIO_MVP_TDD.md` §1.1 Repository tests 一致）；
- **Findings**：
  - `path_provider ^2.1.6` 与既有 Drift 数据库路径（默认 `<docs>` 子目录）共存，无路径冲突；
  - T028 实现 `AudioFileStorageService` 时路径命名候选 `<docs>/recordings/<yyyy-MM-dd>/<recordId>.m4a` 与 Drift 数据库路径命名约定一致；
  - `getApplicationDocumentsDirectory()` 卸载自动清除行为与 SDD §3.7 一致；
  - 测试中真实路径与临时路径物理隔离明确；
  - T028 / T032 / T034 任务边界清晰（与既有 §5.1.5 一致）；
- **Blockers**：无
- **Non-blocking Suggestions**：
  - T028 任务最终路径命名待 `04-audio-engineer` + `06-local-data-engineer` 联签（与 `REAL_AUDIO_MVP_SDD.md` §4.3 末段一致）；
  - T032 任务最终字段列表待 `06-local-data-engineer` + `04-audio-engineer` 联签（与 `REAL_AUDIO_MVP_SDD.md` §6.2 候选字段一致）；
- **Approval**：**Approved**

### 4.7 T027 Scorecard（真实音频 MVP 权限与 Manifest 基础层实现）
| 字段 | 值 |
| --- | --- |
| Task ID | `T027_PERMISSION_AND_MANIFEST_IMPLEMENTATION` |
| Primary Agent | `04-audio-engineer`（权限依赖接入 / Manifest 权限声明 / 权限服务抽象 / 测试主导） |
| Review Agents | `02-flutter-architect`（Flutter / Riverpod / 分层结构 / pubspec 变更 / 依赖边界 / 未越界接入录音播放审查）、`08-compliance-reviewer`（RECORD_AUDIO 声明 / 无 INTERNET 原则 / 权限文案 / 敏感文件边界 / 未声称真实录音已完成审查）、`07-qa-reviewer`（测试覆盖 / 权限服务可测性 / 回归测试 / Manifest 权限验证 / 命令纪律审查） |
| High Risk Areas | `RECORD_AUDIO` 权限声明（main/debug/profile 三处一致）/ 无 `INTERNET` 原则保留 / `permission_handler ^12.0.3` 依赖引入 / 权限服务可测性（fake gateway 解耦 platform channel）/ 未完成能力误写（不得把"权限基础层"写成"真实录音已实现"）/ 敏感文件边界（不读取 `key.properties` 内容 / 不记录密码）/ 命令纪律（单条命令 / 无管道 / 无重定向 / 无 `&&` / 无分号 / 无复合）/ 越权（push / Tag / amend / rebase / reset --hard 全部禁止） |
| Blockers Found | 0（Flutter Architect + Compliance + QA 三个 Reviewer 均按 `AGENT_REVIEW_TEMPLATE.md` 只读审查，未发现阻断项；详见下文 §4.7.1 ~ §4.7.3 Reviewer 报告段与 `TASK_LEDGER.md` T027 条目 Reviewer 报告段） |
| Blockers Valid | 0（无 Blockers） |
| Fix Commits Required | 0 |
| Tests Passed | 421（407 既有 + 14 新增；既有测试未减少；新增测试 ≥12 满足任务预期） |
| Scope Clean | Yes（仅修改 4 个允许文件：`pubspec.yaml` 末尾新增 `permission_handler: ^12.0.3` + `pubspec.lock` 自动更新、`android/app/src/main/AndroidManifest.xml` 显式声明 `RECORD_AUDIO` 并更新注释、`android/app/src/debug/AndroidManifest.xml` 显式声明 `RECORD_AUDIO`、`android/app/src/profile/AndroidManifest.xml` 显式声明 `RECORD_AUDIO`；仅新建 5 个允许文件：`lib/shared/services/microphone_permission_status.dart` + `lib/shared/services/microphone_permission_gateway.dart` + `lib/shared/services/permission_handler_microphone_permission_gateway.dart` + `lib/shared/services/microphone_permission_service.dart` + `test/shared/services/microphone_permission_service_test.dart`；仅修改 3 个允许文档：`docs/dev/TASK_LEDGER.md` 追加 T027 条目 + `docs/dev/TECH_DEBT.md` 校准 TD-007（权限基础层完成，真实录音仍未完成） + `docs/dev/TECH_DEBT.md` 校准 TD-010（T027 已完成 `permission_handler ^12.0.3` 引入） + `docs/dev/AGENT_QUALITY_METRICS.md` §4.7 追加 T027 Scorecard） |
| Command discipline violation | **No**（本任务全程命令均为单条命令：`git status --short` / `git branch --show-current` / `git rev-parse --short HEAD` / `git log -1 --oneline` / `git remote -v` / `git tag -n1 --list v0.1.0-mvp` / `git tag -n1 --list v1.0.0-release` / `git rev-parse --short v0.1.0-mvp^{commit}` / `git rev-parse --short v1.0.0-release^{commit}` / `git ls-files ...` / `flutter pub get` / `flutter analyze` / `flutter test` / `grep -c ...` / `grep -E ...` / `Read` / `Write` / `Edit` 等只读或允许写命令；无管道、无重定向、无 `&&`、无分号、无复合命令） |
| Sensitive Files Checked | Yes（`git ls-files android/key.properties` / `*.jks` / `*.keystore` / `build/app/outputs/flutter-apk/app-release.apk` / `build/app/outputs/bundle/release/app-release.aab` 五项均返回空；`v0.1.0-mvp` 仍指向 `d49ce4b` 未变；`v1.0.0-release` 仍指向 `703d2aa` 未变；新代码未记录密码 / keystore 内容 / 用户目录 keystore 绝对路径；未读取 `key.properties` 内容） |
| Build Artifacts Tracked | No（`git ls-files build/app/outputs/**` 返回空） |
| Dependency Modified | **Yes**（`pubspec.yaml` 新增 `permission_handler: ^12.0.3`；`pubspec.lock` 自动更新；pub get 解析成功并自动拉入子包 `permission_handler_android 13.0.1` / `permission_handler_apple 9.4.10` / `permission_handler_html 0.1.3+5` / `permission_handler_platform_interface 4.3.0` / `permission_handler_windows 0.2.1`，均为 permission_handler 生态必需子包，无 record / just_audio / audio_session / audioplayers / flutter_sound） |
| Permissions Modified | **Yes**（`android/app/src/main/AndroidManifest.xml` / `debug/AndroidManifest.xml` / `profile/AndroidManifest.xml` 三处清单均显式声明 `<uses-permission android:name="android.permission.RECORD_AUDIO" />`；**未**声明 `INTERNET`、**未**声明 `READ/WRITE_EXTERNAL_STORAGE`、**未**声明 `MANAGE_EXTERNAL_STORAGE`、**未**声明 `CAMERA`、**未**声明 `BLUETOOTH`） |
| Real Audio Implementation Started | **No**（仅权限基础层 + 单元测试；`AudioRecorderService` / `AudioPlaybackService` / `AudioFileStorageService` 均未实现；`RECORD_AUDIO` 已被 Manifest 声明但 Controller 尚未调用 `requestPermission`；PracticeRecord `audioFilePath` 仍为 `null`） |
| Final Approval | 待 GPT 复审 |
| Collaboration Value | **Medium**（三个 Reviewer 均按模板只读审查并给 Approved；本任务为权限基础层（依赖引入 + Manifest 声明 + 服务抽象 + 单元测试），证据来自 `flutter pub get` 解析输出 + `flutter analyze` 输出 + `flutter test` 14/14 通过 + `grep` 静态 Manifest 检查，未发现重大缺陷；Reviewer 主要做规范性检查 + 范围守卫 + 依赖边界确认 + 无 INTERNET 原则保留确认 + 测试可测性确认 + 未完成能力表述隔离 + 敏感信息未泄露确认 + 命令纪律确认，未拦截真实 Bug；与 T022 / T024 / T025 / T026 类似属于"偏流程化 + 边界校验审查"，但仍是真实音频阶段必经的"权限基础层门禁"，避免后续 T028+ 在无权限服务抽象下启动；协作价值以"完整 `permission_handler ^12.0.3` 引入 + 三处 Manifest 声明 + Gateway 抽象 + Service 注入 + 6 状态 enum 映射 + 14 项单元测试"为主要产出） |
| Notes | Flutter Architect Reviewer 重点确认：① `pubspec.yaml` 仅新增 `permission_handler: ^12.0.3`，未引入 `record` / `just_audio` / `audio_session` / `audioplayers` / `flutter_sound`；② `pubspec.lock` 自动拉入 5 个 permission_handler 生态子包（`permission_handler_android 13.0.1` / `permission_handler_apple 9.4.10` / `permission_handler_html 0.1.3+5` / `permission_handler_platform_interface 4.3.0` / `permission_handler_windows 0.2.1`），均为 `permission_handler` 必需依赖，无其他新顶层依赖；③ `lib/shared/services/microphone_permission_service.dart` 通过 `MicrophonePermissionGateway` 抽象隔离 platform channel，分层与既有 `lib/shared/services/` 既有约定一致；④ 测试使用 fake gateway 注入（`_FakeMicrophonePermissionGateway`），**不**触发真实系统权限弹窗；⑤ `lib/shared/services/microphone_permission_service.dart` 仅 `import` gateway + status 两个文件，**不**接触 `permission_handler` 平台包本身（platform channel 仅由 `PermissionHandlerMicrophonePermissionGateway` 持有）；⑥ `RecordingPracticeController` 未被修改、Drift schema 未被修改、UI 页面代码未修改；⑦ 既有 407 项测试 100% 保留。Compliance Reviewer 重点确认：① 未读取 `android/key.properties` 内容、未记录密码 / keystore 内容 / 用户目录 keystore 绝对路径；② 未声称真实录音已实现、未声称应用商店已提交；③ 三处 AndroidManifest 仅新增 `RECORD_AUDIO`，**未**新增 `INTERNET`、**未**新增 `READ/WRITE_EXTERNAL_STORAGE`、**未**新增 `MANAGE_EXTERNAL_STORAGE`、**未**新增 `CAMERA`、**未**新增 `BLUETOOTH`；④ 无 `INTERNET` 原则保留（与 `REAL_AUDIO_MVP_SDD.md` §3.3 / `REAL_AUDIO_DEPENDENCY_SPIKE.md` §5.4 一致）；⑤ `PermissionStatus.provisional` 在 iOS 临时授权场景下被映射为 `granted`，符合 SDD §3.2 语义；⑥ iOS `NSMicrophoneUsageDescription` 文案已在 SDD §3.5 预留，本任务**不**重复声明（任务范围仅 Android main/debug/profile）；⑦ `MicrophonePermissionStatus` 保留 iOS `limited` / `restricted` 跨平台语义，未识别值兜底为 `unknown`；⑧ 隐私政策文案更新由 T033 任务执行，本任务**不**修改 `PrivacyNoticePage`；⑨ 文档准确说明"权限基础层完成，真实录音调用仍未完成"（`TECH_DEBT.md` TD-007 / TD-010 已校准）；⑩ 未 push、未 Tag、未 amend / rebase / reset --hard。QA Reviewer 重点确认：① 14 项单元测试全部通过（`flutter test test/shared/services/microphone_permission_service_test.dart` 输出 `00:00 +14: All tests passed!`）；② 状态映射覆盖 6 个 `MicrophonePermissionStatus` 值（granted / denied / permanentlyDenied / restricted / limited / unknown），其中 unknown fallback 通过 fake gateway 自定义 raw 值触发，验证 forward-compat；③ 契约不变式测试覆盖：`checkStatus` 不调用 `request`（`checkStatusCallCount = 1 && requestPermissionCallCount = 0`）、`requestPermission` 调用 `request` exactly once（`requestPermissionCallCount = 1 && checkStatusCallCount = 0`）、service 不引用录音 SDK 符号；④ 测试不触发真实系统权限弹窗（fake gateway 注入，无 platform channel 调用）；⑤ 全量 `flutter test` 通过 421 项（407 既有 + 14 新增，既有测试未减少）；⑥ `flutter analyze` 输出 `No issues found! (ran in 4.4s)`；⑦ Manifest 静态检查：`grep -c RECORD_AUDIO` 三处 Manifest 各返回 2（1 行 uses-permission + 1 行注释），`grep -E "uses-permission.*INTERNET"` 三处 Manifest 均返回空，`grep -E "READ_EXTERNAL_STORAGE|WRITE_EXTERNAL_STORAGE|MANAGE_EXTERNAL_STORAGE|CAMERA|BLUETOOTH"` 三处 Manifest 均返回空；⑧ `pubspec.yaml` 单行修改（`uuid: ^4.5.3` 后追加 `permission_handler: ^12.0.3`），无其他变化；⑨ 命令纪律严格执行，未触发 T022A 记录的命令纪律违规模式（管道 / 重定向 / 输出截断 helper / 复合），与 T023 / T024 / T025 / T026 表现一致；详见 `docs/dev/TASK_LEDGER.md` T027 条目 |

#### 4.7.1 Flutter Architect Reviewer（02-flutter-architect）只读审查

- **Reviewer Role**：`02-flutter-architect`
- **Scope Reviewed**：`pubspec.yaml` / `pubspec.lock` 变更；`lib/shared/services/microphone_permission_status.dart` / `microphone_permission_gateway.dart` / `permission_handler_microphone_permission_gateway.dart` / `microphone_permission_service.dart` 四个新文件；`android/app/src/main/AndroidManifest.xml` / `debug/AndroidManifest.xml` / `profile/AndroidManifest.xml` 三处清单；`test/shared/services/microphone_permission_service_test.dart` 单元测试；既有 `docs/TECH_STACK.md` §6.1 / §7.4 / §10 + `docs/ARCHITECTURE.md` §3 / §7
- **Evidence Checked**：
  - `pubspec.yaml` 单行修改（`uuid: ^4.5.3` 后追加 `permission_handler: ^12.0.3`），`pubspec.lock` 仅由 pub 自动更新；
  - `flutter pub get` 解析成功，输出 `+ permission_handler 12.0.3` + 5 个子包；`pubspec.yaml` 当前**不**包含 `record` / `just_audio` / `audio_session` / `audioplayers` / `flutter_sound`；
  - `lib/shared/services/microphone_permission_status.dart` 6 个 enum 值（granted / denied / permanentlyDenied / restricted / limited / unknown），注释明确"跨平台语义保留"；
  - `lib/shared/services/microphone_permission_gateway.dart` 抽象接口 3 个方法（`checkStatus` / `requestPermission` / `openSettings`），与 `REAL_AUDIO_MVP_SDD.md` §7.1 一致；
  - `lib/shared/services/permission_handler_microphone_permission_gateway.dart` 显式映射 `PermissionStatus` 6 个枚举值到 `MicrophonePermissionStatus`（granted 包含 provisional、permanentlyDenied 单独、restricted 单独、limited 单独、denied 单独），forward-compat 兜底 `unknown`；
  - `lib/shared/services/microphone_permission_service.dart` 通过构造注入 gateway，3 个只读方法，**不**在 `checkStatus` 时自动申请、**不**调用真实麦克风、**不**依赖 UI、**不**依赖 Riverpod codegen；
  - `test/shared/services/microphone_permission_service_test.dart` 使用 `_FakeMicrophonePermissionGateway` fake gateway 注入，14 项测试覆盖 6 状态映射 + 3 契约不变式 + 2 openSettings 分支 + 1 service 不引用录音 SDK 符号；
  - `android/app/src/main/AndroidManifest.xml` / `debug/AndroidManifest.xml` / `profile/AndroidManifest.xml` 三处清单均显式声明 `<uses-permission android:name="android.permission.RECORD_AUDIO" />`；
  - `lib/features/recording/application/recording_practice_controller.dart` 未被修改（`RecordingPracticeController` 仍硬编码 `audioFilePath: null`）；
  - `lib/data/database/app_database.dart` 未被修改（schemaVersion 仍为 1）；
  - `lib/features/recording/presentation/recording_page.dart` / `lib/features/practice_records/presentation/practice_record_detail_page.dart` 等 UI 页面代码未修改；
- **Findings**：
  - `pubspec.yaml` 单行修改符合任务预期（仅新增 `permission_handler ^12.0.3`），无其他顶层依赖变更；
  - 权限服务分层（`shared/services/microphone_permission_*.dart`）与既有 `lib/shared/services/` 约定一致（参考 `install_date_service.dart` / `drift_install_date_service.dart` 的接口 + 实现分离模式）；
  - `MicrophonePermissionGateway` 抽象隔离 platform channel，测试 fake gateway 注入即可验证映射逻辑，无需 mocktail / mockito（与 T026 §7.3 T035 设计原则一致）；
  - `PermissionHandlerMicrophonePermissionGateway` 是唯一接触 `permission_handler` 平台包的生产代码，符合"薄包装"原则；
  - `RecordingPracticeController` 未被修改、Drift schema 未被修改、UI 页面代码未修改，符合任务"权限基础层"边界；
  - `permission_handler` 12.0.3 满足 `compileSdk ≥ 33` 要求（当前 `compileSdk = 36`），无 `coreLibraryDesugaring` 需求；
- **Blockers**：无
- **Non-blocking Suggestions**：
  - 未来 T033 任务实现 UI 权限体验时，可考虑在 `MicrophonePermissionService` 之上加一层 `MicrophonePermissionNotifier`（Riverpod `AsyncNotifier`）以驱动 UI 状态；本任务**不**强制此设计（避免过度架构）；
  - `MicrophonePermissionStatus.unknown` 在 Android MVP 不会触发（permission_handler 12.x 枚举已穷尽），保留仅为 forward-compat；如未来 T036 真机验收发现新枚举值，按 unknown 处理即可；
- **Approval**：**Approved**

#### 4.7.2 Compliance Reviewer（08-compliance-reviewer）只读审查

- **Reviewer Role**：`08-compliance-reviewer`
- **Scope Reviewed**：`android/app/src/main/AndroidManifest.xml` / `debug/AndroidManifest.xml` / `profile/AndroidManifest.xml` 三处清单权限声明；`lib/shared/services/microphone_permission_status.dart` enum 状态语义；`lib/shared/services/microphone_permission_service.dart` / `permission_handler_microphone_permission_gateway.dart` 权限流程；`test/shared/services/microphone_permission_service_test.dart` 权限行为测试；既有 `docs/dev/REAL_AUDIO_MVP_SDD.md` §3 Permission and Privacy / `docs/dev/TECH_DEBT.md` TD-007 / TD-010
- **Evidence Checked**：
  - `git ls-files android/key.properties` / `*.jks` / `*.keystore` / `build/app/outputs/**` 五项均返回空；
  - `v0.1.0-mvp` 仍指向 `d49ce4b`、`v1.0.0-release` 仍指向 `703d2aa`；
  - 全文搜索 `pubspec.yaml` / `lib/shared/services/microphone_permission_*.dart` / `test/shared/services/microphone_permission_service_test.dart` 确认未出现 `key.properties` 内容 / 密码 / keystore 内容 / 用户目录 keystore 绝对路径；
  - `grep -c RECORD_AUDIO` 三处 Manifest 各返回 2（1 行 `<uses-permission>` 节点 + 1 行注释行）；
  - `grep -E "uses-permission.*INTERNET"` 三处 Manifest 均返回空（**未**声明 `INTERNET`）；
  - `grep -E "READ_EXTERNAL_STORAGE|WRITE_EXTERNAL_STORAGE|MANAGE_EXTERNAL_STORAGE|CAMERA|BLUETOOTH"` 三处 Manifest 均返回空（**未**声明任何存储 / 相机 / 蓝牙权限）；
  - `MicrophonePermissionStatus` 6 个值权限语义注释明确（granted / denied / permanentlyDenied / restricted / limited / unknown），与 `REAL_AUDIO_MVP_SDD.md` §3.2 决策一致；
  - `PermissionStatus.provisional`（iOS 临时授权）被映射为 `granted`，符合 SDD §3.2 "在 App 内可继续使用"语义；
  - `TECH_DEBT.md` TD-007 已校准"权限基础层完成；真实录音调用仍未完成"，未把"已声明 RECORD_AUDIO"写成"真实录音已实现"；
  - `TECH_DEBT.md` TD-010 已校准"T027 已完成 `permission_handler ^12.0.3` 引入"，明确 `record ^7.1.0` 与 `just_audio ^0.10.5` 仍**未**写入 `pubspec.yaml`；
  - 真实音频阶段无 `INTERNET` 原则保留（与 `REAL_AUDIO_MVP_SDD.md` §3.3 / `REAL_AUDIO_DEPENDENCY_SPIKE.md` §5.4 一致）；
  - iOS `NSMicrophoneUsageDescription` 文案已在 `REAL_AUDIO_MVP_SDD.md` §3.5 预留，本任务**不**重复声明（任务范围仅 Android main/debug/profile）；
- **Findings**：
  - 权限声明范围与 `REAL_AUDIO_MVP_SDD.md` §3.1 设计一致：T027 在三处 AndroidManifest 显式声明 `RECORD_AUDIO`；
  - 无 `INTERNET` 原则保留：三处 Manifest **未**声明 `INTERNET`，`PermissionHandlerMicrophonePermissionGateway` 仅调用 `Permission.microphone` platform channel（无任何网络 API 调用）；
  - 状态映射语义正确：`PermissionStatus.denied` / `permanentlyDenied` / `restricted` / `limited` / `granted` 各自对应 `MicrophonePermissionStatus` 同名值；`provisional`（iOS 临时授权）映射为 `granted`；forward-compat `unknown` 兜底；
  - 未声称真实录音已实现：`TECH_DEBT.md` TD-007 / TD-010 已显式标注"权限基础层完成"而非"真实录音完成"；
  - 未读取 `android/key.properties` 内容、未记录密码 / keystore 内容 / 用户目录 keystore 绝对路径；
  - 未 push、未 Tag、未 amend / rebase / reset --hard；
  - 隐私政策更新由 T033 任务执行，本任务**不**修改 `PrivacyNoticePage`（符合 T033 任务边界）；
- **Blockers**：无
- **Non-blocking Suggestions**：
  - `PermissionStatus.grantedLimited` 在 permission_handler 12.0.3 实际并不存在（仅有 6 个枚举值），`PermissionHandlerMicrophonePermissionGateway._mapStatus` 已正确删除该 case；如未来 permission_handler 13.x 引入新枚举值（如 `grantedLimited` / 部分授权），按 unknown fallback 即可，无需阻塞当前任务；
  - 建议 T033 任务实现 UI 权限体验时，`MicrophonePermissionStatus.restricted` 文案可与 `permanentlyDenied` 区分（前者为"系统级限制"，如家长控制 / MDM；后者为"用户永久拒绝"），避免文案误导；
- **Approval**：**Approved**

#### 4.7.3 QA Reviewer（07-qa-reviewer）只读审查

- **Reviewer Role**：`07-qa-reviewer`
- **Scope Reviewed**：`test/shared/services/microphone_permission_service_test.dart` 单元测试；`flutter analyze` / `flutter test` 实际输出；`flutter pub get` 解析结果；Manifest 静态检查结果；既有 `docs/dev/AGENT_REVIEW_TEMPLATE.md` QA Checklist
- **Evidence Checked**：
  - `flutter analyze` `No issues found! (ran in 4.4s)`；
  - `flutter test test/shared/services/microphone_permission_service_test.dart` 输出 `00:00 +14: All tests passed!`（14 项测试 100% 通过）；
  - `flutter test` 全量输出 `00:13 +421: All tests passed!`（421 = 407 既有 + 14 新增，既有测试未减少，新增 ≥12 满足任务预期）；
  - `flutter pub get` 解析成功，输出 `+ permission_handler 12.0.3` + 5 个子包；
  - 14 项测试覆盖：① checkStatus maps granted；② checkStatus maps denied；③ checkStatus maps permanentlyDenied；④ checkStatus maps restricted；⑤ checkStatus maps limited；⑥ checkStatus maps unknown fallback；⑦ requestPermission maps granted；⑧ requestPermission maps denied；⑨ requestPermission maps permanentlyDenied；⑩ checkStatus does not call request；⑪ requestPermission calls request exactly once；⑫ service does not call microphone recording APIs（契约测试：service 文件**不**引用 record / just_audio / audio_session 符号）；⑬ openSettings returns true when gateway opens settings；⑭ openSettings returns false when gateway fails to open settings；
  - 全部 14 项测试使用 `_FakeMicrophonePermissionGateway` fake gateway 注入，**不**触发真实 platform channel / **不**触发真实系统权限弹窗；
  - `unknown` fallback 通过 fake gateway 自定义 `MicrophonePermissionStatus.unknown` 返回值触发，验证 forward-compat；
  - `grep -c RECORD_AUDIO` 三处 Manifest 各返回 2（1 行 `<uses-permission>` 节点 + 1 行注释行）；
  - `grep -E "uses-permission.*INTERNET"` 三处 Manifest 均返回空；
  - `grep -E "READ_EXTERNAL_STORAGE|WRITE_EXTERNAL_STORAGE|MANAGE_EXTERNAL_STORAGE|CAMERA|BLUETOOTH"` 三处 Manifest 均返回空；
  - `pubspec.yaml` 单行修改（`uuid: ^4.5.3` 后追加 `permission_handler: ^12.0.3`），无其他变化；
- **Findings**：
  - 测试数从 407 增至 421（+14），既有 407 项测试 100% 保留，**无**测试减少；
  - 测试覆盖完整：6 状态映射 + 3 契约不变式 + 2 openSettings 分支 + 1 录音 SDK 符号未引用契约测试，14 项测试 = 12 状态映射/契约 + 2 openSettings（任务最低要求 12 项，已超额）；
  - 测试不触发真实系统权限弹窗（fake gateway 注入，与 `REAL_AUDIO_MVP_TDD.md` §1.1 Permission behavior tests 一致）；
  - `flutter analyze` 通过，无新警告；
  - Manifest 权限验证通过：三处 `RECORD_AUDIO` 声明 + 三处无 `INTERNET` + 三处无任何存储 / 相机 / 蓝牙权限；
  - 既有 407 项测试 100% 保留（基线 T024 锁定，本任务**未**修改任何既有测试代码 / 既有生产代码 / Drift schema / Android Gradle 配置 / `pubspec.yaml` 其他字段 / `pubspec.lock` 既有部分）；
  - 命令纪律严格执行：本任务全程命令均为单条命令，无管道 / 重定向 / `&&` / 分号 / 复合命令，与 T023 / T024 / T025 / T026 表现一致；
- **Blockers**：无
- **Non-blocking Suggestions**：
  - `PermissionStatus.grantedLimited` 映射分支在初版曾被加入 `PermissionHandlerMicrophonePermissionGateway._mapStatus`，但 permission_handler 12.0.3 实际**不**存在该枚举值，编译失败后已删除；如未来 permission_handler 13.x 引入新枚举值（如 `grantedLimited` / `partial`），可在 T028+ 任务按 unknown fallback 即可；
  - `unknown` fallback 当前通过 fake gateway 自定义 raw 值触发，未在生产代码中显式覆盖（permission_handler 12.x switch 已穷尽，dead code 已被 `// ignore: dead_code` 标注保留 forward-compat）；如未来 permission_handler 升级引入新枚举值，按 unknown 处理无需修改本任务代码；
- **Approval**：**Approved**

### 4.8 T028 Scorecard（真实音频 MVP 音频文件存储基础层实现）

| 字段 | 值 |
| --- | --- |
| Task ID | `T028_AUDIO_FILE_STORAGE_SERVICE` |
| Primary Agent | `06-local-data-engineer`（音频文件路径 / 命名 / 临时与已保存目录 / 安全删除 / 测试主导） |
| Review Agents | `04-audio-engineer`（文件格式 / 临时文件 / 保存路径 / 未来 record / just_audio 接入契约审查）、`02-flutter-architect`（Flutter / path_provider / service 分层 / 测试隔离 / 未越界接入 UI 或 Controller 审查）、`08-compliance-reviewer`（不使用外部共享目录 / 不泄露隐私路径 / 不引入 INTERNET / 未误写真实录音已完成审查）、`07-qa-reviewer`（测试覆盖 / 文件系统边界 / 异常场景 / 回归测试 / 命令纪律审查） |
| High Risk Areas | 路径逃逸（`..` / 绝对路径 / `audio/../etc/passwd`）/ 误删 root 外文件 / 外部共享目录（`/storage/emulated/0/Music` 等）/ 测试隔离（不污染真实 `getApplicationDocumentsDirectory`）/ 未完成能力误写（不得把"文件存储基础层"写成"真实录音已实现"）/ Windows / POSIX 路径兼容 / 删除 root 本身 / 未触发权限弹窗 / 未调用麦克风 / 命令纪律（单条命令 / 无管道 / 无重定向 / 无 `&&` / 无分号 / 无复合）/ 越权（push / Tag / amend / rebase / reset --hard 全部禁止 / 不修改 `pubspec.yaml` / `pubspec.lock` / AndroidManifest.xml / Drift schema / 已有 production code） |
| Blockers Found | 0（四个 Reviewer 均按 `AGENT_REVIEW_TEMPLATE.md` 只读审查，未发现阻断项；详见下文 §4.8.1 ~ §4.8.4 Reviewer 报告段与 `TASK_LEDGER.md` T028 条目 Reviewer 报告段） |
| Blockers Valid | 0（无 Blockers） |
| Fix Commits Required | 0 |
| Tests Passed | 444（421 既有 + 23 新增；既有测试未减少；新增测试 ≥22 满足任务预期） |
| Scope Clean | Yes（仅新建 3 个允许文件：`lib/shared/services/audio_file_storage_paths.dart` + `lib/shared/services/audio_file_storage_service.dart` + `test/shared/services/audio_file_storage_service_test.dart`；仅修改 3 个允许文档：`docs/dev/TASK_LEDGER.md` 追加 T028 条目 + `docs/dev/TECH_DEBT.md` 校准 TD-007（音频文件存储基础层完成；真实录音仍未完成） + `docs/dev/AGENT_QUALITY_METRICS.md` §4.8 追加 T028 Scorecard） |
| Command discipline violation | **No**（本任务全程命令均为单条命令；无管道、无重定向、无 `&&`、无分号、无复合命令） |
| Sensitive Files Checked | Yes（`git ls-files android/key.properties` / `*.jks` / `*.keystore` / `build/app/outputs/flutter-apk/app-release.apk` / `build/app/outputs/bundle/release/app-release.aab` 五项均返回空；`v0.1.0-mvp` 仍指向 `d49ce4b` 未变；`v1.0.0-release` 仍指向 `703d2aa` 未变；新代码未记录密码 / keystore 内容 / 用户目录 keystore 绝对路径；未读取 `key.properties` 内容） |
| Build Artifacts Tracked | No（`git ls-files build/app/outputs/**` 返回空） |
| Dependency Modified | **No**（`pubspec.yaml` / `pubspec.lock` 未被修改；`record` / `just_audio` / `audio_session` / `audioplayers` / `flutter_sound` 均未引入；`path_provider ^2.1.6` 已存在 + `permission_handler ^12.0.3` 已由 T027 引入；本任务复用 `path_provider` 默认生产 root provider） |
| Permissions Modified | **No**（`AndroidManifest.xml` 三处清单均未修改；`RECORD_AUDIO` / `INTERNET` / 其他权限均未在本任务变更；T027 已完成 `RECORD_AUDIO` 声明，本任务**不**触及权限） |
| Real Audio Implementation Started | **No**（仅音频文件路径 / 命名 / 临时与已保存目录 / 安全删除基础层；`AudioRecorderService` / `AudioPlaybackService` / `RecordingPracticeController` 真实音频状态机均未实现；`RECORD_AUDIO` 已被 Manifest 声明但 Controller 尚未调用 `requestPermission`；PracticeRecord `audioFilePath` 仍为 `null`；service 文件**不**引用 record / just_audio / audio_session / AudioRecorder / AudioPlayer 任何符号） |
| Final Approval | 待 GPT 复审 |
| Collaboration Value | **Medium**（四个 Reviewer 均按模板只读审查并给 Approved；本任务为音频文件存储基础层，证据来自 `flutter analyze` 输出 + `flutter test` 23/23 通过 + 单文件测试通过 + 静态边界检查（grep `record` / `just_audio` / `permission_handler` / `AudioRecorder` / `AudioPlayer` 字符串仅出现在**注释中显式声明"不引用"**或**标识符名 `recordId`**，无实际 import / 引用 / 调用） + 测试隔离验证（fake provider + `Directory.systemTemp.createTempSync()`） + 敏感文件边界（key.properties / *.jks / *.keystore / build artifacts 全部返回空）+ v0.1.0-mvp / v1.0.0-release Tag 完整性，未发现重大缺陷；Reviewer 主要做规范性检查 + 范围守卫 + 文件名片段校验完整性确认 + 路径逃逸防护完整性确认 + root 外路径防御确认 + temp/saved 目录契约确认 + 未来 record / just_audio 接入契约兼容性确认 + 测试覆盖完整性确认 + 测试不触发权限弹窗确认 + 测试不调用麦克风确认 + 测试不调用 path_provider 平台通道确认 + 未完成能力表述隔离 + 敏感信息未泄露确认 + 命令纪律确认，未拦截真实 Bug；与 T022 / T024 / T025 / T026 / T027 类似属于"偏流程化 + 边界校验审查"，但仍是真实音频阶段必经的"音频文件存储基础层门禁"，避免后续 T029+ 在无文件存储契约下启动；协作价值以"完整 8 个 API + 文件名片段校验 + 路径逃逸防护 + Windows/POSIX 兼容 + 23 项纯单元测试 + 未来 record/just_audio 接入契约保留"为主要产出） |
| Notes | Audio Engineer Reviewer 重点确认：① 文件格式默认 `m4a`、可选 `aac` / `wav`、扩展名校验覆盖 `[a-z0-9]{2,4}`；② temp 目录契约（`root/temp/` + 仅生成路径不写内容 + 录音写入由未来 T029 `AudioRecorderService.start()` 负责）清楚；③ saved 目录契约（`root/saved/YYYY-MM-DD/<recordId>.m4a` + 本地午夜日期格式化 + 不覆盖已有文件）清楚；④ saved 路径格式 `YYYY-MM-DD/<recordId>.m4a` 满足后续 `record` 7.1.0（m4a/AAC-LC）+ `just_audio` 0.10.5（本地 file://）接入契约；⑤ service 文件**不**引用 record / just_audio / permission_handler / audio_session 任何符号（grep 验证仅在注释或标识符名 `recordId` 中）；⑥ 未声称真实录音已实现（`TECH_DEBT.md` TD-007 已校准"音频文件存储基础层完成；真实录音仍未完成"）。Flutter Architect Reviewer 重点确认：① 未修改 `pubspec.yaml` / `pubspec.lock`；② 未修改 `AndroidManifest.xml` 三处清单；③ service 位于 `lib/shared/services/`，与既有 `install_date_service.dart` / `microphone_permission_service.dart` 同级，分层合理；④ 默认生产 root provider 基于 `path_provider.getApplicationDocumentsDirectory()`，测试用注入式 provider 实现隔离；⑤ 测试使用 `_IsolatedRootProvider` fake provider + `Directory.systemTemp.createTempSync()` 创建隔离临时目录，测试结束通过 `addTearDown` 清理；⑥ 未修改 `RecordingPracticeController` / `PracticeRecord` / `Drift` / `Repository` / UI 页面 / `android/app/build.gradle` / `key.properties` / `.gitignore`；⑦ 既有的 421 项测试 100% 保留。Compliance Reviewer 重点确认：① 未读取 `key.properties` 内容、未记录密码 / keystore 内容 / 用户目录 keystore 绝对路径；② 未声称真实录音已实现；③ 默认生产 root provider 使用 `getApplicationDocumentsDirectory()/audio`（app 私有文档目录），**不**使用外部共享目录；④ `deleteIfExists` + `cleanupTempFiles` + `isPathInsideRoot` 三重路径逃逸防护；⑤ 未新增 `INTERNET` 权限（三处 Manifest 未变更）；⑥ 未新增任何权限；⑦ 未 push、未 Tag、未 amend / rebase / reset --hard。QA Reviewer 重点确认：① 23 项单元测试全部通过（`flutter test test/shared/services/audio_file_storage_service_test.dart` 输出 `00:00 +23: All tests passed!`）；② 覆盖 ensureDirectories（创建三目录 + 幂等）+ createTempFile（路径生成 + takeId 空/点点/斜杠反斜杠点空格 6 种坏 ID / 扩展名 6 种坏值）+ savedFileForRecord（YYYY-MM-DD 路径 + 创建日期目录 + recordId 校验）+ exists（true/false）+ sizeBytes（实际长度/缺失返 0）+ deleteIfExists（文件内/缺失返 false/root 自身拒绝/root 外文件拒绝）+ cleanupTempFiles（白名单扩展名清理/saved 不删/子目录不删/root 外 temp 拒绝）+ 静态边界契约测试（service 文件**不**引用录音/播放/权限 SDK 符号）；③ 路径逃逸测试覆盖（root 自身拒绝、root 外文件拒绝、root 外 temp 拒绝、takeId `..` 拒绝、takeId 斜杠反斜杠点空格拒绝、扩展名带点拒绝）；④ 删除 root 外文件测试覆盖（`AudioFileStorageService.deleteIfExists refuses root-outside path even when wrapped as File` + `AudioFileStorageService.cleanupTempFiles refuses to clean up temp directory outside of root`）；⑤ 清理 temp 不删除 saved 测试覆盖（`AudioFileStorageService.cleanupTempFiles does not delete saved files`）；⑥ 测试清理临时目录（每个测试通过 `_createIsolatedRoot` 的 `addTearDown` hook 删除临时根目录及其全部内容）；⑦ 测试不触发权限弹窗（fake provider 注入，无 platform channel 调用）；⑧ 旧 421 项测试不减少（实际 444 通过 = 421 既有 + 23 新增）；⑨ 命令纪律无违规（全程单条命令，无管道 / 重定向 / `&&` / 分号 / 复合）；详见 `docs/dev/TASK_LEDGER.md` T028 条目 |

#### 4.8.1 Audio Engineer Reviewer（04-audio-engineer）只读审查

- **Reviewer Role**：`04-audio-engineer`
- **Scope Reviewed**：`lib/shared/services/audio_file_storage_paths.dart` 不可变数据结构 + `lib/shared/services/audio_file_storage_service.dart` 8 个 API + 文件名片段校验 + 路径逃逸防护 + 文件格式契约；`test/shared/services/audio_file_storage_service_test.dart` 23 项单元测试；既有 `docs/dev/REAL_AUDIO_MVP_SDD.md` §4 Audio File Lifecycle + `docs/dev/REAL_AUDIO_MVP_TDD.md` §2.7 Filesystem + `docs/dev/REAL_AUDIO_DEPENDENCY_SPIKE.md` §3.6 path_provider
- **Evidence Checked**：
  - `lib/shared/services/audio_file_storage_paths.dart` 不可变数据结构含 `rootDirectory` / `tempDirectory` / `savedDirectory` / 可空 `dayDirectory`，注释明确"**不**依赖 Flutter UI / Riverpod / Codegen / path_provider"；
  - `lib/shared/services/audio_file_storage_service.dart` 默认扩展名 `m4a`、可选 `aac` / `wav`、扩展名校验 `[a-z0-9]{2,4}`、白名单 `m4a` / `aac` / `wav`；
  - `createTempFile` 仅生成 temp 路径契约，**不**写入文件内容（注释明确"调用方拿到路径后可由真实录音服务（未来 T029 实现）写入内容"）；
  - `savedFileForRecord` 返回 `saved/YYYY-MM-DD/<recordId>.m4a` 路径，`_formatLocalDay` 使用本地午夜 `YYYY-MM-DD` 格式（与 SDD §6.2 一致）；
  - `cleanupTempFiles` 仅清理 `m4a` / `aac` / `wav` 白名单扩展名顶层文件（**不**删 `saved`、**不**删目录）；
  - saved 路径格式与未来 `record` 7.1.0 输出 m4a + `just_audio` 0.10.5 本地 file:// 播放兼容；
  - grep `record` / `just_audio` / `permission_handler` / `AudioRecorder` / `AudioPlayer` 在 `lib/shared/services/audio_file_storage_*.dart` 与 `test/shared/services/audio_file_storage_service_test.dart` 三个文件中仅出现在**注释中显式声明"不引用"**或**标识符名 `recordId`**，无实际 `import` / 引用 / 调用；
  - `TECH_DEBT.md` TD-007 已校准"音频文件存储基础层完成；真实录音仍未完成"，未把"已声明 RECORD_AUDIO"或"文件存储基础层完成"写成"真实录音已实现"；
- **Findings**：
  - 文件格式默认 `m4a` 与既有 `REAL_AUDIO_MVP_SDD.md` §4.3 命名规则一致；
  - temp / saved 目录契约清楚，与既有 `REAL_AUDIO_MVP_SDD.md` §4.2 + `REAL_AUDIO_DEPENDENCY_SPIKE.md` §3.6 一致；
  - saved 路径 `saved/YYYY-MM-DD/<recordId>.m4a` 满足后续 `record` 7.1.0（m4a/AAC-LC 44100Hz/128kbps）+ `just_audio` 0.10.5（本地 file:// 路径播放，无需 INTERNET）接入契约；
  - 未接入 record / just_audio / audio_session / AudioRecorder / AudioPlayer 任何符号；
  - 未声称真实录音已实现；
- **Blockers**：无
- **Non-blocking Suggestions**：
  - `dayDirectory` 字段当前不可空但未使用，建议未来 T029 录音服务在生成 day 目录时显式调用 `ensureDirectories` 填充 `dayDirectory`，让 Controller 拿到 day 目录引用以便清理；当前保留不影响 T028 主任务；
  - `_validateExtension` 当前白名单 `[a-z0-9]{2,4}` 已覆盖 `m4a`（3 字符）/ `aac`（3 字符）/ `wav`（3 字符），未来如需支持 `opus` / `flac`（4 字符）也可工作；建议 T029 / T030 隔离 spike 实测 `record` 实际输出扩展名后追加；
- **Approval**：**Approved**

#### 4.8.2 Flutter Architect Reviewer（02-flutter-architect）只读审查

- **Reviewer Role**：`02-flutter-architect`
- **Scope Reviewed**：`pubspec.yaml` / `pubspec.lock` 未变更；`lib/shared/services/audio_file_storage_paths.dart` + `audio_file_storage_service.dart` 两个新文件 + 既有 `lib/shared/services/` 既有约定（参考 `install_date_service.dart` / `microphone_permission_service.dart` 的接口 + 实现分离模式）；`test/shared/services/audio_file_storage_service_test.dart` 23 项单元测试；既有 `docs/ARCHITECTURE.md` §3 / §7 + `docs/TECH_STACK.md` §6.1 / §7 / §10
- **Evidence Checked**：
  - `git status --short` 工作树（Commit 前）显示仅有允许文件改动；
  - `git diff --check` 无空白错误；
  - `pubspec.yaml` 未被修改（既有 `permission_handler: ^12.0.3` / `path_provider: ^2.1.6` 不变，未引入 record / just_audio / audio_session / audioplayers / flutter_sound）；
  - `pubspec.lock` 未被修改；
  - `AndroidManifest.xml` 三处清单均未修改（T027 已完成 `RECORD_AUDIO` 声明，本任务**不**触及权限）；
  - `lib/shared/services/audio_file_storage_service.dart` 注入式根目录设计（`AudioRootDirectoryProvider` typedef + 默认生产 `defaultAudioRootDirectoryProvider()` 基于 `path_provider.getApplicationDocumentsDirectory()/audio`），与既有 `lib/shared/services/` 既有约定一致；
  - `lib/shared/services/audio_file_storage_paths.dart` 不可变数据结构 + `dart:io` only 依赖（不依赖 Flutter UI / Riverpod / codegen）；
  - `_validateIdSegment` 字符集 `[A-Za-z0-9_-]+` 与 SDD §6.1 `audioFilePath` 契约 + 真实音频阶段命名规则一致；
  - `_validateExtension` 字符集 `[a-z0-9]{2,4}` + 默认 `m4a` 与 SDD §4.3 命名规则一致；
  - `_canonicalPath` 用 `p.normalize` 处理 `..` 路径逃逸，跨 Windows / POSIX 一致（POSIX 正斜杠与 Windows 反斜杠都被规范化为 `/`）；
  - `isPathInsideRoot` 公开方法供 Controller / Repository 防御性校验；
  - `deleteIfExists` 仅在 `existsSync() == true` 时进入路径校验 → 删除流程，未通过存在性检查的文件直接返回 `false` 而不抛错（**不**抛异常给 UI，符合 MVP 既有行为约定）；
  - `_IsolatedRootProvider` fake provider 注入 + `Directory.systemTemp.createTempSync()` 实现测试隔离，测试结束通过 `addTearDown` 删除临时根目录及其全部内容；
  - 既有的 421 项测试 100% 保留（实际 444 通过 = 421 既有 + 23 新增）；
  - `RecordingPracticeController` / `PracticeRecord` / Drift schema / `Repository` / UI 页面 / `android/app/build.gradle` / `key.properties` / `.gitignore` 均未修改；
- **Findings**：
  - service 位于 `lib/shared/services/`，与既有 `install_date_service.dart` / `microphone_permission_service.dart` 同级，分层合理；
  - 默认生产 root provider 仅用于生产路径，测试用注入式 provider 实现隔离；
  - `AudioFileStorageService` 不依赖 Flutter UI、不依赖 Riverpod、不依赖 codegen，可被 Controller / Repository 直接 `new` 注入；
  - `_canonicalPath` 跨平台一致：Windows 反斜杠 `\audio\temp` 与 POSIX 正斜杠 `/audio/temp` 都被规范化为 `/audio/temp`；
  - `_validateIdSegment` + `_validateExtension` 校验完整，覆盖空 / 点 / 点点 / 斜杠 / 反斜杠 / 空格 / 长度；
  - `_validateIdSegment` 字符集 `[A-Za-z0-9_-]+` 与 `PracticeRecordIdGenerator` UUID v4 + `audioFilePath` 契约一致（仅小写十六进制 + 连字符 + 下划线字母数字组合）；
- **Blockers**：无
- **Non-blocking Suggestions**：
  - 当前 `AudioFileStorageService` **未**封装成 Riverpod Provider；如未来需要全局单例，建议在 `lib/shared/providers/audio_file_storage_service_provider.dart` 新建 `Provider<AudioFileStorageService>`（参考 `install_date_service_provider.dart`）；本任务**不**强制此设计（避免过度架构）；
  - 未来 T031 Controller 可通过 `ProviderScope.overrides` 在测试中注入 `InMemoryAudioFileStorageService` 替换 `AudioFileStorageService`，与 `MicrophonePermissionService` 的 fake gateway 注入模式一致；
- **Approval**：**Approved**

#### 4.8.3 Compliance Reviewer（08-compliance-reviewer）只读审查

- **Reviewer Role**：`08-compliance-reviewer`
- **Scope Reviewed**：`lib/shared/services/audio_file_storage_paths.dart` / `audio_file_storage_service.dart` 两个新文件 + 默认生产 root provider 基于 `getApplicationDocumentsDirectory()/audio` + 路径逃逸防护；`test/shared/services/audio_file_storage_service_test.dart` 测试隔离；既有 `docs/dev/REAL_AUDIO_MVP_SDD.md` §3 Permission and Privacy + `docs/dev/TECH_DEBT.md` TD-007 / TD-010 / TD-011 / TD-012 / TD-013
- **Evidence Checked**：
  - `git ls-files android/key.properties` / `*.jks` / `*.keystore` / `build/app/outputs/**` 五项均返回空；
  - `v0.1.0-mvp` 仍指向 `d49ce4b`、`v1.0.0-release` 仍指向 `703d2aa`；
  - 全文搜索 `audio_file_storage_paths.dart` / `audio_file_storage_service.dart` / 测试文件确认未出现 `key.properties` 内容 / 密码 / keystore 内容 / 用户目录 keystore 绝对路径；
  - 默认生产 root provider 使用 `getApplicationDocumentsDirectory()/audio`（app 私有文档目录），**不**使用外部共享目录；
  - `deleteIfExists` 接受 `rootDirectory` 参数并执行 `_isPathInsideRoot` 校验：root 外已存在文件 + `..` 路径逃逸抛 `ArgumentError`；root 目录被 `File(rootDirectory.path)` 包装时按"文件不存在"处理（`File.exists()` 对目录路径返回 `false`），返回 `false` 且 **不** 删除 root 目录；
  - `cleanupTempFiles` 接受 `tempDirectory` + `rootDirectory` 两个参数并执行 `_isCanonicalChild` 校验，root 外 temp 抛 `ArgumentError`，仅清理白名单扩展名（`m4a` / `aac` / `wav`）顶层文件，**不**删 saved、**不**删目录；
  - `isPathInsideRoot` 公开方法供 Controller / Repository 防御性校验；
  - `AndroidManifest.xml` 三处清单均未修改（**未**新增 `INTERNET`、**未**新增任何权限）；
  - `TECH_DEBT.md` TD-007 已校准"音频文件存储基础层完成；真实录音仍未完成"，未把"文件存储基础层完成"写成"真实录音已实现"；
  - 未声称真实录音已实现、未声称应用商店已提交；
  - 未读取 `key.properties` 内容、未记录密码 / keystore 内容 / 用户目录 keystore 绝对路径；
  - 未 push、未 Tag、未 amend / rebase / reset --hard；
- **Findings**：
  - 默认生产 root provider 使用 `getApplicationDocumentsDirectory()/audio`（app 私有文档目录），与既有 `REAL_AUDIO_MVP_SDD.md` §4.1 候选 A（推荐）一致；
  - 不使用外部共享目录（`/storage/emulated/0/Music` 等）、不使用公共 Downloads / Music / DCIM，与既有 SDD §3.3 无 INTERNET 原则 + §4.1 候选 A 一致；
  - 路径逃逸防护三重：`deleteIfExists` + `cleanupTempFiles` + `isPathInsideRoot` 公开方法；
  - 未新增 `INTERNET` 权限（三处 Manifest 未变更）；
  - 未新增任何权限（仅复用 T027 已声明的 `RECORD_AUDIO`）；
  - 未声称真实录音已实现；
- **Blockers**：无
- **Non-blocking Suggestions**：
  - 当前 `defaultAudioRootDirectoryProvider()` 直接返回 `<docs>/audio` 路径，**不**在内部调用 `createSync(recursive: true)`；如未来 T031 Controller 在 App 启动时立即调用 `ensureDirectories()`，可保持现有行为；如未来需要立即创建目录，建议把 `createSync(recursive: true)` 移到 provider 内部；
  - 未来 T033 任务可在 `PrivacyNoticePage` 中明确说明"音频文件保存到 App 私有目录（`<docs>/audio`），其他应用无法访问"，与既有 SDD §3.6 一致；
- **Approval**：**Approved**

#### 4.8.4 QA Reviewer（07-qa-reviewer）只读审查

- **Reviewer Role**：`07-qa-reviewer`
- **Scope Reviewed**：`test/shared/services/audio_file_storage_service_test.dart` 23 项单元测试；`flutter analyze` / `flutter test` 实际输出；grep 静态边界检查；既有 `docs/dev/AGENT_REVIEW_TEMPLATE.md` QA Checklist + `docs/dev/REAL_AUDIO_MVP_TDD.md` §2.7 Filesystem + §4 Regression Matrix
- **Evidence Checked**：
  - `flutter analyze` `No issues found! (ran in 3.3s)`；
  - `flutter test test/shared/services/audio_file_storage_service_test.dart` 输出 `00:00 +23: All tests passed!`（23 项测试 100% 通过）；
  - `flutter test` 全量输出 `00:13 +444: All tests passed!`（444 = 421 既有 + 23 新增，既有测试未减少，新增 ≥22 满足任务预期）；
  - 23 项测试覆盖：① ensureDirectories creates root temp saved；② ensureDirectories is idempotent；③ createTempFile returns temp path with provided extension；④ createTempFile validates takeId empty；⑤ createTempFile rejects path traversal (..)；⑥ createTempFile rejects slash/backslash/dot/space in takeId（6 种坏 ID 全覆盖）；⑦ createTempFile rejects invalid extension（6 种坏值全覆盖）；⑧ savedFileForRecord returns saved/YYYY-MM-DD/recordId.m4a；⑨ savedFileForRecord creates day directory；⑩ savedFileForRecord validates recordId (rejects invalid)（空 + `../escape`）；⑪ exists returns true for existing file；⑫ exists returns false for missing file；⑬ sizeBytes returns file length for existing file；⑭ sizeBytes returns 0 for missing file；⑮ deleteIfExists deletes file inside root；⑯ deleteIfExists returns false for missing file；⑰ deleteIfExists refuses to delete the root directory itself；⑱ deleteIfExists refuses root-outside path even when wrapped as File；⑲ cleanupTempFiles deletes temp files with whitelisted extension；⑳ cleanupTempFiles does not delete saved files；21 cleanupTempFiles does not delete subdirectories inside temp；22 cleanupTempFiles refuses to clean up temp directory outside of root；23 static boundary generated service does not import record / just_audio / permission_handler / audio_session symbols；
  - 全部 23 项测试使用 `_IsolatedRootProvider` fake provider + `Directory.systemTemp.createTempSync()` 注入隔离，**不**触发真实系统权限弹窗、**不**调用麦克风、**不**调用 `path_provider` 平台通道；
  - 测试结束通过 `_createIsolatedRoot` 的 `addTearDown` hook 删除临时根目录及其全部内容（递归清理）；
  - grep `record` / `just_audio` / `permission_handler` / `AudioRecorder` / `AudioPlayer` 在三个文件中仅出现在**注释中显式声明"不引用"**或**标识符名 `recordId`**；
  - 既有的 421 项测试 100% 保留（实际 444 通过 = 421 既有 + 23 新增）；
- **Findings**：
  - 测试数从 421 增至 444（+23），既有 421 项测试 100% 保留，**无**测试减少；
  - 测试覆盖完整：8 个 API 全部覆盖 + 文件名片段校验覆盖空 / 点 / 点点 / 斜杠 / 反斜杠 / 空格 + 扩展名校验覆盖空 / 点 / 斜杠 / 反斜杠 / 空格 / 超长 + 路径逃逸防护覆盖 root 外文件拒绝 + root 外 temp 拒绝 + root 被 `File` 包装时按文件不存在处理（`deleteIfExists` 返回 `false`，root 目录仍存在）+ `..` 路径拒绝 + 子目录不删 + saved 不删 + 白名单扩展名清理；
  - 测试不触发真实系统权限弹窗（fake provider 注入，与 `REAL_AUDIO_MVP_TDD.md` §1.1 File storage tests 一致）；
  - 测试不调用麦克风（仅 IO 文件操作，与 `REAL_AUDIO_MVP_TDD.md` §5 Test Gaps 9 项一致）；
  - `flutter analyze` 通过，无新警告；
  - Manifest 权限未变更（三处 Manifest 与 T027 一致，未新增任何权限）；
  - 既有的 421 项测试 100% 保留（基线 T027 锁定，本任务**未**修改任何既有测试代码 / 既有生产代码 / Drift schema / Android Gradle 配置 / `pubspec.yaml` / `pubspec.lock`）；
  - 命令纪律严格执行：本任务全程命令均为单条命令，无管道 / 重定向 / `&&` / 分号 / 复合命令，与 T023 / T024 / T025 / T026 / T027 表现一致；
- **Blockers**：无
- **Non-blocking Suggestions**：
  - 当前 23 项测试全部用 `_IsolatedRootProvider` + `Directory.systemTemp.createTempSync()` 注入隔离；如未来 T029 录音服务需要测试与 file storage service 协同，可考虑抽出共享 `_IsolatedRootProvider` 到 `test/shared/services/test_helpers/`；本任务**不**强制抽取（避免过度抽象）；
  - `dayDirectory` 字段当前不可空但未在 `ensureDirectories` 内填充；如未来需要清理当日临时目录，建议 T029 / T030 隔离 spike 中实测 `record` 实际输出路径后追加 `dayDirectory` 填充逻辑；
- **Approval**：**Approved**

### 4.9 T028A Scorecard（音频文件存储 root 删除契约文档校准）

| 字段 | 值 |
| --- | --- |
| Task ID | `T028A_FIX_AUDIO_STORAGE_ROOT_DELETE_CONTRACT_DOCS` |
| Primary Agent | `06-local-data-engineer`（T028 实施者；本任务仅修正 T028 文档删除契约表述） |
| Review Agents | `07-qa-reviewer`（只读审查：文档删除契约是否与代码 / 测试一致；测试数 / commit hash / 功能结论是否未被改变）、`08-compliance-reviewer`（只读审查：是否未误写为安全漏洞 / 是否未泄露路径或敏感文件 / 是否未越界修改 / 是否未读取 `key.properties` 内容） |
| High Risk Areas | 文档契约准确性（root 自身 + root 外 + `..` 路径逃逸行为表述校准）/ 删除语义（root 被 `File` 包装时返回 `false` vs 抛 `ArgumentError`）/ 路径逃逸（root 外文件 + `..` 抛 `ArgumentError`，root 自身**不**抛）/ 未完成能力误写（不得把 T028 写成失败 / 不得把文档不一致夸大为安全事故）/ 越界修改（不得修改生产代码 / 测试代码 / 依赖 / 权限 / 既有未授权文档）/ 越权发布（push / Tag / amend / rebase / reset --hard 全部禁止 / 不开始 T029） |
| Blockers Found | 0（QA Reviewer 与 Compliance Reviewer 均按 `AGENT_REVIEW_TEMPLATE.md` 只读审查并给 Approved，详见下文 §4.9.1 ~ §4.9.2 Reviewer 报告段与 `TASK_LEDGER.md` T028A 条目 Reviewer 报告段） |
| Blockers Valid | 0（无 Blockers） |
| Fix Commits Required | 0 |
| Tests Passed | 444（基线 T028 保持不变；新增 / 更新 / 删除 0 / 0 / 0；T028A 不修改任何测试代码） |
| Scope Clean | Yes（仅修改三个允许文档：`docs/dev/AGENT_QUALITY_METRICS.md`（§4.8.3 Compliance Reviewer Evidence 段 + §4.8.4 QA Reviewer Findings 段 + §4.9 新增 T028A Scorecard）+ `docs/dev/TASK_LEDGER.md`（T028 条目遗留说明中 `deleteIfExists` 描述与测试覆盖列表校准 + 追加 T028A 条目 + 追加 T029 占位条目）+ `docs/dev/TECH_DEBT.md`（TD-007 中 T028 描述校准为准确删除契约 + T028A 文档契约校准备注）） |
| Command discipline violation | **No**（本任务全程命令均为单条命令：`git status --short` / `git branch --show-current` / `git rev-parse --short HEAD` / `git log -1 --oneline` / `git tag -n1 --list v0.1.0-mvp` / `git tag -n1 --list v1.0.0-release` / `git rev-parse --short v0.1.0-mvp^{commit}` / `git rev-parse --short v1.0.0-release^{commit}` / `git ls-files ...` / `flutter analyze` / `flutter test` / `flutter test test/shared/services/audio_file_storage_service_test.dart` / `grep` / `Read` / `Edit` 等只读或允许写命令；无管道、无重定向、无 `&&`、无分号、无复合命令；与 T023 / T024 / T025 / T026 / T027 / T028 表现一致） |
| Sensitive Files Checked | Yes（`git ls-files android/key.properties` / `*.jks` / `*.keystore` / `build/app/outputs/flutter-apk/app-release.apk` / `build/app/outputs/bundle/release/app-release.aab` 五项均返回空；`v0.1.0-mvp` 仍指向 `d49ce4b` 未变；`v1.0.0-release` 仍指向 `703d2aa` 未变；新文档未记录密码 / keystore 内容 / 用户目录 keystore 绝对路径；未读取 `key.properties` 内容） |
| Build Artifacts Tracked | No（`git ls-files build/app/outputs/**` 返回空） |
| Dependency Modified | **No**（`pubspec.yaml` / `pubspec.lock` 未被修改；`record` / `just_audio` / `audio_session` / `audioplayers` / `flutter_sound` 均未引入） |
| Permissions Modified | **No**（`AndroidManifest.xml` 三处清单均未修改；`RECORD_AUDIO` / `INTERNET` / 其他权限均未在本任务变更） |
| Real Audio Implementation Started | **No**（仅文档契约校准；`AudioRecorderService` / `AudioPlaybackService` / `RecordingPracticeController` 真实音频状态机均未实现；`RECORD_AUDIO` 已被 Manifest 声明但 Controller 尚未调用 `requestPermission`；PracticeRecord `audioFilePath` 仍为 `null`） |
| Production Code Modified | **No**（`lib/shared/services/audio_file_storage_service.dart` / `audio_file_storage_paths.dart` 未被修改；service 文件 `deleteIfExists` 实现保持 `if (!await file.exists()) return false;` 在前、`_isPathInsideRoot` 校验在后的既有顺序） |
| Tests Modified | **No**（`test/shared/services/audio_file_storage_service_test.dart` 未被修改；23 项测试覆盖保持不变） |
| Contract Corrected | Yes（基于 `lib/shared/services/audio_file_storage_service.dart` 实际代码 + `test/shared/services/audio_file_storage_service_test.dart` 实际测试行为，把 `deleteIfExists` 处理 root 自身的契约从"root 自身抛 `ArgumentError`"校准为"root 目录被 `File(rootDirectory.path)` 包装时按文件不存在处理（`File.exists()` 对目录路径返回 `false`），返回 `false`，root 目录仍存在"） |
| Actual `deleteIfExists` Behavior | 文件不存在 → 返回 `false`（不抛错）；root 目录被 `File(rootDirectory.path)` 包装 → `File.exists()` 返回 `false` → 按文件不存在处理 → 返回 `false`（root 目录仍存在）；root 外已存在文件 → 抛 `ArgumentError`；`..` 路径逃逸 → 抛 `ArgumentError` |
| Path Escape Behavior | `deleteIfExists`：root 外已存在文件 + `..` 路径逃逸抛 `ArgumentError`；root 自身按文件不存在处理返回 `false`；`cleanupTempFiles`：root 外 temp 目录抛 `ArgumentError`；temp 内白名单扩展名顶层文件正常清理；**安全目标**：root 不会被删除、root 外文件不会被删除 |
| Tests Added/Updated/Deleted | Added: 0；Updated: 0；Deleted: 0 |
| Exact Test Count | 444 |
| Final Approval | 待 GPT 复审 |
| Collaboration Value | **High**（T029 前置检查（真实依赖 T028 删除契约时必然会复用 T028 服务 + 调用 `deleteIfExists`）成功拦截了 T028 文档与代码 / 测试之间的契约不一致，避免 T029 在错误契约基础上实现"删除 / 清理 / 异常处理"逻辑；本任务选择"文档校准"而非"代码修改"路径，保护 T028 既有的 444 测试通过 / 23 项新增测试 / `flutter analyze` 无问题；多 Agent 质量机制（QA Reviewer + Compliance Reviewer + Chief Architect 范围守卫）在 T029 前置阶段有效发现并阻断了潜在的"按错误文档实现删除流程"风险，避免后续 T029+ 在错误契约基础上叠加错误逻辑） |
| Notes | QA Reviewer 重点确认：① 文档删除契约与代码 / 测试行为一致（root 目录被 `File` 包装时返回 `false` 而非抛 `ArgumentError`）；② root 外已存在文件 + `..` 路径逃逸抛 `ArgumentError` 语义清楚；③ 没有把 T028 写成失败；④ 没有修改测试或生产代码；⑤ 444 测试仍通过（既有测试未减少）；⑥ 命令纪律无违规；⑦ T028A 文档表述校准与 `lib/shared/services/audio_file_storage_service.dart` 第 198-221 行 `deleteIfExists` 实现 + `test/shared/services/audio_file_storage_service_test.dart` 第 393-420 行 "refuses to delete the root directory itself" 测试断言完全一致（期望 `result == false` + `paths.rootDirectory.existsSync() == isTrue`）。Compliance Reviewer 重点确认：① 未读取 `key.properties` 内容、未泄露密码、未记录 keystore 内容 / 路径；② 未把文档不一致写成安全事故（错误表述仅是文档措辞不准确，不涉及安全漏洞 / 不涉及生产代码 / 不涉及实际行为偏差）；③ 未声称真实录音已实现、未声称麦克风权限已加入、未声称应用商店已提交；④ 未 push、未 Tag、未 amend / rebase / reset --hard；⑤ 未修改权限或依赖；⑥ 未越界修改（diff 范围 ⊆ 三个允许文档）；⑦ 未记录任何 keystore 内容 / 用户目录 keystore 绝对路径 / 密码字面量；⑧ 未把"root 自身不抛 `ArgumentError`"误写成"安全漏洞"或"权限泄露"；⑨ 未把 T028 写成失败（T028 仍然是"音频文件存储基础层完成、真实录音仍未开始"）；本任务全程命令纪律严格执行，未触发 T022A 记录的命令纪律违规模式（管道 / 重定向 / 输出截断 helper / 复合），与 T023 / T024 / T025 / T026 / T027 / T028 表现一致；详见 `docs/dev/TASK_LEDGER.md` T028A 条目 + `docs/dev/TECH_DEBT.md` TD-007 备注 |

#### 4.9.1 QA Reviewer（07-qa-reviewer）只读审查

- **Reviewer Role**：`07-qa-reviewer`
- **Scope Reviewed**：`docs/dev/AGENT_QUALITY_METRICS.md` §4.8.3 Compliance Reviewer Evidence 段 + §4.8.4 QA Reviewer Findings 段 + §4.9 T028A Scorecard；`docs/dev/TASK_LEDGER.md` T028 条目遗留说明 + T028A 条目 + T029 占位条目；`docs/dev/TECH_DEBT.md` TD-007 描述；既有 `lib/shared/services/audio_file_storage_service.dart` `deleteIfExists` 实现 + `test/shared/services/audio_file_storage_service_test.dart` "refuses to delete the root directory itself" 测试断言
- **Evidence Checked**：
  - `git status --short` 工作树（Commit 前）显示仅有三个允许文件改动；
  - `git diff --check` 无空白错误；
  - `lib/shared/services/audio_file_storage_service.dart` 第 198-221 行 `deleteIfExists` 实现：`if (!await file.exists()) return false;` 在 `_isPathInsideRoot` 校验之前；这意味着 root 自身被 `File(rootDirectory.path)` 包装时，`File.exists()` 对目录路径返回 `false`，走"文件不存在"分支返回 `false`，**不**抛 `ArgumentError`；
  - `test/shared/services/audio_file_storage_service_test.dart` 第 393-420 行 "refuses to delete the root directory itself" 测试断言：`expect(result, isFalse)` + `expect(paths.rootDirectory.existsSync(), isTrue)` — 完全验证"root 被 `File` 包装时按文件不存在处理，root 目录仍存在"的实际行为；
  - `test/shared/services/audio_file_storage_service_test.dart` 第 422-458 行 "refuses root-outside path even when wrapped as File" 测试断言：`throwsA(isA<ArgumentError>())` + `expect(outsideFile.existsSync(), isTrue)` — 验证"root 外文件 + `..` 路径逃逸抛 `ArgumentError`"的实际行为；
  - `test/shared/services/audio_file_storage_service_test.dart` 第 541-574 行 "refuses to clean up temp directory outside of root" 测试断言：`throwsA(isA<ArgumentError>())` — 验证"`cleanupTempFiles` 对 root 外 temp 目录抛 `ArgumentError`"的实际行为；
  - `flutter analyze` `No issues found!`、`flutter test` `All tests passed!`（444 tests passed）；
  - `flutter test test/shared/services/audio_file_storage_service_test.dart` `00:00 +23: All tests passed!`；
  - 既有 444 项测试覆盖保持不变（T028A 不修改任何测试代码）；
  - T028A 文档表述校准后，`deleteIfExists` 契约描述与代码第 198-221 行 + 测试第 393-420 行 / 第 422-458 行完全一致；
- **Findings**：
  - T028A 准确校准了 T028 文档中关于 `deleteIfExists` 处理 root 自身的错误表述；
  - root 自身被 `File` 包装时按"文件不存在"处理返回 `false`（与代码 + 测试一致），与"root 外文件 + `..` 路径逃逸抛 `ArgumentError`"形成清晰对比；
  - 没有把 T028 写成失败（T028 仍然是音频文件存储基础层完成，真实录音仍未开始）；
  - 既有 444 项测试 100% 保留（T028A 不新增 / 修改 / 删除任何测试）；
  - 命令纪律严格执行（全程单条命令，无管道 / 重定向 / `&&` / 分号 / 复合命令）；
- **Blockers**：无
- **Non-blocking Suggestions**：
  - 未来 T029 / T030 任务实现录音 / 播放服务时，可在 `deleteIfExists` 调用前后显式调用 `isPathInsideRoot` 做防御性校验，与既有 `AudioFileStorageService` 公开方法契约一致；本任务**不**强制此设计；
  - 未来 T033 任务实现 UI 文案时，可在"删除录音"按钮的 disabled 文案中提示"root 目录不可删除"，与既有 §4.8 Scorecard 中 Compliance Reviewer 建议一致；
- **Approval**：**Approved**

#### 4.9.2 Compliance Reviewer（08-compliance-reviewer）只读审查

- **Reviewer Role**：`08-compliance-reviewer`
- **Scope Reviewed**：三个允许文档（T028A 改动范围）；既有 `lib/shared/services/audio_file_storage_service.dart` `deleteIfExists` 实现 + `cleanupTempFiles` 实现；既有 `docs/dev/REAL_AUDIO_MVP_SDD.md` §3 Permission and Privacy / §4 Audio File Lifecycle + `docs/dev/TECH_DEBT.md` TD-007 / TD-010 / TD-011 / TD-012 / TD-013
- **Evidence Checked**：
  - `git ls-files android/key.properties` / `*.jks` / `*.keystore` / `build/app/outputs/**` 五项均返回空；
  - `v0.1.0-mvp` 仍指向 `d49ce4b`、`v1.0.0-release` 仍指向 `703d2aa`；
  - 全文搜索三个允许文档确认未出现 `key.properties` 内容 / 密码 / keystore 内容 / 用户目录 keystore 绝对路径；
  - 全文搜索三个允许文档确认未出现"安全漏洞 / 权限泄露 / 密钥泄露 / 危险代码"等夸大为安全事故的表述；
  - 全文搜索三个允许文档确认未出现"真实录音已实现 / 麦克风权限已加入 / 应用商店已提交"等未完成能力表述；
  - §4.9 T028A Scorecard Notes 明确"未把 T028 写成失败 / 未把文档不一致夸大为安全事故 / 未声称真实录音已实现"；
  - `lib/shared/services/audio_file_storage_service.dart` 默认生产 root provider 使用 `getApplicationDocumentsDirectory()/audio`（app 私有文档目录），**不**使用外部共享目录；
  - `AndroidManifest.xml` 三处清单均未修改（**未**新增 `INTERNET`、**未**新增任何权限）；
  - T028A **未**读取 `key.properties` 内容、**未**记录密码 / keystore 内容 / 用户目录 keystore 绝对路径；
  - T028A **未** push、未 Tag、未 amend / rebase / reset --hard；
- **Findings**：
  - T028A 仅修正文档表述，不涉及安全漏洞 / 权限泄露 / 密钥泄露 / 危险代码；
  - 文档不一致属于"措辞不准确"，**不**构成安全事故：实际代码 + 测试行为一致（root 目录被 `File` 包装时按文件不存在处理），仅文档表述与该行为有偏差；
  - 默认生产 root provider 使用 `getApplicationDocumentsDirectory()/audio`（app 私有文档目录），与既有 `REAL_AUDIO_MVP_SDD.md` §4.1 候选 A（推荐）一致；
  - 不使用外部共享目录（`/storage/emulated/0/Music` 等）、不使用公共 Downloads / Music / DCIM，与既有 SDD §3.3 无 INTERNET 原则 + §4.1 候选 A 一致；
  - 路径逃逸防护保留（root 外文件 + `..` 抛 `ArgumentError` + `cleanupTempFiles` 对 root 外 temp 抛 `ArgumentError`）；
  - 未新增 `INTERNET` 权限（三处 Manifest 未变更）；
  - 未新增任何权限（仅复用 T027 已声明的 `RECORD_AUDIO`）；
  - 未声称真实录音已实现；
  - 未读取 `key.properties` 内容、未记录密码 / keystore 内容 / 用户目录 keystore 绝对路径；
  - 未 push、未 Tag、未 amend / rebase / reset --hard；
- **Blockers**：无
- **Non-blocking Suggestions**：
  - 未来 T033 任务可在 `PrivacyNoticePage` 中明确说明"音频文件保存到 App 私有目录（`<docs>/audio`），其他应用无法访问"，与既有 SDD §3.6 一致；
  - 本任务 T028A 文档契约校准完成；建议 T029 / T030 / T032 等后续任务执行前在 Primary Agent Findings 中显式引用"deleteIfExists 仅允许删除 root 之下普通文件 + root 外文件抛 `ArgumentError` + root 被 File 包装返回 false"的契约，避免后续任务再次出现表述不一致；
- **Approval**：**Approved**

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
