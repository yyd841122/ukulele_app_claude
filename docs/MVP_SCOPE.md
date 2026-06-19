# MVP Scope - 明确边界文档

> 本文档定义 MVP 的明确边界，是所有 Agent 执行任务的最高参考依据。任何超出 MVP Scope 的功能实现必须经过 Chief Architect 和 Product Manager 双重审批。

## 1. MVP 做什么

### 1.1 功能清单

| 模块 | 功能 | 说明 |
|------|------|------|
| 首页/今日练习 | 每日练习计划展示 | 显示当天练习任务列表 |
| 调音器 | GCEA 标准调弦 | 支持 G/C/E/A 四弦手动选择检测 |
| 单音练习 | 音名按弦练习 | C/F/Am/G 等基础音名练习 |
| 和弦库 | 基础和弦列表 | 最基础的大和弦、小和弦 |
| 指法图 | 和弦指法展示 | 静态图片或简单图形 |
| 节拍器 | 可调 BPM 节拍器 | 50-200 BPM 范围 |
| 录音 | 麦克风录制 | 最长 5 分钟 |
| 回放 | 录音播放 | 支持播放/暂停/停止 |
| 自评 | 手动自评 | 好/一般/需改进 三档 |
| 本地记录 | 练习记录保存 | 日期 + 内容 + 自评 |
| 设置 | 基础设置项 | 音量、节拍器默认 BPM 等 |

### 1.2 技术要求

- Android 平台独立运行
- 所有数据本地保存
- 无网络依赖
- 无账号依赖

## 2. MVP 不做什么

以下功能**明确禁止**在 MVP 阶段实现，任何 Agent 不得擅自添加：

### 2.1 账号与网络

| 禁止功能 | 原因 |
|----------|------|
| 账号注册/登录 | MVP 聚焦离线练习 |
| 云端数据同步 | MVP 本地优先 |
| 第三方登录 | 同上 |
| 任何联网 API 调用 | MVP 完全离线 |
| 推送通知 | MVP 简单化 |

### 2.2 AI 与评分

| 禁止功能 | 原因 |
|----------|------|
| AI 自动评分 | 技术验证不足 |
| AI 音高检测 | MVP 降风险 |
| AI 节奏分析 | 同上 |
| AI 和弦识别 | 同上 |
| AI 自动扒谱 | 超纲 |

### 2.3 社区与商业

| 禁止功能 | 原因 |
|----------|------|
| 用户社区 | MVP 简单化 |
| 排行榜 | 同上 |
| 好友系统 | 同上 |
| 分享功能 | 版权风险 |
| 内购/订阅 | MVP 后期考虑 |
| 广告 | MVP 体验优先 |

### 2.4 高级内容

| 禁止功能 | 原因 |
|----------|------|
| 完整歌曲库 | 版权问题 |
| 未经授权歌词 | 版权问题 |
| 未经授权曲谱 | 版权问题 |
| Low G 调弦 | MVP 简化 |
| TAB 四线谱 | MVP 简化 |
| 五线谱 | MVP 简化 |
| 简谱 | MVP 简化 |
| 混合谱 | MVP 简化 |

### 2.5 平台扩展

| 禁止功能 | 原因 |
|----------|------|
| iOS 版本 | MVP Android 优先 |
| iPad 适配 | MVP 简化 |
| Web / PWA | MVP 简化 |
| 桌面端 | MVP 简化 |
| 多乐器支持 | MVP 单乐器 |

## 3. 后期预留

以下功能在 MVP 架构设计时必须预留扩展点：

### 3.1 账号与同步

```dart
// 架构预留：AuthService 抽象接口
abstract class AuthService {
  Future<User?> signIn();
  Future<void> signOut();
  Future<bool> isSignedIn();
}

// 架构预留：SyncService 抽象接口
abstract class SyncService {
  Future<void> uploadPracticeRecords(List<PracticeRecord> records);
  Future<List<PracticeRecord>> downloadPracticeRecords();
}
```

### 3.2 AI 服务

```dart
// 架构预留：AIService 抽象接口
abstract class AIService {
  Future<PitchScore> evaluatePitch(String audioPath);
  Future<RhythmScore> evaluateRhythm(String audioPath);
  Future<ChordRecognition> recognizeChord(String audioPath);
}
```

### 3.3 内容扩展

```dart
// 架构预留：ContentService 抽象接口
abstract class ContentService {
  Future<List<Song>> fetchSongs();
  Future<List<ChordProgression>> fetchChordProgressions();
}
```

## 4. MVP 成功标准

### 4.1 功能完成度

- [ ] 所有 P0 功能可正常使用
- [ ] 离线环境下完整流程可跑通
- [ ] 无崩溃、无数据丢失

### 4.2 用户体验

- [ ] 用户能在 3 分钟内完成首次调音 → 练习 → 录音 → 保存
- [ ] 界面清晰，无歧义
- [ ] 错误提示友好

### 4.3 技术指标

- [ ] APK 可独立安装运行
- [ ] 冷启动 < 3 秒
- [ ] 调音器响应 < 100ms
- [ ] 录音延迟 < 200ms

## 5. 范围守卫规则

### 5.1 Agent 执行规则

任何 Agent 在执行任务时，必须先检查：

1. **需求来源**：是否来自 TODO 列表或 Product Manager 的明确需求？
2. **Scope 检查**：该需求是否在 MVP Scope 内的"做什么"列表中？
3. **边界冲突**：该需求是否触犯"不做什么"列表？
4. **扩展预留**：如果不在 MVP 中，是否有抽象接口预留？

如果答案是"不在 MVP 中且没有预留"，Agent **必须停止并报告**，不得擅自实现。

### 5.2 例外申请流程

如确有业务需要突破 MVP Scope：

1. Agent 提出书面申请（含理由）
2. Chief Architect + Product Manager 联合审批
3. 审批通过后更新本文档和 ADR
4. 才能执行

**禁止口头审批、事后补批。**

## 6. 文档版本

| 版本 | 日期 | 修改内容 | 审批 |
|------|------|----------|------|
| 0.1 | 2026-06-19 | 初始 MVP Scope | T000 执行 |
