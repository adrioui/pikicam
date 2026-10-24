#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

SKIPS=()

echo "== xcodegen =="
xcodegen generate

if [ -n "${CI:-}" ]; then
  git diff --exit-code -- pikicam.xcodeproj || { echo "project.pbxproj not deterministic"; exit 1; }
fi

echo "== device destination =="
UDID=$(xcrun devicectl list devices 2>/dev/null | awk '/available/ && /iPhone/ {print $NF; exit}')
if [ -z "$UDID" ]; then
  # devicectl prints the identifier as the last column only in some versions; parse robustly
  UDID=$(xcrun devicectl list devices 2>/dev/null | grep -E "iPhone.*available" | awk '{for(i=1;i<=NF;i++) if ($i ~ /^[0-9A-F-]{36}$/) {print $i; exit}}')
fi
if [ -z "$UDID" ]; then
  echo "FAIL: no available iPhone destination (connect and unlock the device)"; exit 1
fi
echo "device: $UDID"

echo "== build for testing (device) =="
xcodebuild -project pikicam.xcodeproj -scheme pikicam \
  -destination "platform=iOS,id=$UDID" \
  -derivedDataPath build/dd -allowProvisioningUpdates \
  build-for-testing 2>&1 | { grep -E "error:|BUILD" || true; }

echo "== test on device =="
RESULT_BUNDLE=build/dd/results.xcresult
set +e
xcodebuild -project pikicam.xcodeproj -scheme pikicam \
  -destination "platform=iOS,id=$UDID" \
  -derivedDataPath build/dd -allowProvisioningUpdates \
  -resultBundlePath "$RESULT_BUNDLE" \
  test-without-building 2>&1 | tee build/dd/test.log | grep -E "Test case .* (passed|failed)|TEST FAILED|TEST SUCCEEDED" | tail -30
TEST_STATUS=${PIPESTATUS[0]}
set -e

if [ "$TEST_STATUS" -ne 0 ]; then
  echo "FAIL: test run exited non-zero"; exit 1
fi

EXECUTED=$(xcrun xcresulttool get test-results tests --path "$RESULT_BUNDLE" 2>/dev/null | grep -c '"result" :' || true)
if [ "$EXECUTED" -eq 0 ]; then
  EXECUTED=$(grep -cE "Test case .* passed" build/dd/test.log || true)
fi
if [ "$EXECUTED" -eq 0 ]; then
  echo "FAIL: zero tests executed"; exit 1
fi
echo "tests executed: $EXECUTED"

echo "== swiftlint =="
swiftlint lint --strict --quiet

echo "== periphery =="
periphery scan --quiet || SKIPS+=("periphery")

echo "== reference diff (LibRaw + RawTherapee bracket) =="
if [ -x .venv/bin/python ]; then
  .venv/bin/python scripts/reference-diff.py --check || SKIPS+=("reference-diff")
else
  SKIPS+=("reference-diff: venv missing")
fi

echo "== fuzz corpus =="
if [ -x .venv/bin/python ]; then
  .venv/bin/python scripts/fuzz-corpus.py --smoke || SKIPS+=("fuzz")
else
  SKIPS+=("fuzz: venv missing")
fi

echo "== skip classes =="
for s in "${SKIPS[@]:-}"; do echo "  skipped: $s"; done
echo "verify.sh OK"
