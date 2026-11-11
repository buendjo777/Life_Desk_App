#!/bin/bash
# Builds Desk in release, assembles Desk.app, signs it ad hoc and installs it to ~/Applications.
# Zero cost: no Apple Developer Program, no notarisation.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Desk"

APP="build/Desk.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Desk"
cp scripts/Info.plist "$APP/Contents/Info.plist"
cp -R demo-vault "$APP/Contents/Resources/demo-vault"

# The icon is drawn by the app itself, then packed with iconutil.
ICONSET="build/AppIcon.iconset"
rm -rf "$ICONSET"
if "$BIN" --render-icon "$ICONSET" >/dev/null 2>&1; then
  iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
fi

codesign --force --deep --sign - "$APP"

mkdir -p "$HOME/Applications"
rm -rf "$HOME/Applications/Desk.app"
cp -R "$APP" "$HOME/Applications/Desk.app"
echo "Installed $HOME/Applications/Desk.app"
