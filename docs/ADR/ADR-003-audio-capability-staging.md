# ADR-003: 音频能力分阶段实现

## Status

**Accepted**

## Context

音频能力是 ukulee_app 的核心技术能力，包括调音器、录音、评分等。但 AI 音频分析技术复杂、风险高，不适合 MVP 阶段一次性实现。

## Decision

**音频能力分三阶段实现**：

| 阶段 | 能力 | 实现方式 |
|------|------|----------|
| MVP | 调音器 + 录音 + 回放 + 手动自评 | 纯本地，无 AI |
| V1 | 单音音高评分 | 本地算法或云端 API |
| V2+ | 节奏评分、和弦识别、完整度评分 | 需 AI 模型 |

## Alternatives Considered

### 1. MVP 一次性实现完整音频能力

| 优点 | 缺点 |
|------|------|
| 体验完整 | 技术风险高 |
| 一次开发 | 开发周期长 |
| - | AI 方案不确定 |

### 2. MVP 完全不做音频

| 优点 | 缺点 |
|------|------|
| 风险最低 | 功能太弱 |
| 开发最快 | 无法验证产品 |
| - | 用户价值低 |

### 3. 分阶段实现

| 优点 | 缺点 |
|------|------|
| 风险可控 | 多次开发 |
| 快速验证 | 需要预留接口 |
| 技术验证先行 | 架构需要兼容后期 |

## Decision Rationale

### 为什么 MVP 不做 AI 评分

| 因素 | 分析 |
|------|------|
| **技术风险** | 音高检测、节奏分析、和弦识别算法复杂 |
| **不确定性** | 纯 Dart 方案 vs native 插件 vs 云 API 未定 |
| **开发周期** | AI 能力可能阻塞 MVP 交付 |
| **MVP 目标** | 验证核心练习流程，不验证 AI 评分 |

### MVP 音频能力范围

| 能力 | MVP 实现 |
|------|----------|
| 调音器 | 频率检测 + 音准显示 |
| 录音 | 麦克风录制 + 本地保存 |
| 回放 | 录音播放 |
| 自评 | 手动三档选择 |
| AI 评分 | **不做** |

### 接口预留

```dart
// 调音器（当前实现）
class TunerService {
  Stream<double> getFrequencyStream();
  double detectNote(double frequency);
}

// AI 评分服务（后期实现）
abstract class PitchEvaluationService {
  Future<PitchResult> evaluate({
    required String audioPath,
    required String expectedNote,
  });
}

// MVP 实现：返回占位结果
class LocalPitchEvaluationService implements PitchEvaluationService {
  @override
  Future<PitchResult> evaluate(...) async {
    return PitchResult(score: 0, feedback: 'AI 评分待集成');
  }
}
```

## Consequences

### Positive

- MVP 功能完整可交付
- 技术风险可控
- 可在 MVP 后验证 AI 方案
- 架构预留扩展性

### Negative

- MVP 评分依赖手动，用户体验有限
- 后续需要二次开发

## Technical Verification Items

### MVP 阶段技术验证

| 验证项 | 验证目标 | 通过标准 |
|--------|----------|----------|
| 频率检测精度 | 确认 Flutter 能满足调音需求 | ±10 cents |
| 录音延迟 | 确认用户体验可接受 | < 200ms |
| 麦克风权限 | 确认权限流程正常 | 可正常申请 |

### V1 阶段技术验证

| 验证项 | 验证目标 | 备选方案 |
|--------|----------|----------|
| 音高检测算法 | 确认本地算法精度 | 云 API |
| 评分反馈 | 确认评分合理性 | 规则引擎 |

## Risks

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| 调音器精度不足 | 中 | MVP 不承诺专业精度 |
| AI 方案不确定 | 高 | 预留接口，先做技术验证 |
| 评分用户体验差 | 低 | MVP 仅手动自评 |

## Review Conditions

| 条件 | 触发 |
|------|------|
| MVP 发布后 | 评估 AI 评分需求 |
| T009 调音器验证后 | 确认 V1 技术方案 |
| 用户反馈评分需求 | 加速 V1 开发 |

## 后期路线图

```
Phase 3: 调音器基础能力
  ↓
Phase 4: 录音 + 回放
  ↓
Phase 6: MVP 完成
  ↓
V1: 音高评分 (PitchEvaluationService)
  ↓
V2: 节奏评分 + 和弦识别
  ↓
V3: 完整度评分
```

## Revision History

| 版本 | 日期 | 说明 |
|------|------|------|
| 0.1 | 2026-06-19 | 初始版本 |
