#!/bin/zsh
set -euo pipefail
PROJECT_DIR="${0:A:h:h}"
cd "$PROJECT_DIR"
mkdir -p "$PROJECT_DIR/build/module-cache"
export CLANG_MODULE_CACHE_PATH="$PROJECT_DIR/build/module-cache"
swift test --scratch-path "$PROJECT_DIR/build/swift" --cache-path "$PROJECT_DIR/build/cache" --config-path "$PROJECT_DIR/build/config" --security-path "$PROJECT_DIR/build/security"
