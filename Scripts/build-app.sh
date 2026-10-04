#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
PROJECT_ROOT="$PWD"
export CLANG_MODULE_CACHE_PATH="$PROJECT_ROOT/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PROJECT_ROOT/.build/ModuleCache"
SWIFT_FLAGS=(--disable-sandbox --cache-path "$PROJECT_ROOT/.build/cache" --config-path "$PROJECT_ROOT/.build/config" --security-path "$PROJECT_ROOT/.build/security")
swift build "${SWIFT_FLAGS[@]}" -c release
BIN_DIR="$(swift build "${SWIFT_FLAGS[@]}" -c release --show-bin-path)"
APP_PATH="$PROJECT_ROOT/dist/GoToShell.app"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
cp "$BIN_DIR/GoToShell" "$APP_PATH/Contents/MacOS/GoToShell"
cp Resources/Info.plist "$APP_PATH/Contents/Info.plist"
swift -module-cache-path "$CLANG_MODULE_CACHE_PATH" Scripts/make-icon.swift "$PROJECT_ROOT/.build/AppIcon.iconset" "$APP_PATH/Contents/Resources/AppIcon.icns"
codesign --force --sign "${SIGNING_IDENTITY:--}" --options runtime --entitlements Resources/GoToShell.entitlements "$APP_PATH"
codesign --verify --strict "$APP_PATH"
printf '\n已生成：%s\n' "$APP_PATH"
