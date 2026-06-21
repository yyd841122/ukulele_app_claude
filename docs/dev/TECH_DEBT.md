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
| TD-007 | 当前 MVP 阶段不调用真实麦克风、不保存或播放真实音频,`PracticeRecord.audioFilePath` 始终为 `null`;`RecordingPracticeController` 在保存时硬编码 `audioFilePath: null`(`lib/features/recording/application/recording_practice_controller.dart:534`);同时未申请 `RECORD_AUDIO` 权限,`AndroidManifest.xml` 显式声明无此权限 | 高 — 进入真实音频阶段前,必须重新设计:① 运行时权限申请与回退(RECORD_AUDIO / iOS `NSMicrophoneUsageDescription`);② 音频文件生命周期(目录、清理、迁移);③ 隐私政策、用户告知、合规审查;④ 平台架构(Drift schema 升级、文件存储抽象、错误恢复);这些范围远超当前离线 MVP,不得在未排期的情况下私自启动 | 高 | 真实音频阶段(由 GPT 首席架构师 + 产品另行决策) | 待处理 (T025 已落盘 `REAL_AUDIO_MVP_SDD.md` + `REAL_AUDIO_MVP_TDD.md` 设计;T026 已完成依赖研究 / Spike `REAL_AUDIO_DEPENDENCY_SPIKE.md`;推荐组合 `record ^7.1.0` + `just_audio ^0.10.5` + `permission_handler ^12.0.3` + `path_provider ^2.1.6` 仍**未**写入 `pubspec.yaml`;实现仍待 GPT 首席架构师下发 T027+ 独立 Prompt 后才能启动;设计阶段边界、依赖候选、状态机、错误处理、回滚方案、测试矩阵均已落盘,见 `docs/dev/REAL_AUDIO_MVP_SDD.md` + `REAL_AUDIO_MVP_TDD.md` + `REAL_AUDIO_DEPENDENCY_SPIKE.md`) |
| TD-008 | MVP 之后的产品方向(账号 / 云同步 / AI 评分 / 商业化 / 真实音频)尚未决定;`ROADMAP.md` 中 V1-V5 阶段均标记为"后期",不在当前 MVP 范围守卫内 | 中 — 任何"开始下一阶段"的指令必须由用户和 GPT 首席架构师显式发出,本仓库不在 T016 内自动启动 | 中 | MVP 复盘与下一阶段排期阶段 | 待处理 |
| TD-009 | 构建环境可能依赖用户级网络代理配置(例如 Gradle 依赖拉取、Dart pub 镜像);该配置属于本机环境而非仓库,本台账不记录具体端口、用户名、绝对用户目录或密钥;如未来 CI / 团队协作需要,应改用仓库外(环境变量 / CI 密钥管理)而非提交到代码库 | 低 — 不影响仓库可移植性,仅在跨环境协作时需要明确"该配置不属于本仓库" | 低 | 持续 | 待处理 |
| TD-010 | 真实音频阶段必须新增或评估的音频相关依赖(`record` 7.1.0 / `just_audio` 0.10.5 / `permission_handler` 12.0.3 / `path_provider` 2.1.6)已由 T026 完成依赖研究 / Spike 调研,候选版本号、平台要求、风险与推荐组合均已落盘 `docs/dev/REAL_AUDIO_DEPENDENCY_SPIKE.md`;`pubspec.yaml` 实际写入必须由 T027 (`permission_handler`) / T029 (`record`) / T030 (`just_audio`) 三个独立任务按"一个任务一个 commit"节奏执行,**不得**绕过 Spike 直接恢复旧依赖或一次性引入多个依赖 | 高 — T026 已提供研究结论,但实现仍待 T027+ GPT 首席架构师独立 Prompt | 高 | T027 / T029 / T030（按 T026 推荐组合分别引入） | 待处理 (T026 Spike 完成,推荐组合已确认;依赖**未**写入 `pubspec.yaml`;待 GPT 首席架构师下发 T027+ 独立 Prompt 后才能启动) |
| TD-011 | 真实音频阶段必须新增 Drift `schemaVersion = 2` 迁移:`practice_records` 表新增 `audioDurationMs` / `audioFormat` / `audioFileSizeBytes` / `audioCreatedAt` / `audioDeletedAt` / `recordingMode` 等候选字段(最终字段列表待 T032 确认),旧记录 `audioFilePath = null` 保留,新增字段填默认值(`recordingMode = "simulated"` 等);迁移脚本与迁移测试必须先于迁移代码(TDD);**不得**在 T025 任务中执行迁移 | 高 — 旧记录兼容性、Repository 契约、`audioFilePath` 语义变化均需在迁移前明确 | 高 | T032 `T032_PRACTICE_RECORD_SCHEMA_MIGRATION` | 待处理 |
| TD-012 | 真实音频阶段 PrivacyNoticePage 文案需要更新"麦克风权限用途 / 录音本地存储 / 不上传"三段文案,且不得误导用户以为录音会上传 / 分享 / 导出;更新由 T033 任务执行,T025 / T026 仅落盘文案设计原则 | 中 — 用户知情权 + 隐私合规的核心要求,任何错误文案都会触发合规风险 | 中 | T033 `T033_UI_COPY_AND_PERMISSION_UX` | 待处理 |
| TD-013 | T026 依赖研究 Spike 识别的潜在实现风险点:`record 7.x` `AudioEncoder.aacLc` 重命名(4.x 引入)与本项目既有命名差异需在 T029 隔离 spike 中实测确认;`just_audio 0.10.x` 在 `INTERNET` 权限未声明场景下仅支持本地播放(file:// / asset://),不得误用 https:// 流;`permission_handler 12.x` API 与 11.x 差异需在 T027 隔离 spike 中实测确认;真机国产 ROM 兼容性(HUAWEI / 小米 / OPPO / vivo)未在 Spike 阶段验证,必须由 T036 真机用户验收;`just_audio` 内置 ExoPlayer 版本冲突需在引入第二个 ExoPlayer 依赖时由 `02-flutter-architect` 评估是否显式指定 `exoplayer_version` | 中 — Spike 阶段已识别,但实际表现需 T029 / T030 隔离 spike + T036 真机验收最终确认 | 中 | T027 / T029 / T030（隔离 spike）+ T036（真机验收） | 待处理 (T026 Spike 已识别风险,具体表现待 T029 / T030 / T036 验证) |