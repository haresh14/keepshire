#!/bin/zsh
# Builds Keepshire and installs it on a physical iPhone (does not launch it).
#
# Usage:
#   ./install-on-device.sh            # first paired physical iPhone
#   ./install-on-device.sh <UDID>     # a specific device
#   DEVICE_UDID=<UDID> ./install-on-device.sh

set -euo pipefail

# launchd/cron start with a minimal PATH
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:$PATH"

cd "$(dirname "$0")"

PROJECT="Keepshire.xcodeproj"
SCHEME="Keepshire"
CONFIGURATION="Debug"
DERIVED_DATA="build/DerivedData"
APP="$DERIVED_DATA/Build/Products/$CONFIGURATION-iphoneos/Keepshire.app"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

UDID="${1:-${DEVICE_UDID:-}}"
if [[ -z "$UDID" ]]; then
  DEVICES_JSON="$(mktemp -t keepshire-devices)"
  trap 'rm -f "$DEVICES_JSON"' EXIT
  xcrun devicectl list devices --json-output "$DEVICES_JSON" >/dev/null
  # Skip simulators; devicectl lists them too
  UDID="$(python3 -c '
import json, sys
devices = json.load(open(sys.argv[1]))["result"]["devices"]
for d in devices:
    hw = d.get("hardwareProperties", {})
    if hw.get("reality") == "physical" and hw.get("deviceType") == "iPhone" \
            and d.get("connectionProperties", {}).get("pairingState") == "paired":
        print(hw["udid"])
        break
' "$DEVICES_JSON")"
fi

if [[ -z "$UDID" ]]; then
  log "No paired physical iPhone found. Connect it and try again."
  exit 1
fi

log "Building $SCHEME ($CONFIGURATION) for device $UDID"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "id=$UDID" \
  -derivedDataPath "$DERIVED_DATA" \
  -allowProvisioningUpdates \
  -quiet \
  build

log "Installing $APP"
xcrun devicectl device install app --device "$UDID" "$APP"

log "Done"
