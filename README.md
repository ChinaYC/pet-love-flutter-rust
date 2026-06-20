# pet-love-flutter-rust

## 编译与开发指南

如果你修改了 `core` 目录下的 Rust 代码，你需要进入 `core` 目录进行编译，或者重新生成桥接代码：

1. **重新生成桥接代码 (FRB)**
   在项目根目录 (`/Volumes/T7/code/Flutter/pet-love-flutter-rust`) 执行：
   ```bash
   flutter_rust_bridge_codegen generate
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