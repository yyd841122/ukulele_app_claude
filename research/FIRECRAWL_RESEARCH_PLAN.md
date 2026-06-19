# Firecrawl 研究计划 (FIRECRAWL_RESEARCH_PLAN)

> 本计划定义后续需要通过 Firecrawl 抓取的外部资源，为 ukulele_app 的开发提供参考。

## 1. 研究目标

通过 Firecrawl 抓取以下类别的外部资源：
- 竞品应用页面
- 尤克里里教学内容
- 音频识别技术文档
- App Store / Google Play 政策

## 2. 研究分类

### 2.1 竞品研究

#### AI 音乐学园

| 项目 | 说明 |
|------|------|
| 研究目的 | 了解竞品功能、用户体验、付费模式 |
| 抓取页面 | 官网产品页、应用介绍页 |
| 需要提取 | 功能列表、截图、价格、用户评价 |
| 可能风险 | 页面结构变化、反爬机制 |
| 产出文档 | research/ai-music-learning-analysis.md |

#### 其他尤克里里 App

| 项目 | 说明 |
|------|------|
| 研究目的 | 了解市面主要竞品 |
| 抓取页面 | App Store/Google Play 页面 |
| 需要提取 | 功能列表、评分、评论 |
| 可能风险 | 平台政策限制 |
| 产出文档 | research/competitor-apps-analysis.md |

### 2.2 教学内容研究

#### 尤克里里教学网站

| 项目 | 说明 |
|------|------|
| 研究目的 | 了解尤克里里练习内容和方法 |
| 抓取页面 | 教程页、和弦库页 |
| 需要提取 | 练习方法、和弦指法、曲目推荐 |
| 可能风险 | 版权内容 |
| 产出文档 | research/ukulele-teaching-content.md |

#### 歌谱/曲谱网站

| 项目 | 说明 |
|------|------|
| 研究目的 | 了解曲谱格式和展示方式 |
| 抓取页面 | 和弦谱页、TAB 谱页 |
| 需要提取 | 谱面格式、交互方式 |
| 可能风险 | 版权内容，只看不采集 |
| 产出文档 | research/sheet-music-formats.md |

### 2.3 技术研究

#### 音频识别库文档

| 项目 | 说明 |
|------|------|
| 研究目的 | 了解音频处理和识别技术 |
| 抓取页面 | GitHub README、官方文档 |
| 需要提取 | API 用法、示例代码、性能数据 |
| 可能风险 | 页面不存在或需要认证 |
| 产出文档 | research/audio-libraries-docs.md |

#### Flutter 音频插件

| 项目 | 说明 |
|------|------|
| 研究目的 | 了解 Flutter 音频生态 |
| 抓取页面 | pub.dev 插件页、GitHub |
| 需要提取 | 功能、用法、限制、issues |
| 可能风险 | 信息可能过时 |
| 产出文档 | research/flutter-audio-plugins.md |

### 2.4 政策研究

#### App Store 政策

| 项目 | 说明 |
|------|------|
| 研究目的 | 了解 iOS 上架要求 |
| 抓取页面 | Apple 开发者文档、审核指南 |
| 需要提取 | 权限要求、隐私政策、评分内容 |
| 可能风险 | 页面需登录 |
| 产出文档 | research/app-store-guidelines.md |

#### Google Play 政策

| 项目 | 说明 |
|------|------|
| 研究目的 | 了解 Android 上架要求 |
| 抓取页面 | Google Play 政策中心 |
| 需要提取 | 权限政策、隐私政策、内容分级 |
| 可能风险 | 页面结构复杂 |
| 产出文档 | research/google-play-policies.md |

## 3. 执行计划

### 3.1 Phase 1: 竞品研究 (T001 阶段)

```bash
# 竞品抓取命令示例
firecrawl https://ai-music-learning.com/products
firecrawl https://appstore.com/ukulele-apps
```

**执行时间**：T001 任务期间

**产出**：
- research/ai-music-learning-analysis.md
- research/competitor-apps-analysis.md

### 3.2 Phase 2: 技术研究 (T003 阶段)

```bash
# 技术文档抓取
firecrawl https://github.com/xxx/audio-library
firecrawl https://pub.dev/packages/record
```

**执行时间**：T003 技术验证期间

**产出**：
- research/audio-libraries-docs.md
- research/flutter-audio-plugins.md

### 3.3 Phase 3: 政策研究 (Phase 6 期间)

```bash
# 政策文档抓取
firecrawl https://developer.apple.com/app-store/review/guidelines
firecrawl https://play.google.com/about/privacy
```

**执行时间**：MVP 上架准备期间

**产出**：
- research/app-store-guidelines.md
- research/google-play-policies.md

## 4. 风险和注意事项

### 4.1 反爬风险

| 风险 | 缓解 |
|------|------|
| IP 被封 | 控制抓取频率 |
| 需验证码 | 使用备用方案 |
| 页面登录 | 使用已认证账号 |

### 4.2 版权风险

| 风险 | 缓解 |
|------|------|
| 采集商业歌曲 | 只看不采集 |
| 采集付费内容 | 使用公开免费内容 |
| 版权声明 | 标注来源 |

### 4.3 信息时效风险

| 风险 | 缓解 |
|------|------|
| 页面更新 | 记录抓取日期 |
| 版本过时 | 定期更新 |
| 链接失效 | 使用 Wayback Machine |

## 5. 产出管理

### 5.1 文件命名规范

```
research/
  ├── competitor-analysis/     # 竞品分析
  │   ├── ai-music-learning-analysis.md
  │   └── competitor-apps-analysis.md
  ├── technical-docs/         # 技术文档
  │   ├── audio-libraries-docs.md
  │   └── flutter-audio-plugins.md
  ├── content-research/       # 内容研究
  │   ├── ukulele-teaching-content.md
  │   └── sheet-music-formats.md
  └── policy-research/        # 政策研究
      ├── app-store-guidelines.md
      └── google-play-policies.md
```

### 5.2 文档格式

每个研究文档必须包含：

```markdown
# [研究主题]

**抓取日期**: YYYY-MM-DD
**来源**: [URL]
**可信度**: [高/中/低]

## 关键发现

[主要发现]

## 详细内容

[详细记录]

## 对项目的启发

[如何应用到项目]

## 参考价值

- [价值点 1]
- [价值点 2]

## 风险和限制

- [风险 1]
- [限制 1]
```

## 6. 后续更新

研究文档需要定期更新：

- **竞品分析**：每季度更新
- **技术文档**：技术验证时更新
- **政策研究**：上架前更新

## 7. 文档版本

| 版本 | 日期 | 修改内容 |
|------|------|----------|
| 0.1 | 2026-06-19 | 初始版本 |
