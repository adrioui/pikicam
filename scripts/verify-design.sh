#!/usr/bin/env bash
#
# verify-design.sh — run the design lint the way CI does.
#
# Why this exists: between 2026-08 and 2026-10 the design layer sat outside
# every Xcode target. It compiled never, ran never, and `xcodebuild test`
# reported TEST SUCCEEDED having executed zero tests — a false green. The fix
# was to make project.yml the source of truth and regenerate. This script
# asserts that is still true, so the same drift cannot happen quietly again.
#
# Usage:  ./scripts/verify-design.sh
# Exit:   0 = design rules hold, non-zero = violations (or drift).

set -euo pipefail

cd "$(dirname "$0")/.."
REPO_ROOT="$(pwd)"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "error: xcodegen not installed. Run: brew install xcodegen" >&2
  exit 2
fi

echo "==> Regenerating the Xcode project from project.yml"
xcodegen generate >/dev/null

# If regeneration changes the tracked pbxproj, someone hand-edited it. That is
# how the design layer went orphaned last time.
if ! git diff --quiet -- pikicam.xcodeproj/project.pbxproj; then
  echo "error: project.pbxproj drifted from project.yml." >&2
  echo "       Edit project.yml and regenerate; never hand-edit the pbxproj." >&2
  git --no-pager diff --stat -- pikicam.xcodeproj/project.pbxproj >&2
  exit 3
fi

# The design files must be in a real target. Zero mentions means orphaned.
for f in Room.swift ControlIDRegistry.swift; do
  if ! grep -q "$f" pikicam.xcodeproj/project.pbxproj; then
    echo "error: $f is in no Xcode target — the design layer is inert again." >&2
    exit 4
  fi
done
if ! grep -q "DesignLintTests.swift" pikicam.xcodeproj/project.pbxproj; then
  echo "error: DesignLintTests.swift is in no target — the lint cannot run." >&2
  exit 4
fi

DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 17}"
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

echo "==> Running the design lint ($DESTINATION)"
set +e
xcodebuild test \
  -project pikicam.xcodeproj \
  -scheme pikicam \
  -destination "$DESTINATION" \
  -only-testing:pikicamTests/DesignLintTests \
  > "$LOG" 2>&1
STATUS=$?
set -e

EXECUTED="$(grep -oE 'Executed [0-9]+ tests?' "$LOG" | head -1 || true)"
echo "==> ${EXECUTED:-no tests executed}"

# Zero executed tests is NOT a pass — that was the original false green.
if [ -z "$EXECUTED" ] || [ "$EXECUTED" = "Executed 0 tests" ]; then
  echo "error: the design lint executed zero tests. A green suite here is a lie." >&2
  exit 5
fi

if [ "$STATUS" -ne 0 ]; then
  echo
  echo "Design violations:" >&2
  grep '^  • ' "$LOG" | sort -u >&2 || true
  exit "$STATUS"
fi

echo "==> Design rules hold."