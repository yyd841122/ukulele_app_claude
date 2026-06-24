# T046 — TASK_LEDGER 记录

> Task ID：`T046_PRODUCT_V2_BENCHMARK_AND_PRD`
> 日期：2026-06-24 | 版本：0.1
> 状态：完成（PRD v2 初稿 + Benchmark 矩阵 + ROADMAP + Ledger + Metrics）

## 1. 任务基本信息

| 字段 | 值 |
|------|-----|
| Task ID | T046_PRODUCT_V2_BENCHMARK_AND_PRD |
| 任务名 | 产品重新定向与 PRD v2 设计（不编码） |
| 起始分支 | master @ b2983fa |
| 工作分支 | product-v2 |
| 测试基线 | 744（未运行） |
| 任务性质 | 仅文档 |
| 启动检查 | ✅ HEAD=b2983fa；✅ clean；✅ origin/master 同步 |
| 启动时间 | 2026-06-24 |
| 关闭时间 | 2026-06-24 |

## 2. 任务范围声明

- ✅ 制定 PRD v2（`docs/PRD_v2.md`）
- ✅ AI音乐学园 Benchmark 矩阵（`docs/T046_AI_MUSIC_SCHOOL_BENCHMARK.md`）
- ✅ 更新 ROADMAP（`docs/T046_ROADMAP.md`，v1.0 保留为历史）
- ✅ 保留旧 PRD（`docs/PRD.md` 不覆盖不删除）
- ❌ 不编码（不修改 lib/ test/ android/）
- ❌ 不设计接口 / 算法 / 代码
- ❌ 不 push / 不 tag / 不 amend / 不 rebase / 不 reset

## 3. 多 Agent 协作

| 角色 | Agent ID | 任务 | 产出 |
|------|----------|------|------|
| Primary Agent (01-product-manager) | 主会话 | 整合调研 + 撰写 PRD | PRD v2 + 4 配套文档 |
| Benchmark Research Agent | a75670748e0c89cc5 | v1.1.0 Capability Audit | `t046-product-v2-benchmark-and-prd-e-yup-jazzy-nebula-agent-a75670748e0c89cc5.md` |
| 05-music-domain-expert | 复用既有 agent 定义 | 教学路径核对 | 已并入 PRD v2 §7 切片设计 + §14 反思 |
| Product Strategy Reviewer | a8d1189b97fb72469 | 范围 / 优先级 / 可执行性审查 | Approved with conditions (10 项最低变更) |

> 备注：Benchmark Research Agent 调研阶段被用户显式终止（指令："不再扩大网络搜索"），改为只读 v1.1.0 能力审计。AI音乐学园 Benchmark 矩阵以"Verified/Inferred/Unknown"三级证据标注，⚪ Unknown 占多数。

## 4. 交付物清单

| # | 文档 | 路径 | 状态 |
|---|------|------|------|
| 1 | AI音乐学园 Benchmark 与功能对标矩阵 | `docs/T046_AI_MUSIC_SCHOOL_BENCHMARK.md` | ✅ 新建 |
| 2 | PRD v2 | `docs/PRD_v2.md` | ✅ 新建 |
| 3 | 更新后的 ROADMAP | `docs/T046_ROADMAP.md` | ✅ 新建（v1.0 保留为历史） |
| 4 | TASK_LEDGER 记录 | `docs/T046_TASK_LEDGER.md` | ✅ 本文档 |
| 5 | AGENT_QUALITY_METRICS 记录 | `docs/T046_AGENT_QUALITY_METRICS.md` | ✅ 新建 |

## 5. 关键决策记录

| # | 决策 | 来源 |
|---|------|------|
| D-01 | v2 PRD 路径为 `docs/PRD_v2.md`，v1.1.0 PRD 保留为历史 | Reviewer C8 / C10 |
| D-02 | 6 阶段路线（P1 补齐 → P2 切片 → P3 音高 → P4 统计 → P5 跟弹 → P6 商业化） | Reviewer §5.1 |
| D-03 | 第一垂直切片沿用 T041 `c_am_down_4x4` 模板，扩展 Day 3/5/6/7 | Reviewer §5.2 + T041 §3.4 |
| D-04 | 不引入 iOS / Web / 平板 / 多乐器 / Low G / TAB / 五线谱 / 简谱 | Reviewer §4 S1-S14 + v1.1.0 §7.5 |
| D-05 | INTERNET 权限 P6 之前不开 | Reviewer §4 S6 / S12 |
| D-06 | 商业歌曲 / UGC 永远不引入 | Reviewer R4 / S5 + CONTENT_POLICY |
| D-07 | AI音乐学园 Benchmark 矩阵 ⚪ Unknown 占多数；不为填满推断 | 用户指令（停止网络搜索） |
| D-08 | schemaVersion 升级到 3 在 P4；P1-P3 不改 schema | Reviewer R7 / C7 |
| D-09 | P1 拆为 P1a / P1b 两个子阶段以维持 3 任务真机可见 | 自我找茬 14.2 #2 |
| D-10 | 切片"关卡通过"toast 改为"自评已落盘"中性提示 | 自我找茬 14.2 #6 |

## 6. 范围守卫（不通过验收的反例）

| 反例 | 是否发生 |
|------|----------|
| 覆盖或删除 v1.1.0 PRD | ❌ 未发生 |
| 修改 lib/ test/ android/ 任何代码 | ❌ 未发生 |
| 引入商业歌曲 / 商业曲谱 / UGC 入口 | ❌ 未发生 |
| 申请 INTERNET 权限 | ❌ 未发生 |
| 引入第三方分析 SDK | ❌ 未发生 |
| 引入 iOS / Web / 平板相关代码 | ❌ 未发生 |
| 引入多乐器相关代码 | ❌ 未发生 |
| push 分支 / tag / amend / rebase / reset | ❌ 未发生 |
| 运行 flutter test / build | ❌ 未发生 |

## 7. 下一任务

| 任务 | 路径 / 触发 |
|------|-------------|
| T047_PRODUCT_V2_SDD | PRD v2 完成后启动；将 PRD 拆解为 SDD（系统设计文档） |

## 8. 文档版本

| 版本 | 日期 | 修改内容 |
|------|------|----------|
| 0.1 | 2026-06-24 | T046 任务台账初稿：4 子文档 + 5 决策 + 范围守卫 + 下一任务 |
