#!/bin/zsh
# Captures App Store screenshots on a 6.9" iPhone and a 13" iPad simulator.
#
# Usage:
#   release/screenshots.sh
#   IPHONE_SIM="iPhone 18 Pro Max" IPAD_SIM="iPad Pro 13-inch (M5)" release/screenshots.sh
#   IPHONE_SIM=skip release/screenshots.sh     # iPad only (IPAD_SIM=skip for iPhone only)
#
# Each run erases the two simulators, stages generated sample photos in the app's
# share inbox (imported on unlock), sets a clean 9:41 status bar, and runs
# AppStoreScreenshotTests. PNGs land in release/screenshots/{iphone-6.9,ipad-13}.

set -euo pipefail

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:$PATH"

cd "$(dirname "$0")/.."

PROJECT="Keepshire.xcodeproj"
SCHEME="Keepshire"
IPHONE_SIM="${IPHONE_SIM:-iPhone 18 Pro Max}"
IPAD_SIM="${IPAD_SIM:-iPad Pro 13-inch (M5)}"
DERIVED_DATA="build/DerivedData"
MEDIA="build/screenshot-media"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

# Newest available simulator with this exact name.
udid_for() {
  xcrun simctl list devices available --json | python3 -c '
import json, sys
name = sys.argv[1]
runtimes = json.load(sys.stdin)["devices"]
matches = [(rt, d["udid"]) for rt, ds in runtimes.items() if "iOS" in rt for d in ds if d["name"] == name]
def version(rt):
    return [int(p) for p in rt.rsplit("iOS-", 1)[1].split("-")]
print(sorted(matches, key=lambda m: version(m[0]))[-1][1] if matches else "")
' "$1"
}

log "Generating sample photos"
rm -rf "$MEDIA" && mkdir -p "$MEDIA"
swift release/tools/sample-photos.swift "$MEDIA"

log "Building for testing"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "generic/platform=iOS Simulator" \
  -derivedDataPath "$DERIVED_DATA" \
  -quiet \
  build-for-testing

capture() {
  local name="$1" folder="$2"
  [[ "$name" == "skip" ]] && return
  local udid
  udid="$(udid_for "$name")"
  if [[ -z "$udid" ]]; then
    log "No simulator named '$name'. Create it in Xcode → Window → Devices and Simulators."
    exit 1
  fi

  local out="$PWD/release/screenshots/$folder"
  rm -rf "$out" && mkdir -p "$out"

  log "Preparing $name ($udid)"
  xcrun simctl shutdown "$udid" 2>/dev/null || true
  # erase fails while the simulator is still shutting down.
  until xcrun simctl list devices | grep "$udid" | grep -q "(Shutdown)"; do sleep 1; done
  xcrun simctl erase "$udid"
  xcrun simctl boot "$udid"
  xcrun simctl bootstatus "$udid" -b >/dev/null
  # Stage the photos in the share inbox; the app imports them on unlock.
  xcrun simctl install "$udid" "$DERIVED_DATA/Build/Products/Debug-iphonesimulator/Keepshire.app"
  local group
  group="$(xcrun simctl get_app_container "$udid" dev.haresh.keepshire group.dev.haresh.keepshire)"
  mkdir -p "$group/Inbox/screenshots"
  cp "$MEDIA"/*.jpg "$group/Inbox/screenshots/"
  xcrun simctl status_bar "$udid" override \
    --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 \
    --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100

  log "Capturing on $name"
  TEST_RUNNER_SCREENSHOT_DIR="$out" xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "id=$udid" \
    -derivedDataPath "$DERIVED_DATA" \
    -only-testing:KeepshireUITests/AppStoreScreenshotTests \
    -parallel-testing-enabled NO \
    test-without-building

  xcrun simctl status_bar "$udid" clear
  log "Saved $(ls "$out" | wc -l | tr -d ' ') screenshots to $out"
}

capture "$IPHONE_SIM" iphone-6.9
capture "$IPAD_SIM" ipad-13

log "Done"
