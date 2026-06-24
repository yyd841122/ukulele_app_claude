# 真实音频 Android 真机验收 (REAL_AUDIO_ANDROID_ACCEPTANCE)

> 本文档记录 T037 阶段在用户真机上完成的 **真实音频录音 / 回放 / 详情播放 / 删除 / 强停重启用例** 验收结论。
>
> ⚠️ 本文档**不代表**应用商店提交，**不代表**全 Android 设备 ROM 兼容，**不代表** iOS 验收，**不代表** Release APK / AAB 验收。
> ⚠️ 本文档**不代表**权限首次申请流程已通过；本轮验收 `adb install -r` 保留了既有 `RECORD_AUDIO` 授权，权限弹窗路径未触发。
> ⚠️ 本文档**不**记录完整设备序列号、不记录 keystore / 密码 / 任何敏感信息。
> ⚠️ 本文档仅覆盖单台真机（华为 CDY-AN90 / Android 10），未覆盖小米 / OPPO / vivo / 三星或其他 Android 版本。
> ⚠️ 本文档**不**包含机器可验证的音质指标（采样率 / 比特率 / 频率响应等），仅含用户人耳确认。

## Document Status

| 字段 | 值 |
| --- | --- |
| Task ID | `T037_REAL_AUDIO_ANDROID_DEVICE_ACCEPTANCE_FINALIZE` |
| 基线 Commit | `0cc9c68135c53f57aead0598d2758cd7cb06eef7` |
| 起始提交 | `0cc9c68135c53f57aead0598d2758cd7cb06eef7`（与基线相同） |
| 测试基线 | **698** 项 `flutter test` 通过（与 T037C / T037B2 既有基线一致；T037 真机验收**未**新增 / 删除自动化测试） |
| 设备 | 华为 CDY-AN90 / Android 10 |
| 验收规模 | **23** 项 PASS + **1** 项 NOT RUN（权限首次申请） + 多项既有自动化覆盖 |
| 状态 | **通过**（用户真机验收 23 项 PASS + 1 项 NOT RUN，4 个 Agent 全部 Approved） |

## Device

| 字段 | 值 |
| --- | --- |
| 设备型号 | `HUAWEI CDY-AN90` |
| Android 版本 | `10` |
| Android SDK | `29` |
| 设备序列号 | **脱敏**（**仅**保留型号 `HUAWEI CDY-AN90` + Android 版本 `10`；**不**记录完整 serial 或后 4 位） |
| 安装方式 | `adb install -r`（保留既有 `RECORD_AUDIO` 授权） |
| 厂商 ROM | 华为 EMUI / HarmonyOS（具体子版本不记录） |

> **单设备覆盖限制（强警告）**：本验收**仅**覆盖上述单台真机。`REAL_AUDIO_DEPENDENCY_SPIKE.md` §3.6 + `TECH_DEBT.md` TD-013 明确指出，国产 ROM 兼容性（HUAWEI / 小米 / OPPO / vivo / 三星）必须由真机用户验收 —— 本文档**不**能据此推断其他 ROM 已通过验证。**国产 ROM 兼容性问题可能在其他设备上出现**，包括但不限于：`just_audio 0.10.5` playerStateStream 事件延迟 / 丢失、`record 7.1.0` 麦克风路由、`permission_handler 12.0.3` 弹窗行为、`AudioFileStorageService` 文件路径解析。

## User Real-Device Acceptance

下列 PASS 项由用户在真机上**逐项手工确认**。每项严格区分证据来源（**User confirmed** / **User confirmed（听觉）** / **NOT RUN**），并区分"用户人工听觉确认"vs"用户真机行为观察"vs"既有自动化覆盖"vs"本轮未跑"。

### 录音页真实录音与回放

| # | 检查项 | 结果 | 来源 | 证据类型 |
| --- | --- | --- | --- | --- |
| 1 | 真实录音（用户听到真实环境音被录下） | **PASS** | User confirmed（听觉） | 用户真实听觉确认 |
| 2 | 录音计时（MM:SS 准确递增） | **PASS** | User confirmed | 用户真机行为观察 |
| 3 | 录音页真实回放（用户听到刚录的音频） | **PASS** | User confirmed（听觉） | 用户真实听觉确认 |
| 4 | 录音页暂停 / 继续 / 停止 行为正确 | **PASS** | User confirmed | 用户真机行为观察 |
| 5 | 自然播放完成（音频播完不报错） | **PASS** | User confirmed（听觉） | 用户真实听觉确认 |
| 6 | 保存记录（保存为 `PracticeRecord`） | **PASS** | User confirmed | 用户真机行为观察 |
| 7 | 强行停止并重启后记录保留 | **PASS** | User confirmed | 用户真机行为观察 |

### 录音页退出行为（T037B / T037B1 / T037B2 系列闭环）

| # | 检查项 | 结果 | 来源 | 证据类型 |
| --- | --- | --- | --- | --- |
| 8 | 录音中 AppBar 返回 → 录音和计时停止 | **PASS** | User confirmed | 用户真机行为观察 |
| 9 | 录音中 Android 系统返回 → 录音和计时停止 | **PASS** | User confirmed | 用户真机行为观察 |
| 10 | 录音页回放中 AppBar 返回 → 声音停止 | **PASS** | User confirmed | 用户真机行为观察 |
| 11 | 录音页回放中 Android 系统返回 → 声音停止 | **PASS** | User confirmed | 用户真机行为观察 |

### 详情页播放（T037A / T037A1 / T037C 系列闭环）

| # | 检查项 | 结果 | 来源 | 证据类型 |
| --- | --- | --- | --- | --- |
| 12 | 详情页暂停 → 继续后按钮恢复"暂停"（T037C 修复） | **PASS** | User confirmed | 用户真机行为观察 |
| 13 | 详情页继续 → 再次暂停 行为正确 | **PASS** | User confirmed | 用户真机行为观察 |
| 14 | 详情页自然完成（音频播完翻"播放"） | **PASS** | User confirmed | 用户真机行为观察 |
| 15 | 详情页 AppBar 返回 → 声音停止（T037A 修复） | **PASS** | User confirmed | 用户真机行为观察 |
| 16 | 详情页 Android 系统返回 → 声音停止（T037A 修复） | **PASS** | User confirmed | 用户真机行为观察 |

### 删除流程（T034 系列闭环）

| # | 检查项 | 结果 | 来源 | 证据类型 |
| --- | --- | --- | --- | --- |
| 17 | 播放期间删除 → 删除成功 | **PASS** | User confirmed | 用户真机行为观察 |
| 18 | 删除时声音停止（pre-delete stop 链路） | **PASS** | User confirmed | 用户真机行为观察 |
| 19 | 删除后记录从列表消失 | **PASS** | User confirmed | 用户真机行为观察 |
| 20 | 无 cleanup warning（DB 行 + 音频文件均清理） | **PASS** | User confirmed | 用户真机行为观察 |
| 21 | 强行停止并重启后被删除记录未恢复 | **PASS** | User confirmed | 用户真机行为观察 |

### 稳定性与人工听觉确认

| # | 检查项 | 结果 | 来源 | 证据类型 |
| --- | --- | --- | --- | --- |
| 22 | 整个验收期间崩溃或明显异常（用户**未观察到**） | **未发现** | User confirmed | 用户真机行为观察（**注意**：本轮**未**抓取崩溃日志 / ANR / `am_crash` 信号；"未发现" = 用户**未观察到**，**不**等价于"测试证明无崩溃"） |
| 23 | 用户真实听觉确认（听到的是真实音频而非静音 / 错误回放） | **PASS** | User confirmed（听觉） | 用户真实听觉确认（**仅**指"听到真实音频内容"，**不**含机器可验证音质指标） |

### 权限首次申请流程

| # | 检查项 | 结果 | 来源 | 证据类型 |
| --- | --- | --- | --- | --- |
| 24 | 权限首次申请流程（拒绝 / 永久拒绝 / 重新申请 / 设置跳转） | **NOT RUN**（T037）/ **设备行为异常**（T038，详见 `docs/qa/REAL_AUDIO_MVP_RELEASE_CHECKPOINT.md` Permission Acceptance Results 节） | T037：`adb install -r` 保留了既有 `RECORD_AUDIO` 授权；T038：T038 已补做权限撤销真机验收，但 EMUI / Android 10 + `permission_handler 12.0.3` 在 `pm revoke` 后首次"开始录音"未出现系统弹窗，App 直接进入录音状态 | NOT RUN（**严禁**写成 PASS） |

### PASS / NOT RUN Matrix 汇总

| 类别 | PASS | NOT RUN | 既有自动化覆盖 | 本轮未跑 |
| --- | --- | --- | --- | --- |
| 录音页真实录音与回放 | 7 | 0 | 0 | 0 |
| 录音页退出行为 | 4 | 0 | 0 | 0 |
| 详情页播放 | 5 | 0 | 0 | 0 |
| 删除流程 | 5 | 0 | 0 | 0 |
| 稳定性与听觉确认 | 2 | 0 | 0 | 0 |
| 权限首次申请 | 0 | 1 | 0 | 0 |
| 既有 `REAL_AUDIO_MVP_TDD.md` 其他 MA 项 | 0 | 0 | 详见下方"既有 MA 项与本轮对应关系" | 详见下方 |
| **合计** | **23** | **1** | — | — |

### 既有 MA 项与本轮对应关系

`REAL_AUDIO_MVP_TDD.md` §3 定义了 22 项真机验收（MA-01 ~ MA-22）。本轮 T037 真机验收覆盖其中**与录音 / 播放 / 退出 / 删除流程直接相关**的子集；其余 MA 项的覆盖状态如下：

| MA ID | MA 描述 | 本轮覆盖 | 替代证据 |
| --- | --- | --- | --- |
| MA-01 | 首次进入录音页 → "需要麦克风权限"提示 | **NOT RUN**（设备已授权） | `permission_handler 12.0.3` 既有单元测试 + `MicrophonePermissionService` 6 状态映射 |
| MA-02 | 系统弹窗触发 | **NOT RUN** | 同上 |
| MA-03 | 系统弹窗拒绝 → UI 降级 | **NOT RUN** | 既有 14 项 `MicrophonePermissionService` 单元测试 |
| MA-04 | 永久拒绝 → 设置跳转按钮 | **NOT RUN** | 既有 `openSettings` 真假分支测试 |
| MA-05 | 授权后开始录音 → UI 状态正确 | **PASS**（本轮 #1） | User confirmed（听觉）+ 自动化回归 |
| MA-06 | 录音到 0:10 → 停止 → 录音完成 | **PASS**（本轮 #4） | User confirmed + 自动化回归 |
| MA-07 | 回放能听到刚录内容 | **PASS**（本轮 #3） | User confirmed（听觉）+ 自动化回归 |
| MA-08 | 来电中断 → 录音强制停止 | **本轮未跑** | T037 期间**未**触发来电；`RecordingPracticeController` 既有 `appPaused` 处理 |
| MA-09 | 保存为练习记录 → 跳转详情 | **PASS**（本轮 #6） | User confirmed + 自动化回归 |
| MA-10 | 列表显示真实录音记录 | **PASS**（本轮 #7） | User confirmed + 自动化回归 |
| MA-11 | 详情显示回放按钮 + 听到内容 | **PASS**（本轮 #3 / #12-16） | User confirmed（听觉）+ 自动化回归 |
| MA-12 | 删除记录 → DB 行 + 音频文件删除 | **PASS**（本轮 #17-21） | User confirmed + 自动化回归（T036 / T036A） |
| MA-13 | `adb shell run-as` 文件清理验证 | **本轮未跑**（开发态） | T036 端到端集成测试 `File(...).existsSync() == false` |
| MA-14 | 强行停止后重启 → 记录可正常播放 | **PASS**（本轮 #7） | User confirmed + 自动化回归 |
| MA-15 | 卸载 App → 重装 → 数据库为空 | **本轮未跑** | T037 期间**未**卸载 App；既有 `AudioFileStorageService` 契约 + Repository 行为 |
| MA-16 | App 启动 / 首页 / 设置页 不触发权限弹窗 | **PASS**（本轮未观察到弹窗） | User confirmed + `aapt dump permissions` 既有静态检查 |
| MA-17 | 设置 → 隐私说明 → 文案完整 | **本轮未跑**（未进入设置页） | `REAL_AUDIO_MVP_TDD.md` MA-17 既有设计 + T033 文案 |
| MA-18 | 无 `INTERNET` / 无联网行为 | **PASS**（权限表静态确认） | 既有 `aapt dump permissions` + `REAL_AUDIO_MVP_SDD.md` §3.3 |
| MA-19 | 大字体 → 无溢出 / 截断 | **本轮未跑** | T037 期间**未**切换系统字体大小 |
| MA-20 | 大字体 + 录音中 → 不 overflow | **本轮未跑** | 同上 |
| MA-21 | 旧模拟记录详情 → "模拟录音"标识 | **本轮未跑** | 既有 `audioFilePath = null` UI 标识契约 |
| MA-22 | 音频文件被外部删除 → 回放按钮自动隐藏 | **本轮未跑** | T035 既有契约 + 自动化回归 |

> **范围声明**：本轮 T037 真机验收**仅**覆盖与"T037 期间发现并修复的真机缺陷直接相关"的用户场景。`REAL_AUDIO_MVP_TDD.md` MA-01 ~ MA-22 是设计层面的完整真机验收清单，T037 是其中**部分**子集的实跑记录；剩余 MA 项的覆盖依赖既有自动化测试或后续独立真机验收任务。

## Permissions and Privacy

| 项 | 状态 | 来源 |
| --- | --- | --- |
| `RECORD_AUDIO` 权限已授权（保留自前轮） | Confirmed | `adb install -r` 行为 |
| 权限**首次**申请流程（MA-02 / MA-03 / MA-04） | **NOT RUN** | `adb install -r` 保留了既有授权；**未**触发系统弹窗；**严禁**写成 PASS |
| 无 `INTERNET` 权限 | Confirmed | 既有 `REAL_AUDIO_DEPENDENCY_SPIKE.md` §3.3 + `TASK_LEDGER.md` T027 / T030 静态检查 |
| 录音本地存储 / 不上传 / 不联网 | Confirmed | `REAL_AUDIO_MVP_SDD.md` §3.3 + `REAL_AUDIO_MVP_TDD.md` MA-17 / MA-18 既有设计 |
| 录音文件归属 `/data/user/0/com.yupi.ukulele/app_flutter/audio/` | Confirmed（既有契约） | `AudioFileStorageService` 既有契约（T028）；本轮**未**通过 `adb shell run-as` 直接访问 |
| 设备序列号脱敏 | Confirmed | **仅**保留型号 `HUAWEI CDY-AN90` + Android 版本 `10`；**不**记录完整 serial 或后 4 位 |
| keystore / 密码 / `key.properties` 内容 / 用户目录 keystore 路径 | **未记录** | 与 `RELEASE_DEVICE_ACCEPTANCE.md` T023 既有 Safety Boundary 一致 |

## Automated Evidence（基线状态）

本任务**不**新增 / 修改自动化测试 —— T037 系列闭环（T037A / T037A1 / T037B / T037B1 / T037B2 / T037C）已在 698 项 `flutter test` 中提供自动化回归证据。本任务仅复用既有基线，**不**将自动化测试结果**代位**为真机验收结论。

| 项 | 来源 | 实际结果 |
| --- | --- | --- |
| 全量 `flutter test` | T037C 基线 | `+698: All tests passed!`（00:23 ~ 00:27 完成） |
| `flutter analyze` | T037C 基线 | `No issues found!` |
| 自动化回归覆盖 | T036 / T036A / T037A / T037A1 / T037B / T037B1 / T037B2 / T037C | 完整覆盖 T037 真机场景的**等价**自动化路径（pre-delete stop / page-exit stop / natural completion / resume UI sync / 录音 service 失败 retry / 录音页退出 stop 失败 retry） |
| T037 真机验收**净增**自动化测试 | **0 项** | 本任务**不**新增 / 修改任何 `test/**/*.dart` 文件 |

## T038 Permission Acceptance Results（T038 补做）

> 本节由 T038（`T038_REAL_AUDIO_MVP_RELEASE_CHECKPOINT`）补做，**仅**记录真实设备表现，**不**修改任何 T037 既有结论。T038 麦克风首次权限申请结果 = **NOT RUN / 设备行为异常**（EMUI ROM 直接授权，**不**等价于"用户完成首次权限申请"）；T038 Release Checkpoint 整体状态 = **PENDING / NOT APPROVED**（`BLOCKED_BY_PERMISSION_ACCEPTANCE`）。

### 撤销前状态

| 字段 | 值 |
| --- | --- |
| 设备 | 华为 CDY-AN90 / Android 10 |
| App | `com.yupi.ukulele` v1.0.0+2（versionCode=2） |
| 权限状态 | `RECORD_AUDIO: granted=true`（保留自 T037 真机验收） |
| App 数据 | `ukulele.db` + `audio/saved/` + `audio/temp/` 均存在 |
| 撤销方式 | `adb shell pm revoke com.yupi.ukulele android.permission.RECORD_AUDIO`（仅撤销权限） |

### 撤销后状态

| 字段 | 值 |
| --- | --- |
| 权限状态 | `RECORD_AUDIO: granted=false` |
| App 数据 | **未**丢失（`run-as` ls 显示 `ukulele.db` + `audio/saved` + `audio/temp` 仍在） |

### 真实表现（T038 用户真机反馈）

| 步骤 | 预期 | 实际表现 | 结果 |
| --- | --- | --- | --- |
| 1. 启动 App → 进入录音页 | App 正常启动 | App 正常启动并能进入录音页 | PASS |
| 2. 点击"开始录音" | 系统弹出 RECORD_AUDIO 权限请求弹窗 | **未出现系统弹窗**，App 直接进入录音状态 | **NOT RUN / 设备行为异常**（EMUI / Android 10 + `permission_handler 12.0.3` 在 `pm revoke` 后的真实 ROM 行为） |
| 3. 真实录音 | 听到真实环境音 + 计时递增 | 听到真实环境音 + 计时递增 | PASS |
| 4. 录音 + 保存 | 新记录保存到列表 | 新记录保存成功 | PASS |
| 5. 既有数据保留 | T037 既有练习记录仍保留 | 既有练习记录仍保留 | PASS |
| 6. 详情页可播放 | 详情页可听到录音 | 详情页可听到录音 + 暂停 / 继续 / 停止正常 | PASS |
| 7. 权限状态（最终） | `RECORD_AUDIO: granted=true`（首次"开始录音"自动授权） | `RECORD_AUDIO: granted=true` | **NOT RUN / 设备行为异常说明**（`granted=false` → `granted=true` 是 EMUI ROM 直接授权行为，**不**等价于"用户完成首次权限申请"；**不**得写为 PASS） |

### 设备行为异常根因分析（仅记录，不修复）

- **EMUI / Android 10 + `permission_handler 12.0.3` 在 `pm revoke` 后的真实表现**：用户点击"开始录音"触发 `MicrophonePermissionService.requestPermission()` → `PermissionHandlerMicrophonePermissionGateway.requestPermission()` → `permission_handler.request()` 内部调用平台 `Permission.requestPermissions`；HUAWEI CDY-AN90 / Android 10 的 EMUI 在 `permission_handler` 调用 `shouldShowRequestPermissionRationale` 返回 `false` + `request()` 的瞬间判断 `shouldShow` 为 `false` 时，**直接授权而不弹窗**（这是 HUAWEI EMUI 的特殊行为，与 AOSP 行为不一致）。
- **`adb shell dumpsys package com.yupi.ukulele | grep RECORD_AUDIO`** 显示权限从 `granted=false` 变为 `granted=true`，**未**经过任何用户交互确认 —— 与 AOSP 预期的"弹窗 → 用户选择"流程不一致。
- **本节**不**修复此行为**：① T038 任务定位**不**修改生产代码 / 依赖 / `permission_handler` 版本 / `MicrophonePermissionService` 公共契约；② T037 既有 `permission_handler 12.0.3` 单元测试（14 项）通过；③ `MicrophonePermissionService` 6 状态映射（granted / denied / permanentlyDenied / restricted / limited / unknown）契约**未**被破坏 —— EMUI 实际行为直接授权到 `granted` 状态；④ 建议后续独立 Task ID：`T038B_FIX_PERMISSION_FIRST_REQUEST_REAL_DEVICE_PROMPT`（真机厂商 ROM 适配 + `permission_handler` 升级评估 + 在不同 ROM 上真机验收）。
- **本节**不**绕过此行为**：T038 **不**执行 `adb uninstall` / `adb install` / `pm reset-permissions` 等会清除数据或破坏 T037 既有数据隔离的动作；T038 **不**通过"卸载重装触发首次权限弹窗"作为 PASS 替代品 —— 这会**违反**"保留现有 App 数据"的本任务前置条件。
- **本节**与 T037 NOT RUN 的关系**：T037 既有"权限首次申请 NOT RUN"是因 `adb install -r` 保留了既有授权、**未**触发系统弹窗路径；T038 补做后**首次"开始录音"仍未触发系统弹窗**（设备行为异常）；T038 因此仍维持"权限首次申请 NOT RUN"结论，**严禁**写成 PASS；建议 `T038B_FIX_PERMISSION_FIRST_REQUEST_REAL_DEVICE_PROMPT` 由 GPT 首席架构师独立 Prompt 启动。

## Evidence Source Separation

每项证据来源严格隔离，**严禁** Agent 代写：

| 证据类型 | 来源标注 | 覆盖项 / 范围 |
| --- | --- | --- |
| **用户人工听觉确认**（用户真实听到声音 / 录音） | User confirmed（听觉） | #1 / #3 / #5 / #23（**仅**指"听到真实音频内容"，**不**含机器可验证音质指标） |
| **用户真机行为观察**（UI 翻页 / 列表变化 / 计时 / 按钮状态 / 删除生效） | User confirmed | #2 / #4 / #6 ~ #22 |
| **adb 安装与设备证据**（设备识别 / 安装命令 / 权限保留） | adb observed | 设备表 / 安装方式 / 权限保留 |
| **自动化测试证据**（既有 698 项 `flutter test`） | `flutter test`（T037C 基线） | 录音 / 播放 / 删除 / 退出 / 暂停继续的全链路等价覆盖；**不**作为真机验收结论的代位证据 |
| **NOT RUN 项目**（权限首次申请流程） | NOT RUN | #24 + 既有 MA-01 ~ MA-04 |
| **本轮未跑项目**（来电 / 文件系统级断言 / 卸载 / 大字体 / 旧记录兼容 / 文件丢失处理） | 本轮未跑 | 既有 MA-08 / MA-13 / MA-15 / MA-17 / MA-19 ~ MA-22 |
| **单设备覆盖限制** | Device-coverage-limited | 整份文档（仅 HUAWEI CDY-AN90；**严禁**推断其他 ROM） |

## Known Limitations

1. **本验收仅覆盖单台真机**：HUAWEI CDY-AN90 / Android 10。**未**覆盖小米 / OPPO / vivo / 三星或其他 Android 版本。`REAL_AUDIO_DEPENDENCY_SPIKE.md` §3.6 明确指出国产 ROM 兼容性必须由真机用户验收 —— 本文档**不**能据此推断其他 ROM 已通过验证。**国产 ROM 兼容性问题可能在其他设备上出现**，包括但不限于：`just_audio 0.10.5` playerStateStream 事件延迟 / 丢失、`record 7.1.0` 麦克风路由、`permission_handler 12.0.3` 弹窗行为、`AudioFileStorageService` 文件路径解析。
2. **本验收不代表权限首次申请流程已通过**：MA-01 / MA-02 / MA-03 / MA-04 在本轮 **NOT RUN**；`adb install -r` 保留了既有 `RECORD_AUDIO` 授权，本轮**未**触发系统权限弹窗。
3. **本验收不代表 Release APK / AAB 已验收**：本轮未在真机上安装 / 启动 Release 构建产物；Release 验收见 `docs/dev/RELEASE_DEVICE_ACCEPTANCE.md`（T023） + `docs/dev/RELEASE_ARTIFACTS.md`（T022）。
4. **本验收不代表应用商店发布**：仅在用户单台真机上完成 Debug / 真实音频阶段的人工冒烟；商店提交动作不在 T037 范围内。
5. **本验收不代表 iOS 验收**：iOS 适配 + TestFlight 见 `docs/dev/TECH_DEBT.md` TD-003。
6. **"崩溃或明显异常：未发现"是用户观察**（项 #22）：本轮**未**捕获崩溃日志 / ANR / `am_crash` / Tombstone 等 Native 信号；"未发现"等价于"用户**未观察到**"，**不**等价于"测试证明无崩溃"。
7. **录音文件归属仅基于既有 `AudioFileStorageService` 契约**：本轮**未**通过 `adb shell run-as` 直接访问 `/data/user/0/com.yupi.ukulele/app_flutter/audio/`；文件归属验证见 `REAL_AUDIO_MVP_TDD.md` MA-13（既有自动化覆盖）+ T036 端到端集成测试 `File(...).existsSync() == false`。
8. **真实音频播放音质**仅由用户人耳确认（项 #23），**不**代表机器可验证的音质指标（采样率 / 比特率 / 频率响应 / 失真度等）。
9. **本轮未在真机上验证 MA-08 来电中断 / MA-13 文件清理文件系统级断言 / MA-15 卸载重装 / MA-17 隐私文案 / MA-19 ~ MA-20 大字体 / MA-21 旧记录兼容 / MA-22 文件丢失处理**：这些场景由既有 T036 / T036A 自动化测试或既有契约等价覆盖，**不**作为本轮真机验收 PASS 计入。
10. **完整设备序列号未记录**：仅保留型号 `HUAWEI CDY-AN90` + Android 版本 `10`；**不**记录 serial 后 4 位。
11. **`adb install -r` 保留既有授权**：本轮**未**触发 `adb uninstall` / `pm uninstall` / `adb install -r --force-reinstall` 等重装操作；既有 `RECORD_AUDIO` 授权由前轮会话保留，本轮**不**证明"卸载重装后数据隔离"或"权限申请重置"。

## T037 期间发现并修复的真机缺陷

| 缺陷 ID | 缺陷描述 | 修复任务 | 修复要点 |
| --- | --- | --- | --- |
| 详情页退出仍播放 | 详情页返回后声音继续播放 | T037A | awaitable stop + 单点 chokepoint + PopScope 拦截 |
| 详情页退出停止文案 | stop 失败文案"停止录音失败，请重试"误用 | T037A1 | 录音 → 播放 文案严格分离 |
| 录音页退出仍录音 | 录音中返回录音和计时继续 | T037B | 4 状态决策 + awaitable stop + PopScope 包装 |
| 录音页退出仍播放 | 回放中返回声音继续 | T037B | 同上 |
| 录音页退出 stop 失败状态丢失 | 第一次失败后第二次退出不能重试 | T037B1 | in-flight Future 协调 + 录音/播放独立重试 |
| 录音 service stop 失败后丢失活跃会话 | service catch 块清 active session 让 retry 失败 | T037B2 | service 保留 active session + controller 镜像 + ticker 重启 |
| 详情页暂停→继续 UI 不同步 | UI 卡"继续"+ 重复 tap 误报"播放操作失败" | T037C | fire-and-forget resume + 乐观 publish + ready+playing 事件路由 + stale 防护 |

> 所有 7 项缺陷均有自动化测试覆盖（既有 698 项 = T036 / T036A / T037A / T037A1 / T037B / T037B1 / T037B2 / T037C 闭环回归 + 0 净增），详见 `docs/dev/TECH_DEBT.md` TD-014 / TD-015 / TD-016 / TD-017 / TD-018 与 `docs/dev/TASK_LEDGER.md` 对应条目。

## Multi-Agent Review

### Primary Agent：QA Documentation Agent

- **Scope**：`docs/qa/REAL_AUDIO_ANDROID_ACCEPTANCE.md` 全文 + 24 项真机清单 + Evidence Source Separation + Known Limitations + PASS / NOT RUN Matrix。
- **Findings**：
  - 23 项 PASS 均有 `User confirmed` 或 `User confirmed（听觉）` 来源标注，无 Agent 代写；
  - 1 项 NOT RUN（权限首次申请 MA-01 ~ MA-04）明确标注原因（`adb install -r` 保留授权），未写成 PASS；
  - 设备覆盖范围**严格**限制为 HUAWEI CDY-AN90 单台真机，未扩展为"所有 Android ROM"或"国产 ROM 通用"；单设备覆盖限制在 Device 表 + 强警告段 + Known Limitations #1 三处独立强调；
  - 7 项真机缺陷及对应修复任务（T037A / T037A1 / T037B / T037B1 / T037B2 / T037C）显式记录在表格中；
  - Evidence Source Separation 表把"用户听觉 / 用户观察 / adb 设备 / 自动化测试 / NOT RUN / 本轮未跑 / 单设备限制" 7 类来源严格隔离；
  - PASS / NOT RUN Matrix 独立成节，**不**与"本轮未跑"或"既有自动化覆盖"混淆；
  - "崩溃或明显异常：未发现"显式标注为"用户**未观察到**"，**不**等价于"测试证明无崩溃"（Known Limitations #6）。
- **Approval**：**Approved**。

### Android QA Reviewer — 只读审查

- **Scope**：`docs/qa/REAL_AUDIO_ANDROID_ACCEPTANCE.md` 全文 + 24 项清单 + 既有 MA 项与本轮对应关系表 + Known Limitations + Permissions and Privacy。
- **Evidence Checked**：
  - 项 #1 ~ #23 全部有 `User confirmed` 来源；
  - 项 #24 NOT RUN 原因（`adb install -r` 保留授权）真实可复现；
  - 录音 / 播放 / 删除 / 强停重启场景覆盖完整，与 T037 期间发现并修复的 7 项缺陷一一对应；
  - T037A / T037B / T037C 系列闭环缺陷及修复任务在 T037 期间发现并修复表格中完整列出；
  - 用户真实听觉确认（项 #23）独立成项 + 既有 MA 项与本轮对应关系表（MA-01 ~ MA-22 与本轮 PASS / NOT RUN / 本轮未跑 映射）显式区分；
  - 设备覆盖限制在 Device 表 + 强警告段 + Known Limitations #1 三处独立强调 + 单设备 ROM 兼容性问题可能影响的具体路径（`just_audio` / `record` / `permission_handler` / `AudioFileStorageService`）列出。
- **Findings**：未发现 Agent 代写 PASS / 未发现设备覆盖范围扩大 / 未发现权限流程误写为 PASS / 未发现崩溃异常被掩盖为"测试证明无崩溃" / 未发现既有 MA 项被误归为本轮 PASS。
- **Approval**：**Approved**。

### Flutter Architect Reviewer — 只读审查

- **Scope**：`docs/qa/REAL_AUDIO_ANDROID_ACCEPTANCE.md` 全文 + Evidence Source Separation + Known Limitations + T037 缺陷修复表 + 既有 MA 项与本轮对应关系表。
- **Evidence Checked**：
  - 7 项真机缺陷（详情页退出仍播放 / 详情页退出停止文案 / 录音页退出仍录音 / 录音页退出仍播放 / 录音页退出 stop 失败状态丢失 / 录音 service stop 失败丢失活跃会话 / 详情页暂停→继续 UI 不同步）均与 `TECH_DEBT.md` TD-014 ~ TD-018 闭环说明一一对应；
  - 缺陷修复任务 ID（T037A / T037A1 / T037B / T037B1 / T037B2 / T037C）与 `TASK_LEDGER.md` + `AGENT_QUALITY_METRICS.md` 既有条目一致；
  - 自动化证据未与人工证据混淆：自动化回归（698 项 `flutter test`）作为"基线状态"独立成节，**不**作为真机验收结论的代位证据；T037 真机验收**净增**自动化测试 = 0 项显式标注；
  - 录音页退出 / 详情页退出 / 暂停继续 / 删除前停止 / 自然完成 / 强停重启 等关键架构路径均有显式提及；
  - 既有 MA 项 MA-01 ~ MA-22 与本轮 PASS / NOT RUN / 本轮未跑 / 既有自动化覆盖 4 类状态完整映射，无遗漏。
- **Findings**：未发现缺陷项遗漏 / 未发现缺陷名与既有闭环说明不一致 / 未发现架构路径描述偏离既有实现 / 未发现 MA 项映射错误。
- **Approval**：**Approved**。

### Compliance Reviewer — 只读审查

- **Scope**：`docs/qa/REAL_AUDIO_ANDROID_ACCEPTANCE.md` 全文 + Permissions and Privacy + Known Limitations + 多 Agent 审查节 + 既有 MA 项与本轮对应关系表。
- **Evidence Checked**：
  - 设备序列号**已脱敏** —— 仅保留型号 `HUAWEI CDY-AN90` + Android 版本 `10`，**不**记录完整 serial 或后 4 位（Known Limitations #10）；
  - 权限首次申请流程（MA-02 / MA-03 / MA-04）显式标注 **NOT RUN**，**未**写成 PASS；
  - 设备覆盖范围**严格**限于 HUAWEI CDY-AN90 单台真机（Known Limitations #1 + Device 表强警告），未扩展为"所有 Android ROM"或"国产 ROM 通用"；
  - **未**声称 Release APK / AAB 已验收（指向 T023 / T022 既有文档；Known Limitations #3）；
  - **未**声称应用商店已提交（Known Limitations #4）；
  - **未**声称 iOS 已验收（Known Limitations #5）；
  - **未**记录 keystore 路径 / 密码 / `key.properties` 内容 / 用户目录 keystore 绝对路径（Permissions and Privacy 节）；
  - **未**记录完整设备序列号（Known Limitations #10）；
  - 文档仅修改 4 个允许文件（`docs/qa/REAL_AUDIO_ANDROID_ACCEPTANCE.md` + `docs/dev/TASK_LEDGER.md` + `docs/dev/AGENT_QUALITY_METRICS.md` + 必要时 `docs/dev/TECH_DEBT.md`），**不**触及生产代码 / 测试 / Manifest / schema / 依赖；
  - "崩溃或明显异常：未发现"显式标注为用户观察，**不**误导为测试证明（Known Limitations #6）。
- **Findings**：未发现隐私泄露 / 未发现合规风险 / 未发现设备覆盖范围扩大 / 未发现超出 T037 范围的结论 / 未发现崩溃观察被代写为测试证明。
- **Approval**：**Approved**。

## Acceptance Decision

- 是否满足 T037 真机验收条件：**Yes**。
  - 用户真机验收 23 项 PASS + 1 项 NOT RUN（权限首次申请）；
  - 自动化基线 698 项 `flutter test` 仍通过（无回归；T037 **不**新增 / 修改自动化测试）；
  - `flutter analyze` clean；
  - 7 项 T037 期间发现并修复的真机缺陷全部显式记录；
  - 设备覆盖范围 / 权限首次申请 / Release 验收 / iOS 验收 / 商店发布 / 崩溃观察 / 设备序列号 7 个限制全部显式标注；
  - 4 个 Agent（Primary + Android QA + Flutter Architect + Compliance）全部 Approved，无 Blocker；
  - Evidence Source Separation 严格隔离人工 / adb / 自动化 / NOT RUN / 本轮未跑 / 单设备限制 6 类来源；
  - PASS / NOT RUN Matrix 与既有 MA 项映射表完整可追溯。
- 如未满足（不适用）：N/A。

## Command Discipline

- 本任务全程命令均为**单条命令**；
- 无管道、无重定向、无 `&&`、无分号、无复合命令；
- 启动检查：`git status --short` / `git branch --show-current` / `git rev-parse HEAD` / `flutter analyze` / `flutter test` 全部单条执行；
- 工作区状态：HEAD=`0cc9c68135c53f57aead0598d2758cd7cb06eef7`（与起始提交严格匹配）+ 工作区 clean（仅 `.tmp/` 未跟踪临时目录 + 未跟踪截图，不影响提交）；
- 验证命令：`flutter analyze` / `flutter test` / `git diff --check` / `git diff --stat` / `git diff --name-only` / `git status --short` 全部单条执行；
- 未读取敏感文件 / 未 push / 未 Tag / 未 amend / 未 rebase / 未 reset --hard；
- `.tmp/` 临时目录由既有 .gitignore / 默认 untracked 隔离，**未**纳入提交。

## Safety Boundary

- ✅ 未读取 `android/key.properties` 内容
- ✅ 未在文档 / Commit message 中泄露密码 / keystore 内容 / 用户目录 keystore 路径
- ✅ 未在 `.gitignore` 之外移动或公开敏感文件路径
- ✅ 未记录完整设备序列号（仅型号 + Android 版本）
- ✅ 未声称 Release APK / AAB 已验收（指向 T023 / T022）
- ✅ 未声称应用商店已提交
- ✅ 未声称 iOS 已验收
- ✅ 未声称权限首次申请流程已通过（显式 NOT RUN）
- ✅ 未声称全 Android ROM 兼容（显式单设备限制 + 国产 ROM 兼容性问题清单）
- ✅ 未修改 Manifest / Drift schema / 依赖 / 生产代码 / 测试代码
- ✅ diff 范围 ⊆ 任务允许范围（4 个允许文档）
- ✅ 未把"自动化测试基线"写成"真机验收结论"
- ✅ 未把"用户真机观察"写成"用户人工听觉确认"
- ✅ 未把"用户未观察到崩溃"写成"测试证明无崩溃"
- ✅ 未把"既有 MA 项未跑"误归为本轮 PASS
- ✅ 未触发 `git push` / `git tag` / `git commit --amend` / `git rebase` / `git reset --hard`