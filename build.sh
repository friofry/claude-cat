#!/bin/bash
# Builds build/ClaudeCat.app with the hook helper inside.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
BIN=$(swift build -c release --show-bin-path)

APP=build/ClaudeCat.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Helpers"
cp "$BIN/ClaudeCat" "$APP/Contents/MacOS/ClaudeCat"
cp "$BIN/claude-cat-hook" "$APP/Contents/Helpers/claude-cat-hook"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --deep -s - "$APP" >/dev/null

echo "built $APP"
