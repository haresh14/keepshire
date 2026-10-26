#!/bin/zsh
# Records App Store app preview videos on a 6.9" iPhone and a 13" iPad simulator.
#
# Usage:
#   release/app-preview.sh
#   IPHONE_SIM=skip release/app-preview.sh     # iPad only (IPAD_SIM=skip for iPhone only)
#
# Each run erases the simulator, stages the sample photos, records the screen while
# AppStoreScreenshotTests.testRecordAppPreview plays the tour, then cuts and encodes
# the tour to App Store app preview specs: H.264 High@4.0, 30 fps, 11 Mbps CBR (.mov),
# silent 256 kbps stereo AAC, 15–30 seconds. Output: release/assets/app-preview/.

set -euo pipefail

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:$PATH"

cd "$(dirname "$0")/.."

PROJECT="Keepshire.xcodeproj"
SCHEME="Keepshire"
IPHONE_SIM="${IPHONE_SIM:-iPhone 18 Pro Max}"
IPAD_SIM="${IPAD_SIM:-iPad Pro 13-inch (M5)}"
DERIVED_DATA="build/DerivedData"
MEDIA="build/screenshot-media"
WORK="build/app-preview"
OUT="release/assets/app-preview"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
now() { python3 -c 'import time; print(f"{time.time():.3f}")'; }

command -v ffmpeg >/dev/null || { log "ffmpeg is required (brew install ffmpeg)"; exit 1; }

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

mkdir -p "$OUT"

record() {
  local name="$1" label="$2" size="$3"
  [[ "$name" == "skip" ]] && return
  local udid
  udid="$(udid_for "$name")"
  if [[ -z "$udid" ]]; then
    log "No simulator named '$name'. Create it in Xcode → Window → Devices and Simulators."
    exit 1
  fi

  local work="$PWD/$WORK/$label"
  rm -rf "$work" && mkdir -p "$work"

  log "Preparing $name ($udid)"
  xcrun simctl shutdown "$udid" 2>/dev/null || true
  # erase fails while the simulator is still shutting down.
  until xcrun simctl list devices | grep "$udid" | grep -q "(Shutdown)"; do sleep 1; done
  xcrun simctl erase "$udid"
  xcrun simctl boot "$udid"
  xcrun simctl bootstatus "$udid" -b >/dev/null
  xcrun simctl install "$udid" "$DERIVED_DATA/Build/Products/Debug-iphonesimulator/Keepshire.app"
  local group
  group="$(xcrun simctl get_app_container "$udid" dev.haresh.keepshire group.dev.haresh.keepshire)"
  mkdir -p "$group/Inbox/screenshots"
  cp "$MEDIA"/*.jpg "$group/Inbox/screenshots/"
  xcrun simctl status_bar "$udid" override \
    --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 \
    --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100

  log "Recording on $name"
  xcrun simctl io "$udid" recordVideo --codec=h264 --force "$work/raw.mov" 2>/dev/null &
  local recorder=$!
  local recording_start
  recording_start="$(now)"
  echo "$recording_start" > "$work/recording-start.txt"
  TEST_RUNNER_SCREENSHOT_DIR="$work" TEST_RUNNER_APP_PREVIEW=1 xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "id=$udid" \
    -derivedDataPath "$DERIVED_DATA" \
    -only-testing:KeepshireUITests/AppStoreScreenshotTests/testRecordAppPreview \
    -parallel-testing-enabled NO \
    -quiet \
    test-without-building || { kill -INT $recorder; wait $recorder || true; exit 1; }
  kill -INT $recorder
  wait $recorder || true
  xcrun simctl status_bar "$udid" clear

  local start end duration
  start="$(python3 -c "print(f'{float(open(\"$work/preview-start.txt\").read()) - $recording_start:.3f}')")"
  end="$(python3 -c "print(f'{float(open(\"$work/preview-end.txt\").read()) - $recording_start:.3f}')")"
  duration="$(python3 -c "print(f'{$end - $start:.3f}')")"
  if ! python3 -c "import sys; sys.exit(0 if 15 <= $duration <= 30 else 1)"; then
    log "Tour took ${duration}s; App Store previews must be 15–30 s. Adjust testRecordAppPreview."
    exit 1
  fi

  local width="${size%x*}" height="${size#*x}" fade_out
  fade_out="$(python3 -c "print(f'{$duration - 0.4:.3f}')")"
  log "Encoding ${duration}s at $size"
  # Fades through black at both ends so the autoplay loop has no visible jump.
  ffmpeg -loglevel error -y \
    -ss "$start" -t "$duration" -i "$work/raw.mov" \
    -f lavfi -t "$duration" -i "anullsrc=channel_layout=stereo:sample_rate=48000" \
    -vf "scale=${width}:-2:flags=lanczos,crop=${width}:${height},fps=30,format=yuv420p,fade=t=in:st=0:d=0.4,fade=t=out:st=${fade_out}:d=0.4" \
    -c:v libx264 -profile:v high -level:v 4.0 -b:v 11M -minrate 11M -maxrate 11M -bufsize 11M -x264-params nal-hrd=cbr:filler=1 \
    -c:a aac -b:a 256k -ar 48000 -ac 2 \
    -movflags +faststart -shortest \
    "$OUT/$label.mov"
  log "Saved $OUT/$label.mov"
}

record "$IPHONE_SIM" iphone-6.9 886x1920
record "$IPAD_SIM" ipad-13 1200x1600

log "Done"
