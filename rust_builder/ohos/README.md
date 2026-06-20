# rust_builder HarmonyOS Plan

## 当前目的

- 为 `rust_builder` 预留鸿蒙平台目录。
- 后续在这里补齐 HarmonyOS 插件宿主、动态库打包和加载逻辑。

## 当前已完成

- `cargokit` 目标枚举已预留 `aarch64-unknown-linux-ohos` / `ohos-arm64`。
- 项目根目录提供了 `tools/setup_ohos_rust_target.sh`，用于安装 Rust 鸿蒙 target。

## 当前仍缺失

- `rust_builder/pubspec.yaml` 的 `ohos` 平台声明。
- HarmonyOS 插件宿主工程文件。
- Rust 动态库在鸿蒙侧的打包与加载桥接。
- `flutter_rust_bridge` 在鸿蒙宿主下的初始化链路。

## 建议后续目录

```text
rust_builder/ohos/
├── src/main/ets/
├── src/main/resources/
├── src/main/cpp-or-rust-loader/
├── module.json5
├── build-profile.json5
├── hvigorfile.ts
└── oh-package.json5
```
