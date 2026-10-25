#!/bin/bash
set -u
cd "$(dirname "$0")/.."
CYCLES="${1:-10}"
UDID=$(xcrun devicectl list devices 2>/dev/null \
  | grep -E "available \(paired" \
  | grep -oE "[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}" \
  | head -1)
[ -z "$UDID" ] && { echo "FAIL: no paired device"; exit 1; }

GREEN=0; FLAKE=0; RED=0
for cycle in $(seq 1 "$CYCLES"); do
  rm -rf build/dd/results.xcresult
  xcodebuild -project pikicam.xcodeproj -scheme pikicam \
    -destination "platform=iOS,id=$UDID" \
    -derivedDataPath build/dd -allowProvisioningUpdates \
    DEVELOPMENT_TEAM=V7BF8622ZR \
    -only-testing:pikicamUITests/WalkSmokeUITests \
    test-without-building > build/dd/cycle.log 2>&1
  cp build/dd/cycle.log build/dd/cycle-$cycle.log
  if grep -q "TEST EXECUTE SUCCEEDED" build/dd/cycle.log; then
    GREEN=$((GREEN+1)); echo "cycle $cycle: GREEN ($GREEN/$cycle)"
  elif grep -qE "Timed out while enabling automation|Failed to establish communication|Lost pending connection|not trusted|Failure collecting diagnostics|Device error" build/dd/cycle.log; then
    FLAKE=$((FLAKE+1)); echo "cycle $cycle: RUNNER-FLAKE ($FLAKE flakes)"
    sleep 45
  else
    RED=$((RED+1)); echo "cycle $cycle: RED — app failure"; 
    grep -E "error: -\[" build/dd/cycle.log | head -2
  fi
done
echo "STREAK: $GREEN/$CYCLES green, $FLAKE runner-flakes, $RED app failures"
[ "$RED" -eq 0 ]
