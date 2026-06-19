# TODO 索引 (TODO_INDEX)

> 本文档是 ukulele_app 项目的任务总索引，按执行顺序排列。

## 任务总览

| Task ID | 名称 | Agent | 状态 | 编码 |
|---------|------|-------|------|------|
| T000 | 初始化项目文档和 Agent 体系 | 00-chief-architect | 已完成 | ❌ |
| T001 | 研究竞品和文档 | 01-product-manager + 02-flutter-architect + 04-audio-engineer + 08-compliance-reviewer | 待开始 | ❌ |
| T002 | 最终确定 MVP PRD | 01-product-manager | 待开始 | ❌ |
| T003 | 最终确定技术架构 | 02-flutter-architect | 待开始 | ❌ |
| T004 | 创建 Flutter 项目 | 02-flutter-architect | 待开始 | ✅ 工程初始化 |
| T005 | 添加核心依赖 | 02-flutter-architect | 待开始 | ✅ |
| T006 | 构建导航和 App Shell | 02-flutter-architect | 待开始 | ✅ |
| T007 | 构建首页和今日练习 | 03-mobile-ui-engineer | 待开始 | ✅ |
| T008 | 构建和弦库和指法图 | 03-mobile-ui-engineer | 待开始 | ✅ |
| T009 | 构建基础调音器技术验证 | 04-audio-engineer | 待开始 | ✅ |
| T010 | 构建节拍器 | 04-audio-engineer | 待开始 | ✅ |
| T011 | 构建录音和回放 | 04-audio-engineer | 待开始 | ✅ |
| T012 | 构建自评 | 03-mobile-ui-engineer | 待开始 | ✅ |
| T013 | 构建本地练习记录 | 06-local-data-engineer | 待开始 | ✅ |
| T014 | MVP QA 和打磨 | 07-qa-reviewer | 待开始 | ✅ |

---

## T000: 初始化项目文档和 Agent 体系

**Task ID**: T000_INIT_PROJECT_DOCS_AND_AGENTS

**目标**: 创建完整的项目文档、Agent 角色定义、任务拆分体系

**建议执行 Agent**: 00-chief-architect

**输入文档**:
- 用户需求（来自本 Prompt）

**输出文件**:
- README.md
- docs/ (所有文档)
- agents/ (所有 Agent 文档)
- tasks/ (所有任务文档)
- handoff/ (所有模板)
- prompts/ (所有模板)
- research/ (所有研究计划)

**验收标准**:
- [ ] 目录结构完整
- [ ] 所有文档已创建
- [ ] 所有 Agent 文档包含 10 个章节
- [ ] README 说明项目目标
- [ ] MVP_SCOPE 明确做/不做/预留

**编码**: ❌ 否

---

## T001: 研究竞品和文档

**Task ID**: T001_RESEARCH_COMPETITORS_AND_DOCS

**目标**: 收集竞品分析、技术文档、音频方案、合规政策，为后续开发提供参考

**建议执行 Agent**: 01-product-manager + 02-flutter-architect + 04-audio-engineer + 08-compliance-reviewer

**输入文档**:
- PRD.md
- docs/MVP_SCOPE.md
- docs/TECH_STACK.md
- docs/AUDIO_RECOGNITION_PLAN.md
- docs/COMPLIANCE.md
- research/FIRECRAWL_RESEARCH_PLAN.md
- research/CONTEXT7_DOCS_PLAN.md

**输出文件**:
- research/competitor_analysis.md（产品竞品分析）
- research/flutter_docs_notes.md（Flutter / Riverpod / Drift / go_router 关键文档摘录）
- research/audio_tech_notes.md（record / just_audio / 调音器 / 音高检测初步技术结论）
- research/compliance_policy_notes.md（麦克风 / 录音 / 版权 / 用户内容政策风险）
- research/T001_RESEARCH_SUMMARY.md（T001 研究结论汇总，支持 T002/T003 决策）

**验收标准**:
- [ ] 产品竞品分析完成（至少 3 个竞品）
- [ ] Flutter / Riverpod / Drift / go_router 关键文档已通过 Context7 确认
- [ ] record / just_audio / 调音器 / 音高检测方案已有初步技术结论
- [ ] 麦克风、录音、版权、用户内容政策风险已整理
- [ ] 研究结论能支持 T002（PRD）和 T003（技术架构）
- [ ] Chief Architect 审核通过

**编码**: ❌ 否

---

## T002: 最终确定 MVP PRD

**Task ID**: T002_FINALIZE_MVP_PRD

**目标**: 完善 PRD，使其足够指导后续任务拆分

**建议执行 Agent**: 01-product-manager

**输入文档**:
- docs/PRD.md (草稿)
- T001 研究结果

**输出文件**:
- docs/PRD.md (最终版)

**验收标准**:
- [ ] 用户故事完整
- [ ] 功能范围明确
- [ ] 验收标准可测试
- [ ] Chief Architect 审核通过

**编码**: ❌ 否

---

## T003: 最终确定技术架构

**Task ID**: T003_FINALIZE_TECH_ARCHITECTURE

**目标**: 完善 TECH_STACK 和 ARCHITECTURE 文档

**建议执行 Agent**: 02-flutter-architect

**输入文档**:
- docs/TECH_STACK.md (草稿)
- docs/ARCHITECTURE.md (草稿)
- T001 研究结果

**输出文件**:
- docs/TECH_STACK.md (最终版)
- docs/ARCHITECTURE.md (最终版)

**验收标准**:
- [ ] 技术选型已确定
- [ ] 目录结构已定义
- [ ] 接口预留已明确
- [ ] Chief Architect 审核通过

**编码**: ❌ 否

---

## T004: 创建 Flutter 项目

**Task ID**: T004_CREATE_FLUTTER_PROJECT_SHELL

**目标**: 创建可运行的 Flutter 项目空壳（工程初始化）

**建议执行 Agent**: 02-flutter-architect

**输入文档**:
- docs/TECH_STACK.md
- docs/ARCHITECTURE.md

**输出文件**:
- Flutter 项目文件 (pubspec.yaml, lib/, android/ 等)

**验收标准**:
- [ ] flutter create 成功
- [ ] 项目可打开
- [ ] Android 构建配置正确
- [ ] 仅创建空壳，**不添加任何业务代码**
- [ ] pubspec.yaml 仅保留默认依赖，**不预先写入** MVP 业务依赖（业务依赖在 T005 写入）

**编码**: ✅ 是（工程初始化）

> **说明**："工程初始化"指 `flutter create` 创建项目骨架（`pubspec.yaml` / `lib/main.dart` / `android/` 等默认结构），**不包含**业务路由、业务页面、业务依赖。这部分工作分别由 T005 / T006 / T007+ 等后续任务完成。

---

## T005: 添加核心依赖

**Task ID**: T005_ADD_CORE_DEPENDENCIES

**目标**: 配置 pubspec.yaml，添加 Riverpod, Drift, go_router 等核心依赖

**建议执行 Agent**: 02-flutter-architect

**输入文档**:
- docs/TECH_STACK.md
- T004 创建的项目

**输出文件**:
- pubspec.yaml (更新)

**验收标准**:
- [ ] pubspec.yaml 依赖配置完成
- [ ] flutter pub get 成功
- [ ] 无版本冲突

**编码**: ✅ 是

---

## T006: 构建导航和 App Shell

**Task ID**: T006_BUILD_NAVIGATION_AND_APP_SHELL

**目标**: 配置 go_router 路由，构建 App Shell 页面结构

**建议执行 Agent**: 02-flutter-architect

**输入文档**:
- docs/ARCHITECTURE.md
- docs/ROADMAP.md

**输出文件**:
- lib/app/router.dart
- lib/app/app.dart
- lib/app/theme.dart
- 基础页面占位

**验收标准**:
- [ ] 路由配置完成
- [ ] 页面可跳转
- [ ] 主题配置正确

**编码**: ✅ 是

---

## T007: 构建首页和今日练习

**Task ID**: T007_BUILD_HOME_AND_TODAY_PRACTICE

**目标**: 实现 HomePage 和今日练习计划展示

**建议执行 Agent**: 03-mobile-ui-engineer

**输入文档**:
- docs/PRD.md
- docs/ARCHITECTURE.md
- T006 路由配置

**输出文件**:
- lib/features/home/

**验收标准**:
- [ ] HomePage 可显示
- [ ] 今日练习任务卡片
- [ ] 快速操作入口

**编码**: ✅ 是

---

## T008: 构建和弦库和指法图

**Task ID**: T008_BUILD_CHORD_LIBRARY_AND_DIAGRAMS

**目标**: 实现和弦库页面和指法图展示

**建议执行 Agent**: 03-mobile-ui-engineer + 05-music-domain-expert

**输入文档**:
- docs/PRD.md
- docs/DATA_MODEL_DRAFT.md
- 05-music-domain-expert 提供的和弦数据

**输出文件**:
- lib/features/chord_library/
- lib/features/chord_diagrams/

**验收标准**:
- [ ] 和弦列表可浏览
- [ ] 指法图正确显示
- [ ] 至少支持 C, F, G, Am

**编码**: ✅ 是

---

## T009: 构建基础调音器技术验证

**Task ID**: T009_BUILD_BASIC_TUNER_SPIKE

**目标**: 实现调音器，验证频率检测技术

**建议执行 Agent**: 04-audio-engineer

**输入文档**:
- docs/AUDIO_RECOGNITION_PLAN.md
- docs/MVP_SCOPE.md

**输出文件**:
- lib/features/tuner/
- 调音器服务

**验收标准**:
- [ ] 能检测 G/C/E/A 四弦
- [ ] 频率显示正常
- [ ] 偏高/偏低/接近准确判断可理解
- [ ] 2 秒内给出反馈
- [ ] 不崩溃、不明显卡顿
- [ ] ±10 cents 作为 MVP 体验目标；若无法稳定达到，标记为"实验性调音器"，不阻塞整体 MVP

**编码**: ✅ 是

---

## T010: 构建节拍器

**Task ID**: T010_BUILD_METRONOME

**目标**: 实现节拍器功能

**建议执行 Agent**: 04-audio-engineer

**输入文档**:
- docs/AUDIO_RECOGNITION_PLAN.md
- docs/MVP_SCOPE.md

**输出文件**:
- lib/features/metronome/

**验收标准**:
- [ ] BPM 可调 (50-200)
- [ ] 节拍声音正常
- [ ] 精度误差 < 5 BPM

**编码**: ✅ 是

---

## T011: 构建录音和回放

**Task ID**: T011_BUILD_RECORDING_AND_PLAYBACK

**目标**: 实现录音和回放功能

**建议执行 Agent**: 04-audio-engineer

**输入文档**:
- docs/AUDIO_RECOGNITION_PLAN.md
- docs/COMPLIANCE.md

**输出文件**:
- lib/features/recording/
- lib/features/playback/

**验收标准**:
- [ ] 录音正常（最长 5 分钟）
- [ ] 回放正常
- [ ] 录音保存到本地
- [ ] 权限处理友好

**编码**: ✅ 是

---

## T012: 构建自评

**Task ID**: T012_BUILD_SELF_ASSESSMENT

**目标**: 实现手动自评功能

**建议执行 Agent**: 03-mobile-ui-engineer

**输入文档**:
- docs/PRD.md
- docs/DATA_MODEL_DRAFT.md

**输出文件**:
- lib/features/self_assessment/

**验收标准**:
- [ ] 可选择自评等级（好/一般/需改进）
- [ ] 自评结果保存
- [ ] 与录音关联

**编码**: ✅ 是

---

## T013: 构建本地练习记录

**Task ID**: T013_BUILD_LOCAL_PRACTICE_RECORDS

**目标**: 实现练习记录持久化和查看

**建议执行 Agent**: 06-local-data-engineer

**输入文档**:
- docs/DATA_MODEL_DRAFT.md
- docs/ARCHITECTURE.md

**输出文件**:
- lib/data/database/
- lib/features/practice_records/

**验收标准**:
- [ ] 练习记录保存到 SQLite
- [ ] 历史记录可查看
- [ ] 录音可回放
- [ ] 数据持久化正常

**编码**: ✅ 是

---

## T014: MVP QA 和打磨

**Task ID**: T014_MVP_QA_AND_POLISH

**目标**: QA 验收、Bug 修复、打磨、准备发布

**建议执行 Agent**: 07-qa-reviewer + 03-mobile-ui-engineer

**输入文档**:
- docs/PRD.md
- 所有已完成功能

**输出文件**:
- Bug 修复
- 完善文档

**验收标准**:
- [ ] 所有 P0 功能测试通过
- [ ] 无崩溃
- [ ] 离线流程完整
- [ ] 可提交 Google Play 内测

**编码**: ✅ 是

---

## Phase 映射

| Phase | 包含任务 |
|-------|----------|
| Phase 0 | T000 |
| Phase 1 | T004, T005, T006 |
| Phase 2 | T007, T008 |
| Phase 3 | T009 |
| Phase 4 | T010, T011, T012 |
| Phase 5 | T013 |
| Phase 6 | T014 |

---

## 文档版本

| 版本 | 日期 | 修改内容 |
|------|------|----------|
| 0.1 | 2026-06-19 | 初始版本 |
