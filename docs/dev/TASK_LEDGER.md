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
| T012_DOCS_COLLABORATION_BASELINE | 建立任务台账与技术债台账 | 待复审 | `7ca3f36` | 175 | 待复审 | 建立 `TASK_LEDGER.md` 与 `TECH_DEBT.md`,后续有文档一致性 FIX |
| T012_FIX_DOCS_LEDGER_CONSISTENCY | 修复协作文档的状态矛盾、技术债证据不足与任务漏记 | 待补录 | 待补录 | 待补录 | 待补录 | 统一 T006-T011 状态为"待补录";删除证据不足的 TD-002;补充本任务与上一步的台账条目 |