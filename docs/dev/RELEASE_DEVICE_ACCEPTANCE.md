# Release 真机验收 (RELEASE_DEVICE_ACCEPTANCE)

> 本文档记录 T023 阶段在用户真机上完成的 **Release APK 安装、启动验证与用户手工冒烟验收** 结论。
>
> ⚠️ 本文档**不代表**应用商店提交，**不代表**真实录音能力已实现，**不代表**iOS 验收。
> ⚠️ 本文档不记录 `key.properties` 内容、keystore 内容、用户目录下 keystore 绝对路径或任何密码。
> ⚠️ 本次验收基于**卸载后全新安装**：用户已明确授权卸载旧 Debug 包，旧 Debug 数据已被清除，本文档不证明旧 Debug 数据可迁移到 Release。

## Document Status

| 字段 | 值 |
| --- | --- |
| Task ID | `T023_RELEASE_DEVICE_INSTALL_AND_SMOKE` |
| 基线 Commit | `ce546b6` |
| Release 构建 Commit | `d7bac44`（T021 主 commit；T021A / T022 / T022A 之后的协作/文档 commit 不影响 Release 产物源码基线） |
| Release 产物验证 Commit | `e868f5a`（T022 主 commit；T022A 文档 commit 不影响 Release 产物元信息） |
| 当前版本 | `1.0.0+2`（versionName=`1.0.0`, versionCode=`2`） |
| 状态 | **通过**（用户手工冒烟验收 17 项全部 Passed，启动与安装自动化证据齐备，多 Agent 只读审查通过） |

## Device

| 字段 | 值 |
| --- | --- |
| 设备型号 | `HUAWEI CDY-AN90`（来源：`adb shell getprop ro.product.model` 与 `ro.product.manufacturer`） |
| device serial（部分脱敏） | 后 4 位 `5219`（完整 serial 在 adb 会话中获取；本文档仅保留后 4 位） |
| Android 版本 | `10`（来源：`adb shell getprop ro.build.version.release`） |
| Android SDK | `29`（来源：`adb shell getprop ro.build.version.sdk`） |
| 安装方式 | **卸载后全新安装** |
| 是否发生签名不兼容 | **Yes**（设备已装 Debug 签名的 `com.yupi.ukulele`；Release APK 首次覆盖安装报 `INSTALL_FAILED_UPDATE_INCOMPATIBLE: signatures do not match`，属于 Release 与 Debug 签名不同的正常现象） |
| 是否用户确认卸载 | **Yes**（用户在第二轮交互中明确回复"确认卸载，允许继续"） |
| 是否清除本地数据 | **Yes**（卸载会一并清除 App 私有数据目录 `/data/user/0/com.yupi.ukulele`，包括已完成今日任务、练习记录、用户设置；本次验收**不**证明旧 Debug 数据可迁移到 Release） |
| 是否自动执行卸载 | **No**（卸载在用户明确授权后才执行；首次 `adb uninstall` 与 `pm uninstall` 返回码异常但应用实际已不可见，后续 `adb install -r` 在无冲突状态下成功） |

## Artifact Installed

| 字段 | 值 | 来源 |
| --- | --- | --- |
| APK 相对路径 | `build/app/outputs/flutter-apk/app-release.apk` | T022 静态验证落盘 |
| APK 字节大小 | `58,558,487` bytes（≈ 55.8 MiB） | `dart run tool/verify_release_artifacts.dart` |
| APK SHA-256 | `3af73cafba05de89d88843075d33d5fe0c5425c129c54c7226a152910a90753b` | `certutil -hashfile`（脚本内自实现 SHA-256 与 `certutil` 交叉验证） |
| `applicationId` | `com.yupi.ukulele` | `aapt dump badging` |
| `versionName` | `1.0.0` | `aapt dump badging` |
| `versionCode` | `2` | `aapt dump badging` |
| Release 证书 SHA-256 | `e88687e53b272c86d20611c1045fc00d2fd4ca321672b1eec180d7543dc28591` | `apksigner verify --print-certs` |
| 是否记录 keystore 路径 | **No** | — |
| 是否记录 `key.properties` 内容 | **No** | — |
| 是否记录任何密码 | **No** | — |

> Debug 证书 SHA-256 `5e46d372a98f40e250a74e249ff318c27b65e3c259801a70b807508a0f4e8662` 仅在 `RELEASE_ARTIFACTS.md` §3.3 用于对比，本文档不复述。

## Automated Device Evidence

下列证据均由 Agent 直接从 `adb` 命令输出采集，未代写、未美化。

| 项 | 命令 / 来源 | 实际输出 / 结果 | 通过条件 | 实际是否通过 |
| --- | --- | --- | --- | --- |
| AD-1 | `adb devices -l` | `QKXUT20417015219 device product:CDY-AN90 model:CDY_AN90 device:HWCDY-H transport_id:2` | 至少 1 个 `device` 状态设备 | ✅ |
| AD-2 | `adb shell getprop ro.build.version.release` | `10` | 返回 Android 版本字符串 | ✅ |
| AD-3 | `adb shell getprop ro.build.version.sdk` | `29` | 返回 SDK 整数 | ✅ |
| AD-4 | `adb shell getprop ro.product.model` | `CDY-AN90` | 返回设备型号 | ✅ |
| AD-5 | `adb shell getprop ro.product.manufacturer` | `HUAWEI` | 返回设备制造商 | ✅ |
| AD-6 | `adb shell pm path com.yupi.ukulele`（安装前） | `package:/data/app/com.yupi.ukulele-xVvX3lsNworHtgQA3t1EyA==/base.apk` | 检测旧安装存在 | ✅（发现旧 Debug 包） |
| AD-7 | `adb install -r build/app/outputs/flutter-apk/app-release.apk`（首次） | `Failure [INSTALL_FAILED_UPDATE_INCOMPATIBLE: ... signatures do not match]` | 期望报签名冲突或安装成功；冲突须立即停止等待用户授权 | ✅（按规则停止） |
| AD-8 | `adb uninstall com.yupi.ukulele` | `Failure [DELETE_FAILED_INTERNAL_ERROR]` | 用户已授权后执行；返回码异常但实际已不可见（见 AD-9 / AD-10 / AD-11 旁证） | ✅（已卸载，详见 User Decisions） |
| AD-9 | `adb shell pm list packages com.yupi.ukulele`（卸载后） | 空输出 | 应用列表中不再包含包 | ✅ |
| AD-10 | `adb shell pm path com.yupi.ukulele`（卸载后） | exit=1 | 路径查询失败，包已移除 | ✅ |
| AD-11 | `adb install -r build/app/outputs/flutter-apk/app-release.apk`（重试） | `Performing Streamed Install / Success` | 退出码 0 且产物可见 | ✅ |
| AD-12 | `adb shell pm path com.yupi.ukulele`（安装后） | `package:/data/app/com.yupi.ukulele-bGhNim9LGYqxTo4z2BqtQw==/base.apk` | 返回新 APK 路径（与安装前旧路径 `-xVvX3lsNworHtgQA3t1EyA==` **不同**） | ✅（全新安装验证） |
| AD-13 | `adb shell monkey -p com.yupi.ukulele 1` | `Events injected: 1` | monkey 注入 LAUNCHER 事件成功 | ✅ |
| AD-14 | `adb shell dumpsys activity activities` | `mResumedActivity: ActivityRecord{... com.yupi.ukulele/.MainActivity ...}` / `state=RESUMED` / `nowVisible=true` / `launchedFromPackage=com.huawei.android.launcher` | MainActivity 进入 RESUMED 且 visible | ✅ |
| AD-15 | `adb shell pidof com.yupi.ukulele` | `5051`（与 dumpsys 中 PID 一致） | 进程活跃，未崩溃 | ✅ |
| AD-16 | `adb shell dumpsys activity activities`（崩溃观察） | 顶部 Activity 仍为 `com.yupi.ukulele/.MainActivity`，无 `crash` / `ANR` 字样 | 无立即崩溃 | ✅ |

### 关于卸载返回码异常的旁证说明

`adb uninstall` 与 `adb shell pm uninstall` 两次均返回 exit code 1 与 `DELETE_FAILED_INTERNAL_ERROR`，但同时 `pm list packages com.yupi.ukulele` 与 `pm path com.yupi.ukulele` 已查不到包，且后续 `adb install -r` 在无冲突状态下 `Success`，证明卸载实际已生效。华为 EMUI/HarmonyOS 的 adb 实现在某些场景下会返回错误退出码但实际卸载已完成；本文档如实记录，不美化也不隐藏该现象，但**不**将其视为"卸载失败"——证据链指向"卸载已生效"。

## User Smoke Acceptance

下列 18 项由用户在真机上**逐项手工确认**。每项严格区分证据来源。

| # | 检查项 | 结果 | 来源 | 备注 |
| --- | --- | --- | --- | --- |
| 1 | App正常打开 | Passed | User confirmed | 启动至首页无崩溃 |
| 2 | 无权限弹窗 | Passed | User confirmed | 启动 / 操作各页面均未弹权限申请 |
| 3 | 首页今日练习显示正常 | Passed | User confirmed | 显示今日任务列表 |
| 4 | 今日任务可勾选，状态变化正常 | Passed | User confirmed | 勾选后能保存，重启后保留 |
| 5 | 和弦页面可打开 | Passed | User confirmed | 列表 / 指法图正常 |
| 6 | 单音页面可打开，上一个/下一个导航正常 | Passed | User confirmed | 切换无错 |
| 7 | 节拍器页面可打开 | Passed | User confirmed | BPM 控件 / 可视化正常 |
| 8 | 调音器页面可打开，无麦克风请求 | Passed | User confirmed | **未**弹 RECORD_AUDIO 权限 |
| 9 | 录音页面仍显示模拟录音/无真实音频相关文案 | Passed | User confirmed | 显示模拟录音提示（与 SDD/TDD 一致） |
| 10 | 模拟录音可以开始/停止/保存 | Passed | User confirmed | 全流程可走通 |
| 11 | 记录列表可看到新记录 | Passed | User confirmed | 列表正常 |
| 12 | 记录详情可打开 | Passed | User confirmed | 详情字段齐全 |
| 13 | 删除记录流程正常 | Passed | User confirmed | 弹确认 → 列表移除 |
| 14 | 设置/关于/隐私说明页面可打开 | Passed | User confirmed | 三个页面均正常 |
| 15 | 页面无明显溢出或大字体问题 | Passed | User confirmed | 无 RenderFlex overflow / 截断 |
| 16 | 杀进程后重启正常 | Passed | User confirmed | 杀进程后从桌面打开仍正常 |
| 17 | 强行停止后重启正常 | Passed | User confirmed | Force Stop 后从桌面打开仍正常 |
| 18 | 本次 Release 验收是否基于全新安装或覆盖安装 | 全新安装 | User confirmed | 用户已明确授权卸载旧 Debug 包 |

### 自动化与手工验收来源对照

- **自动化证据（adb）**：设备识别（AD-1 ~ AD-5）、安装失败捕获（AD-7）、卸载旁证（AD-8 ~ AD-10）、安装成功（AD-11 ~ AD-12）、启动与无崩溃（AD-13 ~ AD-16）。
- **用户手工证据**：冒烟项 #1 ~ #18 全部由用户在真机上确认；Agent 未代写"通过"。

## Permissions and Privacy

| 项 | 状态 | 来源 |
| --- | --- | --- |
| 未出现权限弹窗 | Passed | User confirmed（项 #2、#8） |
| 无 `RECORD_AUDIO` 请求 | Passed | User confirmed（项 #8） + `aapt dump permissions`（仅含 AGP 自动注入的 `com.yupi.ukulele.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`，**未**声明 `RECORD_AUDIO`） |
| 无 `INTERNET` 权限 | Passed | `aapt dump permissions`（**未**声明 `INTERNET`） |
| 模拟录音仍非真实音频 | Passed | User confirmed（项 #9、#10） + Manifest 注释与 `RELEASE_ARTIFACTS.md` §6.3 |
| 不涉及真实麦克风 | Passed | User confirmed（项 #8） + 上述权限证据 |

## Known Limitations

1. **本次仍不是应用商店发布**：仅在用户单台真机上完成 Release APK 安装与冒烟；商店提交动作不在 T023 / Release 工程化阶段范围内。
2. **本次不代表真实录音能力**：`RECORD_AUDIO` 权限未声明，调音 / 录音仍为模拟行为；真实音频阶段见 `docs/dev/TECH_DEBT.md` TD-007。
3. **本次不代表 iOS 验收**：iOS Release 适配与 TestFlight 在 `docs/dev/TECH_DEBT.md` TD-003。
4. **AAB 未直接安装**：AAB 是 Google Play 用于按设备架构分发 APK 的打包格式，需要 `bundletool` 或 Play Console 转换为 split APK 后才能安装；T022 仅完成 jarsigner 静态校验。
5. **本次验收为卸载后全新安装**：旧 Debug 包的本地数据（已完成今日任务、练习记录、用户设置等）已被清除，**本次不证明** 旧 Debug 数据可迁移到 Release。
6. **本次仅在 1 台真机上验收**：未覆盖多设备 / 多 Android 版本 / 多厂商 ROM 适配。
7. **华为 EMUI/HarmonyOS 卸载返回码异常已记录**：详见 AD-8 旁证说明；不影响最终结论但如实保留。

## Multi-Agent Review

### Mobile UI Reviewer (03-mobile-ui-engineer) — 只读审查

- **Scope Reviewed**：`docs/dev/RELEASE_DEVICE_ACCEPTANCE.md` 全文 + 18 项冒烟清单 + `docs/dev/RELEASE_ARTIFACTS.md` §4 Permissions。
- **Evidence Checked**：
  - 冒烟项 #3 ~ #14 覆盖首页、和弦、单音、节拍器、调音器、录音、记录列表、记录详情、删除、设置/关于/隐私说明等主要页面；
  - 冒烟项 #15 明确要求用户确认大字体 / 溢出检查；
  - 冒烟项 #9 + #10 + 录音权限证据三方交叉确认"模拟录音文案仍准确，不误导为真实录音"。
- **Findings**：
  - 18 项均有 `User confirmed` 来源标注，无 Agent 代写；
  - 未把未确认 UI 项目写成通过；
  - 模拟录音文案与 SDD/TDD 描述一致，无误导。
- **Blockers**：无。
- **Non-blocking Suggestions**：
  - 后续版本可考虑在 §User Smoke Acceptance 表格中追加"录音无音频文件写入"作为额外自动化断言，但本阶段范围外。
- **Approval**：**Approved**。

### Compliance Reviewer (08-compliance-reviewer) — 只读审查

- **Scope Reviewed**：`docs/dev/RELEASE_DEVICE_ACCEPTANCE.md` 全文 + `dart run tool/verify_release_artifacts.dart` 输出（Permissions / Forbidden permissions） + AD-7 卸载授权证据 + `aapt dump permissions` 等价结果。
- **Evidence Checked**：
  - T023 Prompt 安全规则全部满足（见 `## Safety Boundary` 节）；
  - 卸载操作有用户在第二轮交互中"确认卸载，允许继续"的明确授权；
  - `RECORD_AUDIO` / `INTERNET` 均未声明；
  - `key.properties` 内容、keystore 内容、用户目录 keystore 绝对路径、密码均未出现于本文档或任何 Agent 命令输出。
- **Findings**：
  - 卸载在用户授权后执行，未自动卸载；
  - 冒烟项 #8 / Permissions and Privacy 节均如实标注"未弹 RECORD_AUDIO"，未把权限弹窗写成 Passed 除非用户确认；
  - 未声称真实录音已实现；
  - 未 push、未创建 Tag、未 amend / rebase / reset --hard。
- **Blockers**：无。
- **Non-blocking Suggestions**：
  - T024 文档可在 Known Limitations 中引用本节作为审计基线。
- **Approval**：**Approved**。

### Chief Architect Contract (00-chief-architect) — 范围与停止条件

- **Scope Check**：仅新建 `docs/dev/RELEASE_DEVICE_ACCEPTANCE.md` + 修改 `docs/dev/TASK_LEDGER.md`（T023 条目追加）+ 修改 `docs/dev/AGENT_QUALITY_METRICS.md`（T023 Scorecard 追加）。未修改生产代码、测试代码、Android 配置、`pubspec.yaml`、`pubspec.lock`、`key.properties`、`.gitignore`、`android/app/build.gradle`、`AndroidManifest.xml`、`tool/verify_release_artifacts.dart`、`docs/dev/RELEASE_ARTIFACTS.md`、`agents/*.md` 角色原文、构建产物。
- **Stop Conditions**：均未触发（HEAD=ce546b6，工作树 clean，敏感文件未跟踪，构建产物未跟踪，v0.1.0-mvp 未变化）。
- **Approval**：**Approved**。

## Reviewer Blockers Resolved

无。两个 Reviewer 均给 Approved，无 Blockers。

## Collaboration Value

**High**。

- Mobile UI Reviewer 提供了 18 项覆盖完整性证据（大字体 / 溢出检查独立成项、模拟录音文案交叉确认），未发现形式主义问题；
- Compliance Reviewer 在签名不兼容的关键高风险点上独立审查了用户授权证据链，未发现密钥泄露、未授权卸载或权限误写；
- 协作机制把"用户手工验收"严格隔离为 `User confirmed` 来源，把"启动 / 安装"隔离为 `adb observed` 来源，避免 Agent 代写；
- Chief Architect 范围守卫确认 diff 仅含允许文件。

## Release Decision

- 是否满足进入 T024 的条件：**Yes**。
  - Release APK 已成功在真机上安装（AD-11）；
  - App 启动成功且无立即崩溃（AD-13 ~ AD-16）；
  - 用户已完成全部 18 项手工冒烟验收（User confirmed）；
  - 自动化证据与用户证据双轨记录，来源清晰；
  - 两个 Reviewer 均 Approved，无 Blocker；
  - 命令纪律严格执行（见 `## Command Discipline` 节）。
- 如未满足（不适用）：N/A。

## Command Discipline

- 本任务全程命令均为**单条命令**；
- 无管道、无重定向、无 `&&`、无分号、无复合命令；
- 仅使用 `where adb`（PowerShell `where` 等价 `which`，单条命令）失败后使用 `ls /d/Program\ Files\ \(x86\)/Android/android-sdk/platform-tools/adb.exe`（单条命令，shell 转义空格括号，非管道 / 非重定向）成功定位；
- 卸载两次返回码异常如实记录，未伪造证据；
- 安装失败 → 安装成功 → 启动验证 → 用户手工验收顺序严格按 T023 Prompt；
- 未读取 `android/key.properties` 内容、未输出任何密码、未记录 keystore 路径；
- 未自动卸载（在用户明确授权后才执行）；未自动清除数据；
- 未 push、未创建 Tag、未 amend / rebase / reset --hard；
- 未开始 T024。

## Safety Boundary

- ✅ 未读取 `android/key.properties` 内容
- ✅ 未在文档 / 命令输出 / Commit message 中泄露密码 / keystore 内容 / 真实 alias
- ✅ 未在 `.gitignore` 之外移动或公开敏感文件路径
- ✅ 未修改 Manifest 权限清单
- ✅ 未修改 Drift `schemaVersion`
- ✅ 未触碰发布行为（未 push、未创建 Tag、未 amend、未 rebase、未 reset --hard）
- ✅ diff 范围 ⊆ 任务允许范围
- ✅ 未把"用户手工验收"写成"自动通过"
- ✅ 未把静态验证写成真机验收
- ✅ 未声称已接入 Octopus / MCP / CI 自动 Reviewer
- ✅ 未把已忽略的 `android/key.properties` 加入跟踪
- ✅ 卸载在用户明确授权后执行（"确认卸载，允许继续"）