#!/bin/zsh
# Preserve the app, notebook and preferences before an in-place update.
set -euo pipefail
PROJECT_DIR="${0:A:h:h}"
SOURCE_APP="$PROJECT_DIR/build/BlankNote.app"
DEST_APP="$HOME/Applications/BlankNote.app"
DATA_DIR="$HOME/Library/Application Support/BlankNote"
if [[ ! -d "$DEST_APP" || ! -x "$SOURCE_APP/Contents/MacOS/BlankNote" ]]; then
  echo "缺少已安装应用或新构建，请先检查安装路径并运行 scripts/build.sh。" >&2
  exit 1
fi
if pgrep -x BlankNote >/dev/null; then
  echo "请先通过菜单退出 BlankNote（包括独立测试版）。本脚本不会强制关闭或丢弃输入。" >&2
  exit 1
fi
codesign --verify --deep --strict "$SOURCE_APP"
BACKUP_DIR="$DATA_DIR/Upgrade Backups/$(date +%Y%m%d-%H%M%S)-$(uuidgen)"
mkdir -p "$BACKUP_DIR"
ditto "$DEST_APP" "$BACKUP_DIR/BlankNote.app"
for NAME in notebook.json notebook.backup.json; do
  if [[ -f "$DATA_DIR/$NAME" ]]; then
    cp -p "$DATA_DIR/$NAME" "$BACKUP_DIR/$NAME"
  fi
done
defaults export org.blanknote.BlankNote "$BACKUP_DIR/preferences.plist" 2>/dev/null || true
echo "完整备份：$BACKUP_DIR"
ditto "$SOURCE_APP" "$DEST_APP"
codesign --verify --deep --strict "$DEST_APP"
if [[ -f "$BACKUP_DIR/notebook.json" ]]; then
  cmp "$DATA_DIR/notebook.json" "$BACKUP_DIR/notebook.json"
  echo "记录校验通过：更新前后 notebook.json 完全一致。"
fi
if launchctl print "gui/$(id -u)/org.blanknote.BlankNote" >/dev/null 2>&1; then
  launchctl kickstart "gui/$(id -u)/org.blanknote.BlankNote" || open "$DEST_APP"
else
  open "$DEST_APP"
fi
echo "已更新并启动 BlankNote；未修改登录启动偏好。"
