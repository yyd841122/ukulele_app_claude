# Release 工程化测试驱动开发计划 (RELEASE_ENGINEERING_TDD)

> 本文档是 Release 工程化阶段的 **测试驱动开发计划**，不是第二份架构文档。架构与设计见 [`RELEASE_ENGINEERING_SDD.md`](./RELEASE_ENGINEERING_SDD.md)。
>
> 本文使用的"测试"是广义可重复证据：单元测试 / Widget 测试 / 集成测试 / 静态检查 / 构建命令 / 产物校验命令 / 真机手工验收。

## 1. Test Strategy

Release 工程化阶段在 MVP `flutter_test` 体系之外，引入以下测试维度：

| 维度 | 工具 / 手段 | 触发任务 | 适用场景 |
| --- | --- | --- | --- |
| **静态检查（Flutter）** | `flutter analyze` | 每个 T02x 任务结束 | 任何代码 / 资源改动后必跑 |
| **静态检查（Gradle）** | `./gradlew :app:tasks` / 配置审阅 | T020 / T021 | 签名读取逻辑、release signingConfig 配置审阅 |
| **单元测试** | `flutter test`（dart test） | 仅在 Dart 层新增校验逻辑时 | T022 可能新增 `test/release/` 子目录用于产物元信息解析 |
| **Widget 测试** | `flutter test` | 仅在 UI 改动时（本阶段不应发生） | T020-T024 默认不触发 |
| **集成测试** | `flutter test integration_test/` | 仅在产品行为改动时（本阶段不应发生） | T014 已建立 baseline，本阶段不新增 |
| **Gradle / Flutter 构建验证** | `flutter build apk --release`、`flutter build appbundle --release`、`./gradlew :app:assembleRelease` | T021 / T022 | 验证 release 流程可重复 |
| **APK 静态校验** | `aapt dump badging <apk>`、`aapt dump permissions <apk>`、`keytool -printcert -jarfile <apk>`、`certutil -hashfile <apk> SHA256` | T022 | 产物身份与签名校验 |
| **AAB 静态校验** | `bundletool dump manifest --bundle=<aab>`（如未来引入）或解压查看 `AndroidManifest.xml` + `certutil` | T022 | AAB 元信息校验 |
| **真机手工验收** | 用户在本机真机手动执行 | T023 | 安装、启动、冒烟、杀进程/强行停止重启 |

> **adb 假定**：本计划**不假定 `adb` 已在系统 PATH**。所有命令仅依赖 `flutter` / `aapt` / `keytool` / `certutil` / `dir` 等 Windows 标准命令。如未来需要 `adb`，T023 由用户提供具体 `adb` 路径或在 T023 任务 Prompt 中明确。

## 2. Baseline

| 项 | 当前值 | 来源 |
| --- | --- | --- |
| `flutter analyze` | No issues found | `docs/dev/MVP_ACCEPTANCE.md` §3 |
| `flutter test` | 407 tests passed | `docs/dev/MVP_ACCEPTANCE.md` §3 |
| 新增 / 更新 / 删除测试 | 0 / 0 / 0（T019 范围内） | T019 任务约定 |
| Debug 真机验收 | 通过（`CDY-AN90`） | `docs/dev/MVP_ACCEPTANCE.md` §5 |
| Release 真机验收 | **未执行** | 当前状态 |
| Release APK / AAB 构建 | **未执行** | 当前状态 |

> T019 阶段结束后的预期基线仍是 `flutter analyze` 无问题、`flutter test` 407 项通过、且不新增任何 Flutter 测试。

## 3. Test-First Rules

每个后续任务（T020-T024）必须按以下顺序执行，**禁止**先写实现再补测试：

1. **定义失败条件或验收证据**
   - 在任务 Prompt 或本计划对应章节明确"什么算失败"
   - 配置类任务（T020 签名配置 / T021 版本元数据）使用可重复的**静态检查 / 构建命令 / 产物检查**作为证据，不得伪造"先红后绿"的单元测试假象
2. **做最小实现**
   - 仅修改任务允许范围内的文件
   - 不顺手重构 / 不顺手升级依赖
3. **执行定向验证**
   - 仅跑与本任务直接相关的命令 / 测试 / 构建
4. **执行全量回归**
   - `flutter analyze` + `flutter test` 必须仍为基线
5. **自检并修正**
   - 对照本计划 §6 Regression Matrix 逐项核对
6. **通过后才 Commit**
   - 测试失败 → 不允许 Commit
   - 任何警告未处理 → 不允许 Commit
   - 工作树不干净 → 不允许 Commit

### 3.1 配置类任务的"测试证据"原则

Gradle / Flutter / 产物校验不属于普通单元测试范畴，必须使用以下任意一种**可重复**方式作为测试证据：

- **可重复命令的退出码 + 输出**（如 `certutil -hashfile` 输出与期望值比对）
- **新增 Dart 测试**用于本地断言产物元信息（仅在可解析且稳定时引入，不强制）
- **构建命令的成功/失败**作为粗粒度门禁

> 严禁伪造"先红后绿"的测试用例。例如：T020 不允许写一个"未配置签名 → 测试期望 build 成功"的反向用例来人为制造绿色。

## 4. Signing Tests（T020）

### 4.1 必须通过的证据

| 编号 | 证据项 | 命令 / 操作 | 通过条件 |
| --- | --- | --- | --- |
| S-1 | `.gitignore` 覆盖 `*.jks` / `*.keystore` | `rg -n '^\*\.jks$' .gitignore` 与 `rg -n '^\*\.keystore$' .gitignore` | 各返回 ≥1 行 |
| S-2 | `.gitignore` 覆盖 `key.properties` | `rg -n '^key\.properties$' .gitignore` 或 `rg -n '^android/key\.properties$' .gitignore` | 返回 ≥1 行 |
| S-3 | 无已跟踪的 keystore 文件 | `git ls-files '*.jks' '*.keystore'` | 返回 0 行 |
| S-4 | 无已跟踪的 `key.properties` | `git ls-files '**/key.properties'` | 返回 0 行 |
| S-5 | `buildTypes.release.signingConfig` 不指向 `signingConfigs.debug` | `rg -n 'signingConfig\s*=\s*signingConfigs\.debug' android/app/build.gradle` | 在 release 块内返回 0 行（仍允许 comment 中出现，但 release 块本身必须指向 `signingConfigs.release`） |
| S-6 | 缺少 `key.properties` 时构建安全失败 | `flutter build apk --release`（或 `:app:assembleRelease`） | 命令退出码非 0；日志出现指向 `key.properties` 或 `storePassword` 缺失的报错 |
| S-7 | Gradle 读取逻辑使用 `rootProject.file(...)` / 类似 API | `rg -n 'rootProject\.file' android/app/build.gradle` | 返回 ≥1 行（表示签名材料路径来自仓库外） |
| S-8 | 日志/报告中无密码字面量 | 人工审阅 build log 与 task report 摘录 | 无 `storePassword=xxx` / `keyPassword=xxx` / 实际 alias 字符串示例（仅允许 `<用户填写>` 占位） |

> 4.1-S-7 中的 `rootProject.file(...)` 是 Android 官方推荐做法之一；T020 也可以使用 `project.findProperty` + `gradle.properties` 注入方案，但**不得**把密码以任何形式硬编码进 `build.gradle`。

## 5. Artifact Tests（T021 / T022）

### 5.1 构建成功（T021）

| 编号 | 证据项 | 命令 | 通过条件 |
| --- | --- | --- | --- |
| B-1 | Release APK 构建成功 | `flutter build apk --release` | 退出码 0；产物存在于 `build/app/outputs/flutter-apk/app-release.apk` |
| B-2 | Release AAB 构建成功（如用户在 SDD §6.1 同意） | `flutter build appbundle --release` | 退出码 0；产物存在于 `build/app/outputs/bundle/release/app-release.aab` |

### 5.2 产物身份与内容（T022）

| 编号 | 证据项 | 命令（仅建议） | 通过条件 |
| --- | --- | --- | --- |
| A-1 | APK 文件存在 | `dir build\app\outputs\flutter-apk\app-release.apk` | 列出文件且字节数 > 0 |
| A-2 | AAB 文件存在（如构建） | `dir build\app\outputs\bundle\release\app-release.aab` | 列出文件且字节数 > 0 |
| A-3 | APK applicationId 正确 | `aapt dump badging build\app\outputs\flutter-apk\app-release.apk \| rg '^package: name='` | 包含 `name='com.yupi.ukulele'` |
| A-4 | APK versionName 正确 | `aapt dump badging ...apk \| rg '^package: name='` | 包含用户批准的 versionName |
| A-5 | APK versionCode 正确 | 同上 | versionCode 与用户批准的整数一致 |
| A-6 | Manifest 不出现 `RECORD_AUDIO` | `aapt dump permissions ...apk \| rg 'RECORD_AUDIO'` | 返回 0 行 |
| A-7 | Manifest 不出现 `INTERNET` | `aapt dump permissions ...apk \| rg 'INTERNET'` | 返回 0 行 |
| A-8 | Manifest 不出现其他新增运行时权限 | `aapt dump permissions ...apk` 与 `android/app/src/main/AndroidManifest.xml` 字段对照 | 仅有 launcher Activity 与 `flutterEmbedding` meta-data；无新增 `<uses-permission>` |
| A-9 | APK SHA-256 已生成 | `certutil -hashfile build\app\outputs\flutter-apk\app-release.apk SHA256` | 输出 64 位十六进制字符串；该字符串已写入 `docs/dev/RELEASE_ARTIFACTS.md` |
| A-10 | APK 字节大小已记录 | 读取 A-9 输出前后取文件大小 | 字节大小已写入 `docs/dev/RELEASE_ARTIFACTS.md` |
| A-11 | AAB SHA-256 已生成（如构建） | `certutil -hashfile ...\app-release.aab SHA256` | 同 A-9 |
| A-12 | AAB 字节大小已记录 | 读取 A-11 输出前后取文件大小 | 字节大小已写入 `docs/dev/RELEASE_ARTIFACTS.md` |
| A-13 | 签名证书指纹已记录 | `keytool -printcert -jarfile build\app\outputs\flutter-apk\app-release.apk` | SHA-256 指纹已记录到 `docs/dev/RELEASE_ARTIFACTS.md`（仅指纹，不含 alias 名称以外的敏感信息） |
| A-14 | 产物未被 Git 跟踪 | `git ls-files 'build/app/outputs/**'` | 返回 0 行（`.gitignore` 已覆盖） |

### 5.3 产物记录文件

T022 引入 `docs/dev/RELEASE_ARTIFACTS.md`，**仅记录**以下字段（**绝不记录**密码 / keystore 内容 / 用户目录）：

| 字段 | 必填 | 示例占位（仅占位，禁用真实值） |
| --- | --- | --- |
| 产物名称 | ✅ | `app-release.apk` |
| 产物路径（相对仓库根） | ✅ | `build/app/outputs/flutter-apk/app-release.apk` |
| 字节大小（bytes） | ✅ | `<待 T022 填写>` |
| SHA-256 | ✅ | `<待 T022 填写>` |
| applicationId | ✅ | `com.yupi.ukulele` |
| versionName | ✅ | `<待用户批准>` |
| versionCode | ✅ | `<待用户批准>` |
| 签名证书 SHA-256 指纹 | ✅ | `<待 T022 填写>` |
| 构建日期（UTC 日期即可，不含本机绝对路径） | ✅ | `<待 T022 填写>` |
| 构建机器匿名标识 | ✅ | `local-windows`（**不记录用户名**） |
| 是否含 RECORD_AUDIO | ✅ | `否` |
| 是否含 INTERNET | ✅ | `否` |

## 6. Regression Matrix

以下矩阵列出 Release 阶段必须覆盖的核心功能验收点。

> 说明：`A` = 全自动测试覆盖；`M` = 用户在真机手工确认；`H` = 由历史产物 / 静态检查断言。

| 功能点 | 验收范围 | 覆盖方式 | 主要测试位置 | 备注 |
| --- | --- | --- | --- | --- |
| 今日练习 | 安装日期 + 7 天循环 + 任务完成 | A + M | T013.3 系列测试 + Release 真机 | 全量 `flutter test` 自动覆盖；Release 真机冒烟 |
| 持久化（任务完成） | 杀进程 / 强行停止后重启保留 | M | 真机 | T013.3 系列已有 widget 测试，Release 真机复测 |
| 持久化（练习记录） | 列表 / 详情 / 删除 | A + M | T013.4B / T013.4C / T014 测试 + Release 真机 | 同上 |
| 和弦库 | 内置和弦浏览 + 指法图 | A + M | T008 / T008_FIX 系列测试 + Release 真机 | 自动测试覆盖；Release 真机确认显示正常 |
| 单音练习 | 单音页面 + 上一个/下一个 | A + M | T009 / T009_FIX 测试 + Release 真机 | 同上 |
| 节拍器 | 可视化 + BPM 设置 | A + M | T010 / T010_FIX 测试 + Release 真机 | 仅可视化（无真实声音） |
| 手动调音辅助 | G/C/E/A 四弦页面 | A + M | T011 / T011_FIX 测试 + Release 真机 | 无自动调音 |
| 模拟录音 / 模拟回放 | 启动 / 停止 / 自评 / 备注 | A + M | T012 系列测试 + Release 真机 | 不写真实音频 |
| 记录列表 / 详情 / 删除 | 三态 UI + 确认对话框 | A + M | T013.4B / T013.4C 系列 + Release 真机 | 全量 `flutter test` 自动覆盖 |
| 权限 | Manifest 不出现 RECORD_AUDIO / INTERNET | H | `android/app/src/main/AndroidManifest.xml` + Release 产物校验 | T022 静态断言 |
| 强行停止后重启 | 本地数据保留 | M | 真机 | T015C 已验证，Release 真机复测 |
| Release APK 启动 / 启动页 | 启动正常，无崩溃 | M | 真机 | 用户真机验收 |
| Release APK 升级安装 | 已存在 Debug APK 时覆盖安装 | M | 真机 | 用户真机验收（如适用；若 applicationId 不变，升级需保持签名一致） |

> Release 真机验收 = 用户手工。Agent **不得**自行勾选"通过"。

## 7. Release Acceptance Gate

仅在以下**全部满足**时，Release 工程化阶段方可视为完成：

| 门禁 | 验证手段 | 通过条件 |
| --- | --- | --- |
| `flutter analyze` | `flutter analyze` | No issues found |
| 全量测试 | `flutter test` | 407（或后续正确更新后的精确总数）项全通过；无新增 / 更新 / 删除测试，除非业务功能明确要求 |
| Release APK 构建 | `flutter build apk --release` | 退出码 0；产物落盘 |
| Release AAB 构建（如启用） | `flutter build appbundle --release` | 退出码 0；产物落盘 |
| 签名校验 | `keytool -printcert -jarfile` | 签名证书 ≠ debug keystore；与正式 keystore 指纹一致 |
| Manifest 校验 | `aapt dump permissions` | 不出现 RECORD_AUDIO / INTERNET / 新增权限 |
| applicationId / 版本 | `aapt dump badging` | 与 `pubspec.yaml` / 用户批准一致 |
| Diff 范围 | `git diff --stat HEAD~1` | 仅包含 SDD §10 允许的文件 + 文档 |
| 敏感文件未被 Git 跟踪 | `git ls-files '*.jks' '*.keystore' '**/key.properties'` | 全部返回 0 行 |
| 真机验收 | T023 报告 | 用户勾选所有冒烟项；Agent 不替用户填写"通过" |
| GPT 首席架构师复审 | T024 报告 | 通过 |

## 8. Evidence Template（后续 Claude 报告统一使用）

每个 T02x 任务报告必须包含以下字段（T019 报告已示范该格式）：

```markdown
## 任务执行报告

### Task ID
<TASK_ID>

### 摘要（Summary）
<本任务做了什么；不超过 6 行>

### 仓库事实确认（Repository Facts Confirmed）
- 仅列本任务涉及的可验证事实
- 不复述 SDD 已记录的不变事实

### 新建文件（Files Created）
<绝对路径列表>

### 修改文件（Files Modified）
<绝对路径列表 + 修改摘要>

### 命令清单（Commands Run）
- <命令 1>
- <命令 2>
- ...

### 验证证据（Validation Evidence）
| 项 | 命令 | 实际输出 / 结果 | 通过条件 | 实际是否通过 |
| --- | --- | --- | --- | --- |
| <编号> | <命令> | <实际> | <条件> | ✅ / ❌ |

### 三步反思（Self-Critique）
1. Initial Implementation: ...
2. Self-Critique Findings: ...
3. Final Delivery: ...

### Git Commit Hash
<commit hash>

### Git Status
<clean / dirty>

### 是否 Push
No

### 是否创建 Tag
No

### 待用户决策项（User Decisions Required Before Next Task）
<列表；若无则写"无">

### 风险（Risks）
<列表>

### 是否准备好 GPT 首席架构师复审
Yes / No
```

> 不在报告中填写**尚未执行**的结果。任何字段缺失必须写"待执行"，不得用占位未来值填充。
