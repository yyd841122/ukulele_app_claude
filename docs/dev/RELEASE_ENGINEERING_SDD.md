# Release 工程化软件设计文档 (RELEASE_ENGINEERING_SDD)

## 1. Document Status

| 字段 | 值 |
| --- | --- |
| Task ID | `T019_DESIGN_RELEASE_ENGINEERING_PHASE` |
| 基线 Commit | `d49ce4b` |
| 基线 Tag | `v0.1.0-mvp` |
| 当前状态 | 设计阶段（Design Phase） |
| 是否已构建 Release APK / AAB | 否（计划中，未执行） |
| 是否已配置正式签名 | 否（当前 release 临时借用 `signingConfigs.debug`，见 `TECH_DEBT.md` TD-002） |
| 是否实际商店发布 | 否（明确不在本阶段范围） |

> 本文档**不代表**Release 已完成；它是 T019 阶段产出的正式设计基线，供 T020-T024 实施时参照。

## 2. Goals

本阶段（Release 工程化）的可交付目标：

1. **安全签名**：建立正式 Android upload/release 签名方案，签名材料与口令不进入仓库。
2. **版本管理**：明确 `pubspec.yaml` 与 Android `versionName` / `versionCode` 的对应关系与递增规则。
3. **Release APK 构建**：在正式签名下产出 Release APK，可用于本地真机安装验收。
4. **Release AAB 构建**：在正式签名下产出 Release AAB，可用于商店提交（提交动作不在本阶段范围）。
5. **产物验证**：自动校验 APK / AAB 的 applicationId、versionName/versionCode、签名证书、Manifest 权限，并记录 SHA-256 与字节大小。
6. **真机安装与冒烟验收**：由用户在真机上完成 Release APK 的安装、启动、核心流程冒烟与杀进程/强行停止重启验证。
7. **发布检查清单**：沉淀可复用的 Release 工程化检查点文档，供后续迭代复用。

## 3. Non-Goals

明确不在本阶段范围内：

- 真实录音 / 真实音频播放（见 `TECH_DEBT.md` TD-007）
- 麦克风权限 / `RECORD_AUDIO` 权限申请
- 自动调音
- 账号系统、云同步、AI 评分（见 `TECH_DEBT.md` TD-008）
- iOS Release 适配与 TestFlight（见 `TECH_DEBT.md` TD-003）
- 真实商店提交（Google Play / App Store Console 实际点击"发布"动作）
- Gradle、AGP、Kotlin 或 Flutter 无理由升级（见 `TECH_DEBT.md` TD-005）
- 数据库 `schemaVersion` 修改（保持基线 1）
- 产品功能扩张（不变 MVP Scope）
- Level 3 自动化多 Agent 调度（见 `docs/MULTI_AGENT_WORKFLOW.md` §0.3）

## 4. Current-State Inventory（仅记录仓库核实事实）

> 所有条目均来自 T019 调研阶段对仓库的只读核对，不包含任何规划性改动。

### 4.1 Android 工具链

| 项 | 当前值 | 来源 |
| --- | --- | --- |
| Kotlin Gradle Plugin | 2.1.0 | `docs/dev/MVP_ACCEPTANCE.md` §4 |
| Android Gradle Plugin (AGP) | 8.6.0 | `docs/dev/MVP_ACCEPTANCE.md` §4 |
| Gradle | 8.7 | `docs/dev/MVP_ACCEPTANCE.md` §4 |
| JDK | 17 | `docs/dev/MVP_ACCEPTANCE.md` §4 |
| Flutter embedding | v2 | 提交 `7407660`，见 `android/app/src/main/AndroidManifest.xml` `meta-data flutterEmbedding=2` |
| Flutter / Dart SDK | `sdk: ^3.5.4` | `pubspec.yaml` |
| 工具链升级窗口 | 不主动升级（TD-005） | `docs/dev/TECH_DEBT.md` |

### 4.2 applicationId 与版本

| 项 | 当前值 | 来源 |
| --- | --- | --- |
| `namespace` | `com.yupi.ukulele` | `android/app/build.gradle:9` |
| `applicationId` | `com.yupi.ukulele` | `android/app/build.gradle:23` |
| `pubspec.yaml` version | `1.0.0+1`（versionName=1.0.0, versionCode=1） | `pubspec.yaml:19` |
| Android `versionName` | 由 `flutter.versionName` 派生 | `android/app/build.gradle:28` |
| Android `versionCode` | 由 `flutter.versionCode` 派生 | `android/app/build.gradle:27` |

### 4.3 签名配置现状

| 项 | 当前状态 | 来源 |
| --- | --- | --- |
| `signingConfigs.release` | **未定义** | `android/app/build.gradle` |
| `buildTypes.release.signingConfig` | `signingConfigs.debug`（临时借用 debug 键） | `android/app/build.gradle:35` |
| `android/key.properties` | 不存在（仓库内未提交） | 仓库实际状态 |
| 正式 upload/release keystore | 未生成 | 仓库实际状态 |
| `.gitignore` 是否覆盖潜在签名敏感文件 | **完全未定义** `*.jks` / `*.keystore` / `key.properties` 等任何签名相关规则（当前 `.gitignore` 仅有 Flutter 默认条目与 `/android/app/{debug,profile,release}` 路径） | `.gitignore` 实际内容 |

### 4.4 Manifest 权限

| 项 | 当前状态 | 来源 |
| --- | --- | --- |
| `INTERNET` 权限 | 不存在 | `android/app/src/main/AndroidManifest.xml` |
| `RECORD_AUDIO` 权限 | 不存在（仅注释说明） | `android/app/src/main/AndroidManifest.xml:3` |
| 其他运行时权限 | 无 | `android/app/src/main/AndroidManifest.xml` |
| `MainActivity` | 单 launcher Activity，`launchMode="singleTop"` | `android/app/src/main/AndroidManifest.xml:9-29` |

### 4.5 图标与应用名称

| 项 | 当前值 | 来源 |
| --- | --- | --- |
| `android:label` | `Ukulele` | `android/app/src/main/AndroidManifest.xml:6` |
| `android:icon` | `@mipmap/ic_launcher` | `android/app/src/main/AndroidManifest.xml:8` |
| `android:name` | `${applicationName}` | `android/app/src/main/AndroidManifest.xml:7` |

> 本阶段**不重命名、不更换图标、不替换启动图**。

### 4.6 Debug MVP 状态

| 项 | 当前值 | 来源 |
| --- | --- | --- |
| Debug APK 相对路径 | `build/app/outputs/flutter-apk/app-debug.apk` | `docs/dev/MVP_ACCEPTANCE.md` §4 |
| Debug APK 字节大小 | 161,305,625 bytes（≈154 MiB） | `docs/dev/MVP_ACCEPTANCE.md` §4 |
| Debug 真机验收 | 通过（`CDY-AN90`） | `docs/dev/MVP_ACCEPTANCE.md` §5 |
| 全仓测试 | 407 tests passed | `docs/dev/MVP_ACCEPTANCE.md` §3 |
| `flutter analyze` | No issues found | `docs/dev/MVP_ACCEPTANCE.md` §3 |

### 4.7 已知警告与技术债

| 编号 | 内容 | 来源 |
| --- | --- | --- |
| TD-001 | `RecordingPracticeController` 非 autoDispose | `docs/dev/TECH_DEBT.md` |
| TD-002 | Release 签名 / AAB 未配置（当前 release 借调 debug） | `docs/dev/TECH_DEBT.md` |
| TD-003 | iOS 验收未执行 | `docs/dev/TECH_DEBT.md` |
| TD-004 | Debug APK 体积较大，不代表 Release 体积 | `docs/dev/TECH_DEBT.md` |
| TD-005 | 工具链弃用窗口不主动升级 | `docs/dev/TECH_DEBT.md` |
| TD-006 | 本机 `adb` 未加入 PATH（非仓库问题） | `docs/dev/TECH_DEBT.md` |
| TD-007 | 真实音频阶段前置（权限 / 文件 / 隐私 / 平台架构） | `docs/dev/TECH_DEBT.md` |
| TD-008 | 后续产品方向未决定 | `docs/dev/TECH_DEBT.md` |
| TD-009 | 构建环境依赖用户级网络代理配置（非仓库配置） | `docs/dev/TECH_DEBT.md` |

### 4.8 Release APK / AAB 当前状态

- **未产出任何 Release APK**（仓库内仅有 `build/` 由 `.gitignore` 覆盖）
- **未产出任何 Release AAB**
- 当前 `android/app/build.gradle` 中 `buildTypes.release.signingConfig = signingConfigs.debug`，意味着任何后续 `flutter build apk --release` / `flutter build appbundle --release` 实际会用 debug 键签名 → **不得直接执行**（须先在 T020 完成正式签名配置）

## 5. Release Architecture

### 5.1 文件边界

| 边界 | 允许提交 | 必须 `.gitignore` | 仅由用户保管 |
| --- | --- | --- | --- |
| `android/app/build.gradle` | ✅（须加入 `signingConfigs.release` 读取逻辑与 `release { signingConfig signingConfigs.release }`） | — | — |
| `android/app/build.gradle.kts`（若仓库改用） | ✅ | — | — |
| `android/key.properties`（或等价 `keystore.properties`） | ❌ | ✅ | ✅（路径指向 + 密码读取） |
| `*.jks` / `*.keystore` | ❌ | ✅ | ✅（keystore 文件本体） |
| `keyAlias` / `keyPassword` / `storePassword` 实际值 | ❌（不得以任何形式出现在仓库中） | — | ✅ |
| `pubspec.yaml` 的 `version` 字段 | ✅（随版本递增修改） | — | — |
| `build/app/outputs/**` | ❌（构建产物） | ✅（`.gitignore` 已覆盖 `/android/app/release`、`/android/app/profile`、`/android/app/debug`；需补充 AAB 输出目录） | — |
| `docs/dev/RELEASE_ARTIFACTS.md`（产物记录，建议 T022 引入） | ✅（**只记录** SHA-256 + 字节大小 + 文件名 + 构建时间，**不记录密码**） | — | — |

> **结论**：当前 `.gitignore` 已覆盖 `/android/app/{debug,profile,release}` 与 `**/doc/api/`、`build/` 等典型 Flutter 产物，但**未明确覆盖** `*.jks` / `*.keystore` / `key.properties`。T020 必须在 `.gitignore` 中追加以下条目：
>
> ```
> # Android signing materials — never commit
> *.jks
> *.keystore
> key.properties
> android/key.properties
> ```

### 5.2 签名材料读取链路

```
[用户本机] android/ukulele-upload.jks（不进仓库）
        +
[用户本机] android/key.properties（不进仓库，含 storePassword/keyPassword/keyAlias）
        ↓
[构建期] android/app/build.gradle 通过 rootProject.file(...) 读取 key.properties
        ↓
[Gradle] 构造 signingConfigs.release
        ↓
[构建期] buildTypes.release.signingConfig = signingConfigs.release
        ↓
[Flutter] flutter build apk --release / flutter build appbundle --release
        ↓
[产物] build/app/outputs/{flutter-apk, bundle/release}/...
```

### 5.3 安全失败模式

| 触发条件 | 期望行为 | 禁止行为 |
| --- | --- | --- |
| `android/key.properties` 缺失 | Gradle 构建直接失败，报错指向 `key.properties` | ❌ **不允许**自动回退到 `signingConfigs.debug` |
| `key.properties` 字段缺失或为空 | Gradle 构建失败，提示缺失字段 | ❌ 不允许使用空字符串占位继续构建 |
| keystore 文件不存在 / 路径错误 | Gradle 构建失败 | ❌ 不允许静默替换 |
| 用户密码输入错误 | Gradle 构建失败（由 keystore 工具报错） | ❌ 不允许缓存错误密码到任何文件 |
| 用户在 T020 前手动执行 `flutter build apk --release` | 命令本身会失败（因为尚未配置 release signingConfig） | ❌ 不得在 T020 完成前声明"已产出 Release APK" |

### 5.4 产物记录边界

- 仓库内**仅记录**产物的元信息：文件名、字节大小、SHA-256 校验和、applicationId、versionName/versionCode、构建日期、构建机器匿名标识（如 `local-windows`）。
- 仓库内**绝不记录**：密码、密钥、keystore 文件内容、用户本机绝对路径（详见 `§11` 安全约束）。

## 6. Signing Decision Gate（用户确认关卡）

> 在 T020 开始前，以下事项**必须**由用户决定或确认。Agent 不得自行决定或使用占位符继续。

### 6.1 必须由用户确认的事项

| 决策项 | 待用户回答 | 默认建议（仅供用户参考，Agent 不主动采用） |
| --- | --- | --- |
| 是否创建新的正式 Android upload/release keystore | 是 / 否 | 建议：是（标准做法，**不得**复用 debug keystore） |
| keystore 存放位置原则 | 仅本机 / 仅离线备份介质 / 两者并存 | 建议：仅本机 + 离线加密备份介质，**不进仓库** |
| keystore alias 命名 | 用户指定 | 建议：`ukulele-upload` 或 `ukulele-release`（待用户确认） |
| 密码由谁创建与保管 | 用户本人 / 指定保管人 | 建议：仅用户本人；密码不入仓库、不入文档、不入 Agent 报告 |
| 是否同时构建 APK 和 AAB | 是 / 否 | 建议：是（APK 用于本地真机安装验收，AAB 用于潜在商店提交） |
| 密码管理器选择 | 用户指定 | 建议：使用用户已有的密码管理器，不在本项目中引入 |

### 6.2 本任务（T019）不执行的内容

- 不生成任何 keystore 文件
- 不生成任何 `key.properties` 文件
- 不写入任何真实密码、密钥、用户名
- 不写入本机绝对用户目录

### 6.3 文档明文禁令

本文档与 `RELEASE_ENGINEERING_TDD.md` / `MULTI_AGENT_WORKFLOW.md` 修改版中：

- ❌ 不得出现真实密码
- ❌ 不得出现真实密钥（keystore 内容 / alias 字符串示例可使用 `<用户填写>` 占位）
- ❌ 不得出现真实用户名
- ❌ 不得出现本机绝对用户目录（如 `C:\Users\xxx\...`）
- ❌ 不得出现本机代理配置（端口、用户名、密钥）

## 7. Versioning

### 7.1 语义

| 字段 | 位置 | 含义 |
| --- | --- | --- |
| `version`（pubspec.yaml） | 顶层 `version:` | `MAJOR.MINOR.PATCH+BUILDNUMBER`；Android 派生为 `versionName=MAJOR.MINOR.PATCH`、`versionCode=BUILDNUMBER` |
| `versionName` | Android Manifest（由 Flutter 派生） | 用户可见版本号 |
| `versionCode` | Android Manifest（由 Flutter 派生） | 单调递增整数，商店用于识别更新 |

### 7.2 递增规则

| 变更类型 | versionName | versionCode |
| --- | --- | --- |
| 不兼容的产品变更 | MAJOR 自增，MINOR/PATCH 归零 | 自增 |
| 向后兼容的功能新增 | MAJOR 不变，MINOR 自增 | 自增 |
| 修复 / 打磨 | MAJOR.MINOR 不变，PATCH 自增 | 自增 |
| 仅构建元数据变更 | versionName 不变 | **必须** 自增（不可重复） |

> versionCode 在同 applicationId 下不得重复；重复将导致商店拒绝更新或设备无法覆盖安装。

### 7.3 与 Git Commit / Tag 的关系

| 行为 | 规则 |
| --- | --- |
| 发布 commit | 任务对应 commit 必须能在 `git log` 中被清晰检索 |
| Release Tag | 由用户在 GPT 首席架构师复审通过 Release 阶段后**显式创建**（形如 `v0.2.0-release`）；Agent **不得**自行创建或移动 |
| 现有 Tag | **不得**覆盖、删除或移动 `v0.1.0-mvp`（指向 `d49ce4b`） |

### 7.4 推荐新版本号（待用户确认）

- 当前 `pubspec.yaml` version = `1.0.0+1`，基线 Tag = `v0.1.0-mvp`（指向 Debug MVP 验收 commit `ebfe12d` 对应 `d49ce4b` 系列）
- **推荐**下一个 Release 版本号（标记为**待批准**）：
  - `version: 1.0.0+2`（最小递增）→ Tag `v1.0.0-release`
  - 或 `version: 0.2.0+2` → Tag `v0.2.0-release`
- **本任务不替用户做最终决定**；正式版本号须在 T020 由用户在 Signing Decision Gate 一并确认。

## 8. Artifact Plan

### 8.1 产物用途

| 产物 | 用途 | 是否本阶段必须 |
| --- | --- | --- |
| `app-release.apk` | 本地真机安装 / 冒烟验收 / 内部分发 | ✅ 是 |
| `app-release.aab` | 商店提交（实际提交不在本阶段） | ✅ 是（按 6.1 用户确认） |

### 8.2 产物路径

| 类型 | 相对路径 |
| --- | --- |
| Release APK | `build/app/outputs/flutter-apk/app-release.apk` |
| Release AAB | `build/app/outputs/bundle/release/app-release.aab` |

> `.gitignore` 已覆盖 `build/`，产物不会被提交；T020 还需确认 `bundle/release/` 也被覆盖（Flutter 默认行为下 `build/` 已覆盖所有子目录）。

### 8.3 验证项

| 项 | 命令（仅建议，T022 时落地） |
| --- | --- |
| APK 存在 | `dir build\app\outputs\flutter-apk\app-release.apk` |
| AAB 存在 | `dir build\app\outputs\bundle\release\app-release.aab` |
| APK 字节大小 | 记录到产物文档 |
| AAB 字节大小 | 记录到产物文档 |
| SHA-256 | `certutil -hashfile <path> SHA256`（Windows） |
| applicationId | 通过 `aapt dump badging <apk>` 校验（**不假定 adb 在 PATH**） |
| versionName / versionCode | 通过 `aapt dump badging <apk>` 校验 |
| Manifest 权限 | 通过 `aapt dump permissions <apk>` 校验 |
| 签名证书指纹 | 通过 `keytool -printcert -jarfile <apk>` 校验 |

### 8.4 产物不提交

- AAB 不能直接作为普通 APK 安装到设备（用于商店签名分发，不可在 Android 上双击安装）
- Release APK / AAB 均通过 `.gitignore` 排除，**不得**通过 `git add -f` 强制提交

## 9. Acceptance Criteria

Release 工程化阶段完成时，必须**全部满足**：

1. `flutter analyze` 仍为 `No issues found`
2. `flutter test` 全仓通过（基线 407，或后续正确更新后的精确总数，无回归）
3. `.gitignore` 明确覆盖 `*.jks` / `*.keystore` / `key.properties` / `android/key.properties`
4. `android/app/build.gradle` 中 `signingConfigs.release` 与 `buildTypes.release` 配置完整，且未回退到 debug 签名
5. Release APK 构建成功，路径、字节大小、SHA-256 已记录
6. Release AAB 构建成功（如用户在 §6.1 同意构建），路径、字节大小、SHA-256 已记录
7. `aapt dump badging` 校验 applicationId = `com.yupi.ukulele`，versionName 与 versionCode 与 `pubspec.yaml` 一致
8. `aapt dump permissions` 校验 Manifest **不出现** `RECORD_AUDIO` / `INTERNET` / 任何新增运行时权限
9. APK 签名证书指纹已记录，且指纹与 keystore 文件一致
10. 用户在真机上完成 Release APK 的安装、启动、核心流程冒烟、杀进程重启、强行停止重启验收
11. `git status` 工作树 clean；新 commit 不修改 MVP 阶段已有的产品代码、测试、依赖、Android 配置（除 `android/app/build.gradle` 与 `.gitignore` 中明确允许的签名相关条目）
12. GPT 首席架构师基于本任务报告复审通过
13. **任何**敏感文件（`*.jks` / `*.keystore` / `key.properties` / 含密码字符串的 props）**未被** `git ls-files` 跟踪

## 10. Task Breakdown

后续任务拆分（每项独立 Commit、独立报告、独立 GPT 复审）：

| Task ID | 单一目标 | 允许范围 | 停止条件 |
| --- | --- | --- | --- |
| **T020_RELEASE_SIGNING_AND_SENSITIVE_FILE_GUARD** | 建立正式签名读取链路 + `.gitignore` 守护 + 缺失时安全失败 | `android/app/build.gradle` 加入 `signingConfigs.release` 读取逻辑；`.gitignore` 追加签名敏感条目；新增示例 `.gitignore` 行；**不**生成 keystore / key.properties；**不**实际执行 release 构建 | gradle assembleRelease 在缺少 `key.properties` 时失败而非回退 debug；`git ls-files \| grep -E '\.(jks\|keystore)$'` 返回空；`git ls-files \| grep -E 'key\.properties$'` 返回空 |
| **T021_VERSION_METADATA_AND_RELEASE_BUILD** | `pubspec.yaml` 版本元数据 + 正式签名下的 Release APK / AAB 构建 | 修改 `pubspec.yaml` 的 `version` 字段；执行 `flutter build apk --release` 与 `flutter build appbundle --release`（仅在用户已提供 keystore + key.properties 后）；记录产物路径与构建日志摘要（**不记录密码**） | APK 与 AAB 均构建成功；`flutter test` 仍 407 通过；`flutter analyze` 仍无问题；不引入新依赖 |
| **T022_RELEASE_ARTIFACT_AUTOMATED_VERIFICATION** | APK / AAB 静态校验：applicationId / versionName / versionCode / 权限 / 签名证书 / SHA-256 / 字节大小 | 新增校验脚本（Windows 兼容，使用 `certutil` / `aapt`，不假定 `adb` 在 PATH）；新增 `docs/dev/RELEASE_ARTIFACTS.md`（仅元信息）；可新增静态检查类 Dart 测试用于本地断言 | 校验脚本对 APK 与 AAB 全项通过；产物元信息已落盘；任何校验失败必须 fail-fast，不允许"先通过再补" |
| **T023_RELEASE_DEVICE_INSTALL_AND_SMOKE** | Release APK 真机安装、启动、核心流程冒烟、杀进程/强行停止重启验收 | 由用户在本机真机完成；Agent 仅产出验收报告模板与已知限制列表；不修改产品代码 | 用户在报告中勾选所有冒烟项；Agent 不替用户填写"通过"结论 |
| **T024_RELEASE_DOCS_AND_CHECKPOINT** | 汇总 Release 验收报告 + 发布检查清单 + 更新 TASK_LEDGER / TECH_DEBT | 修改 `docs/dev/TASK_LEDGER.md`、`docs/dev/TECH_DEBT.md`（清除 TD-002）；新增 `docs/dev/RELEASE_ACCEPTANCE.md`；不修改产品代码 | 用户完成真机验收 + GPT 首席架构师复审通过；不创建 Git Tag / 不 push |

> 每个任务的停止条件均包含"不自动进入下一任务"。

## 11. Risks and Rollback

| 风险 | 触发场景 | 回滚 / 缓解 |
| --- | --- | --- |
| 密钥泄漏 | keystore / `key.properties` 被提交到仓库 | 立即吊销该 keystore（Google Play App Signing key reset / 重新生成）；轮换所有依赖该签名的产物；`.gitignore` 审计 + 历史清理（按 GitHub Secret Scanning 流程，**不得**继续在已泄漏密钥下构建） |
| 密钥丢失 | 本机 keystore 文件丢失且无离线备份 | 无法恢复已上架应用的签名 → 必须在生成 keystore 的同时做离线加密备份；T020 文档需告知用户该风险 |
| 错误使用 debug 签名冒充 Release | `buildTypes.release.signingConfig = signingConfigs.debug` 残留 | T020 配置完成后必须删除 debug 回退分支；T022 静态校验必须断言 release 签名 ≠ debug 签名 |
| versionCode 重复 | 不同发布 commit 复用同一 versionCode | T022 校验 versionCode 单调递增；TASK_LEDGER 记录每次发布 commit 与 versionCode 对应关系 |
| Release 与 Debug 行为差异 | 例如：debug 启用热重载 / mock 数据 / 跳过证书校验 | Release 验收必须覆盖核心流程冒烟；任何 debug-only 逻辑必须在 T020 / T021 范围之外提前识别并隔离（当前 MVP 不存在该问题，需在 T023 验收中确认） |
| 构建工具警告 | Gradle / AGP / Kotlin 弃用提示 | 不主动升级工具链（TD-005）；若警告影响产物，需独立排期升级任务 |
| 产物误提交 | `git add -f` 强制加入 AAB / APK | `.gitignore` 覆盖 + 仓库根目录增加 pre-commit 钩子检查（待未来单独任务引入）；T019 不引入该钩子 |
| 用户手动覆盖 `pubspec.yaml` 的 version 字段后版本不一致 | 用户在多终端修改 | 版本号变更必须随 commit 同步；TASK_LEDGER 记录每次变更 commit 与 versionCode |
| 工作树不干净时执行 release 构建 | 上一个任务遗留未提交改动 | 每个任务开始前必须 `git status --short` 返回空；T019 已建立的"基线不匹配则停止"机制延伸至 T020-T024 |

## 12. References

- `docs/dev/TASK_LEDGER.md`：任务台账与历史 commit
- `docs/dev/TECH_DEBT.md`：技术债台账（特别是 TD-002 / TD-003 / TD-004 / TD-005 / TD-007）
- `docs/dev/MVP_ACCEPTANCE.md`：MVP 验收基线
- `docs/MULTI_AGENT_WORKFLOW.md`：多 Agent 协作流程
- `pubspec.yaml`：版本与依赖
- `android/app/build.gradle`：Gradle 配置
- `android/app/src/main/AndroidManifest.xml`：Manifest 配置
