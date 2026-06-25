# OP-1 Audio Capture Architecture Decision Record (ADR)

> Task ID: `T050_OP1_AUDIO_CAPTURE_SPIKE`
> 上游: `docs/PRD_v2.md` v0.3 / `docs/architecture/SDD_V2.md` v0.4 / `docs/architecture/TDD_PRODUCT_V2_PHASE1.md` v1.0 / `docs/architecture/IMPLEMENTATION_PLAN_PRODUCT_V2_PHASE1.md` v1.2
> 起始 HEAD: `7b84efd` (`docs: complete product v2 implementation plan review evidence`)
> 当前分支: `product-v2`
> 测试基线: 744（`744 tests baseline retained, not rerun`）
> 状态: **ADR 决策 = `Blocked`**
> 是否引入依赖: **否**
> 是否修改生产代码 (`lib/**`): **否**
> 是否修改 Manifest / pubspec / Drift: **否**
> 是否新增 INTERNET 权限: **否**

---

## 1. 背景

Product V2 Phase 1 PRD §11 OP-1 提出"音频分析输入来源"作为开放问题。SDD v0.4 §7.2 列出 5 个候选方案：

| 候选 | 简述 |
|------|------|
| **A. 双 record 实例 + PCM 流 + m4a 并行** | 第二个 `AudioRecorder` 用 `startStream(PCM16bits)` 跑分析流；原实例继续 m4a 写入 |
| B. `flutter_sound` 第二条采集路径 | 引入新顶层依赖（与 T026 锁定 `record` 唯一决策冲突） |
| C. 事后解码 m4a → 后台 isolate 检测 | 录完再跑；UI 仅会话结束反馈（非实时） |
| D. Android `AudioRecord` JNI / FFI 直采 | 自己写 FFI 调 Android `AudioRecord` |
| E. 放弃实时分析 | 仅会话结束反馈（与 PRD §5.1 步骤 7 实时反馈冲突，**反推荐**） |

SDD v0.4 §7.2 把 **A 方案**列为"首选 Spike 验证候选（**非**已证明架构）"，并显式声明：

> 双 `AudioRecord` 共用同一物理麦克风时，Android 10+ AAudio/MMMap 路径可能返回 `ERROR_INVALID_OPERATION` 或第二实例降采样；`record_android` 双实例共用同一 `MethodChannel` 的 `onStop` / `onCancel` 回调可能错配。**这些风险**目前**无官方 API 文档证伪**——T048A 必须真机验证。

TDD v1.0 §5.1 "Spike 协议"列出 7 项必含清单 + 设备兼容矩阵 ≥2 设备 × 3 时长 = 6 实验。**所有真机物理实验是 A 方案能否成为 P1 正式方案的决策门。**

本任务 `T050_OP1_AUDIO_CAPTURE_SPIKE` 的目标是：**真机执行 A 方案实验 + 产出 ADR 决策**。

## 2. PRD / SDD / TDD 引用

| 文档 | 节 | 引用要点 |
|------|----|---------|
| PRD v2 | §5.5 + §11 OP-1 | "v1.1.0 真实音频录音（`record ^7.1.0`，m4a / 44.1 kHz / mono，5 分钟上限，**仅写文件**）不暴露 PCM 流或实时分析回调。" SDD **必须**比较（至少）：扩展 `record` 插件同时支持流式分析 + 文件录制 / 第二条采集路径 / 事后解码 / FFI / 放弃实时 5 种方案 |
| SDD v2 | §7.1 + §7.2 + §7.4 | OP-1 = A 方案 = 首选 Spike 验证候选（非已证明架构）；T048A 真机 Spike 必含 5s/30s/5min + m4a 完整性 + PCM 连续性 + 权限生命周期 + 停止回调归属 + 资源释放 + 设备兼容矩阵 |
| TDD v1.0 | §5.1 + §5.2 + §5.4 | 详细协议：7 项必含清单 + 候选方案判定矩阵 + ADR 必须含 7 项必含清单结果 |
| Implementation Plan v1.2 | §2 T1 | `T049A_OP1_AUDIO_CAPTURE_SPIKE`（原任务命名）→ 本任务统一为 `T050_OP1_AUDIO_CAPTURE_SPIKE`；Reviewer 3 名（Audio Architecture + Flutter Data + Android QA） |

## 3. 候选方案 A / C / D / E

### 3.1 A 方案（首选验证候选）

- **机制**：第二个 `AudioRecorder` 实例用 `startStream(RecordConfig(encoder: AudioEncoder.pcm16bits))` 跑 PCM 流；原实例用 `start(RecordConfig(encoder: AudioEncoder.aacLc))` 写 m4a 文件
- **API 层事实**（Context7 `/llfbandit/record` README + 源码）：
  - 同一 `AudioRecorder` 实例 `start()` 与 `startStream()` **互斥**（同一实例二选一）
  - **不同**实例可以分别 `start()` + `startStream()` —— 但底层 `record_android` 各自创建 `AudioRecord`，共用物理麦克风时是否稳定占用未在官方 README 中明确
  - PCM16bits + AAC-LC 在 Android stream + file 两种路径均支持
- **已知隐藏风险**（SDD v0.4 §7.2）：
  - Android 10+ AAudio/MMMap 路径：双 `AudioRecord` 共用物理麦克风时可能返回 `ERROR_INVALID_OPERATION` 或第二实例降采样
  - `MethodChannel('record_android')` `onStop` / `onCancel` 回调可能错配（同一 channel，多实例归属不清）
- **理论性结论**（**未由真机验证**）：
  - API 层调用路径在 Dart 侧**可达**（spike 工具已静态 analyze 通过；见 §6）
  - Android 平台层行为**未被本任务证实** —— 需要真机 6 次实验

### 3.2 C 方案（事后解码）

- **机制**：录完 m4a 后由后台 isolate 解码 → 跑事后检测；UI 仅会话结束反馈
- **延迟**：秒级（**非**实时）
- **依赖**：需评估 `just_audio ^0.10.5` 是否暴露"纯解码到 PCM"API；`ffmpeg_kit_flutter` 已 deprecate 警告；`MediaExtractor` JNI 需 FFI
- **代价**：破坏 PRD §5.1 步骤 7"实时反馈"承诺（**不**到 150-300 ms 目标）

### 3.3 D 方案（FFI / JNI）

- **机制**：自己写 FFI 调 Android `AudioRecord`
- **代价**：与 v1.1.0 既有 Dart-side 抽象偏离；FFI 编译 + 维护成本高；与 `record` 包内 `AudioRecord` 实例可能冲突
- **可行性**：P3+ 备选

### 3.4 E 方案（放弃实时）

- **反推荐**：与 PRD §5.1 步骤 7 实时反馈冲突
- **不**作 P1 正式方案

## 4. 本次实验范围

| 项 | 内容 |
|----|------|
| Spike 工具 | `tool/spike_op1_audio_capture.dart`（新建；A 方案 spike harness；可被 `flutter run -d <device>` 直接执行） |
| 真机执行 | **本任务执行环境（Windows 11 + Git Bash）无真机；真机物理实验未执行** |
| 时长矩阵 | 5s / 30s / 5min（**全部 NOT RUN**） |
| 设备矩阵 | ≥2 设备（**0 设备执行**） |
| 7 项必含清单 | 见 §7-§12；除 `start/stop 顺序`（API 路径可达）外**全部 NOT RUN** |
| 产物保存 | `e2e/spike_logs/op1_<device>_<timestamp>.log`（**本任务目录已创建但空**；spike 工具未在真机上执行故**无**日志文件；未来真机执行 spike 工具会自动写入） |

## 5. 实验工具说明

### 5.1 `tool/spike_op1_audio_capture.dart`

- 封装两个 `AudioRecorder` 实例：
  - 实例 1：`start(RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 44100, bitRate: 128000, numChannels: 1), path: <temp>.m4a)`
  - 实例 2：`startStream(RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: 44100, numChannels: 1))` → `Stream<Uint8List>`
- 流程：
  1. 申请 `RECORD_AUDIO`（用 `record` 内置 `hasPermission()`，**不**调用既有 `MicrophonePermissionService` 避免与 T027 契约冲突）
  2. 准备 temp m4a 路径（`getTemporaryDirectory()/op1_spike_<ts>/<uuid>.m4a`）
  3. 双实例 start（先 m4a 再 PCM 流）
  4. 订阅 PCM stream → 记录 chunk 数量 + 间隔 + 总字节
  5. 等待 `Duration(5s|30s|5min)`
  6. 双实例 stop（**反序**：先 PCM 流 stop，再 m4a stop）
  7. 校验 m4a 文件存在 + 大小 > 0
  8. dispose 两个实例
  9. 写日志到 `e2e/spike_logs/op1_<device>_<timestamp>.log`
- 边界：
  - **不**修改 `lib/**` 任何文件
  - **不**修改 `pubspec.yaml` / Manifest / Drift schema
  - **不**调用既有 `RealAudioRecorderService` / `MicrophonePermissionService`
  - **不**触发 INTERNET 权限
  - **不**写 `test/**` / `integration_test/**`
- 静态检查：`dart analyze tool/spike_op1_audio_capture.dart` = `No issues found!`；`dart analyze tool/` = `No issues found!`
- **退出码语义澄清**（Reviewer 建议）：`main()` 末尾 `exit(0)` **仅**表示"spike 流程跑完"，**不**等价于"7 项必含清单 PASS"。未来真机执行后，调用方必须读取日志文件 `_formatResult` 输出做 PASS / FAIL 判定；**不**仅看退出码。
- **当前时长档位硬编码**（Reviewer 建议的增强项）：`_runSpike` 调用点（main 函数）当前硬编码 `Duration(seconds: 5)`（5s 档）。未来真机执行 30s / 5min 档位时，需修改 main 函数中 `_runSpike` 调用点的 `Duration` 参数为 `Duration(seconds: 30)` / `Duration(minutes: 5)`（spike 工具**不**解析 CLI args；**不**改源码易错性是已知改进项，**非** Blocker）。

### 5.2 真机执行方式（**当前未执行**）

```bash
flutter run -d <android-device> tool/spike_op1_audio_capture.dart
```

未来用户在真机上执行本工具时，需要：
- 修改 `tool/spike_op1_audio_capture.dart` 中 `_runSpike` 调用点的 `Duration` 参数为 5s / 30s / 5min 三档
- 在至少 2 台 Android 真机（如 HUAWEI CDY-AN90 + 1 台中端 Android 13+）上执行
- 收集每档的 `m4aPath` / `m4aSizeBytes` / `pcmChunkCount` / `pcmIntervalStatsMs` / `errors`

## 6. 真机设备矩阵

| 设备 | 型号 | Android 版本 | 厂商 ROM | 麦克风硬件 | Spike 结果 |
|------|------|-------------|---------|----------|-----------|
| **设备 1** | **NOT RUN** | — | — | — | 无真机物理执行 |
| **设备 2** | **NOT RUN** | — | — | — | 无真机物理执行 |

**ADR 决策必含项**："设备矩阵证据不足"是本任务硬约束。任务要求"目标至少 2 台 Android 真机"——本任务 0 台真机执行。

## 7. 5s / 30s / 5min 结果

| 时长 | 期望行为 | 实测结果 |
|------|---------|---------|
| 5s | 双实例 start → 5s 后 stop 反序 → m4a 文件存在 + PCM chunks 累计 ≥ 100 帧 | **NOT RUN**（无真机） |
| 30s | 双实例 start → 30s 后 stop 反序 → m4a 文件大小 ≈ 480 KB（128 kbps × 30s）；PCM chunks 累计 ≥ 600 帧 | **NOT RUN**（无真机） |
| 5min | 双实例 start → 300s 后 stop 反序 → m4a 文件大小 ≈ 3.66 MB（128 kbps × 300s = 3,840,000 bytes）；PCM chunks 累计 ≥ 6000 帧；5 分钟稳态下相对漂移 ≤ 50 ms（初始验收目标，**非**永久常量） | **NOT RUN**（无真机） |

## 8. m4a 完整性结果

| 检查项 | 状态 |
|--------|------|
| `m4aRecorder.stop()` 返回路径 == 请求路径 | **NOT RUN**（无真机） |
| m4a 文件存在 + 大小 > 0 | **NOT RUN**（无真机） |
| m4a 文件可被 `just_audio ^0.10.5` 正常解码 + 播放（沿用 T030 契约） | **NOT RUN**（无真机） |
| 5min 后无 0 字节文件 / 无无声文件 / 无半截 m4a | **NOT RUN**（无真机） |

## 9. PCM 连续性结果

| 检查项 | 状态 |
|--------|------|
| `pcmRecorder.startStream()` 返回非 null `Stream<Uint8List>` | **NOT RUN**（无真机） |
| PCM chunk 帧序号连续无丢失 / 重复 / 乱序 | **NOT RUN**（无真机） |
| PCM chunk 间隔在稳态下均匀分布（无长时间中断） | **NOT RUN**（无真机） |
| 5min 后 PCM 总字节 ≈ 5min × 44100 samples/s × 2 bytes × 1 channel ≈ 26.46 MB（**理论**） | **NOT RUN**（无真机） |

## 10. 权限与生命周期结果

| 检查项 | 状态 |
|--------|------|
| `RECORD_AUDIO` 首次申请 → granted / denied / permanentDenied 三态表现 | **NOT RUN**（无真机） |
| 双实例共享同一 `RECORD_AUDIO`（任一实例 start 期间另一个实例 cancel / dispose 不导致权限吊销） | **NOT RUN**（无真机） |
| 录音中模拟来电 / 系统 kill app / 蓝牙耳机断开 → 双实例优雅失败 | **NOT RUN**（无真机） |
| 5 分钟档位下 app 被电池优化 / 屏幕关闭导致系统 kill app | **NOT RUN**（无真机；建议未来真机 spike 前置条件：保持屏幕常亮 / 关闭电池优化 / 禁用 Doze —— Reviewer 建议，**非** Blocker） |
| 页面退出 / `Controller.dispose()` → 双实例 stop → 释放 → 后续 page open 不报错 | **NOT RUN**（无真机） |

## 11. stop / callback 归属结果

| 检查项 | 状态 |
|--------|------|
| `MethodChannel('record_android')` 的 `onStop` / `onCancel` 回调能正确归属到调用实例（不串台） | **NOT RUN**（无真机） |
| start 顺序：先 m4a 再 PCM 流；stop 顺序反序（先 PCM 流 stop，再 m4a stop） | **code-level PASS**（spike 工具代码路径可达；**未**在真机 platform channel 验证） |
| `record ^7.1.0` 双实例是否共用同一 `MethodChannel`（归属风险点） | **未证实**（README / 源码未明确；需真机 platform-channel 日志确认；建议未来真机 spike 增补 platform-channel 日志采集以验证 `onStop` 回调归属 —— Reviewer 建议，**非** Blocker） |

## 12. 失败现象与复现步骤

**当前没有失败现象** —— 因为没有真机执行。

| 理论性失败场景 | 复现步骤（**待真机验证**） |
|--------------|------------------------|
| AAudio/MMMap `ERROR_INVALID_OPERATION` | 双实例并发启动；观察第二个 `start` / `startStream` 是否抛 native 异常 |
| 第二实例降采样 | 双实例并发启动；观察 PCM chunk 实际 `sampleRate` 是否仍为 44100 |
| onStop 回调串台 | m4a 录音中 stop PCM 流；观察 `MethodChannel.onStop` 回调归属 |
| 资源未释放 → 麦克风占用 | 双实例 dispose 后立即尝试第三次 start；观察是否抛 "device busy" 或类似错误 |
| 5 分钟稳态下 PCM chunk 间隔漂移 | 5 分钟录音；统计 chunk 间隔方差 / 最大间隔 |

## 13. 风险与限制

### 13.1 本任务硬限制

1. **无真机物理执行**：当前执行环境（Windows 11 + Git Bash）仅 1 台开发者设备（**HUAWEI CDY-AN90 / Android 10** 由用户持有，不在本任务执行者控制）；本任务**未**调用真机
2. **0 设备执行**：未跑任何真机 spike
3. **0 时长档位执行**：5s / 30s / 5min 三档全部 NOT RUN
4. **设备矩阵证据不足**：未满足 SDD v0.4 §7.2 "至少 2 台真机" + TDD v1.0 §5.1 "6/6 实验"

### 13.2 理论性结论（**非**真机证据）

1. **API 层路径可达**：`record ^7.1.0` 提供 `start()` 与 `startStream()` 两个独立调用入口（不同实例）；同一实例互斥（README 明确）
2. **静态层无问题**：spike 工具 `dart analyze tool/` `No issues found!`
3. **Android 平台层行为未被证实**：双实例并发 + 共享物理麦克风是否稳定占用、`onStop` 回调是否串台 —— **必须真机验证**

### 13.3 不可绕过边界的边界（任务 §6）

- **不**写 `lib/**` 生产代码
- **不**修改 `pubspec.yaml` / `pubspec.lock`
- **不**修改 Manifest（含新增 INTERNET 权限）
- **不**升级 Drift schema
- **不**修改 `RealAudioRecorderService` 公共 API
- **不**动 m4a 录音 + T030 播放 + T031E LoopMode 既有闭环

## 14. 决策

### 14.1 决策结论

**`Blocked`**

### 14.2 决策理由

| 标准（任务 §8） | 期望 | 实际 | 结论 |
|----------------|------|------|------|
| 证据完整 | 7 项必含清单全部 PASS + 6/6 真机实验通过 | 0/7 必含清单 PASS（仅 1 项 code-level PASS）；0/6 真机实验 | 不满足 |
| ≥2 台设备矩阵 | 至少 2 台 Android 真机 | 0 台真机执行 | 不满足 |
| m4a 与 PCM 均稳定 | m4a 文件完整 + PCM 流连续 | 全部 NOT RUN | 不满足 |
| 二元裁决 | `Approved for P1 implementation` **或** `Blocked` | 必须 `Blocked` | ✓ |

任务 §8 明确：

> `Approved for P1 implementation` 只能在证据完整、至少 2 台设备矩阵通过、m4a 与 PCM 均稳定时使用。
> 如果只有 1 台设备通过，结论必须是 `Blocked` 或 `Provisional evidence only, not approved`。

**本任务证据强度 = 0（无任何真机物理执行）；不允许 `Approved with Conditions`（任务 §8 + §10 禁止）。**

### 14.3 不允许裁决项拒绝

任务 §10 明确禁止：

- ❌ `Approved with Conditions` → **不**使用
- ❌ `Pending` → **不**使用
- ❌ `Blocker equivalent` → **不**使用
- ❌ `Provisional evidence only, not approved` → 任务 §8 允许，但本任务证据 = 0，**不**写 Provisional；直接 `Blocked`（更明确）

## 15. 后续任务建议

### 15.1 推荐下一步方向（**待真机物理执行**）

| 选项 | 描述 | 风险 | 推荐度 |
|------|------|------|--------|
| **选项 X：真机补做 A 方案 spike** | 在 ≥2 台真机（HUAWEI CDY-AN90 + 1 台中端 Android 13+）上执行 5s/30s/5min 三档双实例 spike；更新 ADR；若 6/6 PASS → `Approved for P1 implementation` | 需要用户 / 真机 | **首选** |
| 选项 C：事后解码方案 Spike（`T050B`） | 评估 `just_audio ^0.10.5` 是否暴露纯解码 API；若不暴露则需 FFI / `MediaExtractor` JNI；UI 改为"会话结束反馈" | 破坏 PRD §5.1 步骤 7 实时反馈承诺 | 二选（仅作为"放弃实时"兜底） |
| 选项 D：FFI 方案 Spike（`T050C`） | 自己写 FFI 调 Android `AudioRecord`；与 `record` 包内 `AudioRecord` 实例做隔离 | FFI 编译 + 维护成本高；与既有 Dart-side 抽象偏离 | P3+ 备选 |
| 选项 Y：暂缓 OP-1 | 接受"P2 互动闭环仅会话结束反馈"或"P1 调音器走静态 GCEA 频率表降级路径"；OP-1 推到 P3+ | 影响 P2 关键门（9 步闭环真机录屏 + 节奏/起音对齐初始校准） | 兜底 |

### 15.2 给主会话 + GPT 首席架构师的建议

1. **本任务 ADR = `Blocked`**；**不**进入 P2 互动闭环；**不**启动 T8 Tuner Real-Time
2. **推荐选项 X（真机补做 A 方案 spike）**：由用户在真机上执行 `tool/spike_op1_audio_capture.dart`；更新本 ADR 的 §7-§12；如 6/6 PASS → 启动 `T049A_REDO_OP1_SPIKE` 产出 `Approved for P1 implementation` ADR；如部分 FAIL → 评估 C / D / 暂缓
3. **本 ADR 必含**：`dart analyze tool/spike_op1_audio_capture.dart` PASS + Context7 `/llfbandit/record` README 引用 + spike 工具代码静态层 OK + 真机 NOT RUN 显式标注
4. **不**修改 `pubspec.yaml` / Manifest / Drift / 生产代码；**不**绕过 §6 边界

## 16. 是否允许进入 P1 正式实现

**不允许** —— A 方案**未**通过真机 spike；任何 P2 互动闭环任务（如 T3 OP-1/OP-2 Decision、T8 Tuner Real-Time）**必须等待真机补做 spike 后的 ADR Approved**。

具体阻断范围：
- ❌ T8 Tuner Real-Time Implementation（依赖 OP-1 = A 方案通过）
- ❌ P2 Lesson Session Engine（依赖 OP-1 PCM 流）
- ❌ P2 9 步互动闭环真机录屏
- ❌ 节奏/起音对齐初始校准

## 17. 三步反思

### 17.1 【初步实现】

- 编写 `tool/spike_op1_audio_capture.dart`（spike harness；静态层 OK）
- 编写 ADR 初稿（基于 SDD v0.4 §7.2 + TDD v1.0 §5.1）
- 验证 `dart analyze tool/` `No issues found!`
- 明确"无真机"硬限制 → ADR 决策必须为 `Blocked`
- 不修改 `lib/**` / `pubspec.yaml` / Manifest / Drift schema / 生产代码

### 17.2 【自我找茬】（≥ 3 项偏航风险）

1. **"无真机"被低估**：本任务执行环境（Windows 11 / Git Bash）只有 1 台开发者机器，且不是 Android 设备。任务要求真机 6 次实验——0 台真机 = 0/6 实验。**缓解**：ADR §13 + §14 显式标注 0 真机证据；决策必须 `Blocked`；**不**伪造 / **不**编造 PASS。
2. **spike 工具静态 OK ≠ 平台层 OK**：spike 工具 `dart analyze` PASS 仅证明 Dart 代码可达；Android 平台层（AAudio/MMMap / `MethodChannel.onStop` 归属）未被真机验证。**缓解**：ADR §11 + §12 显式区分"code-level PASS"与"真机 NOT RUN"；**不**混淆两层证据。
3. **PRD §5.5 / SDD §7.2 / TDD §5.1 都强调"未证实 ≠ 通过"**：双 `AudioRecord` 共用麦克风的 Android 平台层行为**当前无官方 API 文档证伪也未证实**（SDD v0.4 §7.2 明文）。**缓解**：ADR §3.1 显式引用 SDD v0.4 §7.2 原文；**不**预设"理论可行 = 真机通过"。
4. **`tool/spike_op1_audio_capture.dart` 是 `dart analyze tool/` OK 但 `flutter analyze tool/` 可能不同**（pubspec 入口 vs 单独 analyze）：spike 工具是 `flutter run` 入口（`main()` 函数 + `package:record` / `package:uuid` / `package:path_provider` 等生产依赖）；Dart-only `dart analyze tool/` 能用是因为这些依赖在 `pubspec.yaml` 中已声明。**缓解**：本任务**不**声明新依赖；**不**改 `pubspec.yaml`；spike 工具仅静态 analyze。
5. **`onStop` 回调归属测试未在 spike 工具中实现**：`record ^7.1.0` 的 `onStateChanged()` 是 broadcast stream（Context7 验证）；但**双实例**的 `onStop` / `onCancel` 是否串台 —— `record ^7.1.0` API 是否支持 platform-channel 级别实例标识 —— **未被本 spike 工具代码覆盖**。**缓解**：ADR §11 显式标注"start/stop 顺序 code-level PASS"但"回调归属 NOT RUN"；**不**伪造回调归属证据。
6. **ADR 决策二元裁决不模糊**：本任务**绝不**使用 `Approved with Conditions` / `Pending` / `Provisional` —— 因为任务 §8 + §10 明确禁止；证据 = 0 → 决策 = `Blocked`（明确二元）。
7. **三步反思的"自我找茬"本身必须基于真机未执行的事实**：不能"找茬"说"可能 m4a 文件不完整"——这是猜测，不是已知问题。已知问题是"真机未执行"。**缓解**：本节找茬只列"已知风险"（SDD §7.2 明文）；不列"假设风险"。

### 17.3 【终极交付】

- spike 工具代码静态 OK（`dart analyze tool/` clean）
- ADR §1-§16 全部按 SDD v0.4 §7.2 + TDD v1.0 §5.1 模板填写
- ADR 决策 = `Blocked`（二元裁决；**不**用 `Approved with Conditions` / `Pending`）
- 后续任务建议指向"选项 X：真机补做 A 方案 spike"作为首选
- 不修改 `lib/**` / `pubspec.yaml` / Manifest / Drift schema / 生产代码 / 既有契约
- Reviewer 3 名（Audio Architecture + Flutter Data + Android QA）只读评审
- 不 push / 不 tag / 不 amend / 不 rebase / 不 reset --hard

## 18. 引用

- `docs/PRD_v2.md` v0.3 §5.5 + §11 OP-1
- `docs/architecture/SDD_V2.md` v0.4 §3.5 + §3.6 + §7.1 + §7.2 + §7.4
- `docs/architecture/TDD_PRODUCT_V2_PHASE1.md` v1.0 §5.1 + §5.2 + §5.4
- `docs/architecture/IMPLEMENTATION_PLAN_PRODUCT_V2_PHASE1.md` v1.2 §2 T1
- `docs/dev/REAL_AUDIO_DEPENDENCY_SPIKE.md` §3.1 record 候选
- `docs/dev/TASK_LEDGER.md` T029 / T030 / T031E / T036 真机验收条目
- `docs/dev/TECH_DEBT.md` TD-007 / TD-010 / TD-013
- `lib/shared/services/real_audio_recorder_service.dart` (T029 既有契约)
- `lib/shared/services/audio_recorder_gateway.dart` (T029 既有契约)
- `lib/shared/services/microphone_permission_service.dart` (T027 既有契约)
- `lib/shared/services/audio_file_storage_service.dart` (T028 既有契约)
- `android/app/src/main/AndroidManifest.xml` RECORD_AUDIO 既有声明
- Context7 `/llfbandit/record` README + 源码（PCM16bits + AAC-LC + startStream + 双实例）
- Context7 `/llfbandit/record` record_android（Android `AudioRecord` 底层依赖）
