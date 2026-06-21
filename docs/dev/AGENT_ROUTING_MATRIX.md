# Agent 路由矩阵 (AGENT_ROUTING_MATRIX)

> 本文档定义"任务类型 → Agent 角色 → Review Agents → 可写范围 → 证据 → 停止条件"的路由表。
> 是 `docs/MULTI_AGENT_WORKFLOW.md` 定义的 Level 1 → Level 2 协作模式的**任务路由层**落地。

## 1. Document Status

| 字段 | 值 |
| --- | --- |
| Task ID | `T021A_ACTIVATE_MULTI_AGENT_ROLE_SYSTEM` |
| 基线 Commit | `d7bac44` |
| 当前状态 | 协作机制（轻量级） |
| 是否自动化多 Agent 调度 | 否（明确不实现） |
| 是否要求外部运行器 | 否 |
| 是否要求联网 | 否 |
| 是否修改生产代码 | 否 |
| 是否修改 `agents/*.md` 角色原文 | 否（仅引用，不重写） |

> 说明：本文档是**轻量协作机制**，不是自动化调度系统。Reviewer 是角色化只读审查协议，不是真实独立进程。

## 2. Core Principles

1. **单一写入 Agent**：同一工作树同一时间只允许一个写入 Agent。任何发现工作树被未授权修改的情况，立即停止并上报用户。
2. **Reviewer 默认只读**：QA Reviewer / Compliance Reviewer / 领域 Reviewer 不得直接修改文件，必须以报告形式提交审查意见。
3. **GPT 首席架构师最终复审**：所有任务报告最终由 GPT 首席架构师复审通过才进入下一任务。
4. **用户掌控高风险关卡**：产品方向、密钥、真机验收、push、Tag 等高风险动作必须由用户决定；Agent 不得代写"通过"。
5. **每个任务必须声明角色**：Prompt 与最终报告必须包含 `Primary Agent` 与 `Review Agents`，缺一项视为报告不完整。
6. **每个任务必须记录证据**：按 `AGENT_REVIEW_TEMPLATE.md` 输出 Primary Report + Reviewer Report。
7. **低风险任务可少 Reviewer，高风险任务必须 ≥2 Reviewer**：典型高风险（密钥、schema、权限、构建发布）必须包含 QA Reviewer + Compliance Reviewer。
8. **不为"多 Agent 感"加角色**：每个 Reviewer 必须能产生可观察的证据或拦截价值；形式主义角色必须删除。

## 3. Agent Registry

> 角色原文在 `agents/*.md`。本表仅做**路由维度摘要**，不重写角色职责。

| 角色 ID | 主要职责 | 是否可写 | 典型 Reviewer 职责 | 适用任务类型 | 禁止事项 |
| --- | --- | --- | --- | --- | --- |
| `00-chief-architect` | 架构决策、任务拆分、最终审核、范围守卫 | 只审不写（仅在文档任务中可写架构/任务台账） | Chief 复审：架构一致性、SDD/TDD 一致性、MVP Scope 守护 | 架构变更、任务拆分、范围决策、文档基线 | 不直接写业务代码；不越权审批 Scope |
| `01-product-manager` | PRD、MVP Scope、用户故事、优先级 | 只写产品文档 | PM 复审：需求范围、用户故事验收标准 | 产品文档、范围决策、用户故事 | 不写代码；不做技术架构决策 |
| `02-flutter-architect` | Flutter 项目结构、Riverpod / Drift / go_router 架构、依赖管理 | 可写（仅限允许范围） | Flutter 架构复审：Feature 划分、Provider 边界、依赖版本 | 架构变更、依赖调整、跨 feature 接口 | 不写 UI 细节；不绕过 MVP Scope |
| `03-mobile-ui-engineer` | UI 页面与组件、Material 3 样式、交互 | 可写（仅限允许范围） | UI 复审：页面渲染、Material 3 一致性、布局适配 | UI 页面、文案、可访问性、响应式布局 | 不改数据模型；不做架构决策 |
| `04-audio-engineer` | 麦克风权限、录音、播放、调音器 | 可写（仅限允许范围） | 音频复审：录音链路、权限流程、调音器算法 | 音频架构、录音/回放、音频文件生命周期 | 不做 AI 评分；不做网络音频传输 |
| `05-music-domain-expert` | 和弦库、练习路线、指法图、节奏内容 | 可写（仅限允许范围） | 音乐内容复审：和弦按法准确性、练习难度梯度 | 音乐内容、教学文案、练习计划 | 不写代码；不引入未授权商业内容 |
| `06-local-data-engineer` | Drift 数据库、Repository、数据迁移 | 可写（仅限允许范围） | 数据复审：schema 变更、Repository 契约、迁移正确性 | 数据库、Repository、迁移、备份恢复 | 不做云端数据库；不做云同步 |
| `07-qa-reviewer` | 测试策略、验收标准、回归、Agent 输出审查 | 默认只读 | QA 复审：测试覆盖、边界条件、回归、diff 范围、构建产物 | 任何代码 / 文档 / 产物 / 报告审查 | 不直接修复 Bug；不绕过 MVP Scope |
| `08-compliance-reviewer` | 麦克风隐私、录音数据安全、版权、上架政策 | 默认只读 | 合规复审：权限声明、隐私政策、版权风险、用户数据 | 权限、隐私、内容版权、上架、签名密钥保护 | 不做技术实现；不绕过 MVP Scope |

## 4. Routing Table

> 每类任务至少指定：Primary / Required Review / Optional Review / Writable Files Owner / Evidence Required / Stop Conditions。

### 4.1 Release 签名与构建

| 项 | 值 |
| --- | --- |
| Primary | `02-flutter-architect`（构建脚本）/ `00-chief-architect`（设计阶段） |
| Required Review | `07-qa-reviewer`、`08-compliance-reviewer` |
| Optional Review | `00-chief-architect` |
| Writable Files Owner | `android/app/build.gradle`、`.gitignore`、`pubspec.yaml`（仅 `version`）、文档 |
| Evidence Required | Release 失败/成功命令退出码、产物路径、SHA-256、aapt 输出、不出现密码字面量 |
| Stop Conditions | 工作树不 clean；HEAD ≠ 基线；构建脚本无防御性失败路径；`buildTypes.release` 残留 debug 回退 |

### 4.2 Release 产物验证

| 项 | 值 |
| --- | --- |
| Primary | `07-qa-reviewer` |
| Required Review | `02-flutter-architect`、`08-compliance-reviewer` |
| Optional Review | `00-chief-architect` |
| Writable Files Owner | 校验脚本（独立目录）、`docs/dev/RELEASE_ARTIFACTS.md`、可选静态 Dart 测试 |
| Evidence Required | 校验命令全项通过、applicationId/versionName/versionCode/权限/签名/SHA-256/字节大小落盘 |
| Stop Conditions | 任何校验项失败未 fail-fast；产物元信息缺失；出现密码字面量；产物被 git 跟踪 |

### 4.3 Release 真机验收

| 项 | 值 |
| --- | --- |
| Primary | 用户本人（真机操作主导） |
| Required Review | `07-qa-reviewer`、`08-compliance-reviewer` |
| Optional Review | `03-mobile-ui-engineer` |
| Writable Files Owner | 验收报告模板（Agent 产出） |
| Evidence Required | 用户勾选冒烟项；Agent 不代写"通过" |
| Stop Conditions | Agent 替用户勾选"通过"；无用户真机证据；冒烟项未覆盖关键路径 |

### 4.4 Flutter UI 布局与文案

| 项 | 值 |
| --- | --- |
| Primary | `03-mobile-ui-engineer` |
| Required Review | `07-qa-reviewer` |
| Optional Review | `02-flutter-architect`、本地化负责人 |
| Writable Files Owner | UI 页面文件、Widget 组件、相关测试、UI 文案常量 |
| Evidence Required | Widget 测试、analyze 通过、视觉/交互回归 |
| Stop Conditions | UI 直接耦合业务逻辑；引入未授权依赖；未跑通 widget 测试 |

### 4.5 本地数据库 / Drift / Repository

| 项 | 值 |
| --- | --- |
| Primary | `06-local-data-engineer` |
| Required Review | `02-flutter-architect`、`07-qa-reviewer` |
| Optional Review | `08-compliance-reviewer`（如涉及用户数据存储） |
| Writable Files Owner | Drift 数据库文件、Repository 实现、相关测试 |
| Evidence Required | schema 变更、迁移脚本、CRUD 测试、Repository 契约测试 |
| Stop Conditions | 未经 Chief Architect 批准的 `schemaVersion` 自增；无迁移测试；数据模型与 Repository 契约不一致 |

### 4.6 练习计划和音乐内容

| 项 | 值 |
| --- | --- |
| Primary | `05-music-domain-expert` |
| Required Review | `07-qa-reviewer`、`08-compliance-reviewer` |
| Optional Review | `01-product-manager`（需求一致性） |
| Writable Files Owner | 练习计划常量、内置和弦/单音数据、相关测试 |
| Evidence Required | 内容正确性审查、版权来源标注、难度梯度合理 |
| Stop Conditions | 引入未授权商业内容；和弦按法错误；难度不匹配目标用户 |

### 4.7 真实录音与播放

| 项 | 值 |
| --- | --- |
| Primary | `04-audio-engineer` |
| Required Review | `02-flutter-architect`、`08-compliance-reviewer`、`07-qa-reviewer` |
| Optional Review | `00-chief-architect` |
| Writable Files Owner | 音频服务、权限处理、UI 页面、相关测试 |
| Evidence Required | 权限流程、录音链路、播放链路、文件生命周期、真机录音验证 |
| Stop Conditions | 未声明 `RECORD_AUDIO` 权限即调用；录音文件未受控；权限被拒时无降级方案 |

### 4.8 权限与隐私

| 项 | 值 |
| --- | --- |
| Primary | `08-compliance-reviewer` |
| Required Review | `02-flutter-architect`、`07-qa-reviewer` |
| Optional Review | `04-audio-engineer`（如涉及音频权限） |
| Writable Files Owner | Manifest 权限清单、隐私文档、权限申请 UI 文案 |
| Evidence Required | 最小权限原则证据、用户知情同意、权限拒绝降级 |
| Stop Conditions | 引入未声明权限；权限使用与目的不一致；无用户拒绝降级方案 |

### 4.9 测试与回归

| 项 | 值 |
| --- | --- |
| Primary | `07-qa-reviewer` |
| Required Review | 域内执行 Agent（如 `02-flutter-architect` / `06-local-data-engineer`） |
| Optional Review | `00-chief-architect` |
| Writable Files Owner | 测试文件、`test/` 目录、覆盖率配置 |
| Evidence Required | 测试计数、analyze、build、回归矩阵勾选 |
| Stop Conditions | 测试计数下降未说明；新增/删除测试未记录；存在未关闭资源或 sleep 类脆弱测试 |

### 4.10 文档 / 交接 / 台账

| 项 | 值 |
| --- | --- |
| Primary | `00-chief-architect`（任务台账、ADR、SDD/TDD） |
| Required Review | `07-qa-reviewer`（范围/格式）、`08-compliance-reviewer`（合规） |
| Optional Review | 任意领域 Reviewer（按文档内容） |
| Writable Files Owner | `docs/**/*.md`（明确允许范围） |
| Evidence Required | 文档与基线一致、跨文档无矛盾、未记录敏感信息 |
| Stop Conditions | 出现真实密码/密钥/keystore 路径；文档与实际行为矛盾；未按台账格式追加 |

### 4.11 产品范围决策

| 项 | 值 |
| --- | --- |
| Primary | `01-product-manager` |
| Required Review | `00-chief-architect`（强制联签）、`07-qa-reviewer` |
| Optional Review | `08-compliance-reviewer`（涉及权限/内容） |
| Writable Files Owner | PRD、MVP_SCOPE、ROADMAP |
| Evidence Required | 需求评审记录、范围影响评估、Scope 变更审批 |
| Stop Conditions | Scope 变更无 Chief Architect 联签；未评估 MVP 影响；绕过台账记录 |

## 5. Current Release Phase Routing（T022-T024）

### 5.1 T022_RELEASE_ARTIFACT_AUTOMATED_VERIFICATION

| 项 | 值 |
| --- | --- |
| Primary | `07-qa-reviewer` |
| Required Review | `02-flutter-architect`、`08-compliance-reviewer` |
| Optional Review | `00-chief-architect` |
| Writable Files Owner | 校验脚本（独立目录）、`docs/dev/RELEASE_ARTIFACTS.md`、可选静态 Dart 测试 |
| Evidence Required | 校验命令全项通过、applicationId/versionName/versionCode/权限/签名/SHA-256/字节大小落盘、不出现密码字面量 |
| Stop Conditions | 任何校验项失败未 fail-fast；产物元信息缺失；产物被 `git ls-files` 跟踪；引入新依赖 |

### 5.2 T023_RELEASE_DEVICE_INSTALL_AND_SMOKE

| 项 | 值 |
| --- | --- |
| Primary | `07-qa-reviewer` |
| Required Review | `03-mobile-ui-engineer`、`08-compliance-reviewer` |
| Optional Review | `00-chief-architect` |
| Writable Files Owner | 验收报告模板（Agent 产出），不修改产品代码 |
| Evidence Required | 用户勾选冒烟项（用户确认真机结果）；Agent 不代写"通过"；杀进程/强行停止重启验证 |
| Stop Conditions | Agent 替用户勾选"通过"；冒烟项未覆盖关键路径；缺少杀进程/强行停止重启验证 |

### 5.3 T024_RELEASE_DOCS_AND_CHECKPOINT

| 项 | 值 |
| --- | --- |
| Primary | `00-chief-architect`（或文档角色） |
| Required Review | `07-qa-reviewer`、`08-compliance-reviewer` |
| Optional Review | `01-product-manager`（如涉及范围决策） |
| Writable Files Owner | `docs/dev/RELEASE_ACCEPTANCE.md`、`docs/dev/TASK_LEDGER.md`、`docs/dev/TECH_DEBT.md` |
| Evidence Required | 验收基线汇总、台账更新、技术债清理、Scope 状态一致 |
| Stop Conditions | 文档与实际行为矛盾；未引用实际产物元信息；未引用实际真机验收结论 |

## 6. Future Audio MVP Routing

> 真实录音 / 真实播放阶段（T025+）的初步路由规划。具体任务以 GPT 首席架构师拆分 Prompt 为准。

| 子领域 | Primary | Required Review | Optional Review | 关键约束 |
| --- | --- | --- | --- | --- |
| 音频架构（record / just_audio 选型、权限方案） | `04-audio-engineer` | `02-flutter-architect`、`08-compliance-reviewer` | `00-chief-architect` | 不引入云音频；不引入 AI 评分 |
| 音频文件生命周期（本地存储、清理、删除） | `04-audio-engineer` | `06-local-data-engineer`、`07-qa-reviewer` | `08-compliance-reviewer` | 用户可删除；不静默占用空间 |
| 权限与隐私（`RECORD_AUDIO` 声明、拒绝降级、隐私政策） | `08-compliance-reviewer` | `04-audio-engineer`、`07-qa-reviewer` | `02-flutter-architect` | 最小权限；用户知情；拒绝不崩溃 |
| UI 录音体验（页面、Controller、Wave/进度展示） | `03-mobile-ui-engineer` | `04-audio-engineer`、`07-qa-reviewer` | `02-flutter-architect` | UI 不耦合音频服务；异常有降级 |
| 真机弹唱验收 | `07-qa-reviewer` | `04-audio-engineer`、`08-compliance-reviewer` | `00-chief-architect` | 用户本人真机操作；Agent 不代写"通过" |

## 7. Stop Conditions 通用规则

无论任务类型，命中以下任一即**立即停止**：

1. 工作树不 clean / HEAD ≠ 基线 / 出现未授权改动
2. `key.properties` / `*.jks` / `*.keystore` 出现在 diff 或被 `git ls-files` 跟踪
3. 真实密码 / keystore 内容 / 用户本机绝对路径出现在报告或文档
4. Agent 自行 push、创建 Tag、amend、rebase、reset --hard
5. 报告缺失 Primary Agent / Review Agents / Evidence / 验证结果任一字段
6. 报告把"用户手工验收"写成"自动通过"
7. 修改了任务未明确允许的文件
8. 任何校验失败未 fail-fast
9. 工具链/依赖无理由升级
10. 越权审批 Scope 变更

## 8. References

- `docs/MULTI_AGENT_WORKFLOW.md`：多 Agent 协作流程总览（Level 1 / Level 2 / Level 3 分级）
- `docs/dev/AGENT_REVIEW_TEMPLATE.md`：任务报告与审查模板
- `docs/dev/AGENT_QUALITY_METRICS.md`：协作质量度量
- `agents/*.md`：各角色职责原文（本文档不重写）
- `docs/dev/RELEASE_ENGINEERING_SDD.md`：Release 工程化 SDD
- `docs/dev/RELEASE_ENGINEERING_TDD.md`：Release 工程化 TDD
- `docs/dev/TASK_LEDGER.md`：任务台账
