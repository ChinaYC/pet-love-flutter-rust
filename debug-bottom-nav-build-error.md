[OPEN] bottom-nav-build-error

# Debug Session

- Session ID: `bottom-nav-build-error`
- Started At: `2026-06-28`
- Symptom:
  - 切换底部菜单时仍触发 Riverpod 异常
  - 报错为 `setState() or markNeedsBuild() called during build`
- Expected:
  - 切换底部菜单时不应在构建阶段触发 provider 重建异常

# Hypotheses

1. `inventoryDataChangeProvider` 仍在某些帧阶段同步触发，延后策略覆盖不完整。
2. 底部菜单切换过程中，某个页面的 `build` 或路由回调里直接触发了 `ref.invalidate` / provider state 更新。
3. `ProviderScope` 某个 override notifier 在页面重建时执行了同步状态写入，最终命中了 `UncontrolledProviderScope` 断言。
4. `GoRouter` 的 `StatefulShellRoute.indexedStack` 在切分支时与页面内 `AsyncValue` 刷新逻辑同帧冲突。
5. 不是 inventory 同步链路，而是设置抽屉/主题/用户信息相关 provider 在菜单切换时被意外触发。

# Plan

1. 先添加最小埋点，不改业务逻辑。
2. 复现并收集日志，确认究竟是哪一个 provider/页面先触发更新。
3. 依据证据做最小修复，再做 post-fix 对比验证。

# Analysis Update

- Runtime evidence status:
  - 由于本地 Debug Server 未稳定接收事件，`.dbg/trae-debug-log-bottom-nav-build-error.ndjson` 未成功生成。
  - 临时埋点反而引入了 `HttpException: Connection reset by peer` 噪音，因此已先移除，避免干扰主问题验证。
- Best current hypothesis:
  - `inventorySettingsProvider` 在首次进入“囤货”页时被创建。
  - 其构造函数会立刻触发 `_loadSettings()`，而 `_loadSettings()` 内部存在多处 `state = ...`。
  - 当底部菜单切换触发 `StatefulShellRoute.indexedStack` 分支构建时，如果这些状态写入落在同一 build 帧，会命中 `UncontrolledProviderScope during build` 断言。

# Fix Applied

1. 将 `InventorySettingsNotifier` 的首次加载改为“构建期安全启动”：
   - 若当前处于 Flutter build 相关 scheduler phase，则延后到下一帧再执行 `_loadSettings()`。
2. 将 `InventorySettingsNotifier` 内部所有关键 `state = ...` 更新改为 `_updateStateSafely(...)`：
   - 若当前处于构建阶段，则自动延后到下一帧再提交状态。
3. 移除本次调试阶段引入的 HTTP 埋点，避免 `Connection reset by peer` 干扰运行。
4. 修复 `userProfileProvider` 初始化策略：
   - 原先在 `main.dart` 中使用 `userProfileProvider.overrideWith(() => notifier..init(profile))`
   - 这会在 provider 创建过程中同步写 `state`
   - 现改为 `initialUserProfileProvider` 注入初始值，由 `build()` 直接读取，避免构建期同步 `init()`

# Next Verification

- 需要用户重新全量运行应用并验证：
  - 首次切到“囤货”页
  - 在“账本”与“囤货”之间快速切换
  - 确认是否仍出现 `UncontrolledProviderScope` / `TickerMode` during build 报错
