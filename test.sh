#!/usr/bin/env bash
#
# Run the unit + UI test suite with the simulator UI visible in DeviceHub, so
# you can watch the UI tests actually tap through the app.
#
#   ./test.sh                       # simulator (default: iPhone 17)
#   SIM="iPhone 17 Pro" ./test.sh   # a different simulator
#
# Xcode 26+ folded the standalone Simulator.app into DeviceHub -- opening it
# by bundle ID is what makes the sim window visible during the run.
set -euo pipefail

SCHEME="TickleMyPickle"
SIM="${SIM:-iPhone 17}"

cd "$(dirname "$0")"

echo "==> Booting $SIM if needed..."
xcrun simctl boot "$SIM" 2>/dev/null || true
xcrun simctl bootstatus "$SIM" -b >/dev/null

echo "==> Opening DeviceHub so the simulator UI is visible..."
open -b com.apple.dt.Devices

# The test run reinstalls the app, which drops its location permission, and
# the sim has no GPS fix -- so "Near me" fails with "couldn't get your
# location" afterwards. Restore both on the way out, pass or fail (same setup
# as refresh.sh).
restore_location() {
  echo "==> Restoring location permission + GPS fix..."
  xcrun simctl privacy "$SIM" grant location com.punchjay.ticklemypickle || true
  xcrun simctl location "$SIM" set 38.8697,-106.9878 || true
}
trap restore_location EXIT

xcodebuild -project "$SCHEME.xcodeproj" -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,name=$SIM,OS=latest" test
