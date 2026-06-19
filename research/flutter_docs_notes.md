# Flutter Docs Notes

> T001 研究产出 - Flutter / Riverpod / Drift / go_router 等技术文档研究。
> 访问日期：2026-06-19
> 研究 Agent：02-flutter-architect
> 工具说明：本次研究主要使用 **Context7**（✅ 可用）查询官方仓库文档，Firecrawl/WebSearch/WebFetch 在本环境不可用。

---

## Research Scope

为后续 T004 / T005 决策提供最新版本和推荐用法依据：

1. Flutter / Dart 当前稳定版本与项目创建注意事项
2. Riverpod 2.x → 3.x 的迁移路径与当前推荐写法
3. Drift 当前推荐用法（@DriftDatabase、迁移、sqlite3_flutter_libs）
4. go_router 路由配置方式
5. Material 3 在 Flutter 中的状态
6. record / just_audio / permission_handler 的 API 用法
7. Android first / iOS reserved 的工程注意事项
8. T005 添加依赖时的版本策略

---

## Sources

| Source | URL (Context7 来源) | Library ID | Access Date | Confidence |
|--------|---------------------|------------|-------------|------------|
| Flutter 官网仓库（含 release-notes / cookbook） | github.com/flutter/website | `/flutter/website` | 2026-06-19 | 高 |
| Flutter API reference | api.flutter.dev | `/websites/api_flutter_dev` | 2026-06-19 | 高 |
| Riverpod 仓库 | github.com/rrousselgit/riverpod | `/rrousselgit/riverpod` | 2026-06-19 | 高 |
| Riverpod pub.dev 文档 | pub.dev/riverpod | `/websites/pub_dev_riverpod` | 2026-06-19 | 高 |
| Drift 仓库 | github.com/simolus3/drift | `/simolus3/drift` | 2026-06-19 | 高 |
| Drift 官网 | drift.simonbinder.eu | `/websites/drift_simonbinder_eu` | 2026-06-19 | 高 |
| go_router pub.dev | pub.dev/go_router | `/websites/pub_dev_packages_go_router` | 2026-06-19 | 高 |
| record 仓库 | github.com/llfbandit/record | `/llfbandit/record` | 2026-06-19 | 高 |
| just_audio 仓库 | github.com/ryanheise/just_audio | `/ryanheise/just_audio` | 2026-06-19 | 高 |
| permission_handler 仓库 | github.com/baseflow/flutter-permission-handler | `/baseflow/flutter-permission-handler` | 2026-06-19 | 高 |
| freezed 仓库 | github.com/rrousselgit/freezed | `/rrousselgit/freezed` | 2026-06-19 | 高 |

---

## Flutter Project Creation Notes

### 当前稳定版本信息（基于 Context7 查询）

| 项目 | 当前推荐 | 来源 |
|------|----------|------|
| Flutter SDK | **3.41+ / 3.44+** （Context7 示例使用 `flutter: ">=3.41.0"` 与 `>=3.44.0`） | Context7 文档片段 |
| Dart SDK | **3.11+ / 3.12+** （Context7 示例使用 `sdk: ^3.11.0` 与 `^3.12.0`） | Context7 文档片段 |
| Android compileSdk | 34（Flutter Gradle 插件默认），**permission_handler 3.1+ 要求 ≥ 33** | Context7 文档 |
| Android minSdk | **21** （Flutter 3.22 起） | Flutter release notes 3.22 |
| Android targetSdk | 34（Flutter Gradle 插件默认） | Flutter release notes |
| Material 3 | Flutter 2.10 起支持，**3.16 起默认开启** | Flutter release notes |

> **T005 最终确认**：具体 Flutter / Dart 版本号在 T005（添加依赖）时通过 `flutter --version` 与 `pub.dev` 实时查询后写入 pubspec.yaml。**T004 不锁版本**。

### 创建命令

```bash
# T004 阶段执行：项目名 lowercase_with_underscores
flutter create --org com.yupi.ukulele --platforms=android ukulele_app
```

要点：

- 使用 `--platforms=android` 显式只创建 Android 平台（iOS 预留，**不在 T004 创建**）
- 使用 `--org com.yupi.ukulele` 统一 applicationId 前缀
- **不要**使用 `--org com.example`（示例域名在正式项目中应替换）

### Android Gradle 配置（T004 / T005 阶段）

Context7 文档显示 Flutter 3.x 的 `android/app/build.gradle.kts` 默认结构：

```kotlin
android {
    namespace = "com.example.[project]"   // → 改为 com.yupi.ukulele
    compileSdk = flutter.compileSdkVersion // → 默认 34
    ndkVersion = flutter.ndkVersion
    defaultConfig {
        applicationId = "com.example.[project]" // → 改为 com.yupi.ukulele
        minSdk = flutter.minSdkVersion          // → 默认 21 (Flutter 3.22+)
        targetSdk = flutter.targetSdkVersion    // → 默认 34
    }
}
```

MVP 必须明确：

- `minSdk = 21`（与 PRD 一致）
- `targetSdk = 34`
- `compileSdk = 34`（如果引入 permission_handler 3.1+，可升级到 35）

---

## Dart / Flutter Version Notes

### SDK 约束策略

参考 Context7 文档片段，Flutter 3.44 要求 Dart SDK `^3.12.0`。MVP 建议：

```yaml
# pubspec.yaml 草案（待 T005 最终确认）
environment:
  sdk: ^3.5.0       # 保守范围；T005 时按 Context7/pub.dev 最新版调整
  flutter: ">=3.24.0" # 保守范围；保证 Material 3 默认开启
```

**注意**：

- 不能在 T004 之前锁定版本号
- T005 时按"实际最新稳定版兼容矩阵"调整
- 不能使用 `sdk: '>=3.0.0 <4.0.0'`（过宽，没有约束力）

### Flutter 3.x → Material 3 默认

- Flutter 3.16 起，新项目默认 `useMaterial3: true`
- MVP 不需要显式设置 `useMaterial3: true`，但需要明确**只用 Material 3 组件**
- ThemeData 中使用 `ColorScheme.fromSeed(seedColor: ...)` 而不是手动定义颜色

---

## Riverpod Notes

### 版本现状（Context7）

- 当前主线版本：**Riverpod 3.x**（3.3.x 系列，`flutter_riverpod` 3.3.2 与 `riverpod` 3.3.2 强绑定）
- Riverpod 2.x → 3.x 迁移文档已发布（`3.0_migration.mdx`）
- 主要破坏性变化：Notifier / AsyncNotifier API 统一，ref 接口简化

### 当前推荐写法（Riverpod 3.x）

**Notifier**：

```dart
class MyNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void increment() => state++;
}

final myNotifierProvider = NotifierProvider<MyNotifier, int>(MyNotifier.new);
```

**AsyncNotifier**（取代 StateNotifier + AsyncValue）：

```dart
class TodoListNotifier extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async {
    return Future.delayed(const Duration(seconds: 1), () => ['Buy milk']);
  }
  Future<void> add(String todo) async {
    state = await AsyncValue.guard(() async {
      final cur = await future;
      return [...cur, todo];
    });
  }
}
final todoListProvider = AsyncNotifierProvider<TodoListNotifier, List<String>>(TodoListNotifier.new);
```

### 代码生成（@riverpod 注解）

```yaml
dependencies:
  flutter_riverpod: ^3.3.2     # 待 T005 确认
  riverpod_annotation: ^3.3.2  # 待 T005 确认

dev_dependencies:
  build_runner: ^2.x           # 待 T005 确认
  riverpod_generator: ^3.3.2   # 待 T005 确认
```

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'main.g.dart';

@riverpod
String label(Ref ref) => 'Hello world';
```

### 对 MVP 的影响

1. MVP 推荐使用 **Riverpod 3.x** 的 `Notifier` / `AsyncNotifier` API
2. 是否启用 `@riverpod` 代码生成 → T003 决策
   - 优点：编译期类型检查、减少模板代码
   - 缺点：增加 `build_runner` 依赖、学习成本
   - **建议**：MVP 启用，但保留手写 Notifier 的能力（混合使用）
3. 不要使用 StateNotifier（已被 AsyncNotifier 取代）

---

## Drift Notes

### 版本与基础设置（Context7）

- Drift 当前稳定 2.x 系列（`drift` + `drift_dev` + `sqlite3_flutter_libs` 配套）
- 推荐使用 `FlutterQueryExecutor.shared`（默认设置）
- 也可使用 `LazyDatabase(() async { ... })` 手动管理路径

### 推荐用法

**定义表**：

```dart
class TodoItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 50)();
  DateTimeColumn get dueDate => dateTime().nullable()();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
}
```

**数据库类**：

```dart
@DriftDatabase(tables: [TodoItems, ...])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(FlutterQueryExecutor.shared);

  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
}
```

### 迁移策略（Context7 推荐写法）

**方式一：手写 MigrationStrategy**（MVP 推荐，简单可控）：

```dart
@override
int get schemaVersion => 2;

@override
MigrationStrategy get migration => MigrationStrategy(
  onCreate: (m) async => m.createAll(),
  onUpgrade: (m, from, to) async {
    if (from == 1) {
      await m.addColumn(todos, todos.dueDate);
    }
  },
);
```

**方式二：stepByStep**（更严格，适合长期演进）：

```dart
@override
MigrationStrategy get migration => MigrationStrategy(
  onUpgrade: stepByStep(
    from1To2: (m, schema) async => m.addColumn(schema.users, schema.users.birthdate),
  ),
);
```

**方式三：make-migrations 命令**（生成初始 schema 文件）：

```bash
dart run drift_dev make-migrations
```

### 对 MVP 的影响

1. MVP schemaVersion = 1，**不需要迁移**（架构预留）
2. 推荐使用 `FlutterQueryExecutor.shared`，简化路径管理
3. `sqlite3_flutter_libs` 必须加，因为 Flutter Android 默认不携带 SQLite
4. 不要混用 `sqflite`，否则会出现 SQLite 实例不一致

---

## go_router Notes

### 版本与基础

- go_router 当前稳定版本 **14.x+**（Context7 显示 6.0.x 系列为旧版，pub.dev 最新为 14.x）
- 推荐使用 `MaterialApp.router(routerConfig: _router)` 模式

### 推荐配置

```dart
final GoRouter _router = GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (ctx, state) => const HomeScreen(),
      routes: <RouteBase>[
        GoRoute(path: 'details', builder: (ctx, state) => const DetailsScreen()),
      ],
    ),
  ],
);

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(routerConfig: _router);
  }
}
```

### 关键能力

- ShellRoute 支持嵌套导航（底部 Tab / 抽屉）
- 路径参数：`/user/:id`
- 重定向：基于 state 做权限/登录跳转
- 错误页：`errorBuilder: (ctx, state) => ...`

### 对 MVP 的影响

1. MVP 路由表简单，**不需要 ShellRoute**（无底部 Tab 需求）
2. MVP 路由深度 ≤ 2 层
3. **不要**使用 Navigator 1.0 混合
4. MVP 不需要重定向（无登录态）

---

## Material 3 Notes

### 当前状态

- Flutter 3.16+ 默认 Material 3（`useMaterial3: true` 默认）
- Material 3 支持早在 2.10 已加入

### 推荐用法（Context7）

```dart
MaterialApp(
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: Brightness.light, // 或 dark
    ),
    textTheme: TextTheme(
      // 使用 M3 命名（titleLarge / bodyMedium / displaySmall）
      titleLarge: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
      bodyMedium: TextStyle(fontSize: 14),
    ),
  ),
  home: const HomePage(),
);
```

### 对 MVP 的影响

1. MVP **默认 Material 3**，不显式设置 `useMaterial3: true`
2. 颜色用 `ColorScheme.fromSeed(seedColor: ...)`，避免手写十六进制
3. 字体使用 M3 命名（`titleLarge`、`bodyMedium` 等），不用旧的 `headline4`
4. **MVP 不做深色模式**（PRD 6.2 明确），但 ThemeData 结构预留扩展

---

## Android First / iOS Reserved Notes

### T004 阶段

```bash
# 只创建 Android 平台
flutter create --org com.yupi.ukulele --platforms=android ukulele_app
```

### 后期 iOS 加入

```bash
# 后期添加 iOS 平台（**不在 T004 执行**）
flutter create --platforms=ios .
```

### iOS 预留但不做的事

| 项目 | 状态 |
|------|------|
| `ios/` 目录 | T004 不创建 |
| iOS Info.plist 配置 | T004 不写 |
| iOS 签名证书 | 不配置 |
| iOS CI | 不配置 |

### iOS 必做但可推迟的事

| 项目 | 说明 |
|------|------|
| `NSMicrophoneUsageDescription` Info.plist 配置 | 等真正做 iOS 版本时配置 |
| iOS 部署目标 | PRD 写 12.0，T004 不设置 |

---

## Dependency Version Strategy for T005

### 策略原则

1. **不在 T004 写具体版本号**（只写 `<T005-confirmed-version>`）
2. **T005 时通过 Context7 + pub.dev 查询最新稳定版**
3. **使用 ^x.y.z 范围约束**，避免破坏性升级
4. **dev_dependencies 与 dependencies 同步升级**
5. **重大版本升级走 ADR 流程**

### 依赖版本差异提醒（**重要**）

T001 发现 **TECH_STACK.md 中现有候选版本** 与 Context7 文档反映的**当前主线版本**存在差异：

| 依赖 | TECH_STACK 候选 | Context7 当前主线 | 状态 |
|------|----------------|-------------------|------|
| record | `^5.1.0` | `7.0.1`（含 Android minSdk 23 要求） | **需 T003 更新 TECH_STACK** |
| Riverpod | `2.x` | `3.3.2`（`flutter_riverpod`） | **需 T003 更新 TECH_STACK** |
| just_audio | `^0.6.21` | `^0.10.x` | **需 T003 更新 TECH_STACK** |

**T003 处理**：在更新 TECH_STACK 时务必使用 Context7 / pub.dev 实时数据，不要继续沿用 T000 阶段的候选范围。

---

### T005 必须确认的依赖清单

| 依赖 | 用途 | 候选版本范围 | 备注 |
|------|------|--------------|------|
| flutter | SDK | ≥3.24.0 | T004 不锁 |
| flutter_riverpod | 状态管理 | ^3.3.2 | Riverpod 3.x |
| riverpod_annotation | 代码生成 | ^3.3.2 | 可选 |
| riverpod_generator | 代码生成 | ^3.3.2 | dev_dependency |
| go_router | 路由 | ^14.x | |
| drift | ORM | ^2.x | |
| sqlite3_flutter_libs | SQLite native | ^0.5.x | |
| path_provider | 路径 | ^2.x | |
| path | 路径处理 | ^1.x | |
| record | 录音 | ^7.x | 7.0.1 为当前主线 |
| just_audio | 播放 | ^0.10.x | |
| permission_handler | 权限 | ^11.x 或更新 | 3.1+ 要求 compileSdk ≥33 |
| freezed_annotation | 数据类 | ^3.x | |
| json_annotation | JSON | ^4.x | |
| intl | 国际化 | ^0.19.x | |
| flutter_lints | lint | latest | dev_dependency |
| build_runner | 代码生成 | ^2.x | dev_dependency |
| freezed | 代码生成 | ^3.x | dev_dependency |
| json_serializable | JSON 代码生成 | ^6.x | dev_dependency |
| drift_dev | Drift 代码生成 | ^2.x | dev_dependency |

> 所有具体版本号**必须由 T005 实际执行 `flutter pub add` 或 `pub.dev` 实时查询后写入**，本文档不锁版本。

### 决策原则

1. **优先稳定版**，不要追最新版
2. **保持依赖相互兼容**（Riverpod 3.x 锁定 riverpod_annotation 3.x）
3. **避免依赖废弃包**（如 flutter_sound 的部分子包）
4. **避免重复依赖**（如不要同时 sqflite 和 drift）

---

## Decisions Needed in T003

T003（技术架构定稿）必须解决：

1. **是否启用 @riverpod 代码生成**？
   - 推荐：MVP 启用，体验更好
   - 备选：纯手写 Notifier，避免 build_runner 学习成本

2. **Drift schema 演进策略**？
   - 推荐：MVP schemaVersion=1，T003 写明未来 addColumn / createTable 的命名规范

3. **go_router 路由错误页是否独立模块**？
   - 推荐：放在 `app/router.dart` 中
   - 备选：独立 `app/error_page.dart`

4. **Material 3 seed color 选择**？
   - 推荐：选用尤克里里主题色（如木色或暖橙），T003 决定具体值
   - 备选：先用 `Colors.deepPurple` 占位

5. **iOS 目录何时创建**？
   - 推荐：T004 不创建，T003 文档明确"iOS 平台何时启用"
   - 备选：T004 就创建（不推荐，与 PRD 不一致）

---

## 工具使用声明

- **Context7**：✅ 可用，作为本文档主要来源
- **Firecrawl / WebSearch / WebFetch**：本环境均不可用
- 本文未抓取任何"实时 pub.dev 页面"，所有版本号均为 Context7 文档中**示例引用**或**模型知识**
- **T005 阶段必须实际查询 pub.dev 写入版本号**，本文档不替代实时查询