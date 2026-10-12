#!/bin/zsh
set -euo pipefail
PROJECT_DIR="${0:A:h:h}"
APP_DIR="$PROJECT_DIR/build/BlankNote.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$PROJECT_DIR/build/module-cache"
export CLANG_MODULE_CACHE_PATH="$PROJECT_DIR/build/module-cache"
cd "$PROJECT_DIR"
swift build -c release --product BlankNote --scratch-path "$PROJECT_DIR/build/swift" --cache-path "$PROJECT_DIR/build/cache" --config-path "$PROJECT_DIR/build/config" --security-path "$PROJECT_DIR/build/security"
cp "$PROJECT_DIR/build/swift/release/BlankNote" "$APP_DIR/Contents/MacOS/BlankNote"
cp "$PROJECT_DIR/Info.plist" "$APP_DIR/Contents/Info.plist"
xcrun swift -module-cache-path "$PROJECT_DIR/build/module-cache" scripts/make-icon.swift "$PROJECT_DIR/build/BlankNote.iconset"
iconutil -c icns "$PROJECT_DIR/build/BlankNote.iconset" -o "$APP_DIR/Contents/Resources/BlankNote.icns"
codesign --force --deep --sign - "$APP_DIR"
echo "$APP_DIR"
