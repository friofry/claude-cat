#!/bin/bash
# ClaudeCat: build and run, install, or uninstall.
#
#   ./run.sh                      build and launch from build/ (hooks must already be installed)
#   ./run.sh --install [--login]  build, copy to ~/Applications, register the hooks, launch;
#                                 --login also starts it at login
#   ./run.sh --uninstall          remove the app, LaunchAgent, hooks and state
set -euo pipefail
cd "$(dirname "$0")"

APP=build/ClaudeCat.app
DEST="$HOME/Applications/ClaudeCat.app"
HOOK="$DEST/Contents/Helpers/claude-cat-hook"
SETTINGS="$HOME/.claude/settings.json"
AGENT="$HOME/Library/LaunchAgents/local.claude-cat.plist"
EVENTS='"SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse", "PermissionRequest", "Notification", "Stop", "SessionEnd"'

build() {
  swift build -c release
  local bin
  bin=$(swift build -c release --show-bin-path)
  rm -rf "$APP"
  mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Helpers"
  cp "$bin/ClaudeCat" "$APP/Contents/MacOS/ClaudeCat"
  cp "$bin/claude-cat-hook" "$APP/Contents/Helpers/claude-cat-hook"
  cp Resources/Info.plist "$APP/Contents/Info.plist"
  codesign --force --deep -s - "$APP" >/dev/null
  echo "built $APP"
}

stop_app() {
  launchctl bootout "gui/$(id -u)/local.claude-cat" 2>/dev/null || true
  pkill -x ClaudeCat 2>/dev/null || true
}

# Rewrites settings.json without ClaudeCat's hooks; with "add", appends them again.
edit_hooks() {
  [ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
  local tmp
  tmp=$(mktemp)
  jq --arg cmd "$HOOK" --arg mode "$1" "
    def mine: tostring | contains(\"claude-cat-hook\");
    # Stop also starts the reply listener, which wakes a finished session with a reply sent from ClaudeCat.
    def entry(\$ev):
      (if (\$ev | IN(\"PreToolUse\", \"PostToolUse\", \"PermissionRequest\", \"Notification\")) then {matcher: \"*\"} else {} end)
      + {hooks: ([{type: \"command\", command: \$cmd, timeout: 5}]
          + (if \$ev == \"Stop\" then [{type: \"command\", command: (\$cmd + \" listen\"), asyncRewake: true, timeout: 21600}] else [] end))};
    .hooks = ((.hooks // {}) | with_entries(.value |= map(select(mine | not))))
    | if \$mode == \"add\" then reduce ($EVENTS) as \$ev (.; .hooks[\$ev] += [entry(\$ev)]) else . end
    | .hooks |= with_entries(select(.value | length > 0))
    | if .hooks == {} then del(.hooks) else . end
  " "$SETTINGS" > "$tmp"
  mv "$tmp" "$SETTINGS"
}

install() {
  build
  stop_app
  mkdir -p "$HOME/Applications"
  rm -rf "$DEST"
  cp -R "$APP" "$DEST"
  cp "$SETTINGS" "$SETTINGS.bak-claude-cat" 2>/dev/null || true
  edit_hooks add
  echo "hooks registered in $SETTINGS (backup: $SETTINGS.bak-claude-cat)"

  if [ "${1:-}" = "--login" ]; then
    mkdir -p "$(dirname "$AGENT")"
    cat > "$AGENT" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>local.claude-cat</string>
    <key>ProgramArguments</key><array><string>$DEST/Contents/MacOS/ClaudeCat</string></array>
    <key>RunAtLoad</key><true/>
    <key>ProcessType</key><string>Interactive</string>
</dict>
</plist>
EOF
    launchctl bootstrap "gui/$(id -u)" "$AGENT"
    echo "starts at login: $AGENT"
  else
    open "$DEST"
  fi
  echo "ClaudeCat is running"
}

uninstall() {
  stop_app
  rm -f "$AGENT"
  rm -rf "$DEST" "$HOME/.claude-cat"
  [ -f "$SETTINGS" ] && edit_hooks remove
  echo "ClaudeCat removed"
}

case "${1:-}" in
  "") build; stop_app; open "$APP"; echo "ClaudeCat is running from $APP" ;;
  --install) install "${2:-}" ;;
  --uninstall) uninstall ;;
  *) sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
