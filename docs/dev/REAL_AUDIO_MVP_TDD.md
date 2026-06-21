# 真实音频 MVP TDD（REAL_AUDIO_MVP_TDD）

> 本文档是 ukulele_app **真实录音与回放 MVP 阶段**的测试驱动开发计划（Test-Driven Development Plan）。
>
> ⚠️ 本文档**只做测试设计**，**不新增测试代码、不运行 build_runner、不构建 APK/AAB、不 push、不创建 Tag、不开始 T026**。
>
> ⚠️ 本文档对应 `docs/dev/REAL_AUDIO_MVP_SDD.md` 的实现阶段（T026-T037）；本任务 T025 仅做设计。

## Document Status

| 字段 | 值 |
| --- | --- |
| Task ID | `T025_REAL_AUDIO_MVP_SDD_TDD_DESIGN` |
| 基线 Commit | `703d2aa` |
| Release Tag | `v1.0.0-release` → `703d2aa` |
| 当前版本 | `1.0.0+2`（versionName=`1.0.0`, versionCode=`2`） |
| 状态 | **设计中**（仅完成 SDD/TDD 设计；测试代码尚未编写） |
| 是否新增 / 更新 / 删除测试 | **0 / 0 / 0** |
| 是否新增测试代码 | **否** |
| 是否运行 build_runner | **否** |
| 是否构建 APK/AAB | **否** |
| 是否 push | **否** |
| 下一步建议 | `T026_DEPENDENCY_RESEARCH_SPIKE` 后由 T035 进入自动化测试 |

## 1. Test Strategy

### 1.1 测试分层

| 层 | 范围 | 工具 | 关键约束 |
| --- | --- | --- | --- |
| Pure unit tests | 工具函数 / 数据模型 / 路径生成规则 / 错误类型映射 | `flutter_test` | 不依赖 Flutter binding；可在纯 Dart VM 运行 |
| Controller tests | `RecordingPracticeController` 状态机 / `PracticeRecordDetailController` 删除流程 | `flutter_test` + `ProviderContainer` | 通过 Provider 注入 mock 服务；不调用真实平台 API |
| Repository tests | `PracticeRecordRepository` 写入校验 / Drift CRUD | `flutter_test` + Drift in-memory | 使用 `NativeDatabase.memory()`；测试数据库与生产路径隔离 |
| Drift migration tests | `schemaVersion = 1 → 2` 迁移 | `flutter_test` + Drift `Migrator` | 必须有"旧数据迁移后保持完整"测试 + "新增字段默认值正确"测试 |
| File storage tests | `AudioFileStorageService` 路径生成 / 存在性检查 / 删除 | `flutter_test` + `path_provider` mock | 测试路径必须使用临时目录（`Directory.systemTemp.createTempSync()`） |
| Permission behavior tests | `PermissionService` 状态映射（拒绝 / 永久拒绝 / 授予） | `flutter_test` + 自定义 mock | 不触发真实系统权限弹窗；通过 mock `permission_handler` 接口 |
| Widget tests | 录音页 / 详情页 UI 状态切换 | `flutter_test` | 通过 `ProviderScope.overrides` 注入 mock 服务 |
| Integration tests | 完整录音 → 保存 → 回放 → 删除流程 | `integration_test` | **不**进入本阶段 CI；真机手动验收优先 |
| Android real-device manual acceptance | 真机录音 / 权限 / 厂商 ROM 兼容 | 用户手动 + adb | **必须**由用户本人在真机上完成；Agent 不得代写"通过" |

### 1.2 测试编写时机

- T028（AudioFileStorageService）开始 **TDD**（先写测试，后写实现）；
- T029 / T030（真实录音 / 回放服务）严格 **TDD**；
- T031（Controller 状态机）严格 **TDD**；
- T032（Drift 迁移）严格 **TDD**（迁移测试必须先于迁移代码）；
- T033（UI 文案）Widget 测试覆盖关键文案与状态切换；
- T035 总集成测试覆盖完整录音 → 回放 → 删除 → 文件清理。

### 1.3 测试基线

| 项 | 值 |
| --- | --- |
| 当前测试基线 | 407 tests passed（T024 阶段锁定） |
| 真实音频 MVP 上线后预期 | 407 + 新增测试 ≥ 30 项（不含手动验收） |
| 真实音频 MVP 不得删除既有测试 | 既有 407 项测试 100% 保留 |
| 测试数下降处理 | 任何测试数下降必须由 Agent 显式说明原因，且不得在 T025 - T037 期间降低 |

### 1.4 测试覆盖目标

| 目标 | 度量 |
| --- | --- |
| Controller 状态机覆盖率 | 每个状态至少有 1 个正向测试 + 1 个反向测试 + 1 个边界测试 |
| Repository 写入校验 | `audioFilePath` 为 null / 真实路径 / 非法路径 三种情况各有测试 |
| Drift 迁移测试 | schemaVersion 1 → 2 完整迁移路径测试；旧数据保留测试；新增字段默认值测试 |
| 权限行为测试 | 拒绝 / 永久拒绝 / 授予 / App 内重试 / 系统设置跳转 五种路径 |
| UI 状态机测试 | 每个 RecordingState 至少 1 个 Widget 测试 |

## 2. Test Matrix（≥30 条）

> 以下测试用例覆盖真实音频 MVP 核心场景。编号用于 T035 任务追踪；不构成"已编写"声明。

### 2.1 权限场景（5 条）

| # | 用例 | 类型 | 期望 |
| --- | --- | --- | --- |
| TC-P01 | 用户首次点击"开始真实录音"且已授权 → 状态切换为 `recording` | Controller | `AudioRecorderService.start()` 被调用 1 次；状态 = `recording` |
| TC-P02 | 用户首次点击"开始真实录音"且一次性拒绝 → 状态切换为 `permissionDenied`；UI 显示"重新申请权限"按钮 | Controller + Widget | `PermissionService.request()` 返回 `denied`；不调用 `AudioRecorderService.start()` |
| TC-P03 | 永久拒绝后用户点击"前往系统设置" → 调用 `openAppSettings()` | Controller | `PermissionService.openAppSettings()` 被调用 |
| TC-P04 | 永久拒绝后用户再次点击"申请权限" → 仍判定为永久拒绝；不调用 `request()` | Controller | 状态保持 `permissionPermanentlyDenied`；不调用 `request()` |
| TC-P05 | 用户从系统设置返回后重新进入录音页 → Controller 重新查询权限状态 | Controller | 状态根据最新权限状态更新；不残留旧 `permissionDenied` 状态 |

### 2.2 录音场景（6 条）

| # | 用例 | 类型 | 期望 |
| --- | --- | --- | --- |
| TC-R01 | 用户点击"开始真实录音"且已授权 → 录音启动成功 | Controller | `AudioRecorderService.start()` 被调用；临时文件创建于 `_tmp/`；状态 = `recording` |
| TC-R02 | 用户在录音中点击"停止" → 录音停止，文件保留 | Controller | `AudioRecorderService.stop()` 返回文件路径；状态 = `recorded`；临时文件迁移（或保留待保存） |
| TC-R03 | 用户在录音中点击"取消" → 录音停止，文件被删除 | Controller | `AudioRecorderService.cancel()` / `stop() + delete()`；临时文件删除；状态 = `idle` |
| TC-R04 | 用户在录音中 App 进入后台 → 录音强制停止 | Controller | `appPaused` 触发；录音停止；已写入磁盘数据保留；状态 = `recorded` |
| TC-R05 | 录音到达 5 分钟上限 → 自动停止 | Controller | `AudioRecorderService` 内部触发自动停止；状态 = `recorded`；UI 显示"录音已达上限"提示 |
| TC-R06 | 录音到达 4:30 → UI 提示"还剩 30 秒" | Widget | UI 文案变更；状态仍为 `recording` |

### 2.3 回放场景（4 条）

| # | 用例 | 类型 | 期望 |
| --- | --- | --- | --- |
| TC-PB01 | 用户点击"播放" → 真实音频文件播放 | Controller | `AudioPlaybackService.play(path)` 被调用；状态 = `playing` |
| TC-PB02 | 用户在播放中点击"停止回放" → 播放停止 | Controller | `AudioPlaybackService.stop()` 被调用；状态回到 `recorded` |
| TC-PB03 | 用户在播放中尝试开始录音 → 按钮禁用或先停止播放 | Controller / Widget | 录音按钮在 `playing` 状态被禁用；或先停止播放再进入 `recording` |
| TC-PB04 | 播放时文件丢失 → `error(playbackFailed)`；UI 隐藏回放按钮 | Controller | `AudioFileResolver.exists()` 返回 `false`；不调用 `play()`；`audioDeletedAt` 标记 |

### 2.4 保存场景（4 条）

| # | 用例 | 类型 | 期望 |
| --- | --- | --- | --- |
| TC-S01 | 用户点击"保存为练习记录" → 数据库写入 + 文件迁移到正式目录 | Repository | `audioFilePath` 写入真实路径；`audioDurationMs` / `audioFormat` / `audioFileSizeBytes` / `audioCreatedAt` / `recordingMode = "real"` 写入正确 |
| TC-S02 | 保存时数据库写入失败 → 文件被回滚删除 | Repository | Drift `insert` 抛异常；关联文件被 `delete()`；状态 = `error(fileWriteFailed)` |
| TC-S03 | 保存时 `audioFilePath` 为非法路径（文件不存在） → Repository 拒绝写入 | Repository | `AudioFileNotFoundException`；不写入数据库 |
| TC-S04 | 保存成功 → UI 跳转 / 清理临时文件 | Controller | 状态 = `saved`；临时文件已删除（或确认不需要清理） |

### 2.5 删除场景（3 条）

| # | 用例 | 类型 | 期望 |
| --- | --- | --- | --- |
| TC-D01 | 用户删除真实录音记录 → 数据库行删除 + 文件删除 | Repository + File | Drift `delete()` 调用 1 次；`AudioFileStorageService.delete(path)` 调用 1 次 |
| TC-D02 | 删除时文件不存在 → 数据库行仍删除；UI 提示 SnackBar "记录已删除，音频文件不存在" | Repository | Drift `delete()` 成功；不抛异常 |
| TC-D03 | 删除时文件删除失败 → 数据库行已删除；UI 提示 SnackBar "记录已删除，音频文件删除失败" | Repository | Drift `delete()` 成功；`AudioFileStorageService.delete()` 返回 `false`；UI SnackBar 提示用户手动清理 |

### 2.6 数据迁移场景（4 条）

| # | 用例 | 类型 | 期望 |
| --- | --- | --- | --- |
| TC-M01 | schemaVersion 1 数据库迁移到 schemaVersion 2 → 迁移成功；旧记录保留 | Drift migration | `Migrator.migrate(1, 2)` 成功；旧记录 `audioFilePath = null` 保留；新增字段填默认值 |
| TC-M02 | 迁移后旧记录查询 → `recordingMode = "simulated"` | Drift migration | 旧记录 `recordingMode` 字段 = `"simulated"` |
| TC-M03 | 迁移后旧记录写入新字段默认值 → `audioDurationMs = 0` / `audioFormat = "unknown"` / `audioFileSizeBytes = 0` / `audioCreatedAt = practiceDate` | Drift migration | 所有新增字段值符合 §6.2 默认值约定 |
| TC-M04 | 迁移前后 `audioFilePath` 契约不变（仍允许 `null`） | Drift migration | 旧记录 `audioFilePath = null` 仍合法 |

### 2.7 文件系统场景（3 条）

| # | 用例 | 类型 | 期望 |
| --- | --- | --- | --- |
| TC-F01 | `AudioFileStorageService.generatePath(recordId)` → 返回预期路径 | Pure unit | 路径格式符合 §4.3 约定；不在公共目录 |
| TC-F02 | `AudioFileStorageService.exists(path)` 对已存在文件返回 `true`，对不存在文件返回 `false` | File | 行为正确；不抛异常 |
| TC-F03 | `AudioFileStorageService.delete(path)` 成功删除文件；文件不存在时不抛异常 | File | 行为符合 §6.5 / §6.7 约定 |

### 2.8 旧模拟记录兼容（2 条）

| # | 用例 | 类型 | 期望 |
| --- | --- | --- | --- |
| TC-LR01 | 列表显示旧模拟记录 → 回放按钮隐藏；显示"模拟录音（历史记录）"标识 | Widget | UI 行为与 MVP PRD §6.7 一致 |
| TC-LR02 | 旧模拟记录详情页打开 → 回放按钮隐藏；不调用 `AudioPlaybackService` | Controller | `audioFilePath == null` 时不调用播放服务 |

### 2.9 互斥与状态机（3 条）

| # | 用例 | 类型 | 期望 |
| --- | --- | --- | --- |
| TC-SM01 | 录音中尝试播放 → 录音按钮禁用 / 互斥锁生效 | Controller / Widget | 播放按钮在 `recording` 状态被禁用 |
| TC-SM02 | 保存中所有关键按钮禁用 → 录音 / 取消 / 删除均不可触发 | Controller / Widget | `saving` 状态下按钮 `onPressed = null` |
| TC-SM03 | 快速连续点击"开始录音" → 仅触发 1 次 `AudioRecorderService.start()` | Controller | 防抖或状态守卫生效 |

### 2.10 合规 / 隐私（3 条）

| # | 用例 | 类型 | 期望 |
| --- | --- | --- | --- |
| TC-CP01 | 启动 App 不触发 `RECORD_AUDIO` 权限弹窗 | Manual + aapt | `aapt dump permissions` 不含 `RECORD_AUDIO` 在 App 启动后状态 |
| TC-CP02 | 真实音频阶段仍未声明 `INTERNET` 权限 | aapt | `aapt dump permissions` **未**含 `INTERNET` |
| TC-CP03 | 真实音频阶段 PrivacyNoticePage 文案包含"麦克风权限用途 / 录音本地存储 / 不上传" | Widget | 关键短语命中；不出现"上传" / "分享" 等误导文案 |

### 2.11 真机验收（独立于自动化测试）

| # | 用例 | 类型 | 期望 |
| --- | --- | --- | --- |
| TC-DA01 | T036 真机手工验收完整通过 | Manual | 用户在真机上确认；详见 `REAL_AUDIO_MVP_ACCEPTANCE.md`（T037 任务产出） |

> **总计**：30+ 条自动化测试用例 + 1 条真机验收用例。手动验收清单详见 §3。

## 3. Manual Acceptance Checklist（Android 真机手工验收）

> 由用户本人在真机上完成。Agent 仅产出验收模板，**不得代写"通过"**。
> 设备基线：单台 Android 真机（HUAWEI CDY-AN90 / Android 10 / SDK 29 或更高版本）；后续扩展多设备由 GPT 首席架构师决定。

| # | 验收项 | 期望 | 证据来源 |
| --- | --- | --- | --- |
| MA-01 | 首次进入录音页 → 显示"需要麦克风权限"提示，未弹系统弹窗 | UI 文案正确 | User confirmed |
| MA-02 | 点击"开始真实录音" → 系统弹窗出现 "允许 ukulele_app 使用麦克风？" | 系统弹窗触发 | User confirmed |
| MA-03 | 系统弹窗中选择"拒绝" → 录音页显示"权限被拒绝" + "重新申请权限"按钮 | UI 降级 | User confirmed |
| MA-04 | 系统弹窗中选择"永久拒绝"（勾选"不再询问"）→ 录音页显示"前往系统设置"按钮 | UI 降级 | User confirmed |
| MA-05 | 授权后再次点击"开始真实录音" → 录音正常启动，UI 显示"正在录音：00:00 / 05:00" | UI 状态正确 | User confirmed |
| MA-06 | 录音到 0:10 → 点击"停止" → 录音页切换为"录音完成：00:10" + "保存为练习记录"按钮 | UI 状态切换 | User confirmed |
| MA-07 | 在 `recorded` 状态点击"播放" → UI 切换为"回放中"且能听到刚录制的音频 | 真实音频播放 | User confirmed |
| MA-08 | 录音中来电 → 录音强制停止，已录制部分保留 | 系统行为正确 | User confirmed |
| MA-09 | 点击"保存为练习记录" → 跳转至记录列表 / 详情，新记录包含真实音频文件 | 数据流正确 | User confirmed |
| MA-10 | 记录列表显示真实录音记录，包含真实时长 | UI 显示正确 | User confirmed |
| MA-11 | 进入记录详情 → 显示真实音频回放按钮；点击播放可听到录制内容 | UI 状态正确 | User confirmed |
| MA-12 | 长按 / 菜单点击"删除记录" → 数据库行删除 + 音频文件被删除；UI 提示删除成功 | 删除流程完整 | User confirmed |
| MA-13 | 删除后通过文件管理器进入 `/data/user/0/com.yupi.ukulele/app_flutter/recordings/` → 关联文件不存在 | 文件清理生效 | adb shell run-as / 文件管理器（仅开发态可见） |
| MA-14 | 强行停止 App → 重启 → 已保存的真实录音记录可正常播放 | 数据持久化正确 | User confirmed |
| MA-15 | 卸载 App → 重装 → 数据库为空（验证文件已随卸载清除） | 数据隔离正确 | User confirmed |
| MA-16 | App 启动 / 首页 / 设置页 均不触发任何权限弹窗 | 权限延迟申请 | User confirmed |
| MA-17 | 设置 → 关于 → 隐私说明 → 文案包含"麦克风权限用途 / 录音本地存储 / 不上传" | 文案准确 | User confirmed |
| MA-18 | 通过网络抓包 / 系统权限监控 / `aapt dump permissions` → App 没有任何联网行为；`INTERNET` 权限未声明 | 无联网原则保留 | aapt + 抓包工具 |
| MA-19 | 设置大字体 → 录音页无明显溢出 / 截断 | 大字体适配 | User confirmed |
| MA-20 | 设置大字体 + 录音中状态 → UI 不出现 RenderFlex overflow | 大字体 + 状态适配 | User confirmed |
| MA-21 | 旧模拟记录（`audioFilePath = null`）详情页打开 → 回放按钮隐藏，显示"模拟录音（历史记录）"标识 | 旧记录兼容 | User confirmed |
| MA-22 | 真实音频文件被外部删除 → 重新进入详情页 → 回放按钮自动隐藏 | 文件丢失处理 | User confirmed |

### 3.1 验收证据采集

| 证据类型 | 工具 | 备注 |
| --- | --- | --- |
| 用户确认 | 用户本人在真机上勾选 | `User confirmed` |
| 权限声明 | `aapt dump permissions build/app/outputs/flutter-apk/app-release.apk` | 仅在 T036 任务执行；本任务不构建 APK |
| 联网检测 | 抓包工具 / `dumpsys` | 用户自愿 |
| 文件清理 | `adb shell run-as com.yupi.ukulele ls app_flutter/recordings/` | 需 Debug build 可见；Release build 仅 root 设备可见 |

## 4. Regression Matrix（真实音频阶段不能破坏既有 MVP / Release 工程化）

| # | 既有功能 | 回归测试 / 验证 |
| --- | --- | --- |
| RR-01 | 今日练习 7 天循环 + 任务完成状态持久化 | `flutter test` 既有 407 项 + T013.3 系列 |
| RR-02 | 任务状态持久化（重启后保留） | 既有集成测试 + T036 真机验证 |
| RR-03 | 和弦库 / 指法图 / 和弦详情 | 既有 widget tests |
| RR-04 | 单音练习 / 上一个 / 下一个导航 | 既有 widget tests |
| RR-05 | 节拍器（开始 / 暂停 / 停止 / BPM 50-200 / 切页停止） | 既有 widget tests |
| RR-06 | 调音器（G/C/E/A 手动选弦 / 频率 + 偏差 / 实验性降级） | 既有 widget tests + T036 真机验证 |
| RR-07 | 调音器**不**申请麦克风 / 不调用真实麦克风 | 真机 MA-16 + aapt 验证 |
| RR-08 | 练习记录列表 / 详情 / 删除 | 既有 widget tests（391 项） |
| RR-09 | 删除记录级联清理音频文件（旧模拟记录无文件，新真实记录有文件） | T035 新增测试 + 真机 MA-12 |
| RR-10 | Drift schemaVersion 1 数据库 schema 与 Repository 契约 | 既有 schema tests |
| RR-11 | Release 签名（Release 证书 SHA-256 = `e88687e5…d28591`） | 静态校验脚本（既有） |
| RR-12 | Release APK / AAB 构建产物元信息 | 静态校验脚本（既有） |
| RR-13 | 无 `INTERNET` 权限 | `aapt dump permissions` 不含 |
| RR-14 | `v1.0.0-release` Tag 指向 `703d2aa` | `git rev-parse v1.0.0-release^{commit}` = `703d2aa` |
| RR-15 | `v0.1.0-mvp` Tag 指向 `d49ce4b` | `git rev-parse v0.1.0-mvp^{commit}` = `d49ce4b` |
| RR-16 | `android/key.properties` 仍 ignored / untracked | `git ls-files android/key.properties` 返回空 |
| RR-17 | `*.jks` / `*.keystore` 仍未跟踪 | `git ls-files "*.jks"` / `"*.keystore"` 返回空 |
| RR-18 | 构建产物未被 `git ls-files` 跟踪 | `git ls-files build/app/outputs/**` 返回空 |
| RR-19 | `flutter analyze` 仍 `No issues found!` | T035 前后均需验证 |
| RR-20 | `flutter test` 测试数 ≥ 407（不得下降） | T035 前后均需验证 |

### 4.1 回归失败处理

- 任一既有功能回归 → 立即停止 T035+；
- 由 Agent 提交回归报告给 GPT 首席架构师；
- 不允许"为通过真实音频阶段而牺牲既有 MVP / Release 工程化验收"。

## 5. Test Gaps（已知无法自动化覆盖的边界）

| 缺口 | 说明 | 缓解 |
| --- | --- | --- |
| 真实麦克风输入 | 自动测试无法验证真实音频输入质量 | 用户真机验收（MA-05）+ 录音文件大小 / 时长断言 |
| 真实音频播放质量 | 自动测试无法人耳验证音质 | 用户真机验收（MA-07 / MA-11）+ 文件可读性断言 |
| iOS 真机验收 | iOS Runner 不在当前阶段配置 | 仅做依赖 Spike（T026）+ 文档预留（SDD §3.5） |
| 多设备 / 多 Android 版本 / 多厂商 ROM 适配 | MVP 仅以单台真机为基线 | T036 单台验收；多设备矩阵由 GPT 首席架构师决定是否扩展 |
| 永久拒绝弹窗 | 模拟器 / 自动化测试难以构造永久拒绝场景 | 通过 `permission_handler` mock + 真机用户协作 |
| 后台 / 前台切换 | 自动化测试难以模拟 App 生命周期 | `WidgetsBinding.lifecycleState` mock + 真机验证 |
| 系统设置跳转 | 自动化测试难以模拟从系统设置返回 | 真机 MA-04 + 可选 deep link 验证 |
| 来电中断 | 自动化测试难以模拟来电 | 真机 MA-08 |
| 蓝牙耳机切换 | 自动化测试难以模拟蓝牙路由变更 | 真机（可选） |

## 6. Testing Toolchain

### 6.1 既有工具

| 工具 | 用途 | 备注 |
| --- | --- | --- |
| `flutter_test` | 单元 + Widget 测试 | 既有基线 407 项 |
| `flutter analyze` | 静态分析 | 既有基线 No issues found |
| `flutter test --coverage` | 覆盖率（可选） | 不强制 |

### 6.2 待 T026 Spike 验证

| 工具 / 库 | 用途 | Spike 验证项 |
| --- | --- | --- |
| `record` | 录音 | mock 策略；测试中如何替换真实 recorder |
| `just_audio` | 播放 | mock 策略；测试中如何替换真实 player |
| `permission_handler` | 权限 | mock 策略；如何模拟 denied / permanentlyDenied |
| `path_provider` | 路径 | mock 策略；测试中如何替换为临时目录 |

### 6.3 不引入的测试工具

| 禁止项 | 原因 |
| --- | --- |
| 任何 E2E 自动化框架（Appium / Patrol 等） | MVP 阶段引入成本高；真机手动验收更可靠 |
| 任何云测试平台（Firebase Test Lab / BrowserStack 等） | 无 INTERNET 原则 |
| 任何 AI 评测 / 代码质量平台 | 引入成本高，收益不明确 |

## 7. Test Reporting

### 7.1 每个真实音频阶段任务的报告必须包含

- `flutter test` 实际输出（精确测试数）；
- `flutter analyze` 实际输出；
- 新增 / 更新 / 删除测试数（精确值）；
- 既有测试数（精确值）；
- 任何测试失败 / 跳过 / `expect` 异常的具体原因；
- 与既有 407 项测试的回归对比。

### 7.2 禁止的写法

- "测试通过"（无具体数字）；
- "全部通过"（无 `flutter test` 输出证据）；
- "等价于既有测试"（无 diff 证据）；
- "回归通过"（无 `flutter test` 完整输出）；
- "自动化验证真实录音"（任何自动测试均不能验证真实麦克风输入，必须由真机用户确认）。

## 8. References

- `docs/dev/REAL_AUDIO_MVP_SDD.md`：真实音频 MVP 软件设计文档
- `docs/dev/RELEASE_ENGINEERING_TDD.md`：Release 工程化 TDD（既有基线）
- `docs/dev/MVP_ACCEPTANCE.md`：MVP 验收基线
- `docs/dev/RELEASE_ACCEPTANCE.md`：Release 验收基线
- `docs/dev/AGENT_ROUTING_MATRIX.md` §4.9：测试与回归路由
- `docs/dev/AGENT_REVIEW_TEMPLATE.md`：报告模板
- `agents/07-qa-reviewer.md`
- `agents/04-audio-engineer.md`
- `agents/02-flutter-architect.md`
- `agents/06-local-data-engineer.md`
- `agents/08-compliance-reviewer.md`