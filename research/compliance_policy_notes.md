# Compliance Policy Notes

> T001 研究产出 - 麦克风权限、录音隐私、版权、上架政策合规研究。
> 访问日期：2026-06-19
> 研究 Agent：08-compliance-reviewer
> 工具说明：本次研究主要使用 **Context7**（✅ 可用）查询 permission_handler / record 仓库中的权限与隐私相关文档。App Store / Google Play 政策原文因 WebFetch 不可用未能直接抓取，相关结论基于"已知公开政策 + 模型知识"，需 T002 复核。

---

## Research Scope

为 MVP 与商业化前两个阶段梳理合规边界：

1. **Android / iOS 麦克风权限** 的申请方式与文案
2. **用户录音本地保存** 的隐私风险
3. **App Store / Google Play** 对录音、用户内容、儿童/未成年人的要求
4. **内置练习曲、歌词、曲谱** 的版权风险
5. **MVP 阶段如何避免侵权**
6. **后期 AI 曲谱生成、用户输入歌名/歌词/链接** 的合规风险

---

## Sources

| Source | URL / Library ID | Access Date | Confidence |
|--------|------------------|-------------|------------|
| permission_handler 官方仓库 | `/baseflow/flutter-permission-handler` (Context7) | 2026-06-19 | 高 |
| record 官方仓库（Android 权限说明） | `/llfbandit/record` (Context7) | 2026-06-19 | 高 |
| 已知 Google Play 政策（隐私 / 麦克风 / 用户生成内容） | 内部知识 | 2026-06-19 | 中 |
| 已知 App Store 审核指南（麦克风 / 用户内容 / 儿童） | 内部知识 | 2026-06-19 | 中 |
| 已知国际版权规则（中欧美） | 内部知识 | 2026-06-19 | 中 |

> **未使用**：Firecrawl / WebSearch / WebFetch（本环境不可用）。本文档对 App Store / Google Play 政策的引用**全部基于模型知识**，T002 阶段必须由人工或启用 Firecrawl 后复核。

---

## Microphone Permission

### Android 平台

**Manifest 必须声明**（Context7 来源：record_android）：

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<!-- 可选 -->
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>
```

**运行时权限申请**（Context7 来源：permission_handler）：

```dart
import 'package:permission_handler/permission_handler.dart';

// 单个权限
var status = await Permission.microphone.request();
if (status.isGranted) { ... }
// 其他状态：isDenied / isPermanentlyDenied / isRestricted / isLimited

// 或检查后请求
if (await Permission.microphone.isDenied) {
  await Permission.microphone.request();
}
```

**Android 13+（API 33）注意**：

- permission_handler 3.1+ 要求 `compileSdkVersion ≥ 33`，推荐 35
- 录音场景仍使用 `Permission.microphone`（不需要用 `Permission.audio` 媒体权限）
- `Permission.storage` 在 Android 13+ 已被 `Permission.photos / videos / audio` 取代，**MVP 录音不写公共目录，可不申请存储权限**

### iOS 平台（预留）

**Info.plist 必须声明**：

```xml
<key>NSMicrophoneUsageDescription</key>
<string>用于调音器和录音练习</string>
```

**权限申请**：iOS 在用户首次调用 `Permission.microphone.request()` 时自动弹窗（系统级，无需代码触发）。

### 权限申请文案（建议）

| 场景 | 文案建议 |
|------|----------|
| 调音器首次启动 | "调音器需要使用麦克风来检测你弹奏的琴弦音准" |
| 录音首次启动 | "录音功能需要使用麦克风来录制你的练习过程" |
| 权限被拒绝 | "你拒绝了麦克风权限。请到系统设置中开启权限以使用调音/录音功能" |
| 永久拒绝 | "你已永久拒绝麦克风权限。请到系统设置 → 应用 → ukulele_app → 权限中开启" |

### 申请时机原则

- **不要**在 App 启动时立即申请（"cold start permission" 反模式）
- **不要**在用户未点击相关功能前申请
- **正确做法**：用户首次点击"开始调音"或"开始录音"时申请

---

## User Recording Privacy

### MVP 录音存储策略（与 COMPLIANCE.md §2 一致）

| 项目 | 策略 |
|------|------|
| 存储位置 | `getApplicationDocumentsDirectory()`（App 私有目录） |
| 访问权限 | 仅 App 自身可读 |
| 备份 | 默认不备份到云端 |
| 导出 | **MVP 不提供导出功能** |
| 上传 | **MVP 不上传任何录音** |
| 删除 | 用户卸载 App 后录音自动删除 |

### 隐私风险点

| 风险 | 等级 | 缓解 |
|------|------|------|
| 录音被恶意 App 访问 | 低 | App 私有目录隔离 |
| 录音被云备份（Google 自动备份） | 低 | 默认不自动备份 |
| 录音意外分享 | 低 | MVP 不提供分享入口 |
| 录音包含其他声音（家人说话、背景音乐） | 中 | 隐私声明中需说明 |

### 隐私声明建议文案

> "本 App 的所有录音仅保存在你的手机本地，App 不会上传、分享或分析你的录音。卸载 App 后录音将一并删除。"

### Android 13+ 媒体权限注意

如未来需要**导出录音到公共目录**：

- Android 13+ 必须使用 `Permission.audio`（`READ_MEDIA_AUDIO`）而非 `Permission.storage`
- 需在 Info.plist 中说明导出目的
- **MVP 不实现导出**，无需处理此场景

---

## Local-Only Data Strategy

### MVP 数据全部本地（与 PRD §6.3、COMPLIANCE.md §3 一致）

| 数据 | 存储位置 | 加密 | 备份 |
|------|----------|------|------|
| 练习记录 | Drift/SQLite（App 私有目录） | 否 | 否 |
| 用户设置 | SharedPreferences | 否 | 否 |
| 录音文件 | App 私有目录（`getApplicationDocumentsDirectory()`） | 否 | 否 |
| 缓存 | App 私有目录 | 否 | 否 |

### 隐私政策要求

**MVP 阶段**：

- ✅ 在 App 内**设置 → 关于**中添加"隐私说明"页面
- ✅ 隐私说明必须包含：
  - 收集哪些数据（答：无）
  - 存储位置（答：本地）
  - 是否上传（答：否）
  - 是否第三方分析（答：否）
  - 麦克风权限用途
- ❌ **MVP 不需要**发布完整版隐私政策网页（仅做基础声明）

**商业化前**：

- 必须发布完整版隐私政策网页（Google Play / App Store 上架要求）
- 必须包含 GDPR / CCPA 合规条款（如面向欧美用户）

### 数据出境风险（远期）

如未来添加云同步：

- 必须明确告知用户数据出境位置
- 需符合 GDPR / CCPA / 中国《个人信息保护法》
- MVP 不实现，但架构上预留 `SyncService` 抽象

---

## Copyright and Built-In Content

### MVP 内容策略（与 PRD §7、COMPLIANCE.md §6 一致）

#### 明确**不做**

| 内容类型 | 原因 |
|----------|------|
| 商业歌曲完整音频 | 版权风险 |
| 商业歌曲完整歌词 | 版权风险 |
| 商业歌曲完整曲谱 | 版权风险 |
| 任何有版权的图像/插画 | 版权风险 |
| 第三方音频样本 | 授权复杂 |

#### 可以做

| 内容类型 | 说明 |
|----------|------|
| **公版旋律** | 版权已过期（如古典名曲） |
| **自制练习曲** | 项目 owner 原创，CC0 协议 |
| **基础和弦练习片段** | 单音、音阶、和弦分解等通用练习 |
| **公版和弦进行** | I-IV-V-I 等通用进行 |
| **和弦指法图（自绘）** | 通用知识，无版权 |
| **节拍器音** | 自制或 CC0 |

#### 版权到期时间参考

| 地区 | 规则 |
|------|------|
| 中国大陆 | 作者死后 50 年 |
| 欧盟 | 作者死后 70 年 |
| 美国 | 1978 年前作品 95 年；1978 年后作者死后 70 年 |

> **MVP 实施**：MVP 内置内容**全部自制或公版**，不引用任何商业歌曲。

### 内置练习曲的风险与对策

| 风险 | 对策 |
|------|------|
| 自制内容被误认为抄袭 | 加原创声明，CC0 协议 |
| 公版旋律版权边界不清晰 | 仅使用明显公版的曲目（古典音乐） |
| 和弦进行被认为有版权 | 和弦进行本身不受版权保护 |

### UI 资源

| 资源 | 来源 | 版权 |
|------|------|------|
| Material Icons | Google | Apache 2.0 |
| 自绘和弦指法图 | 项目 owner 自制 | CC0 |
| 节拍器音 | 自制或 freesound.org CC0 | CC0 |
| 字体 | 系统字体 / Google Fonts | 各异 |

---

## User-Provided Songs / Lyrics / Links

### MVP 现状

- MVP **不提供用户输入歌曲/歌词/链接**的功能
- MVP 仅手动记录练习，无 UGC 入口

### 后期风险（V1+ 引入时考虑）

| 风险 | 说明 |
|------|------|
| 用户输入商业歌曲歌词 | 即"上传未授权内容"，UGC 平台有责任 |
| 用户输入外部链接 | 平台跳转责任 + 版权连带责任 |
| 用户录唱商业歌曲 | 同上 |
| 用户上传自制曲谱 | 自制内容风险较低，但需 DMCA 通道 |

### V1+ 引入 UGC 时的合规要求

1. **必须**有 DMCA / 投诉通道（响应 < 24 小时）
2. **必须**有内容审核机制（关键词过滤 + 人工抽审）
3. **必须**告知用户不得上传版权内容
4. **建议**初期禁用 UGC，等合规机制完善后开放

### MVP 决策

**MVP 不实现任何 UGC 功能**（与 PRD §5.2 一致）。

---

## AI-Generated Chord or Sheet Content

### 远期风险（V4+）

| 风险 | 说明 |
|------|------|
| AI 生成与商业歌曲相似的曲谱 | 算法层面无法完全避免 |
| AI 生成包含版权歌词 | 取决于训练数据 + 过滤机制 |
| AI 模型偏见 | 不同流派的曲谱质量不一 |
| AI 服务中断 | 用户体验问题 |

### V4+ 引入 AI 曲谱生成时

1. **必须**明确告知用户"内容为 AI 生成"
2. **必须**避免生成明显与商业歌曲高度相似的内容（hash / melody similarity check）
3. **必须**有"投诉"通道（用户可标记"这首歌和 X 很像"）
4. **建议**初期只生成通用和弦进行（I-IV-V-I 等），不生成旋律
5. **建议**初期只支持公版曲目 + 自制曲目

### MVP 决策

**MVP 不实现任何 AI 生成内容功能**（与 PRD §10.4 一致）。

---

## App Store / Google Play Risks

### Google Play 政策合规点（基于已知政策）

| 政策项 | MVP 状态 | 后期检查点 |
|--------|----------|------------|
| 麦克风权限声明 | ✅ 必须 | T005 配置 |
| 隐私政策链接 | 后期上架前 | 上架前完成 |
| 内容分级 | 后期提交 | 上架前完成 |
| 儿童隐私（COPPA） | MVP 暂不涉及 | 面向儿童前必须重新评估 |
| 广告 SDK | 无 | 后期如加广告需配置 |
| 内购 | 无 | 后期如加需配置 |
| 用户生成内容（UGC） | 无 | 引入 UGC 前必须评估 |
| 数据收集声明 | 仅本地 | 后期如加分析需声明 |

### App Store 审核指南合规点（基于已知指南）

| 指南项 | MVP 状态 | 后期检查点 |
|--------|----------|------------|
| 麦克风权限（NSMicrophoneUsageDescription） | 后期配置 | iOS 开发时配置 |
| 隐私政策 | 后期上架前 | 上架前完成 |
| 年龄分级 | 后期提交 | 上架前完成 |
| 后台音频 | MVP 不用 | 引入时需声明 |
| 儿童类别 | 不勾选 | MVP 不面向儿童 |

### 上架前合规检查清单

> MVP 不上架，但**架构上需预留**以下机制：

- [ ] 麦克风权限声明（Android Manifest / iOS Info.plist）
- [ ] 隐私政策页面（App 内）
- [ ] 隐私政策网页（公网 URL）
- [ ] 内容分级申请
- [ ] 第三方 SDK 隐私标签（如未来添加）
- [ ] DMCA / 投诉通道（如未来引入 UGC）
- [ ] 用户数据导出 / 删除机制（如未来加云同步）

---

## MVP Compliance Recommendations

### MVP 阶段（Android only）

1. **AndroidManifest.xml**：
   - `<uses-permission android:name="android.permission.RECORD_AUDIO"/>`
   - `<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>`（可选，蓝牙）

2. **App 内设置 → 关于 → 隐私说明**：
   - 简明列出数据处理方式
   - 麦克风权限用途
   - "我们不上传你的录音"

3. **首次使用调音器/录音**：
   - 弹窗前显示简短说明（不是系统弹窗的"补充说明"）
   - 用户拒绝后提供降级方案

4. **录音文件**：
   - 存 `getApplicationDocumentsDirectory()`
   - 默认不备份
   - 不提供导出/分享入口
   - 文件名用时间戳，不含敏感信息

5. **内置内容**：
   - 全部自制或公版
   - 标注自制内容的 CC0 协议
   - 不引用商业歌曲

6. **用户输入**：
   - MVP 不提供用户输入歌曲/歌词/链接的功能

### 商业化前（Phase 6）必须补

1. 完整版隐私政策网页
2. Google Play / App Store 上架配置
3. 内容分级提交
4. DMCA 通道（如未来有 UGC）
5. GDPR / CCPA 合规（如面向欧美）

---

## Decisions Needed Before Commercial Release

| 决策 | 时机 | 建议 |
|------|------|------|
| 隐私政策网页 URL | 商业化前 | 自建静态网页 |
| 内容分级 | 商业化前 | Google Play 自评 |
| 麦克风权限文案 | T005 | 写入 TECH_STACK |
| DMCA 通道 | V1+ 引入 UGC 前 | 准备邮件地址 |
| 数据导出 | V1+ | "导出所有练习记录 + 录音"按钮 |
| 数据删除 | V1+ | "删除所有数据"按钮 |
| COPPA 评估 | 商业化前 | 不面向 13 岁以下 |
| GDPR DPO | 面向欧盟用户前 | 不需要个人 DPO |

---

## 工具使用声明

- **Context7**：✅ 可用，作为技术文档来源
- **Firecrawl / WebSearch / WebFetch**：本环境均不可用
- **App Store / Google Play 政策原文未抓取**，本文档相关结论基于"已知公开政策 + 模型知识"
- **T002 阶段必须**：
  1. 用 Firecrawl 抓取 Apple Developer Guidelines 5.x（隐私 / 权限 / UGC）
  2. 用 Firecrawl 抓取 Google Play Policy Center（数据安全 / 隐私 / UGC）
  3. 复核本文档所有"中"置信度结论
  4. 补充合规风险表中的细节（如具体审核被拒原因）

**Chief Architect 需将"App Store / Google Play 政策原文未抓取"列入 T002 Blocker 清单。**