# 真实音频 MVP v1.1.0 Release Checkpoint (REAL_AUDIO_MVP_V110_RELEASE_CHECKPOINT)

> 本文档记录 T039 阶段在 `1.1.0+3` 版本号下的 **真实音频 MVP v1.1.0 发布准备**:版本号 bump、`v1.1.0` annotated tag、`master` 分支与 tag 的 fast-forward push。本文档**不**重写旧提交、**不**修改代码 / 测试 / 依赖 / Manifest / Gradle / schema / 签名配置。
>
> ⚠️ 本文档**不**创建 GitHub Release, **不**上传 APK / AAB 到任何远程, **不**读取或输出 `android/key.properties` 内容 / keystore 密码 / alias / 敏感路径。
> ⚠️ 本文档仅覆盖单台真机 (HUAWEI CDY-AN90 / Android 10), 未覆盖其他国产 ROM 或 Android 版本。
> ⚠️ 本文档**不**包含机器可验证的音质指标 (采样率 / 比特率 / 频率响应等), 仅含 T037 + T038 + T038B 既有真机验收结论。
> ⚠️ 本文档**不**修复构建缺陷 / **不**修改生产代码 / **不**修改签名配置 / **不**修改 Manifest / **不**修改 schema / **不**修改依赖 / **不**修改 `key.properties` / **不**修改 `pubspec.lock` / **不**修改 `app_database.g.dart` / **不**新增 INTERNET 权限 / **不** push / **不** tag 在本文档阶段。

## Document Status

| 字段 | 值 |
| --- | --- |
| Task ID | `T039_REAL_AUDIO_MVP_VERSION_TAG_AND_PUSH_RESUME` |
| 基线 Commit | `cb28bca40460d5dd5ae4bdbe413bf7b4302423ab` |
| 起始提交 | `cb28bca40460d5dd5ae4bdbe413bf7b4302423ab` (与基线相同) |
| HEAD (最终) | 待本次提交 (`chore: release v1.1.0`) |
| 测试基线 | **711** 项 `flutter test` 通过 (与 T038B 既有基线一致; T039 **不**新增 / 删除自动化测试) |
| Version | `1.1.0+3` (从 `1.0.0+2` bump) |
| Tag | `v1.1.0` (annotated, 待创建) |
| 设备 | HUAWEI CDY-AN90 / Android 10 |
| 真实音频闭环 | T037 + T038 + T038B 全部 Approved |
| 构建产物 | Release APK = 58.2 MiB / Release AAB = 57.8 MiB (与 T038 一致区间) |
| 格式漂移审计 | **0** 个格式漂移 (`git diff --check` exit 0) |
| 修改文件范围 | **1** 个版本文件 (`pubspec.yaml` 版本号) + **3** 个允许文档 (本文档新建 + `docs/dev/TASK_LEDGER.md` 追加 + `docs/dev/TECH_DEBT.md` 校准) |
| **Checkpoint 状态** | **READY_FOR_PUSH** (版本号 bump 完成 + 711 测试通过 + APK / AAB 构建通过 + 签名通过 + 格式漂移审计 0 + 数据丢失风险 0 + 仅本地单向前进 30 个提交) |

## Starting Commit

| 字段 | 值 |
| --- | --- |
| Commit | `cb28bca40460d5dd5ae4bdbe413bf7b4302423ab` |
| 标题 | `docs: approve real audio MVP release checkpoint` |
| 作者 | yyd841122 |
| 日期 | 2026-06-24 (与本任务执行同日) |
| 状态 | HEAD (最终, push 前) |
| 严格匹配 | **是** (`git rev-parse HEAD` 启动检查时与基线一致) |

## Device

| 字段 | 值 |
| --- | --- |
| 设备型号 | `HUAWEI CDY-AN90` |
| Android 版本 | `10` |
| Android SDK | `29` |
| 设备序列号 | **脱敏** (仅保留型号 + Android 版本; 不记录完整 serial 或后 4 位) |
| 厂商 ROM | 华为 EMUI / HarmonyOS (具体子版本不记录) |

> **单设备覆盖限制 (强警告)**: 本验收**仅**覆盖上述单台真机。`REAL_AUDIO_DEPENDENCY_SPIKE.md` §3.6 + `TECH_DEBT.md` TD-013 明确指出, 国产 ROM 兼容性必须由真机用户验收, 本文档**不**能据此推断其他 ROM 已通过验证。

## Version Bump

| 字段 | 旧值 | 新值 |
| --- | --- | --- |
| `pubspec.yaml` `version` | `1.0.0+2` | `1.1.0+3` |

**未**修改字段 (T039 范围外): `name` / `description` / `environment` / `dependencies` / `dev_dependencies` / `flutter` 配置 / `pubspec.lock` / `key.properties` / `AndroidManifest.xml` / `build.gradle` / `app_database.dart` (schemaVersion = 2) / 任何生产代码 / 任何测试。

## Verification Results

### `flutter analyze`

```
Analyzing ukulele_app...
No issues found! (ran in 7.0s)
```

✅ **PASS** — 无静态分析问题。

### `flutter test`

```
00:25 +711: All tests passed!
```

✅ **PASS** — **711** 项测试全部通过 (与 T038B 基线一致; T039 未新增 / 删除测试)。

### `flutter build apk --release`

```
√ Built build\app\outputs\flutter-apk\app-release.apk (58.2MB)
```

✅ **PASS** — Release APK = 61,064,006 bytes (≈ 58.2 MiB)。签名通过 (`apksigner verify` exit 0, schemes = v2 / v3 / v4, Release 证书与 Debug 证书不同)。

### `flutter build appbundle --release`

```
√ Built build\app\outputs\bundle\release\app-release.aab (57.8MB)
```

✅ **PASS** — Release AAB = 60,586,365 bytes (≈ 57.8 MiB)。签名通过 (`jarsigner -verify` exit 0)。

### `git diff --check`

```
---EXIT: 0---
```

✅ **PASS** — 0 个格式漂移 / whitespace conflict。

### `dart run tool/verify_release_artifacts.dart`

```
[ARTIFACT] build/app/outputs/flutter-apk/app-release.apk exists
[ARTIFACT] build/app/outputs/bundle/release/app-release.aab exists
[SIZE] build/app/outputs/flutter-apk/app-release.apk = 61064006 bytes
[SIZE] build/app/outputs/bundle/release/app-release.aab = 60586365 bytes
[SHA256] build/app/outputs/flutter-apk/app-release.apk = f861139f070235a46a35c16df398c37444bb8b0a1b098c4fb339d271697d4dc2
[SHA256] build/app/outputs/bundle/release/app-release.aab = cc55146ac8e3246abaeffadc3ed28f43bd2ed4814de1d1afd20ed4824bc06a7b
[APKSIGN] apksigner verify exit=0 schemes=APK Signature Scheme v2,APK Signature Scheme v3,APK Signature Scheme v4 certSha256=e88687e53b272c86d20611c1045fc00d2fd4ca321672b1eec180d7543dc28591
[JARSIGN] jarsigner -verify exit=0 (AAB)
[AAPT] applicationId=com.yupi.ukulele versionName=1.1.0 versionCode=3
[APKSIGN.debug] apksigner verify --print-certs build/app/outputs/flutter-apk/app-debug.apk exit=0
[DEBUG] Release cert sha256=e88687e53b272c86d20611c1045fc00d2fd4ca321672b1eec180d7543dc28591, Debug cert sha256=5e46d372a98f40e250a74e249ff318c27b65e3c259801a70b807508a0f4e8662, differ=true
```

⚠️ **T022 verifier 硬编码 v1.0.0 基线, 输出 3 项 "FAIL"**: `versionName mismatch (expected 1.0.0, got 1.1.0)` + `versionCode mismatch (expected 2, got 3)` + `Forbidden permission declared in Manifest: android.permission.RECORD_AUDIO`。这 3 项**正是 v1.1.0 相对 v1.0.0 的预期差异**, 不构成 blocker:
- 版本号 mismatch 是 v1.1.0 release 的**目的**, 不是缺陷。
- `RECORD_AUDIO` 在 v1.0.0 时被列入 forbidden 是因为 T022 verifier 当时尚无真实音频能力; v1.1.0 已落地真实音频 MVP (T030~T038B), `RECORD_AUDIO` 是**必需**权限 (已在 main Manifest 中正确声明, 无 INTERNET)。
- 真正关键的安全 / 签名 / 产物存在性 / Release 与 Debug 证书差异 / scheme v2 / v3 / v4 全 PASS。

> T039 **不**修改 T022 verifier; 该 verifier 是 T022 阶段的产物, 升级 verifier 越界。下一阶段如需 v1.1.0 自动化基线, 应在新任务 (例如 T040+) 中改造 verifier。

### Sensitive Files Checked

| 路径 | `git ls-files` | `git status --ignored` | 期望 | 实际 |
| --- | --- | --- | --- | --- |
| `android/key.properties` | 空 | `!!` (ignored) | ignored / untracked | ✅ ignored / untracked |
| `*.jks` | 空 | — | 未跟踪 | ✅ 未跟踪 |
| `*.keystore` | 空 | — | 未跟踪 | ✅ 未跟踪 |
| `build/app/outputs/**` | 空 | `!! build/` (ignored) | ignored / untracked | ✅ ignored / untracked |

✅ **PASS** — 所有敏感 / 产物路径均未被 git 跟踪, 无 keystore / 密码泄露风险。

### Drift schemaVersion

```
lib/data/database/app_database.dart: int get schemaVersion => 2;
```

✅ **PASS** — schemaVersion = 2 (T032 升级后的稳定值, 与 T038 / T038B 一致)。

### Manifest INTERNET Audit

```
android/app/src/main/AndroidManifest.xml:    <!-- MVP: no INTERNET permission. Offline only. -->
android/app/src/debug/AndroidManifest.xml:  <!-- MVP: no INTERNET permission in debug build. Offline only. -->
android/app/src/profile/AndroidManifest.xml:<!-- MVP: no INTERNET permission in profile build. Offline only. -->
```

✅ **PASS** — 三个 Manifest build variant 均**未**声明 `android.permission.INTERNET`, 与 T038 / T038B 一致。

## Git Divergence Status

### Local / Remote HEAD

| Ref | SHA | Subject |
| --- | --- | --- |
| `master` (HEAD) | `cb28bca40460d5dd5ae4bdbe413bf7b4302423ab` | `docs: approve real audio MVP release checkpoint` |
| `origin/master` | `703d2aa20dfe44f5d7a0628978ceeb12b9165614` | `docs: record Android release acceptance checkpoint` |
| `merge-base` | `703d2aa` = `origin/master` | (本地 30 个提交严格接在 origin 尖端之上) |

### Divergence Classification

```
git rev-list --left-right --count master...origin/master
→ 30    0
```

✅ **Local-only ahead** (非真正分叉): origin 没有任何本地没有的提交, `merge-base = origin/master`, 本地 30 个提交是真实音频 MVP 的设计→实现→测试→验收闭环, 父链严格线性, reflog 无 rebase / cherry-pick / reset 改写事件。

### Existing Tags

| Tag | Local SHA | Remote SHA | 状态 |
| --- | --- | --- | --- |
| `v0.1.0-mvp` | `d49ce4bdd5ea2a1aded4d7910e94172213f89093` | `d49ce4bdd5ea2a1aded4d7910e94172213f89093` | ✅ 未变 |
| `v1.0.0-release` | `703d2aa20dfe44f5d7a0628978ceeb12b9165614` | `703d2aa20dfe44f5d7a0628978ceeb12b9165614` | ✅ 未变 |

✅ `v1.1.0` 在本地与远程均**不存在** (push 前 T039 会创建本地 annotated tag)。

## Commit Plan

| 顺序 | 操作 | 命令 | 期望 |
| --- | --- | --- | --- |
| 1 | 验证前置 | `flutter analyze` / `flutter test` / `flutter build apk --release` / `flutter build appbundle --release` / `git diff --check` | 全部 PASS (已 ✅) |
| 2 | 提交版本 + 文档 | `git add pubspec.yaml docs/qa/REAL_AUDIO_MVP_V110_RELEASE_CHECKPOINT.md docs/dev/TASK_LEDGER.md docs/dev/TECH_DEBT.md && git commit -m "chore: release v1.1.0"` | 新 HEAD 创建, HEAD 仍匹配发布 commit |
| 3 | 创建 annotated tag | `git tag -a v1.1.0 -m "Real audio MVP release v1.1.0"` | `v1.1.0` 指向发布 commit, `v1.1.0^{commit}` 同一 SHA |
| 4 | 推送前再 fetch + 验证祖先关系 | `git fetch origin && git merge-base --is-ancestor origin/master master && echo ANCESTOR_OK` | 输出 `ANCESTOR_OK` |
| 5 | 获得用户 push 授权 | AskUserQuestion | 用户明确授权 |
| 6 | 原子推送 | `git push origin master v1.1.0` | `origin/master` 移到新 HEAD, `refs/tags/v1.1.0` 创建 |
| 7 | 推送后验证 | `git ls-remote origin master refs/tags/v1.1.0 refs/tags/v1.0.0-release refs/tags/v0.1.0-mvp` | 所有 ref 位置符合预期, 工作区 clean |

## Out of Scope (T039 明确不做)

- ❌ rebase / amend / reset / force push / 修改旧提交邮箱
- ❌ `git gc --prune=now` (会销毁 14 个不可达 commit + 悬空对象)
- ❌ T022 verifier 升级 (越界, 留待下一阶段)
- ❌ GitHub Release 创建 / APK / AAB 上传
- ❌ INTERNET 权限新增 / 移除
- ❌ Manifest / Gradle / Drift schema / 签名配置修改
- ❌ 生产代码 / 测试代码 / 依赖 / lock 文件修改
- ❌ 清理悬空对象 / 技术债批量处理