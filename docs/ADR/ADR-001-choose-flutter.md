# ADR-001: 选择 Flutter 作为主技术栈

## Status

**Accepted**

## Context

需要为 ukulele_app 选择一个移动应用开发框架。该应用是尤克里里练习工具，需要覆盖 Android（MVP）和未来的 iOS 平台。

## Decision

选择 **Flutter** 作为主技术栈。

## Alternatives Considered

### 1. Kotlin 原生 (Android Only)

| 优点 | 缺点 |
|------|------|
| 性能最佳 | 仅支持 Android |
| 原生体验 | iOS 需要单独开发 |
| 内存占用低 | 开发成本 x2 |

### 2. React Native / Expo

| 优点 | 缺点 |
|------|------|
| JavaScript 生态 | 运行时性能较差 |
| 熟悉人群广 | 包体积较大 |
| 热更新方便 | 版本升级破坏性 |

### 3. Web / PWA / Capacitor

| 优点 | 缺点 |
|------|------|
| 跨平台最广 | 麦克风 API 不稳定 |
| 无需应用商店 | 音频延迟高 |
| 开发快 | 用户体验不如 App |

## Decision Rationale

### 为什么选择 Flutter

| 因素 | 分析 |
|------|------|
| **跨平台** | 一套代码覆盖 Android + iOS，未来成本低 |
| **性能** | 编译为原生 ARM 代码，性能接近 Kotlin |
| **开发效率** | Hot Reload 提升迭代速度 |
| **生态** | 丰富的 Package 生态（Riverpod, Drift, go_router 等） |
| **音频支持** | record + just_audio 满足 MVP 需求 |
| **团队** | 已有 Flutter 开发经验 |

### Flutter vs 竞品对比

| 维度 | Flutter | Kotlin | RN | Web |
|------|---------|--------|-----|-----|
| 性能 | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ |
| iOS 支持 | ⭐⭐⭐⭐ | ❌ | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| 开发成本 | ⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| 音频场景 | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ |
| 包体积 | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |

## Consequences

### Positive

- 一套代码支持 Android + iOS
- 开发效率高，迭代快
- 丰富的状态管理和数据库生态
- 社区活跃，文档完善

### Negative

- Flutter SDK 有一定学习曲线
- 相比 Kotlin 原生，极限性能略低
- 需要维护 Dart 版本升级

## Risks

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| Flutter SDK 大版本升级破坏性 | 中 | 使用稳定版本，延迟升级 |
| Package 维护中断 | 低 | 核心包都有替代品 |
| iOS 审核问题 | 中 | 预留 iOS 配置，提前了解政策 |

## Review Conditions

| 条件 | 触发 |
|------|------|
| Flutter 发布重大版本 | 评估升级影响 |
| 项目性能出现瓶颈 | 评估 Kotlin 原生可行性 |
| iOS 功能占比超过 50% | 重新评估 iOS 投入 |

## Revision History

| 版本 | 日期 | 说明 |
|------|------|------|
| 0.1 | 2026-06-19 | 初始版本 |
