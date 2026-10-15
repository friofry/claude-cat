#!/bin/bash
# Installs ClaudeCat into ~/Applications and registers its hooks in ~/.claude/settings.json.
# --login also starts it at login (LaunchAgent).
set -euo pipefail
cd "$(dirname "$0")"

./build.sh

DEST="$HOME/Applications/ClaudeCat.app"
HOOK="$DEST/Contents/Helpers/claude-cat-hook"
SETTINGS="$HOME/.claude/settings.json"
AGENT="$HOME/Library/LaunchAgents/local.claude-cat.plist"

pkill -x ClaudeCat 2>/dev/null || true
mkdir -p "$HOME/Applications"
rm -rf "$DEST"
cp -R build/ClaudeCat.app "$DEST"

[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
cp "$SETTINGS" "$SETTINGS.bak-claude-cat"
tmp=$(mktemp)
jq --arg cmd "$HOOK" '
  def entry($ev):
    (if ($ev | IN("PreToolUse", "PostToolUse", "PermissionRequest", "Notification")) then {matcher: "*"} else {} end)
    + {hooks: [{type: "command", command: $cmd, timeout: 5}]};
  .hooks = (.hooks // {})
  | reduce ("SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse",
            "PermissionRequest", "Notification", "Stop", "SessionEnd") as $ev (.;
      .hooks[$ev] = (((.hooks[$ev] // []) | map(select(tostring | contains("claude-cat-hook") | not))) + [entry($ev)]))
' "$SETTINGS" > "$tmp"
mv "$tmp" "$SETTINGS"
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
  launchctl bootout "gui/$(id -u)/local.claude-cat" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$AGENT"
  echo "starts at login: $AGENT"
else
  open "$DEST"
fi
echo "ClaudeCat is running"
