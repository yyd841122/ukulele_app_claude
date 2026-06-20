# 任务台账(Task Ledger)

本台账用于追踪 ukulele_app 的任务交付状态,记录每个任务的 Task ID、Commit、测试基线与 GPT 首席架构师复审结论。

## 维护约定

- 每个任务完成后必须追加或更新对应行,不得删除既有记录。
- 同一任务的 FIX 必须独立成行,不能覆盖原任务历史。
- 仅记录能够从 Git 历史、现有文档或代码验证的信息;无法确认的字段写"待补录",不得猜测。
- 字段含义:
  - **Task ID**: 任务编号,与上游 GPT Prompt 中的 ID 一致。
  - **任务名称**: 任务中文简称,沿用上游 Prompt 中给出的描述。
  - **状态**: `通过` / `进行中` / `待开始` / `已废弃` / `待补录`。`待补录` 表示该字段在当前阶段无法从 Git 历史、现有 docs 或代码中可靠验证,不能填入"通过"或其他已确认结论。
  - **Commit**: 任务对应的主交付 commit(短 hash)。
  - **测试总数**: 该任务交付时的全仓 `flutter test` 通过测试数。
  - **GPT 复审**: `通过` / `未通过` / `待复审` / `待补录`。
  - **遗留说明**: 关联的 FIX、约束、未解决问题等。

---

## T006 - T011(历史任务)

| Task ID | 任务名称 | 状态 | Commit | 测试总数 | GPT 复审 | 遗留说明 |
| --- | --- | --- | --- | --- | --- | --- |
| T006 | App Shell + 路由 + 占位页 | 待补录 | `03a3eb7` | 待补录 | 待补录 | 首个 feat commit,建立 `lib/app/router.dart` 与占位页骨架 |
| T007 | 首页今日练习 | 待补录 | `4fb7b31` | 待补录 | 待补录 | 引入 `TodayPracticeController`、`practice_plan_constants` |
| T007_FIX | 修复 unknown taskId 污染完成状态 | 待补录 | `94e2833` | 待补录 | 待补录 | commit message: tighten today practice state handling |
| T008 | 和弦库 + 指法图 | 待补录 | `c16d922` | 待补录 | 待补录 | 引入 `chord_library_controller`、`built_in_chords`、指法图组件 |
| T008_FIX | 修复和弦图方向与 ChordFingering.validate | 待补录 | `4e1437f` | 待补录 | 待补录 | commit message: correct chord diagram orientation and validation |
| T008_FIX_DOC | 修正 high-G 相关误导注释 | 待补录 | `8f59c5d` | 待补录 | 待补录 | commit message: clarify ukulele string numbering,涉及 chord_fingering 与 chord_diagram 注释 |
| T009 | 单音练习 | 待补录 | `3aa7e3d` | 待补录 | 待补录 | 引入 `single_note_practice_controller`、`built_in_single_notes` |
| T009_FIX | 修正单音练习文案和注释 | 待补录 | `96a0b66` | 待补录 | 待补录 | commit message: clarify single note practice copy |
| T010 | 基础可视化节拍器 | 待补录 | `aedebf3` | 待补录 | 待补录 | 引入 `MetronomeController` 与可视化节拍器 UI |
| T010_FIX | 修正节拍器注释和测试边界 | 待补录 | `ef021a1` | 待补录 | 待补录 | commit message: clarify metronome timer and audio notes |
| T011 | 手动调音辅助页面 | 待补录 | `0ef5366` | 待补录 | 待补录 | commit message: add tuner guide |
| T011_FIX | 修正 tuner 数据注释误导问题 | 待补录 | `c2f99d7` | 待补录 | 待补录 | commit message: clarify tuner string comments |

> 说明:T006-T011 段的所有字段在本任务(T012_DOCS_COLLABORATION_BASELINE)及其 FIX 中无法从 Git 历史、现有 docs 或代码中直接验证交付完成情况,统一以"待补录"标注,后续由对应任务的执行 Agent 在必要时回填。

---

## T012 - 录音回放基础版 + 一致性 FIX + 文档协作

| Task ID | 任务名称 | 状态 | Commit | 测试总数 | GPT 复审 | 遗留说明 |
| --- | --- | --- | --- | --- | --- | --- |
| T012_BUILD_BASIC_RECORDING_PLAYBACK | 实现录音回放基础版(MVP 占位式练习页面) | 通过 | `e0ae6c4` | 174 | 通过 | 引入 `RecordingPracticeController`、`SelfRating`、模拟回放流程页面;其后有两个 FIX |
| T012_FIX_RECORDING_START_CLEARS_METADATA | 修复 `startRecording` 清空 selfRating/note 的行为 | 通过 | `edd457b` | 174 | 通过 | 让 Controller 行为、状态机注释、测试断言三者保持一致 |
| T012_FIX_RECORDING_PLAYBACK_START_BUTTON | 修复播放中"开始模拟录音"按钮误禁用 | 通过 | `974198d` | 175 | 通过 | 让 UI 启用条件与 Controller"播放中可 start"契约一致 |
| T012_DOCS_COLLABORATION_BASELINE | 建立任务台账与技术债台账 | 通过 | `7ca3f36` | 175 | 通过 | 建立 `TASK_LEDGER.md` 与 `TECH_DEBT.md`,后续有文档一致性 FIX |
| T012_FIX_DOCS_LEDGER_CONSISTENCY | 修复协作文档的状态矛盾、技术债证据不足与任务漏记 | 通过 | `c533272` | 175 | 通过 | 统一 T006-T011 状态为"待补录";删除证据不足的 TD-002;补充本任务与上一步的台账条目 |
| T013_PREP_LOCAL_PERSISTENCE_AUDIT | T013 本地持久化只读审计 | 通过 | 无 | 175 | 待复审 | 只读审计,无代码改动;为 T013.1 ~ T013.5 拆分提供依据 |
| T013.1_LOCAL_DB_FOUNDATION | Drift 数据库底座 | 通过 | `52bc2f9` | 184 | 通过 | 引入 `AppDatabase`、三张表的 schema 文件、`app_database_provider`,schemaVersion = 1;无 DAO / Repository;已在 `app_database_test.dart` 中覆盖 schema 与三张表基础往返 |
| T013.2_LOCAL_REPOSITORIES | 本地 Repository 层(Drift) | 通过 | `67d7189` | 237 | 通过 | 引入 `DriftCompletedTasksRepository`、`DriftPracticeRecordRepository`、`DriftUserSettingsRepository`;统一 localDate / UTC 等 Repository 边界契约;本任务有范围与契约 FIX |
| T013.2_FIX_REPOSITORY_SCOPE_AND_CONTRACTS | 修复 Repository 范围与契约 | 通过 | `b27f6d9` | 237 | 通过 | 修复 T013.2 中 Repository 暴露了不必要的方法、localDate 时区契约缺失等问题,缩窄 API 并补齐契约测试 |
| T013.3_PREP_HOME_PERSISTENCE_INTEGRATION | 首页持久化整合只读审计 | 通过 | 无 | 237 | 待复审 | 只读审计,无代码改动;最终采用 AsyncNotifier + HomePage AsyncValue 路径,放弃启动前 Bootstrap |
| T013.3_PERSIST_TODAY_PRACTICE | 首页 installDate + 今日任务完成状态接入 Drift | 通过 | `4296036` | 253 | 通过 | 将 `InstallDateService` 改为 `Future<DateTime> getInstallDate()`,新增 `DriftInstallDateService`(single-flight + ISO-8601 解析),`TodayPracticeController` 改为 `AsyncNotifier<TodayPracticeState>`,`HomePage` 处理 `AsyncValue` 三态(loading/error/data + retry),`toggleTaskCompleted` 返回 `Future<bool>` 并按 taskId 串行化,`widget_test.dart` 改为注入 `DriftInstallDateService` 不再走 `path_provider`;后续有两个 FIX |
| T013.3_FIX_PENDING_RESULT_AND_INSTALL_DATE_BOUNDARY | 修复 toggle 结果与 install date 边界 | 通过 | `6cd01cd` | 266 | 通过 | `toggleTaskCompleted` 改返回 `ToggleTaskResult`(success/ignored/failure);新增 `pendingTaskIds` 让 Checkbox 在写盘期间禁用;`completedAt` 来源切换到 `clockProvider`;`InstallDateService` 实现 `DriftInstallDateService`,`parseIsoUtc` 拒绝无时区设计符的字符串 |
| T013.3_FIX_LOCAL_DAY_AND_ERROR_UI | 修复本地日与错误 UI | 通过 | `0d8da00` | 275 | 通过 | 把 localToday / localInstallDate 在调用 `calculatePracticeDayIndex` 之前先算好,消除 UTC ↔ local 偏移错位;HomePage 错误视图不再渲染 `error.toString()`,只显示固定友好文案 + 重试按钮 |
| T013.4_PREP_RECORDING_HISTORY_INTEGRATION | 录音与历史页整合只读审计 | 通过 | 无 | 275 | 通过 | 只读审计,无代码改动;最终采用首席架构师修订方案(规范 UUID v4 + 共享日期解析 + SelfRating 映射位于 recording/application),不创建 T013.4A 之前无法验证的假说 |
| T013.4A0_RECORDING_SAVE_FOUNDATION | 录音保存基础设施(ID Generator + Mapper + Resolver + Clock) | 通过 | `9530b20` | 297 | 通过 | 引入 `PracticeRecordIdGenerator`(UUID v4)、`mapSelfRatingToSelfAssessment`、`practiceDayResolverProvider` 与 `appClockProvider`,Repository 不再生成 id;后续有 `PracticeDayContext` 不变量 FIX |
| T013.4A0_FIX_PRACTICE_DAY_CONTEXT_INVARIANTS | 修复 PracticeDayContext 不变量 | 通过 | `f854b6e` | 305 | 通过 | 把 `PracticeDayContext` 的 `dayIndex` 与 `today` / `installDate` 的本地午夜约束改为 Release-safe 抛错,补齐单测覆盖 |
| T013.4B_BUILD_PRACTICE_RECORDS_LIST | 练习记录列表页(本地列表 + 进入既有详情路由) | 通过 | `cbffb85` | 361 | 待复审 | 新增 `practice_records_list_controller.dart`(StreamNotifier 订阅 `repository.watchAll()`)、`practice_record_list_item.dart`(枚举全映射 + 长内容截断)、重写 `practice_records_page.dart`(Loading/Error/Empty/Data 四态 + 重试 + 详情路由入口);列表 Provider 不持有排序与查询逻辑,Repository 仍是排序唯一边界;`ref.onDispose` 取消订阅并关闭内部 StreamController,`retry()` 通过 `ref.invalidateSelf` 重建订阅;新增测试 23 项覆盖 12 项要求 + 控制器四态 + 标签全映射(初版报告误写为 21,T013.4C_FIX 已校正);未实现删除、详情内容、编辑、录音、搜索/筛选/分页 |
| T013.4C_BUILD_RECORD_DETAIL_AND_DELETE | 练习记录详情页与删除流程 | 通过 | `892c1be` | 389 | 待复审 | 新增 `practice_record_detail_controller.dart`(AsyncNotifier family(`recordId`)+ `DeleteResult` 三态机 + `_isDeleting` 互斥锁 + `ref.mounted` 守卫)、重写 `practice_record_detail_page.dart`(Loading/Error/NotFound/Data 四态 + 确认对话框 + OutlinedButton 删除 + SnackBar + `pop` 优先、`canPop` 失败回退到 `context.go('/records')`);复用 T013.4B 已有的 `practiceTypeLabel` / `selfAssessmentLabel` 与新提取的 `formatPracticeDate` / `formatPracticeDuration` / `practiceTagLabel`,同时为标签值单元格加上稳定的 `ValueKey` 便于测试;Repository 接口 / Drift 实现 / domain model / schema 均未改动;新增测试 28 项覆盖 21 项要求(全 5 PracticeType × 全 3 SelfAssessment × 全 6 PracticeTag 映射、所有状态、删除三态、dispose 期间加载/删除、`pumpAndSettle` 后 SnackBar 仅出现一次);最终测试数 361 + 28 − 0 = 389;`T013.4C_FIX_DELETE_PROGRESS_CONTRACT` 指出 `_isDeleting` 仅为私有 bool 不触发页面重建、`findsOneWidget` 不能证 SnackBar 唯一、T013.4B 测试数为 23 而非 21 |
| T013.4C_FIX_DELETE_PROGRESS_CONTRACT | 修复删除进度的可观察 UI 契约 | 通过 | 本次提交 | 397 | 待复审 | 把删除进行中状态从 Controller 的私有 `_isDeleting` 提升为 `PracticeRecordDetailState.isDeleting`,由 `AsyncNotifier.state = AsyncData(...)` 在删除开始 / 结束两次发布;Controller 仍保留 `_isDeleting` 作为同步并发互斥锁(防御性,不与状态机漂移),并在 `ref.mounted` 失效时跳过状态发布;`PracticeRecordDetailPage` 从 WATCHED state 读取 `isDeleting` 而非从 Controller getter,因此 `ref.watch` 会在删除开始 / 结束两次重建 `_DataView`,OutlinedButton 自动变为 `onPressed: null` 并展示 `CircularProgressIndicator` + "正在删除…" 文案;`_confirmAndDelete` 在 showDialog 前 / 后两次再读 `isDeleting` 防止用户在异步窗口内触发第二次确认;保留 `_DataView` 加载详情显示(不通过清空 record 来表达删除中),失败后状态机会把 `isDeleting` 复位以便同一份测试同时验证按钮恢复与失败 SnackBar;成功 SnackBar 仍然只走 `_confirmAndDelete` 的 `DeleteResult.success` 单分支、`pumpAndSettle` 后通过 `find.byKey('practice-record-delete-success-snackbar')` 在 5 s 缓冲期内断言"无后续排队 SnackBar";新增 8 项 widget / state 测试覆盖"pending 时显示删除中 + 按钮禁用 + 二次点击不开对话框 + Repository 仅调用 1 次"四项契约、"failure 后保留详情 + isDeleting 解除 + 按钮恢复 + 可重试"两项契约、"success 后仅一条 SnackBar + 5 s 后无第二条"两项契约,以及"dispose during delete 不产生异常"一项契约;更正 T013.4B 报告中的测试数 21 → 23;最终测试数 389 + 8 − 0 = 397 |