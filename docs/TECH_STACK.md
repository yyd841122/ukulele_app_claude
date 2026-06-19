# 技术栈文档 (TECH_STACK)

## 1. 技术选型总览

| 层级 | 技术选型 | 版本（候选范围） | 用途 |
|------|----------|------------------|------|
| 框架 | Flutter | 3.x 候选 | 跨平台移动开发 |
| 语言 | Dart | 3.x 候选 | Flutter 官方语言 |
| 状态管理 | Riverpod | 2.x 候选 | 响应式状态管理 |
| 本地数据库 | Drift | 2.x 候选 | SQLite ORM |
| 路由 | go_router | 14.x 候选 | 声明式路由 |
| 音频录制 | record | 5.x 候选 | 麦克风录音 |
| 音频播放 | just_audio | 0.6.x 候选 | 音频播放 |
| 数据类 | freezed | 3.x 候选 | 不可变数据类 |
| JSON 序列化 | json_serializable | 6.x 候选 | JSON 编解码 |
| 权限处理 | permission_handler | 11.x 候选 | 运行时权限 |
| 测试 | flutter_test | SDK | 单元/组件测试 |
| 集成测试 | integration_test | SDK | E2E 测试（后期） |

> **版本说明**：以上版本号为 T000 阶段的**候选范围**，**不是最终锁定版本**。最终版本在 T005 任务（添加核心依赖）时确认并写入 pubspec.yaml。

## 1.1 版本策略

为避免在研究阶段就锁死可能过期的依赖版本，本项目采用以下版本策略：

| 阶段 | 版本处理方式 |
|------|--------------|
| T000（已完成） | 仅给出候选范围，不写入 pubspec.yaml |
| T001 / T003 | 通过 Context7、pub.dev、官方文档确认**最新稳定版本**与兼容性 |
| T005 | 添加依赖时**最终写入** pubspec.yaml，并在 ADR 中记录决策依据 |
| T005 之后 | 升级需走 ADR 流程，不允许私自变更 |

**禁止行为**：
- T003 之前在 pubspec.yaml 中写入具体版本号
- 把候选范围误认为已锁定版本
- 在未通过 Context7/pub.dev 验证前承诺兼容版本

## 2. 框架选择理由

### 2.1 为什么选择 Flutter

| 优势 | 说明 |
|------|------|
| 跨平台 | 一套代码支持 Android/iOS，减少开发成本 |
| 性能 | 编译为原生 ARM 代码，性能接近原生 |
| 开发效率 | Hot Reload 提升迭代速度 |
| 生态 | 丰富的 Package 生态，满足音频、数据库等需求 |
| 社区 | Flutter 社区活跃，文档完善 |

Flutter 是当前最适合 MVP 阶段多平台支持的技术选型。

### 2.2 为什么不选 Kotlin 原生

| 劣势 | Flutter 对比 |
|------|--------------|
| Android only | Flutter 一套代码覆盖 Android + iOS |
| iOS 需要 Swift | 无 |
| 开发成本 x2 | Flutter 单一代码库 |
| 生态 | Kotlin 移动生态不如 Flutter 丰富 |

**结论**：Kotlin 原生适合纯 Android 应用，但本项目有 iOS 预留，Flutter 成本更低。

### 2.3 为什么不选 React Native / Expo

| 劣势 | Flutter 对比 |
|------|--------------|
| JavaScript 运行时 | Dart 静态类型，更安全 |
| 性能 | Flutter 渲染性能优于 RN |
| 包大小 | RN runtime 约 10MB，Flutter 约 4MB |
| 原生模块 | Flutter FFI 更直接 |
| 长期维护 | RN 版本升级破坏性较大 |

**结论**：RN 适合已有 React 团队的场景，本项目是全新启动，Flutter 更合适。

### 2.4 为什么不选 Web / PWA / Capacitor

| 劣势 | Flutter 对比 |
|------|--------------|
| 麦克风 API | Web 麦克风 API 不如原生稳定 |
| 性能 | Web 音频延迟高于原生 |
| 用户体验 | App Store / Google Play 分发更专业 |
| 离线能力 | 原生离线更可靠 |
| 硬件访问 | 麦克风、音频延迟控制更精确 |

**结论**：Web 方案在音频场景下延迟和稳定性不足，本项目核心场景是音频，MVP 选择原生体验。

## 3. 状态管理选型

### 3.1 为什么选择 Riverpod

| 优势 | 说明 |
|------|------|
| 编译时安全 | 编译期检查 provider 依赖 |
| 测试友好 | 不依赖 BuildContext |
| 懒加载 | 性能优化 |
| 生态成熟 | Flutter 官方推荐之一 |

### 3.2 备选方案

| 备选 | 不选原因 |
|------|----------|
| Provider | 不支持编译时检查 |
| setState | 不适合复杂状态 |
| Bloc | 过度设计，MVP 简化 |
| GetX | 魔法过多，不够显式 |

## 4. 数据库选型

### 4.1 为什么选择 Drift

| 优势 | 说明 |
|------|------|
| Type Safety | Dart 类型安全 |
| SQL 表达力 | 复杂查询优于 NoSQL |
| 迁移支持 | 版本升级友好 |
| 生态完整 | drift_dev + drift 配套 |

### 4.2 备选方案

| 备选 | 不选原因 |
|------|----------|
| Hive | NoSQL，不适合结构化练习记录 |
| sqflite | 手动写 SQL，工作量大 |
| Isar | 文档和生态不如 Drift |
| ObjectBox | 商业授权有风险 |

## 5. 音频技术选型

### 5.1 录音：record

```yaml
dependencies:
  record: ^5.1.0
```

- 支持 WAV/MP4 格式
- 支持录音回调
- 支持权限处理
- 跨平台 Android/iOS

### 5.2 播放：just_audio

```yaml
dependencies:
  just_audio: ^0.6.21
```

- 支持本地/网络音频
- 支持播放控制（播放/暂停/停止/跳转）
- 支持循环播放
- 支持 Android 后台播放

### 5.3 调音器技术验证（候选路径）

MVP 调音器是技术 Spike + 简化功能。本节给出**三种候选路径**，**不承诺**任何单一方案一定可行。

| 路径 | 方案 | 优势 | 风险 |
|------|------|------|------|
| 路径 A：Flutter/Dart 插件方案 | 使用 Dart 实现的 FFT / 音高检测插件（如 fft、pitch_detector 等） | 纯 Dart，无需写原生代码 | 性能与精度依赖包质量，部分包维护状态不稳定 |
| 路径 B：record 音频流 + Dart 轻量算法 | 通过 record 拿到 PCM 流，Dart 端做自相关或简化 FFT | 不依赖额外插件，可控性高 | 纯 Dart FFT 在低端机可能 CPU 偏高，**不承诺一定可行** |
| 路径 C：Android 原生音频处理方案（备选） | 通过平台通道或 FFI 接入 Android 原生音频处理 / 原生 FFT 库 | 性能稳定，精度可控 | 跨平台能力受限，需要写 Kotlin 桥接 |

**说明**：
- 不承诺"纯 Dart FFT 一定可行"，必须经过 T009 Spike 验证。
- 如 Flutter/Dart 方案不稳定，后续再评估 Android 原生插件 / FFI / 平台通道。
- 此处"原生 ftt 插件"措辞为**文档历史错误**，正确表述应为：**原生音频处理插件 / FFI / 平台通道**。

**验证项**（T009 任务）：

| 验证项 | MVP Spike 目标 |
|--------|----------------|
| 麦克风权限 | 能申请 |
| 音频输入 | 能获取可用音频输入 |
| 单音频率 / 音名 | 能对 G/C/E/A 单音给出稳定频率或最近音名 |
| 反馈时间 | 2 秒内给出可理解反馈 |
| 偏差提示 | 能提示偏高 / 偏低 / 接近准确 |
| 稳定性 | 不崩溃、不明显卡顿 |
| 精度（建议指标） | ±10 cents（MVP 体验目标，不承诺专业级） |
| 降级 | 若精度无法稳定达到，降级为"实验性调音器"，**不阻塞整体 MVP** |

**禁止行为**：
- 把"实验性调音器"上升为"专业级调音器"
- 不做 AI 自动评分（详见 MVP_SCOPE 2.2.1）

## 6. 架构模式

### 6.1 Feature-First + Clean-ish Architecture

```
lib/
  main.dart
  app/
  core/
    constants/
    theme/
    utils/
    extensions/
  shared/
    widgets/
    services/
  features/
    home/
      presentation/
      application/
      domain/
      data/
    tuner/
    practice/
    metronome/
    recording/
    settings/
```

**原则**：
- Feature-first：按功能模块组织代码，不是按层组织
- Clean-ish：允许 MVP 阶段适度简化 domain/data 层
- 避免过度工程化：不需要每个 feature 都有完整的四层
- Riverpod provider 集中在 feature 内，不搞全局 provider

## 7. 依赖管理

### 7.1 pubspec.yaml 结构

```yaml
name: ukulele_app
publish_to: 'none'
version: 0.1.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.4.0
  riverpod_annotation: ^2.3.0
  go_router: ^14.0.0
  drift: ^2.14.0
  sqlite3_flutter_libs: ^0.5.0
  path_provider: ^2.1.0
  path: ^1.8.0
  record: ^5.1.0
  just_audio: ^0.6.21
  permission_handler: ^11.1.0
  freezed_annotation: ^2.4.0
  json_annotation: ^4.8.0
  intl: ^0.19.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
  build_runner: ^2.4.0
  freezed: ^2.4.0
  json_serializable: ^6.7.0
  drift_dev: ^2.14.0
  riverpod_generator: ^2.3.0

flutter:
  uses-material-design: true
  assets:
    - assets/chord_diagrams/
    - assets/exercises/
```

## 8. 平台配置

### 8.1 Android

| 配置项 | 值 | 说明 |
|--------|-----|------|
| minSdkVersion | 21 | Android 5.0 |
| targetSdkVersion | 34 | Android 14 |
| compileSdkVersion | 34 | 最新稳定 |
| 麦克风权限 | RECORD_AUDIO | 录音/调音用 |

**AndroidManifest.xml 必要权限**：

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
```

### 8.2 iOS 预留

| 配置项 | 值 | 说明 |
|--------|-----|------|
| 麦克风权限 | NSMicrophoneUsageDescription | 待 iOS 开发时配置 |
| 部署目标 | iOS 12.0 | 预留 |

## 9. 测试策略

### 9.1 单元测试

- Riverpod Provider 测试
- 数据模型序列化测试
- 业务逻辑测试

### 9.2 Widget 测试

- 独立 Widget 渲染测试
- 用户交互测试

### 9.3 集成测试（后期）

- 完整用户流程 E2E
- 离线场景验证

## 10. 后期预留扩展点

### 10.1 Auth Service 抽象

```dart
// 当前：直接用 local storage
// 后期：注入 AuthService 实现
abstract class AuthService {
  Future<User?> getCurrentUser();
  Future<User> signInAnonymously();
  Future<void> signInWithApple();
  Future<void> signInWithGoogle();
}
```

### 10.2 Sync Service 抽象

```dart
abstract class SyncService {
  Future<void> uploadRecords(List<PracticeRecord> records);
  Future<List<PracticeRecord>> downloadRecords();
  Future<bool> hasPendingSync();
}
```

### 10.3 AI Service 抽象

```dart
abstract class AIService {
  Future<PitchEvaluation> evaluatePitch(AudioData audio);
  Future<RhythmEvaluation> evaluateRhythm(AudioData audio);
  Future<ChordEvaluation> evaluateChord(AudioData audio);
}
```

这些抽象接口在 MVP 阶段使用 LocalStorage/LocalService 实现，后期再替换为真实后端/AI 服务。
