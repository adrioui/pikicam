#!/usr/bin/env bash
#
# pikicam verify chain:
#   1. swift-format lint (Xcode toolchain binary, real check)
#   2. SwiftLint --strict           (if installed; SKIP + hint otherwise)
#   3. xcodebuild build             (real build, Apple simulator destination)
#
# Usage:
#   ./scripts/verify.sh             # missing tools are SKIPped with install hints
#   ./scripts/verify.sh --force     # missing tools count as FAIL
#
# Exit: 0 = every enforced stage clean; 1 = any stage reported offenders/failure.

set -u
cd "$(dirname "$0")/.." || exit 2

FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

FAILED=0
step()   { printf '\n==> %s\n' "$1"; }
pass()   { printf '    PASS  %s\n' "$1"; }
skip()   { printf '    SKIP  %s (install with: %s)\n' "$1" "$2"; }
fail()   { printf '    FAIL  %s\n' "$1"; FAILED=1; }

# ---------------------------------------------------------------- 1. format
step "1/3  swift-format lint (pikicam/, config .swift-format)"
if xcrun --find swift-format >/dev/null 2>&1; then
  out=$(xcrun swift-format lint --configuration .swift-format -r pikicam 2>&1)
  rc=$?
  if [ "$rc" -eq 0 ]; then
    pass "swift-format lint"
  else
    fail "swift-format lint"
    printf '%s\n' "$out" | sed -n '1,20p'
  fi
else
  skip "swift-format lint" "Xcode toolchain (xcrun swift-format)"
  [ "$FORCE" = 1 ] && fail "swift-format lint (missing tool)"
fi

# ---------------------------------------------------------------- 2. lint
step "2/3  SwiftLint --strict (config .swiftlint.yml)"
if command -v swiftlint >/dev/null 2>&1; then
  out=$(swiftlint lint --quiet --strict --config .swiftlint.yml 2>&1)
  rc=$?
  if [ "$rc" -eq 0 ]; then
    pass "SwiftLint --strict"
  else
    fail "SwiftLint --strict"
    printf '%s\n' "$out" | sed -n '1,20p'
  fi
else
  skip "SwiftLint --strict" "brew install swiftlint"
  [ "$FORCE" = 1 ] && fail "SwiftLint --strict (missing tool)"
fi

# ---------------------------------------------------------------- 3. build
step "3/3  xcodebuild build (scheme pikicam, iPhone 17 Pro simulator)"
DEST='platform=iOS Simulator,name=iPhone 17 Pro'
if command -v xcbeautify >/dev/null 2>&1; then
  xcodebuild -project pikicam.xcodeproj -scheme pikicam -destination "$DEST" build 2>&1 | xcbeautify | tail -n 10
  rc=${PIPESTATUS[0]}
else
  xcodebuild -project pikicam.xcodeproj -scheme pikicam -destination "$DEST" -quiet build 2>&1 | tail -n 10
  rc=${PIPESTATUS[0]}
fi
if [ "$rc" -eq 0 ]; then pass "xcodebuild build"; else fail "xcodebuild build"; fi

# ---------------------------------------------------------------- summary
echo
if [ "$FAILED" -eq 0 ]; then
  echo "verify: ALL CHECKS PASS"
  exit 0
else
  echo "verify: FAILED — see stage output above (offenders reported by file/line)"
  exit 1
fi
