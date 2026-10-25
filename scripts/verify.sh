#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== xcodegen =="
xcodegen generate

UDID=$(xcrun devicectl list devices 2>/dev/null \
  | grep -E "available \\(paired" \
  | grep -oE "[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}" \
  | head -1)
if [ -z "$UDID" ]; then
  echo "FAIL: no available paired iPhone (connect + unlock)"; exit 1
fi
echo "device: $UDID"

echo "== build =="
xcodebuild -project pikicam.xcodeproj -scheme pikicam \
  -destination "platform=iOS,id=$UDID" \
  -derivedDataPath build/dd -allowProvisioningUpdates \
  DEVELOPMENT_TEAM=V7BF8622ZR build-for-testing

echo "== device suite (real pipeline) =="
run_suite() {
  rm -rf build/dd/results.xcresult
  set +e
  xcodebuild -project pikicam.xcodeproj -scheme pikicam \
    -destination "platform=iOS,id=$UDID" \
    -derivedDataPath build/dd -allowProvisioningUpdates \
    DEVELOPMENT_TEAM=V7BF8622ZR \
    -resultBundlePath build/dd/results.xcresult \
    test-without-building 2>&1 | tee build/dd/test.log | \
    grep -E "Test case .* (passed|failed)|TEST (FAILED|EXECUTE)" | tail -10
  STATUS=${PIPESTATUS[0]}
  set -e
}

run_suite
if [ "$STATUS" -ne 0 ]; then
  if grep -qE "Timed out while enabling automation|failed to initialize for UI testing|not trusted|Failed to create a bundle instance|Failure collecting diagnostics|Lost pending connection|Device error" build/dd/test.log; then
    echo "RUNNER FLAKE detected (automation init) — one labeled retry"
    sleep 45
    run_suite
  fi
fi
[ "$STATUS" -eq 0 ] || { echo "FAIL: suite red (app failure, not runner flake)"; exit 1; }
grep -qE "Test [Cc]ase .* passed" build/dd/test.log || { echo "FAIL: zero tests"; exit 1; }

echo "== lint =="
swiftlint lint --strict --quiet

echo "verify.sh OK"
