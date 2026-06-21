# MVP 验收检查点 (MVP Acceptance Checkpoint)

> 本文档为离线 MVP 在 Android Debug 产物上完成的正式验收检查点,由 T016_MVP_RELEASE_CHECKPOINT 任务建立。
> 任何超出本文档范围的能力声明(例如"生产环境已就绪""可直接上架")均不成立。

## 1. Checkpoint

| 项 | 值 |
| --- | --- |
| 任务 ID | `T016_MVP_RELEASE_CHECKPOINT` |
| Git 分支 | `master` |
| Git HEAD | `ebfe12d` |
| HEAD Commit message | `fix: polish device acceptance copy and layouts` |
| 检查点类型 | 离线 Android Debug MVP 验收(非 Release / 非商店) |
| 是否创建 Git Tag | 否 |
| 是否 push | 否 |

## 2. Product Scope

MVP 在以下范围内视为"完成":

- 7 天循环的今日练习(基于 `installDate` 计算 dayIndex)
- 今日任务完成状态通过 Drift 持久化,重启后保留
- 和弦库、和弦详情、静态指法图
- 单音练习与单音页面"上一个 / 下一个"导航
- 可视化节拍器(不播放真实声音,BPM 不持久化)
- 手动调音辅助页面(G/C/E/A 四弦)
- 模拟录音 / 模拟回放 / 三档自评 / 备注
- 练习记录保存 / 列表 / 详情 / 删除
- Drift Repository 边界(`lib/data/` 与 `lib/features/*/data/`)
- 完整记录纵向集成测试(`mvp_practice_record_flow_test.dart`)

明确不在当前 MVP 范围内(以 `docs/MVP_SCOPE.md` 为准):账号、云同步、AI 评分、自动扒谱、自动调音、真实麦克风录音、真实音频文件、商店发布。

## 3. Automated Validation

| 项 | 实际值 | 备注 |
| --- | --- | --- |
| `flutter analyze` | No issues found | 全仓静态分析通过 |
| `flutter test` | 407 tests passed | 终态测试数;T014 至 T016 期间未新增 / 更新 / 删除任何测试 |
| Drift schemaVersion | 1 | 保持基线,未调整 |
| 集成测试入口 | `test/integration/mvp_practice_record_flow_test.dart` | 由 T014 提交 `b17e780` 引入 |

## 4. Android Build Artifact

| 项 | 值 |
| --- | --- |
| applicationId | `com.yupi.ukulele` |
| minSdk | `flutter.minSdkVersion`(当前 24) |
| targetSdk / compileSdk | 由 `flutter.targetSdkVersion` / `flutter.compileSdkVersion` 决定 |
| Kotlin / AGP / Gradle / JDK | Kotlin Gradle Plugin 2.1.0 / AGP 8.6.0 / Gradle 8.7 / JDK 17 |
| 构建类型 | Debug |
| APK 相对路径 | `build/app/outputs/flutter-apk/app-debug.apk` |
| APK 字节大小 | 161,305,625 bytes |
| 体积说明 | Debug 通用 APK 体积较大,不代表 Release 包体积;Release 阶段需重新评估体积策略 |

> 当前仅产出一份 Debug APK,未产出 Release APK / AAB;`android/app/build.gradle` 中 `release` 当前仍临时借用 `signingConfigs.debug`。

## 5. Device Acceptance

下列验收项由用户在真机上**手工完成**,不构成自动化测试结果。

| 验收项 | 真机结论 |
| --- | --- |
| 真机型号 | `CDY-AN90` |
| APK 覆盖安装 | 成功 |
| App 启动 | 成功,无崩溃 |
| 权限弹窗 | 无 |
| 新文案(首页 / 关于 / 内容声明 / 隐私声明 / 设置入口 / 单音练习) | 正常显示 |
| 单音页面"上一个 / 下一个"导航 | 正常 |
| 页面布局 | 无明显溢出 |
| 今日任务状态持久化 | 正常(由 T013.3 系列沉淀) |
| 模拟录音保存 | 正常(由 T013.4A0 / T013.4A0_FIX 沉淀) |
| 记录列表 / 详情 | 正常(由 T013.4B / T013.4C 系列沉淀) |
| 记录删除 | 正常(由 T013.4C / T013.4C_FIX 沉淀) |
| 杀进程后重新启动 | 正常 |
| 强行停止后重新启动 | 正常,本地数据保留 |

## 6. Persistence Acceptance

- 今日任务完成状态:`lib/data/database/` 中 `completed_tasks` 表 + `DriftCompletedTasksRepository`,重启后由 `DriftInstallDateService` + `practiceDayResolverProvider` 还原
- installDate:`DriftInstallDateService` 持久化为 ISO-8601,`parseIsoUtc` 拒绝无时区设计符
- 练习记录:`practice_records` 表 + `DriftPracticeRecordRepository`,通过 `PracticeRecordIdGenerator`(UUID v4)生成 id
- `audioFilePath` 始终为 `null`,数据库列保留仅为后续真实音频阶段做 schema 占位
- 强行停止 App 后,上述所有数据在重新启动时均保留

## 7. Permissions and Privacy

- `AndroidManifest.xml` 不声明 `RECORD_AUDIO`,也无任何 `INTERNET` / 存储权限
- `pubspec.yaml` 不依赖 `record` / `flutter_sound` / `permission_handler` 等音频或权限相关包
- App 启动与各核心页面无任何运行时权限弹窗
- 模拟录音不写入任何真实音频文件到本地
- 隐私声明 / 内容声明页面已实装并通过真机验收(由 `ebfe12d` 文案打磨)

## 8. Known Limitations

- 模拟录音 / 模拟回放:`audioFilePath` 始终为 `null`,无真实音频文件
- 节拍器:仅可视化,BPM 不持久化
- 调音器:仅手动调音辅助页面,不做自动调音
- Release 签名 / 商店发布:未配置,见 `TECH_DEBT.md` TD-002
- iOS 适配与验收:未执行,见 `TECH_DEBT.md` TD-003
- Debug APK 体积:不代表 Release 体积,见 `TECH_DEBT.md` TD-004
- 工具链弃用警告:当前构建成功,不主动升级,见 `TECH_DEBT.md` TD-005
- 真实音频阶段:权限 / 文件 / 隐私 / 平台架构均需重新设计,见 `TECH_DEBT.md` TD-007

## 9. Deferred Work

- Release APK / AAB 构建(`TD-002`)
- 正式签名与商店发布流程(`TD-002`)
- iOS 真机验收与适配(`TD-003`)
- Debug / Release 体积策略(`TD-004`)
- 真实音频阶段(权限 / 隐私 / 平台架构 / 隐私政策更新)(`TD-007`)
- MVP 后产品方向(账号 / 云同步 / AI 评分 / 商业化)(`TD-008`)

## 10. Release Decision

- 当前检查点仅代表**离线 Android Debug MVP 验收通过**
- **不代表**Release 签名、商店发布、iOS 验收、真实音频能力完成
- 下一阶段(无论是 Release 工程化、真实音频、还是 iOS / 商业化)必须由**用户和 GPT 首席架构师另行选择**启动
- 本任务不创建 Git Tag、不 push、不进入下一阶段
- 由 GPT 首席架构师基于本检查点复审后,再决定是否进入下一个正式任务
