#!/usr/bin/env bash
set -euo pipefail

# Builds a Release Copybara.app and packages it into a DMG.
#
# Local (unsigned) DMG:   ./scripts/build_dmg.sh
# Signed DMG:             DEVELOPMENT_TEAM=XXXXXXXXXX ./scripts/build_dmg.sh
#
# Distribution also requires notarization — see docs/RELEASE.md.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="Copybara"
BUILD_DIR="$ROOT/build"

command -v xcodegen >/dev/null || { echo "Install xcodegen: brew install xcodegen"; exit 1; }
xcodegen generate

if [ -n "${DEVELOPMENT_TEAM:-}" ]; then
  SIGN_ARGS=(DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" CODE_SIGN_STYLE=Automatic)
else
  echo "No DEVELOPMENT_TEAM set — building an UNSIGNED app (local testing only)."
  SIGN_ARGS=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO)
fi

# Optional version override (e.g. from a release tag).
VERSION_ARGS=()
if [ -n "${COPYBARA_VERSION:-}" ]; then
  VERSION_ARGS=(MARKETING_VERSION="$COPYBARA_VERSION")
fi

rm -rf "$BUILD_DIR"
xcodebuild \
  -project "$APP_NAME.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  "${SIGN_ARGS[@]}" \
  "${VERSION_ARGS[@]}" \
  build

APP_PATH="$BUILD_DIR/DerivedData/Build/Products/Release/$APP_NAME.app"
[ -d "$APP_PATH" ] || { echo "Build failed: $APP_PATH not found"; exit 1; }

STAGING="$BUILD_DIR/dmg"
rm -rf "$STAGING"; mkdir -p "$STAGING"
cp -R "$APP_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

DMG="$BUILD_DIR/$APP_NAME.dmg"
rm -f "$DMG"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG"

echo "Created $DMG"
if [ -z "${DEVELOPMENT_TEAM:-}" ]; then
  echo "Unsigned build: on other Macs, clear quarantine after copying to /Applications:"
  echo "  xattr -dr com.apple.quarantine /Applications/$APP_NAME.app"
fi
