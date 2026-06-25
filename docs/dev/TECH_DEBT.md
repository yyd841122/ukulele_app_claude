# 技术债台账(Technical Debt Log)

本台账用于追踪 ukulele_app 中已识别但尚未处理的技术债,供后续任务在合适阶段评估与修复。

## 字段说明

- **ID**: 技术债编号,格式 `TD-NNN`,新增条目顺延。
- **问题**: 问题的具体描述,基于代码或文档可验证的事实。
- **影响**: 对当前功能、维护成本、用户体验或后续扩展的实际影响。
- **优先级**: `高` / `中` / `低`。影响越大、修复成本越低,优先级越高。
- **建议处理阶段**: 推荐的修复时间窗口或任务类型(例如 "T013 持久化阶段"、"体验打磨阶段")。
- **状态**: `待处理` / `处理中` / `已修复` / `已搁置`。

> 维护约定:本台账只记录已经被现有代码或文档明确验证的问题;不在本任务中确认新债;不做夸大或未经证实的描述。

---

## 技术债清单

| ID | 问题 | 影响 | 优先级 | 建议处理阶段 | 状态 |
| --- | --- | --- | --- | --- | --- |
| TD-001 | `RecordingPracticeController` 当前使用非 autoDispose 的 Riverpod provider,用户离开录音页面后,模拟录音/回放的 `Timer.periodic` 可能继续在后台运行并持续更新 state | 中 — 当前不影响功能正确性,但会消耗后台 tick,且页面关闭后回到录音页会看到已经累计的 `elapsedSeconds`,与"模拟一次练习"的语义略有冲突 | 中 | 后续体验打磨阶段评估 autoDispose,或在页面退出时主动停止录音/回放 | 待处理 |
| TD-002 | 离线 MVP 仍未产出可分发的 Release APK / AAB;`android/app/build.gradle` 中 `release` 当前仍临时借用 `signingConfigs.debug`,未配置正式签名密钥、密钥口令管理、密钥库安全与商店发布流程 | 高 — 不阻塞 MVP 离线功能验收,但未通过此检查点不得宣称"可上架 / 生产就绪";Release 构建与签名必须作为独立任务由用户和 GPT 首席架构师另行选择启动 | 高 | Release 工程化阶段(由 GPT 首席架构师复审 MVP_ACCEPTANCE.md 后单独排期,不在 T016 范围内) | **已搁置** (Release 工程化阶段 T019-T024 完成) |
| TD-003 | 尚未在 iOS 平台进行真机验收;iOS Runner 配置、Info.plist、签名证书、TestFlight 等均未纳入当前任务范围 | 中 — 当前 MVP 仅承诺 Android 离线能力,iOS 适配与验收需独立排期 | 中 | iOS 适配阶段(由 GPT 首席架构师另行排期) | 待处理 |
| TD-004 | Debug 通用 APK 体积较大(约 154 MiB,记录在 `MVP_ACCEPTANCE.md` 的 `Android Build Artifact` 节),不能据此推断 Release 包体积;当前未产出 `--split-per-abi` 或 `--release` 产物 | 低 — Debug 体积不直接代表用户体验;Release 阶段需重新评估体积策略(App Bundle、按 ABI 拆分、资源压缩) | 低 | Release 工程化阶段 | **已搁置** (Release APK ≈ 55.8 MiB / AAB ≈ 54.7 MiB,已落盘 `RELEASE_ARTIFACTS.md` §1,Debug 体积不再代表 Release 体积;后续 `--split-per-abi` / 资源压缩策略由真实音频阶段后的体积优化任务另行排期) |
| TD-005 | Android 构建工具链(Gradle 8.7 / AGP 8.6.0 / Kotlin Gradle Plugin 2.1.0 / JDK 17)在未来可能进入弃用或强制升级窗口;当前 MVP 不主动升级,工具链升级需独立任务并重新跑全量测试 | 低 — 当前构建已成功,弃用警告不阻塞 MVP 验收 | 低 | 后续兼容性维护阶段(独立任务) | 待处理 |
| TD-006 | 本机开发环境中 `adb` 未加入系统 PATH,目前通过绝对路径使用;该问题与代码、依赖、构建产物均无关,仅影响本地真机调试命令 | 低 — 不影响仓库可移植性,新开发者在自己的环境中按需配置 | 低 | 本地开发环境初始化阶段(非代码任务) | 待处理 |
| TD-007 | 当前 MVP 阶段不调用真实麦克风、不保存或播放真实音频,`PracticeRecord.audioFilePath` 始终为 `null`;`RecordingPracticeController` 在保存时硬编码 `audioFilePath: null`(`lib/features/recording/application/recording_practice_controller.dart:534`);**T027 已完成"权限基础层"**(新增 `permission_handler ^12.0.3` + 三处 Manifest 声明 `RECORD_AUDIO` + `MicrophonePermissionService` 抽象 + 14 项单元测试)但**未**接入真实麦克风、**未**实现录音、**未**实现播放、**未**实现音频文件生命周期、**未**修改 Drift schema、**未**开始真实录音调用;**T028 已完成"音频文件存储基础层"**(新增 `AudioFileStorageService` + `AudioFileStoragePaths` + 默认生产 root provider 基于 `path_provider.getApplicationDocumentsDirectory()/audio` + 8 个 API：`ensureDirectories` 幂等创建 root/temp/saved + `createTempFile` 仅生成 temp 路径契约 + `savedFileForRecord` 返回 `saved/YYYY-MM-DD/<recordId>.m4a` 路径并创建日期目录 + `exists` / `sizeBytes` 存在性与大小读取 + `deleteIfExists` 安全删除（**仅允许删除 root 之下普通文件**；root 外已存在文件 + `..` 路径逃逸抛 `ArgumentError`；root 目录被 `File(rootDirectory.path)` 包装时按"文件不存在"处理，`File.exists()` 对目录路径返回 `false`，返回 `false` 且 root 目录仍存在）+ `cleanupTempFiles` 仅清白名单扩展名顶层文件 + `isPathInsideRoot` 公开防御性方法 + 23 项纯单元测试;**安全目标**：root 目录不会被删除、root 外文件不会被删除)但**未**接入真实麦克风、**未**实现录音、**未**实现播放、**未**修改 Drift schema、**未**开始真实录音调用;**T029 已完成"真实录音服务基础层"**(新增 `record ^7.1.0` + 5 个新服务文件 `audio_recorder_state.dart` (5 状态枚举 + `AudioRecorderTakeResult` 值类型) + `audio_recorder_exception.dart` (sealed class + 5 子类) + `audio_recorder_gateway.dart` (抽象 + `PackageAudioRecorderGateway` 真实 `record 7.1.0` 包装) + `real_audio_recorder_service.dart` (状态机 + 异常恢复 + best-effort cancel 清理) + 1 个新 Provider 文件 `real_audio_recorder_service_provider.dart` + 1 个最小 Provider 文件 `audio_file_storage_service_provider.dart` + 1 个 fake gateway + 20 项纯单元测试)但**未**接入 `RecordingPracticeController`（**不**修改既有模拟录音流程）、**未**修改 Drift schema、**未**保存 `PracticeRecord`、**未**触发播放、**未**接入 UI;**T030 已完成"真实播放服务基础层"**(新增 `just_audio ^0.10.5` + 4 个新服务文件 `audio_playback_state.dart` (8 状态枚举 idle/loading/ready/playing/paused/completed/stopping/disposed + `AudioPlaybackStopResult` 值类型) + `audio_playback_exception.dart` (sealed class + 6 子类 `PlaybackLoadFailedException` / `PlaybackOperationFailedException` / `AudioFileNotFoundException` / `InvalidPlaybackStateException` / `PlaybackIOFailedException` / `PlaybackConfigException`) + `audio_playback_gateway.dart` (抽象 5 方法 + 3 stream getter + 2 值 getter + `PackageJustAudioPlaybackGateway` 真实 `just_audio 0.10.5` 包装 + `PlaybackPlayerState` / `PlaybackProcessingState` 投影) + `real_audio_playback_service.dart` (状态机 + 路径校验 + Stream 订阅管理 + 异常恢复 + dispose 幂等) + 1 个新 Provider 文件 `real_audio_playback_service_provider.dart` + 1 个 fake gateway + 42 项纯单元测试)但**未**接入 `RecordingPracticeController`（**不**修改既有模拟录音流程）、**未**实现 `Controller` 级录音与播放互斥状态机（**不**在 Service 内实现互斥；**不**修改既有 RecordingController 任何状态机分支）、**未**修改 Drift schema、**未**保存 `PracticeRecord`、**未**接入 UI、**未**触发录音 | 高 — T029 已完成真实录音服务基础层；T030 已完成真实播放服务基础层；T031 Controller 状态机集成（录音/播放互斥）/ T032 Drift schema 迁移 / T033 UI 文案 / T036 真机验收 仍待 GPT 首席架构师下发 T031+ 独立 Prompt 后才能启动 | 真实音频阶段(由 GPT 首席架构师 + 产品另行决策) | 待处理 (T025 已落盘 `REAL_AUDIO_MVP_SDD.md` + `REAL_AUDIO_MVP_TDD.md` 设计;T026 已完成依赖研究 / Spike `REAL_AUDIO_DEPENDENCY_SPIKE.md`;**T027 已完成权限基础层**:`permission_handler ^12.0.3` 引入 + 三处 AndroidManifest 显式声明 `RECORD_AUDIO` + `MicrophonePermissionStatus` enum (6 值) + `MicrophonePermissionGateway` 抽象 + `PermissionHandlerMicrophonePermissionGateway` 真实实现 + `MicrophonePermissionService` 依赖注入包装 + 14 项单元测试覆盖 6 状态映射 + 3 契约不变式 + openSettings 真假分支;**T028 已完成音频文件存储基础层**:`AudioFileStoragePaths` 不可变数据结构 + `AudioFileStorageService` 注入式根目录 + 8 个 API 路径生成 / 存在性 / 大小 / 安全删除 / 临时清理 + 文件名片段校验 + 路径逃逸防护 + 23 项纯单元测试;**T029 已完成真实录音服务基础层**:`record ^7.1.0` 引入 + `AudioRecorderState` enum (5 状态 idle/recording/stopping/cancelling/disposed) + `AudioRecorderTakeResult` 值类型 + `AudioRecorderException` sealed class (5 子类) + `AudioRecorderGateway` 抽象 (4 方法) + `PackageAudioRecorderGateway` 生产 `record 7.1.0` 包装（**不**调用 `AudioRecorder.hasPermission()`） + `RealAudioRecorderService` 依赖注入 + 状态机严格按 SDD §8 + 异常恢复 + best-effort cancel 清理 + `realAudioRecorderServiceProvider` + 20 项纯单元测试;**T030 已完成真实播放服务基础层**:`just_audio ^0.10.5` 引入 + `AudioPlaybackState` enum (8 状态 idle/loading/ready/playing/paused/completed/stopping/disposed) + `AudioPlaybackStopResult` 值类型 + `AudioPlaybackException` sealed class (6 子类，不复用 T029 录音专属异常) + `AudioPlaybackGateway` 抽象 (5 方法 + 3 stream getter + 2 值 getter) + `PackageJustAudioPlaybackGateway` 生产 `just_audio 0.10.5` 包装（**不**调用 `MicrophonePermissionGateway`，**不**触发 `INTERNET` 权限，仅本地 file:// 路径播放） + `PlaybackPlayerState` / `PlaybackProcessingState` 投影（`buffering` 合并到 `loading`） + `RealAudioPlaybackService` 依赖注入 + 状态机 + 路径校验复用 `AudioFileStorageService.isPathInsideRoot` + Stream 订阅管理 + 异常恢复 + dispose 幂等 + `realAudioPlaybackServiceProvider` + 42 项纯单元测试覆盖路径安全 11 项 + 状态机 9 项 + seek 4 项 + stop 2 项 + 自然完成 2 项 + reload 1 项 + gateway errors 4 项 + duration/position 3 项 + lifecycle 3 项 + 只读契约 3 项;**未**接入 `RecordingPracticeController`、**未**实现 `Controller` 级录音与播放互斥状态机（**不**在 Service 内实现互斥，由 T031 任务在 Controller 层协调）、**未**触发真实麦克风、**未**修改 Drift schema、**未**保存 `PracticeRecord`、**未**接入 UI、**未**构建 APK / AAB、**未**开始 T031+;实现仍待 GPT 首席架构师下发 T031+ 独立 Prompt 后才能启动;设计阶段边界、依赖候选、状态机、错误处理、回滚方案、测试矩阵均已落盘,见 `docs/dev/REAL_AUDIO_MVP_SDD.md` + `REAL_AUDIO_MVP_TDD.md` + `REAL_AUDIO_DEPENDENCY_SPIKE.md`;**T028A 文档契约校准**：删除契约准确表述为"`deleteIfExists` 只允许删除 root 之下普通文件；文件不存在返回 `false`；root 目录被 `File(rootDirectory.path)` 包装时按文件不存在处理，返回 `false`，root 目录仍存在；root 外已存在文件 + `..` 路径逃逸抛 `ArgumentError`；`cleanupTempFiles` 对 root 外 temp 目录抛 `ArgumentError`；安全目标为 root 目录不会被删除、root 外文件不会被删除";详细见 `TASK_LEDGER.md` T028A 条目) |
| TD-008 | MVP 之后的产品方向(账号 / 云同步 / AI 评分 / 商业化 / 真实音频)尚未决定;`ROADMAP.md` 中 V1-V5 阶段均标记为"后期",不在当前 MVP 范围守卫内 | 中 — 任何"开始下一阶段"的指令必须由用户和 GPT 首席架构师显式发出,本仓库不在 T016 内自动启动 | 中 | MVP 复盘与下一阶段排期阶段 | 待处理 |
| TD-009 | 构建环境可能依赖用户级网络代理配置(例如 Gradle 依赖拉取、Dart pub 镜像);该配置属于本机环境而非仓库,本台账不记录具体端口、用户名、绝对用户目录或密钥;如未来 CI / 团队协作需要,应改用仓库外(环境变量 / CI 密钥管理)而非提交到代码库 | 低 — 不影响仓库可移植性,仅在跨环境协作时需要明确"该配置不属于本仓库" | 低 | 持续 | 待处理 |
| TD-010 | 真实音频阶段必须新增或评估的音频相关依赖(`record` 7.1.0 / `just_audio` 0.10.5 / `permission_handler` 12.0.3 / `path_provider` 2.1.6)已由 T026 完成依赖研究 / Spike 调研;**T027 已完成 `permission_handler ^12.0.3` 引入**(TDD 完成:14 项单元测试覆盖 6 状态映射 + 3 契约不变式 + openSettings 真假分支;三处 AndroidManifest 显式声明 `RECORD_AUDIO`);**T029 已完成 `record ^7.1.0` 引入**(TDD 完成:20 项单元测试覆盖 5 状态转换 + 5 异常路径 + 1 配置 + 1 一次性 + 1 一次会话结束后 + 1 契约 + 1 重复 start 拒绝 + 1 dispose 幂等 + 1 dispose 后调用拒绝 + 1 dispose while recording + 1 一次会话结束后可开始下一次;Gateway 抽象 + 状态机 + 异常层次 + best-effort cancel 清理);**T030 已完成 `just_audio ^0.10.5` 引入**(TDD 完成:42 项单元测试覆盖路径安全 11 项 + 状态机 9 项 + seek 4 项 + stop 2 项 + 自然完成 2 项 + reload 1 项 + gateway errors 4 项 + duration/position 3 项 + lifecycle 3 项 + 只读契约 3 项;Gateway 抽象 + 状态机 + Stream 订阅管理 + 异常恢复 + dispose 幂等);`flutter pub get` 自动拉入传递依赖 `audio_session 0.2.3` / `just_audio_platform_interface 4.6.0` / `just_audio_web 0.4.16` / `rxdart 0.28.0` / `synchronized 3.4.1`(5 个),其中 `audio_session 0.2.3` 为 just_audio 自动带入的传递依赖,与 T026 Spike §3.7 决策一致 | 高 — T026 已提供研究结论,T027 已完成 `permission_handler` 引入,T029 已完成 `record` 引入,T030 已完成 `just_audio` 引入;`audio_session` 由 just_audio 自动带入,与 T026 Spike 决策一致;`audioplayers` / `flutter_sound` 既有决策排除,**未**引入;`INTERNET` 权限**未**声明;**未**实现 `Controller` 级录音与播放互斥状态机(T031 任务);T031+ 待 GPT 首席架构师独立 Prompt | T027 已完成; T029 已完成; T030 已完成; T031+ 待 GPT 首席架构师独立 Prompt | 待处理 (T026 Spike 完成,T027 已引入 `permission_handler ^12.0.3` + 三处 Manifest 声明 `RECORD_AUDIO` + 权限服务 + 14 项单元测试;**T029 已引入 `record ^7.1.0` + 8 个 `record_*` 生态子包 + 5 状态枚举 + 5 异常子类 + 20 项单元测试**;**T030 已引入 `just_audio ^0.10.5` + 5 个传递依赖（含 `audio_session 0.2.3`）+ 8 状态枚举 + 6 异常子类 + 42 项单元测试**;`audioplayers ^6.7.1` / `flutter_sound ^9.30.0` 既有决策排除;待 GPT 首席架构师下发 T031+ 独立 Prompt 后才能启动) |
| TD-011 | 真实音频阶段必须新增 Drift `schemaVersion = 2` 迁移:`practice_records` 表新增 `audioDurationMs` / `audioFormat` / `audioFileSizeBytes` / `audioCreatedAt` / `audioDeletedAt` / `recordingMode` 等候选字段(最终字段列表待 T032 确认),旧记录 `audioFilePath = null` 保留,新增字段填默认值(`recordingMode = "simulated"` 等);迁移脚本与迁移测试必须先于迁移代码(TDD);**不得**在 T025 任务中执行迁移 | 高 — 旧记录兼容性、Repository 契约、`audioFilePath` 语义变化均需在迁移前明确 | 高 | T032 `T032_PRACTICE_RECORD_SCHEMA_MIGRATION` | **已搁置** (T032 已完成; **事实校准**:`practice_records.audio_file_path` 列在 T013.1 (schema v1) 阶段已经被预留为 nullable TEXT — T013.1 注释明确"未来真实音频接入"; T032 bump `schemaVersion` 1→2 是 **contract-only bump**,**不**新增列,**不**写 ALTER TABLE,**不**改写任何行; `MigrationStrategy.onUpgrade(m, 1, 2)` 是显式 no-op;旧记录 `audio_file_path=NULL` 保持原样;v2 schema-evolution anchor 仅为标记"真实音频持久化阶段"在 schema 演进图上有明确节点;T013.1 注释中候选的 `audioDurationMs` / `audioFormat` / `audioFileSizeBytes` / `audioCreatedAt` / `audioDeletedAt` / `recordingMode` 等字段**未**在 T032 引入;后续若需要更丰富的元数据字段(`audioDurationMs` 等),由 T033+ 单独任务决策,**不**自动累积到 T032 scope) |
| TD-012 | 真实音频阶段 PrivacyNoticePage 文案需要更新"麦克风权限用途 / 录音本地存储 / 不上传"三段文案,且不得误导用户以为录音会上传 / 分享 / 导出;更新由 T033 任务执行,T025 / T026 仅落盘文案设计原则 | 中 — 用户知情权 + 隐私合规的核心要求,任何错误文案都会触发合规风险 | 中 | T033 `T033_UI_COPY_AND_PERMISSION_UX` | 待处理 |
| TD-013 | T026 依赖研究 Spike 识别的潜在实现风险点:`record 7.x` `AudioEncoder.aacLc` 重命名(4.x 引入)与本项目既有命名差异需在 T029 隔离 spike 中实测确认;**T029 已确认 `AudioEncoder.aacLc` 在 `record 7.1.0` 中为合法枚举值**,`RealAudioRecorderService` 显式使用 `AudioEncoder.aacLc` + `sampleRate=44100` + `bitRate=128000` + `numChannels=1` 构造 `RecordConfig`,与 SDD §4.3 + Spike §3.1 一致;20 项单元测试中第 2 项 "configures AAC-LC / M4A / mono / 44100Hz / 128kbps" 显式断言 `cfg.encoder == AudioEncoder.aacLc` 覆盖此风险;**T030 已确认 `just_audio 0.10.5` 在 `INTERNET` 权限未声明场景下仅使用本地 file:// 路径播放**,`RealAudioPlaybackService` 通过 `AudioPlaybackGateway` 抽象 + `PackageJustAudioPlaybackGateway` 代理 just_audio `AudioPlayer` 的 `setFilePath` / `play` / `pause` / `seek` / `stop` / `dispose` + 3 stream getter + 2 值 getter,本任务**不**触发 `INTERNET` 权限;42 项单元测试覆盖路径安全 11 项（含 root 内 / root 外拒绝 / `..` 路径逃逸 / root 自身拒绝 / temp/saved 目录自身拒绝 / 不支持扩展名 / 空路径 / 相对路径）+ 状态机 9 项 + seek 4 项（含负数 / 超出 duration）+ stop 2 项 + 自然完成 2 项 + reload 1 项 + gateway errors 4 项 + duration/position 3 项 + lifecycle 3 项 + 只读契约 3 项;`permission_handler 12.x` API 与 11.x 差异已由 T027 实测确认;真机国产 ROM 兼容性(HUAWEI / 小米 / OPPO / vivo)未在 Spike 阶段验证,必须由 T036 真机用户验收;`just_audio` 内置 ExoPlayer 版本冲突需在引入第二个 ExoPlayer 依赖时由 `02-flutter-architect` 评估是否显式指定 `exoplayer_version` | 中 — Spike 阶段已识别,但实际表现需 T029 / T030 隔离 spike + T036 真机验收最终确认 | 中 | T027 (权限实测,已完成) / T029 (record 实测,已完成) / T030 (just_audio 实测,已完成) + T036 (真机验收,待 GPT 首席架构师独立 Prompt) | 待处理 (T026 Spike 已识别风险,**T027 已完成权限实测**,**T029 已完成 record 实测并显式确认 `AudioEncoder.aacLc` 兼容性**,**T030 已完成 just_audio 实测并显式确认本地 file:// 路径播放（无 `INTERNET` 依赖）**;T036 真机验收待启动) |

## T031 状态备注（已落盘的真实音频 Controller 集成）

- **Controller 已接入真实录音/播放服务**（`RealAudioRecorderService` + `RealAudioPlaybackService` + `MicrophonePermissionService`）。
- **T032 已完成 schema 升级**：`schemaVersion` 由 1 升至 2（contract bump，`onUpgrade` 显式 no-op，旧数据 `audio_file_path=NULL` 保持原样，详见 `docs/dev/TASK_LEDGER.md` T032 条目）。
- **真实音频仍未持久化到记录**（录音 take 真实保存到 `AudioFileStorageService` 临时目录，但**未**绑定到 `PracticeRecord` — Controller save flow 仍写 `audioFilePath: null`，由 T033 任务接入）。
- **删除记录仍未联动删除音频**（T034 任务）。
- **历史真实回放仍未实现**（必须等 T032 schema 迁移 + `audioFilePath` 写入 + 真实文件存在性校验）。
- **T032+ 待 GPT 首席架构师下发独立 Prompt**（Drift schema 迁移 / UI 文案 / 真机验收 / 隐私政策更新 / Release 文档收口 等）。

## T035A 状态备注（详情页播放生命周期与旧事件隔离修复闭环）

- **T035A 已完成**（基于 T035 既有 610 tests 基线 + 7 新增 controller 测试 = 617 tests passed；既有测试 0 减少）。核心修复：① `_onDispose` 新增 best-effort fire-and-forget `service.stop()`（mirror-guarded：`playing | paused | loading | ready` 才 stop；`idle | error` 跳过；`.catchError` 吞错 + sentinel `AudioPlaybackStopResult` return type）；② 跨会话 completed 隔离通过 `_playbackSessionId` 单调计数器 + listener 闭包在订阅时一次性捕获 `subscriptionSessionId` 实现 —— 在 `playRecordedAudio` / `stopPlayback` / `_stopPlaybackIfActive` 三个 session 边界 bump；③ `_lastPublishedPlaybackStatus` mirror + `_cachedPlaybackService` 引用绕过 Riverpod 3.x `onDispose` 的 `_throwIfInvalidUsage` 约束（"Cannot use Ref or modify other providers inside life-cycles/selectors"）；④ 18 处 `state = AsyncData<...>(...)` 统一走 `_publish(...)` chokepoint 保证 mirror 同步；⑤ T035 既有契约（pre-delete stop / cleanup warning / shared-path 保护 / 不调 `service.dispose`）100% 保留（21+17=38 项既有 controller 测试全部 pass）。
- **共享 service 所有权保持**：`realAudioPlaybackServiceProvider` 是非 autoDispose 单 Provider，T035A **不**在 `_onDispose` 调 `service.dispose()`（与 T031 录音 controller 同契约）。
- **T035A 关闭的潜在 bug**：T035 既有实现下，stop → replay 序列中 A session 的延迟 `completed` 事件会通过 `_onPlayerState` 回调错误地把 B session 的状态从 `playing` 翻为 `idle`（即使加上 `_handlingNaturalCompletion` 守卫也无效，因为该守卫只对**同步重复**事件起作用，对**跨会话异步延迟**事件失效）；T035A 通过 `_playbackSessionId` 闭包捕获解决。
- **未**修改生产代码（除允许范围内 1 个 lib 文件）/ 测试代码（除允许范围内 1 个 test 文件增强）/ 文档（本 TECH_DEBT 条目 + TASK_LEDGER + AGENT_QUALITY_METRICS）/ 依赖 / Android 配置 / Drift schema / `PracticeRecord` 域模型 / Repository / DAO / `audioFilePath` 字段 / `RealAudioRecorderService` / `RealAudioPlaybackService` 公共契约（既有契约已足够）/ `AudioFileStorageService` / `RecordingController` / `RecordingPage` / Manifest / 隐私政策 / `tool/verify_release_artifacts.dart` / `key.properties` / `.gitignore` / 构建产物。
- **T036 仍待启动**：由 GPT 首席架构师独立 Prompt 启动。

## T035B 状态备注（详情页播放 session 事件路由双向验证闭环）

- **T035B 已完成**（基于 T035A 既有 617 tests 基线 + 2 净增 controller 测试 = 619 tests passed；既有测试 0 减少）。Chief Architect re-audit 指出 T035A 的"延迟事件测试"是 **false positive** —— 仅证明 negative case（"A 的 stale completed 不影响 B"），未证明 positive case（"B 的 own `completed` 必须被处理"）。T035A 实现里 listener 闭包绑定 A 的 token 后**从未重建订阅**，导致 B 的 own `completed` 也被 session-id 校验错误拒绝 → B 永远不能自然完成（这是 T035A 的真 bug，被 T035B 修复）。
- **核心修复**：① `_ensurePlaybackSubscription` 改为 **cancel-and-rebuild** 语义 —— 移除原 `if (_playbackStateSubscription != null) return;` guard，改为无条件 `previous?.cancel()`（fire-and-forget）+ 重新 `listen`；让 A 的 listener 离开 broadcast listener group，让 B 的新 listener 是**唯一** active listener，listener 闭包捕获 B 的 token；② session-id 校验在 `_onPlayerState` 保留作为 **defense-in-depth**（cancel future 是 unawaited by design，理论上 A 的 in-flight callback 可能仍 fire 一次，session-id 校验在 `_onPlayerState` 短路这些 in-flight callback）；③ 文件头注释新增 `// T035B — cancel-and-rebuild subscription seam:` 章节解释为什么 T035A 设计的"keep A's listener alive with A's token"是错的，以及 cancel-and-rebuild 为什么是正确 seam。
- **测试变更**：① 替换原 T035A "A 的 late completed 不污染 B"测试为 3 项 T035B dual-direction 测试 + 1 项 rationale 测试（**净 +2 项**）：① **session B 有独立新订阅**：用 `playerStateListenerInstallCount` 断言 A→stop→B 序列的安装次数增长 = 1（cancel-and-rebuild 发生；T035A 会是 0）；② **B 的 own `completed` 翻 B → idle**（T035A 设计的 false positive 暴露：B 的 own `completed` 被 listener 闭包的 A token 错误拒绝 → B 永远 playing）；③ **T035B 设计原理说明**（broadcast stream 不携带 session id，controller 不试图过滤 stale A events，real gateway 不发 stale A events）；② 6 项 T035A 既有 controller 测试 100% 保留（dispose-time stop / dispose 后 event 不抛错 / 5 次连续 completed 幂等 / paused 链完整 / stop 抛错吞错 / idle 无 stop）；③ 21 项 T035 既有 controller 测试 100% 保留；④ 17 项 T034 既有 controller 测试 100% 保留；⑤ 38 项 T013.4C + T034 既有 widget 测试 100% 保留；⑥ 6 项 T035 widget 测试 100% 保留。
- **Fake 增强**：`test/shared/services/fake_audio_playback_gateway.dart` 新增 ① `playerStateListenerInstallCount`（int 累计）+ ② `playerStateActiveListenerCount`（int 当前活跃）+ ③ `_PlayerStateListenerCounters` 静态 helper（`onListenCallback` / `onCancelCallback` 通过 `_activeFake` 静态指针桥接到当前 fake 实例 —— production 测试一个 fake per test，单槽足够）；`playerStateStream` getter 改为 `_playerStateController.stream.asBroadcastStream(onListen: ..., onCancel: ...)` —— 关键技巧：`asBroadcastStream` 的 onListen/onCancel **每次** listen/cancel 都触发（不同于 `StreamController.broadcast` 构造函数的 onListen 只在 0→1 转换时触发）。
- **7 项必答审计全部通过**：① Q1 yes（B 时 rebuild）；② Q2 B 的 token（订阅时一次性捕获）；③ Q3 通过 A 旧订阅（已 cancel） → 不进入 controller；④ Q4 B 的 own `playing/paused` 通过 controller 同步方法；`completed` 通过 B 新订阅 listener 闭包进入 controller（session-id 匹配 → 翻 `idle`）；⑤ Q5 Dart 的 `StreamController.broadcast` **不携带 session id** 且**不缓冲已发送事件** —— controller **无法**在 stream 层区分"A 的 stale event"和"B 的 fresh event"；⑥ Q6 该区分**不**依赖生产 service 真实保证（生产 gateway 不会在 B 开始后再发 A 的 `completed`），controller 也**不**试图做这个区分；cancel-and-rebuild 的实质是**让 A 的 listener 离开 listener group**，而不是用 session-id 过滤；⑦ Q7 取消旧订阅后已经排队的 callback 由 session-id 校验拒绝（即使有 A 的 callback 在 cancel 之前已被 microtask 调度，listener 闭包仍持有 A 的 token，与 B 的 `_playbackSessionId` 不匹配 → 短路 return）。
- **T034 / T035 / T035A 回归要求 100% 保留**：verbatim 路径 / 删除前 stop / stop 失败拒绝删除 / DB 成功后才清文件 / shared-path 保护 / successWithCleanupWarning / `AudioFileStorageService` 唯一磁盘入口 / Repository 不碰磁盘 / 自然完成幂等 / 错误文案不泄露绝对路径。
- **未**修改生产代码（除允许范围内 1 个 lib 文件）/ 测试代码（除允许范围内 2 个 test 文件：1 controller + 1 fake helper）/ 文档（本 TECH_DEBT 条目 + TASK_LEDGER + AGENT_QUALITY_METRICS）/ 依赖 / Android 配置 / Drift schema / `PracticeRecord` 域模型 / Repository / DAO / `audioFilePath` 字段 / `RealAudioRecorderService` / `RealAudioPlaybackService` 公共契约（既有契约已足够，cancel-and-rebuild 完全在 controller 边界内）/ `AudioFileStorageService` / `RecordingController` / `RecordingPage` / Manifest / 隐私政策 / `tool/verify_release_artifacts.dart` / `key.properties` / `.gitignore` / 构建产物。
- **T036 仍待启动**：由 GPT 首席架构师独立 Prompt 启动。

## T036 状态备注（真实音频端到端闭环集成测试闭环）

- **T036 已完成**（基于 T035B 既有 619 tests passed 基线 + 4 新增集成测试 = 623 tests passed；既有测试 0 减少；连跑 3 次稳定）。T036 是 GPT 首席架构师下发的最终跨层集成测试任务，**首次**用单一 testWidgets 串联 T031 → T035B 6 个子系统（真实录音 / 录音页保存 / 列表 / 详情 / 播放 / 删除 + 清理）形成完整闭环验证。
- **核心交付**：`test/integration/real_audio_end_to_end_test.dart`（**新建**，单文件约 1000 行，**唯一**新增测试文件）：4 个 `testWidgets` 块（1 main loop + 3 additional scenarios），所有断言都通过用户可见页面 + 真实 Provider 装配驱动，**不**直接调 controller / repository。
- **主闭环 25 步**：录 → 停止 → 占位文件 → 自评 + 备注 → 保存 → list 显示 → 详情 → 播放（verbatim 路径 + loadFile 计数基线+1）→ 暂停 → 继续 → 停止（基线+1）→ 再播放 → emit completed（不额外 stop）→ 详情页自然完成（playerStateListenerInstallCount 增长 ≥ 3 验证 T035B cancel-and-rebuild）→ 再次播放 → 删除（stopsBaseBeforeUserTap 之后 stopCallCount 又增长 ≥ 1）→ DB getById null → 文件不存在 → list 回空。
- **3 个附加场景**：① **Shared path 保护** —— 两条记录同 verbatim 路径，删 A 时文件保留，删 B 时文件清理（端到端验证 T034 的 `hasAudioPathReference` 引用计数保护）；② **Cleanup warning** —— outside-root file + DB 删除成功 + warning SnackBar（无 success snackbar）+ DB 不回滚（端到端验证 T034 successWithCleanupWarning 路径）；③ **Pre-delete stop 失败** —— `nextStopExceptionOnce` 注入 + delete 拒绝 + DB 保留 + 文件保留 + 失败 SnackBar 不含路径/异常（端到端验证 T035 的 `_stopPlaybackIfActive` 拒绝路径）。
- **核心断言契约**（每条都通过三事实链 / 真实磁盘 / T035B 计数器交叉证明）：① **verbatim path** —— `saved.audioFilePath == recordedPath`（字符串 ==）+ `lastLoadPath == saved.audioFilePath`；② **pre-delete stop 顺序** —— controller 源码契约 + `stopCallCount` 基线 + DB `getById == null` 三事实链证明（**不**引入跨服务 event log spy 避免 production-instrumentation 钩子）；③ **文件清理** —— 真实 `File(...).existsSync() == false` 磁盘断言（**不**用 mock 计数）；④ **listener 区分** —— T035B `playerStateListenerInstallCount` 增长 ≥ 3 跨 3 次 play；⑤ **T035 natural completion** 不调 `playback.stop` —— `stopCallCount` 等于 `stopsBaseBeforeUserTap + 1`。
- **Provider 装配**：8 个边界 override（`appDatabaseProvider` → in-memory `NativeDatabase.memory()`；`appClockProvider` → pinned clock；`installDateServiceProvider` → `DriftInstallDateService`；`practiceRecordIdGeneratorProvider` → **真实 UUID** `UuidPracticeRecordIdGenerator`；`audioFileStorageServiceProvider` → temp-rooted `AudioFileStorageService`；`realAudioRecorderServiceProvider` → `RealAudioRecorderService(fakeRecorder, storage)`；`realAudioPlaybackServiceProvider` → `RealAudioPlaybackService(fakePlayback, storage)` + `keepPlayPending = true`；`microphonePermissionServiceProvider` → `MicrophonePermissionService(fakePermission)`），其它 Provider 全部走生产默认（`practiceRecordRepositoryProvider` / `practiceRecordsListControllerProvider` / `practiceRecordDetailControllerProvider` / `recordingPracticeControllerProvider` / `practiceDayResolverProvider` / `appRouter`）。
- **fake 边界**（仅硬件层）：`FakeAudioRecorderGateway`（recorder 平台通道）/ `FakeAudioPlaybackGateway`（playback 平台通道 + T035B listener install count）/ `FakeMicrophonePermissionGateway`（permission_handler 平台通道）/ 受控临时音频根目录（替代 `path_provider.getApplicationDocumentsDirectory()`）。**不**mock 业务逻辑。
- **Self-Critique 8 项修复**：① 初版 fake dispose 时序错 → 改在 widget tree teardown 之前调 fake dispose；② 初版 `pageBack()` 抛 Bad state → 改 `find.byTooltip('Back').tap(warnIfMissed: false)` + list page 守卫；③ 初版 step 10/15/18 `loadFileCallCount == N` 绝对值失败 → 改基线模式（recording controller `_probeRecordingDuration` 已调过 playback.loadFile 一次）；④ 初版 step 14/17/19 `stopCallCount == N` 绝对值失败 → 改基线模式（`RealAudioPlaybackService.loadFile` 内部 `_stopInternal` 已触发 stop）；⑤ 初版 `pumpAndSettle` 在 delete 后 hang → 改显式 `for (i < 20) pump(100ms);` + `runAsync delay(50ms)` 收尾；⑥ 初版 Shared path 第二次删除抛 `UnmountedRefException`（line 863 `state.value` 在 controller dispose 后）→ 增大 30*100ms pumps + runAsync delay 100ms 让 line 863 完成；⑦ 初版 stop failure 测试通过 UI 录音页让 test 时长爆增且 home page ListView 渲染时序不稳 → 改直接 `repository.insert` 占位 .m4a 文件；⑧ 初版 `dart format` 触发 `unused_import 'dart:async'` → 删除。
- **测试稳定** —— 连跑 3 次全部 `+4: All tests passed!`；`flutter test` 全量 `00:21 +623: All tests passed!`；既有测试 0 减少。
- **Reviewers Approved**（read-only）：Flutter Architect Reviewer（dispose 路径 / 跨会话 listener 区分 / shared service 所有权 / 跨会话 completed 路由 / 基线计数 / 显式 pump 替代 pumpAndSettle / `_tapHomeTile` 兼容 ListView / stop failure 用 `repository.insert` 替代 UI 录音 8 项建议 全部采纳）；Local Data Engineer Reviewer（verbatim 路径 / schemaVersion 未改 / `app_database.g.dart` 未重生成 / `DriftPracticeRecordRepository.delete` / `_cleanupAudioFileIfOrphaned` / `hasAudioPathReference` 多记录引用 / T034 shared-path 保护 端到端不退化 ✓）；QA Reviewer（5 项建议：verbatim 路径断言 / 顺序证明 / 文件清理 / listener 区分 / natural completion 不调 stop 全部采纳）；Compliance Reviewer（仅修改 1 个允许 test 文件 + 3 个允许 doc 文件；AndroidManifest / `pubspec.yaml` / `pubspec.lock` / Drift schema / `app_database.g.dart` / `PracticeRecord` 域模型 / Recorder / Playback / Storage / Recording / Detail controller / 详情页 UI / 录音页 UI / Manifest INTERNET 权限 / 敏感文件 / build 产物 全部**未**修改 ✓）。
- **未**修改生产代码 / 测试代码（除本任务唯一新增 test 文件）/ 文档（本 TECH_DEBT 条目 + TASK_LEDGER + AGENT_QUALITY_METRICS）/ 依赖 / Android 配置 / Drift schema / `PracticeRecord` 域模型 / Repository / DAO / `audioFilePath` 字段 / `RealAudioRecorderService` / `RealAudioPlaybackService`（既有契约已足够，无修改）/ `AudioFileStorageService` / `RecordingController` / `RecordingPage` / 详情页 UI / 录音页 UI / Manifest / 隐私政策 / `tool/verify_release_artifacts.dart` / `key.properties` / `.gitignore` / 构建产物。
- **未**实现真实麦克风调用 / **未**实现后台播放 / **未**实现波形 / **未**实现拖动进度 / **未**实现倍速 / **未**实现循环播放 / **未**实现剪辑 / **未**新增第二套播放服务 / **未**修改现有 fake gateway / **未**修改现有 controller / **未**修改现有 service / **未**调用底层 gateway 直连 / **未**申请 INTERNET / **未**修改 Manifest / **未**读取敏感文件。
- **T037 仍待启动** —— `T037_REAL_AUDIO_ANDROID_DEVICE_ACCEPTANCE`（真机验收），由 GPT 首席架构师独立 Prompt 启动。T036 自动测试是闭环的**最后一道自动化验证**，但**不替代**真机用户验收（详见 `docs/REAL_AUDIO_DEPENDENCY_SPIKE.md` §3.6 + `docs/dev/TECH_DEBT.md` TD-013：真机国产 ROM 兼容性 HUAWEI / 小米 / OPPO / vivo 未在 Spike 阶段验证，必须由 T037 真机用户验收最终确认）。

## T036A 状态备注（pre-delete stop < repository delete 顺序的共享事件日志证据闭环）

- **T036A 已完成**（基于 T036 既有 623 tests 基线；测试数恒等 —— T036A **不**新增 / 删除 testWidgets 块；既有测试 0 减少；连跑 3 次稳定）。核心修复：**T036 既有 pre-delete stop 顺序断言用"controller 源码契约 + stopCallCount 增长 + DB getById null"三事实链证明** —— 这只能证明 stop 与 delete 都发生 + 生产源码当前顺序正确，**不能**证伪"未来 regression 把顺序翻过来"仍能让测试通过（如源码把 `repository.delete` 改到 `playback.stop` 之前，stopCallCount 仍会增长、DB 仍 getById null、T036 仍会通过）。
- **T036A 证据缺口修复**：两个测试专用 spy + 共享事件日志 + 基线切片 + 严格顺序断言。
  - **`_PlaybackStopSpyGateway implements AudioPlaybackGateway`**：包装既有 `FakeAudioPlaybackGateway`（**不**改 fake helper 文件）；唯一特殊方法是 `stop()` —— `recorder.events.add(const _PlaybackStopEvent()); return fake.stop();`；其它方法（loadFile / play / pause / seek / setLoopModeOff / dispose / stream getter / 同步 getter）全部 `=> fake.X()` 委托；既有 fake 字段访问（`env.playbackGateway.stopCallCount` / `loadFileCallCount` / `lastLoadPath` / `playerStateListenerInstallCount`）继续工作；T031E 双重防御（service 内部 setLoopModeOff + fake loadFile 内部 setLoopModeOff）保持。
  - **`_RepositoryEventSpy implements PracticeRecordRepository`**：装饰**真实** `DriftPracticeRecordRepository`（**不**mock）；唯一特殊方法是 `delete(id)` —— `recorder.events.add(_RepositoryDeleteEvent(id)); return delegate.delete(id);`；insert / getById / listRecent / watchAll / hasAudioPathReference 全部 `=> delegate.X()` 委托；DB 真删、watchAll 仍 emit、SQL 仍 hit。
  - **`_EventRecorder`** 共享事件日志（`List<_TestEvent>` + `add()` + `indexWhere()`），由两个 spy 共享同一实例；`sealed _TestEvent` + `_PlaybackStopEvent` + `_RepositoryDeleteEvent` 不可变事件对象（比 string 可靠 + 编译期穷尽匹配）。
  - **基线切片**：tap delete 之前快照 `eventBaselineBeforeDelete = eventRecorder.events.length`；删完后取 `deleteSlice = events.sublist(eventBaselineBeforeDelete)`；排除录音阶段的早期 stop（`_probeRecordingDuration` 内部 stop / loadFile-driven stop / 用户 step 14 stop / 自然完成 stop-less）污染。
  - **严格顺序断言**：`playbackStopIndexInSlice < repositoryDeleteIndexInSlice` + 切片非空防御性 `fail` + `repositoryDeleteEvent.id == saved.id` 严格 id 匹配。
- **Failure sensitivity**（negative-case 可证伪）：如生产源码把 `repository.delete` 改到 `playback.stop` 之前，spy 在 delete 入口**先**记录 → `repositoryDelete` 索引早于 `playbackStop`；断言 `playbackStopIndex < repositoryDeleteIndex` 立即失败，失败消息含 `slice: [repository.delete(<id>), playback.stop]` 完整序列 —— 提供**明确**的"顺序翻转"证据而非 T036 旧版的"事后证据"。
- **测试数恒等**：T036A **不**新增 / 删除 testWidgets 块；4 个 testWidgets = T036 既有（1 main closed loop + 1 shared-path + 1 cleanup-warning + 1 pre-delete stop failure）；既有测试 0 减少；623 → 623（连跑 3 次稳定）；`flutter test` 全量 `00:20 +623: All tests passed!`。
- **3 个 additional scenario 不走 spy**：shared-path / cleanup-warning / pre-delete stop failure 这 3 个 testWidgets 各自的契约与 spy 无关；`_pumpApp` 扩展 `playbackServiceOverride` + `repositoryOverride` 是 optional 参数；只有主闭环测试传 spy 包装实例；3 个 additional 仍走 T036 既有 8 个 Provider override（无 spy）。
- **Reviewers Approved**（read-only）：Flutter Architect Reviewer（spy 包装位置正确 —— fake gateway 测试硬件边界 + real Drift repository 测试数据边界；production service / controller / fake helper 文件**未**修改；`_pumpApp` 扩展 `playbackServiceOverride` + `repositoryOverride` 是最小签名扩展；既有 8 个 Provider override 全部保留 ✓）；Local Data Engineer Reviewer（`_RepositoryEventSpy` 仍委托真实 `DriftPracticeRecordRepository` 而**非** mock —— DB row 真删、watchAll 仍 emit、`hasAudioPathReference` 仍 hit SQL；事件记录 `add(_RepositoryDeleteEvent(id))` 同步发生在 `delegate.delete(id)` 之前；schemaVersion = 2 / `app_database.g.dart` **未**改 ✓）；QA Reviewer（4 项建议：sealed `_TestEvent` 不可变事件对象 / 共享 `_EventRecorder` 单例 / 基线切片 / `repositoryDeleteEvent.id == saved.id` 严格相等断言 全部采纳 ✓）；Compliance Reviewer（仅修改 1 个允许 test 文件 + 3 个允许 doc 文件；AndroidManifest / `pubspec.yaml` / `pubspec.lock` / Drift schema / `app_database.g.dart` / `PracticeRecord` 域模型 / Recorder / Playback / Storage / Recording / Detail controller / 详情页 UI / 录音页 UI / Manifest INTERNET 权限 / 敏感文件 / build 产物 全部**未**修改；spy 包装**仅**在测试边界；无 production-instrumentation 钩子；5 允许文件 scope 守住 ✓）。
- **未**修改生产代码 / 测试代码（除允许范围内 1 个 test 文件） / 文档（本 TECH_DEBT 条目 + TASK_LEDGER + AGENT_QUALITY_METRICS）/ 依赖 / Android 配置 / Drift schema / `PracticeRecord` 域模型 / Repository / DAO / `audioFilePath` 字段 / `RealAudioRecorderService` / `RealAudioPlaybackService`（既有契约已足够，无修改）/ `AudioFileStorageService` / `RecordingController` / `RecordingPage` / 详情页 UI / 录音页 UI / Manifest / 隐私政策 / `tool/verify_release_artifacts.dart` / `key.properties` / `.gitignore` / 构建产物 / 既有 fake helper 文件。
- **未**实现真实麦克风调用 / **未**实现后台播放 / **未**实现波形 / **未**实现拖动进度 / **未**实现倍速 / **未**实现循环播放 / **未**实现剪辑 / **未**新增第二套播放服务 / **未**修改现有 fake gateway / **未**修改现有 controller / **未**修改现有 service / **未**调用底层 gateway 直连 / **未**申请 INTERNET / **未**修改 Manifest / **未**读取敏感文件。
- **T037 仍待启动** —— `T037_REAL_AUDIO_ANDROID_DEVICE_ACCEPTANCE`（真机验收），由 GPT 首席架构师独立 Prompt 启动。T036 + T036A 自动化证据闭环完成，但**不替代**真机用户验收。

---

## TD-014: T037A 详情页退出播放停止（fire-and-forget 竞争）— 闭环说明

**问题**：T037 真机验收发现 — 打开已保存录音的练习记录详情 → 点击播放 → 真实声音正常 → 点击页面顶部 AppBar 返回箭头 → 页面成功返回列表，但**声音继续播放**。其他行为（播放/暂停/继续/停止 / 删除 / 强行停止后重启）均正常，无崩溃或错误提示。

**根因（最关键审计结论）**：`RealAudioPlaybackService.stop()` 是异步 future 调用，T035A 既有的 dispose-time stop 是 `cachedService.stop().catchError(...)` fire-and-forget；Flutter 3.44 + Riverpod 3.x 的 autoDispose 在 pop 时同步触发 `_onDispose`，但 native `just_audio` 的 platform-channel stop 在真机上需要数毫秒到数十毫秒才真正让音频解码器静音。go_router 的 route pop 动画与 fire-and-forget stop **并发执行** —— Navigator 已弹出页面，但 stop future 仍在 in-flight，结果是用户在列表页仍听到声音继续播放。

**解决（closed）**：`T037A_FIX_DETAIL_BACK_NAVIGATION_PLAYBACK_STOP` —— ① controller 暴露 `Future<PageExitStopResult> requestStopForPageExit()` awaitable 接口（skip / success / failure 三态 sealed class）；② Page 层新增 `_handleExit()` 单点 chokepoint 把 AppBar 返回箭头 + PopScope.onPopInvokedWithResult 都汇入 `_await controller.requestStopForPageExit() → success→pop / failure→SnackBar+保留页面` 单一路径；③ `_exitInFlight: bool` 串行守卫防止 AppBar 重复点击 / AppBar + 系统返回并发；④ PopScope 包装 Scaffold 让 Android 系统返回走相同 chokepoint；⑤ T035A dispose-time stop 保留作为 non-cooperative safety net；⑥ `service.dispose()` **不**调用（共享 service 由 Riverpod scope teardown）。

**回归证据**：净增 15 项测试（8 controller + 7 widget）。`stopGate` 机制直接证明 `requestStopForPageExit` future 在 service.stop 解析前**真的 pending** —— 这正是真机 fix 的核心断言（fire-and-forget 设计下 future 立即 resolved；awaitable 设计下 future 必须等待 service.stop）；T035B 跨会话回归显式 pin（A play → A page-exit stop → B play → B emit completed → B 翻 idle）；既有 623 测试零回归。

**未**修改生产代码（除允许范围内 2 个 lib 文件）/ 测试代码（除允许范围内 3 个 test 文件：1 controller + 1 widget + 1 fake helper）/ Manifest / schema / 依赖 / 共享 service 所有权契约。

**T037 仍待用户真机验收** —— 由 `T037_REAL_AUDIO_ANDROID_DEVICE_ACCEPTANCE_RESUME` 接力，需用户在真机上**手动重放 T037 验收场景**确认声音在返回时立刻停止；自动化测试覆盖已就位（638 tests passed），但真机 audio stop 时序受 native `just_audio` 实现影响，最终用户体验仍需用户真机验证。

---

## TD-015: T037B 录音页退出活动音频停止（4 状态决策 + 录音/播放失败文案严格分离）— 闭环说明

**问题**：T037 真机验收发现 — 进入"录音回放" → 完成一次录音 → 开始回放 → 点击 AppBar 返回箭头 → 页面返回首页但**声音继续播放**（缺陷一）；进入"录音回放" → 开始录音 → 录音中点击 AppBar 返回箭头 → 页面返回首页但**录音仍在进行** → 再次进入页面时计时仍持续累计，录音仍未停止（缺陷二）。T037A 修复的是 `PracticeRecordDetailPage`（详情页），**不**是 `RecordingPage`（录音页），**不**回滚 T037A。

**根因**：`RecordingPage` 是 `ConsumerWidget`（[recording_page.dart:31](lib/features/recording/presentation/recording_page.dart#L31)），**没有 PopScope 包装**；AppBar 没有自定义 `leading`，依赖默认返回箭头（默认 `Navigator.maybePop`）；`recordingPracticeControllerProvider` 是 `NotifierProvider`（**非 autoDispose** —— [recording_practice_controller.dart:1232-1236](lib/features/recording/application/recording_practice_controller.dart#L1232-L1236)），pop 后 provider **仍然存活**；`_onDispose` 内部虽然 stop ticker + 取消 subscriptions，但 stop future **不** await（fire-and-forget），route pop 与 stop future 并发，stop future 解析时 page 已被 dispose，无法驱动 UI 状态变更；**录音 service 的 `dispose()` 不会自动调**（既有 `_onDispose` 0 改动），但**平台 stop 必须 await**才能让 native 麦克风/播放器真的停下来。录音页有 **4 个活动状态**需在退出时正确收尾：① `isRecording == true` → 必须 `await _recorder.stop()`，计时必须停；② `isPlaying == true` → 必须 `await _playback.stop()`；③ `isPlaying == false && takeId != null`（`paused` / `ready` / `loading` 状态）→ 释放底层 player 句柄；④ `idle` → 不需要 stop。

**解决（closed）**：`T037B_FIX_RECORDING_PAGE_EXIT_ACTIVE_AUDIO` —— ① 新建独立 sealed class `PageExitStopResult` 在 [recording_page_exit_stop_result.dart](lib/features/recording/application/recording_page_exit_stop_result.dart)（**不**复用 detail controller 的同名 sealed，避免耦合；**录音 / 播放失败 message 严格分离**：`停止录音失败，请重试` vs `停止播放失败，请重试`）；② controller 新增公开方法 `Future<PageExitStopResult> requestStopForPageExit()` —— 同步 await `recorder.stop()` / `playback.stop()`，4 状态决策表 + 4 skip reasons（`disposed` / `noState` / `idle` / `serviceAlreadyTerminal`）+ 录音/播放失败分两个 message；`isRecording` / `isPlaying` 在 await 之前**同步翻 false**（防止 duplicate back 第二调用走 `InvalidRecorderStateException` / `InvalidPlaybackStateException`）；③ Page 层 `RecordingPage` 从 `ConsumerWidget` 改为 `ConsumerStatefulWidget` + `PopScope` 包装 Scaffold + `canPop: !_exitInFlight && !_hasActiveSession()`（`_hasActiveSession` 覆盖 4 状态）；`onPopInvokedWithResult` 驱动 `_handleExit`；`_exitInFlight: bool` 串行守卫；④ AppBar 自定义 `leading: BackButton(onPressed: _handleExit)` —— 用 stock `BackButton` widget（**不**用 `IconButton`）保留 Flutter 内置的"back button"类型识别（widget testing `tester.pageBack()` helper 仍能识别 + T036 集成测试 `await tester.pageBack()` 不被破坏）；⑤ stop 成功后 `_popOrGoHome(context)` 真正导航；stop 失败时**保留页面** + 录音 SnackBar `key='recording-page-exit-stop-recording-failure-snackbar'` + 内容"停止录音失败，请重试" / 播放 SnackBar `key='recording-page-exit-stop-playback-failure-snackbar'` + 内容"停止播放失败，请重试"；⑥ T035A dispose-time stop **保留**作为 non-cooperative safety net —— widget tree 强制 drop / parent route 替换 / 测试绕开 page 时仍 best-effort cancel subscriptions + stop ticker；dispose **不**调用 `service.dispose()`（共享 service 由 Riverpod scope teardown）。

**未保存 take 文件安全**：① 录音后未回放直接退出 — `requestStopForPageExit` 在 `isPlaying == false` 但 `takeId != null` 分支调 `playback.stop()` 释放句柄，**不删除文件**（文件在 temp 目录），takeId 保留，下次进入页面仍可保存；② 录音中退出 — `recorder.stop()` 成功，take 文件在 temp 目录 + `recordedTakeResult` 持有 resolvedPath + takeId 保留，下次进入仍可看到；③ 回放中退出 — `playback.stop()` await 解析后 pop，recordedTakeResult 不变、hasRecording 不变。**不**调 `recorder.cancel()`（cancel 会清文件破坏未保存 take）；删除只能通过 `AudioFileStorageService` + 已 save 的 `PracticeRecord` 删除流程（详情页 T034 路径）。

**回归证据**：净增 17 项测试（8 controller + 8 widget + 1 helper count）。`stopGate` 机制直接证明 `requestStopForPageExit` future 在 `recorder.stop` 解析前**真的 pending** —— 这正是真机 fix 的核心断言（fire-and-forget 设计下 future 立即 resolved；awaitable 设计下 future 必须等待 recorder.stop）；duplicate back 测试 pin 严格 1 次 `recorder.stop` 调用（录音 / 播放分支 await 之前同步翻 state false 防御 duplicate back）；录音 / 播放失败路径独立 SnackBar key + 4 项 PII pin（`synthetic` / `Exception` / `.m4a` / 路径 全部 `findsNothing`）；既有 639 测试零回归。

**未**修改生产代码（除允许范围内 2 个 lib 修改 + 1 个 lib 新建）/ 测试代码（除允许范围内 3 个 test 文件：1 controller + 1 widget + 1 fake helper）/ Manifest / schema / 依赖 / 共享 service 所有权契约 / 详情页 T037A / T037A1 0 改动 / 录音页既有 `recording_practice_controller.dart:801` state.error `'停止播放失败：$e'` 排障流**未**触碰。

**T037 仍待用户真机验收** —— 由 `T037_REAL_AUDIO_ANDROID_DEVICE_ACCEPTANCE_RESUME_2` 接力，需用户在真机上**手动重放 T037 验收场景**确认录音 / 播放声音在返回时立刻停止；自动化测试覆盖已就位（656 tests passed），但真机 audio stop 时序受 native `record` / `just_audio` 实现影响，最终用户体验仍需用户真机验证。

## TD-016: T037B1 录音页退出 stop 失败后重试语义（in-flight Future 协调 + 录音/播放独立重试 + service-already-terminal 兜底）— 闭环说明

**问题**：T037B 修复解决了录音页退出时 stop 不被等待、native 录音/播放继续运行的问题，但**未**解决"stop 失败后第二次退出真正重试"的问题。**场景**：① 录音中退出 → 第一次 `recorder.stop` throws → 页面保留 + SnackBar 显示 → 第二次退出**不会**再次调用 `recorder.stop()`（T037B 第一次 await 之前 flip `isRecording=false` 后第二次 observe idle，跳过 recording 分支）→ native 录音可能仍运行（service 抛错时 service 内部已清 active session，service state 是 idle，但 controller 状态机报告 idle 与 service 状态不冲突的边界未被 pin）；② 播放中退出 → 第一次 `playback.stop` throws → 第二次退出**确实**会调 `playback.stop()`（service state 在 failure 后恢复 previousState），但**未**保证 ticker 在 recording 失败后保持与真实录音状态一致。

**根因**：T037B 既有 `_performPageExitStop` 在 `await recorder.stop()` / `await playback.stop()` **之前**同步 flip `isRecording=false` / `isPlaying=false`，目的是防止 duplicate back 第二次 observe 仍然 active → 调第二次 stop → service 抛 `InvalidRecorderStateException` / `InvalidPlaybackStateException`。但这一设计在 stop 失败场景下反而让第二次退出**不能**再进入正确分支：录音失败后第二次 observe `isRecording=false && takeId != null` 进入 playback 分支（**不**调 recorder.stop）；播放失败后第二次 observe `isPlaying=false && takeId != null` 走 playback 分支，理论能 retry 但**未**严格保证 takeId 已被保留。

**解决（closed）**：`T037B1_FIX_RECORDING_EXIT_STOP_FAILURE_RETRY` —— ① **In-flight Future 协调**：controller 私有字段 `Future<PageExitStopResult>? _pageExitStopFuture`；`requestStopForPageExit` 是**纯协调 wrapper** —— 检查 existingFuture → 复用同一 Future；否则创建新 `Completer` + install `Future` + `try { _performPageExitStop } finally { _pageExitStopFuture = null }`；② 内部 worker `_performPageExitStop` 接管既有决策表；③ **录音分支不再提前 flip `isRecording=false`** —— 保持 recording → 第二次退出 re-enter recording 分支；录音失败时 controller **仍然 flip `isRecording=false`**（与 `RealAudioRecorderService.stop` 抛错时的 `_state = idle` 同步 —— service 是 source of truth）；④ ticker 在录音 stop 失败时**不**重启（service 说 idle，ticker 重启会创建重复 Timer）；⑤ **播放分支不再提前 flip `isPlaying=false`** —— 保持 playing → 第二次退出 re-enter playback 分支 → service state 已恢复到 previousState（`RealAudioPlaybackService._stopInternal` 抛错时 `_state = previousState`）→ 真正调第二次 `playback.stop()`；⑥ 播放失败时**保留 `isPlaying=true`**（让 retry 走对分支）；⑦ file 头注释 + doc comment 升级为 T037B + T037B1，新增 `T037B1 — failure-retry contract:` 章节。

**Service 契约诚实记录**：① **recording service 抛错时是否真的 stop 了 native 录音仍是真机层面的"黑盒"** —— `RealAudioRecorderService.stop` catch 块同步设置 `_state = idle` + `_clearActiveSession()`，但**不**保证 native `record` package 真的停止了 native 录音；这是 service-layer 限制，controller 只能 surface honest SnackBar + 保留 takeId（即"录音所有权"状态）让用户能 retry；② **playback service 抛错时是否真的 stop 了 native 播放** —— `RealAudioPlaybackService._stopInternal` catch 块 `_state = previousState`（恢复到 stop 前的状态），service 状态正确（playing 仍可被 retry 调 stop）；但**不**保证 native `just_audio` player 真的释放了；这是 service-layer 限制，controller 同样只能 surface honest SnackBar + 保留 isPlaying 状态让用户能 retry。

**未保存 take 文件安全契约**（保持 T037B 既有契约）：① 录音中退出第一次失败 → service idle + takeId != null + 第二次 retry → `skipped(serviceAlreadyTerminal)` 走 page pop 路径 → 用户能再次进入页面看到 takeId；② 录音后未回放直接退出 → takeId != null + isPlaying == false → 仍调 `playback.stop()` 释放 player 句柄，**不**调 `recorder.cancel()`（cancel 会清文件破坏未保存 take）。**未保存 take 在进程存活期间保留** —— `recordingPracticeControllerProvider` 是 `NotifierProvider`（**非 autoDispose**），跨 route pop 状态保留，下次进入页面用户能继续 save 或 start new take。**App 进程被系统终止后的临时文件回收** —— 当前**未**实现启动清理机制（`AudioFileStorageService` 不在启动时扫描 `temp/` 目录），孤儿 temp 文件可能持续累积；这是后续技术债，**不**在本任务越界实现。**`recorder.cancel()` 与 `recorder.stop()` 的语义差异** —— `cancel()` 会 best-effort 清理 temp 文件（破坏未保存 take），`stop()` 只 stop 录音但**不**清文件；`requestStopForPageExit` **只**调 `recorder.stop()`（保留 take）；删除只能走详情页 T034 路径（已 save 的 `PracticeRecord` 通过 `AudioFileStorageService.deleteIfExists` 清理）。

**回归证据**：净增 10 项测试（6 controller + 3 widget + 1 既有 controller 测试修改）。`stopGate` + in-flight Future 协调机制直接证明 4 个并发 caller resolve 同一 `PageExitStopSuccess` identity（`identical()` 严格断言）—— 这是 T037B1 修复的核心证据；recording failure retry 测试 pin 第二次 `requestStopForPageExit` resolve `skipped(serviceAlreadyTerminal)` 且**不**调第二次 `recorder.stop`（严格 0 次额外 stop）；playback failure retry 测试 pin 第二次 `requestStopForPageExit` resolve `success` 且**真的**调第二次 `playback.stop`（严格 +1 次 stop）；ticker duplicate 防御测试 pin 录音 stop 失败后 `elapsedSeconds == recordedDurationSeconds`（duplicate Timer 会推进 elapsedSeconds）；既有 656 测试零回归；page 层 0 改动（`_handleExit` / `_runExit` / `PopScope` / `_exitInFlight` 全部保留）。

**未**修改生产代码（除允许范围内 1 个 lib 文件 —— controller）/ 测试代码（除允许范围内 2 个 test 文件：1 controller + 1 widget）/ 文档（本 ledger / AGENT_QUALITY_METRICS / TASK_LEDGER 三 doc 文件）/ Manifest / schema / 依赖 / 共享 service 所有权契约 / 详情页 T037A / T037A1 0 改动 / 录音页既有 `recording_practice_controller.dart:801` state.error `'停止播放失败：$e'` 排障流**未**触碰 / 录音页既有 `recording_page_exit_stop_result.dart` sealed class 0 改动 / `fake_audio_recorder_gateway.dart` T037B 已加 `stopGate` 0 改动 / page 层 (`recording_page.dart`) 0 改动。

**遗留技术债（不属于本任务范围）**：① App 启动时清理孤儿 temp 文件的机制**未**实现（`AudioFileStorageService.ensureDirectories` 只确保目录存在，不扫描 stale `temp/*.m4a`）；② native 录音 / 播放 stop 失败后是否真的停止仍依赖 service-layer 反馈（service 抛错 = black-box，native 仍可能在跑）；③ **未**为 in-flight Future 协调添加 page-exit 之外的语义扩展（例如录音中 `stopRecording()` / `reset()` 也想复用 in-flight Future，但当前 `_pageExitStopFuture` 字段是 page-exit 专用）。

## TD-017: T037B2 录音 service stop 失败保留活跃会话 + controller 真正重试（service-layer 修复 + ticker 重启 + verbatim resolvedPath）— 闭环说明

**问题**：T037B1 修复解决了录音页退出 stop 失败的并发保护（in-flight Future 协调），但**未**解决"录音 service 抛错后第二次退出真正重试 `recorder.stop()`"的问题。**场景**：录音中退出 → 第一次 `recorder.stop` throws → service catch 块调用 `_clearActiveSession()` + `_state = idle` → 第二次退出 observe `recorder.state == idle` → controller 走 `skipped(serviceAlreadyTerminal)` short-circuit → page 直接 pop，但**不**会真正调第二次 `recorder.stop()`。Service 抛错时 native `record` package 是否真的停止了 native 录音**仍是 black-box**（`record` 7.1.0 的 `_safeCall` 通过 semaphore 保护 platform-channel 调用，gateway 抛错时 native 录音**可能**还在跑），所以 service 伪装成 idle + 清 active session 实际上**让 native 录音可能在 page 弹出后继续跑**。

**根因**：T037B1 既有 `RealAudioRecorderService.stop` catch 块在 throw 时执行 `_clearActiveSession()` + `_state = idle` —— service 主动放弃"对 native 录音的所有权"，理由是"service 已无法证明 native 真的 stop 了"。但这一设计在 controller 层导致第二次退出走 `skipped(serviceAlreadyTerminal)` 短路径（service idle + state idle → page pop），实际效果是用户**无法重试**真实 stop（service 已 clear session，**不**可能再调 `recorder.stop()`）。**核心矛盾**：service 想用"伪装 idle"表达"我不知道 native 状态"，但 controller 把"service idle"理解为"可以安全退出"。

**解决（closed）**：`T037B2_FIX_RECORDER_STOP_FAILURE_RECOVERY` —— **service-layer 修复 + controller 镜像**两阶段：① **`RealAudioRecorderService.stop` catch 块改为** —— gateway 抛错时**保留** `_activeTakeId` / `_activeTempFile` / `_activePaths`（不调 `_clearActiveSession()`），state 从 `stopping` revert 到 `recording`（**不**是 idle）；② **service 状态机新语义** —— 抛错后 service 表达"录音尚未确认停止，active session 仍可用"，controller 第二次进 recording 分支时 `recorder.state == recording`（不是 idle），**不**被 short-circuit 拦截；③ **controller 镜像** —— 录音 stop 失败时 controller **保持** `isRecording = true`、**重启** ticker（`_startTicker()`），让 MM:SS 读数诚实反映"录音还没真的停下来"；④ **retry 真正调 `recorder.stop()`** —— 第二次 `requestStopForPageExit` 进 recording 分支 → 调 `await recorder.stop()`（service 已 keep active session）→ gateway 恢复时成功 → 返回 take result → page pop；⑤ **verbatim resolvedPath** —— 成功 retry 时 `resolvedPath` 等于 gateway 返回字符串 AS-IS（与 T033 既有 verbatim 契约一致）；⑥ **consecutive failure 仍可 retry** —— 3 次连续 throw 仍然每次都真正调 `gateway.stop()`（service 永不进入 `idle`，永不丢失 active session）；⑦ **cancel 既有语义不破坏** —— 录音 stop 失败后 service 仍处于 `recording` 状态，`cancel()` 仍可正常调（清理 temp 文件）；⑧ **file 头注释 + doc comment 升级为 T037B + T037B1 + T037B2**，新增 `T037B2 — failure-retry contract:` 章节详细解释 service 状态机新语义。

**Service 契约诚实记录**（与 T037B1 既有契约一致 + 升级）：① **recording service 抛错时是否真的 stop 了 native 录音仍是真机层面的"黑盒"** —— `RealAudioRecorderService.stop` catch 块**不**再调 `_clearActiveSession()`、**不**再 flip `_state = idle`、而是 revert `_state = recording`；**这本身不证明 native 真的停止**；**但** retry 路径现在能真正重发 `gateway.stop()`，如果 native 真的还在跑，第二次调用有可能成功（如果 native 已 stop，第二次 gateway 会抛 `InvalidRecorderStateException` 或返回 null → service catch 块仍会保留 active session + state recording，让用户继续重试）；② **playback 失败契约 0 改动** —— `RealAudioPlaybackService._stopInternal` catch 块 `_state = previousState`（与 T037B1 一致）；controller 保留 `isPlaying=true` 让 retry 走对 playback 分支；③ **service 状态机不变量新条款** —— "recording state" **不**再等价于"用户正在录音"，而是等价于"录音 session 仍在 service 所有权下、可被 stop 调用"；这是与 T037B1 旧契约的关键差异。

**未保存 take 文件安全契约**（与 T037B / T037B1 既有契约一致 + 升级）：① 录音中退出第一次失败 → service state stays `recording` + takeId != null + active session 仍可用 → 第二次 retry → 调 `await recorder.stop()`（gateway 恢复时成功）→ takeId 保留 + 文件在 temp 目录 → 用户能保存；② 录音后未回放直接退出 → takeId != null + isPlaying == false → 仍调 `playback.stop()` 释放 player 句柄，**不**调 `recorder.cancel()`（cancel 会清文件破坏未保存 take）；③ **service 状态机在 stop 失败时**不**主动清 active session**（T037B2 修复）；删除只能走详情页 T034 路径（已 save 的 `PracticeRecord` 通过 `AudioFileStorageService.deleteIfExists` 清理）。

**回归证据**：净增 14 项测试（5 service + 5 controller + 4 widget）+ 修改 4 项既有 T037B / T037B1 测试（1 service + 2 controller + 1 widget）= 净增 14 项。**service 5 项新 T037B2 测试**：① first gateway.stop throws → service stays `recording` + active session 保留（**不**进 idle）；② second stop after first throws → re-issues against same active session + resolves to take result；③ verbatim resolvedPath invariant（与 T033 既有 verbatim 契约一致）；④ 3 consecutive stop failures → active session 仍保留（**不**进 idle，无 file deletion）；⑤ cancel still works correctly after a stop failure（既有 cancel 语义不破坏）。**controller 5 项新 T037B2 测试**：① first failure: page ownership preserved（isRecording stays true + takeId preserved + failure result with safe recording-failure message）；② second call after failure: drives a real second recorder.stop against SAME active session + resolves to success（**不**走 `skipped(serviceAlreadyTerminal)`）；③ consecutive failures: every retry drives a real recorder.stop + page NEVER popped until retry succeeds（3 次 throw 仍 3 次真实 stop）；④ ticker restart on failure does NOT create a duplicate Timer.periodic（`elapsedSeconds == recordedDurationSeconds`，duplicate Timer 会偏离）；⑤ controller does NOT return `skipped(serviceAlreadyTerminal)` as a way to bypass the real retry（严格 pin 短路径在 T037B2 修复后**不**被 retry 触发）。**widget 4 项新 T037B2 测试**：① first failure: page retained + recording-failure SnackBar + recorder.stop call count 严格 +1（**不**pre-emptive skip）；② second exit after failure: recorder.stop call count 严格 +1（**不**skip）+ page finally pops；③ consecutive failures: page stays mounted across all failures + recorder.stop call count increases for every retry + no unhandled exception；④ Android system back after failure: also drives a real second recorder.stop + page finally pops on successful retry（**双 back gesture 覆盖**）。既有 666 测试零回归；page 层 0 改动（`_handleExit` / `_runExit` / `PopScope` / `_exitInFlight` 全部保留）。

**修改 4 项既有 T037B / T037B1 测试**（覆盖率**不**倒退）：① service `RealAudioRecorderService.stop` "stop throwing an exception is translated and state recovers" 改写为 T037B2 语义（state stays `recording` + retry resolves to success + verbatim resolvedPath）；② controller T037B "recording.stop throws" 改写（isRecording stays true + takeId preserved）；③ controller T037B1 "recording stop failure: page is retained" 改写为 T037B2 语义（isRecording STAYS true + takeId preserved）；④ controller T037B1 "recording retry" 改写（second call drives a real second recorder.stop + resolves to success）；⑤ controller T037B1 "duplicate timer invariant" 改写为 T037B2 语义（ticker restart on failure）；⑥ controller T037B1 "recorder retry after in-flight Future" 改写为 T037B2 语义（second call drives a real second recorder.stop）；⑦ widget T037B1 "recorder.stop throws then service is idle" 改写为 T037B2 "recorder.stop throws then retry"（second exit drives a real second recorder.stop + page finally pops）。**修改 0 净增测试**，但 T037B2 实际新增 14 项测试，所以总净增 +14。

**未**修改生产代码（除允许范围内 2 个 lib 文件：1 service + 1 controller）/ 测试代码（除允许范围内 3 个 test 文件：1 service + 1 controller + 1 widget）/ 文档（本 ledger / AGENT_QUALITY_METRICS / TASK_LEDGER 三 doc 文件）/ Manifest / schema / 依赖 / 共享 service 所有权契约 / 详情页 T037A / T037A1 0 改动 / 录音页既有 `recording_practice_controller.dart:801` state.error `'停止播放失败：$e'` 排障流**未**触碰 / 录音页既有 `recording_page_exit_stop_result.dart` sealed class 0 改动 / `fake_audio_recorder_gateway.dart` T037B 已加 `stopGate` 0 改动 / page 层 (`recording_page.dart`) 0 改动 / 录音页既有 `_onDispose` 兜底（T035A safety net）0 改动。

**遗留技术债（不属于本任务范围）**：① App 启动时清理孤儿 temp 文件的机制**未**实现（`AudioFileStorageService.ensureDirectories` 只确保目录存在，不扫描 stale `temp/*.m4a`）；② native 录音 / 播放 stop 失败后是否真的停止仍依赖 service-layer 反馈（service 抛错 = black-box，native 仍可能在跑）—— T037B2 修复让 retry 路径真正能重发 `gateway.stop()`，但**不**证明 native 状态；③ **T037B2 + T037B1 + T037B 三层**retry 语义需用户真机验证 —— 自动化测试覆盖（680 tests passed）证明 service 状态机 + controller 镜像 + ticker 行为 + verbatim 路径，但真机 audio stop 时序受 native `record` 实现影响，最终用户体验仍需用户真机验证；④ **service 状态机新语义需文档同步** —— 既有 `RealAudioRecorderService` library 注释 + `AudioRecorderState` enum doc 仍描述 T029 既有契约（"stop 抛错状态恢复 idle"），T037B2 修复后需要更细的状态机描述（"recording 表达 service 所有权下可被 stop"，与"用户正在录音"解耦）；⑤ **`_playbackServiceId` 类似 T037B2 修复对 playback 是否有需要** —— 现有 playback 失败时 service `_state = previousState` 已经满足"retry 路径合法"语义，**不**需要 service-layer 修复。

## TD-018: T037C 详情页"暂停→继续"播放状态同步（fire-and-forget resume + ready+playing 事件路由 + stale 防护）— 闭环说明

**问题**：T037 真机验收发现 — 打开已保存录音的练习记录详情 → 播放已保存录音 → 暂停 → 声音正确暂停，按钮显示"继续" → 点击继续 → 真实声音恢复播放 → **按钮仍显示"继续"，没有切换回"暂停"** → 再次点击"继续" → 页面进入错误状态（标题"出错了" / 按钮"重试" / 文案"播放操作失败，请重试"）→ 实际声音继续播放直至自然结束。其他行为正常（首次播放/暂停/继续 OK）。T037A 修复的是退出停止、T037A1 修复的是文案，**未**触碰 resume 路径；T035B session 隔离**不**是 bug 源；录音页与录音 service **未**触碰。

**根因（最关键审计结论）**：`just_audio 0.10.5` 真实 `AudioPlayer.play()` 语义（Context7 验证）：**"The Future returned by this method completes when the playback completes or is paused or stopped. ... This method causes playing to become true, and it will remain true until pause or stop is called."** —— `play()` 调用的瞬间 `playing` 已 true，但 Future 在 playing 期间**一直挂起不 complete**。`RealAudioPlaybackService.resume()` 内部 `await play()` → `play()` → `_gateway.play()` Future 一直挂起到自然完成 / pause / stop。T035 既有 `PracticeRecordDetailController.resumePlayback` `await playback.resume()` 在真机上**永不返回** → controller 永远不写 `playbackStatus = playing` → UI 卡在 `paused` 显示"继续" → 第二次 click 时 `playbackStatus == paused` 通过守卫 → `await playback.resume()` → service 内部 `_state` 已是 `playing`（service `play()` 内部已切到 playing）→ `play()` 在 `_state == playing` 时抛 `InvalidPlaybackStateException` → controller catch → 发 `error` + "播放操作失败，请重试"。`controller._onPlayerState` 只处理 `completed`（[practice_record_detail_controller.dart:1712](lib/features/practice_records/application/practice_record_detail_controller.dart#L1712)）—— `ready + playing` / `ready + not playing` 事件被丢弃，controller 永远不通过 playerStateStream 跟随 service 状态（hidden bug）。`FakeAudioPlaybackGateway.play()` 默认（[fake_audio_playback_gateway.dart:286-337](test/shared/services/fake_audio_playback_gateway.dart#L286-L337)）走"非 keepPlayPending 分支"立即 `isPlaying = true` 并返回；完全没模拟真机 play Future 一直挂起语义——这正是 T031G 注释警告的"mirror just_audio's real-device behaviour"问题，**默认行为掩盖了真机 bug**。

**解决（closed）**：`T037C_FIX_DETAIL_RESUME_UI_STATE_SYNC` —— ① **`resumePlayback` 改为 fire-and-forget + 乐观 publish `playing` + 双层守卫**（同步 `_isResuming` 私有标志 + state 守卫 `playbackStatus != paused`）—— 不再 `await playback.resume()`（真机 play Future 一直挂起），立即 fire-and-forget `playback.resume()` + 同步 `_publish(playbackStatus: playing)` 让 UI 在同一帧翻回"暂停"；② **`_onPlayerState` 扩展处理 `ready + playing` / `ready + not playing` 事件** + stale 防护（`_lastEmittedPlaybackStatus` mirror 防止 stale `ready + not playing` 事件覆盖刚乐观 publish 的 `playing`）；`completed` 行为保持 T035 既有契约；session id 守卫 + disposed / mounted 检查保留；③ **`FakeAudioPlaybackGateway` 增强**：`playFutureCompleter: Completer<void>?` 让 play Future 保持 pending（模拟真机）+ `emitReadyPlaying()` / `emitReadyPaused()` 测试 helper + `releasePlayFutureCompleter()` —— 默认行为兼容（旧测试不破）；④ **service 公共 API 0 改动**。**Real-device play Future 语义**：`just_audio` 0.10.5 `AudioPlayer.play()` Future 在 playing 期间**一直挂起不 complete**（Context7：源码 `await playCompleter.future` 在 `_sendPlayRequest` 内 `playCompleter` 由 platform `play` 事件完成时 complete）；service `play()` 同步设置 `_state = playing` 然后 `await _gateway.play()` 一直挂起；这与 T031G 注释一致。**Resume 行为前后对比**：**Before**：`await playback.resume()`（真机永远不返回）→ controller 状态机永远写不到 `playing` → UI 卡在 paused；第二次 click 走同样 await → service 抛 `InvalidPlaybackStateException` → catch 发 error + "播放操作失败，请重试"。**After**：fire-and-forget `playback.resume()` + 乐观 publish `playing`（service play() 同步 flip `_state = playing`，与 controller optimistic publish 同步）→ UI 立即翻"暂停"；service 后续 emit `ready + playing` 事件经 `_onPlayerState` 二次确认（`state == playing` → no-op）。**Duplicate Resume 防护**（双层）：(a) 同步 `_isResuming` 标志在 resume 操作中 + 第二次 click 立即被守卫拒绝；(b) state 守卫 `playbackStatus != paused` → 第二次 click 落入 `playing` 时被守卫拒绝（optimistic publish 已 flip state）。**Pending Play Future 证据**：新增 `playFutureCompleter` + 11 项 controller 测试中 T037C-A / T037C-K 显式 gate `play()` + assert `playGate.isCompleted == false`（证明 controller 不 await play Future）+ assert 200ms 内 resume call 返回（fire-and-forget 验证）。**Natural Completion 行为**：T037C-E 显式 pin — resume 后 emit `ready + playing` 然后 emit `completed` → controller 必须翻回 `idle`（T035 既有契约保留）。**T035B 跨会话隔离保持**：T037C-F 显式 pin — A session: play → pause → resume → stop;B session: play → pause → resume → emit ready+playing → B's listener 处理（cancel-and-rebuild 在 B playRecordedAudio 时建立）。**Stale 防护**：`_lastEmittedPlaybackStatus` mirror 记录 controller 主动 publish 的状态；`ready + not playing` 事件只在 `_lastEmittedPlaybackStatus == paused` 时才允许覆盖 `playing`（防止 resume 期间的 pause blip 把 UI 弹回"继续"）。**服务状态防御（onError）**：fire-and-forget resume 的 onError 路径中，若 `playback.state == playing`（service 实际在 playing），**不**翻 error（stale failure 误报防护）。**Fake 真实性增强**：`FakeAudioPlaybackGateway.play()` 现在区分 `keepPlayPending`（一-shot flag）vs `playFutureCompleter`（reusable Completer）—— `playFutureCompleter` 是 T037C 引入的持续性 gate，让 play Future 保持 pending；测试通过 `releasePlayFutureCompleter()` 释放 gate（模拟真机 play 自然完成 / pause / stop 边界）。

**回归证据**：净增 18 项测试（11 controller + 7 widget）= 既有 680 → 698（+18）。`playFutureCompleter` + 11 项 controller 测试（T037C-A 真机 happy path / T037C-B 三次并发 resume 只一次 play / T037C-C stale paused 事件不覆盖 / T037C-D sync-time failure 走 error / T037C-E natural completed 仍翻 idle / T037C-F T035B 跨会话 / T037C-G 快速三次 click / T037C-H resume from idle no-op / T037C-I resume from error no-op / T037C-J page-exit 协同 / T037C-K fire-and-forget 性能）+ 7 项 widget 测（T037C-W1 真机 happy path UI 翻转 / T037C-W2 第二次 tap 不触发 / T037C-W3 resume → natural completed 恢复"播放" / T037C-W4 pause → resume → stop 全链路 / T037C-W5 stale 事件不弹回 / T037C-W6 playCallCount 锁步 / T037C-W7 fire-and-forget 性能）。`flutter test` 全量 `00:24 +698: All tests passed!`（既有 680 项 0 回归）。

**未**修改生产代码（除允许范围内 1 个 lib 文件 —— detail controller）/ 测试代码（除允许范围内 3 个 test 文件：1 controller + 1 widget + 1 fake helper）/ 文档（本 ledger / 后续 AGENT_QUALITY_METRICS T037C Scorecard / TECH_DEBT TD-018 三 doc 文件）/ 依赖 / Android 配置 / Drift schema / `app_database.g.dart` / `PracticeRecord` 域模型 / Repository / DAO / `audioFilePath` 字段 / `RealAudioRecorderService` / `RealAudioPlaybackService` 公共 API（既有契约已足够，controller 通过 playerStateStream 消费 service 状态）/ `AudioFileStorageService` / `MicrophonePermissionService` / 详情页 UI / 录音页 controller / 录音页 UI / 录音页既有 save flow / 录音页既有 reset flow / 录音页既有 _onDispose 兜底（T035A safety net 0 改动）/ 录音页既有 sealed class（`recording_page_exit_stop_result.dart` 0 改动）/ 录音页既有 `requestStopForPageExit` 行为 0 改动 / 录音页既有 `'停止录音失败，请重试'` / `'停止播放失败：$e'` 字面量**未**触碰 / 详情页既有 `requestStopForPageExit` 行为 0 改动 / 详情页既有 `'停止播放失败，请重试'` 字面量**未**触碰 / Manifest / 隐私政策 / `tool/verify_release_artifacts.dart` / `key.properties` / `.gitignore` / 构建产物 / `agents/*.md` / `MULTI_AGENT_WORKFLOW.md`。

**遗留技术债（不属于本任务范围）**：① **service 公共 API 是否需新增 `playingStream` 暴露** —— 当前 controller 通过 playerStateStream 消费 ready+playing 事件（via `ps.playing`），但 service 内部 `_state` 已是 source of truth；如果未来需要 service-level listening（不止 detail page），可考虑暴露 `playingStream` 让上层自由订阅；这是 API 扩展，**不**影响 T037C 修复正确性；② **resume optimistic publish 与 stream 事件到达之间的微小窗口** —— T037C-A 中 `gateway.playCallCount == 1` 后 controller 立即 `_publish(playing)`（同帧），但 `ready + playing` 事件可能在下一 microtask 到达；在 `ready + playing` 事件到达前若用户 tap pause（"暂停"按钮已可见），pause 路径走 `pausePlayback` → `service.pause()` → `playback.state == paused` → controller `_publish(paused)`（同步）→ 后续到达的 `ready + playing` 事件进入 `_onPlayerState`：state 已是 `paused`（不是 `playing`）→ 分支 `current.playbackStatus != playing` → return（被忽略），不会被覆盖回 playing；**修正**：stale 防护已隐式覆盖此 race（state 守卫 + mirror 守卫）；③ **真机国产 ROM 兼容性** —— T037C 修复依赖 just_audio 0.10.5 playerStateStream 的 `ready + playing` 事件按时到达；若某些 ROM 延迟 / 丢失 playing 事件，UI 会卡在 "暂停"（按钮）+ 实际声音在 playing——T037C 乐观 publish 让 UI 立即翻"暂停"，但 service 实际是否真的在 playing 仍依赖 playerStateStream 事件二次确认（如果 lost，service 状态不一致）；这是 T037 真机国产 ROM 兼容性范畴，**不**在本任务越界；④ **controller 与 service 状态机双向同步** —— 当前 controller 通过 `_onPlayerState` 单向消费 service 状态；service 内部 `_state` 是 source of truth，controller 状态机是 derived view；如未来需要在 controller 内做"反向"操作（e.g. service state 异常但 controller 必须显示 playing），需引入 service-state-mirror 而非 playerStateStream 订阅——这是架构演进，**不**在本任务越界。

**T037C 修复完整**（1 lib controller + 3 test files: 1 controller + 1 widget + 1 fake helper），**用户可见收益明确**：暂停→继续后 UI 立即翻"暂停"（不再卡"继续"）；第二次 tap 不再触发重复 resume（双层守卫：`_isResuming` 同步标志 + state 守卫 `playbackStatus != paused`）；不再出现"播放操作失败，请重试"误报；声音状态与 UI 状态锁步（fake.playCallCount 与 widget 状态对应）；自然完成、返回前停止、删除前停止、T035B session 隔离、T037A exit-stop 100% 保留。

## TD-019: T037 真机验收文档收口（23 项 PASS + 1 项 NOT RUN + 单设备覆盖限制）— 闭环说明

**任务定位**：T037 真机验收文档收口任务（`T037_REAL_AUDIO_ANDROID_DEVICE_ACCEPTANCE_FINALIZE`）**仅**完成 T037 真机验收文档收口，**不**修改生产代码 / 测试 / Manifest / schema / 依赖 / 任何 `test/**/*.dart` 文件。本任务**不**新增任何自动化测试（既有 698 项 `flutter test` 基线 0 回归）；**不**声称已通过 GPT 复审（待 GPT 复审）。

**真机验收范围**：用户在真机上**逐项**手工确认 → **23 项 PASS + 1 项 NOT RUN**（权限首次申请）；设备为**华为 CDY-AN90 / Android 10**（**单台真机**，**不**覆盖小米 / OPPO / vivo / 三星或其他 Android 版本）；设备序列号**已脱敏**（**仅**保留型号 `HUAWEI CDY-AN90` + Android 版本 `10`，**不**记录完整 serial 或后 4 位）。**验收规模**：

- **录音页真实录音与回放**：7/7 PASS（#1 ~ #7，录音 / 计时 / 回放 / 暂停继续停止 / 自然完成 / 保存 / 强停重启）
- **录音页退出行为**：4/4 PASS（#8 ~ #11，T037B / T037B1 / T037B2 闭环；录音中 + 回放中 + AppBar + 系统返回各组合）
- **详情页播放**：5/5 PASS（#12 ~ #16，T037A / T037A1 / T037C 闭环；暂停→继续 UI 同步 / 继续→再暂停 / 自然完成 / AppBar 返回 / 系统返回）
- **删除流程**：5/5 PASS（#17 ~ #21，T034 闭环；播放期间删除 / 声音停止 / 列表消失 / 无 cleanup warning / 强停重启未恢复）
- **稳定性与人工听觉确认**：2/2 PASS（#22 ~ #23；崩溃或明显异常 = 用户**未观察到** / 用户真实听觉确认）
- **权限首次申请**：0/1（#24 **NOT RUN**，因 `adb install -r` 保留了既有 `RECORD_AUDIO` 授权；**严禁**写成 PASS）

**Evidence Source Separation 7 类**严格隔离（详见 `docs/qa/REAL_AUDIO_ANDROID_ACCEPTANCE.md` "Evidence Source Separation" 节）：① 用户人工听觉确认（User confirmed（听觉））；② 用户真机行为观察（User confirmed）；③ adb 安装与设备证据；④ 自动化测试证据（既有 698 项 `flutter test`，**不**作为真机验收结论的代位证据）；⑤ NOT RUN 项目（#24 + 既有 MA-01 ~ MA-04 权限首次申请）；⑥ 本轮未跑项目（既有 MA-08 来电中断 / MA-13 文件系统级断言 / MA-15 卸载重装 / MA-17 隐私文案 / MA-19 ~ MA-20 大字体 / MA-21 旧记录兼容 / MA-22 文件丢失处理）；⑦ 单设备覆盖限制（整份文档，**严禁**推断其他 ROM）。

**既有 MA 项与本轮对应关系**（`REAL_AUDIO_MVP_TDD.md` MA-01 ~ MA-22 22 项真机验收清单与本轮 PASS / NOT RUN / 本轮未跑 / 既有自动化覆盖 4 类状态完整映射，详见 `docs/qa/REAL_AUDIO_ANDROID_ACCEPTANCE.md` "既有 MA 项与本轮对应关系" 节）：MA-01 / MA-02 / MA-03 / MA-04 权限弹窗（NOT RUN）+ MA-05 ~ MA-07 录音 / 回放（PASS，对应本轮 #1 / #3 / #4）+ MA-08 来电中断（本轮未跑）+ MA-09 ~ MA-12 列表 / 详情 / 删除（PASS，对应本轮 #6 / #7 / #17 ~ #21）+ MA-13 文件系统级断言（本轮未跑 / 既有 T036 端到端覆盖）+ MA-14 强停重启（PASS，对应本轮 #7）+ MA-15 卸载重装（本轮未跑）+ MA-16 不弹权限（PASS，对应本轮未观察到弹窗）+ MA-17 隐私文案（本轮未跑）+ MA-18 无 `INTERNET`（PASS，既有静态检查）+ MA-19 ~ MA-20 大字体（本轮未跑）+ MA-21 旧记录兼容（本轮未跑）+ MA-22 文件丢失（本轮未跑）。**范围声明**：本轮 T037 真机验收**仅**覆盖与"T037 期间发现并修复的真机缺陷直接相关"的用户场景；`REAL_AUDIO_MVP_TDD.md` MA-01 ~ MA-22 是设计层面的完整真机验收清单，T037 是其中**部分**子集的实跑记录；剩余 MA 项的覆盖依赖既有自动化测试或后续独立真机验收任务。

**T037 期间发现并修复 7 项真机缺陷**（与 TD-014 / TD-015 / TD-016 / TD-017 / TD-018 闭环说明一一对应，全部由既有 698 项 `flutter test` 覆盖，T037 **净增 0 项**自动化测试）：① 详情页退出仍播放 → T037A → awaitable stop + 单点 chokepoint + PopScope 拦截；② 详情页退出停止文案误用（"停止录音失败，请重试"误用）→ T037A1 → 录音 / 播放 文案严格分离；③ 录音页退出仍录音 → T037B → 4 状态决策 + awaitable stop + PopScope 包装；④ 录音页退出仍播放 → T037B → 同上；⑤ 录音页退出 stop 失败状态丢失（第一次失败后第二次退出不能重试）→ T037B1 → in-flight Future 协调 + 录音/播放独立重试 + service-already-terminal 兜底；⑥ 录音 service stop 失败丢失活跃会话（service catch 块清 active session 让 retry 失败）→ T037B2 → service 保留 active session + controller 镜像 + ticker 重启；⑦ 详情页暂停→继续 UI 不同步（UI 卡"继续"+ 重复 tap 误报"播放操作失败，请重试"）→ T037C → fire-and-forget resume + 乐观 publish + ready+playing 事件路由 + stale 防护。

**单设备覆盖限制（强警告）**：`docs/qa/REAL_AUDIO_ANDROID_ACCEPTANCE.md` Device 表 + 强警告段 + Known Limitations #1 + 国产 ROM 兼容性问题清单 4 处独立强调：① 本验收**仅**覆盖 HUAWEI CDY-AN90 / Android 10 一台真机；② `REAL_AUDIO_DEPENDENCY_SPIKE.md` §3.6 + TD-013 明确指出国产 ROM 兼容性必须由真机用户验收 —— 本文档**不**能据此推断其他 ROM 已通过验证；③ **国产 ROM 兼容性问题可能在其他设备上出现**，包括但不限于：`just_audio 0.10.5` playerStateStream 事件延迟 / 丢失、`record 7.1.0` 麦克风路由、`permission_handler 12.0.3` 弹窗行为、`AudioFileStorageService` 文件路径解析；④ 本文档**严禁**被解读为"已通过所有 Android ROM 验证"或"已通过国产 ROM 通用验证"。

**`adb install -r` 保留授权风险**（Known Limitations #11）：本轮**未**触发 `adb uninstall` / `pm uninstall` / `adb install -r --force-reinstall` 等重装操作；既有 `RECORD_AUDIO` 授权由前轮会话保留，本轮**不**证明"卸载重装后数据隔离"或"权限申请重置"。MA-15 卸载重装数据隔离 = 本轮未跑（既有 T036 端到端测试未覆盖此场景）；MA-01 ~ MA-04 权限首次申请 = NOT RUN。

**崩溃或明显异常代写风险**（Known Limitations #6）：项 #22"整个验收期间崩溃或明显异常：未发现"是用户**未观察到**的描述，**不**等价于"测试证明无崩溃"。本轮**未**抓取崩溃日志 / ANR / `am_crash` / Tombstone 等 Native 信号；如未来需要机器可验证的崩溃率 / 异常率，需引入 `flutter_driver` / `integration_test` 端到端 crash hook 或 Sentry 等崩溃监控。

**自动化测试基线 vs 真机验收结论严格区分**：`docs/qa/REAL_AUDIO_ANDROID_ACCEPTANCE.md` "Automated Evidence（基线状态）" 节显式标注：① 698 项 `flutter test` 是 T037C / T037B2 既有基线，**不**作为真机验收结论的代位证据；② T037 真机验收**净增**自动化测试 = 0 项；③ 自动化回归覆盖（T036 / T036A / T037A / T037A1 / T037B / T037B1 / T037B2 / T037C）仅作为"基线状态"参考，**不**替代真机用户验收。

**未**声称：① 所有 Android ROM 均兼容（**强警告** Known Limitations #1 + Device 表 + 单设备覆盖限制 + 国产 ROM 兼容性问题清单 4 处独立强调）；② 权限首次申请已通过（显式 NOT RUN + Known Limitations #2）；③ Release APK / AAB 已验收（指向 T023 / T022 既有文档 + Known Limitations #3）；④ 已完成商店发布（Known Limitations #4）；⑤ 已完成 iOS 验收（Known Limitations #5 / TD-003）；⑥ 已完成 push 或 tag（`Command Discipline` 节显式列出未触发）。

**`docs/qa/` 目录新建** —— 之前**未**存在，由本任务 `mkdir -p docs/qa` 单条命令创建，**仅**放置 `REAL_AUDIO_ANDROID_ACCEPTANCE.md` 一份文档；**不**影响任何代码 / 测试 / Manifest / schema / 依赖 / `.gitignore` / `key.properties` / 构建产物。

**修改文件清单**（4 允许文件 + 1 目录新建）：① `docs/qa/REAL_AUDIO_ANDROID_ACCEPTANCE.md`（新建，约 380 行）；② `docs/dev/TASK_LEDGER.md`（追加本 T037 任务条目，**不**修改既有 T006-T037C 任何条目）；③ `docs/dev/AGENT_QUALITY_METRICS.md`（追加 4.24 T037 Scorecard 条目，**不**修改既有 4.1 ~ 4.23 任何 Scorecard）；④ `docs/dev/TECH_DEBT.md`（追加本 T037 闭环说明段，**不**修改既有 TD-001 ~ TD-018 任何条目）。

**未**修改：生产代码 / 测试代码（`test/**/*.dart` 0 改动）/ Android 配置（Manifest / `pubspec.yaml` / `pubspec.lock` 0 改动）/ Drift schema（`schemaVersion` 仍 2，T032 锚点未变）/ `app_database.g.dart` / `PracticeRecord` 域模型 / Repository / DAO / `audioFilePath` 字段 / `RealAudioRecorderService` / `RealAudioPlaybackService` / `AudioFileStorageService` / `MicrophonePermissionService` / Manifest / 隐私政策 / `tool/verify_release_artifacts.dart` / `key.properties` / `.gitignore` / 构建产物 / `agents/*.md` / `MULTI_AGENT_WORKFLOW.md` / 既有 T006-T037C 任何台账条目 / 既有 TD-001 ~ TD-018 任何条目 / 既有 T037A / T037A1 / T037B / T037B1 / T037B2 / T037C Scorecard 任何条目。

**实现后验证**：`git status --short` 仅 `?? .tmp/`（既有临时目录 + 未跟踪截图，**未**纳入提交）+ 4 个 `M`（4 个允许文档）+ 1 个 `?? docs/qa/`（新建目录）+ 1 个 `?? docs/qa/REAL_AUDIO_ANDROID_ACCEPTANCE.md`（新建文档），**不**触及受控文件；`flutter analyze` `No issues found!`；`flutter test` 全量 `+698: All tests passed!`（**T037 任务净增自动化测试 = 0 项**；既有 698 项基线 0 回归；与 T037C / T037B2 既有基线一致）；`git diff --check` 通过；`git diff --name-only` 仅 4 个允许文档（`docs/qa/REAL_AUDIO_ANDROID_ACCEPTANCE.md` + `docs/dev/TASK_LEDGER.md` + `docs/dev/AGENT_QUALITY_METRICS.md` + `docs/dev/TECH_DEBT.md`）；`git diff --stat` 仅文档变化（无 `lib/` / `test/` / `android/` / `pubspec.yaml` / `.gitignore` / `key.properties` 变化）。

**Reviewers Approved**（read-only）：`05-android-qa-reviewer` Approved（23 项 PASS 全部 `User confirmed` 来源；1 项 NOT RUN 原因（`adb install -r` 保留授权）真实可复现；7 项 T037 期间发现并修复的缺陷与 TD-014 ~ TD-018 闭环说明一一对应；既有 MA-01 ~ MA-22 与本轮 PASS / NOT RUN / 本轮未跑 4 类状态完整映射无遗漏）；`02-flutter-architect` Approved（7 项真机缺陷 ID 与修复任务（T037A / T037A1 / T037B / T037B1 / T037B2 / T037C）一一对应 `TASK_LEDGER.md` + `AGENT_QUALITY_METRICS.md` 既有条目；自动化证据**不**与人工证据混淆；T037 真机验收**净增**自动化测试 = 0 项显式标注；录音页退出 / 详情页退出 / 暂停继续 / 删除前停止 / 自然完成 / 强停重启 6 类关键架构路径均有显式提及；既有 MA 项 MA-01 ~ MA-22 4 类状态映射无架构路径描述偏离）；`08-compliance-reviewer` Approved（设备序列号**已脱敏** —— 仅保留型号 `HUAWEI CDY-AN90` + Android 版本 `10`；权限首次申请流程（MA-02 / MA-03 / MA-04）显式 NOT RUN **未**写成 PASS；设备覆盖范围**严格**限于 HUAWEI CDY-AN90 单台真机；**未**声称 Release APK / AAB 已验收 / **未**声称应用商店已提交 / **未**声称 iOS 已验收 / **未**记录 keystore 路径或密码或 `key.properties` 内容 / **未**记录完整设备序列号 / 文档仅修改 4 个允许文件 + 1 个新建目录 / **不**触及生产代码 / 测试 / Manifest / schema / 依赖 / "崩溃或明显异常：未发现"显式标注为用户观察**不**误导为测试证明）。

**遗留技术债（不属于本任务范围）**：① 国产 ROM 兼容性（HUAWEI / 小米 / OPPO / vivo / 三星）必须由真机用户验收 —— 本任务**不**越界覆盖；② 权限首次申请流程（MA-01 ~ MA-04）的真机验收（拒绝 / 永久拒绝 / 设置跳转 / 重新申请）需要 `adb uninstall` + `adb install` 全新安装触发，**不**在本任务范围；③ MA-08 来电中断 / MA-13 文件系统级断言 / MA-15 卸载重装 / MA-17 隐私文案 / MA-19 ~ MA-20 大字体 / MA-21 旧记录兼容 / MA-22 文件丢失处理等场景需要独立真机验收任务；④ 机器可验证的音质指标（采样率 / 比特率 / 频率响应 / 失真度等）需要音频分析工具（如 ffmpeg / sox），**不**在本任务范围；⑤ 崩溃 / ANR / `am_crash` 等 Native 信号需要引入 `flutter_driver` / `integration_test` 端到端 crash hook 或 Sentry 等崩溃监控，**不**在本任务范围。

## T037D 状态备注（TD-017 旧注释问题闭环 + 录音 service stop 失败 retry 文档契约校准）

- **T037D 已完成**（基于 T037C 既有 698 tests passed 基线；T037D **不**新增 / 删除任何自动化测试；既有 698 项 0 回归；连跑稳定）。T037D 是文档收口任务，仅追加本台账段 + 同步 `TASK_LEDGER.md` + `AGENT_QUALITY_METRICS.md` + `docs/qa/REAL_AUDIO_ANDROID_ACCEPTANCE.md`，**不**修改任何生产代码 / 测试 / Manifest / schema / 依赖 / `key.properties` / `.gitignore` / 构建产物。
- **TD-017 旧注释问题已闭环**：`T037B2_FIX_RECORDER_STOP_FAILURE_RECOVERY` 在 T037D 提交 `270b27e`（即 `docs: align recorder stop retry contract`）已完成"录音 service stop 失败保留活跃会话 + controller 真正重试"修复；既有 TECH_DEBT.md TD-017 段（自 T037B2 起）已真实反映修复后契约（service-layer catch 块保留 `_activeTakeId` / `_activeTempFile` / `_activePaths`、state 从 `stopping` revert 到 `recording`、controller 镜像 `isRecording = true` + ticker 重启、retry 真正调 `recorder.stop()`）。**任何后续 Task ID（如 T038+）读取 TD-017 必须以当前台账段（`## TD-017: T037B2 ...`）为准**，不再以 T037B / T037B1 旧版"service catch 块清 active session"描述为准。
- **录音 / 播放失败文案严格分离契约（T037B 既有，T037D 文档同步）**：
  - 录音失败 SnackBar 文案严格 = `'停止录音失败，请重试'`（T037B 既有）；**不**复用 T037A / T037A1 详情页 `'停止播放失败，请重试'` 文案。
  - 播放失败 SnackBar 文案严格 = `'停止播放失败，请重试'`（T037B 既有）；**不**复用 `'停止录音失败，请重试'` 文案。
  - 录音页既有 `state.error = '停止播放失败：$e'` 排障流**未**触碰（T037B / T037B1 / T037B2 零改动；T037D 仅文档同步）。
  - 详情页既有 `'停止播放失败，请重试'` 字面量**未**触碰（T037A / T037A1 零改动；T037D 仅文档同步）。
- **未保存 take 文件安全契约（T037B / T037B1 / T037B2 既有，T037D 文档同步）**：① 录音中退出第一次失败 → service state stays `recording`（T037B2 修复）+ takeId != null + active session 仍可用 → 第二次 retry → 调 `await recorder.stop()`（gateway 恢复时成功）→ takeId 保留 + 文件在 temp 目录 → 用户能保存；② 录音后未回放直接退出 → takeId != null + isPlaying == false → 仍调 `playback.stop()` 释放 player 句柄，**不**调 `recorder.cancel()`（cancel 会清文件破坏未保存 take）；③ 录音 stop 失败时 service **不**再调 `_clearActiveSession()`、**不**再 flip `_state = idle`、而是 revert `_state = recording`（T037B2 修复）。
- **删除文件契约（T034 既有，T037D 文档同步）**：删除只能走详情页 T034 路径（已 save 的 `PracticeRecord` 通过 `AudioFileStorageService.deleteIfExists` 清理），**不**走 `recorder.cancel()`（cancel 会清 temp 文件破坏未保存 take）。
- **App 进程被系统终止后的临时文件回收契约（遗留债）**：① 当前**未**实现启动清理机制（`AudioFileStorageService.ensureDirectories` 只确保目录存在，不扫描 stale `temp/*.m4a`）；② 孤儿 temp 文件可能持续累积；③ 这是后续技术债，**不**在本任务越界实现。
- **真机国产 ROM 兼容性（遗留债）**：① TD-013 既已识别 HUAWEI / 小米 / OPPO / vivo 国产 ROM 兼容性未在 Spike 阶段验证；② T037 真机验收**仅**覆盖 HUAWEI CDY-AN90 / Android 10 单台真机（详见 `docs/qa/REAL_AUDIO_ANDROID_ACCEPTANCE.md` "单设备覆盖限制" 节）；③ **T037D 不**在本任务扩大设备覆盖范围，**不**在 EMUI / 其他 ROM 上做真机验收；④ T038+ 真机用户验收（不同 ROM / Android 版本）由独立任务决策。
- **未**修改生产代码 / 测试代码（`test/**/*.dart` 0 改动）/ Android 配置（Manifest / `pubspec.yaml` / `pubspec.lock` 0 改动）/ Drift schema（`schemaVersion` 仍 2）/ `app_database.g.dart` / `PracticeRecord` 域模型 / Repository / DAO / `audioFilePath` 字段 / `RealAudioRecorderService` / `RealAudioPlaybackService` / `AudioFileStorageService` / `MicrophonePermissionService` / `RecordingPracticeController`（除 `recording_practice_controller.dart:801` state.error `'停止播放失败：$e'` 排障流零改动）/ 录音页 UI / 详情页 UI / 录音页既有 sealed class（`recording_page_exit_stop_result.dart` 0 改动）/ 详情页既有 sealed class（`detail_page_exit_stop_result.dart` 0 改动）/ 录音页既有 `requestStopForPageExit` 行为 / 详情页既有 `requestStopForPageExit` 行为 / Manifest / 隐私政策 / `tool/verify_release_artifacts.dart` / `key.properties` / `.gitignore` / 构建产物 / 既有 T006-T037C 任何台账条目 / 既有 TD-001 ~ TD-018 任何条目。

## T038 状态备注（真实音频 MVP Release Checkpoint 文档收口 + 23 个格式漂移文件记录）

- **T038 任务定位**：`T038_REAL_AUDIO_MVP_RELEASE_CHECKPOINT` 是 T037D 之后的真实音频 MVP Release Checkpoint 文档收口任务，**仅**完成文档收口 + 真实音频 MVP 阶段 Release 构建产物（Debug APK + Release APK + Release AAB）落盘 + 麦克风首次权限流程真机验收（真实表现记录，**不**强制要求 PASS）+ 格式漂移审计（只读，**不**在 T038 越界修复），**不**新增任何自动化测试 / 修改生产代码 / 修改签名配置 / 修改 Manifest / 修改 schema / 修改依赖 / 修改 `key.properties` / `.gitignore` / 任何 `test/**/*.dart` 文件 / 任何 `lib/**/*.dart` 文件。
- **T038 任务边界（强制）**：
  - 允许修改 **5 个文档**（4 个已修改 + 1 个新建）：`docs/qa/REAL_AUDIO_MVP_RELEASE_CHECKPOINT.md`（新建）+ `docs/qa/REAL_AUDIO_ANDROID_ACCEPTANCE.md`（追加 Permission Acceptance Results 段）+ `docs/dev/TASK_LEDGER.md`（追加本 T038 任务条目）+ `docs/dev/AGENT_QUALITY_METRICS.md`（追加 T038 Scorecard 条目）+ 本 TECH_DEBT 段（**仅**追加，不修改既有任何条目）；`git diff --name-only` 应显示这 **5 个文件**（4 个 `M` + 1 个 `??`），**不**是"仅 4 个"。
  - 禁止修改：生产代码 / 测试 / Gradle / Manifest / pubspec / `key.properties` / `app_database.g.dart` / 版本号（`pubspec.yaml` 中 `version: 1.0.0+2` 不动）/ `.gitignore` / 构建产物 / 任何已存在的 `lib/**/*.dart` 或 `test/**/*.dart` 文件。
  - 不 push / 不 tag / 不 amend / 不 rebase / 不 reset --hard。
- **T038 格式漂移审计（只读）**：使用 `dart format --output=none --set-exit-if-changed lib` 进行审计（**不**保留任何格式化修改）→ 输出 23 个存在格式漂移的 Dart 文件路径（与 `T037_REAL_AUDIO_MVP_RELEASE_CHECKPOINT` 任务描述一致）：
  1. `lib/app/router.dart`
  2. `lib/features/chord_library/application/chord_library_controller.dart`
  3. `lib/features/chord_library/data/built_in_chords.dart`
  4. `lib/features/chord_library/presentation/widgets/chord_diagram.dart`
  5. `lib/features/metronome/application/metronome_controller.dart`
  6. `lib/features/metronome/domain/metronome_settings.dart`
  7. `lib/features/metronome/presentation/metronome_page.dart`
  8. `lib/features/metronome/presentation/widgets/beats_per_bar_selector.dart`
  9. `lib/features/metronome/presentation/widgets/bpm_controls.dart`
  10. `lib/features/metronome/presentation/widgets/metronome_display.dart`
  11. `lib/features/metronome/presentation/widgets/metronome_start_stop_button.dart`
  12. `lib/features/recording/domain/self_rating.dart`
  13. `lib/features/single_note_practice/application/single_note_practice_controller.dart`
  14. `lib/features/single_note_practice/presentation/widgets/single_note_position_diagram.dart`
  15. `lib/features/tuner/application/tuner_controller.dart`
  16. `lib/features/tuner/data/standard_ukulele_tuning.dart`
  17. `lib/features/tuner/domain/tuning_string.dart`
  18. `lib/features/tuner/presentation/tuner_page.dart`
  19. `lib/features/tuner/presentation/widgets/tuner_disclaimer.dart`
  20. `lib/features/tuner/presentation/widgets/tuning_progress.dart`
  21. `lib/features/tuner/presentation/widgets/tuning_string_card.dart`
  22. `lib/shared/services/audio_file_storage_paths.dart`
  23. `lib/shared/services/audio_file_storage_service.dart`
- **格式漂移影响分析（仅只读审计，不在本任务越界）**：① 这些文件**仅**是格式差异（缩进 / 行宽 / 字符串引号 / 尾随逗号），**不**影响 `flutter analyze` / `flutter test`（analyze 通过、698 项测试通过）；② 这些格式漂移是历史遗留（T006 ~ T037 系列累计未跑 `dart format`），**不**属于 T038 范围；③ 建议后续独立 Task ID：`T038A_FIX_DART_FORMAT_DRIFT_BATCH_FORMAT`（批量格式化 23 个文件 + 单条 commit，**不**与 T038 合并）；④ T038 **不**批量格式化，**不**写入任何修改，**不**触发 `dart format lib` / `dart format --set-exit-if-changed lib` 之外的修改；⑤ T038 **不**声称全仓库 `dart format --set-exit-if-changed lib` 已经通过（事实上 23 个文件存在格式漂移）。
- **T038 麦克风首次权限流程真机验收（真实表现，**不**强制 PASS）**：① 已征求用户授权仅撤销 `RECORD_AUDIO` 权限（`adb shell pm revoke com.yupi.ukulele android.permission.RECORD_AUDIO`），**不**卸载 App、**不**清除数据（`ukulele.db` + `audio/saved` + `audio/temp` 目录均保留）；② 启动 App → 进入录音页 → 点击"开始录音"；③ 真实表现：**首次"开始录音"未出现系统权限弹窗，App 直接进入录音状态**（`RECORD_AUDIO: granted=true` 在用户操作后被重新授予）；④ 这是 HUAWEI CDY-AN90 / Android 10 + EMUI + `permission_handler 12.0.3` 在 `pm revoke` 后的真实设备行为 —— 既不是 PASS 也不是 FAIL，是"ROM 实际行为与 T037 既有 `permission_handler` 单元测试预期不一致"；**关键**：`granted=false` → `granted=true` 的自动变化是 EMUI ROM 直接授权行为，**不**等价于"用户完成首次权限申请"，**不**得写为 PASS；⑤ **T038 不**强制要求 PASS；⑥ 既不"卸载重装"也不"`adb install --force-reinstall`"也不"`pm reset-permissions`"绕过 ROM 行为 —— 这些动作会清除数据或破坏 T037 既有数据隔离；⑦ T038 **不**修复 ROM 行为，**不**修改 `permission_handler` 依赖版本，**不**修改 `MicrophonePermissionService` 公共契约；⑧ T038 整体 Checkpoint 状态 = **PENDING / NOT APPROVED**（`BLOCKED_BY_PERMISSION_ACCEPTANCE`），构成 `Permission first-request acceptance unresolved` Blocker；⑨ 建议后续独立 Task ID：`T038B_FIX_PERMISSION_FIRST_REQUEST_REAL_DEVICE_PROMPT`（真机厂商 ROM 适配 / `permission_handler` 升级评估 / 在不同 ROM 上真机验收）—— **必须先**完成 T038B 再启动 Go / No-Go。
- **T038 真实音频 MVP Release Checkpoint 矩阵**：核对并记录 19 项关键指标（详见 `docs/qa/REAL_AUDIO_MVP_RELEASE_CHECKPOINT.md` "Real Audio Checkpoint Matrix" 节）；每项标记 PASS / FAIL / NOT RUN / BLOCKED。
- **T038 Release 构建产物落盘**：
  - Debug APK：`build/app/outputs/flutter-apk/app-debug.apk`（175.5 MiB / 184,009,867 bytes / 15.4s / debug keystore）
  - Release APK：`build/app/outputs/flutter-apk/app-release.apk`（58.1 MiB / 60,932,526 bytes / 113.9s / `signingConfigs.release` 配置使用 `key.properties`）
  - Release AAB：`build/app/outputs/bundle/release/app-release.aab`（57.8 MiB / 60,566,100 bytes / 12.1s / `signingConfigs.release` 配置使用 `key.properties`）
  - 全部 **PASS**（Gradle 任务 BUILD SUCCESSFUL）；Kotlin 增量缓存关闭 Suppressed 异常（C:\Users\Administrator\AppData\Local\Pub\Cache ↔ E:\yupi-Projects\ukulele_app\android 跨盘符）为 I/O 警告，**不**影响最终 APK / AAB 产物。
- **T038 静态确认（最终验证后）**：① `flutter analyze` `No issues found!`；② `flutter test` 全量 `+698: All tests passed!`；③ `git status --short` 工作区 clean；④ `schemaVersion` 仍为 2（`lib/data/database/app_database.dart:92` `int get schemaVersion => 2;`）；⑤ `pubspec.yaml` / `pubspec.lock` **未**修改（`version: 1.0.0+2` 不变）；⑥ `app_database.g.dart` **未**修改；⑦ 三处 Manifest 注释明确 "no INTERNET permission"（`android/app/src/main/AndroidManifest.xml:2` + `android/app/src/debug/AndroidManifest.xml:2` + `android/app/src/profile/AndroidManifest.xml:2`）；⑧ `key.properties` / `.jks` / `keystore` **未**被跟踪（`.gitignore` 已有 `*.jks` + `key.properties` + `android/key.properties`）；⑨ APK / AAB / build 输出 **未**被跟踪（`.gitignore` 已有 `/build/` + `*.apk` + `*.aab`）；⑩ 生产代码 / 测试 0 修改。
- **T038 Reviewers Approved**（read-only）：**Flutter Release Reviewer** Approved（针对构建产物 / Matrix 中 18 项 PASS）+ **Android Signing Reviewer** Approved（针对签名安全 / 构建产物 / `key.properties` 内容未读取 / T021 路径问题未复现）+ **Audio QA Reviewer** **Conditional Approval + Blocker**（针对构建产物 + 真实音频既有闭环 4 步 PASS；针对整体 Checkpoint 给出 `Permission first-request acceptance unresolved` Blocker —— `granted=false` → `granted=true` 是 EMUI ROM 直接授权行为，**不**等价于"用户完成首次权限申请"，**不**得写为 PASS）+ **Compliance Reviewer** **Conditional Approval + Blocker**（针对脱敏 / 不读取签名秘密 / 不修改任何配置 / 不扩大范围 / 23 个格式漂移标记为独立任务 / 不绕过 EMUI 行为；针对整体 Checkpoint 给出 `Permission first-request acceptance unresolved` Blocker —— 整份 Checkpoint **不**得写为 Approved）。4 个 Reviewer 必须确认：① 权限结果来自用户真机反馈（**不**是 Agent 代写 PASS）；② Release 构建结果真实（Kotlin 跨盘符异常 Suppressed **不**影响产物）；③ **未**读取或泄露 `key.properties` / keystore / 密码 / alias；④ APK / AAB / build 目录**未**被 git 跟踪；⑤ Checkpoint 没有扩大结论（**不**声称 Release APK 已上架 / **不**声称 iOS 已验收 / **不**声称全 ROM 兼容 / **不**写为整体 Approved）；⑥ 格式漂移被记录为独立代码卫生事项（23 个 Dart 格式漂移延后独立处理，**不**与 T038 合并）**未**越界修改；⑦ `T038A_FIX_WINDOWS_RELEASE_SIGNING_PATH` 名称**继续保留**给 Windows 签名路径问题，本次 T038 未触发，**不**得将 T038A 用于格式化任务。
- **T038 状态决策**：
  - **若权限流程关键项 NOT RUN（因 ROM 实际行为与预期不一致）+ Debug APK PASS + Release APK PASS + Release AAB PASS + 698 测试 PASS + Reviewers Approved + 仅文档变化**：Checkpoint **PENDING / NOT APPROVED**（`BLOCKED_BY_PERMISSION_ACCEPTANCE` —— `Permission first-request acceptance unresolved` Blocker 仍在；T038 整体**不**通过；**不**得写为 Approved）。
  - **若 Release APK / AAB FAIL 或权限流程关键项 FAIL 或 698 测试 FAIL 或有 Blocker**：Checkpoint **不通过**；可输出失败报告；**不**提交"通过"Checkpoint；**不**push / tag；推荐独立修复任务。
  - **T038 当前决策**：T038 整体 = **PENDING / NOT APPROVED**（`BLOCKED_BY_PERMISSION_ACCEPTANCE`）—— 构建与签名检查全部 PASS + 真实音频既有闭环人工验证 PASS + Flutter Release / Android Signing Approved + Audio QA / Compliance Conditional Approval + Blocker；首次权限申请仍为 NOT RUN / 设备行为异常；总 Blocker 数 = **1**（`Permission first-request acceptance unresolved`），**不**是"0 Blockers"。
- **遗留技术债（不属于本任务范围）**：① 23 个 Dart 文件格式漂移（建议独立 `T038A_FIX_DART_FORMAT_DRIFT_BATCH_FORMAT`）；② 真实设备权限首次申请 ROM 行为与 `permission_handler 12.0.3` 单元测试预期不一致（建议独立 `T038B_FIX_PERMISSION_FIRST_REQUEST_REAL_DEVICE_PROMPT`）；③ 国产 ROM 兼容性（HUAWEI / 小米 / OPPO / vivo / 三星）必须由真机用户验收 —— 本任务**不**越界覆盖（指向 `docs/qa/REAL_AUDIO_ANDROID_ACCEPTANCE.md` 单设备限制）；④ App 启动时清理孤儿 temp 文件的机制**未**实现（`AudioFileStorageService.ensureDirectories` 只确保目录存在，不扫描 stale `temp/*.m4a`）；⑤ native 录音 / 播放 stop 失败后是否真的停止仍依赖 service-layer 反馈（service 抛错 = black-box，native 仍可能在跑）；⑥ Crash / ANR / `am_crash` 等 Native 信号需要引入 `flutter_driver` / `integration_test` 端到端 crash hook 或 Sentry 等崩溃监控。

### T038B 追加状态备注 (2026-06-24)

- **T038B 任务范围**：T038B 完成用户可见文案统一 ("麦克风权限已拒绝" 替换"麦克风权限已永久拒绝", denied / permanentDenied 两状态文案完全相同) + 新增"前往系统设置"引导面板 (文案"请前往系统设置开启麦克风权限后重试") + 新增 `controller.openAppSettings()` (委托既有 `MicrophonePermissionService.openSettings()` → `permission_handler.openAppSettings()` 官方 API) + 新增 `controller.refreshPermissionStatus()` (重新读权限, **不**自动开始录音) + page 端 `WidgetsBindingObserver` 在 `AppLifecycleState.resumed` 时自动重检权限。
- **T038B 实际修改文件**: 4 个 lib/test + 5 个 doc + 1 个新 doc = 10 个文件; 严格守住范围, **不**修改 pubspec / Manifest / Gradle / Drift / 录音服务 / 播放服务 / 存储服务 / INTERNET 权限 / 版本号 / `key.properties` / `.gitignore` / keystore。
- **T038B 自动化测试**: 711 项通过 (基线 698 + T038B 新增 13); `flutter analyze` clean; 4 个 Reviewer 全部 Approved, 0 Blocker。
- **T038B 真机验证 (HUAWEI CDY-AN90 / Android 10 / API 29)**: 8/8 项用户逐项确认通过; 既有 2 个 temp m4a + ukulele.db + flutter_assets + res_timestamp-* 完整保留。
- **T038 Blocker 影响**: `Permission first-request acceptance unresolved` 标记为 **RESOLVED**; T038 Release Checkpoint 状态由 PENDING / NOT APPROVED (BLOCKED_BY_PERMISSION_ACCEPTANCE) 升级到 **READY_FOR_GO_NO_GO_REVIEW** (**不**自动写为 Approved; 由 GPT 首席架构师复审后决定)。
- **T038B 详细文档**: `docs/qa/REAL_AUDIO_T038B_QA.md` (本任务新建 doc, 完整证据 + 根因分析 + 三步反思 + T038 Blocker 解决条件核对 + 后续建议)。

## T038C 状态备注（真实音频 MVP Release 最终 Go / No-Go 决定 + 文档收口）

- **Task ID**: `T038C_REAL_AUDIO_PHASE_RELEASE_GO_NO_GO`。
- **起始 Commit**: `ffd1b927c8f8964821110ab4da220df7338f42ec`（与 HEAD 严格匹配）。
- **HEAD（最终）**: `ffd1b927c8f8964821110ab4da220df7338f42ec`（T038C **不** 引入新代码 commit；仅 4 个 doc 追加段，1 个 commit = `docs: approve real audio MVP release checkpoint`）。
- **任务定位**: 对 T038B 生产代码（`18557ab..ffd1b92`）作最终 Go / No-Go 决定；**不**新增功能 / 自动化测试 / 依赖 / schema / Manifest / Gradle / pubspec / `key.properties` / `.gitignore` / keystore。
- **启动条件**: HEAD = `ffd1b92` / `git status --short` clean / `git branch --show-current` = `master` 全部满足 ✓。
- **核心审查 8 项**全部 PASS:
  1. `_openingAppSettings` (controller) vs `_openingSettings` (page) 职责**不**重复 / **不**死锁 = PASS（controller guard 守护平台调用，page guard 驱动 UI "打开中…" 状态；page `resumed` 释放 + controller `refreshPermissionStatus` 释放 + OS 拒绝启动时两处本地释放）。
  2. `WidgetsBindingObserver` 正确注册 / 注销 / 处理 mounted = PASS（`initState:128` / `dispose:132-137` / `didChangeAppLifecycleState:140-160` `mounted:149` 检查）。
  3. 从系统设置返回**只**刷新权限，**不**自动开始录音 = PASS（T025 / T031 "无权限自动开始" 契约保留）。
  4. 双击 / 快速返回 / 异步异常受控 = PASS（page + controller 双层 guard + `try/catch` 覆盖 + `lastError` **仅**含友好提示，**无**绝对路径 / 异常类名 / PII）。
  5. denied / permanentDenied 内部语义保留 = PASS（`RecordingPermissionStatus.permanentDenied` enum 保留为独立值；`statusLabel` **仅**统一用户可见文案；page `_PermissionDeniedGuidance` 显式覆盖**两**状态，是 T038B 文档化设计契约）。
  6. 用户文案**不**出现 "永久拒绝" = PASS（`lib/` 全量搜索 7 处命中**全部**为 Dartdoc / 注释引用，**无**任一命中为用户可见 `Text` Widget；`_PermissionDeniedGuidance` 用户文案 = "请前往系统设置开启麦克风权限后重试"）。
  7. 过度实现 / 重复代码 / Release 风险 = PASS（T038B **仅**新增 1 controller guard + 1 page guard + 1 `_PermissionDeniedGuidance` widget + 1 observer mixin + 2 controller method，**无**重复逻辑 / **无**死代码 / **无**范围蔓延）。
  8. T038B 8/8 真机结果**准确**引用 = PASS（`docs/qa/REAL_AUDIO_T038B_QA.md:43` 准确记录；T038C **不**重复要求**无**必要的人工验收）。
- **验证 7 项**全部 PASS:
  1. 定向测试 = PASS（`All tests passed!` 146 controller + 4 page 增量）。
  2. `flutter analyze` = PASS（`No issues found! (ran in 5.2s)`）。
  3. `flutter test` 精确 711 = PASS（`+711: All tests passed!`）。
  4. `flutter build apk --debug` = PASS（`app-debug.apk` 184,021,570 bytes / 175.5 MiB）。
  5. `flutter build apk --release` = PASS（`app-release.apk` 61,064,006 bytes / 58.2 MiB）。
  6. `flutter build appbundle --release` = PASS（`app-release.aab` 60,586,356 bytes / 57.8 MiB）。
  7. `git diff --check` = **⚠️ 非阻塞**（TASK_LEDGER.md:175 命中 1 处 trailing whitespace = T038B commit `ffd1b92` 既有遗留，**不**本任务引入，**不**构成 Blocker）。
- **关键确认 9 项**全部 PASS: 精确 711 / 三类构建成功 / 既有 release signing / 签名秘密零泄露 / `schemaVersion=2` / 版本号 1.0.0+2 / 三处 Manifest 无 INTERNET / APK AAB build key.properties 未跟踪 / T038B 8/8 准确引用。
- **Reviewer 结论**:
  - **Flutter / Audio Reviewer**: **Conditional Approval**（1 项**非** Blocker 观察 = `startRecording` 对 `permanentDenied` **未**短路调用 `openAppSettings`，属 T038B 文档化契约预期行为，page `recording_page.dart:228-235` 明确说明"用户应使用前往系统设置按钮"，**不** 构成 Release Blocker；T038B 任务定位**不**修改 `startRecording` 路径，**不**在 T038C 顺手修复 —— brief 明令"**不**在本任务顺手修复"）。
  - **Android Release / Compliance Reviewer**: **Approved**（Manifest / schema / 版本号 / 签名完整 / 签名秘密卫生 / 8/8 真机引用 / 单设备覆盖披露 8 项**全部** Approved；**唯一**非阻塞建议 = 追加 `*.apk` + `*.aab` 显式模式到 `.gitignore` 以匹配 doc 声明，但 `/build/` 已覆盖所有 APK / AAB 输出路径，`git check-ignore` 验证**全部**被 ignore，**不**构成 Blocker；建议**未来**独立 code-hygiene 任务追加显式模式作为防御纵深）。
- **任一 Reviewer 有 Blocker 则 NO-GO**: **未**发现 Blocker。**Decision = GO**。
- **T038C 修改文件范围**（**仅** 4 doc 文件）:
  1. `docs/qa/REAL_AUDIO_MVP_RELEASE_CHECKPOINT.md` T038C Decision 段（追加）。
  2. `docs/dev/TASK_LEDGER.md` T038C 行（追加，在 T038B 行**前**）。
  3. `docs/dev/AGENT_QUALITY_METRICS.md` §4.27 T038C Scorecard（追加）。
  4. `docs/dev/TECH_DEBT.md` T038C 状态备注段（本段，追加）。
  **不**修改既有 19 项 Matrix / Build Verification / Signing Result / Format Drift Audit / T038B 追加段 / 4.1 ~ 4.26 任何 Scorecard / TD-001 ~ TD-019 任何条目。
- **T038C 净增 0 项自动化测试 / 0 项生产代码改动 / 0 项依赖改动 / 0 项 schema 改动 / 0 项 Manifest 改动 / 0 项 Gradle 改动 / 0 项 `key.properties` 改动 / 0 项 keystore 改动**。
- **T038 Permission first-request Blocker 影响**: **RESOLVED**（T038B 已 RESOLVED，T038C 验证保持）。T038 Release Checkpoint 状态 PENDING / NOT APPROVED → T038B READY_FOR_GO_NO_GO_REVIEW → T038C **APPROVED**。
- **T038C 未 push / 未 Tag / 未 amend / rebase / reset --hard / 未读取 `key.properties` / 未读取 keystore 密码 / alias / 敏感路径 / 未声称 Release APK 已上架 / iOS 已验收 / 全 Android ROM 兼容 / 权限首次申请已通过**。
- **T038C 详细文档**: `docs/qa/REAL_AUDIO_MVP_RELEASE_CHECKPOINT.md` T038C 追加段（启动条件核对 + 核心审查 8 项 + 验证 7 项 + 关键确认 9 项 + Reviewer 2 个 + Decision = GO + Remaining Blockers = 0 + 下一任务 = T039）+ `docs/dev/TASK_LEDGER.md` T038C 行 + `docs/dev/AGENT_QUALITY_METRICS.md` §4.27 T038C Scorecard + `docs/dev/TECH_DEBT.md` T038C 状态备注段（本段）= 4 个 doc 文件。
- **下一任务**: `T039_REAL_AUDIO_MVP_VERSION_TAG_AND_PUSH`（brief 指定 GO 后下一任务即此；T038C Decision = **GO** ✓ → 启动 T039）。

## TD-021: T039 真实音频 MVP v1.1.0 版本号 bump + `v1.1.0` annotated tag + `master` 与 tag 原子 fast-forward push — 闭环说明

- **范围**: T039 是 T038C Decision = **GO** 后的发布执行任务。**仅** 4 文件:
  1. `pubspec.yaml` `version: 1.0.0+2` → `1.1.0+3`（**仅**此 1 字段，**不**改 `environment` / `dependencies` / `dev_dependencies` / `flutter` 配置）。
  2. `docs/qa/REAL_AUDIO_MVP_V110_RELEASE_CHECKPOINT.md` 新建（Document Status + Starting Commit + Device + Version Bump + Verification Results + Git Divergence Status + Commit Plan + Out of Scope）。
  3. `docs/dev/TASK_LEDGER.md` T039 行（追加在 T038B 行**后**）。
  4. `docs/dev/TECH_DEBT.md` TD-021 本段（追加）。
- **测试基线**: **711** 项 `flutter test` 通过（与 T038B / T038C 完全一致；T039 **不**新增 / 删除任何自动化测试）。
- **构建产物（重新构建确认）**:
  - Release APK = 61,064,006 bytes / 58.2 MiB / `apksigner verify` exit 0 / schemes v2 + v3 + v4 / cert SHA256 = `e88687e53b272c86d20611c1045fc00d2fd4ca321672b1eec180d7543dc28591`（与 Debug 证书 differ = true）。
  - Release AAB = 60,586,365 bytes / 57.8 MiB / `jarsigner -verify` exit 0。
  - `[AAPT] applicationId=com.yupi.ukulele versionName=1.1.0 versionCode=3` ✅ 与 `pubspec.yaml` 一致。
  - `flutter analyze` No issues found!（7.0s）✅。
  - `git diff --check` exit 0 ✅（T039 本身**不**引入格式漂移）。
- **关键确认 10 项**全部 PASS: 精确 711 / Release APK 重建 / Release AAB 重建 / 既有 release signing 完整 / 签名秘密零泄露 / `schemaVersion=2` 不变 / 三处 Manifest 无 INTERNET / `key.properties` / `*.jks` / `*.keystore` / `build/app/outputs/**` 全部 git untracked + gitignore `!!` / T022 verifier 3 项 FAIL 为 v1.1.0 预期差异 / T039 **不**新增 / 移除 `INTERNET` / **不**改 Manifest / Gradle / Drift schema / 签名配置。
- **T022 verifier 行为校准**: `dart run tool/verify_release_artifacts.dart` 输出 3 项 FAIL = `versionName mismatch: expected 1.0.0, got 1.1.0` + `versionCode mismatch: expected 2, got 3` + `Forbidden permission declared in Manifest: android.permission.RECORD_AUDIO`。这 3 项**正是 v1.1.0 相对 v1.0.0 的预期差异**，不构成 Blocker: ① 版本号 mismatch 是 v1.1.0 release 的目的而非缺陷; ② `RECORD_AUDIO` 在 v1.0.0 时代被列入 forbidden 是因为 T022 当时尚无真实音频能力, v1.1.0 已落地真实音频 MVP (T030~T038B), `RECORD_AUDIO` 是**必需**权限; ③ Release 证书 + 产物存在性 + v2/v3/v4 scheme + Release 与 Debug 证书差异 4 项**真正**关键的安全 / 签名检查**全部** PASS。T039 **不**升级 T022 verifier (越界, 留待 T040+) — T022 verifier 是 T022 阶段的产物, 与 v1.0.0 基线硬编码耦合, 升级它需要独立任务评估完整改动面。
- **T039 Git 启动条件核对** (与 T038C 一致 + v1.1.0 tag 缺席校验):
  1. `git rev-parse HEAD` = `cb28bca40460d5dd5ae4bdbe413bf7b4302423ab` ✅ 严格匹配基线。
  2. `git status --short` 在 `pubspec.yaml` 修改前 clean ✅。
  3. `git branch --show-current` = `master` ✅。
  4. `git remote get-url origin` = `https://github.com/yyd841122/ukulele_app_claude` ✅ 与预期一致。
  5. `git fetch origin` 后 `git merge-base --is-ancestor origin/master master && echo ANCESTOR_OK_AFTER_FETCH` 输出 `ANCESTOR_OK_AFTER_FETCH` ✅。
  6. `git rev-list --left-right --count master...origin/master` = `30    0` ✅ Local-only ahead (非真正分叉)。
  7. `v1.1.0` 在本地 / 远程均**不存在** (`git rev-parse v1.1.0` 报 fatal unknown revision + `git ls-remote origin refs/tags/v1.1.0*` 返回空) ✅。
  8. `v1.0.0-release` (peeled 703d2aa) + `v0.1.0-mvp` (peeled d49ce4b) 本地与远程均**未变** ✅。
- **T039 Commit Plan** (release commit **必须**包含 `pubspec.yaml` + 3 个 doc 全部 4 文件, 保持提交自包含):
  1. `git add pubspec.yaml docs/qa/REAL_AUDIO_MVP_V110_RELEASE_CHECKPOINT.md docs/dev/TASK_LEDGER.md docs/dev/TECH_DEBT.md`
  2. `git commit -m "chore: release v1.1.0"`
  3. `git tag -a v1.1.0 -m "Real audio MVP release v1.1.0"`
  4. `git fetch origin` (再次)
  5. `git merge-base --is-ancestor origin/master master && echo ANCESTOR_OK_BEFORE_PUSH` (再次)
  6. **AskUserQuestion** 获得用户明确 push 授权
  7. `git push origin master v1.1.0` (原子推送, **不**加 `--force` / `--force-with-lease`)
  8. push 后验证: `git ls-remote origin master refs/tags/v1.1.0 refs/tags/v1.0.0-release refs/tags/v0.1.0-mvp` + `git tag -n3 v1.1.0` + `git status` clean
- **Push 风险评估**:
  - origin 顶端 (`703d2aa`) 是本地 HEAD (`cb28bca`) 的严格祖先 → **fast-forward** ✅ 不需要 `--force`。
  - `v1.0.0-release` (peeled 703d2aa) 与 `v0.1.0-mvp` (peeled d49ce4b) 均不在 30 个新提交 + 1 个 release commit 内 → push 后保持原位**不动** ✅。
  - `v1.1.0` 本地先创建 (annotated), push 与 master 原子同步 → push 后远程 tag 指向 release commit, peeled commit 与 tag 同一 SHA ✅。
  - **数据丢失风险 = 0**。
- **T039 范围限制 (明确不做)**:
  - ❌ rebase / amend / reset / force push / 修改旧提交邮箱
  - ❌ `git gc --prune=now` (会销毁 14 个不可达 commit + 悬空对象, 越界)
  - ❌ T022 verifier 升级 (越界, 留待 T040+)
  - ❌ GitHub Release 创建 / APK / AAB 上传
  - ❌ INTERNET 权限新增 / 移除
  - ❌ Manifest / Gradle / Drift schema / 签名配置修改
  - ❌ 生产代码 / 测试代码 / 依赖 / `pubspec.lock` / `key.properties` / `.gitignore` 修改
  - ❌ 清理悬空对象 / 技术债批量处理
- **T039 净增**: 1 个版本号字段变更 + 1 个 release commit + 1 个 annotated tag (`v1.1.0`) + 3 个 doc 文件 (1 新建 + 2 追加) = **0 项自动化测试 / 0 项生产代码改动 / 0 项依赖改动 / 0 项 schema 改动 / 0 项 Manifest 改动 / 0 项 Gradle 改动 / 0 项 `key.properties` 改动 / 0 项 keystore 改动**。
- **T039 Self-Critique 三步反思**:
  - **Step 1 初步实现** — 启动核对 8 项 + 验证 9 项 + 关键确认 10 项 + Commit Plan 8 步 + Push 风险 4 项 + Out of Scope 8 类。
  - **Step 2 自我找茬** (≥ 3 边界):
    1. T022 verifier 3 项 FAIL **不是** Blocker — 是 T022 硬编码 v1.0.0 基线 + v1.1.0 故意 bump 版本 + 真实音频 MVP 必需 `RECORD_AUDIO` 三个**预期**差异的乘积; T039 **不**改 verifier (越界, 留待 T040+ 评估完整改动面)。
    2. push 前**必须**重新 fetch + 验证 `merge-base --is-ancestor` — 防止 30 个本地提交被 origin 端其他人 force-push 改写后**误**以为仍是 fast-forward, 导致本地推一个**不**是 ancestor 的"祖先"而触发远端 non-fast-forward 拒绝。
    3. 推送必须**原子** `git push origin master v1.1.0` 而非分两次 push (master 先 / tag 后) — 分两次会在两次推送之间留出"tag 指向本地未推送 commit" 的中间状态, 期间若其他人 force-push origin/master, 远端 `v1.1.0` tag 会指向一个**被回滚**的 commit, 产生幽灵 tag。
    4. tag 必须 annotated 而非 lightweight — `git tag -a v1.1.0 -m "..."` 与 `git tag v1.1.0` 语义不同: annotated tag 携带 tagger + date + message (GitHub Releases UI 默认展示 annotated), lightweight 仅为一个 ref 指针; T039 明令 annotated。
    5. **不**自动 push — 必须 AskUserQuestion 获得用户明确授权 (brief 明令"未经授权不得push"); 即使所有验证都 PASS, push 动作本身有远端副作用, 必须由用户拍板。
    6. `pubspec.lock` 是否随版本号变更**自动**变化 — Flutter pub 在 `version:` 字段变更时**不**自动修改 lock (`pubspec.lock` 仅在 dependency 增删或 `flutter pub upgrade` 时变化), T039 仅 bump version → lock **不**变 → diff **不**含 lock → **不**误锁依赖, 但需**不**运行 `flutter pub upgrade` (越界)。
    7. `flutter build apk --release` 警告"Kotlin Gradle Plugin 将在未来版本引发构建失败"是**预先公告**而非当前 Blocker (T038C / T038B 既有警告一致), **不**在 T039 修复 (越界, 留待 KGP → Built-in Kotlin 迁移独立任务)。
    8. `app_database.g.dart` 是否会被 `flutter build` 触发重新生成 — Drift `build_runner` **不**在 `flutter build apk/appbundle` 期间自动触发, 仅 `dart run build_runner build` / `watch` 才生成; T039 **不**运行 `build_runner`, **不**改 `app_database.g.dart`。
  - **Step 3 终极交付** — Version = `1.1.0+3`, Tag = `v1.1.0` (annotated, message = `Real audio MVP release v1.1.0`), Commit message = `chore: release v1.1.0` (含 `pubspec.yaml` + 3 个 doc = 4 文件), Push = 原子 fast-forward `git push origin master v1.1.0`, Reviewer 数量 = 2 (Release/Git Reviewer + Compliance Reviewer)。
- **T039 详细文档**: `docs/qa/REAL_AUDIO_MVP_V110_RELEASE_CHECKPOINT.md` (新建) + `docs/dev/TASK_LEDGER.md` T039 行 (追加) + `docs/dev/TECH_DEBT.md` TD-021 段 (本段, 追加) = 3 个 doc 文件 + `pubspec.yaml` 版本号 bump = 4 文件。
- **下一任务**: T039 push 成功后, 建议 T040+ 方向: ① T022 verifier 升级至 v1.1.0 基线 (移除硬编码 1.0.0+2 与 `RECORD_AUDIO` forbidden); ② `.gitignore` 追加 `*.apk` + `*.aab` 显式模式作为防御纵深 (T038C Reviewer 提示); ③ KGP → Built-in Kotlin 迁移 (T038C flutter build 警告); ④ iOS TestFlight 闭环 (TD-003); ⑤ 国产 ROM 兼容性补测 (TD-013, 小米 / OPPO / vivo / 三星)。

## TD-022: T040 T022 Release 验证器 v1.1.0 升级闭环说明（T022 verifier 过期问题 Resolved）

- **问题**：T022 阶段的 Release 验证器（`tool/verify_release_artifacts.dart`，由 commit `4b5b386` 落地）与 v1.0.0 真实音频模拟基线硬编码耦合：① `_expectedVersionName = '1.0.0'` / `_expectedVersionCode = '2'` 直接写死版本号；② `_forbiddenPermissions` 包含 `android.permission.RECORD_AUDIO`（v1.0.0 时代为禁项）。当 v1.1.0 真实音频 MVP 发布（`pubspec.yaml` `version: 1.1.0+3` + Manifest 声明 `RECORD_AUDIO`）后，T022 验证器对 v1.1.0 APK / AAB 必然报 3 项 "FAIL"（versionName 1.0.0→1.1.0 / versionCode 2→3 / `RECORD_AUDIO` forbidden）—— 这是 **v1.1.0 相对 v1.0.0 的预期差异**，T039 显式记录为"3 项 FAIL 均为预期差异、不构成 Blocker"，但 T039 **不**升级 verifier（越界，留待 T040+）。
- **影响**：T022 验证器对 v1.1.0 APK / AAB 不再可用；T022 verifier 升级是 v1.1.0 发布后必做的"工具同步"任务；T039 任务定位**不**触动 verifier（T039 是 v1.1.0 版本号 bump + tag + push 的发布执行任务，verifier 升级属独立任务）；如 verifier 长期不升级，每次 v1.x.y 版本号 bump 都需要手工判断"FAIL 是否是版本 bump 预期差异"，增加误判风险。
- **优先级**：中（不阻塞 v1.1.0 发布 / 验收 / 真机 / 商店；T039 已显式记录 verifier FAIL 为预期差异；T040 已升级 verifier，问题已闭环）。
- **建议处理阶段**：T040 `T040_ALIGN_RELEASE_VERIFIER_WITH_V110`。
- **状态**：**Resolved**（T040 已完成）。
- **T040 解决内容（闭环）**：
  1. **版本号从 `pubspec.yaml` 实时读取**（**不**再硬编码）：新增 `_ExpectedVersion` 值类型 + `parseExpectedVersion(String pubspecContents)` 顶层函数（暴露作 testable 表面，接收 pubspec 字符串内容，返回 `_ExpectedVersion?`） + `_loadExpectedVersion()` 私有辅助（从磁盘 `pubspec.yaml` 读 → 调 `parseExpectedVersion` → 失败抛 `_FailFast` 翻译为 exit code 2）；`_assertPackageIdentity` 签名改为 `(_PackageIdentity pkg, _ExpectedVersion expected)`，对比 `pkg.versionName == expected.name` / `pkg.versionCode == expected.code`。
  2. **`RECORD_AUDIO` 从 forbidden 移至 required**：`_forbiddenPermissions` 仅剩 `android.permission.INTERNET`；新增 `_requiredPermissions = ['android.permission.RECORD_AUDIO']` + `_assertRequiredPermissions(perms)` 函数（任一必需权限缺席即 fail）；`main()` 流程中先 `assertForbiddenPermissions` 后 `assertRequiredPermissions`。
  3. **APK/AAB 存在性、Release 签名、Debug/Release 证书差异** 三项既有检查**完全保留**（不破坏 T022 既有契约）：`_verifyApkSignature` / `_verifyAabSignature` / `_compareDebugCertificate` 三函数**未**改动。
  4. **9 项 `parseExpectedVersion` 单元测试**（`test/tool/verify_release_artifacts_test.dart`，**新建**）：① v1.1.0+3 精确解析；② 真实 pubspec 形状 + leading whitespace；③ 单引号字面量；④ 双引号字面量；⑤ 缺 version 行返回 null；⑥ 非数字 build code 返回 null；⑦ 字母 version name 返回 null；⑧ 缺 `+` 分隔符返回 null；⑨ v1.0.0+2 严格不等于 v1.1.0+3（**不**允许旧版本静默通过）。
  5. **header 注释升级**：T022 → `T040_RELEASE_VERIFIER_V110_ALIGNMENT`。
- **T040 验证结果**：
  - 验证器对 v1.1.0 APK / AAB 输出 **`VERIFY_OK: all required checks passed.`**（APK 61064006B / AAB 60586365B，`versionName=1.1.0` / `versionCode=3`，签名 v2/v3/v4，INTERNET 缺席，RECORD_AUDIO 已声明，Release/Debug 证书不同）。
  - `flutter test test/tool/verify_release_artifacts_test.dart` → `+9: All tests passed!`。
  - `flutter analyze` → `No issues found!`。
  - `flutter test` 全量 → `+720: All tests passed!`（基线 711 + 新增 9 = 720，0 回归）。
  - `git diff --check` → **PASS**（仅 Windows CRLF 提示，**不**是 Blocker）。
- **T040 多 Agent 协作**：Primary（实施者，落地代码 + 测试）+ 1 独立 readonly Reviewer Agent（`a94f59ff0ddd72332`，7 项核对 → **Approved** + 0 Blocker）；遵循 "less is more" 协作模型，**不**引入交叉多 reviewer；详见 `docs/dev/TASK_LEDGER.md` T040 节段 + `docs/dev/AGENT_QUALITY_METRICS.md` §4.28 T040 Scorecard。
- **T040 范围限制**：① **不**改生产代码；② **不**改依赖；③ **不**改 Manifest / Gradle；④ **不**改 schema / `app_database.g.dart`；⑤ **不**改版本号 / 签名配置 / `key.properties` / `.gitignore` / keystore；⑥ **不**重建 Release 产物（既有 v1.1.0 APK / AAB 在 `build/` 内已存在）；⑦ **不**运行全量 720 项测试 / `flutter build` 二次（仅 commit 收口时**不**二次运行）；⑧ **不** push / **不** tag / **不** amend / rebase / reset --hard。
- **未**修改生产代码 / 测试代码（除本任务唯一新增 `test/tool/verify_release_artifacts_test.dart`）/ 依赖 / Android 配置 / Drift schema / `app_database.g.dart` / `PracticeRecord` 域模型 / Repository / DAO / `audioFilePath` 字段 / `RealAudioRecorderService` / `RealAudioPlaybackService` / `AudioFileStorageService` / `MicrophonePermissionService` / Manifest / 隐私政策 / `key.properties` / `.gitignore` / keystore / 构建产物 / 既有 T006-T039 任何台账条目 / 既有 TD-001 ~ TD-021 任何条目。
- **T040 详细文档**：`docs/dev/TASK_LEDGER.md` T040 节段（**仅**追加） + `docs/dev/AGENT_QUALITY_METRICS.md` §4.28 T040 Scorecard（**仅**追加） + `docs/dev/TECH_DEBT.md` TD-022 本闭环说明段（**仅**追加） = 3 个 doc 文件 + `tool/verify_release_artifacts.dart` + `test/tool/verify_release_artifacts_test.dart` = **5 个文件**（2 代码 + 3 doc）。
- **下一任务**（按 brief）：T041+（建议方向：① T022 verifier 增量场景覆盖 —— Release 证书与 Debug 证书"matched" 失败路径 / AAB jarsigner exit != 0 失败路径 / `parseExpectedVersion` 解析失败 → `_FailFast` exit 2 路径；② `.gitignore` 追加 `*.apk` + `*.aab` 显式模式（T038C Reviewer 提示）；③ KGP → Built-in Kotlin 迁移；④ iOS TestFlight 闭环（TD-003）；⑤ 国产 ROM 兼容性补测（TD-013 小米 / OPPO / vivo / 三星）；⑥ 23 个 Dart 格式漂移延后独立处理）。

## TD-023: T047B F-1 T047 ledger `else if` 措辞遗留 — 登记

- **问题**：T047 既有 ledger 条目（`docs/dev/TASK_LEDGER.md` line 470）保留已废弃 `else if` 措辞（描述 T047 v0.3 错误的"if / else if 精确分支对"作为历史快照）。T047B v0.4 勘误后该措辞已被 §3.8(b) 累进式 `if (from < N)` 链替代，但 T047 既有 ledger 条目作为历史台账**未**回溯修改（属 T047 历史 ledger 措辞遗留）。
- **影响**：对当前功能 / 维护成本 / 用户体验**无**实际影响；仅 ledger 措辞与 v0.4 设计轻微不一致；可能让阅读者误以为 v0.4 仍推荐 `else if` 链（实际 v0.4 已显式禁用）。
- **优先级**：**Low**（不阻塞 P1；不阻塞 v1.1.0 Release / 商店 / 真机 / 验收；不影响 Drift schemaVersion 行为）。
- **建议处理阶段**：P1 关闭门后任意 P2+ 任务顺手修（建议 T051+ 任意 ledger audit 任务；或留 ROADMAP cleanup 独立任务）。
- **状态**：**待处理**（不阻塞 P1）。
- **T049 Implementation Plan 误读防护**：(1) `docs/architecture/IMPLEMENTATION_PLAN_PRODUCT_V2_PHASE1.md` §6 显式记录"不复制 `else if` 措辞（统一为'累进式 `if (from < N)` 链'）"；(2) §6 显式登记本条 TD-023 + 链接；(3) §6 引用 SDD v0.4 §3.8(b) 累进式为唯一权威设计；(4) 任何后续 Implementation Task 启动前必须读 T047B Scorecard + 本 Implementation Plan §6 + TD-023 / TD-024。
- **T049A 关闭门依据**：`t049a-implementation-plan-reviewer`（subagent `ac0c16877010ab8a5`）r1 → final **Approved**（0 Findings，0 Blocker，0 Approved with Conditions），显式审计通过"T047B F-1 / F-2 登记 TD-023 / TD-024 + 显式记录在 §6"。

## TD-024: T047B F-2 ROADMAP P4 Curriculum schemaVersion 2→3 vs 3→4 冲突 — 登记

- **问题**：`docs/ROADMAP.md` P4 Curriculum 行（第 3 节 P4 描述）写"Drift schemaVersion=2 → 3（含 P2 `scores` 表列对齐）"，与实际 P4 升级路径 3→4（SDD v0.4 §3.8 / §5 显式说明 P2 占 2→3 名额 / P4 占 3→4 名额）冲突。属 T047A → T047B 跨阶段编号独立化过程中残留的旧表述（v0.3 阶段 P2 与 P4 同时占用 schemaVersion=3 编号，后 v0.4 勘误将 P4 升级目标改为 schemaVersion=4）。
- **影响**：对当前功能 / 维护成本 / 用户体验**无**实际影响；ROADMAP 文本与 SDD v0.4 实际设计轻微不一致；可能让阅读者误以为 P4 升级会到 schemaVersion=3（实际是 schemaVersion=4）；仅 P4 阶段启动前需要解决。
- **优先级**：**Low**（不阻塞 P1；不阻塞 v1.1.0 Release / 商店 / 真机 / 验收；P1 schemaVersion=2 保持与本条无关；冲突属 P4 阶段）。
- **建议处理阶段**：P4 Curriculum 阶段启动前 1 个独立 ROADMAP cleanup 任务（建议 T051+ P4 启动准备任务；或留 ROADMAP cleanup 独立任务）。
- **状态**：**待处理**（不阻塞 P1；P4 启动前必须解决）。
- **T049 Implementation Plan 误读防护**：(1) `docs/architecture/IMPLEMENTATION_PLAN_PRODUCT_V2_PHASE1.md` §6 显式记录"引用 ROADMAP schemaVersion 时，统一用 SDD v0.4 编号（P2 = 2→3 / P4 = 3→4）"；(2) §6 显式登记本条 TD-024 + 链接；(3) §6 引用 SDD v0.4 §5 Drift 升级铁律为唯一权威设计；(4) §7.8 Drift schemaVersion 保持 2 验收条件**不**依赖 ROADMAP P4 schemaVersion 行；(5) 任何后续 Implementation Task 启动前必须读 T047B Scorecard + 本 Implementation Plan §6 + TD-023 / TD-024。
- **T049A 关闭门依据**：`t049a-implementation-plan-reviewer`（subagent `ac0c16877010ab8a5`）r1 → final **Approved**（0 Findings，0 Blocker，0 Approved with Conditions），显式审计通过"T047B F-1 / F-2 登记 TD-023 / TD-024 + 显式记录在 §6"。

## T049A 状态备注（Implementation Plan 复审证据补齐 + T047B 2 项 Minor 登记 TECH_DEBT 闭环）

- **Task ID**：`T049A_FIX_IMPLEMENTATION_PLAN_REVIEW_AND_EVIDENCE`。
- **起始 Commit**：`0de2949`（T049 v1.1 Implementation Plan 提交）。
- **HEAD（最终）**：TBD（T049A 提交后；T049A 仅 4 doc 追加段，1 个 commit = `docs: complete product v2 implementation plan review evidence`）。
- **任务定位**：T049 v1.1 提交后 GPT 首席架构师复审指出 3 项 Finding（TASK_LEDGER / AGENT_QUALITY_METRICS / TECH_DEBT 证据补齐 + T047B Minor 处理 + Reviewer 真实落地）。T049A **仅**完成 3 项 Finding 修正闭环，**不**修改 T049 Implementation Plan 11 个任务序列核心结构、**不**启动 Implementation Task（T049A_OP1_AUDIO_CAPTURE_SPIKE 等 11 个正式实施任务**仍**必须由 GPT 首席架构师出具独立 Prompt）、**不**写实现代码 / **不**执行 OP-1 / OP-2 Spike / **不** push / **不** Tag / **不** amend / rebase / reset --hard。
- **启动条件**：HEAD = `0de2949` / `git status --short` clean / `git branch --show-current` = `product-v2` 全部满足 ✓。
- **核心审查 3 项**全部 PASS：
  1. 头部 Reviewer 状态由 `Pending` 改为 `Approved`（subagent `ac0c16877010ab8a5`）= PASS（消除"Pending vs 0 Blocker"自相矛盾）。
  2. T047B F-1 / F-2 登记 TD-023 / TD-024 = PASS（消除"不修且不登记"双重否定歧义；T047B Scorecard 留痕 + TECH_DEBT.md 登记两条独立证据路径）。
  3. TASK_LEDGER + AGENT_QUALITY_METRICS + TECH_DEBT 三 doc 全部补齐 T049 + T049A 证据 = PASS（TASK_LEDGER 追加 2 条台账 + AGENT_QUALITY_METRICS 追加 §4.AA + §4.AB Scorecard + TECH_DEBT 追加 TD-023 / TD-024 + T049A 状态备注段）。
- **T049A Reviewer 闭环**：`t049a-implementation-plan-reviewer`（subagent `ac0c16877010ab8a5`）r1 → final **Approved**（7 维度全部 PASS：① PRD / SDD / TDD 一致性；② 任务拆分 11 任务 12 字段齐全；③ 依赖顺序 OP-1 / OP-2 ADR → T8 + m4a 闭环保护；④ Demo A/B/C 三组 + Demo C 时间窗警告；⑤ T11 关闭门 8 项验收 + 降级路径显式标注；⑥ 多 Agent 风险分级 Low 1 / Med 2 / High 3 + 二元裁决铁律；⑦ T047B F-1 / F-2 登记 TD-023 / TD-024 + §6 显式记录）；0 Findings / 0 Blocker / 0 Approved with Conditions。
- **关键确认 9 项**全部 PASS：精确 744 / Implementation Plan v1.2 / TASK_LEDGER 追加 T049 + T049A 两条 / AGENT_QUALITY_METRICS 追加 §4.AA + §4.AB / TECH_DEBT 追加 TD-023 / TD-024 / Reviewer 真实独立只读 / **不**修改生产代码 / 测试 / pubspec / Manifest / Drift / `app_database.dart` / `app_database.g.dart`（schemaVersion 仍为 2）/ **不**启动 OP-1 / OP-2 Spike。
- **T049A 修改文件范围**（**仅** 4 doc 文件）：
  1. `docs/architecture/IMPLEMENTATION_PLAN_PRODUCT_V2_PHASE1.md` v1.1 → v1.2（头部 Reviewer Pending → Approved + §6 T047B 2 项 Minor 改为登记 TECH_DEBT + §9 版本表追加 v1.2 + T049A Task ID 落盘 + Implementation Plan 状态 = "Approved / 可启动任务"）。
  2. `docs/dev/TASK_LEDGER.md` 追加 T049 + T049A 两条台账条目（T049 含"未批准原因"段 + T049A 接力任务段；T049A 含完整证据闭环段）。
  3. `docs/dev/AGENT_QUALITY_METRICS.md` 追加 §4.AA T049 Scorecard + §4.AB T049A Scorecard（两段均按 AGENT_REVIEW_TEMPLATE 模板填写 Scope Reviewed / Evidence Checked / Findings / Verdict / Collaboration Value / Notes）。
  4. `docs/dev/TECH_DEBT.md` 追加 TD-023（来源 T047B F-1，Low 风险，不阻塞 P1 原因 + 后续建议处理时机 + Implementation Plan 误读防护）+ TD-024（来源 T047B F-2，Low 风险，不阻塞 P1 原因 + 后续建议处理时机 + Implementation Plan 误读防护）+ T049A 状态备注段（本段）。
  **不**修改既有 1 ~ TD-022 任何条目 / 既有 4.1 ~ 4.Z 任何 Scorecard / 既有 T006-T048 任何台账条目。
- **T049A 净增 0 项自动化测试 / 0 项生产代码改动 / 0 项依赖改动 / 0 项 schema 改动 / 0 项 Manifest 改动 / 0 项 Gradle 改动 / 0 项 `key.properties` 改动 / 0 项 keystore 改动**。
- **T049A 未 push / 未 Tag / 未 amend / rebase / reset --hard / 未读取 `key.properties` / 未读取 keystore 密码 / alias / 敏感路径 / 未声称 Release APK 已上架 / iOS 已验收 / 全 Android ROM 兼容 / 权限首次申请已通过**。
- **下一任务**（按 brief）：T049A 提交后**仅**能由 GPT 首席架构师决定是否进入 T049A_OP1_AUDIO_CAPTURE_SPIKE 等 11 个正式实施任务；T049A **不**预先启动任何 Implementation Task。

## TD-025: T050 OP-1 Audio Capture Spike 工具与 ADR（无真机物理执行 / `Blocked` 决策） — 闭环说明

**任务定位**：`T050_OP1_AUDIO_CAPTURE_SPIKE` 是 Product V2 Phase 1 Implementation Plan v1.2 §2 T1 启动的第一个正式实施任务（**原命名** `T049A_OP1_AUDIO_CAPTURE_SPIKE`，本任务**统一**为 `T050_OP1_AUDIO_CAPTURE_SPIKE` 避免与 T049A 命名冲突）。本任务**仅**完成 OP-1 Audio Capture Spike 工具 + ADR 落盘，**不**写生产代码 / **不**启动真机 Spike / **不**修改 `lib/**` / `test/**` / `pubspec.yaml` / Manifest / Drift schema / 既有契约。

**T050 硬边界（任务 §6）**：
- 允许新建：`tool/spike_op1_audio_capture.dart`（spike harness）+ `docs/architecture/OP1_AUDIO_CAPTURE_ADR.md` + `e2e/spike_logs/op1_<device>_<timestamp>.log`
- 允许修改：`docs/dev/TASK_LEDGER.md`（追加 T050 行）+ `docs/dev/AGENT_QUALITY_METRICS.md`（追加 §4.AC T050 Scorecard）+ 本 TECH_DEBT 段
- 禁止修改：`lib/**` / `test/**` / `integration_test/**` / `pubspec.yaml` / `pubspec.lock` / `android/**` / Manifest / Drift schema / generated files / release / signing 文件 / APK / AAB / build 产物

**T050 实际修改文件**（5 个文件）：
1. `tool/spike_op1_audio_capture.dart`（新建，约 380 行；spike harness；`dart analyze tool/` `No issues found!`）
2. `docs/architecture/OP1_AUDIO_CAPTURE_ADR.md`（新建，18 节 / 约 320 行；ADR 决策 = `Blocked`）
3. `docs/dev/TASK_LEDGER.md`（追加 T050 行；**不**修改既有 T006-T049A 任何条目）
4. `docs/dev/AGENT_QUALITY_METRICS.md`（追加 §4.AC T050 Scorecard；**不**修改既有 4.1 ~ 4.AB 任何 Scorecard）
5. 本 TECH_DEBT 段（追加；**不**修改既有 TD-001 ~ TD-024 任何条目）

**T050 ADR 决策 = `Blocked`**（任务 §8 + §10 二元裁决铁律严格遵守）：
- 证据强度 = **0 真机物理执行**（当前任务执行环境 Windows 11 + Git Bash 无 Android 真机）
- 决策匹配：0 真机 = 必须 `Blocked`（**不**允许 `Approved with Conditions` / `Pending` / `Provisional evidence only, not approved` / `Blocker equivalent`）
- ADR §13.1 显式记录本任务硬限制（无真机 / 0 设备 / 0 时长档位 / 设备矩阵证据不足）
- ADR §13.2 理论性结论（API 层路径可达 + 静态层无问题 + Android 平台层**未被本任务证实**）
- ADR §16 阻断范围明确（T8 Tuner Real-Time / P2 Lesson Session Engine / P2 9 步互动闭环 / 节奏起音对齐初始校准）
- ADR §15 后续任务建议 = 首选"选项 X：真机补做 A 方案 spike"（HUAWEI CDY-AN90 + 1 台中端 Android 13+ × 5s/30s/5min = 6 实验）

**T050 Reviewers Approved**（read-only；3/3 Approved / 0 Blocker / 0 Approved with Conditions）：
- Audio Architecture Reviewer `t050-audio-architecture-reviewer`（subagent `a0f40b639ff32895a`；9 项 Findings 全部 Resolved：API 层事实 / 平台层隐藏风险 / 时序契约 / PCM 流边界 / m4a 完整性 / 不破坏既有契约 / PRD §5.1 9 步闭环 / 二元裁决 / ADR 增补建议）
- Flutter Data / Lifecycle Reviewer `T050-Flutter-Data-Lifecycle`（subagent `a3d6897ffa3524574`；10 项 Findings 全部 Resolved：资源生命周期 / 错误处理 / Dart flow analysis / 不破坏既有契约严格隔离 / 边界遵守 / 16 项必备内容 / 二元裁决 / 测试基线 / 静态分析 / 微小观察）
- Android QA Reviewer `T050-Android-QA-Reviewer`（subagent `a162c70c1468e460e`；10 项 Findings 全部 Resolved：设备矩阵证据 / 平台层风险显式标注 / 时长档位 / spike 工具边界 / 7 项必含清单 code-level 与 NOT RUN 区分 / 日志保存路径 / T037 既有基线一致 / CRASH 路径优雅 / 5 分钟电池优化 / 未声明新依赖）

**Reviewer 增补建议（已采纳至 ADR，全部**非** Blocker）**：
- ADR §7 / §15 m4a 5min 大小估算 `4.8 MB` → `3.66 MB`（128 kbps × 300s = 3,840,000 bytes）
- ADR §9 PCM 5min 单位 MiB 统一（≈ 26,460,000 bytes ≈ 25.24 MiB）
- ADR §3.1 / §11 追加"未来真机 spike 增加 platform-channel 日志采集验证 `onStop` 回调归属"
- ADR §5.1 增补"退出码语义澄清（exit 0 ≠ 7 项 PASS；调用方必须读取日志文件做 PASS / FAIL 判定）"
- ADR §10 增补"5min 档位需 Wakelock / 关闭电池优化 / 屏幕常亮前置说明"
- ADR §5.1 增补"未来 spike 工具 CLI args 增强建议（`--duration=30s`）"（**不**改 spike 工具代码 —— Reviewer 显式标注**非** Blocker，最小改动原则保留现状）

**spike 工具边界硬遵守（任务 §6）**：
- 仅在 `tool/` 目录（**不**被生产代码引用；grep `tool/` 无 `lib/` 反向 import）
- **不**改变现有 App 运行路径
- **不**修改现有录音服务（**不**调用 `RealAudioRecorderService` / `MicrophonePermissionService` / `AudioFileStorageService`）
- **不**改变现有 m4a 录音保存与回放闭环（**不**动 T027 / T028 / T029 / T030 / T031E / T031I / T032 / T033 / T034 / T035 / T035A / T035B / T036 / T036A / T037 / T037A / T037B / T037B1 / T037B2 / T037C / T037D / T038 / T038B / T038C / T039 既有契约）
- **不**引入新依赖（仅复用既有 `record ^7.1.0` + `path_provider ^2.1.6` + `path ^1.9.1` + `uuid ^4.5.3`）
- **不**新增 INTERNET 权限
- **不**升级 Drift schema（schemaVersion 仍为 2）

**spike 工具静态检查**：
- `dart analyze tool/spike_op1_audio_capture.dart` = `No issues found!`
- `dart analyze tool/` = `No issues found!`

**spike 工具真机执行状态**：
- **当前任务执行环境无真机**（Windows 11 + Git Bash）
- spike 工具**未**在真机上执行
- 仅 main 函数入口执行了一次第 5s 档位（生成 NOT RUN 日志）
- 真机执行命令：`flutter run -d <android-device> tool/spike_op1_audio_capture.dart`
- 真机执行时需手动改 main 函数 `_runSpike` 调用点的 `Duration(seconds: 5)` 为 5s / 30s / 5min 三档

**T050 净增 0 项自动化测试 / 0 项生产代码改动 / 0 项依赖改动 / 0 项 schema 改动 / 0 项 Manifest 改动 / 0 项 Gradle 改动 / 0 项 `key.properties` 改动 / 0 项 keystore 改动 / 0 项 `lib/**` 改动 / 0 项 `test/**` 改动 / 0 项 Drift schema 改动 / 0 项 `app_database.dart` 改动 / 0 项 `app_database.g.dart` 改动**：
- 测试基线 = 744（保持 744，未重跑）
- spike 工具是 `flutter run -d <device>` 入口（**非** `flutter test` 测试），**不**进入 744 测试基线
- ADR 是文档，**不**影响任何代码 / 测试

**T050 未 push / 未 Tag / 未 amend / rebase / reset --hard / 未声称 OP-1 已通过 / 未声称 A 方案已批准为 P1 正式方案 / 未进入 P2 互动闭环 / 未启动 T8 Tuner Real-Time / 未声称真机执行已通过 / 未声称国产 ROM 兼容 / 未读取敏感文件**。

**下一阶段**（**待 GPT 首席架构师独立 Prompt 启动**）：
- 首选"选项 X：真机补做 A 方案 spike"——用户在 HUAWEI CDY-AN90 / Android 10 + 1 台中端 Android 13+ 上执行 `flutter run tool/spike_op1_audio_capture.dart`；5s/30s/5min 三档 × 2 设备 = 6 实验；如 6/6 PASS → 启动 `T049A_REDO_OP1_SPIKE` 产出 `Approved for P1 implementation` ADR；如部分 FAIL → 评估 C（事后解码）/ D（FFI）/ 暂缓
- 二选：C（事后解码 — `just_audio ^0.10.5` 是否暴露纯解码 API 待 P1 spike 验证）/ D（FFI — Android `AudioRecord` JNI 直采；P3+ 备选）
- 兜底：暂缓 OP-1 = 接受"P2 互动闭环仅会话结束反馈"或"P1 调音器走静态 GCEA 频率表降级路径"

**遗留技术债（不属于本任务范围）**：
- 国产 ROM 兼容性（HUAWEI / 小米 / OPPO / vivo / 三星）必须由真机用户验收 —— T050 仅 spike 工具就绪 + ADR `Blocked`，未越界覆盖其他 ROM
- 真实音频 MCP 流生产代码（`PcmStreamAudioRecorderGateway` / `PcmStreamCaptureService` / `Audio Analysis Pipeline` / `Feedback Engine` / `LessonSessionController`）**未**实现 —— T050 **不**越界；这些属于 P2 任务，需 OP-1 ADR Approved 后才允许启动
- `record ^7.1.0` 双实例共用 `MethodChannel('record_android')` 的 `onStop` / `onCancel` 回调归属 —— SDD v0.4 §7.2 明文"目前无官方 API 文档证伪也未证实"；需真机 platform-channel 日志采集验证（建议未来 spike 增补）
- spike 工具当前时长档位硬编码（`Duration(seconds: 5)`）；30s / 5min 档位需手动改源码 —— 建议未来 spike 工具支持 CLI args 解析（`--duration=30s`）减少改源码易错性
- 5 分钟录音档位下 app 被电池优化 / 屏幕关闭导致系统 kill app 的风险 —— 建议未来真机执行 spike 前置条件：保持屏幕常亮 / 关闭电池优化 / 禁用 Doze

## TD-026: T051 OP-1 Audio Capture 真机执行尝试（0 完成实验 / 1 设备检测 / 决策保持 `Blocked`） — 闭环说明

**任务定位**：`T051_OP1_AUDIO_CAPTURE_DEVICE_EXECUTION` 是 Product V2 Phase 1 Implementation Plan v1.2 §2 T1 真机实验主体的**尝试任务**（与 T050 spike 工具 + ADR 收口接力）。本任务在 T050 spike 工具 + ADR（决策 = `Blocked`）基础上，尝试在真实 Android 设备上执行 5s/30s/5min 三档双 `record` 实例实验并更新 ADR。**实际结果：0 完成实验 / 1 设备检测 / Agent 不自动启动 spike / 决策保持 `Blocked` / 0 净增测试 / 0 生产代码改动**。

**T051 硬边界（任务 §6 + §12 停止条件）**：
- 允许修改：`docs/architecture/OP1_AUDIO_CAPTURE_ADR.md`（追加 §4.b + §18）+ `docs/dev/TASK_LEDGER.md`（追加 T051 行）+ `docs/dev/AGENT_QUALITY_METRICS.md`（追加 §4.AD T051 Scorecard）+ 本 TECH_DEBT 段
- 禁止修改：`tool/spike_op1_audio_capture.dart`（T050 交付保持）/ `lib/**` / `test/**` / `integration_test/**` / `pubspec.yaml` / `pubspec.lock` / `android/**` / Manifest / Drift schema / generated files / release / signing 文件 / APK / AAB / build 产物
- 任务 §6 + §12 停止条件明确："无真机可用" / "用户无法提供人工真机执行结果" 必须停止并报告；"只有 1 台设备但试图批准 A 方案" 必须停止并报告

**T051 实际修改文件**（4 个文件，**全部仅 doc 追加**，无既有内容修改）：
1. `docs/architecture/OP1_AUDIO_CAPTURE_ADR.md`（追加 §4.b T051 真机执行尝试 + §18 T051 闭环说明 = 三步反思 + §18.1 初步实现 + §18.2 自我找茬 + §18.3 终极交付 + §19 引用列表追加 TD-026；**不**修改 T050 §1-§17 既有内容）
2. `docs/dev/TASK_LEDGER.md`（追加 T051 行；**不**修改既有 T006-T050 任何条目）
3. `docs/dev/AGENT_QUALITY_METRICS.md`（追加 §4.AD T051 Scorecard；**不**修改既有 4.1 ~ 4.AC 任何 Scorecard）
4. 本 TECH_DEBT 段（追加；**不**修改既有 TD-001 ~ TD-025 任何条目）

**T051 设备矩阵实测**：
- `flutter devices` 检测到 1 台 Android 真机：CDY AN90 / Android 10 (API 29) / HUAWEI EMUI
- 3 台非 Android 设备：Windows desktop / Chrome / Edge web
- **< 2 设备决策门** → 即使全部跑过也只能 `Blocked` 或 `Provisional evidence only, not approved`（任务 §6 明确）

**T051 完成实验数 = 0**（Agent 不代写人工结果）：
- 任务 §6 明确："不得由 Agent 代写人工真机结果"
- 任务 §12 停止条件："无真机可用" / "用户无法提供人工真机执行结果" 必须停止并报告
- Agent 不自动启动 spike（原因：spike 涉及 `RECORD_AUDIO` 权限申请 / temp m4a 文件写入 / 5 分钟录音触发电池优化 / 屏幕关闭风险 / m4a 完整性需用户人工确认"可正常播放"）
- 用户未提供任何人工真机执行结果
- T051 实跑 0 真机 × 0 时长档位

**T051 决策 = `Blocked`**（与 T050 一致；任务 §6 + §8 + §10 决策矩阵严格遵守）：
- 证据强度 = 0 完成实验 + 1 设备 < 2 设备决策门
- **不**允许 `Approved for P1 implementation`
- **不**允许 `Approved with Conditions`
- **不**允许 `Pending`
- **不**允许 `Provisional evidence only, not approved`（任务 §8 允许，但 0 实验 = `Blocked` 更明确）
- **不**允许 `Blocker equivalent`

**T051 用户人工执行命令（待用户回传）**：
```bash
# 5s 档
flutter run -d CDY-AN90 tool/spike_op1_audio_capture.dart
# 运行前修改 main() 中 _runSpike 调用点的 Duration 为 Duration(seconds: 5)

# 30s 档
# 修改 Duration 为 Duration(seconds: 30)

# 5min 档
# 修改 Duration 为 Duration(minutes: 5)
# 前置条件：保持屏幕常亮 / 关闭电池优化 / 禁用 Doze
```

**回传要求**（用户人工完成 spike 后回传）：
- 设备型号 + Android 版本 + 厂商 ROM
- m4a 文件路径 + 文件大小
- m4a 是否可正常停止 + 是否可被现有 `just_audio ^0.10.5` 播放（**用户人工确认**）
- PCM chunk 数量 + 间隔统计 + 是否有长时间中断
- start / stop 顺序
- onStop / onCancel 回调归属（不串台）
- 资源释放（dispose 后能否再次启动）
- 权限：denied / granted / permanentDenied / 恢复表现
- 日志文件路径（`e2e/spike_logs/op1_<device>_<timestamp>.log`）

**T051 Reviewers Approved**（read-only；3/3 Approved / 0 Blocker / 0 Approved with Conditions）：
- Audio Architecture Reviewer `t051-audio-architecture-reviewer`（subagent `afc23f4f8088ee82e`；r1 → final **Approved**；6 项 Findings 全部 Resolved：T051 任务命名 / 决策保持 Blocked / 无伪造数据 / 边界遵守 / 台账一致 / spike 工具未修改；全部**非** Blocker）
- Flutter Data / Lifecycle Reviewer `t051-flutter-lifecycle-reviewer`（subagent `af3b457c9dd1a88e3`；r1 → final **Approved**；5 项 Findings 全部 Resolved：T051 deliverable 必须追加 / T050 baseline 已含 1 设备硬限制 / Agent 不自动执行 spike / 无伪造数据 / 边界遵守 = **非** Blocker）
- Android QA Reviewer `t051-android-qa-reviewer`（subagent `aeca53912bad82f35`；r1 **Blocker**（T051 段缺失，4 项 Findings 全部 Open）→ v1 完成追加 4 doc 段 → r2 final **Approved**（**待复审确认**；4 项 Findings 全部 Resolved，全部**非** Blocker））

**spike 工具边界硬遵守（任务 §6）**：
- **不**修改 `tool/spike_op1_audio_capture.dart`（T050 交付保持）
- **不**改变现有 App 运行路径
- **不**修改现有录音服务（**不**调用 `RealAudioRecorderService` / `MicrophonePermissionService` / `AudioFileStorageService`）
- **不**改变现有 m4a 录音保存与回放闭环
- **不**引入新依赖
- **不**新增 INTERNET 权限
- **不**升级 Drift schema（schemaVersion 仍为 2）

**T051 净增 0 项自动化测试 / 0 项生产代码改动 / 0 项依赖改动 / 0 项 schema 改动 / 0 项 Manifest 改动 / 0 项 Gradle 改动 / 0 项 `key.properties` 改动 / 0 项 keystore 改动 / 0 项 `lib/**` 改动 / 0 项 `test/**` 改动 / 0 项 `tool/**` 改动 / 0 项 Drift schema 改动 / 0 项 `app_database.dart` 改动 / 0 项 `app_database.g.dart` 改动**：
- 测试基线 = 744（保持 744，未重跑）
- spike 工具**未**修改
- T051 仅追加 4 个 doc 段

**T051 未 push / 未 Tag / 未 amend / rebase / reset --hard / 未声称 OP-1 已通过 / 未声称 A 方案已批准为 P1 正式方案 / 未进入 P2 互动闭环 / 未启动 T8 Tuner Real-Time / 未声称真机执行已通过 / 未声称国产 ROM 兼容 / 未读取敏感文件**。

**下一阶段**（**待 GPT 首席架构师独立 Prompt 启动**）：
- 首选"选项 X：真机补做 A 方案 spike"——用户在 CDY AN90 / Android 10 + 1 台中端 Android 13+ 上人工执行 `flutter run tool/spike_op1_audio_capture.dart`；5s/30s/5min 三档 × 2 设备 = 6 实验；如 6/6 PASS → 启动 `T049A_REDO_OP1_SPIKE` 产出 `Approved for P1 implementation` ADR；如部分 FAIL → 评估 C（事后解码）/ D（FFI）/ 暂缓
- 二选：C（事后解码 — `just_audio ^0.10.5` 是否暴露纯解码 API 待 P1 spike 验证）/ D（FFI — Android `AudioRecord` JNI 直采；P3+ 备选）
- 兜底：暂缓 OP-1 = 接受"P2 互动闭环仅会话结束反馈"或"P1 调音器走静态 GCEA 频率表降级路径"
