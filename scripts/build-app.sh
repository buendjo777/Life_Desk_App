#!/bin/bash
# Builds Desk in release, assembles Desk.app, signs it ad hoc and installs it to ~/Applications.
# Zero cost: no Apple Developer Program, no notarisation.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Desk"

# Assemble outside the repo: a repo inside an iCloud-synced folder gets Finder attributes
# on every new directory, and codesign refuses a bundle that carries them.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
APP="$STAGE/Desk.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Desk"
cp scripts/Info.plist "$APP/Contents/Info.plist"
cp -R demo-vault "$APP/Contents/Resources/demo-vault"

# The icon is drawn by the app itself, then packed with iconutil.
ICONSET="$STAGE/AppIcon.iconset"
if "$BIN" --render-icon "$ICONSET" >/dev/null 2>&1; then
  iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
fi

# Finder metadata (.DS_Store, extended attributes) makes codesign refuse the bundle.
find "$APP" -name .DS_Store -delete
xattr -cr "$APP"
codesign --force --deep --sign - "$APP"

mkdir -p "$HOME/Applications"
rm -rf "$HOME/Applications/Desk.app"
ditto --norsrc --noextattr "$APP" "$HOME/Applications/Desk.app"
codesign --verify --deep --strict "$HOME/Applications/Desk.app"
echo "Installed $HOME/Applications/Desk.app"
