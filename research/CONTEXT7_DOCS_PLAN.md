# Context7 文档计划 (CONTEXT7_DOCS_PLAN)

> 本计划定义后续需要通过 Context7 获取的 Flutter/Dart 技术文档，为技术选型和实现提供参考。

## 1. 研究目标

通过 Context7 获取以下 Flutter 技术栈的官方文档：
- Flutter 核心
- Riverpod 状态管理
- Drift 数据库
- go_router 路由
- 音频相关库
- 权限处理

## 2. 文档分类

### 2.1 Flutter 核心

#### Flutter SDK

| 查询目的 | 确认 Flutter 3.x 用法、Widget 语法 |
|----------|-----------------------------------|
| 查询内容 | StatefulWidget, StatelessWidget, Provider 用法 |
| 影响模块 | 所有 UI 模块 |
| 优先级 | P0 |
| 产出文档 | research/flutter-core-usage.md |

#### Material 3

| 查询目的 | 确认 Material 3 组件和主题用法 |
|----------|-----------------------------------|
| 查询内容 | ThemeData, ColorScheme, Material 3 组件 |
| 影响模块 | UI 主题 |
| 优先级 | P0 |
| 产出文档 | research/material3-guidelines.md |

### 2.2 状态管理

#### Riverpod

| 查询目的 | 确认 Riverpod 2.x 最新用法 |
|----------|---------------------------|
| 查询内容 | @riverpod, ref.watch, Notifier, AsyncNotifier |
| 影响模块 | 所有需要状态的模块 |
| 优先级 | P0 |
| 产出文档 | research/riverpod-usage.md |

#### Riverpod Generator

| 查询目的 | 确认 riverpod_generator 用法 |
|----------|----------------------------|
| 查询内容 | 代码生成配置、@riverpod 注解 |
| 影响模块 | Provider 定义 |
| 优先级 | P1 |
| 产出文档 | research/riverpod-generator.md |

### 2.3 数据库

#### Drift

| 查询目的 | 确认 Drift 2.x 数据库用法 |
|----------|--------------------------|
| 查询内容 | @DriftDatabase, Table, DAO, 迁移 |
| 影响模块 | 本地数据存储 |
| 优先级 | P0 |
| 产出文档 | research/drift-usage.md |

#### SQLite Flutter

| 查询目的 | 确认 sqlite3_flutter_libs 用法 |
|----------|-------------------------------|
| 查询内容 | 平台配置、native 库加载 |
| 影响模块 | 数据库配置 |
| 优先级 | P1 |
| 产出文档 | research/sqlite-flutter-libs.md |

### 2.4 路由

#### go_router

| 查询目的 | 确认 go_router 14.x 最新用法 |
|----------|------------------------------|
| 查询内容 | GoRouter 配置、路由参数、嵌套路由 |
| 影响模块 | 导航 |
| 优先级 | P0 |
| 产出文档 | research/go-router-usage.md |

### 2.5 音频

#### record 插件

| 查询目的 | 确认 record 5.x 录音 API |
|----------|------------------------|
| 查询内容 | 录音配置、权限处理、状态管理 |
| 影响模块 | 录音、调音器 |
| 优先级 | P0 |
| 产出文档 | research/record-plugin-usage.md |

#### just_audio

| 查询目的 | 确认 just_audio 播放 API |
|----------|--------------------------|
| 查询内容 | 播放控制、进度、后台播放 |
| 影响模块 | 录音回放 |
| 优先级 | P0 |
| 产出文档 | research/just-audio-usage.md |

#### 麦克风权限

| 查询目的 | 确认 Flutter 麦克风权限处理 |
|----------|---------------------------|
| 查询内容 | Android manifest 配置、iOS Info.plist |
| 影响模块 | 权限配置 |
| 优先级 | P0 |
| 产出文档 | research/microphone-permission.md |

### 2.6 其他

#### permission_handler

| 查询目的 | 确认权限处理统一方案 |
|----------|---------------------|
| 查询内容 | 权限申请、拒绝处理 |
| 影响模块 | 麦克风权限 |
| 优先级 | P1 |
| 产出文档 | research/permission-handler-usage.md |

#### freezed

| 查询目的 | 确认 freezed 不可变数据类 |
|----------|-------------------------|
| 查询内容 | @freezed, JSON 序列化 |
| 影响模块 | 数据模型 |
| 优先级 | P1 |
| 产出文档 | research/freezed-usage.md |

## 3. 执行计划

### 3.1 Phase 1: 核心文档 (T003-T004 期间)

**优先级 P0 文档**：

```bash
# Flutter 核心
context7 query Flutter StatefulWidget vs StatelessWidget

# Riverpod
context7 query Flutter Riverpod @riverpod Notifier

# go_router
context7 query Flutter go_router configuration

# Drift
context7 query Flutter Drift database @DriftDatabase
```

**执行时间**：技术验证和项目初始化期间

### 3.2 Phase 2: 音频文档 (T009 期间)

**优先级 P0 音频文档**：

```bash
# 录音
context7 query Flutter record package microphone

# 播放
context7 query Flutter just_audio playback

# 权限
context7 query Flutter microphone permission Android iOS
```

**执行时间**：T009 调音器开发期间

### 3.3 Phase 3: 补充文档 (按需)

**优先级 P1 文档**：

```bash
# Riverpod Generator
context7 query Flutter riverpod_generator code generation

# freezed
context7 query Dart freezed immutable classes
```

**执行时间**：按需执行

## 4. 文档格式

每个技术文档必须包含：

```markdown
# [技术主题]

**查询日期**: YYYY-MM-DD
**来源**: Context7
**版本**: [版本号]

## 关键 API

### 主要用法

```dart
// 示例代码
```

### 常用配置

| 配置项 | 类型 | 说明 |
|--------|------|------|
| [项] | [类型] | [说明] |

## 注意事项

- [注意点 1]
- [注意点 2]

## 对项目的应用

[如何应用到当前项目]

## 参考链接

- [链接 1]
- [链接 2]
```

## 5. 风险和注意事项

### 5.1 信息准确性

| 风险 | 缓解 |
|------|------|
| Context7 文档可能过时 | 记录查询日期，核对版本 |
| 版本差异 | 指定版本号查询 |
| 语法变化 | 使用稳定版本语法 |

### 5.2 适用性

| 风险 | 缓解 |
|------|------|
| 示例代码不适配 | 调整代码适配项目 |
| 配置不适用 | 核对平台要求 |

## 6. 产出管理

### 6.1 文件命名规范

```
research/
  ├── flutter-docs/           # Flutter 文档
  │   ├── flutter-core-usage.md
  │   └── material3-guidelines.md
  ├── state-management/      # 状态管理
  │   ├── riverpod-usage.md
  │   └── riverpod-generator.md
  ├── database/              # 数据库
  │   ├── drift-usage.md
  │   └── sqlite-flutter-libs.md
  ├── routing/               # 路由
  │   └── go-router-usage.md
  ├── audio/                 # 音频
  │   ├── record-plugin-usage.md
  │   ├── just-audio-usage.md
  │   └── microphone-permission.md
  └── data-classes/          # 数据类
      └── freezed-usage.md
```

## 7. 更新机制

### 7.1 更新时机

- **技术验证时**：需要使用某技术时查询
- **版本升级时**：升级依赖版本后更新
- **遇到问题时**：查阅文档解决

### 7.2 更新记录

每次更新记录：

```markdown
## 更新日志

### YYYY-MM-DD
- 更新内容
- 更新原因
- 更新人
```

## 8. 文档版本

| 版本 | 日期 | 修改内容 |
|------|------|----------|
| 0.1 | 2026-06-19 | 初始版本 |
