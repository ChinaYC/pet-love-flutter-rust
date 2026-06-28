# pet-love-flutter-rust

## 编译与开发指南

如果你修改了 `core` 目录下的 Rust 代码，你需要进入 `core` 目录进行编译，或者重新生成桥接代码：

1. **重新生成桥接代码 (FRB)**
   在项目根目录 (`/Volumes/T7/code/Flutter/pet-love-flutter-rust`) 执行：
   ```bash

   adb connect 10.40.13.96:39163
   adb connect 192.168.110.32:39637

   pkill -f gradle || true
   
   flutter_rust_bridge_codegen generate

   dart fix --apply
   ```

2. **手动编译 Rust 代码 (可选)**
   由于我们使用了 `rust_builder` (Cargokit)，Flutter 在构建/运行应用时（如 `flutter run` 或 Xcode 编译）会**自动调用 Cargo 编译**。
   但如果你想提前检查 Rust 代码是否有语法错误，请进入 `core` 目录执行：
   ```bash
   cd core
   cargo build
   ```
   **注意**：在项目根目录直接执行 `cargo build` 会失败，因为根目录没有 `Cargo.toml` 工作空间配置。

3. **安装 Flutter 依赖**
   进入 `app` 目录执行：
   ```bash
   cd app
   flutter pub get
   ```

## Monorepo 目录树设计

- 采用彻底的 Feature-First 结构，明确划定前端与后端的边界。
- 前端：位于 app/lib/features ，内含 layout 、 settings 、 pet 、 analytics 等业务模块。
- 后端：位于 core/src ，拆分为 api （FFI 接口）、 database 、 logger 、 telemetry 等底层基础设施。
技术配置与依赖

- Flutter 依赖： pubspec.yaml 已集成 flutter_riverpod , go_router , flutter_rust_bridge 等，并开启了跨平台设计支持。
- Rust 依赖： Cargo.toml 已集成 rusqlite (本地数据库), tracing (排查日志), serde 与 tokio (高并发异步处理)。
Rust 侧：核心基础设施与冲突层

- 系统层骨架 ： system.rs 实现了导出诊断日志、埋点事件触发与模拟 OTA 在线更新的骨架，打通了“日志-埋点-更新”三位一体的基础设施。
- Append-Only 冲突检测 ： pet.rs 中的 check_pet_conflicts 和 resolve_pet_conflict 摒弃了传统的 UPDATE 覆盖模式。遇到离线编辑冲突时，使用 INSERT 追加新日志，并将旧记录标记为 superseded ，保证数据不丢失且可追溯。
Flutter 侧：苹果风格 UI 与全局外壳

- 统一动态主题 ： theme_provider.dart 使用 Riverpod 实现了治愈系粉橘色与暗黑模式的动态切换，组件深度对齐 Cupertino 视觉规范（无界感、大圆角卡片）。
- 极简布局与抽屉 ： main_layout_page.dart 实现了底部 4 栏导航，主页顶部点击双人头像可滑出 settings_drawer.dart 。抽屉内直接对接了日志导出、检查更新等系统级接口。
- 优雅的冲突裁决弹窗 ： conflict_resolver_dialog.dart 封装了专属的冲突处理 UI，在检测到两端数据冲突时自然弹出，由用户主导最终数据的合并与保留。




彻底清理 Flutter & CocoaPods 缓存 ：
我执行了以下命令，清理了 Xcode 构建缓存并重新同步了依赖：
cd app
flutter clean
flutter pub get
cd macos
pod install


由于清理了 Xcode 的深度缓存，请 重新执行运行命令 ：
cd app
flutter run -d macos

## ⚠️ Android 构建常见问题 (AGP 9.0+ 与 JVM 兼容性)

如果你在运行 `flutter run` 时遇到 `Failed to apply plugin 'org.jetbrains.kotlin.android'` 或 `The 'org.jetbrains.kotlin.android' plugin is no longer required` 错误，这是因为 AGP 9.0 引入了“内置 Kotlin”机制导致的冲突。
如果你遇到 `Inconsistent JVM-target compatibility detected for tasks 'compileDebugJavaWithJavac' (17) and 'compileDebugKotlin' (21)`，这是因为 Java 目标版本和 Kotlin 默认的工具链版本不一致。

### 一劳永逸的解决方案：
1. **不要**在 `app/android/app/build.gradle.kts` 中显式应用 `kotlin-android` 插件。
2. 必须显式声明 Kotlin 的 `jvmToolchain` 以对齐 Java 版本（推荐 17）：
   ```kotlin
   android {
       compileOptions {
           sourceCompatibility = JavaVersion.VERSION_17
           targetCompatibility = JavaVersion.VERSION_17
       }
       kotlin {
           jvmToolchain(17) // 强制对齐版本，防止默认漂移到 21
       }
   }
   ```
3. 在 `app/android/gradle.properties` 中确保以下配置：
   ```properties
   android.newDsl=false
   android.builtInKotlin=false
   ```
   *注：将这些设为 `false` 是为了兼容尚未适配 AGP 9.0 的第三方插件（如 `package_info_plus`）。*

---

## ⚠️ Android Build Issues (AGP 9.0+ & JVM Compatibility)

If you encounter `Failed to apply plugin 'org.jetbrains.kotlin.android'` or `The 'org.jetbrains.kotlin.android' plugin is no longer required` during `flutter run`, it's due to the "Built-in Kotlin" mechanism in AGP 9.0.
If you see `Inconsistent JVM-target compatibility detected... (17) and (21)`, it's a version mismatch between Java and Kotlin compilation tasks.

### Permanent Fix:
1. **DO NOT** explicitly apply the `kotlin-android` plugin in `app/android/app/build.gradle.kts`.
2. Explicitly define the Kotlin `jvmToolchain` to match your Java version (17 recommended):
   ```kotlin
   android {
       compileOptions {
           sourceCompatibility = JavaVersion.VERSION_17
           targetCompatibility = JavaVersion.VERSION_17
       }
       kotlin {
           jvmToolchain(17) // Prevents drifting to Java 21 default
       }
   }
   ```
3. Ensure the following in `app/android/gradle.properties`:
   ```properties
   android.newDsl=false
   android.builtInKotlin=false
   ```
   *Note: Keeping these `false` is necessary to support third-party plugins (like `package_info_plus`) that haven't migrated to AGP 9.0 yet.*

# Role
你是一个精通 Rust 生产级架构的专家，深谙领域驱动设计 (DDD)。
当前项目是一个基于同步 `rusqlite` 的本地核心库（需要通过 FFI 与跨平台 UI 桥接）。请绝对禁止引入 tokio、deadpool 或任何 async/await 异步代码。

# Task
我需要在 `core/src/api/` 下开发一个新的领域模块：`[模块名称]`。
具体业务需求如下：
<requirements>
[在此处用自然语言描述你的需求，比如：需要一张宠物表，包含宠物名字、种类、生日，并且能记录每天的喂食状态。]
</requirements># Role
你是一个精通 Rust 生产级架构的专家，深谙领域驱动设计 (DDD)。
当前项目是一个基于同步 `rusqlite` 的本地核心库（需要通过 FFI 与跨平台 UI 桥接）。请绝对禁止引入 tokio、deadpool 或任何 async/await 异步代码。

# Task
我需要在 `core/src/api/` 下开发一个新的领域模块：`[模块名称]`。
具体业务需求如下：
<requirements>
[在此处用自然语言描述你的需求，比如：需要一张宠物表，包含宠物名字、种类、生日，并且能记录每天的喂食状态。]
</requirements># Role你是一个精通 Rust 生产级架构的专家，深谙领域驱动设计 (DDD)。当前项目是一个基于同步 `rusqlite` 的本地核心库（需要通过 FFI 与跨平台 UI 桥接）。请绝对禁止引入 tokio、deadpool 或任何 async/await 异步代码。# Task我需要在 `core/src/api/` 下开发一个新的领域模块：`[模块名称]`。具体业务需求如下：<requirements>[在此处用自然语言描述你的需求，比如：需要一张宠物表，包含宠物名字、种类、生日，并且能记录每天的喂食状态。]</requirements>

# Action Plan
请严格按照本项目已有的架构规范，一步步生成代码。不要省略任何业务逻辑：

## 1. 骨架搭建 (Scaffolding)
在 `core/src/api/[模块名称]/` 下创建标准的子模块结构：
-# Action Plan
请严格按照本项目已有的架构规范，一步步生成代码。不要省略任何业务逻辑：

## 1. 骨架搭建 (Scaffolding)
在 `core/src/api/[模块名称]/` 下创建标准的子模块结构：
-# Action Plan请严格按照本项目已有的架构规范，一步步生成代码。不要省略任何业务逻辑：## 1. 骨架搭建 (Scaffolding)在 `core/src/api/[模块名称]/` 下创建标准的子模块结构：- `mod.rs` (模块统一入口，使用 `pub use` 扁平化导出所有下层 public API)
-`mod.rs` (模块统一入口，使用 `pub use` 扁平化导出所有下层 public API)
-`mod.rs` (模块统一入口，使用 `pub use` 扁平化导出所有下层 public API)- `errors.rs` (使用 `thiserror` 定义该模块专属错误枚举)
-`errors.rs` (使用 `thiserror` 定义该模块专属错误枚举)
-`errors.rs` (使用 `thiserror` 定义该模块专属错误枚举)- `models.rs` (数据结构定义、前端请求的 Payload 结构及防御性校验逻辑)
-`models.rs` (数据结构定义、前端请求的 Payload 结构及防御性校验逻辑)
-`models.rs` (数据结构定义、前端请求的 Payload 结构及防御性校验逻辑)- `[模块名称].rs` (核心业务逻辑与 CRUD 操作)
-`[模块名称].rs` (核心业务逻辑与 CRUD 操作)
-`[模块名称].rs` (核心业务逻辑与 CRUD 操作)- `stats.rs` (如果有聚合统计需求则创建)

## 2. 核心实施规范 (Implementation Rules)`stats.rs` (如果有聚合统计需求则创建)

## 2. 核心实施规范 (Implementation Rules)`stats.rs` (如果有聚合统计需求则创建)## 2. 核心实施规范 (Implementation Rules)
-- **错误处理**: 严禁返回 `Result<T, String>`。所有业务函数必须返回 `Result<T, [模块名称]Error>`。通过 `#[from]` 自动转换 `rusqlite::Error`。错误定义要结构化，方便前端 UI 捕获并做国际化/弹窗提示。
-**错误处理**: 严禁返回 `Result<T, String>`。所有业务函数必须返回 `Result<T, [模块名称]Error>`。通过 `#[from]` 自动转换 `rusqlite::Error`。错误定义要结构化，方便前端 UI 捕获并做国际化/弹窗提示。
-**错误处理**: 严禁返回 `Result<T, String>`。所有业务函数必须返回 `Result<T, [模块名称]Error>`。通过 `#[from]` 自动转换 `rusqlite::Error`。错误定义要结构化，方便前端 UI 捕获并做国际化/弹窗提示。- **数据流转**: 参数超过 3 个时，必须在 `models.rs` 中封装为 `xxxPayload`，并在写入数据库前调用其 `validate()` 方法进行数据清洗。
-**数据流转**: 参数超过 3 个时，必须在 `models.rs` 中封装为 `xxxPayload`，并在写入数据库前调用其 `validate()` 方法进行数据清洗。
-**数据流转**: 参数超过 3 个时，必须在 `models.rs` 中封装为 `xxxPayload`，并在写入数据库前调用其 `validate()` 方法进行数据清洗。- **数据库操作**:
  - 所有跨表或多步写操作必须开启显式事务 `tx`。
  - 使用标准的 `crate::database::get_connection()` 获取同步连接。
  - SQL 语句保持内聚，直接写在业务函数内部。

## 3. 执行要求
请一次性输出上述所有文件的完整代码（不要用 // TODO 省略），并在确认无误后提示我运行 `cargo check` 验证编译。
**数据库操作**:
  - 所有跨表或多步写操作必须开启显式事务 `tx`。
  - 使用标准的 `crate::database::get_connection()` 获取同步连接。
  - SQL 语句保持内聚，直接写在业务函数内部。

## 3. 执行要求
请一次性输出上述所有文件的完整代码（不要用 // TODO 省略），并在确认无误后提示我运行 `cargo check` 验证编译。
**数据库操作**:- 所有跨表或多步写操作必须开启显式事务 `tx`。- 使用标准的 `crate::database::get_connection()` 获取同步连接。- SQL 语句保持内聚，直接写在业务函数内部。## 3. 执行要求请一次性输出上述所有文件的完整代码（不要用 // TODO 省略），并在确认无误后提示我运行 `cargo check` 验证编译。