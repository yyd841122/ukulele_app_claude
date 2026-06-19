# T001 Research Summary

> T001 任务汇总 - 由 Chief Architect 角色汇总所有研究结论。
> 访问日期：2026-06-19
> 研究 Agent：00-chief-architect（汇总）+ 01-product-manager / 02-flutter-architect / 04-audio-engineer / 08-compliance-reviewer（产出）

---

## Task Overview

**任务**：T001_RESEARCH_COMPETITORS_AND_DOCS
**目标**：收集并整理 4 类研究资料（竞品 / 技术文档 / 音频 / 合规），输出 5 个研究文档，为 T002-T005 提供决策依据。
**状态**：✅ 已完成初版（待 Step 2 / Step 3 反思修正）

---

## Agents Involved

| Agent | 角色 | 输出 |
|-------|------|------|
| 01-product-manager | Product Manager | research/competitor_analysis.md |
| 02-flutter-architect | Flutter Architect | research/flutter_docs_notes.md |
| 04-audio-engineer | Audio Engineer | research/audio_tech_notes.md |
| 08-compliance-reviewer | Compliance Reviewer | research/compliance_policy_notes.md |
| 00-chief-architect | Chief Architect | research/T001_RESEARCH_SUMMARY.md（本文件） |

---

## Files Created

```
research/
  competitor_analysis.md        ✅ 竞品分析（PM）
  flutter_docs_notes.md         ✅ Flutter 技术文档（Flutter Architect）
  audio_tech_notes.md           ✅ 音频技术研究（Audio Engineer）
  compliance_policy_notes.md    ✅ 合规政策研究（Compliance Reviewer）
  T001_RESEARCH_SUMMARY.md      ✅ 本汇总（Chief Architect）
```

---

## Key Findings

### 产品结论

1. **"今日练习"是 MVP 必备首页**：所有竞品都有"今日练什么"的一屏
2. **调音器 + 节拍器 + 录音回放 + 手动自评 = MVP 最简闭环**
3. **MVP 不做 AI 自动评分**（与 PRD §5.2 一致）
4. **MVP 不做完整歌曲库 / 视频课程 / 社区**（版权与成本双重风险）

### 技术结论

1. **Flutter 3.24+ / Dart 3.5+** 是合理起点（最终版本 T005 确认）
2. **Riverpod 3.x** 是当前推荐（`Notifier` / `AsyncNotifier` API）
3. **Drift + sqlite3_flutter_libs** 继续作为数据库方案
4. **go_router 14.x+** 继续作为路由方案
5. **Material 3 默认开启**（Flutter 3.16+）
6. **minSdkVersion 推荐 23**（因 record 要求 23，覆盖率损失 < 1%）

### 音频结论

1. **record 7.x 继续作为录音方案**
2. **just_audio 0.10.x 继续作为播放方案**
3. **调音器推荐路径 B**：record PCM 流 + Dart 自相关算法
4. **没有发现成熟的 Flutter 音高检测插件**，建议自实现
5. **±10 cents 仅作为体验目标**，不阻塞 MVP
6. **路径 C（Android 原生）作为备选**，但 MVP 不预先实施

### 合规结论

1. **麦克风权限申请必须延迟到用户点击相关功能时**
2. **录音全部本地保存**，MVP 不提供导出/分享
3. **MVP 内置内容全部自制或公版**
4. **MVP 不引入任何 UGC / AI 生成内容**
5. **MVP 不上架，但架构上需预留隐私说明 + 权限文案**

---

## Product Implications

### T002（PRD 定稿）必须解决

1. **"今日练习"轮换逻辑**：按天序号 / 按周 / 用户状态？
2. **"今日练习"内容列表**：T001 给出了内容类型，但具体清单需 T002
3. **调音器自动选弦 vs 手动选弦**：MVP 限定手动
4. **录音保存策略**：永久 / 30 天 / 90 天？
5. **MVP 是否需要"导出录音"按钮**：MVP 不做（合规风险）
6. **iOS 上架时间表**：T002 文档中明确"iOS 暂留"

---

## Technical Implications

### T003（技术架构定稿）必须解决

1. **是否启用 @riverpod 代码生成**：推荐启用
2. **minSdkVersion 是否提到 23**：推荐提到 23
3. **Drift schema 演进策略**：MVP schemaVersion=1，手写 MigrationStrategy
4. **go_router 路由错误页**：放在 `app/router.dart`
5. **Material 3 seed color**：选用尤克里里主题色（如木色）
6. **iOS 目录何时创建**：T004 不创建，T003 文档明确
7. **是否准备 Android 原生桥接代码**：暂不写，T009 失败再写

### T004（创建 Flutter 工程）注意事项

- 使用 `--org com.yupi.ukulele --platforms=android ukulele_app`
- 不锁版本，依赖版本由 T005 决定

### T005（添加依赖）注意事项

- **必须**通过 Context7 + pub.dev 查询最新稳定版
- **必须**保证 Riverpod 3.x + riverpod_annotation 3.x + riverpod_generator 3.x 三者一致
- **必须**验证 record 7.x 与 minSdk 23 的兼容性
- **必须**验证 permission_handler 3.1+ 与 compileSdk ≥33 的要求
- **必须**在 ADR 中记录每个版本决策

---

## Audio Implications

### T003（技术架构定稿）

1. **PCM 流处理用 Dart Isolate**（避免阻塞 UI）
2. **录音文件命名规则**：时间戳 + UUID
3. **调音器 UI 刷新策略**：每 100ms 一次（不强制 30fps）
4. **调音器采样率**：44100Hz（兼容 record 默认）

### T009（调音器 Spike）

1. **必须做硬验收**：权限 / PCM 流 / 单音识别 / 偏差提示 / 不崩溃
2. **不阻塞 MVP 的情况**：±10 cents 精度未达
3. **失败降级**：标记"实验性调音器"，UI 注明
4. **失败后续**：评估路径 C（Android 原生）

---

## Compliance Implications

### T003 必须解决

1. **AndroidManifest.xml 麦克风权限文案**（写入 ARCHITECTURE.md）
2. **录音文件路径规范**（`getApplicationDocumentsDirectory()`）
3. **权限申请弹窗文案**（写入 COMPLIANCE.md 附录）
4. **App 内隐私说明页面**（`/settings/about`）

### T004 / T005 必须配置

1. **AndroidManifest.xml**：`RECORD_AUDIO` + `MODIFY_AUDIO_SETTINGS`
2. **Info.plist（iOS 预留）**：`NSMicrophoneUsageDescription`
3. **不引入任何第三方分析 SDK**

### 商业化前必须补

1. 隐私政策网页
2. 内容分级
3. DMCA 通道（如有 UGC）

---

## Recommended Changes to PRD

> 本节为 Chief Architect 对 PRD 的建议改动。**T002 需根据这些建议决定是否改 PRD**。

### 新增章节建议

- §5.3 节拍器：明确"基础 4/4 拍 + 50-200 BPM"范围
- §9.2 体验验收：调音器降级为"实验性"也接受
- §6.1 性能需求：明确"±10 cents 是体验目标，非硬指标"

### 调整建议

- minSdkVersion：21 → **23**（record 要求）
- 调音器精度：作为体验目标

---

## Recommended Changes to TECH_STACK

### 调整建议

| 项目 | 候选范围 | 备注 |
|------|----------|------|
| Flutter SDK | ≥3.24.0 | 保留 |
| Dart SDK | ≥3.5.0 | **T005 必须复核**：可能 3.24 对应更高 Dart |
| flutter_riverpod | ^3.3.2 | **从 2.x 升级到 3.x**（Context7 当前主线） |
| riverpod_annotation | ^3.3.2 | 配套 |
| riverpod_generator | ^3.3.2 | 配套 dev |
| go_router | ^14.0.0 | 保留 |
| drift | ^2.20.0 | 保留（具体小版本 T005 查） |
| sqlite3_flutter_libs | ^0.5.0 | 保留 |
| record | ^7.0.0 | **从 5.x 升级到 7.x**（Context7 当前主线 7.0.1） |
| just_audio | ^0.10.0 | **从 0.6.x 升级到 0.10.x**（Context7 当前主线） |
| permission_handler | ^11.0.0 | 保留 |
| freezed | ^3.0.0 | 保留 |

### 不建议新增

经 T001 复核，**不需要**新增以下依赖（无实际使用场景）：

- ❌ `crypto` — 文件命名用时间戳即可，不需要加密 hash
- ❌ `device_info_plus` — MVP 不做版本分支判断

如有需要，T003 / T005 时再评估。

---

## Recommended Changes to ARCHITECTURE

### 新增建议

- **`shared/services/audio_stream_processor.dart`**：Dart 音高检测服务
- **`features/tuner/data/pitch_algorithm.dart`**：自相关算法实现
- **`shared/services/permission_service.dart`**：统一权限管理

### 调整建议

- **`shared/services/audio_recorder_service.dart`**：增加 PCM 流模式
- **`features/tuner/`**：明确分层（presentation / domain / data）

---

## Recommended Changes to MVP_SCOPE

### 不需要改动

MVP_SCOPE.md 已经定义清晰：
- 调音器精度不承诺专业级
- AI 评分明确禁止
- 录音本地保存、不可导出

### 微调建议

- **§2.2.1 调音器**：可补充"如精度未达 ±10 cents，标记为实验性调音器，UI 注明"
- **§1.1 节拍器**：明确"仅基础 4/4 拍"

---

## Open Decisions for T002

T002 必须决策（按优先级）：

1. **"今日练习"轮换逻辑**
2. **MVP 内置内容清单**（具体哪些练习）
3. **录音保存时长**（永久 / N 天）
4. **是否启用 @riverpod 代码生成**（或 T003 决定也行）
5. **Material 3 seed color 具体值**
6. **minSdkVersion：21 → 23 是否接受**

---

## Open Decisions for T003

T003 必须决策：

1. **iOS 目录创建时间**：T004 / V1 / 商业化前
2. **Drift 迁移策略**：手写 vs stepByStep
3. **是否准备 Android 原生桥接代码**：暂不 / 预留 / 立即实施
4. **权限弹窗前补充说明 UI 设计**
5. **App 内隐私说明页面内容**

---

## Chief Architect Review

### 研究质量评估

| 维度 | 评分 | 说明 |
|------|------|------|
| 文档完整性 | ✅ 5/5 | 5 个输出文件全部生成 |
| 来源可追溯 | ⚠️ 3/5 | 仅 Context7 可用，Firecrawl/WebSearch/WebFetch 不可用 |
| 结论可执行性 | ✅ 4/5 | 给出了 T002/T003/T005/T009 的具体决策项 |
| 风险识别 | ✅ 4/5 | 标注了"网络抓取工具不可用"为主要风险 |
| MVP 边界守住 | ✅ 5/5 | 严格遵守 PRD §5.2 + MVP_SCOPE |

### Blocker

1. **网络抓取工具不可用**（Firecrawl / WebSearch / WebFetch）
   - 影响：竞品事实、App Store / Google Play 政策原文、Flutter 实时版本号
   - 缓解：T002 在启用工具后复核
   - **严重度：中**（不阻塞决策，但需在 T002 强制复核"中"置信度结论）

2. **App Store / Google Play 政策原文未抓取**
   - 影响：合规结论全部基于模型知识
   - 缓解：T002 用 Firecrawl 抓取后复核
   - **严重度：中**（MVP 不上架，暂不影响开发）

3. **某些库版本号仍需 T005 实际查询**
   - 影响：TECH_STACK 版本范围仍为候选
   - 缓解：T005 通过 pub.dev 实时查询后写入
   - **严重度：低**（不阻塞 T002/T003）

4. **调音器精度（±10 cents）未实测**
   - 影响：是否真正可达体验目标未知
   - 缓解：T009 Spike 验证
   - **严重度：低**（已声明 ±10 cents 为体验目标，T009 失败不阻塞 MVP）

5. **record 7.x 要求 minSdk 23，与 PRD 21 冲突**
   - 影响：覆盖率与依赖选择冲突
   - 缓解：T002 / T003 决策 minSdk 是否提到 23
   - **严重度：中**（必须 T002 决策）

### Decision

```text
APPROVED_TO_CONTINUE_TO_T002: YES
APPROVED_TO_CONTINUE_TO_T003: YES（条件性，见下）
BLOCKERS:
1. 网络抓取工具不可用（建议 T002 启用 Firecrawl / WebSearch 后复核本研究中的"中"置信度结论）
2. App Store / Google Play 政策原文未抓取（T002 必须复核）
3. Flutter / 依赖版本号需 T005 实际查询（不阻塞 T002/T003）
4. 调音器精度需 T009 Spike 验证（不阻塞 T002/T003）
```

### 说明

- **T002 可以继续**：所有"必做项"都已研究；T002 主要基于本文档进行决策
- **T003 可以继续（条件性）**：技术选型已明确，但 T003 必须把"minSdk 23"等调整同步到 PRD / TECH_STACK / ARCHITECTURE
- **不建议**T003 在没看到 PRD 修订前就动手

### Next Recommended Task

```text
T002_FINALIZE_MVP_PRD
```

---

## 文档版本

| 版本 | 日期 | 修改内容 | 作者 |
|------|------|----------|------|
| 0.1 | 2026-06-19 | 初版汇总 | 00-chief-architect |