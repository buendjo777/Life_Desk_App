#!/bin/bash
# Builds AboutJose in release, assembles AboutJose.app with the story and the Desk screenshots it shows,
# signs it ad hoc and installs it to ~/Applications. The sibling of build-app.sh, at the same zero cost.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --product AboutJose
BIN="$(swift build -c release --show-bin-path)/AboutJose"

# Assemble outside the repo: codesign refuses a bundle that carries Finder attributes (see build-app.sh).
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
APP="$STAGE/AboutJose.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/screens"
cp "$BIN" "$APP/Contents/MacOS/AboutJose"
cp scripts/AboutJose-Info.plist "$APP/Contents/Info.plist"
cp about/story.json "$APP/Contents/Resources/story.json"

# The Desk screens the story names, light and dark, at half size: the app shows them small.
for FILE in $(sed -n 's/.*"file": *"\([^"]*\)".*/\1/p' about/story.json); do
  for SCHEME in light dark; do
    sips -Z 1440 "design/screenshots/$FILE-$SCHEME.png" --out "$APP/Contents/Resources/screens/$FILE-$SCHEME.png" >/dev/null
  done
done

# The icon is drawn by the app itself, then packed with iconutil.
ICONSET="$STAGE/AppIcon.iconset"
if "$BIN" --render-icon "$ICONSET" >/dev/null 2>&1; then
  iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
fi

find "$APP" -name .DS_Store -delete
xattr -cr "$APP"
codesign --force --deep --sign - --requirements '=designated => identifier "app.aboutjose.mac"' "$APP"

mkdir -p "$HOME/Applications"
rm -rf "$HOME/Applications/AboutJose.app"
ditto --norsrc --noextattr "$APP" "$HOME/Applications/AboutJose.app"
codesign --verify --deep --strict "$HOME/Applications/AboutJose.app"
echo "Installed $HOME/Applications/AboutJose.app"
