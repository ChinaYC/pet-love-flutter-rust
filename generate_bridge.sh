#!/bin/bash
set -e

echo "============================================================"
echo "🚀 PetLove: FFI 桥接代码生成脚本 (flutter_rust_bridge v2)"
echo "============================================================"

# 检查环境变量
if ! command -v cargo &> /dev/null; then
    echo "❌ 错误: 未安装 Rust (cargo)。请先运行 curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.tech | sh"
    exit 1
fi

if ! command -v flutter &> /dev/null; then
    echo "❌ 错误: 未安装 Flutter。请确保 flutter 命令在 PATH 中。"
    exit 1
fi

if ! command -v flutter_rust_bridge_codegen &> /dev/null; then
    echo "📦 正在全局安装 flutter_rust_bridge_codegen..."
    cargo install 'flutter_rust_bridge_codegen@^2.0.0'
fi

# 进入核心库确保可以编译
echo "🦀 正在预编译 Rust Core 以校验代码..."
cd core
cargo check
cd ..

# 生成粘合层代码
echo "🌉 正在生成 FFI 桥接代码..."
# FRB v2 的标准生成命令，假设我们在根目录下
# 注意：实际项目中你需要在 pubspec.yaml 和 Cargo.toml 中正确配置 frb，
# 这里提供的是标准构建入口。
flutter_rust_bridge_codegen generate

echo "✅ 桥接代码生成完毕！"
echo "你可以通过运行 'cd app && flutter run' 启动项目了。"
