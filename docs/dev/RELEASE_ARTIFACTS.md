# Release 产物记录 (RELEASE_ARTIFACTS)

> 本文档记录 T021 阶段产出的 Release APK / AAB 元信息，以及 T022 阶段对这些产物完成的**静态验证结果**。
>
> ⚠️ 本文档**不代表**真机验收完成，**不代表**应用商店提交，**不代表**真实录音能力已实现。T023 真机安装与冒烟验收、T024 验收基线汇总由后续任务负责。
>
> ⚠️ 本文档不记录 `key.properties` 内容、keystore 内容、用户目录下 keystore 绝对路径或任何密码。

## Document Status

| 字段 | 值 |
| --- | --- |
| Task ID | `T022_RELEASE_ARTIFACT_AUTOMATED_VERIFICATION` |
| 基线 Commit | `4b5b386` |
| Release 构建 Commit | `d7bac44`（T021 主 commit） |
| 当前版本 | `1.0.0+2`（versionName=`1.0.0`, versionCode=`2`） |
| 状态 | 静态产物验证完成（APK + AAB 元信息、签名、权限、SHA-256 已落盘），真机验收尚未进行 |
| Push Performed | No |
| Tag Created | No |
| Device Acceptance Performed | No |

> 注：基线 Commit 4b5b386 与 Release 构建 Commit d7bac44 之间的差异为 `docs/dev/AGENT_ROUTING_MATRIX.md` / `docs/dev/AGENT_REVIEW_TEMPLATE.md` / `docs/dev/AGENT_QUALITY_METRICS.md` / `docs/MULTI_AGENT_WORKFLOW.md` / `docs/dev/TASK_LEDGER.md` —— 这些都是 T021A 阶段的协作机制文档，**不**包含 Release 产物或签名配置改动。Release 构建的源码基线等价于 T021 阶段的 d7bac44。

## 1. Artifacts

### 1.1 Release APK

| 字段 | 值 |
| --- | --- |
| 相对路径 | `build/app/outputs/flutter-apk/app-release.apk` |
| 字节大小 | `58,558,487` bytes (≈ 55.8 MiB) |
| SHA-256 | `3af73cafba05de89d88843075d33d5fe0c5425c129c54c7226a152910a90753b` |

### 1.2 Release AAB

| 字段 | 值 |
| --- | --- |
| 相对路径 | `build/app/outputs/bundle/release/app-release.aab` |
| 字节大小 | `57,332,407` bytes (≈ 54.7 MiB) |
| SHA-256 | `a782231edc6dcc31044f936a8b6ed0e09b211da69167e08adc9636241326d233` |

### 1.3 Debug APK（仅供证书对比）

| 字段 | 值 |
| --- | --- |
| 相对路径 | `build/app/outputs/flutter-apk/app-debug.apk` |
| 字节大小 | `161,305,625` bytes (≈ 154 MiB) |
| SHA-256 | Debug APK 未在本文档固化（仅证书指纹用于对比；Debug APK 体积较大，不进入 Release 产物台账） |

## 2. Package Identity

来源：`aapt dump badging build/app/outputs/flutter-apk/app-release.apk`

| 字段 | 值 | 来源 |
| --- | --- | --- |
| `applicationId`（package name） | `com.yupi.ukulele` | aapt `package:` |
| `versionName` | `1.0.0` | aapt `package:` |
| `versionCode` | `2` | aapt `package:` |
| `minSdk`（sdkVersion） | `24` | aapt `sdkVersion:` |
| `targetSdk` | `36` | aapt `targetSdkVersion:` |
| `compileSdk` | `36` | aapt `compileSdkVersion=` |
| `application-label` | `Ukulele` | aapt `application-label:` |
| `native-code` ABI | `arm64-v8a`, `armeabi-v7a`, `x86_64` | aapt `native-code:` |

> 与 `pubspec.yaml` `version: 1.0.0+2`（Android 派生 `versionName=1.0.0`, `versionCode=2`）一致；与 `android/app/build.gradle` `applicationId = "com.yupi.ukulele"` 一致。

## 3. Signature

### 3.1 APK 签名验证（`apksigner verify --verbose --print-certs`）

| 字段 | 值 |
| --- | --- |
| 验证退出码 | `0` |
| APK Signature Scheme v2 | true |
| APK Signature Scheme v3 | true |
| APK Signature Scheme v4 | true |
| Release 证书 SHA-256 | `e88687e53b272c86d20611c1045fc00d2fd4ca321672b1eec180d7543dc28591` |

### 3.2 AAB jarsigner 验证

| 字段 | 值 |
| --- | --- |
| 命令 | `jarsigner -verify build/app/outputs/bundle/release/app-release.aab` |
| 退出码 | `0` |

> `apksigner` 不直接支持 AAB 格式。T022 按任务约定使用 `jarsigner -verify`（退出码为 0 即视为 jar 校验通过）。

### 3.3 Release 与 Debug 证书对比

| 项 | 值 |
| --- | --- |
| Release 证书 SHA-256 | `e88687e53b272c86d20611c1045fc00d2fd4ca321672b1eec180d7543dc28591` |
| Debug 证书 SHA-256 | `5e46d372a98f40e250a74e249ff318c27b65e3c259801a70b807508a0f4e8662` |
| Release 与 Debug 证书不同 | **Yes** |

> Debug 证书 DN 形如 `C=US, O=Android, CN=Android Debug`（Android SDK 默认 debug keystore）。Release 证书 DN 形如 `CN=yyd, OU=yyd, O=yyd, L=yyd, ST=yyd, C=yyd`（用户保管的真实 keystore）。本文档不记录 alias / 密码 / keystore 文件内容 / 用户目录下 keystore 绝对路径。

## 4. Permissions

来源：`aapt dump permissions build/app/outputs/flutter-apk/app-release.apk`

| 权限 | 状态 |
| --- | --- |
| `android.permission.RECORD_AUDIO` | **未声明** |
| `android.permission.INTERNET` | **未声明** |
| `android.permission.<其他业务权限>` | **未声明** |
| `com.yupi.ukulele.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | 由 AGP 自动注入；非业务权限，不等同麦克风或网络权限 |

Manifest 中仅有 launcher Activity（`com.yupi.ukulele.MainActivity`，`launchMode="singleTop"`）与 `flutterEmbedding=2` meta-data，**无**新增 `<uses-permission>`。

## 5. Verification Commands

下列命令均可重复执行，且**不**包含密码 / keystore 路径 / 敏感配置。SHA-256 路径中的 `certutil` 是 Windows 内置命令。

### 5.1 产物存在性

```text
dir build\app\outputs\flutter-apk\app-release.apk
dir build\app\outputs\bundle\release\app-release.aab
```

### 5.2 APK SHA-256 / AAB SHA-256

```text
certutil -hashfile build\app\outputs\flutter-apk\app-release.apk SHA256
certutil -hashfile build\app\outputs\bundle\release\app-release.aab SHA256
```

### 5.3 APK 签名验证（apksigner）

```text
apksigner verify --verbose --print-certs build\app\outputs\flutter-apk\app-release.apk
```

### 5.4 AAB jarsigner 验证

```text
jarsigner -verify build\app\outputs\bundle\release\app-release.aab
```

### 5.5 applicationId / versionName / versionCode（aapt）

```text
aapt dump badging build\app\outputs\flutter-apk\app-release.apk
```

### 5.6 Permissions（aapt）

```text
aapt dump permissions build\app\outputs\flutter-apk\app-release.apk
```

### 5.7 Release vs Debug 证书对比

```text
apksigner verify --print-certs build\app\outputs\flutter-apk\app-release.apk
apksigner verify --print-certs build\app\outputs\flutter-apk\app-debug.apk
```

> 上方 5.3 / 5.5 / 5.6 命令依赖 `apksigner` / `aapt` 在 PATH 中或通过 `D:\Program Files (x86)\Android\android-sdk\build-tools\<version>\` 定位。本任务提供的 Dart 脚本 `tool/verify_release_artifacts.dart` 自动按 `ANDROID_HOME` / `ANDROID_SDK_ROOT` / 常见 Windows SDK 路径定位工具。

### 5.8 自动化校验脚本

```text
dart run tool/verify_release_artifacts.dart
```

> 脚本覆盖 1.1 / 1.2 / 2 / 3 / 4 全部字段的自动化断言。脚本仅使用 Dart 标准库（`dart:io`），不新增依赖，不修改任何构建产物，不读取 `android/key.properties` 内容，不打印用户目录下 keystore 路径，不打印密码。

## 6. Known Limitations

1. **本文档不代表真机验收完成**。真机安装 / 启动 / 核心流程冒烟 / 杀进程 / 强行停止重启 由 T023 任务在用户真机上完成；Agent 不得代写"通过"。
2. **本文档不代表已提交应用商店**。AAB 不可双击安装到 Android 设备；商店提交动作不在 Release 工程化阶段范围内。
3. **本文档不代表真实录音功能已实现**。`AndroidManifest.xml` 中仅保留 `<!-- MVP: no INTERNET permission. Offline only. -->` 与 `<!-- MVP: no RECORD_AUDIO. Tuner and recording are simulated only. -->` 注释，`RECORD_AUDIO` 权限**未**声明；当前 MVP 的录音 / 回放 / 调音均为**模拟**行为，详见 `docs/dev/TECH_DEBT.md` TD-007。
4. **AAB 不能像 APK 一样直接普通安装**。AAB（Android App Bundle）是 Google Play 用于按设备架构分发 APK 的打包格式，需要通过 `bundletool` 或 Play Console 转换为 split APK 后才能安装。
5. **T023 仍需用户真机安装和冒烟验收**。本文档只是 Release 产物的静态台账；真机行为（冷启动 / 热启动 / 任务完成持久化 / 练习记录详情 / 删除 / 杀进程保留等）必须由用户在 T023 任务中手动确认。
6. **基线 Commit 与 Release 构建 Commit 不一致**。本文档记录基线 `4b5b386` 与 Release 构建 `d7bac44` 不一致——这是因为 T021A 阶段在 `4b5b386` 之后追加了协作机制文档（不影响 Release 产物元信息），所以 Release 构建的源码基线等价于 T021 阶段的 `d7bac44`。该差异不构成真机验证缺陷，但 T024 报告须明确这一点。
7. **Debug APK 元信息不固化在本文档**。Debug APK 仅用于 Release vs Debug 证书指纹对比（见 §3.3），Debug APK 的字节大小 / SHA-256 不进入 Release 产物台账。
8. **ABI 列表来源于 aapt `native-code:`**。该字段反映 APK 内嵌的 native code 集合（`arm64-v8a` / `armeabi-v7a` / `x86_64`），与 Flutter 默认 ABI 派生一致；本文档不固化 `flutter.minSdkVersion` / `flutter.targetSdkVersion` 等 Flutter SDK 派生值。