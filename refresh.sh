#!/usr/bin/env bash
#
# Dev "refresh" loop: build -> install -> relaunch on the simulator in one step.
# The closest thing to Expo's reload for this native app -- run it after editing
# and you get the new build running in the sim a few seconds later.
#
#   ./refresh.sh            # build + install + launch on the default sim
#   SIM="iPhone 17 Pro" ./refresh.sh   # target a different simulator
#
# Fails fast: if the build breaks, it stops and never relaunches a stale app.
set -euo pipefail

SIM="${SIM:-iPhone 17}"
SCHEME="TickleMyPickle"
BUNDLE_ID="com.punchjay.ticklemypickle"
DERIVED="build"
APP_PATH="$DERIVED/Build/Products/Debug-iphonesimulator/$SCHEME.app"

cd "$(dirname "$0")"

echo "==> Building $SCHEME (this is the slow part)..."
xcodebuild -project "$SCHEME.xcodeproj" -scheme "$SCHEME" -configuration Debug \
  -destination "platform=iOS Simulator,name=$SIM,OS=latest" \
  -derivedDataPath "$DERIVED" build \
  | grep -E ": (warning|error):|BUILD (SUCCEEDED|FAILED)" || true

echo "==> Booting $SIM if needed..."
xcrun simctl boot "$SIM" 2>/dev/null || true
xcrun simctl bootstatus "$SIM" -b >/dev/null

echo "==> Installing..."
xcrun simctl install booted "$APP_PATH"

echo "==> Relaunching (terminate + launch)..."
xcrun simctl terminate booted "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl launch booted "$BUNDLE_ID"

open -a Simulator
echo "==> Done."
