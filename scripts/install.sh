#!/bin/zsh
# Explicitly installs only the current user's app and login agent.
set -euo pipefail
PROJECT_DIR="${0:A:h:h}"
SOURCE_APP="$PROJECT_DIR/build/BlankNote.app"
DEST_APP="$HOME/Applications/BlankNote.app"
AGENT_FILE="$HOME/Library/LaunchAgents/org.blanknote.BlankNote.plist"
DATA_DIR="$HOME/Library/Application Support/BlankNote"
if [[ ! -x "$SOURCE_APP/Contents/MacOS/BlankNote" ]]; then
  echo "请先运行：zsh scripts/build.sh" >&2
  exit 1
fi
if [[ -e "$DEST_APP" || -e "$AGENT_FILE" ]]; then
  echo "已存在 BlankNote 应用或启动项，安装已停止，未覆盖任何内容。请先确认旧版本的处理方式。" >&2
  exit 1
fi
codesign --verify --deep --strict "$SOURCE_APP"
mkdir -p "$HOME/Applications" "$HOME/Library/LaunchAgents" "$DATA_DIR/Logs"
ditto "$SOURCE_APP" "$DEST_APP"
/usr/libexec/PlistBuddy -c 'Clear dict' -c 'Add :Label string org.blanknote.BlankNote' -c 'Add :ProgramArguments array' -c "Add :ProgramArguments:0 string $DEST_APP/Contents/MacOS/BlankNote" -c 'Add :RunAtLoad bool true' -c 'Add :KeepAlive dict' -c 'Add :KeepAlive:SuccessfulExit bool false' -c 'Add :ThrottleInterval integer 10' -c 'Add :ProcessType string Interactive' -c 'Add :LimitLoadToSessionType string Aqua' -c "Add :StandardOutPath string $DATA_DIR/Logs/stdout.log" -c "Add :StandardErrorPath string $DATA_DIR/Logs/stderr.log" "$AGENT_FILE"
plutil -lint "$AGENT_FILE"
launchctl bootstrap "gui/$(id -u)" "$AGENT_FILE"
launchctl print "gui/$(id -u)/org.blanknote.BlankNote"
echo "已安装并启动：$DEST_APP"
