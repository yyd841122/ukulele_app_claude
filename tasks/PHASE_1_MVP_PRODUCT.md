# PHASE_1_MVP_PRODUCT

## 阶段概述

| 项目 | 说明 |
|------|------|
| Phase ID | Phase 1 |
| 名称 | Flutter App Shell |
| 前置阶段 | Phase 0 |
| 目标 | 创建可运行的 Flutter 项目空壳 |

---

## 阶段目标

1. 完成 T004: 创建 Flutter 项目
2. 完成 T005: 添加核心依赖
3. 完成 T006: 构建导航和 App Shell

---

## 包含任务

| Task ID | 任务名称 | 编码 |
|---------|----------|------|
| T004 | 创建 Flutter 项目 | ✅ |
| T005 | 添加核心依赖 | ✅ |
| T006 | 构建导航和 App Shell | ✅ |

---

## 前置条件

| 条件 | 状态 | 说明 |
|------|------|------|
| Phase 0 完成 | ✅ | 所有文档已创建 |
| T002 PRD 最终确定 | 待开始 | T001 研究后执行 |
| T003 技术架构最终确定 | 待开始 | T001 研究后执行 |

---

## 完成标准

### T004: 创建 Flutter 项目

- [ ] flutter create 成功
- [ ] 项目目录结构正确
- [ ] Android 配置正确 (minSdk 21, targetSdk 34)
- [ ] 可执行 flutter build apk --debug

### T005: 添加核心依赖

- [ ] pubspec.yaml 包含：
  - flutter_riverpod
  - go_router
  - drift
  - sqlite3_flutter_libs
  - record
  - just_audio
  - permission_handler
  - freezed
  - json_serializable
- [ ] flutter pub get 成功
- [ ] 无版本冲突
- [ ] build_runner 可运行

### T006: 构建导航和 App Shell

- [ ] go_router 路由配置
- [ ] 基础页面占位（Home, Tuner, Metronome, Recording, Settings 等）
- [ ] Material 3 主题配置
- [ ] 页面可跳转

---

## 交付物

### 目录结构

```
lib/
  main.dart
  app/
    app.dart
    router.dart
    theme.dart
  core/
  shared/
  features/
    home/
    tuner/
    metronome/
    recording/
    settings/
```

### 配置文件

- pubspec.yaml
- android/app/build.gradle
- android/app/src/main/AndroidManifest.xml

---

## 风险点

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| 依赖版本冲突 | 编译失败 | 仔细选择兼容版本 |
| Android 配置问题 | 构建失败 | 参考 Flutter 文档 |
| 路由设计不合理 | 后期重构 | 遵循已有架构文档 |

---

## 交接要求

Phase 1 完成后，需要向 Phase 2 交接：

1. **交接文档**：
   - Flutter 项目可编译运行
   - 所有依赖已配置
   - 路由已配置

2. **交接确认**：
   - APK 可构建
   - Chief Architect 审核通过

3. **下一步**：
   - T007: 构建首页和今日练习
   - T008: 构建和弦库和指法图

---

## 文档版本

| 版本 | 日期 | 修改内容 |
|------|------|----------|
| 0.1 | 2026-06-19 | 初始版本 |
