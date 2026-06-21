# 真实音频 MVP SDD（REAL_AUDIO_MVP_SDD）

> 本文档是 ukulele_app **真实录音与回放 MVP 阶段**的软件设计文档（Software Design Document）。
>
> ⚠️ 本文档**只做设计**，**不实现任何代码、不修改生产代码、不修改测试代码、不修改 `pubspec.yaml` / `AndroidManifest.xml`、不申请 `RECORD_AUDIO`、不接入真实麦克风、不实现录音、不实现播放、不修改 Drift schema、不构建 APK/AAB、不 push、不创建 Tag**。
>
> ⚠️ 本文档不记录 `key.properties` 内容 / 密码 / keystore 内容 / 用户目录 keystore 绝对路径。
>
> ⚠️ 本文档不是"已实现"声明。T025 仅为设计阶段，所有"将引入 / 将声明 / 将设计"语句均指后续任务（T026+）由 GPT 首席架构师出具独立 Prompt 后才能启动。

## Document Status

| 字段 | 值 |
| --- | --- |
| Task ID | `T025_REAL_AUDIO_MVP_SDD_TDD_DESIGN` |
| 基线 Commit | `703d2aa` |
| Release Tag | `v1.0.0-release` → `703d2aa` |
| 当前版本 | `1.0.0+2`（versionName=`1.0.0`, versionCode=`2`） |
| 状态 | **设计中**（仅完成 SDD/TDD 设计；实现尚未开始） |
| 是否修改生产代码 | **否** |
| 是否新增依赖 | **否** |
| 是否申请 `RECORD_AUDIO` | **否** |
| 是否接入真实麦克风 | **否** |
| 是否修改 Drift schema | **否** |
| 是否构建 APK/AAB | **否** |
| 是否 push | **否** |
| 是否创建 Tag | **否** |
| 下一步建议 | `T026_DEPENDENCY_RESEARCH_SPIKE` |

## 1. Product Scope

### 1.1 真实音频 MVP 包含（In-Scope）

| 能力 | 边界 |
| --- | --- |
| 真实录音 | Android 设备麦克风本地录音，文件保存到 App 私有目录 |
| 真实回放 | 已保存的录音可本地播放（播放 / 暂停 / 停止） |
| 录音文件与 `PracticeRecord` 关联 | 一条记录最多关联一段录音；`audioFilePath` 字段由 `null` / 模拟路径转为真实文件路径 |
| 保存记录时保存真实 `audioFilePath` | 保存流程把录音产物的绝对路径写入 Drift |
| 删除记录时清理对应音频文件 | 删除 `PracticeRecord` 时级联删除关联文件 |
| 权限拒绝时降级 | 麦克风权限被拒时显示友好提示，禁用真实录音入口或保留模拟录音降级文案（见 §3.4 / §6） |
| 用户清楚知道是否在录真实音频 | 文案必须明确"真实录音会调用麦克风并保存到本机" |

### 1.2 真实音频 MVP 不包含（Out-of-Scope）

| 不做 | 原因 |
| --- | --- |
| AI 评分 / 音高识别 / 自动纠错 | MVP 阶段不引入 AI |
| 云同步 / 账号系统 | MVP 离线优先 |
| 后台录音 / 后台播放 | MVP 不引入前台服务与通知 |
| 录音上传 / 录音导出 / 录音分享 | 隐私原则：无 `INTERNET` 权限、无分享入口 |
| 音频转文字 | 不引入第三方 ASR |
| 多轨编辑 / 波形编辑 / 降噪 | MVP 不做音频编辑 |
| 应用商店发布 | T024 验收仅代表"Release 工程化"完成；商店提交不在真实音频 MVP 范围内 |
| 旧模拟记录自动转换 | 旧记录（`audioFilePath = null` 或标记为模拟）保持原状；不自动"补录"或迁移为真实录音 |
| iOS 真机验收 | iOS 适配（`NSMicrophoneUsageDescription`、Runner 配置）仅预留文案；当前阶段不在 Android 真机验收范围 |
| 跨设备 / 跨 ROM 适配矩阵 | MVP 仅以用户单台真机为验收基线 |

### 1.3 与既有阶段的边界

- **离线 MVP（T012-T016）**：保留并兼容；`audioFilePath = null` 的旧记录仍可正确显示、回放按钮隐藏逻辑保留；
- **Release 工程化（T019-T024）**：保留全部产物 / 签名 / 真机验收基线；不替换 `v1.0.0-release` Tag；
- **真实音频 MVP（本任务 T025 设计）**：仅设计；不进入 T026 实现。

## 2. User Experience

### 2.1 录音页面进入流程

```text
打开 /recording 录音页
  ├─ 首次进入：从应用启动未申请过 RECORD_AUDIO
  │   ├─ UI 状态：permissionRequired（仅展示入口按钮 + 友好文案）
  │   └─ 文案：明确"开始真实录音会调用麦克风并把音频保存到本机 App 私有目录，不会上传"
  │
  ├─ 用户点击"开始真实录音"
  │   ├─ 权限通过 → 状态切换为 recording（启动 Recorder）
  │   └─ 权限拒绝（一次性 / 永久拒绝） → 见 §2.2
  │
  └─ 已授权用户：直接进入 recording 状态
```

### 2.2 权限拒绝降级文案

| 拒绝类型 | UI 状态 | 文案（示例，待 UI 工程师校对） |
| --- | --- | --- |
| 一次性拒绝 | `permissionDenied` | "你拒绝了麦克风权限。可点击下方按钮重新申请，或继续使用模拟录音。" |
| 永久拒绝（`permanentlyDenied`） | `permissionPermanentlyDenied` | "你已永久拒绝麦克风权限。请到系统设置 → 应用 → ukulele_app → 权限中开启。" + "前往设置" 按钮 |
| 麦克风被其他应用占用 | `error(micBusy)` | "麦克风正被其他应用占用，请关闭后重试。" + "重试" 按钮 |
| 设备无麦克风硬件 | `error(noMic)` | "当前设备未检测到可用麦克风，无法录音。" |

> 文案必须**明确**真实录音会调用麦克风并保存到本机。**不得**继续使用模拟录音阶段"模拟录音开始 / 停止"等可能误导用户的旧文案。

### 2.3 录音页状态对应的 UI 形态

| 状态 | 顶部文案 | 主按钮 | 次按钮 | 其他 |
| --- | --- | --- | --- | --- |
| `idle` | "未开始" | "开始真实录音" | "查看历史" | — |
| `permissionRequired` | "需要麦克风权限" | "申请权限并开始" | "查看历史" | — |
| `permissionDenied` | "权限被拒绝" | "重新申请权限" | "继续模拟录音（受限）" / "查看历史" | — |
| `permissionPermanentlyDenied` | "权限被永久拒绝" | "前往系统设置" | "查看历史" | — |
| `recording` | "正在录音：00:00 / 05:00" | "停止" | "取消（不保存）" | 显示倒计时；到 4:30 提示"还剩 30 秒"；5:00 自动停止 |
| `recorded` | "录音完成：00:32" | "保存为练习记录" | "重新录制" | 显示音频波形（轻量）或时长；**未保存前不要写入数据库** |
| `playing` | "回放中：00:08 / 00:32" | "停止回放" | "重新录制" | — |
| `saving` | "正在保存…" | 禁用 | 禁用 | 不允许离开页面 |
| `saved` | "已保存" | "查看详情" / "继续录音" | — | 跳转或清理临时文件 |
| `error` | 对应错误类型 | "重试" | "取消" | 见 §2.2 错误文案 |

### 2.4 录音列表 / 详情页

- 列表 / 详情与 T013.4B / T013.4C 既有结构兼容；
- 真实录音记录显示真实时长（`audioDurationMs`）；
- 文件丢失时 UI **隐藏回放按钮**（沿用 MVP `audioFilePath` 字段约定 + `AudioFileResolver` 检查文件存在性）；
- 旧模拟记录（`audioFilePath = null`）保留原行为：详情页回放按钮隐藏，仅显示文本信息；
- **不得**把旧记录伪装成真实录音或自动"补录"。

### 2.5 隐私说明与文案

- 设置 → 关于 → 隐私说明页面必须在真实音频 MVP 上线时同步更新"麦克风权限用途 / 录音本地存储 / 不上传"三段文案；
- 文案不得误导用户以为录音会上传或分享；
- 文案与 `docs/PRD.md` §13.3 既有文案保持一致，新增部分标注"真实音频阶段"。

## 3. Permission and Privacy

### 3.1 Android `RECORD_AUDIO`

| 项 | 设计决策 |
| --- | --- |
| 权限加入时机 | T027 任务在 `android/app/src/main/AndroidManifest.xml` 加入 `<uses-permission android:name="android.permission.RECORD_AUDIO" />`；T025 仅设计 |
| 同时检查的三个 Manifest | main / debug / profile 三处都必须检查（沿用 `TECH_STACK.md` §7.4 既有约定），不允许仅在 main 加 |
| 运行时申请时机 | 用户**首次点击"开始真实录音"**时才申请；**不在 App 启动时申请**；**不在首页 / 今日练习 / 设置页申请**（沿用 MVP 既有原则） |
| 永久拒绝处理 | 引导用户前往系统设置；按钮文案"前往系统设置" |
| 一次性拒绝处理 | 在录音页内允许"重新申请权限"按钮；不强制跳转系统设置 |
| 申请弹窗不可定制 | 使用系统默认权限弹窗；不在 App 内自绘"伪弹窗" |

### 3.2 权限拒绝与永久拒绝的语义

- `permission_handler` 返回 `PermissionStatus.denied` / `limited` / `permanentlyDenied` / `restricted` / `granted`；
- 设计层把 `denied` / `limited` / `restricted` 视为"可在 App 内重试"，`permanentlyDenied` 视为"必须跳转系统设置"；
- 文案必须明确"权限被拒绝不会上传任何数据"。

### 3.3 无 `INTERNET` 原则

- 真实音频 MVP **不得**声明 `android.permission.INTERNET`；
- 任何需要联网的依赖自动禁止（与 `TECH_STACK.md` §10 一致）；
- 录音文件只能保存到 App 私有目录（`getApplicationDocumentsDirectory()`），**不写公共目录**，避免 Android 13+ 媒体权限复杂度（沿用 MVP `PRD.md` §10.4）；
- 不引入任何 Crashlytics / Sentry / Firebase / APM / 分析 SDK；
- 真实音频阶段不修改"无 INTERNET"原则。

### 3.4 权限拒绝时的降级方案

- 设计决策（待 T031 UI 实现时确认）：**保留模拟录音能力作为降级**，但 UI 必须明确标注"模拟录音"；
- 替代方案：**完全禁用真实录音入口**，仅提示"权限被拒绝，无法使用真实录音"；
- 倾向推荐方案：**保留模拟录音降级 + 显式文案标注**，避免用户因为拒绝权限而完全失去录音练习能力；
- 该决策由 GPT 首席架构师 + 用户在 T031 阶段前确认；本任务不锁定。

### 3.5 iOS 预留文案（不在当前验收范围）

> iOS Runner 配置不在 T026-T037 范围内；仅在本文档预留文案。

```xml
<!-- ios/Runner/Info.plist 待 iOS 阶段补充 -->
<key>NSMicrophoneUsageDescription</key>
<string>ukulele_app 需要使用麦克风录制你的练习音频；音频仅保存在本机 App 私有目录，不会上传到任何服务器。</string>
```

### 3.6 隐私政策需要补充的条款

| 条款 | 内容 |
| --- | --- |
| 数据收集 | 真实音频阶段仍**不收集**任何用户行为数据 / 分析数据 |
| 麦克风权限用途 | "调音器检测琴弦音准 + 用户主动触发的真实录音" |
| 录音存储位置 | "App 私有目录（`getApplicationDocumentsDirectory()`），其他应用无法访问" |
| 录音上传 | "不上传；不分享；不导出" |
| 用户权利 | "用户可随时删除单条录音；卸载 App 即清除全部录音与练习记录" |
| 备份 | "默认不备份到云端；卸载 = 数据全部清除" |
| 第三方 | "不接入任何第三方音频分析 / AI 评分 / 语音转文字服务" |

### 3.7 用户删除记录与音频文件清理

- 删除 `PracticeRecord` 时，**必须**同步删除关联音频文件；
- 文件删除失败时：UI 提示"记录已删除，音频文件删除失败，请手动清理"；**不**回滚数据库（数据库删除与文件删除是两步事务，数据库删除成功即视为用户操作生效）；
- 卸载 App：Android 默认清除 App 私有目录与数据库（`/data/user/0/com.yupi.ukulele`），与 MVP 既有行为一致。

## 4. Audio File Lifecycle

### 4.1 存储目录候选

| 候选 | 路径 | 优点 | 风险 |
| --- | --- | --- | --- |
| A. App 私有文档目录（**推荐**） | `getApplicationDocumentsDirectory()/recordings/` | 与 MVP PRD §6.6 一致；卸载自动清除；无需额外权限 | 占用 App 私有空间 |
| B. App 缓存目录 | `getTemporaryDirectory()/recordings/` | 卸载自动清除；用户可在系统设置手动清除 | 任何缓存清理都会丢失录音；不推荐 |
| C. 外部存储（Scoped Storage） | `/storage/emulated/0/Music/ukulele_app/` | 用户可见 | 需 `READ_MEDIA_AUDIO` / `WRITE_EXTERNAL_STORAGE` 权限；增加 Android 13+ 媒体权限复杂度；违反"无媒体权限"原则 |
| **决策** | **候选 A（App 私有文档目录）** | 与 PRD 一致；无额外权限 | — |

### 4.2 临时文件 vs 已保存文件

| 类型 | 路径 | 生命周期 |
| --- | --- | --- |
| 临时文件（recording in progress / 未保存） | `getApplicationDocumentsDirectory()/recordings/_tmp/<uuid>.m4a` | 仅在录音中或 `recorded` 状态存在；保存时迁移到正式目录或重命名 |
| 已保存文件（saved） | `getApplicationDocumentsDirectory()/recordings/<yyyy-MM-dd>/<recordId>.m4a` | 与 `PracticeRecord` 同生命周期；删除记录时一并删除 |

> **设计建议（待 T028 实现时确认）**：MVP PRD §10.2 既有命名 `<timestamp>_<uuid>.m4a` 可保留为扁平结构；真实音频阶段建议改为按日期分目录以避免单目录文件过多。命名格式：**`YYYY/MM/DD/<recordId>.m4a`**，最终决策在 T028 实现时由 `04-audio-engineer` + `06-local-data-engineer` 联签。

### 4.3 文件命名规则

- **命名格式**：`<recordId>.m4a`（`recordId` 为 UUID v4，由 `PracticeRecordIdGenerator` 生成，沿用 T013.4A0 既有约定）；
- **格式**：M4A（AAC-LC），单声道，44100Hz，128kbps（与 MVP PRD §6.6 一致）；
- **不**使用 WAV：体积大、不必要；
- **不**使用 MP3：开源编码库限制；
- **待 T026 依赖 Spike 复核**：record 7.x 的 AAC 输出参数是否与 44100Hz / 128kbps 一致；如有偏差由 T026 写入 ADR。

### 4.4 录音取消时清理

- 用户点击"取消（不保存）"或中途退出录音页（`appPaused` / `appResumed`）：
  - 立即停止 `AudioRecorderService`；
  - 删除 `_tmp/` 下的临时文件；
  - 状态回到 `idle`。

### 4.5 保存失败时清理

- 保存流程（写入 Drift 记录）失败：
  - 删除已写入磁盘的录音文件（避免数据库不存在但文件存在）；
  - 状态回到 `recorded`，允许用户重试保存或重新录制；
  - 错误信息明确"保存失败，请重试"。

### 4.6 删除记录时清理

- 删除 `PracticeRecord`：
  - 先删除 Drift 行；
  - 再删除文件；
  - 文件删除失败：UI SnackBar 提示"记录已删除，音频文件删除失败，请手动清理"；**不**回滚数据库（与 §3.7 一致）；
  - 关联文件存在但数据库已被外部修改（`audioFilePath` 不为空但 `PracticeRecord` 不存在）→ 见 §7.4。

### 4.7 App 重启后的文件恢复规则

- App 重启后，已保存的录音文件不应被自动删除；
- 数据库中 `audioFilePath` 仍指向有效路径的记录视为"可回放"；
- 数据库中存在但文件已被外部删除的记录：UI **隐藏回放按钮**（沿用 MVP 既有逻辑 + `AudioFileResolver`）；
- 文件存在但数据库不存在的孤儿文件：由 §4.8 扫描策略清理。

### 4.8 孤儿文件扫描策略

- **不**在 App 启动时自动扫描（避免冷启动耗时）；
- **可选**：在设置 → 存储管理中提供"清理孤儿文件"按钮（仅作为候选，由 T028 / T037 决定是否实现）；
- **不**自动清理：避免误删用户期望保留但数据库丢失的录音（极端场景，例如数据库损坏）。

### 4.9 最大录音时长策略

- 沿用 MVP PRD §6.6：最长 5 分钟；4:30 提示"还剩 30 秒"；5 分钟自动停止；
- 自动停止时状态切换为 `recorded`，等待用户选择保存 / 重新录制 / 取消。

### 4.10 文件大小风险

- 5 分钟 AAC 128kbps ≈ 4.7 MB；10 条记录 ≈ 47 MB；
- 100 条记录 ≈ 470 MB；
- 真实音频 MVP 阶段**不**实现自动压缩 / 转码 / 清理；
- 由用户在设置页查看总占用（可选，本任务不强制）。

### 4.11 音频格式候选

| 候选 | 优点 | 风险 | 决策 |
| --- | --- | --- | --- |
| M4A / AAC-LC | 体积小；Android 原生支持；record 7.x 默认输出 | 需要校验 record 实际输出格式 | **首选** |
| WAV / PCM | 无损；适合后续 AI 评分 | 体积大（5 分钟 ≈ 50 MB）；不适合长期存储 | 不推荐 |
| OGG / Opus | 开源 | Android 部分机型兼容性问题 | 不推荐 |
| MP3 | 通用 | 开源编码库限制；record 7.x 不直接支持 | 不推荐 |

## 5. Dependency Candidates

> **不直接决定引入旧依赖**。所有候选依赖由 T026 任务通过 Context7 + pub.dev + 实际 Spike 验证后写入 `pubspec.yaml`。本节仅列出候选评估，不构成"已添加"声明。

### 5.1 record

| 项 | 内容 |
| --- | --- |
| 用途 | Android / iOS 麦克风录音（AAC m4a / WAV / PCM 流） |
| 优点 | 与 MVP PRD §6.6 / `TECH_STACK.md` §6.1 既有决策一致；活跃维护 |
| 风险 | 7.x 要求 `minSdk = 23`；当前 `minSdk = 24` 满足；待 T026 复核 9.x / 10.x 最新稳定版 |
| 当前项目兼容性待验证 | record 与 `permission_handler` 是否冲突；record 与 Riverpod 集成模式；record 实际输出格式与 AAC 参数 |
| 是否需要 Context7 或官方文档复核 | **是**（T026 必经） |
| 是否建议进入下一步 Spike | **是**（T026 DEPENDENCY_RESEARCH_SPIKE 首要候选） |

### 5.2 flutter_sound

| 项 | 内容 |
| --- | --- |
| 用途 | 麦克风录音 + 播放 + 波形可视化；底层封装 native API |
| 优点 | 功能完整；支持波形；活跃维护 |
| 风险 | 包体积较大；native API 变化频繁；与 `record` 选型有冲突，**必须二选一**；项目既有决策（`TECH_STACK.md` §6.1）首选 `record` |
| 当前项目兼容性待验证 | 是否提供 PCM 流供调音器复用；包体积对 Release APK 影响 |
| 是否需要 Context7 或官方文档复核 | 是 |
| 是否建议进入下一步 Spike | **可选**（仅作为 `record` 的对照参考；T026 不强制要求独立验证） |

### 5.3 just_audio

| 项 | 内容 |
| --- | --- |
| 用途 | 本地音频播放（MP3 / AAC / WAV / 流媒体） |
| 优点 | 与 MVP PRD §6.7 既有决策一致；活跃维护 |
| 风险 | 与 `audioplayers` 二选一（`TECH_STACK.md` §10 已明确不引入 `audioplayers`） |
| 当前项目兼容性待验证 | just_audio 0.10.x 与 Flutter 3.x SDK 兼容性；M4A / AAC 在 Android 端的解码依赖 |
| 是否需要 Context7 或官方文档复核 | 是 |
| 是否建议进入下一步 Spike | **是**（与 record 同步验证） |

### 5.4 audioplayers（替代候选）

| 项 | 内容 |
| --- | --- |
| 用途 | 轻量音频播放 |
| 优点 | 包体积小 |
| 风险 | MVP 既有决策（`TECH_STACK.md` §6.1）首选 `just_audio`；`TECH_STACK.md` §10 明确不引入 `audioplayers` |
| 当前项目兼容性待验证 | 无需进一步验证；项目决策已锁定 `just_audio` |
| 是否建议进入下一步 Spike | **否**（已被既有决策排除） |

### 5.5 permission_handler

| 项 | 内容 |
| --- | --- |
| 用途 | Android / iOS 运行时权限申请与状态查询 |
| 优点 | 与 MVP PRD §11.4 / `TECH_STACK.md` §6.1 既有决策一致；活跃维护 |
| 风险 | 11.x+ 要求 `compileSdk ≥ 33`；当前 `compileSdk = 36` 满足 |
| 当前项目兼容性待验证 | 是否需要 `coreLibraryDesugaring`；与 Android 13+ 媒体权限的兼容性（本任务不使用媒体权限） |
| 是否需要 Context7 或官方文档复核 | 是 |
| 是否建议进入下一步 Spike | **是** |

### 5.6 path_provider

| 项 | 内容 |
| --- | --- |
| 用途 | 跨平台获取 App 私有目录（`getApplicationDocumentsDirectory()` 等） |
| 优点 | 已有项目中可能已存在（T005 阶段 `TECH_STACK.md` §1.1 已列入候选）；Flutter 官方包 |
| 风险 | 既有项目未必已引入；需 T026 确认 |
| 当前项目兼容性待验证 | 与现有 Drift 数据库路径是否冲突 |
| 是否建议进入下一步 Spike | **是**（基础依赖） |

### 5.7 不引入的依赖

| 禁止项 | 原因 |
| --- | --- |
| `firebase_*` / `sentry_*` / 任何联网 SDK | 违反"无 INTERNET"原则 |
| `flutter_local_notifications` / 前台服务相关 | MVP 不做后台录音 |
| `audioplayers` | 既有决策锁定 `just_audio` |
| `provider` / `flutter_bloc` / `GetX` | 状态管理选型固定为 Riverpod |
| `sqflite` | 与 Drift 冲突 |
| 任何"AI 评分" / "语音转文字" / "音频分析" 第三方 SDK | MVP 不做 AI |
| 任何需要 INTERNET 权限的依赖 | 自动禁止 |

## 6. Data and Schema Design

> **本节是设计，不修改 Drift schema**。`schemaVersion = 1` 的当前状态保持到 T026+ 实际迁移之前。

### 6.1 `PracticeRecord.audioFilePath` 契约

| 阶段 | `audioFilePath` 值 | 含义 |
| --- | --- | --- |
| MVP 离线 / Release v1.0.0 | `null` | 模拟录音；UI 隐藏回放按钮 |
| 真实音频 MVP 上线后（已迁移的旧记录） | `null` | 旧记录保持 `null`；UI 仍隐藏回放按钮 |
| 真实音频 MVP 上线后（新增真实录音） | 真实路径字符串 | UI 显示回放按钮；播放时调用 `AudioPlayerService` |

- **契约**：新增 / 更新 `PracticeRecord` 时，`audioFilePath` 必须为 `null` 或已存在的真实文件绝对路径；
- **不允许**：模拟路径、临时路径、未保存的录音路径被持久化到 `audioFilePath`；
- **校验**：Repository 写入前必须校验 `audioFilePath == null || File(audioFilePath).existsSync() == true`，否则抛 `AudioFileNotFoundException`；
- **回退**：真实音频阶段不向后兼容旧字段；不"补录"或"自动迁移"模拟记录为真实录音。

### 6.2 新增字段（候选，待 T032 确认）

| 字段 | 类型 | 是否可空 | 说明 |
| --- | --- | --- | --- |
| `audioDurationMs` | int | 否 | 录音时长（毫秒）；真实音频记录必填；旧记录默认值 0 或从既有 `durationSeconds` 字段同步（最终由 T032 决定） |
| `audioFormat` | text | 否 | 音频格式字符串（如 `"aac"` / `"m4a"`）；真实音频记录必填；旧记录默认值 `"unknown"` 或 `"simulated"` |
| `audioFileSizeBytes` | int | 否 | 音频文件大小（字节）；真实音频记录必填；旧记录默认值 0 |
| `audioCreatedAt` | dateTime | 否 | 录音文件创建时间；真实音频记录必填；旧记录默认值 = `practiceDate` |
| `audioDeletedAt` | dateTime | 是 | 标记音频文件已被外部删除（与 `audioFilePath` 仍指向原路径并存）；旧记录 `null` |
| `recordingMode` | text | 否 | 录音模式枚举：`"simulated"` / `"real"`；旧记录 `"simulated"`，真实音频阶段新增 `"real"` |

> **决策倾向（待 T032 确认）**：
> - 推荐**新增 `recordingMode` 字段**以明确区分模拟 / 真实录音，避免旧记录被误判为真实录音；
> - 推荐**新增 `audioDurationMs`** 而非复用 `durationSeconds`，因为后者语义是"练习时长"而非"录音时长"，可能不同；
> - 其余字段按需新增；本任务**不锁定**最终字段列表。

### 6.3 `schemaVersion` 升级策略

| 当前 | 升级目标 | 升级方式 |
| --- | --- | --- |
| `schemaVersion = 1` | `schemaVersion = 2` | 在 T032 任务中通过 `MigrationStrategy.onUpgrade` 增加新字段（nullable + default） |
| 不破坏既有数据 | 旧记录保留原 `audioFilePath = null`；新增字段默认值 | — |
| 真实音频 MVP 之前的 release（v1.0.0） | 不会触发迁移（v1.0.0 在 schemaVersion = 1 冻结） | — |
| 真实音频 MVP 上线后 | 触发 `onUpgrade` 把 `schemaVersion = 1` → `2` | 必须有完整迁移测试（见 TDD §Drift migration tests） |

### 6.4 旧记录迁移策略

- **不自动转换**：旧记录（`audioFilePath = null`）保持原状，不"补录" / 不"模拟为真实"；
- **保留兼容**：旧记录继续按"模拟录音"显示（回放按钮隐藏 + 模拟录音文案保留在隐私说明 / 内容声明中作为历史能力说明）；
- **UI 区分**：通过 `recordingMode == "simulated"` 字段在 UI 中显示"模拟录音（历史记录）"标识；
- **不删除旧记录**：用户隐私原则与 MVP 既有约定一致，不主动清理用户数据。

### 6.5 删除记录与文件清理事务边界

| 步骤 | 顺序 | 失败处理 |
| --- | --- | --- |
| 1. 删除 Drift 行 | 第一步 | 失败则中止，不删除文件 |
| 2. 删除关联音频文件 | 第二步 | 失败则 SnackBar 提示用户手动清理；**不回滚数据库** |
| 3. 更新 UI | 第三步 | — |

> 设计选择"先数据库后文件"：保证数据库一致性的优先级高于文件清理，因为数据库不一致更影响用户查询；文件不一致可由用户在系统设置或第三方清理工具中处理。

### 6.6 文件存在但数据库不存在的处理

- **场景**：App 卸载重装（数据库被清空但音频目录可能残留）；或数据库被外部清空；
- **处理**：见 §4.8 孤儿文件策略；**不**在 App 启动时扫描；可选"清理孤儿文件"按钮由 T028 决定；
- **真实音频 MVP 阶段**：**不**提供该按钮（保持 MVP 简洁）。

### 6.7 数据库存在但文件丢失的处理

- **场景**：用户通过文件管理器删除音频；或 App 数据被部分恢复；
- **处理**：
  - `AudioFileResolver.exists(path)` 返回 `false`；
  - UI 隐藏回放按钮（沿用 MVP 既有行为）；
  - 设置 `audioDeletedAt = DateTime.now()` 标记（待 T032 确认是否启用）；
  - 不删除数据库行（用户可能希望保留记录作为练习日志）。

### 6.8 测试数据库与真机文件路径隔离

- 单元测试 / Widget 测试 / 集成测试使用 Drift `NativeDatabase.memory()` 或临时目录；
- **不得**在测试中写真实文件路径到生产 `PracticeRecordRepository`；
- `AudioFileStorageService` 抽象成接口，测试中替换为 `InMemoryAudioFileStorageService`；
- 真机验收路径与测试路径物理隔离：`getApplicationDocumentsDirectory()` 在测试中通过 mock 返回临时目录。

## 7. Architecture

### 7.1 服务边界

| 服务 | 职责 | 文件位置（建议，待 T029 实现确认） |
| --- | --- | --- |
| `AudioRecorderService` | 封装 record 7.x：start / stop / cancel；返回文件路径 | `lib/shared/services/audio_recorder_service.dart` |
| `AudioPlaybackService` | 封装 just_audio 0.10.x：play / pause / stop / seek（**MVP 不实现 seek**） | `lib/shared/services/audio_playback_service.dart` |
| `PermissionService` | 封装 permission_handler：request / status；区分"首次拒绝" / "永久拒绝" | `lib/shared/services/permission_service.dart` |
| `AudioFileStorageService` | 路径生成、文件存在性检查、文件删除；不接触业务逻辑 | `lib/shared/services/audio_file_storage_service.dart` |
| `PracticeRecordRepository` | 既有接口增加真实音频路径写入校验；不破坏既有契约 | `lib/features/practice_records/data/practice_record_repository.dart` |

### 7.2 Controller 状态机变化

| Controller | 既有职责 | 真实音频阶段变化 |
| --- | --- | --- |
| `RecordingPracticeController` | 模拟录音 / 模拟回放 | 真实录音 start / stop；真实回放 play / pause / stop；状态机扩展为真实音频完整状态机（见 §8） |
| `PracticeRecordDetailController` | 加载记录 + 删除 | 增加 `AudioFileResolver.exists()` 检查；删除流程增加文件清理步骤；不破坏既有契约 |
| `PracticeRecordListController` | 列表流 | 不变 |

### 7.3 Riverpod Provider 边界

| Provider | 作用域 | 真实音频阶段变化 |
| --- | --- | --- |
| `audioRecorderServiceProvider` | 全局 | 新增（沿用 `shared/services/` 既有约定） |
| `audioPlaybackServiceProvider` | 全局 | 新增 |
| `permissionServiceProvider` | 全局 | 新增 |
| `audioFileStorageServiceProvider` | 全局 | 新增 |
| `recordingPracticeControllerProvider` | feature-scoped | 既有；内部状态机变更 |
| `practiceRecordDetailControllerProvider` | feature-scoped | 既有；删除流程增强 |

### 7.4 UI 与服务层职责

- UI **不直接**调用 `AudioRecorderService` / `AudioPlaybackService`；
- UI 仅通过 `Controller` 间接调用；
- Controller 是状态机唯一所有者；
- 服务层抛出的异常由 Controller 捕获并转换为 UI 可消费的 `error` 状态；
- 跨 feature 调用通过 Provider 接口（沿用 `ARCHITECTURE.md` §9）。

### 7.5 错误类型

| 异常 | 来源 | 触发场景 |
| --- | --- | --- |
| `PermissionDeniedException` | `PermissionService` | 用户拒绝 RECORD_AUDIO |
| `PermissionPermanentlyDeniedException` | `PermissionService` | 永久拒绝 |
| `MicrophoneBusyException` | `AudioRecorderService` | 麦克风被其他应用占用 |
| `NoMicrophoneException` | `AudioRecorderService` | 设备无麦克风 |
| `RecorderStartFailedException` | `AudioRecorderService` | record 启动失败 |
| `RecorderInterruptedException` | `AudioRecorderService` | 录音中断（来电 / 蓝牙切换 / 系统抢占） |
| `FileWriteFailedException` | `AudioFileStorageService` | 磁盘写入失败 / 空间不足 |
| `AudioFileNotFoundException` | `AudioFileStorageService` / `PracticeRecordRepository` | 校验写入时文件不存在 |
| `PlaybackFailedException` | `AudioPlaybackService` | 播放失败（解码错误 / 文件被外部损坏） |
| `InsufficientStorageException` | `AudioFileStorageService` | 磁盘空间不足 |

> 错误类型必须由 Controller 翻译为 `RecordingState.error(errorType, message)` UI 状态；不直接暴露异常堆栈给用户。

### 7.6 平台差异

| 项 | Android | iOS |
| --- | --- | --- |
| 权限 | `RECORD_AUDIO` | `NSMicrophoneUsageDescription` |
| 文件目录 | `getApplicationDocumentsDirectory()` | 同上 |
| 录音 API | record 7.x Android backend | record 7.x iOS backend |
| 播放 API | just_audio Android backend | just_audio iOS backend |
| 当前阶段验收 | **是**（用户单台真机） | **否**（预留） |

## 8. State Machine

### 8.1 录音页状态枚举

```text
RecordingState
  ├─ idle                        // 未开始
  ├─ permissionRequired          // 待用户授权
  ├─ permissionDenied            // 一次性拒绝
  ├─ permissionPermanentlyDenied // 永久拒绝
  ├─ recording                   // 正在录音
  ├─ recorded                    // 录音完成，未保存
  ├─ playing                     // 回放中
  ├─ saving                      // 写入数据库中
  ├─ saved                       // 已保存
  └─ error                       // 错误（带 errorType）
```

### 8.2 关键事件

| 事件 | 前置状态 | 后置状态 | 副作用 |
| --- | --- | --- | --- |
| `requestPermission` | `idle` / `permissionDenied` | `permissionRequired` / `recording`（通过） / `permissionDenied`（拒绝） / `permissionPermanentlyDenied`（永久拒绝） | 触发 `PermissionService.request()` |
| `startRecording` | `idle` / `permissionRequired` / `permissionDenied`（先申请权限） / `recorded`（取消重新录制） | `recording` | 触发 `AudioRecorderService.start()`；清理旧临时文件 |
| `stopRecording` | `recording` | `recorded` | 触发 `AudioRecorderService.stop()`；返回文件路径 |
| `cancelRecording` | `recording` / `recorded` | `idle` | 删除临时文件；状态重置 |
| `play` | `recorded` / `saved` | `playing` | 触发 `AudioPlaybackService.play()` |
| `stopPlayback` | `playing` | `recorded` / `saved`（回到原状态） | 触发 `AudioPlaybackService.stop()` |
| `save` | `recorded` | `saving` → `saved` / `error` | 写入 Drift；成功后清理临时文件 |
| `delete` | `saved`（从详情页触发） | `error(fileDeleteFailed)` / 跳转 | 删除 Drift 行 + 关联文件 |
| `retry` | `error` / `permissionDenied` | 视情况 | UI 重置按钮 |
| `appPaused` | `recording` / `playing` | `recorded` / 原状态 | 强制停止录音 / 播放；保留已写入磁盘的数据 |
| `appResumed` | 任意 | 视情况 | UI 重建；Controller 重建时按既有逻辑恢复 |

### 8.3 互斥规则

| 规则 | 强制 |
| --- | --- |
| 录音中不能播放 | **是**：`playing` 状态必须先 `stopPlayback` 才能 `startRecording` |
| 播放中不能录音 | **是**：录音前必须 `stopPlayback`（若播放中），或禁止录音按钮 |
| 保存中禁用关键按钮 | **是**：`saving` 状态禁用"停止录音 / 保存 / 取消 / 删除"按钮 |
| 删除中禁用关键按钮 | **是**：`deleting` 状态禁用其他详情操作（沿用 T013.4C_FIX_DELETE_PROGRESS_CONTRACT 既有契约） |
| `idle` 与 `permissionDenied` 互斥 | 严格按事件触发流转；不绕过 `requestPermission` |
| 录音状态与播放状态在同一时刻互斥 | 由 Controller 持有 mutex；UI 仅暴露单一主按钮 |

### 8.4 状态机图（简化）

```text
        requestPermission
idle ──────────────────────────► permissionRequired
  │                                   │
  │                              requestPermission
  │                                   │
  │   ┌───────────────────────────────┴──────────────┐
  ▼   ▼                                              ▼
recording ◄── startRecording ── recorded ── play ──► playing
  │                            │                    │
  │ stopRecording              │ save               │ stopPlayback
  ▼                            ▼                    │
recorded ◄── cancelRecording ── idle ◄───────────────┘
  │                            ▲
  │ save                       │ retry
  ▼                            │
saving ── error ──► error ─────┘
  │
  ▼
saved
```

## 9. Error Handling

### 9.1 错误场景与恢复

| 错误场景 | UI 行为 | 恢复策略 |
| --- | --- | --- |
| 权限被拒（一次性） | `permissionDenied` 状态 + "重新申请权限"按钮 | 按钮触发 `requestPermission` |
| 权限永久拒绝 | `permissionPermanentlyDenied` 状态 + "前往系统设置"按钮 | 跳转系统设置（不自动返回） |
| 麦克风不可用 | `error(noMic)` | 提示用户检查设备；不重试 |
| 录音启动失败 | `error(recorderStartFailed)` | "重试"按钮触发 `startRecording` |
| 录音中断（来电 / 系统抢占） | `recorded`（保留已写入数据）或 `error(interrupted)` | UI 提示"录音被中断，是否保存已录制部分" |
| 文件写入失败 | `error(fileWriteFailed)` | 不重试；返回 `recorded` 让用户重新录制 |
| 播放失败（解码错误） | `error(playbackFailed)` | "重试"按钮触发 `play` |
| 文件丢失（回放时） | UI 隐藏回放按钮 | `audioDeletedAt` 标记（待 T032 确认） |
| 存储空间不足 | `error(insufficientStorage)` | 提示用户清理空间；不自动重试 |
| 删除文件失败 | SnackBar "记录已删除，音频文件删除失败" | 用户手动清理（系统文件管理器） |
| App 后台切换 | 录音强制停止 → `recorded`（保留已录制数据） | 用户回到前台选择保存 / 重新录制 |
| Android 厂商 ROM 差异 | 依赖 record 7.x / just_audio 的兼容性矩阵 | T026 Spike 必须覆盖华为 / 小米 / OPPO 等国内常见 ROM |

### 9.2 错误日志

- 不写入本地日志文件（避免占用空间与隐私泄露）；
- 不上报到任何第三方（无 INTERNET 权限）；
- 真机问题排查依赖 `adb logcat` + 用户报告；
- 开发期间可用 `print` / `debugPrint` 但生产构建不输出。

## 10. Rollout Plan（建议任务拆分，不开始执行）

> 以下拆分仅为建议，最终任务边界与 Prompt 由 GPT 首席架构师出具。本任务（T025）**不执行** T026。

| 任务 ID | 任务名 | 主要 Agent | Reviewer | 关键交付 |
| --- | --- | --- | --- | --- |
| `T026_DEPENDENCY_RESEARCH_SPIKE` | 依赖调研 + Spike | `04-audio-engineer` | `02-flutter-architect` + `07-qa-reviewer` | record / just_audio / permission_handler / path_provider 实际版本验证 + 兼容性报告 + ADR |
| `T027_PERMISSION_AND_MANIFEST_DESIGN` | 权限与 Manifest 设计 | `04-audio-engineer` | `02-flutter-architect` + `08-compliance-reviewer` | `AndroidManifest.xml` 加入 RECORD_AUDIO；PrivacyNoticePage 文案更新；不写其他权限 |
| `T028_AUDIO_FILE_STORAGE_SERVICE` | 音频文件存储服务 | `06-local-data-engineer` | `04-audio-engineer` + `07-qa-reviewer` | `AudioFileStorageService` 实现 + 单测 + 路径生成规则落盘 |
| `T029_REAL_RECORDER_SERVICE` | 真实录音服务 | `04-audio-engineer` | `02-flutter-architect` + `07-qa-reviewer` | `AudioRecorderService` 实现 + PermissionService 整合 + 单测 |
| `T030_REAL_PLAYBACK_SERVICE` | 真实回放服务 | `04-audio-engineer` | `02-flutter-architect` + `07-qa-reviewer` | `AudioPlaybackService` 实现 + 单测 |
| `T031_RECORDING_CONTROLLER_REAL_AUDIO_STATE_MACHINE` | 录音 Controller 状态机 | `04-audio-engineer` | `02-flutter-architect` + `07-qa-reviewer` + `03-mobile-ui-engineer` | `RecordingPracticeController` 状态机扩展 + Widget 测试 |
| `T032_PRACTICE_RECORD_SCHEMA_MIGRATION` | Drift schema 迁移 | `06-local-data-engineer` | `02-flutter-architect` + `07-qa-reviewer` + `08-compliance-reviewer` | `schemaVersion = 1 → 2` 迁移脚本 + 迁移测试 + `audioFilePath` 契约测试 |
| `T033_UI_COPY_AND_PERMISSION_UX` | UI 文案与权限体验 | `03-mobile-ui-engineer` | `04-audio-engineer` + `07-qa-reviewer` + `08-compliance-reviewer` | 录音页文案 / 权限弹窗引导 / 设置页文案 / 隐私说明更新 |
| `T034_DELETE_AND_FILE_CLEANUP_INTEGRATION` | 删除与文件清理整合 | `06-local-data-engineer` | `04-audio-engineer` + `07-qa-reviewer` | 删除流程增加文件清理步骤 + SnackBar 错误处理 |
| `T035_AUTOMATED_TESTS` | 自动化测试 | `07-qa-reviewer` | `04-audio-engineer` + `06-local-data-engineer` + `02-flutter-architect` | 完整测试矩阵（含真实音频阶段的 30+ 测试用例） |
| `T036_ANDROID_REAL_DEVICE_AUDIO_ACCEPTANCE` | Android 真机录音验收 | 用户（主导）+ `07-qa-reviewer`（Agent 产出验收模板） | `04-audio-engineer` + `08-compliance-reviewer` | 真机录音 / 回放 / 权限 / 删除 / 文件丢失全流程用户验收 |
| `T037_RELEASE_DOCS_UPDATE` | 真实音频阶段文档收口 | `00-chief-architect` | `07-qa-reviewer` + `08-compliance-reviewer` | `REAL_AUDIO_MVP_ACCEPTANCE.md` + 台账 + 技术债 + Tag（如适用） |

### 10.1 任务边界铁律

- T026 之前**不**修改 `pubspec.yaml` / `AndroidManifest.xml` / Drift schema / Dart 生产代码 / 测试代码；
- T026 Spike **不**直接引入依赖；Spike 输出 ADR 后由 GPT 首席架构师决定是否进入 T027+；
- 任何 T027+ 任务的 `RECORD_AUDIO` 权限加入、依赖引入、Drift schema 变更必须由 GPT 首席架构师出具独立 Prompt；
- T036 真机验收必须由用户本人在真机上完成；Agent 不得代写"通过"；
- T037 是否创建新 Tag（如 `v1.1.0-real-audio`）由 GPT 首席架构师 + 用户决定；本任务不预设。

## 11. References

- `docs/PRD.md` §6.6 / §6.7 / §10 / §11.4 / §13（PRD 已规划但 MVP 阶段未实现）
- `docs/MVP_SCOPE.md` §2.1 / §2.2.1 / §6.6
- `docs/TECH_STACK.md` §6 / §7 / §10
- `docs/ARCHITECTURE.md` §3 / §5.3 / §7
- `docs/dev/RELEASE_ACCEPTANCE.md`（T024 Release 工程化验收基线）
- `docs/dev/RELEASE_ARTIFACTS.md`（T022 产物元信息）
- `docs/dev/RELEASE_DEVICE_ACCEPTANCE.md`（T023 真机验收基线）
- `docs/dev/MVP_ACCEPTANCE.md`（T016 MVP 验收基线）
- `docs/dev/AGENT_ROUTING_MATRIX.md` §4.7 / §6（真实录音路由）
- `docs/dev/AGENT_REVIEW_TEMPLATE.md`（报告模板）
- `docs/dev/AGENT_QUALITY_METRICS.md` §5.1.5（下一阶段 Reviewer 启用建议）
- `docs/dev/TASK_LEDGER.md`（任务台账）
- `docs/dev/TECH_DEBT.md` TD-007（真实音频阶段技术债）
- `agents/04-audio-engineer.md`
- `agents/02-flutter-architect.md`
- `agents/06-local-data-engineer.md`
- `agents/07-qa-reviewer.md`
- `agents/08-compliance-reviewer.md`