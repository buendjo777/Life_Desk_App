#!/bin/bash
# Builds Desk in release, assembles Desk.app, signs it ad hoc and installs it to ~/Applications.
# Zero cost: no Apple Developer Program, no notarisation.
#   DESK_DIST=<dir>   write <dir>/Desk.zip instead of installing (scripts/release.sh)
#   DESK_UNIVERSAL=1  build for Apple silicon and Intel
#   DESK_VERSION=1.2  the version shown in Finder
set -euo pipefail
cd "$(dirname "$0")/.."

ARCHS=()
if [ "${DESK_UNIVERSAL:-}" = 1 ]; then ARCHS=(--arch arm64 --arch x86_64); fi
swift build -c release --product Desk ${ARCHS[@]+"${ARCHS[@]}"}
BIN="$(swift build -c release ${ARCHS[@]+"${ARCHS[@]}"} --show-bin-path)/Desk"

# Assemble outside the repo: a repo inside an iCloud-synced folder gets Finder attributes
# on every new directory, and codesign refuses a bundle that carries them.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
APP="$STAGE/Desk.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Desk"
cp scripts/Info.plist "$APP/Contents/Info.plist"
if [ -n "${DESK_VERSION:-}" ]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $DESK_VERSION" "$APP/Contents/Info.plist"
fi
cp -R demo-vault "$APP/Contents/Resources/demo-vault"
cp -R starter-vault "$APP/Contents/Resources/starter-vault"

# The icon is drawn by the app itself, then packed with iconutil.
ICONSET="$STAGE/AppIcon.iconset"
if "$BIN" --render-icon "$ICONSET" >/dev/null 2>&1; then
  iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
fi

# Finder metadata (.DS_Store, extended attributes) makes codesign refuse the bundle.
find "$APP" -name .DS_Store -delete
xattr -cr "$APP"
# Ad-hoc signing names the build by its hash, so macOS would ask again for Calendar and Notes after every
# rebuild. A fixed requirement (the bundle identifier) lets the permissions carry over from build to build.
codesign --force --deep --sign - --requirements '=designated => identifier "app.desk.mac"' "$APP"

if [ -n "${DESK_DIST:-}" ]; then
  codesign --verify --deep --strict "$APP"
  mkdir -p "$DESK_DIST"
  ditto -c -k --norsrc --keepParent "$APP" "$DESK_DIST/Desk.zip"
  echo "Wrote $DESK_DIST/Desk.zip"
  exit 0
fi

mkdir -p "$HOME/Applications"
rm -rf "$HOME/Applications/Desk.app"
ditto --norsrc --noextattr "$APP" "$HOME/Applications/Desk.app"
codesign --verify --deep --strict "$HOME/Applications/Desk.app"
echo "Installed $HOME/Applications/Desk.app"
