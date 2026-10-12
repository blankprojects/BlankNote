#!/bin/zsh
set -euo pipefail
PROJECT_DIR="${0:A:h:h}"
APP_DIR="$PROJECT_DIR/build/BlankNoteUITest.app"
if [[ ! -x "$PROJECT_DIR/build/BlankNote.app/Contents/MacOS/BlankNote" ]]; then
  echo "先运行 zsh scripts/build.sh" >&2
  exit 1
fi
ditto "$PROJECT_DIR/build/BlankNote.app" "$APP_DIR"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier org.blanknote.BlankNote.UITest' "$APP_DIR/Contents/Info.plist"
codesign --force --deep --sign - "$APP_DIR"
TEST_DATA_DIR="${BLANKNOTE_TEST_DATA_DIR:-$(mktemp -d /tmp/BlankNote-UI.XXXXXX)}"
echo "独立测试数据：$TEST_DATA_DIR"
env BLANKNOTE_DATA_DIR="$TEST_DATA_DIR" "$APP_DIR/Contents/MacOS/BlankNote"
