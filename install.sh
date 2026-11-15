#!/bin/bash
# Installs the latest Desk for Mac from GitHub. No Xcode, no account, nothing else to download.
#   curl -fsSL https://raw.githubusercontent.com/buendjo777/Life_Desk_App/main/install.sh | bash
set -euo pipefail

URL="https://github.com/buendjo777/Life_Desk_App/releases/latest/download/Desk.zip"

if [ "$(uname)" != Darwin ]; then
  echo "Desk is a Mac app." >&2
  exit 1
fi
if [ "$(sw_vers -productVersion | cut -d. -f1)" -lt 14 ]; then
  echo "Desk needs macOS 14 (Sonoma) or newer. This Mac has $(sw_vers -productVersion)." >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading Desk…"
curl -fL --progress-bar "$URL" -o "$TMP/Desk.zip"
ditto -x -k "$TMP/Desk.zip" "$TMP"

# /Applications when this account may write there, otherwise the personal Applications folder.
DEST="/Applications"
if [ ! -w "$DEST" ]; then
  DEST="$HOME/Applications"
  mkdir -p "$DEST"
fi

pkill -x Desk 2>/dev/null || true
rm -rf "$DEST/Desk.app"
ditto "$TMP/Desk.app" "$DEST/Desk.app"
xattr -dr com.apple.quarantine "$DEST/Desk.app" 2>/dev/null || true

echo "Installed $DEST/Desk.app"
open "$DEST/Desk.app"
