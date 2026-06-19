# ADR-002: MVP 离线优先策略

## Status

**Accepted**

## Context

ukulee_app MVP 阶段的资源有限（单开发者），需要最大化功能交付效率。同时，用户隐私和数据安全是核心考量。

## Decision

**MVP 采用完全离线优先策略**：不做账号系统、不做云同步、不接联网 AI/API。

## Alternatives Considered

### 1. 先做账号 + 基础云同步

| 优点 | 缺点 |
|------|------|
| 数据可备份 | 开发成本增加 |
| 多设备同步 | 隐私风险增加 |
| 可复用 | MVP 延迟交付 |

### 2. 先接免费 BaaS (Firebase/Supabase)

| 优点 | 缺点 |
|------|------|
| 开发快 | 依赖第三方 |
| 有免费额度 | 隐私合规复杂 |
| 可快速验证 | 后期迁移成本 |

### 3. 纯离线 + 本地存储

| 优点 | 缺点 |
|------|------|
| 开发最快 | 数据不可备份 |
| 隐私最安全 | 单设备使用 |
| 离线完美体验 | 换设备数据丢失 |

## Decision Rationale

### 为什么选择离线优先

| 因素 | 分析 |
|------|------|
| **MVP 阶段目标** | 验证产品方向，不做基础设施投资 |
| **单开发者** | 开发资源有限，聚焦核心功能 |
| **用户隐私** | 数据不出设备，隐私风险最低 |
| **离线体验** | 音乐练习常在无网环境 |
| **快速迭代** | 不依赖后端，前端独立开发 |

### 离线优先的优势

1. **开发效率**：前端可完全独立开发，不等后端
2. **发布速度**：APK 可独立发布，不用配后端
3. **隐私合规**：最严格的隐私策略
4. **用户体验**：无网可用，练习不中断

## Consequences

### Positive

- 前端完全独立，开发效率最大化
- 无服务器成本
- 隐私合规最简单
- 用户信任度高

### Negative

- 换设备数据丢失
- 多设备无法同步
- 未来需要迁移成本

## Architecture Implications

### 预留接口

```dart
// Auth Service 抽象（当前用本地实现）
abstract class AuthService {
  Future<User?> getCurrentUser();
}

// 后期实现
class FirebaseAuthService implements AuthService { ... }
class AppleSignInService implements AuthService { ... }

// Sync Service 抽象（当前用空实现）
abstract class SyncService {
  Future<void> uploadRecords(List<PracticeRecord> records);
  Future<List<PracticeRecord>> downloadRecords();
}

// 后期实现
class CloudSyncService implements SyncService { ... }
```

### 数据模型预留

```dart
class PracticeRecord {
  // ... 现有字段 ...

  // 后期字段
  String? cloudId;
  SyncStatus syncStatus;
  DateTime? syncedAt;
}
```

## Risks

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| 用户换设备数据丢失 | 低 | MVP 仅个人使用 |
| 后期迁移成本高 | 中 | 预留接口，数据模型兼容 |
| 云功能验证延迟 | 低 | MVP 后再评估 |

## Review Conditions

| 条件 | 触发 |
|------|------|
| MVP 验证成功 | 评估云同步需求 |
| 用户反馈数据同步 | 评估账号系统 |
| 多设备使用场景出现 | 评估云服务 |

## 后期演进路径

```
Phase 6 (MVP 完成)
  ↓
V5 阶段评估云同步
  ↓
选择 Firebase/Supabase/自建
  ↓
实现账号 + 云同步
```

## Revision History

| 版本 | 日期 | 说明 |
|------|------|------|
| 0.1 | 2026-06-19 | 初始版本 |
