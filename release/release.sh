#!/bin/zsh
# Archives Keepshire (Release) and exports or uploads it for App Store Connect.
#
# Usage:
#   release/release.sh <version> <build>             # test, archive, export .ipa
#   release/release.sh <version> <build> --upload    # test, archive, upload to App Store Connect
#   SKIP_TESTS=1 release/release.sh 1.0 1             # skip the unit tests
#
# <version> is the marketing version (CFBundleShortVersionString, e.g. 1.0).
# <build> is the build number (CFBundleVersion); it must be higher than every
# build already uploaded for that version.
#
# --upload uses the Apple ID signed in under Xcode → Settings → Accounts, or an
# App Store Connect API key when ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_PATH are set.

set -euo pipefail

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:$PATH"

cd "$(dirname "$0")/.."

PROJECT="Keepshire.xcodeproj"
SCHEME="Keepshire"
TEST_DESTINATION="${TEST_DESTINATION:-platform=iOS Simulator,name=iPhone 16 Pro}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

if [[ $# -lt 2 ]]; then
  echo "Usage: release/release.sh <version> <build> [--upload]"
  exit 1
fi

VERSION="$1"
BUILD="$2"
UPLOAD="${3:-}"

if [[ ! "$VERSION" =~ '^[0-9]+(\.[0-9]+){1,2}$' ]]; then
  log "Version must look like 1.0 or 1.0.1 (got '$VERSION')"
  exit 1
fi
if [[ ! "$BUILD" =~ '^[0-9]+(\.[0-9]+){0,2}$' ]]; then
  log "Build must be numeric, like 1 or 12 (got '$BUILD')"
  exit 1
fi

OUTPUT="build/release/$VERSION-$BUILD"
ARCHIVE="$OUTPUT/Keepshire.xcarchive"
EXPORT_OPTIONS="$OUTPUT/ExportOptions.plist"
mkdir -p "$OUTPUT"

if [[ -z "${SKIP_TESTS:-}" ]]; then
  log "Running unit tests on $TEST_DESTINATION"
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "$TEST_DESTINATION" \
    -derivedDataPath build/DerivedData \
    -parallel-testing-enabled NO \
    -only-testing:KeepshireTests \
    -quiet \
    test
fi

# Version and build apply to the app and the share extension, which must match.
log "Archiving $SCHEME $VERSION ($BUILD)"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  -quiet \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD" \
  archive

cp release/ExportOptions.plist "$EXPORT_OPTIONS"
if [[ "$UPLOAD" == "--upload" ]]; then
  /usr/libexec/PlistBuddy -c "Set :destination upload" "$EXPORT_OPTIONS"
fi

AUTH_ARGS=()
if [[ -n "${ASC_KEY_ID:-}" && -n "${ASC_ISSUER_ID:-}" && -n "${ASC_KEY_PATH:-}" ]]; then
  AUTH_ARGS=(
    -authenticationKeyID "$ASC_KEY_ID"
    -authenticationKeyIssuerID "$ASC_ISSUER_ID"
    -authenticationKeyPath "$ASC_KEY_PATH"
  )
fi

log "Exporting archive (${UPLOAD:-export only})"
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -exportPath "$OUTPUT/export" \
  -allowProvisioningUpdates \
  "${AUTH_ARGS[@]}"

if [[ "$UPLOAD" == "--upload" ]]; then
  log "Uploaded. Processing in App Store Connect usually takes 5–30 minutes."
else
  log "IPA: $OUTPUT/export/Keepshire.ipa"
  log "Upload it with Transporter, or run again with --upload."
fi

log "Archive: $ARCHIVE (open it from Xcode → Window → Organizer)"
log "Done"
