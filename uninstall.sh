#!/bin/bash
# Removes ClaudeCat, its LaunchAgent, its hooks and its session state.
set -euo pipefail

SETTINGS="$HOME/.claude/settings.json"
AGENT="$HOME/Library/LaunchAgents/local.claude-cat.plist"

launchctl bootout "gui/$(id -u)/local.claude-cat" 2>/dev/null || true
rm -f "$AGENT"
pkill -x ClaudeCat 2>/dev/null || true
rm -rf "$HOME/Applications/ClaudeCat.app" "$HOME/.claude-cat"

if [ -f "$SETTINGS" ]; then
  tmp=$(mktemp)
  jq '
    if .hooks then
      .hooks |= (with_entries(.value |= map(select(tostring | contains("claude-cat-hook") | not)))
                 | with_entries(select(.value | length > 0)))
      | if .hooks == {} then del(.hooks) else . end
    else . end
  ' "$SETTINGS" > "$tmp"
  mv "$tmp" "$SETTINGS"
fi
echo "ClaudeCat removed"
