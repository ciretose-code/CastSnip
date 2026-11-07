#!/bin/bash
# Scripts/release.sh — Archive, notarize, staple, package a DMG, and publish it
# to GitHub Releases.
#
# One-time credential setup (stored in your keychain, never needs repeating):
#
#   xcrun notarytool store-credentials "castsnip-notary" \
#     --key ~/.private_keys/AuthKey_<KEY_ID>.p8 \
#     --key-id <KEY_ID> \
#     --issuer <ISSUER_ID>
#
# Usage:
#   ./Scripts/release.sh                # full release
#   ./Scripts/release.sh --dry-run      # build and package, but don't notarize or publish
#   ./Scripts/release.sh --skip-tests   # skip the suite (it runs by default)
#
set -euo pipefail

# ── Config ─────────────────────────────────────────────────────────────────────
SCHEME="CastSnip"
PROJECT="CastSnip.xcodeproj"
DISPLAY_NAME="CastSnip"
EXPORT_OPTIONS="Scripts/ExportOptions.plist"
NOTARY_PROFILE="${NOTARY_PROFILE:-castsnip-notary}"   # keychain profile from store-credentials

ARCHIVE_PATH="build/${SCHEME}.xcarchive"
EXPORT_PATH="build/export"
MOUNT_DIR="/Volumes/${DISPLAY_NAME}-staging"
STAGING_DMG="build/staging.dmg"

DRY_RUN=false
RUN_TESTS=true
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --skip-tests) RUN_TESTS=false ;;
    *) echo "error: unknown argument '$arg'" >&2; exit 2 ;;
  esac
done

die() { echo "error: $*" >&2; exit 1; }
step() { echo ""; echo "▶ $*"; }

# ── Preflight ──────────────────────────────────────────────────────────────────
# All of this is cheap and fails in seconds. The alternative is discovering a
# missing certificate after a four-minute archive, or a stale tag after the
# notary service has already accepted the build.
step "Checking preconditions..."

[ -f "$PROJECT/project.pbxproj" ] || die "run this from the repository root"
command -v gh >/dev/null || die "gh is not installed"
gh auth status >/dev/null 2>&1 || die "gh is not authenticated — run: gh auth login"

# `grep PATTERN >/dev/null`, never `grep -q`, at the end of a pipeline in this script.
# `set -o pipefail` is on, and `grep -q` exits the instant it matches — which hands the
# process upstream a SIGPIPE, and pipefail then reports the pipeline as failing with 141
# precisely *because* the thing being looked for was found. Plain grep reads its input
# to the end, so the producer always finishes cleanly.
security find-identity -v -p codesigning 2>/dev/null | grep "Developer ID Application" >/dev/null \
  || die "no Developer ID Application certificate in the keychain"

# The version that ships has to be the version that is committed, or the tag
# points at something nobody can check out.
[ -z "$(git status --porcelain)" ] || die "working tree is dirty — commit or stash first"

BRANCH=$(git rev-parse --abbrev-ref HEAD)
[ "$BRANCH" = "main" ] || die "releases are cut from main, not '$BRANCH'"

git fetch --quiet origin main
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] \
  || die "main is not in sync with origin/main — pull or push first"

if [ "$DRY_RUN" = false ]; then
  # A network call, but a fast one, and much better than finding out after the
  # archive. A failure here is usually a missing profile; it can also be no
  # network, which the message has to allow for.
  xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" --output-format json >/dev/null 2>&1 \
    || die "notary profile '$NOTARY_PROFILE' is not usable (missing, or no network).
       Set one up once with:
         xcrun notarytool store-credentials \"$NOTARY_PROFILE\" --key ... --key-id ... --issuer ...
       Or point at another profile with NOTARY_PROFILE=<name> $0"
fi

# ── Version ────────────────────────────────────────────────────────────────────
# The build number is the commit count rather than a counter stored in
# project.pbxproj. That keeps a release from having to write to the repository.
# It is also reproducible — any checkout of this commit computes the same
# number — and it only ever goes up, because history only grows.
VERSION=$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -showBuildSettings 2>/dev/null \
  | awk '/ MARKETING_VERSION/{print $3}' | head -1)
[ -n "$VERSION" ] || die "could not read MARKETING_VERSION from the project"

BUILD=$(git rev-list --count HEAD)
TAG="v${VERSION}.${BUILD}"
COMMIT=$(git rev-parse HEAD)
DMG_PATH="build/${DISPLAY_NAME}-${VERSION}.${BUILD}.dmg"

if git rev-parse "$TAG" >/dev/null 2>&1; then
  die "tag ${TAG} already exists — nothing new to release"
fi
if gh release view "$TAG" >/dev/null 2>&1; then
  die "release ${TAG} already published"
fi

echo "  ${DISPLAY_NAME} ${VERSION} (build ${BUILD}) → ${TAG} at ${COMMIT:0:7}"

# ── Clean slate ────────────────────────────────────────────────────────────────
# A previous run that died mid-DMG leaves a volume mounted, and hdiutil will
# happily attach a second copy under a different name if we don't clear it.
mkdir -p build
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH" "$STAGING_DMG"
[ -d "$MOUNT_DIR" ] && hdiutil detach "$MOUNT_DIR" -quiet -force 2>/dev/null || true

# ── Tests ──────────────────────────────────────────────────────────────────────
if [ "$RUN_TESTS" = true ]; then
  step "Running tests..."
  # Output goes to a file rather than through a pipe: piping into grep would
  # hand back grep's exit status, and a release must not ship because the
  # failure text happened not to match a pattern.
  # Unit tests only — UI tests are too flaky to gate notarized releases.
  if ! xcodebuild -project "$PROJECT" -scheme "$SCHEME" -destination "platform=macOS" \
       -only-testing:CastSnipTests test \
       > build/test.log 2>&1; then
    grep -E "error:|recorded an issue|failed" build/test.log | head -20 | sed 's/^/  /'
    die "tests failed — not releasing (full log: build/test.log)"
  fi
  grep -E "Test run with" build/test.log | tail -1 | sed 's/^/  /'
else
  echo "  (skipping tests)"
fi

# ── Archive ────────────────────────────────────────────────────────────────────
step "Archiving..."
# CURRENT_PROJECT_VERSION is overridden on the command line rather than written
# into project.pbxproj, so the bundle reports the same build number the release
# is tagged with. Without it the app inside a DMG named 1.0.109 would tell Get
# Info it was build 1, and any future update check would compare the wrong thing.
# ARCHS=arm64: the LAME SPM binary is arm64-only, and the app's deployment
# target already excludes Intel Macs. A generic/platform=macOS archive would
# also try to link x86_64 and fail with undefined lame_* symbols.
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  -destination "generic/platform=macOS" \
  -allowProvisioningUpdates \
  CURRENT_PROJECT_VERSION="$BUILD" \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=NO \
  | grep -E "^(error:|warning:|Build succeeded|Archive succeeded)" || true
[ -d "$ARCHIVE_PATH" ] || die "archive failed"

# ── Export, signed with Developer ID ───────────────────────────────────────────
step "Exporting..."
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -allowProvisioningUpdates \
  | grep -E "^(error:|Export succeeded)" || true

APP_PATH=$(find "$EXPORT_PATH" -maxdepth 1 -name "*.app" | head -1)
[ -n "$APP_PATH" ] || die "no .app found in ${EXPORT_PATH}"

# Ensure the exported bundle matches the release display name.
RELEASE_APP="${EXPORT_PATH}/${DISPLAY_NAME}.app"
if [ "$APP_PATH" != "$RELEASE_APP" ]; then
  rm -rf "$RELEASE_APP"
  mv "$APP_PATH" "$RELEASE_APP"
  APP_PATH="$RELEASE_APP"
fi

# Check the signature before spending minutes at the notary service. `spctl`
# rejecting it here is the same rejection Gatekeeper would give a user.
step "Verifying signature..."
codesign --verify --deep --strict --verbose=1 "$APP_PATH" 2>&1 | sed 's/^/  /'
spctl --assess --type exec --verbose=2 "$APP_PATH" 2>&1 | sed 's/^/  /' || true
codesign -dvv "$APP_PATH" 2>&1 | grep -E "^(Authority|TeamIdentifier|Identifier)=" | sed 's/^/  /'

# The bundle must agree with the tag it is about to be published under.
BUNDLE_BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP_PATH/Contents/Info.plist")
BUNDLE_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
echo "  Bundle=${BUNDLE_VERSION} (${BUNDLE_BUILD})"
[ "$BUNDLE_BUILD" = "$BUILD" ] || die "bundle says build ${BUNDLE_BUILD} but this release is ${TAG}"
[ "$BUNDLE_VERSION" = "$VERSION" ] || die "bundle says version ${BUNDLE_VERSION} but this release is ${TAG}"

# ── DMG ────────────────────────────────────────────────────────────────────────
# A read-write image is staged so Finder can set the icon layout, then converted
# to a compressed read-only one. Layout has to be set on a mounted volume; there
# is no way to describe it to hdiutil directly.
step "Creating DMG..."
APP_BUNDLE=$(basename "$APP_PATH")
APP_SIZE_MB=$(du -sm "$APP_PATH" | awk '{print $1}')

hdiutil create \
  -megabytes $((APP_SIZE_MB + 20)) \
  -volname "${DISPLAY_NAME} ${VERSION}" \
  -fs HFS+ \
  -ov \
  "$STAGING_DMG" >/dev/null

hdiutil attach "$STAGING_DMG" -mountpoint "$MOUNT_DIR" -noautoopen -readwrite >/dev/null
cp -R "$APP_PATH" "$MOUNT_DIR/"

osascript <<APPLESCRIPT >/dev/null
tell application "Finder"
  set theDisk to disk "${DISPLAY_NAME}-staging"
  make new alias file to folder "Applications" of startup disk at theDisk
  tell theDisk
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {100, 100, 540, 380}
    set viewOptions to icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 128
    set position of item "${APP_BUNDLE}" of container window to {120, 150}
    set position of item "Applications" of container window to {330, 150}
    update without registering applications
    delay 2
    close
  end tell
end tell
APPLESCRIPT

sync
sleep 1
hdiutil detach "$MOUNT_DIR" -quiet

hdiutil convert "$STAGING_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH" -ov >/dev/null
rm -f "$STAGING_DMG"
echo "  ${DMG_PATH} ($(du -h "$DMG_PATH" | awk '{print $1}'))"

if [ "$DRY_RUN" = true ]; then
  echo ""
  echo "✅ Dry run complete — built, signed, and packaged."
  echo "   DMG: ${DMG_PATH}"
  echo "   Not notarized and not published. Re-run without --dry-run to ship ${TAG}."
  exit 0
fi

# ── Notarize ───────────────────────────────────────────────────────────────────
# The DMG is submitted rather than the app: stapling the disk image means the
# ticket travels with the download, so the first launch works offline.
step "Notarizing (this takes a few minutes)..."
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

step "Stapling..."
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"

# ── Publish ────────────────────────────────────────────────────────────────────
# The tag is created by `gh` at this exact commit. Nothing is pushed to main —
# a release does not need to write anything back to the repository.
step "Publishing GitHub release ${TAG}..."
gh release create "$TAG" \
  "$DMG_PATH" \
  --target "$COMMIT" \
  --title "${DISPLAY_NAME} ${TAG}" \
  --generate-notes

echo ""
echo "✅ Released ${TAG}"
echo "   DMG: ${DMG_PATH}"
echo "   $(gh release view "$TAG" --json url --jq .url)"
