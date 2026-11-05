#!/bin/zsh
# Archives Keepshire (Release) and exports or uploads it for App Store Connect.
#
# Usage:
#   release/release.sh <version> <build>             # test, archive, export .ipa
#   release/release.sh <version> <build> --upload    # test, archive, upload, then tag and save the archive
#   release/release.sh <version> <build> --tag       # tag only, after uploading an .ipa with Transporter
#   SKIP_TESTS=1 release/release.sh 1.0 1             # skip the unit tests
#
# <version> is the marketing version (CFBundleShortVersionString, e.g. 1.0).
# <build> is the build number (CFBundleVersion); it must be higher than every
# build already uploaded for that version.
#
# --upload uses the Apple ID signed in under Xcode → Settings → Accounts, or an
# App Store Connect API key when ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_PATH are set.
#
# After a successful upload, the script tags the commit it built as v<version>-<build>,
# pushes the tag to origin, and copies the archive into Xcode's Archives folder so the
# Organizer keeps its dSYMs for crash reports. An upload therefore needs a clean working
# tree and an unused tag; both are checked before anything is built.

set -euo pipefail

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:$PATH"

cd "$(dirname "$0")/.."

PROJECT="Keepshire.xcodeproj"
SCHEME="Keepshire"
# Newest available iPhone simulator that meets the 18.5 deployment target. A bare
# name like "iPhone 16 Pro" can resolve to an older runtime the app cannot run on.
default_test_destination() {
  xcrun simctl list devices available --json | python3 -c '
import json, sys
runtimes = json.load(sys.stdin)["devices"]
def version(rt):
    return [int(p) for p in rt.rsplit("iOS-", 1)[1].split("-")]
candidates = [(version(rt), d["udid"]) for rt, ds in runtimes.items() if "iOS" in rt
              for d in ds if d["name"].startswith("iPhone") and "Duo" not in d["name"] and version(rt) >= [18, 5]]
print(f"platform=iOS Simulator,id={max(candidates)[1]}" if candidates else "")
'
}
TEST_DESTINATION="${TEST_DESTINATION:-$(default_test_destination)}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

if [[ $# -lt 2 ]]; then
  echo "Usage: release/release.sh <version> <build> [--upload | --tag]"
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

if [[ -n "$UPLOAD" && "$UPLOAD" != "--upload" && "$UPLOAD" != "--tag" ]]; then
  log "Unknown option '$UPLOAD'; use --upload or --tag"
  exit 1
fi

TAG="v$VERSION-$BUILD"

tree_is_clean() {
  [[ -z "$(git status --porcelain --untracked-files=no)" ]]
}

check_tag_unused() {
  if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
    log "Tag $TAG already exists. Use a new build number."
    exit 1
  fi
  if git ls-remote --exit-code --tags origin "refs/tags/$TAG" >/dev/null 2>&1; then
    log "Tag $TAG already exists on origin. Use a new build number."
    exit 1
  fi
}

# A failed push does not undo an upload, so it warns with the command to retry.
tag_release() {
  local commit="$1"
  git tag -a "$TAG" "$commit" -m "Keepshire $VERSION ($BUILD) – App Store build"
  log "Tagged $(git rev-parse --short "$commit") as $TAG"
  if git push origin "$TAG"; then
    log "Pushed $TAG to origin"
  else
    log "Could not push $TAG. Retry with: git push origin $TAG"
  fi
}

OUTPUT="build/release/$VERSION-$BUILD"
# Written only for a build from a clean tree, so --tag can name exactly what was exported.
COMMIT_RECORD="$OUTPUT/commit"

if [[ "$UPLOAD" == "--tag" ]]; then
  if [[ ! -f "$COMMIT_RECORD" ]]; then
    log "No clean build of $VERSION ($BUILD) to tag. Export it from a clean working tree first."
    exit 1
  fi
  check_tag_unused
  tag_release "$(cat "$COMMIT_RECORD")"
  log "Done"
  exit 0
fi

# The tag must name the exact source of the build, so an upload needs a clean tree.
if [[ "$UPLOAD" == "--upload" ]]; then
  if ! tree_is_clean; then
    log "Commit or stash your changes first: the release tag must match the built source."
    exit 1
  fi
  check_tag_unused
fi
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$BRANCH" != "main" ]]; then
  log "Note: building from '$BRANCH', not main."
fi
RELEASE_COMMIT="$(git rev-parse HEAD)"
TREE_WAS_CLEAN=""
tree_is_clean && TREE_WAS_CLEAN=1
ARCHIVE="$OUTPUT/Keepshire.xcarchive"
EXPORT_OPTIONS="$OUTPUT/ExportOptions.plist"
mkdir -p "$OUTPUT"
rm -f "$COMMIT_RECORD"

if [[ -z "${SKIP_TESTS:-}" ]]; then
  log "Running unit tests on $TEST_DESTINATION"
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "$TEST_DESTINATION" \
    -derivedDataPath build/DerivedData \
    -parallel-testing-enabled NO \
    -retry-tests-on-failure \
    -test-iterations 3 \
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
  tag_release "$RELEASE_COMMIT"

  # build/ is git-ignored and easy to delete; the Organizer copy keeps the dSYMs.
  SAVED_ARCHIVE="$HOME/Library/Developer/Xcode/Archives/$(date '+%Y-%m-%d')/Keepshire $VERSION ($BUILD).xcarchive"
  mkdir -p "$(dirname "$SAVED_ARCHIVE")"
  ditto "$ARCHIVE" "$SAVED_ARCHIVE"
  log "Archive saved for the Organizer: $SAVED_ARCHIVE"
else
  log "IPA: $OUTPUT/export/Keepshire.ipa"
  log "Archive: $ARCHIVE (open it from Xcode → Window → Organizer)"
  if [[ -n "$TREE_WAS_CLEAN" ]]; then
    echo "$RELEASE_COMMIT" > "$COMMIT_RECORD"
    log "Upload it with Transporter, then run: release/release.sh $VERSION $BUILD --tag"
  else
    log "Built with uncommitted changes, so this build cannot be tagged. Commit and build again to release it."
  fi
fi

log "Done"
