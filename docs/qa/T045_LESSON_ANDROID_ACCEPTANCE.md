# T045 Lesson Android Acceptance — BLOCKED

> 第一节课程（`/lessons/c_am_down_4x4`）真机验收在第 1 步即失败。
> 任务标记 **BLOCKED**，不写 Approved，不顺手修复生产代码。
> 修复交由独立任务 `T045A_FIX_LESSON_CHILD_ROUTE_REDIRECT`。

## Document Status

| 字段 | 值 |
| --- | --- |
| Task ID | `T045_LESSON_TEST_AND_ANDROID_ACCEPTANCE` |
| 起始 HEAD | `6b57669d8a2f96afb60c0ce28e2ffd754288b112` |
| 当前 HEAD | `6b57669d8a2f96afb60c0ce28e2ffd754288b112`（**未**前进） |
| 测试基线 | 738 → 740（仅在 `test/` 下新增 2 项；**未**修改 `lib/`） |
| 设备 | HUAWEI CDY-AN90 / Android 10 |
| 自动化测试 | `flutter analyze` 0 issue；`flutter test` 740 / 740 通过 |
| 真机验收 | 第 1 步 FAIL：点击 "开始课程" 后直接返回主页，**未**进入 `/lessons/c_am_down_4x4` |
| 状态 | **BLOCKED**（用户手动 FAIL） |

## 工作区状态

| 路径 | 变更类型 | 备注 |
| --- | --- | --- |
| `test/features/lesson_c_am_down_4x4/presentation/lesson_navigation_isolation_test.dart` | 新增 | T045 补测：导航隔离 + 路由往返（**未**经真机验证） |
| `lib/` | 无变更 | 已遵守 "发现生产缺陷时停止并报告，不顺手修复" |
| `docs/` | 新增本文件 | 记录 BLOCKED 证据 |
| `tasks/` | 无新增任务条目 | 推荐任务 `T045A_FIX_LESSON_CHILD_ROUTE_REDIRECT` 尚未登记 |

## 用户真机 FAIL（来自用户，非 Agent 代写）

1. C 和弦详情页能看到 "开始课程" 入口（视觉确认 OK）。
2. **点击 "开始课程" 后立即返回主页，**`LessonPage` **未渲染。**

## 根因分析（只读诊断，未修复）

`lib/app/router.dart:67-90` 中 `/lessons` 父路由定义了 `redirect: (_, __) => '/'`，意图是 "父路由不应被直接访问"。
但 go_router 17.x 在解析**子路由** `/lessons/:lessonId` 时仍会调用父路由的 `redirect`，导致：

- 每次 `context.push('/lessons/c_am_down_4x4')`（来自 `lesson_intro_card.dart:109`）先匹配父 `/lessons`，
- 父 redirect 立刻返回 `'/'`，
- `LessonPage` 永远不挂载，用户被推回 HomePage。

T044 在生产代码注释（[router.dart:67-79](lib/app/router.dart#L67)）错误假设父 redirect 仅对"直接访问 `/lessons`"生效。

## 为什么现有自动化测试未捕获

| 测试 | 文件 | 是否经过生产 `appRouter` | 是否触发 redirect bug |
| --- | --- | --- | --- |
| `LessonIntroCard` 入口测试 | `lesson_page_test.dart:122-188` | ❌ 用本地 spy GoRouter，父 `/lessons` 用了 `builder` 而非 `redirect` | ❌ 绕过 |
| `chord_detail_page_test.dart` 入口可见性测试 | `chord_detail_page_test.dart:20-59` | ❌ 只断言 `LessonIntroCard` 文本存在，未 push | ❌ 未触发 |
| 新增 `lesson_navigation_isolation_test.dart` | T045 | ❌ 同样用本地 spy GoRouter，父 `/lessons` 用了 `builder` | ❌ 绕过 |
| 任何端到端测试启动 `appRouter` 并 push `/lessons/:id` | （不存在） | — | ❌ **缺位** |

**核心差距**：仓库**没有**任何测试用 `MaterialApp.router(routerConfig: appRouter, ...)` 启动**真实**路由器并触发 `context.push('/lessons/c_am_down_4x4')`。
修复 T045A 时必须补一条端到端测试作为回归网，否则修复也会被未来重构再次悄悄回归。

## 验收范围缩减

| 步骤 | 状态 |
| --- | --- |
| 1. C 和弦页课程入口可见 | ✅ 视觉确认（用户） |
| 2. 课程页面内容与节奏图正常 | ❌ **未到达**（步骤 1 push 后被 redirect 回首页） |
| 3. 页面滚动及文字无截断 | ❌ 未到达 |
| 4. 节拍器入口与返回正常，未自动启动或改 BPM | ❌ 未到达 |
| 5. 录音入口与返回正常，未自动录音 | ❌ 未到达 |
| 6. 原有练习记录和音频仍存在 | ⚠️ **N/A**（前期 `flutter install` 卸载了旧版，数据已清空；用户已确认继续） |
| 7. 无崩溃或明显 UI 异常 | ✅ 视觉确认无崩溃，仅路由错误 |

## 推荐独立修复任务

### `T045A_FIX_LESSON_CHILD_ROUTE_REDIRECT`

**范围**：
- 修改 `lib/app/router.dart` `/lessons` 父路由 `redirect`，使其**仅**在用户直接访问 `/lessons` 时返回 `'/'`；当 `state.matchedLocation` 或子路径被解析时返回 `null`（不重定向）。具体判别条件须在任务里给出（`state.fullPath` / `state.pathParameters` / 子路由命中后再回放）。
- 新增端到端测试 `test/integration/lesson_route_e2e_test.dart`，使用 `MaterialApp.router(routerConfig: appRouter, ...)` + `ProviderScope`，断言 `context.push('/lessons/c_am_down_4x4')` 后 `LessonPage` 可见、`build` 已挂载。

**不做的事**：
- 不修复 `lesson_page_test.dart` 中已有 spy 测试的写法（保留 spy 用于 unit-level 隔离测试）。
- 不删除 `lesson_navigation_isolation_test.dart`（它在 unit 层仍有效）。
- 不顺手调整其他路由或新增功能。

**验收标准**：
- 真机 7 项全部通过。
- 自动化测试数 ≥ 当前 740（含新增端到端测试）。
- 不破坏现有 740 项测试。

---

## T045A 修复交付记录

| 字段 | 值 |
| --- | --- |
| Task ID | `T045A_FIX_LESSON_CHILD_ROUTE_REDIRECT` |
| 起始 HEAD | `6b57669d8a2f96afb60c0ce28e2ffd754288b112` |
| 修复后 HEAD | 待提交（见末尾 commit hash） |
| 测试基线 | 740 → 744（新增 4 项 e2e；既有 740 全部通过） |
| 修复 commit | 待提交（待用户在真机确认后填写） |
| 真机验收 | 待用户在原设备覆盖安装后点击"开始课程"确认 |

### 改动摘要

- `lib/app/router.dart` `/lessons` 父路由 redirect 由 `(_, __) => '/'` 改为按 `state.uri.path` 区分：
  - `state.uri.path == '/lessons'`（用户直接访问父级）→ 仍然返回 `'/'`；
  - 其它（子路由 `/lessons/:lessonId` 被解析）→ 返回 `null`，让子路由 builder 正常挂载。
- `test/integration/lesson_route_e2e_test.dart` 新增：用生产 `appRouter` + `MaterialApp.router(routerConfig: appRouter)` 验证 4 项场景（直接 push 有效 id / 直接 push 未知 id / 直接访问父级 / 从 C 和弦点击"开始课程"）。
- `test/features/lesson_c_am_down_4x4/presentation/lesson_navigation_isolation_test.dart` 顶部 doc 加一句："本测试不经过生产 appRouter，不能替代 `lesson_route_e2e_test.dart` 的端到端断言"——既不重复也保留 unit-level 隔离证据。

### 数据保留状态（事实记录，不得声称 PASS）

- T045 早期真机阶段使用了 `flutter install`，按 Android 平台行为会卸载旧版并清空应用数据；旧版（含未备份的练习记录、录音音频、节拍器设置、安装日期等）**已不可恢复地丢失**。
- 本次 T045A 修复仅修改路由配置与新增测试代码，不涉及任何数据库迁移或数据写入；用户重新覆盖安装（`adb install -r`）后能正常使用，但**不存在"数据保留 PASS"的验收口径**——真实情况是**数据已在前置阶段被清除，且本任务范围内没有恢复手段**。
- 验收表中的第 6 项（"原有练习记录和音频仍存在"）保持 **N/A**，不得改写为通过。

### 真机复测要求（用户在原设备上）

1. 仅使用 `adb install -r build/app/outputs/flutter-apk/app-debug.apk` 覆盖安装；**禁止** `flutter install`、卸载或清除数据。
2. 不撤销权限，不输出完整设备序列号。
3. 安装后从主页进入 `和弦库` → `C 和弦` → 点击 `开始课程`：
   - **预期**：课程详情页真实显示（页面标题 `课程详情`、步骤列表、`StrumPatternDiagram`、`C 和弦 / Am 和弦` 指法参考）。
   - **FAIL 判定**：页面立即跳回主页，或停在加载/空白态。
4. 用户确认前 `T045A` 不得标记 Approved。

### 自动化验收（已运行）

- `flutter analyze` → No issues found。
- `flutter test` → 744 / 744 通过（基线 740 + 新增 4 项 e2e）。
- `git diff --check` → 无空白错误。