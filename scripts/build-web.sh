#!/bin/bash
# Builds the web copy of AboutJose into docs/: one static page, no server, nothing to install to read it.
# The words come from about/story.json and the colours from the app itself, so the page cannot drift from either.
# docs/ is what GitHub Pages serves (Settings → Pages → main, /docs). Open docs/index.html to read it locally.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build --product AboutJose
BIN="$(swift build --show-bin-path)/AboutJose"

OUT="docs"
rm -rf "$OUT"
mkdir -p "$OUT/screens"
cp web/index.html "$OUT/index.html"
# GitHub Pages would otherwise run the folder through Jekyll.
touch "$OUT/.nojekyll"

# The story and the theme as one script, so the page also opens straight from disk.
{
  printf 'window.STORY = '
  cat about/story.json
  printf ';\nwindow.THEME = '
  "$BIN" --web-theme
  printf ';\n'
} > "$OUT/data.js"

# The Desk screens the story names, light and dark, small enough for a phone.
for FILE in $(sed -n 's/.*"file": *"\([^"]*\)".*/\1/p' about/story.json); do
  for SCHEME in light dark; do
    sips -s format jpeg -s formatOptions 78 -Z 1440 "design/screenshots/$FILE-$SCHEME.png" --out "$OUT/screens/$FILE-$SCHEME.jpg" >/dev/null
  done
done

echo "Built $OUT/ ($(du -sh "$OUT" | cut -f1)). Open $OUT/index.html"
