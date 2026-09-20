#!/usr/bin/env bash
#
# Dev "refresh" loop: build -> install -> relaunch in one step. The closest
# thing to Expo's reload for this native app -- run it after editing and you get
# the new build running a few seconds later.
#
#   ./refresh.sh                       # simulator (default)
#   SIM="iPhone 17 Pro" ./refresh.sh   # a different simulator
#   PHONE=1 ./refresh.sh               # a real iPhone over USB
#   PHONE=1 DEVICE="Edward's iPhone" ./refresh.sh  # pick one of several devices
#
# PHONE=1 needs DEVELOPMENT_TEAM set in Secrets.xcconfig. A free "Personal Team"
# ID is fine here and needs no paid enrollment -- builds just expire after 7
# days. Do NOT run appstore/ship.sh with a personal team; that path wants the
# real Denova LLC team.
#
# Fails fast: if the build breaks, it stops and never relaunches a stale app.
set -euo pipefail

SCHEME="TickleMyPickle"
BUNDLE_ID="com.punchjay.ticklemypickle"
DERIVED="build"

cd "$(dirname "$0")"

BUILD_LOG="$(mktemp -t tmp-build)"
DEVICE_JSON=""
trap 'rm -f "$BUILD_LOG" "$DEVICE_JSON"' EXIT

# Trust xcodebuild's exit status, not the presence of a .app -- a stale bundle
# from an earlier run would otherwise sail through and get installed.
build_ok() {
  local rc="$1"
  if [[ "$rc" -eq 0 && -d "$APP_PATH" ]]; then
    if [[ "${PHONE:-0}" == "1" && ! -d "$APP_PATH/_CodeSignature" ]]; then
      echo "error: $APP_PATH is unsigned -- refusing to install it." >&2
      exit 1
    fi
    return 0
  fi
  echo >&2
  echo "error: build failed -- nothing was installed." >&2
  if grep -q errSecInternalComponent "$BUILD_LOG"; then
    cat >&2 <<'MSG'

codesign could not use your signing key (errSecInternalComponent). The keychain
needs to grant access once, from the GUI:

  Open TickleMyPickle.xcodeproj in Xcode, pick the iPhone in the toolbar's
  device menu, and hit Run. macOS prompts to use the signing key -- click
  "Always Allow" (not "Allow"). After that this script works on its own.
MSG
  else
    grep -E ": (error|warning): |error:" "$BUILD_LOG" | tail -15 >&2
  fi
  exit 1
}

if [[ "${PHONE:-0}" != "1" ]]; then
  # ---------- simulator ----------
  SIM="${SIM:-iPhone 17}"
  APP_PATH="$DERIVED/Build/Products/Debug-iphonesimulator/$SCHEME.app"

  echo "==> Building $SCHEME for the simulator (this is the slow part)..."
  rm -rf "$APP_PATH"
  set +e
  xcodebuild -project "$SCHEME.xcodeproj" -scheme "$SCHEME" -configuration Debug \
    -destination "platform=iOS Simulator,name=$SIM,OS=latest" \
    -derivedDataPath "$DERIVED" build 2>&1 \
    | tee "$BUILD_LOG" | grep -E ": (warning|error):|BUILD (SUCCEEDED|FAILED)"
  build_ok "${PIPESTATUS[0]}"
  set -e

  echo "==> Booting $SIM if needed..."
  xcrun simctl boot "$SIM" 2>/dev/null || true
  xcrun simctl bootstatus "$SIM" -b >/dev/null

  echo "==> Installing..."
  xcrun simctl install booted "$APP_PATH"

  # A fresh/erased sim has no GPS and no location permission, so the app's
  # CLLocationManager fails with "couldn't get your location" every time.
  # Grant it and seed a fixed location (Crested Butte, CO -- matches the
  # sample court data) so the simulator behaves like a real device would.
  echo "==> Granting location permission + seeding a GPS fix..."
  xcrun simctl privacy booted grant location "$BUNDLE_ID"
  xcrun simctl location booted set 38.8697,-106.9878

  echo "==> Relaunching (terminate + launch)..."
  xcrun simctl terminate booted "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch booted "$BUNDLE_ID"

  # Xcode 26+ folded the standalone Simulator.app into DeviceHub -- "open -a
  # Simulator" no longer resolves, so target it by bundle ID instead.
  open -b com.apple.dt.Devices
  echo "==> Done."
  exit 0
fi

# ---------- real device ----------
APP_PATH="$DERIVED/Build/Products/Debug-iphoneos/$SCHEME.app"

TEAM_ID="$(sed -n 's|^ *DEVELOPMENT_TEAM *= *||p' Secrets.xcconfig | head -1)"
if [[ -z "$TEAM_ID" || "$TEAM_ID" == X* ]]; then
  cat >&2 <<'MSG'
error: no DEVELOPMENT_TEAM in Secrets.xcconfig -- a device build can't be signed.

For free provisioning (no $99 enrollment):
  1. Xcode > Settings > Accounts > + > Apple ID, sign in with a personal Apple ID.
  2. The row that appears shows a "Personal Team" with a 10-character Team ID.
  3. Put it in Secrets.xcconfig:   DEVELOPMENT_TEAM = XXXXXXXXXX
Builds signed this way stop launching after 7 days; just re-run this script.
MSG
  exit 1
fi

echo "==> Looking for a connected device..."
DEVICE_JSON="$(mktemp -t tmp-devices)"
xcrun devicectl list devices --json-output "$DEVICE_JSON" >/dev/null 2>&1 || true

DEV_INFO=$(DEVICE="${DEVICE:-}" python3 - "$DEVICE_JSON" <<'PYEOF'
import json, os, sys
try:
    devices = json.load(open(sys.argv[1]))["result"]["devices"]
except Exception:
    devices = []

wanted = os.environ.get("DEVICE", "").strip()
matches = []
for d in devices:
    props = d.get("deviceProperties", {})
    hw = d.get("hardwareProperties", {})
    name = props.get("name", "?")
    # devicectl addresses the device by CoreDevice UUID, while the xcodebuild
    # -destination flag wants the hardware UDID. They are different strings.
    core_id, build_udid = d.get("identifier", ""), hw.get("udid", "")
    if not core_id or not build_udid:
        continue
    if wanted and wanted.lower() not in name.lower() and wanted not in (core_id, build_udid):
        continue
    matches.append((core_id, build_udid, props.get("developerModeStatus", "unknown"), name))

if len(matches) == 1:
    print(*matches[0])
else:
    if matches:
        sys.stderr.write("Several devices matched -- set DEVICE= to pick one:\n")
        for _, _, _, name in matches:
            sys.stderr.write("  " + name + "\n")
    print("", "", "", "")
PYEOF
)
read -r CORE_ID BUILD_UDID DEVMODE DEVNAME <<<"$DEV_INFO"

if [[ -z "$CORE_ID" ]]; then
  cat >&2 <<'MSG'
error: no iPhone found.

  - Plug it in over USB and unlock it.
  - The first time, tap "Trust This Computer" on the phone and enter its passcode.
  - Check it shows up:  xcrun devicectl list devices
MSG
  exit 1
fi

if [[ "$DEVMODE" != "enabled" ]]; then
  cat >&2 <<MSG
error: Developer Mode is $DEVMODE on $DEVNAME, so it can't run your own builds.

On the phone: Settings > Privacy & Security > Developer Mode > on. It asks to
restart; after the reboot, unlock and confirm "Turn On". Then re-run this.
MSG
  exit 1
fi

echo "==> Building $SCHEME for $DEVNAME (team $TEAM_ID)..."
rm -rf "$APP_PATH"
set +e
xcodebuild -project "$SCHEME.xcodeproj" -scheme "$SCHEME" -configuration Debug \
  -destination "platform=iOS,id=$BUILD_UDID" \
  -derivedDataPath "$DERIVED" -allowProvisioningUpdates build 2>&1 \
  | tee "$BUILD_LOG" | grep -E ": (warning|error):|BUILD (SUCCEEDED|FAILED)"
build_ok "${PIPESTATUS[0]}"
set -e

echo "==> Installing to $DEVNAME..."
xcrun devicectl device install app --device "$CORE_ID" "$APP_PATH"

echo "==> Launching..."
if ! xcrun devicectl device process launch --device "$CORE_ID" "$BUNDLE_ID"; then
  cat >&2 <<'MSG'

The app installed but wouldn't launch. With a personal team this is almost
always the untrusted-developer prompt: on the phone go to
Settings > General > VPN & Device Management, tap your Apple ID, and Trust it.
Then launch the app from the home screen.
MSG
  exit 1
fi
echo "==> Done."
