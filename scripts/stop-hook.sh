#!/bin/bash
# Stop hook: a turn cannot end on a broken build or failing tests.
# Exit code 2 blocks the stop and hands the output back to Claude.
cd "$(dirname "$0")/.." || exit 0
[ -f Package.swift ] || exit 0

# The repo sits in an iCloud-synced folder, and the sync touches files while SwiftPM reads them:
# "input file … was modified during the build". That is a race, not a broken build, so the step is
# run again, up to four times. Any other error fails at once, and a race that never clears still fails.
attempt() {
  local try
  for try in 1 2 3 4; do
    out=$("$@" 2>&1) && return 0
    if echo "$out" | grep "error:" | grep -qv -e "was modified during the build" -e "error: fatalError"; then
      return 1
    fi
    sleep 3
  done
  return 1
}

if ! attempt swift build; then
  echo "swift build failed:" >&2; echo "$out" | tail -40 >&2; exit 2
fi
if ! attempt swift test; then
  echo "swift test failed:" >&2; echo "$out" | tail -60 >&2; exit 2
fi
exit 0
