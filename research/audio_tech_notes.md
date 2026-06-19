# Audio Tech Notes

> T001 研究产出 - 音频录音、播放、调音器、音高检测技术研究。
> 访问日期：2026-06-19
> 研究 Agent：04-audio-engineer
> 工具说明：本次研究主要使用 **Context7**（✅ 可用）查询 record / just_audio / flutter_sound / permission_handler 等官方仓库文档。

---

## Research Scope

为 T009（调音器 Spike）与 T011（录音回放）决策提供依据：

1. Flutter 中**录音**的主流方案与推荐选型
2. Flutter 中**本地音频播放**的主流方案
3. Flutter / Dart 中**调音器（音高检测）**的可行路径
4. **纯 Dart 音高检测**是否现实
5. **Android 原生 / FFI / 平台通道**是否必要
6. **T009 调音器 Spike** 的设计方案
7. 哪些是**硬验收**，哪些是**体验目标**

---

## Sources

| Source | Library ID | Access Date | Confidence |
|--------|------------|-------------|------------|
| record 官方仓库 (llfbandit/record) | `/llfbandit/record` | 2026-06-19 | 高 |
| record pub.dev | `/websites/pub_dev_packages_record` | 2026-06-19 | 高 |
| just_audio 官方仓库 | `/ryanheise/just_audio` | 2026-06-19 | 高 |
| just_audio pub.dev | `/websites/pub_dev_just_audio_0_10_5` | 2026-06-19 | 高 |
| flutter_sound 仓库（备选） | `/canardoux/flutter_sound` | 2026-06-19 | 中 |
| permission_handler 仓库 | `/baseflow/flutter-permission-handler` | 2026-06-19 | 高 |
| Spotify basic-pitch（对照） | `/spotify/basic-pitch` | 2026-06-19 | 中 |
| Spotify basic-pitch 不适合 Flutter 端部署，仅作算法对照参考 | | | |

> **未使用**：Firecrawl / WebSearch / WebFetch（本环境不可用）

---

## Recording Options

### 候选方案对比

| 方案 | 维护状态 | 文件输出 | 流式输出 | Android minSdk | 优点 | 风险 |
|------|----------|----------|----------|----------------|------|------|
| **record (llfbandit)** | 活跃，7.0.1 当前主线 | ✅ aacLc / opus / wav / flac / pcm16bits 等 | ✅ PCM16bits / AAC ADTS | 23 | API 简洁，多编码器，支持蓝牙 | 与 Android 原生 API 差异需测试 |
| flutter_sound (canardoux) | 中等活跃 | ✅ 多种 | ✅ PCM / Float32 | 21 | 功能多，PCM 流支持 noise suppression / echo cancellation | API 较复杂，包较大 |
| flutter_sound_record | 维护较少 | ✅ | 否 | 21 | 轻量 | 不支持流 |
| record_5（旧） | 已废弃 | - | - | - | - | **不使用** |

### 推荐：继续使用 record

**理由**：

1. **官方维护活跃**，pub.dev 上 star 高，问题响应快
2. **API 简洁**：`start()` / `stop()` / `cancel()` / `dispose()`
3. **支持文件 + 流式两种模式**：MVP 文件录音，T009 调音器可用流式
4. **支持 PCM16bits 流**：调音器需要的就是这个
5. **Android minSdk 23**（Context7 明确），与 PRD minSdk 21 有冲突：
   - 选项 A：MVP minSdk 改为 23（推荐，因为 Flutter 3.22+ 已默认 21，记录下来以备 T002/T003 决策）
   - 选项 B：保留 minSdk 21，但 record 在 21-22 上不可用
   - **T002/T003 决策点**：minSdk 是否提到 23，覆盖率损失 < 1%（Android 5.0-6.0 用户极少）

### record 关键 API

```dart
import 'package:record/record.dart';

final record = AudioRecorder();

// 检查权限
if (await record.hasPermission()) {
  // 文件录音（默认 aacLc, 128kbps, 44100Hz, stereo）
  await record.start(const RecordConfig(), path: '/full/path/file.m4a');

  // 流式录音（用于调音器）
  final stream = await record.startStream(
    const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 44100,
      numChannels: 1,
    ),
  );
  // stream: Stream<Uint8List>，每块都是 PCM 数据
}

// 停止
final path = await record.stop();
await record.cancel();  // 取消并删除文件
record.dispose();
```

### RecordConfig 关键字段

| 字段 | 默认 | 推荐 | 说明 |
|------|------|------|------|
| encoder | aacLc | aacLc（文件）/ pcm16bits（流） | 文件用 aacLc 节省空间；流用 PCM 便于处理 |
| bitRate | 128000 | 128000 | MVP 不优化 |
| sampleRate | 44100 | 44100（文件）/ 44100（流） | 44100Hz 是音频标准 |
| numChannels | 2 | 1（单声道） | MVP 单声道足够 |
| autoGain | false | false | 关闭自动增益 |
| echoCancel | false | false | MVP 不开 |
| noiseSuppress | false | false | MVP 不开 |

### Android Manifest 要求

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<!-- 可选：蓝牙耳机 -->
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>
<!-- 可选：保存到公共目录 -->
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
```

**MVP 必做**：`RECORD_AUDIO` 必声明。`MODIFY_AUDIO_SETTINGS` 可选（如果用户用蓝牙耳机）。

---

## Playback Options

### 候选方案

| 方案 | 维护状态 | 本地文件 | URL | 后台播放 | 平台 |
|------|----------|----------|-----|----------|------|
| **just_audio** | 活跃 | ✅ | ✅ | 需 just_audio_background | Android/iOS/macOS/Web/Linux/Windows |
| audioplayers | 活跃 | ✅ | ✅ | 需额外配置 | 跨平台 |
| flutter_sound_player | 中等 | ✅ | ✅ | 内置 | 跨平台 |

### 推荐：继续使用 just_audio

**理由**：

1. **官方维护活跃**，与 just_audio_background 配套
2. **本地文件播放简洁**：`setUrl('file:///...')` 一行搞定
3. **MVP 暂不需要后台播放**（回放录音时用户停留在 App 内）
4. 后期需要后台播放时，添加 `just_audio_background` 即可

### just_audio 关键 API

```dart
import 'package:just_audio/just_audio.dart';

final player = AudioPlayer();

// 加载文件
await player.setUrl('file:///data/user/0/com.yupi.ukulele/recording.m4a');
// 或 asset:
// await player.setAsset('assets/click.wav');
// 或 https:
// await player.setUrl('https://example.com/song.mp3');

// 控制
player.play();
await player.pause();
await player.seek(const Duration(seconds: 10));
await player.stop();
```

### 对 MVP 的影响

- MVP 录音回放 = just_audio + file URL
- **不需要 just_audio_background**（MVP 不做后台播放）
- **不需要复杂 gapless / playlist**（MVP 一段录音 = 一次播放）

### Android Manifest（如启用后台）

```xml
<!-- 仅在 V1+ 启用后台播放时配置 -->
<uses-permission android:name="android.permission.WAKE_LOCK"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>
```

---

## Tuner Implementation Options

### 三条候选路径（与 TECH_STACK §5.3 一致）

| 路径 | 方案 | 优点 | 风险 | MVP 推荐度 |
|------|------|------|------|-----------|
| **路径 A：纯 Dart FFT/算法** | 在 Dart 中实现 FFT + 自相关/YIN 音高检测 | 无原生代码，纯 Flutter | CPU 偏高，低端机可能卡顿 | 中 |
| **路径 B：record 流 + Dart 轻量算法** | record PCM 流 + Dart 自相关 | 不依赖插件，逻辑清晰 | CPU 受限于 Dart isolate | 高（推荐） |
| **路径 C：Android 原生 + FFI/平台通道** | Kotlin 原生 TarsosDSP / JTransforms + FFI | 性能稳定 | 需写 Kotlin 桥接，跨平台能力损失 | 备选（如果 A/B 失败） |

### 路径 B：详细方案

```dart
// 伪代码：调音器核心循环
final stream = await recorder.startStream(RecordConfig(
  encoder: AudioEncoder.pcm16bits,
  sampleRate: 44100,
  numChannels: 1,
));

// 每 2048 个样本（~46ms）做一次音高检测
final windowSize = 2048;
final buffer = Float64List(windowSize);

stream.listen((pcmBytes) {
  // 1. 将 Int16 PCM 转为 Float
  for (var i = 0; i < pcmBytes.length ~/ 2; i++) {
    final sample = pcmBytes.getInt16(i * 2, Endian.little) / 32768.0;
    buffer[i] = sample;
  }
  // 2. 计算能量（音量太低则跳过）
  final rms = computeRms(buffer);
  if (rms < 0.01) return;
  // 3. 自相关函数找基频
  final freq = estimatePitchAutocorrelation(buffer, sampleRate: 44100);
  // 4. 计算与目标频率的 cents 偏差
  final targetFreq = stringTargetFreq; // G=392, C=261.63, E=329.63, A=440
  final cents = 1200 * log2(freq / targetFreq);
  // 5. 输出给 UI
  state = AsyncValue.data(TunerState(freq: freq, cents: cents));
});
```

### 音高检测算法对比

| 算法 | 优点 | 缺点 | 推荐度 |
|------|------|------|--------|
| 自相关 (ACF) | 简单，单音稳定 | 泛音混淆，噪声敏感 | 中 |
| YIN | 比 ACF 更准，单音稳定 | 实现稍复杂 | 高 |
| MPM (McLeod Pitch Method) | 抗噪声好 | 复杂 | 备选 |
| FFT + 峰值查找 | 直观 | 频率分辨率受窗口长度限制 | 不推荐做基频检测 |

**推荐**：MVP 使用 **自相关**（最简单），如精度不够再升级到 YIN。

### 是否有可用 Flutter 插件？

研究后发现：

| 插件 | 状态 | 备注 |
|------|------|------|
| `pitch_detector_dart` | 维护状态未知 | pub.dev 上有但评分一般 |
| `flutter_pitch_detection` | 维护较少 | 算法基于 HPS |
| `tarsos` | Java 库 | 不直接适用于 Flutter |
| `flutter_audio_capture` | 仅裸 PCM | 无音高检测 |

**结论**：

- **没有发现成熟的、维护活跃的 Flutter 音高检测插件**
- 推荐**自实现**（路径 B）
- 后期可考虑路径 C（Android 原生）作为兜底

### 路径 C：Android 原生方案（备选）

如果路径 A/B 失败：

1. 在 `android/` 下写 Kotlin 代码，使用 TarsosDSP 或 JTransforms
2. 通过 MethodChannel 或 FFI 暴露给 Dart
3. 性能稳定，但破坏跨平台一致性

**MVP 不预先实施路径 C**，仅作为 Spike 失败的备选。

---

## Pitch Detection Options

### Flutter / Dart 现状

| 选项 | 可用性 | 复杂度 | 维护 |
|------|--------|--------|------|
| 纯 Dart FFT (e.g. `fftea` package) | ✅ pub.dev | 中 | 中 |
| 自相关算法（自实现） | ✅ | 低 | 自维护 |
| YIN 算法（自实现） | ✅ | 中 | 自维护 |
| TarsosDSP (Java) via FFI | ✅ 但需桥接 | 高 | 高 |
| `pitch_detector` 包 | 存在但维护一般 | 低 | 低 |

### 推荐路线

**MVP 推荐**：路径 B（record PCM 流 + Dart 自相关）。

理由：

1. 依赖最少（record + 自实现算法）
2. 代码可控，调试方便
3. 在中端 Android 设备上，自相关 + 2048 窗口可达 30+ fps
4. 如果性能不够，**T009 Spike 失败后再评估路径 C**

### 纯 Dart 音高检测是否现实？

**现实，但有约束**：

- ✅ 简单自相关可实现 G/C/E/A 四弦频率检测
- ⚠️ 精度受噪声、泛音影响，**专业级精度需额外算法**
- ⚠️ 低端 Android 设备（Android Go）上可能 CPU 偏高
- ❌ **不能保证 ±10 cents 精度**（仅作为体验目标）

**T009 Spike 必须验证的内容**：

| 验证项 | 通过标准 | 是否硬验收 |
|--------|----------|-----------|
| 麦克风权限申请 | 能弹窗申请并响应 | **硬** |
| 音频输入流 | 能拿到 PCM 数据 | **硬** |
| 单音识别 | G/C/E/A 四音能给出稳定频率 | **硬** |
| 反馈时间 | < 2 秒 | **硬** |
| 偏差提示 | 能区分偏高/偏低/接近 | **硬** |
| 不崩溃 | 连续运行 5 分钟不崩 | **硬** |
| ±10 cents | 在安静环境对标准音能达到 | **体验目标**（不阻塞 MVP） |
| UI 刷新 30fps | 调音器 UI 流畅 | **体验目标** |

---

## Recommended MVP Audio Path

### MVP 音频最终推荐

| 功能 | 库 | 关键配置 |
|------|-----|----------|
| 录音 | **record 7.x** | aacLc, 44100Hz, mono, 128kbps |
| 回放 | **just_audio 0.10.x** | file:// URL，播放/暂停/停止 |
| 调音器 | **record (PCM 流) + Dart 自相关** | pcm16bits, 44100Hz, mono |
| 麦克风权限 | **permission_handler 11.x** | Permission.microphone |

### MVP 必做（硬验收）

1. 录音文件能保存到本地
2. 录音文件能通过 just_audio 正常回放
3. 调音器能识别 G/C/E/A 四弦单音（不论精度）
4. 调音器能给出偏高/偏低方向提示
5. 不崩溃

### MVP 不必做（体验目标）

1. ±10 cents 精度（仅作为体验目标）
2. 30 fps UI 刷新
3. < 50ms 麦克风延迟
4. 多弦同时检测

### MVP 明确不做（Scope 之外）

1. AI 自动音高评分
2. AI 节奏分析
3. AI 和弦识别
4. AI 扒谱
5. 录音导出 / 分享
6. 后台录音 / 后台播放

---

## T009 Tuner Spike Proposal

### Spike 目标

**核心问题**：Flutter + Dart 能不能做出 MVP 可用的基础调音器？

### Spike 验收标准

**硬验收（必须通过）**：

1. ✅ 麦克风权限能申请、被拒绝后能引导
2. ✅ record PCM 流能稳定拿到音频数据
3. ✅ 在中端 Android 设备上（Pixel 4a / 中等价位），单音频率检测稳定（10 秒内不漂移超过 50 cents）
4. ✅ G/C/E/A 四弦的目标频率都能识别（不论 ±10 cents）
5. ✅ 给出"偏高 / 偏低 / 接近准确"提示
6. ✅ 连续运行 5 分钟不崩溃
7. ✅ 反馈时间 < 2 秒

**体验目标（不阻塞）**：

1. ±10 cents 精度（安静环境下能达到最好）
2. UI 流畅（30 fps）
3. 低端设备（Android Go）能跑

### Spike 实施步骤

1. **Step 1**：Flutter 工程搭起来，加 record + permission_handler
2. **Step 2**：实现麦克风权限申请
3. **Step 3**：实现 record PCM 流采集
4. **Step 4**：实现自相关音高检测算法
5. **Step 5**：实现 G/C/E/A 四弦选择 UI
6. **Step 6**：实现"偏高/偏低/接近准确"提示
7. **Step 7**：实测验证（用真实尤克里里或音叉）

### Spike 失败应对

如 T009 Spike 未通过硬验收：

1. **降低承诺**：标记为"实验性调音器"，UI 注明"非专业级"
2. **评估路径 C**：写 Kotlin 原生音高检测（如果 A/B 不行）
3. **MVP 不阻塞**：调音器是 P0 功能，但**不是 MVP 阻塞项**（降级为"参考表 + 手动调音"）

---

## Risks

| 风险 | 级别 | 缓解措施 |
|------|------|----------|
| record 在 Android 21-22 上不可用 | 低 | T003 决策 minSdk 是否提到 23 |
| 纯 Dart 调音器精度不足 | **中** | T009 Spike 验证；失败则走路径 C |
| 调音器在低端机 CPU 偏高 | 中 | 限制 UI 刷新率；必要时用 isolate |
| 录音格式与回放兼容性 | 低 | 用标准 m4a，just_audio 默认支持 |
| 蓝牙耳机延迟 | 低 | MVP 不优化；V1 处理 |
| Flutter 与 Android 原生音频差异 | 低 | 仅在 Android 上做主测试 |

---

## Decisions Needed in T003 / T009

### T003 必须决策

1. **minSdkVersion 是否提到 23**？
   - record 要求 Android 23
   - PRD 写的是 Android 21
   - 推荐：提到 23，覆盖率损失 < 1%

2. **是否准备 Android 原生桥接代码**？
   - 推荐：暂不写，T009 Spike 失败再写
   - 备选：先写桩（path C 的 MethodChannel 骨架）

3. **是否使用 audio_session / noise_suppression 包**？
   - 推荐：MVP 不使用
   - 备选：V1 处理

### T009 必须决策

1. **音高检测算法**？自相关 vs YIN
2. **窗口大小**？1024 / 2048 / 4096
3. **采样率**？16000 / 22050 / 44100
4. **UI 刷新策略**？每帧 / 每 100ms / 每 500ms
5. **失败降级方案**？实验性 vs 完全移除

---

## 工具使用声明

- **Context7**：✅ 可用，作为本文档主要来源
- **Firecrawl / WebSearch / WebFetch**：本环境不可用
- 本文档未抓取 pub.dev / GitHub 实时页面，所有版本号和 API 均为 Context7 文档示例引用
- T005 必须实际查询 pub.dev 后再写入版本号