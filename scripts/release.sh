#!/bin/bash
# Publishes a version of Desk for everyone:  scripts/release.sh v1.2
# Builds Desk.zip for Apple silicon and Intel, tags the commit and creates the GitHub release that
# install.sh downloads. Needs the GitHub CLI signed in once (`gh auth login`); without it the script
# stops after the build and says where to upload dist/Desk.zip by hand.
set -euo pipefail
cd "$(dirname "$0")/.."

TAG="${1:?Usage: scripts/release.sh v1.2}"
DESK_UNIVERSAL=1 DESK_VERSION="${TAG#v}" DESK_DIST=dist ./scripts/build-app.sh

if ! gh auth status >/dev/null 2>&1; then
  echo "Built dist/Desk.zip. The GitHub CLI is not signed in, so nothing was published."
  echo "Either run 'gh auth login' and this script again, or upload dist/Desk.zip at:"
  echo "  https://github.com/buendjo777/Life_Desk_App/releases/new?tag=$TAG"
  exit 0
fi

git tag -f "$TAG"
git push origin "$TAG"
gh release create "$TAG" dist/Desk.zip --title "Desk $TAG" --notes-file scripts/release-notes.md
