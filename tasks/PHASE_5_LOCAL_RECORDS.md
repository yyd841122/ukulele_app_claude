# PHASE_5_LOCAL_RECORDS

## 阶段概述

| 项目 | 说明 |
|------|------|
| Phase ID | Phase 5 |
| 名称 | 本地练习记录 |
| 前置阶段 | Phase 4 |
| 目标 | 实现练习记录持久化和查看 |

---

## 阶段目标

1. 完成 T013: 构建本地练习记录

---

## 包含任务

| Task ID | 任务名称 | 编码 |
|---------|----------|------|
| T013 | 构建本地练习记录 | ✅ |

---

## 前置条件

| 条件 | 状态 | 说明 |
|------|------|------|
| Phase 4 完成 | 待开始 | 录音自评就绪 |
| 数据库设计 | 待开始 | Drift 配置 |

---

## 完成标准

### T013: 构建本地练习记录

**数据库交付物**：
- [ ] Drift 数据库配置
- [ ] PracticeRecords 表
- [ ] Repository 实现
- [ ] CRUD 操作

**功能交付物**：
- [ ] 练习记录保存
- [ ] 历史记录查看
- [ ] 按日期筛选
- [ ] 录音回放入口

**UI 交付物**：
- [ ] PracticeRecordsPage
- [ ] 练习记录卡片
- [ ] 筛选器

**验收标准**：
- [ ] 练习记录保存到 SQLite
- [ ] 历史记录按日期展示
- [ ] 可查看练习详情
- [ ] 可回放历史录音
- [ ] 数据持久化正常

---

## 数据模型

### PracticeRecord

| 字段 | 类型 | 说明 |
|------|------|------|
| id | String | UUID |
| practiceType | String | single_note/chord/metronome/recording |
| content | String | 练习内容描述 |
| selfRating | int | 1=需改进, 2=一般, 3=好 |
| audioPath | String? | 录音路径 |
| durationSeconds | int | 练习时长 |
| createdAt | DateTime | 创建时间 |

---

## 交付物

### PracticeRecordsPage

```
路径: /records
功能:
- 历史练习列表
- 按日期筛选
- 点击查看详情
- 录音回放
```

### 数据库

- lib/data/database/app_database.dart
- lib/data/database/tables/practice_records_table.dart
- lib/features/practice_records/data/practice_record_repository.dart

---

## 风险点

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| 数据库迁移失败 | 数据丢失 | 测试迁移脚本 |
| 查询性能差 | 加载慢 | 添加索引 |
| 数据不一致 | 记录错误 | 事务处理 |

---

## 交接要求

Phase 5 完成后，需要向 Phase 6 交接：

1. **交接文档**：
   - 练习记录持久化完成
   - 历史记录可查看

2. **交接确认**：
   - QA Reviewer 审查通过
   - Chief Architect 审核通过

3. **下一步**：
   - T014: MVP QA 和打磨

---

## 文档版本

| 版本 | 日期 | 修改内容 |
|------|------|----------|
| 0.1 | 2026-06-19 | 初始版本 |
