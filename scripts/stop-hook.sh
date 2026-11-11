#!/bin/bash
# Stop hook: a turn cannot end on a broken build or failing tests.
# Exit code 2 blocks the stop and hands the output back to Claude.
cd "$(dirname "$0")/.." || exit 0
[ -f Package.swift ] || exit 0
if ! out=$(swift build 2>&1); then
  echo "swift build failed:" >&2; echo "$out" | tail -40 >&2; exit 2
fi
if ! out=$(swift test 2>&1); then
  echo "swift test failed:" >&2; echo "$out" | tail -60 >&2; exit 2
fi
exit 0
