#!/usr/bin/env bash
#
# App Store "ship" pipeline: archive -> export IPA -> (optionally) upload.
# The release counterpart to refresh.sh -- run it when a build should go to
# App Store Connect / TestFlight rather than the simulator.
#
#   ./appstore/ship.sh             # archive + export IPA to build/export/
#   UPLOAD=1 ./appstore/ship.sh    # same, but upload to App Store Connect
#
# Prereqs:
#   - DEVELOPMENT_TEAM in Secrets.xcconfig set to the Denova LLC team (post-
#     enrollment) -- a free Personal Team is rejected up front
#   - Signed into Xcode with the Denova LLC Apple ID (Settings > Accounts),
#     so -allowProvisioningUpdates can mint certs/profiles on first run
#   - A real GOOGLE_MAPS_REST_API_KEY in Secrets.xcconfig -- without it the
#     app ships with search disabled, an instant App Review rejection
#
# Fails fast: any broken step stops the pipeline before upload.
set -euo pipefail

SCHEME="TickleMyPickle"
ARCHIVE="build/$SCHEME.xcarchive"
EXPORT_DIR="build/export"
EXPORT_PLIST="build/ExportOptions.plist"

cd "$(dirname "$0")/.."

# Mirrors Config.hasApiKey: empty or the .example placeholder means "no key",
# and the app would launch with search disabled and a developer-facing error.
is_placeholder_key() { [[ -z "$1" || "$1" == "YOUR_KEY_HERE" ]]; }

API_KEY="$(sed -n 's/^ *GOOGLE_MAPS_REST_API_KEY *= *//p' Secrets.xcconfig | head -1)"
if is_placeholder_key "$API_KEY"; then
  echo "error: no real GOOGLE_MAPS_REST_API_KEY in Secrets.xcconfig." >&2
  echo "A build without it ships with search disabled -- refusing to archive." >&2
  exit 1
fi

TEAM_ID="$(sed -n 's/^ *DEVELOPMENT_TEAM *= *//p' Secrets.xcconfig | head -1)"
if [[ -z "$TEAM_ID" || "$TEAM_ID" == X* ]]; then
  echo "error: no DEVELOPMENT_TEAM in Secrets.xcconfig yet." >&2
  echo "Once the Apple Developer enrollment clears, grab the 10-char Team ID" >&2
  echo "from developer.apple.com/account and uncomment the line. Until then" >&2
  echo "there is nothing to sign with -- this script can't run." >&2
  exit 1
fi

# refresh.sh is happy with a free Personal Team for on-device builds, but App
# Store distribution needs the paid Denova LLC team. Xcode records which of its
# signed-in teams are free, so check that instead of letting the archive run
# and fail late with a confusing provisioning error.
IS_FREE_TEAM=$(defaults export com.apple.dt.Xcode - 2>/dev/null | TEAM_ID="$TEAM_ID" python3 -c '
import os, plistlib, sys
try:
    accounts = plistlib.loads(sys.stdin.buffer.read()).get("IDEProvisioningTeamByIdentifier", {})
except Exception:
    accounts = {}
teams = [t for ts in accounts.values() for t in ts if t.get("teamID") == os.environ["TEAM_ID"]]
print("1" if any(t.get("isFreeProvisioningTeam") for t in teams) else "0")
' 2>/dev/null || echo 0)
if [[ "$IS_FREE_TEAM" == "1" ]]; then
  echo "error: DEVELOPMENT_TEAM $TEAM_ID is a free Personal Team -- it can sign" >&2
  echo "on-device dev builds (refresh.sh) but can't ship to the App Store." >&2
  echo "Replace it in Secrets.xcconfig with the Denova LLC Team ID from" >&2
  echo "developer.apple.com/account > Membership Details." >&2
  exit 1
fi

echo "==> Archiving $SCHEME (Release, team $TEAM_ID)..."
# Clear any earlier archive so a failed run can't pass the checks below on a
# stale one.
rm -rf "$ARCHIVE"
xcodebuild archive -project "$SCHEME.xcodeproj" -scheme "$SCHEME" -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  | grep -E ": (warning|error):|ARCHIVE (SUCCEEDED|FAILED)" || true
[[ -d "$ARCHIVE" ]] || { echo "error: archive failed (no $ARCHIVE)" >&2; exit 1; }

# Check the key in what actually ships, not just the xcconfig: a broken
# $(GOOGLE_MAPS_REST_API_KEY) substitution would otherwise slip through.
# PlistBuddy prints some errors (e.g. a missing file) to stdout, so only trust
# its output when it succeeds.
BUILT_KEY="$(/usr/libexec/PlistBuddy -c 'Print :GoogleMapsRestAPIKey' \
  "$ARCHIVE/Products/Applications/$SCHEME.app/Info.plist" 2>/dev/null)" || BUILT_KEY=""
if is_placeholder_key "$BUILT_KEY"; then
  echo "error: the archived app has no real GoogleMapsRestAPIKey in its Info.plist." >&2
  echo "It would ship with search disabled -- stopping before export/upload." >&2
  exit 1
fi

echo "==> Preparing export options..."
cp appstore/ExportOptions.plist "$EXPORT_PLIST"
plutil -replace teamID -string "$TEAM_ID" "$EXPORT_PLIST"
if [[ "${UPLOAD:-0}" == "1" ]]; then
  plutil -replace destination -string upload "$EXPORT_PLIST"
  echo "==> Exporting and UPLOADING to App Store Connect..."
else
  echo "==> Exporting IPA to $EXPORT_DIR (set UPLOAD=1 to send to App Store Connect)..."
fi

xcodebuild -exportArchive -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$EXPORT_PLIST" -exportPath "$EXPORT_DIR" \
  -allowProvisioningUpdates

echo "==> Done."
