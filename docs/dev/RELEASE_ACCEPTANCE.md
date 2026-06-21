# Release 验收检查点 (RELEASE_ACCEPTANCE)

> 本文档是 Android **Release 工程化阶段**的正式验收检查点。汇总 T019-T023 阶段产出的 Release 签名、构建、产物验证与真机验收证据。
>
> ⚠️ 本文档**不代表**应用商店提交，**不代表**真实录音与回放能力已实现，**不代表**iOS 验收完成，**不代表**Debug 数据可迁移到 Release。
> ⚠️ 本文档不记录 `key.properties` 内容、keystore 内容、用户目录下 keystore 绝对路径或任何密码。
> ⚠️ 本检查点基于**用户单台真机（HUAWEI CDY-AN90，Android 10 / SDK 29）**的全新安装验收；不构成多设备 / 多 Android 版本 / 多厂商 ROM 适配证据。

## Document Status

| 字段 | 值 |
| --- | --- |
| Task ID | `T024_RELEASE_DOCS_AND_CHECKPOINT` |
| 当前基线 Commit | `e181ba2` |
| MVP Tag | `v0.1.0-mvp` → `d49ce4b` |
| 当前版本 | `1.0.0+2`（versionName=`1.0.0`, versionCode=`2`） |
| 状态 | Android Release 工程化验收完成，等待 GPT 首席架构师复审 |
| 是否创建新 Tag | **No**（不创建 `v0.2.0-release` 或任何新 Tag） |
| 是否 push | **No** |
| 是否开始 T025 | **No**（未进入真实音频阶段） |
| 是否开始真实录音 | **No** |

> 本检查点不修改 `v0.1.0-mvp` Tag 的指向（仍为 `d49ce4b`）；不创建任何新 Tag；不 push 任何 commit；不进入真实音频 / 录音 / 回放 / 调音 / 麦克风权限 / AI 评分 / 账号 / 云同步阶段。

## Scope

### 本阶段已完成

- Release 签名框架（`build.gradle` 中 `signingConfigs.release` + 仓库外 `android/key.properties` 读取链路）
- 正式 upload keystore 接入（用户本机，仓库外，未跟踪）
- 版本号更新（`pubspec.yaml`: `1.0.0+1` → `1.0.0+2`）
- Release APK 构建（路径 `build/app/outputs/flutter-apk/app-release.apk`）
- Release AAB 构建（路径 `build/app/outputs/bundle/release/app-release.aab`）
- 静态产物验证（`tool/verify_release_artifacts.dart` 全部通过）
- Release APK 真机安装（用户本机 HUAWEI CDY-AN90）
- 真机冒烟验收（用户 18 项手工验收全部 Passed）
- Release 检查点文档（本文档）
- 任务台账 / 技术债台账 / 协作质量度量更新

### 本阶段不包括

- 应用商店提交（Google Play / 任何 App Store 实际点击"发布"动作）
- iOS 验收（iOS Runner / TestFlight / Info.plist 适配）
- 真实录音（`record` / `flutter_sound` / `permission_handler` 等依赖未引入；`RECORD_AUDIO` 未声明）
- 真实播放（`just_audio` 等依赖未引入）
- 麦克风权限（`RECORD_AUDIO` 未声明，无运行时权限弹窗）
- AI 评分
- 云同步
- 账号系统

## Release Timeline

按任务汇总 T019-T024 阶段的执行轨迹。所有任务的详细证据由对应任务文档承载。

| Task ID | 单一目标 | 关键交付 | 状态 |
| --- | --- | --- | --- |
| `T019_DESIGN_RELEASE_ENGINEERING_PHASE` | Release 工程化阶段设计 | 新建 `RELEASE_ENGINEERING_SDD.md` / `RELEASE_ENGINEERING_TDD.md`；`MULTI_AGENT_WORKFLOW.md` §8 追加 | 通过 |
| `T020_RELEASE_SIGNING_AND_SENSITIVE_FILE_GUARD` | 签名读取链路 + 敏感文件保护 | `android/app/build.gradle` 加入 release signing 读取逻辑；`.gitignore` 追加 `*.jks` / `*.keystore` / `key.properties` / `android/key.properties` 保护 | 通过 |
| `T020_FIX_REMOVE_DEBUG_SIGNING_FALLBACK` | 移除 debug 签名回退 + 任务图守卫 | `buildTypes.release.signingConfig` 不再指向 debug；新增 `gradle.taskGraph.whenReady` 守卫拦截聚合任务绕过 | 通过 |
| `T020_FIX_AGGREGATE_SIGNING_CONFIGURATION` | 聚合任务签名配置（实际由 T020_FIX_REMOVE_DEBUG_SIGNING_FALLBACK 的 `gradle.taskGraph.whenReady` 守卫解决；本条为台账中显式记号） | 同 T020_FIX_REMOVE_DEBUG_SIGNING_FALLBACK | 通过 |
| `T020_FIX_RELEASE_SIGNING_ABSOLUTE_STORE_FILE_PATH` | 修复 `storeFile` 绝对路径解析 + 显式 setter 调用 + 消除 Groovy `String.metaClass.call` 拦截导致的密码回显风险 | 新增 `resolveReleaseStoreFile` helper 统一处理 Windows drive / UNC / Unix 绝对路径 + 仓库外相对路径；`storePassword` / `keyAlias` / `keyPassword` setter 改为显式方法调用 | 通过 |
| `T021_RETRY_VERSION_METADATA_AND_RELEASE_BUILD` | 重启 T021：版本号升 `1.0.0+1` → `1.0.0+2` + 用户正式 keystore 下的 Release APK / AAB 构建 + 基础验证 | `pubspec.yaml` version 字段单行修改；APK 58,558,487 bytes / AAB 57,332,407 bytes 构建成功 | 通过 |
| `T021A_ACTIVATE_MULTI_AGENT_ROLE_SYSTEM` | 激活多 Agent 角色路由系统（轻量协作机制） | 新建 `AGENT_ROUTING_MATRIX.md` / `AGENT_REVIEW_TEMPLATE.md` / `AGENT_QUALITY_METRICS.md`；`MULTI_AGENT_WORKFLOW.md` §10 追加四层模型 | 通过 |
| `T022_RELEASE_ARTIFACT_AUTOMATED_VERIFICATION` | Release 产物自动验证 + 元信息落盘 | 新建 `tool/verify_release_artifacts.dart`（Dart 标准库 SHA-256 + apksigner/jarsigner/aapt 静态断言）；新建 `RELEASE_ARTIFACTS.md`（仅元信息，无敏感数据） | 通过 |
| `T022A_RECORD_COMMAND_DISCIPLINE_INCIDENT` | 补充记录 T022 命令纪律违规事件并校准多 Agent 质量度量 | `AGENT_QUALITY_METRICS.md` §4.1 T022 Scorecard 追加 `Command discipline violation = Yes` 字段 + §4.2 T022A Scorecard | 通过 |
| `T023_RELEASE_DEVICE_INSTALL_AND_SMOKE` | Release APK 真机安装 + 启动验证 + 用户手工冒烟验收 | 新建 `RELEASE_DEVICE_ACCEPTANCE.md`（含 18 项用户手工冒烟 + adb 自动化证据 + Mobile UI/Compliance Reviewer Approved） | 通过 |
| `T024_RELEASE_DOCS_AND_CHECKPOINT` | 本任务：Release 验收检查点 + 台账更新 + 技术债校准 + 协作质量度量 | 本文档 + `TASK_LEDGER.md` T024 条目 + `TECH_DEBT.md` 校准 + `AGENT_QUALITY_METRICS.md` §4.4 T024 Scorecard | 进行中（本任务） |

## Build and Artifact Evidence

来源：`docs/dev/RELEASE_ARTIFACTS.md`（T022 阶段落盘）。

| 字段 | 值 | 来源 |
| --- | --- | --- |
| APK 相对路径 | `build/app/outputs/flutter-apk/app-release.apk` | T022 |
| APK 字节大小 | `58,558,487` bytes（≈ 55.8 MiB） | `certutil -hashfile` + 脚本内自实现 SHA-256 |
| APK SHA-256 | `3af73cafba05de89d88843075d33d5fe0c5425c129c54c7226a152910a90753b` | `certutil -hashfile` |
| AAB 相对路径 | `build/app/outputs/bundle/release/app-release.aab` | T022 |
| AAB 字节大小 | `57,332,407` bytes（≈ 54.7 MiB） | `certutil -hashfile` + 脚本内自实现 SHA-256 |
| AAB SHA-256 | `a782231edc6dcc31044f936a8b6ed0e09b211da69167e08adc9636241326d233` | `certutil -hashfile` |
| `applicationId` | `com.yupi.ukulele` | `aapt dump badging` |
| `versionName` | `1.0.0` | `aapt dump badging` |
| `versionCode` | `2` | `aapt dump badging` |
| `minSdk` | `24` | `aapt dump badging`（`sdkVersion:`） |
| `targetSdk` | `36` | `aapt dump badging`（`targetSdkVersion:`） |
| `compileSdk` | `36` | `aapt dump badging`（`compileSdkVersion=`） |
| native-code ABI | `arm64-v8a`, `armeabi-v7a`, `x86_64` | `aapt dump badging`（`native-code:`） |
| Release 证书 SHA-256 | `e88687e53b272c86d20611c1045fc00d2fd4ca321672b1eec180d7543dc28591` | `apksigner verify --print-certs` |
| Debug 证书 SHA-256 | `5e46d372a98f40e250a74e249ff318c27b65e3c259801a70b807508a0f4e8662` | `apksigner verify --print-certs` |
| Release 与 Debug 证书不同 | **Yes** | 对比 3.3 |

> 本文档**不**记录 `key.properties` 内容、密码、keystore 内容、用户目录下 keystore 绝对路径。
> 本文档**不**记录 alias 名称（仅证书指纹）。证书 DN 形如 `CN=yyd, OU=yyd, O=yyd, L=yyd, ST=yyd, C=yyd`（用户保管的真实 keystore），Debug 证书 DN 形如 `C=US, O=Android, CN=Android Debug`。

## Device Acceptance Evidence

来源：`docs/dev/RELEASE_DEVICE_ACCEPTANCE.md`（T023 阶段落盘）。

| 字段 | 值 | 来源 |
| --- | --- | --- |
| 设备型号 | `HUAWEI CDY-AN90` | `adb shell getprop ro.product.model` + `ro.product.manufacturer` |
| Android 版本 | `10` | `adb shell getprop ro.build.version.release` |
| Android SDK | `29` | `adb shell getprop ro.build.version.sdk` |
| device serial（部分脱敏） | 后 4 位 `5219` | `adb devices -l` |
| 安装模式 | **卸载后全新安装** | 用户授权卸载 + `pm path` 新旧路径不同 |
| 签名不兼容 | **Yes**（首次 `adb install -r` 报 `INSTALL_FAILED_UPDATE_INCOMPATIBLE: signatures do not match`） | `adb install -r` 首次输出 |
| 用户确认卸载 | **Yes**（用户在第二轮交互中明确回复"确认卸载，允许继续"） | 用户交互记录 |
| 数据清除 | **Yes**（卸载会一并清除 App 私有数据目录 `/data/user/0/com.yupi.ukulele`） | Android 卸载语义 + 用户授权 |
| Release APK 安装 | **成功**（`adb install -r` 重试 `Success`） | `adb install -r` 重试输出 |
| App 启动 | **成功**（`mResumedActivity = com.yupi.ukulele/.MainActivity`、`state=RESUMED`、`nowVisible=true`） | `adb shell dumpsys activity activities` |
| 用户 18 项手工冒烟验收 | **全部 Passed** | User confirmed（每项均有 `User confirmed` 来源） |

### 验收范围明确边界

- 本次验收**不**证明旧 Debug 数据可迁移到 Release（旧 Debug 包在用户授权后被卸载，私有数据目录 `/data/user/0/com.yupi.ukulele` 已被清除）。
- 本次验收**只**覆盖**一台**真机（HUAWEI CDY-AN90 / Android 10 / SDK 29）。
- 本次验收**不**代表 iOS 验收；iOS Release 适配与 TestFlight 不在本阶段范围（见 `TECH_DEBT.md` TD-003）。
- AAB 未直接安装（AAB 是 Google Play 用于按设备架构分发 APK 的打包格式，需要 `bundletool` 或 Play Console 转换为 split APK 后才能安装）。

## Automated Validation

| 项 | 命令 / 操作 | 实际结果 | 通过条件 | 实际是否通过 |
| --- | --- | --- | --- | --- |
| AV-1 | `dart run tool/verify_release_artifacts.dart` | `VERIFY_OK: all required checks passed.` | 退出码 0 + 全部断言通过 | ✅ |
| AV-2 | `flutter analyze` | `No issues found! (ran in 3.4s)` | `No issues found` | ✅ |
| AV-3 | `flutter test` | `All tests passed!`（407 项） | 407 tests passed | ✅ |
| AV-4 | APK / AAB 静态验证 | `dart run tool/verify_release_artifacts.dart` 内含 SHA-256 / 字节大小 / applicationId / versionName / versionCode / minSdk / targetSdk / compileSdk / ABI / 签名方案 / 证书指纹 | 全项通过 | ✅ |
| AV-5 | 签名检查 | APK Signature Scheme v2 / v3 / v4 均 true + Release 证书 SHA-256 = `e88687e5…d28591` + Debug 证书 SHA-256 = `5e46d372…4e8662` + 两者不同 | 全部满足 | ✅ |
| AV-6 | 权限检查 | `aapt dump permissions` 仅含 `com.yupi.ukulele.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`（AGP 自动注入，非业务权限）；**未**声明 `RECORD_AUDIO` / `INTERNET` | 无业务权限 | ✅ |
| AV-7 | 敏感文件跟踪检查 | `git ls-files android/key.properties` / `*.jks` / `*.keystore` / `build/app/outputs/**` 四项均返回空 | 全部为空 | ✅ |

> 本检查点**不**重新构建 APK / AAB；构建产物 SHA-256 / 字节大小沿用 T022 落盘值；本任务执行时 `verify_release_artifacts.dart` 重新跑通作为最终断言。

## Permissions and Privacy

| 项 | 状态 | 来源 |
| --- | --- | --- |
| 无 `RECORD_AUDIO` 权限声明 | Yes | `aapt dump permissions`（`RELEASE_ARTIFACTS.md` §4） |
| 无 `INTERNET` 权限声明 | Yes | `aapt dump permissions`（`RELEASE_ARTIFACTS.md` §4） |
| 不申请麦克风 | Yes | Manifest 未声明 `RECORD_AUDIO` + 用户真机冒烟 #8 "调音器无麦克风请求" Passed |
| 不调用真实麦克风 | Yes | Manifest 未声明 `RECORD_AUDIO` + 调音器页面仅手动调音辅助（无 `record` / `just_audio` / `permission_handler` 等依赖） |
| 模拟录音仍非真实音频 | Yes | `RecordingPracticeController` 硬编码 `audioFilePath: null` + `PracticeRecord.audioFilePath` 始终为 `null` + 用户真机冒烟 #9 / #10 |
| `audioFilePath` 仍不代表真实音频文件 | Yes | 数据库 schema 占位列保留为 `null`，无任何实际写入路径 |
| `android/key.properties` ignored / untracked | Yes | `git ls-files android/key.properties` 返回空；`git check-ignore -v android/key.properties` 命中 `android/.gitignore:11:key.properties` |
| JKS / keystore 未被 Git 跟踪 | Yes | `git ls-files "*.jks"` / `"*.keystore"` 返回空 |
| 构建产物未被 Git 跟踪 | Yes | `git ls-files build/app/outputs/flutter-apk/app-release.apk` / `build/app/outputs/bundle/release/app-release.aab` 返回空 |

## Multi-Agent Evidence

本阶段（Release 工程化 T019-T024）多 Agent 协作机制运转情况：

- **T021A 激活轻量角色路由机制**：
  - 新建 `AGENT_ROUTING_MATRIX.md`（L2 任务路由层）
  - 新建 `AGENT_REVIEW_TEMPLATE.md`（L3 报告协议层）
  - 新建 `AGENT_QUALITY_METRICS.md`（L4 效果评估层）
  - `MULTI_AGENT_WORKFLOW.md` §10 追加协作四层模型
  - 协作机制本质：**轻量角色路由 + 只读 Reviewer + GPT 复审**，**不是**自动化多 Agent 调度系统
  - Reviewer 是**角色化只读审查协议**，不是真实独立进程

- **T022 使用 QA Primary + Flutter/Compliance Reviewer**：
  - Primary: `07-qa-reviewer`
  - Reviewers: `02-flutter-architect`, `08-compliance-reviewer`
  - 两个 Reviewer 均给 `Approved`，无 Blocker
  - `Collaboration Value = Medium`（本任务为静态校验脚本，元信息已知，未发现重大缺陷）

- **T022A 记录命令纪律事件**：
  - T022 执行过程中曾使用 `where flutter 2>&1 | head -5` 等组合命令探测环境，违反"禁止管道 / 重定向 / 输出截断 helper / 复合命令"的固定命令纪律
  - 违规命令经核查属只读环境探测，无文件修改、无 `key.properties` 内容读取、无密码泄露、无产物验证影响
  - T022 主结论（产物静态验证通过）保持不变；T022A 任务将违规如实回填到 `AGENT_QUALITY_METRICS.md` §4.1 T022 Scorecard

- **T023 使用 QA Primary + UI/Compliance Reviewer**：
  - Primary: `07-qa-reviewer`
  - Reviewers: `03-mobile-ui-engineer`, `08-compliance-reviewer`
  - 两个 Reviewer 均给 `Approved`，无 Blocker
  - `Collaboration Value = High`（Mobile UI Reviewer 确认 18 项覆盖完整性 + 大字体/溢出检查独立成项 + 模拟录音文案与 SDD/TDD 一致；Compliance Reviewer 在签名不兼容的高风险点上独立审查了用户授权证据链）

- **本阶段发现和记录的质量问题**：

| 任务 | 问题 | 拦截方 | 修复任务 |
| --- | --- | --- | --- |
| T020 | `buildTypes.release.signingConfig` 残留 `signingConfigs.debug` 回退 | GPT 复审 | `T020_FIX_REMOVE_DEBUG_SIGNING_FALLBACK` |
| T020 | 聚合任务（`build` / `assemble` / `check`）可绕过 `gradle.startParameter.taskNames` 检查 | GPT 复审 | `T020_FIX_REMOVE_DEBUG_SIGNING_FALLBACK` 新增 `gradle.taskGraph.whenReady` 守卫 |
| T020 | `storeFile` 绝对路径解析缺失 + Groovy `String.metaClass.call` 拦截导致密码值在 Gradle 异常日志回显 | 任务验证发现 | `T020_FIX_RELEASE_SIGNING_ABSOLUTE_STORE_FILE_PATH` 改为显式方法调用 + 路径解析 helper |
| T021 | 首次多 Agent 报告的 Reviewer 证据不完整 | Reviewer 报告观察 | `T021A` 建立 Review Template 标准化 |
| T022 | 命令纪律违规（管道 / 重定向 / `head` 输出截断） | GPT 复审 + 流程自查 | `T022A_RECORD_COMMAND_DISCIPLINE_INCIDENT` 补录 |

## Known Limitations

明确列出**本检查点不覆盖**的能力与**本阶段范围外**的事项：

1. **未进行应用商店提交**：AAB 不可双击安装到 Android 设备；Google Play / 任何 App Store 实际点击"发布"动作不在本阶段范围。
2. **未创建 Release Tag**：不创建 `v0.2.0-release` 或任何新 Tag；`v0.1.0-mvp` 仍指向 `d49ce4b` 且未被修改。
3. **未 push 当前 Release 提交**：T019-T023 的本地 commit 保留在本地工作树，未 push 至 origin。
4. **未进行 iOS 验收**：iOS Release 适配与 TestFlight 不在本阶段范围（见 `TECH_DEBT.md` TD-003）。
5. **未实现真实录音与回放**：`record` / `just_audio` / `permission_handler` 等依赖未引入；`RECORD_AUDIO` 权限未声明；`PracticeRecord.audioFilePath` 始终为 `null`。
6. **未实现真实音频文件生命周期**：未设计 / 实现音频文件目录、清理、删除、迁移策略。
7. **未申请麦克风权限**：未声明 `RECORD_AUDIO`；App 启动与各核心页面无任何运行时权限弹窗。
8. **未进行账号 / 云同步 / AI 评分**：MVP 后产品方向由 GPT 首席架构师 + 用户另行决策（见 `TECH_DEBT.md` TD-008）。
9. **本次 Release 真机验收为全新安装**：旧 Debug 包的本地数据（已完成今日任务、练习记录、用户设置等）已被清除；**本次不证明** 旧 Debug 数据可迁移到 Release。
10. **仅一台 Android 真机验收**：本次验收**只**在 HUAWEI CDY-AN90 / Android 10 / SDK 29 单台设备上完成，未覆盖多设备 / 多 Android 版本 / 多厂商 ROM 适配。
11. **AAB 未直接安装**：AAB 是 Google Play 用于按设备架构分发 APK 的打包格式，需要 `bundletool` 或 Play Console 转换为 split APK 后才能安装；T022 仅完成 jarsigner 静态校验。
12. **基线 Commit 与 Release 构建 Commit 不一致**：基线 `4b5b386`（T022 报告）与 Release 构建 `d7bac44`（T021 主 commit）之间的差异为 T021A 阶段追加的协作机制文档（不影响 Release 产物元信息），所以 Release 构建的源码基线等价于 T021 阶段的 `d7bac44`；当前 HEAD = `e181ba2`（T023 报告），T019-T024 阶段无新的构建产物改动。

## Release Decision

- **Android Release 工程化阶段是否满足进入下一阶段的条件**：**Yes**
  - 正式签名框架 + 仓库外 keystore 接入完成（T020 + 两条 FIX）；
  - 版本号 `1.0.0+2` 落地（T021）；
  - Release APK / AAB 构建成功（T021）；
  - 静态产物验证全部通过（T022）；
  - 真机安装 + 启动 + 18 项用户手工冒烟验收全部 Passed（T023）；
  - 本检查点文档落盘（T024）；
  - 自动化门禁 `flutter analyze` / `flutter test` 407 passed / `verify_release_artifacts.dart` 全部通过；
  - 敏感文件（`key.properties` / `*.jks` / `*.keystore` / 构建产物）未被 `git ls-files` 跟踪；
  - 命令纪律严格执行（单条命令，无管道 / 无重定向 / 无 `&&` / 无分号 / 无复合命令）。

- **下一阶段建议**：**真实录音与回放 MVP 的 SDD / TDD 设计**。
  - 进入真实音频阶段前，**必须**重新设计：① 运行时权限申请与回退（`RECORD_AUDIO` / iOS `NSMicrophoneUsageDescription`）；② 音频文件生命周期（目录、清理、迁移、删除策略）；③ 隐私政策、用户告知、合规审查；④ 平台架构（Drift schema 升级、文件存储抽象、错误恢复）；⑤ 依赖选型（`record` / `flutter_sound` / `just_audio` / `permission_handler` 等需要重新评估，**不得**直接恢复旧依赖）。
  - 本任务**不替代**真实音频阶段的设计；T025 及后续任务必须由 GPT 首席架构师出具独立 Prompt 后才能启动。

- **必须等待 GPT 首席架构师复审通过**才允许进入 T025。

## References

- `docs/dev/RELEASE_ENGINEERING_SDD.md`：Release 工程化软件设计文档
- `docs/dev/RELEASE_ENGINEERING_TDD.md`：Release 工程化测试驱动开发计划
- `docs/dev/RELEASE_ARTIFACTS.md`：Release 产物元信息
- `docs/dev/RELEASE_DEVICE_ACCEPTANCE.md`：Release 真机验收报告
- `docs/dev/MVP_ACCEPTANCE.md`：MVP 验收基线
- `docs/dev/AGENT_ROUTING_MATRIX.md`：任务路由矩阵
- `docs/dev/AGENT_REVIEW_TEMPLATE.md`：审查报告模板
- `docs/dev/AGENT_QUALITY_METRICS.md`：协作质量度量
- `docs/dev/TASK_LEDGER.md`：任务台账
- `docs/dev/TECH_DEBT.md`：技术债台账
- `docs/MULTI_AGENT_WORKFLOW.md`：多 Agent 协作流程
- `agents/00-chief-architect.md` / `07-qa-reviewer.md` / `08-compliance-reviewer.md`：角色职责原文
