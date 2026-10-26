#!/usr/bin/env bash
# Copyright (c) 2026 Anton Ustinoff. All rights reserved.
# Use and redistribution are subject to LICENSE.

set -euo pipefail

# Builds a Release Copybara.app and packages it into a DMG.
#
# Local (ad-hoc) DMG:     ./scripts/build_dmg.sh
# Certificate-signed DMG: COPYBARA_CODE_SIGN_IDENTITY=<SHA1> ./scripts/build_dmg.sh
# Signed DMG:             DEVELOPMENT_TEAM=XXXXXXXXXX ./scripts/build_dmg.sh
# Explicit version:       COPYBARA_VERSION=0.2.0 ./scripts/build_dmg.sh
#
# Output: build/Copybara-<version>.dmg (version from COPYBARA_VERSION, else
# MARKETING_VERSION in project.yml). The image is mounted and checked after
# it is created: the app is present, the Applications link is there, and a
# signed app's signature survived packaging.
#
# Distribution also requires notarization — see docs/RELEASE.md.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="Copybara"
BUILD_DIR="$ROOT/build"
NOTARIZE="${COPYBARA_NOTARIZE:-0}"

if [ "$NOTARIZE" = 1 ]; then
  : "${COPYBARA_CODE_SIGN_IDENTITY:?A Developer ID Application certificate SHA1 is required}"
  : "${COPYBARA_TEAM_ID:?The Developer ID team is required}"
  : "${APPLE_ID:?The notarization Apple ID is required}"
  : "${APPLE_APP_PASSWORD:?An app-specific notarization password is required}"
  [[ "$COPYBARA_CODE_SIGN_IDENTITY" =~ ^[0-9A-Fa-f]{40}$ ]] || { echo "Invalid signing certificate SHA1"; exit 1; }
  [[ "$COPYBARA_TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] || { echo "Invalid Developer ID team"; exit 1; }
elif [ "$NOTARIZE" != 0 ]; then
  echo "COPYBARA_NOTARIZE must be 0 or 1"
  exit 1
fi

command -v xcodegen >/dev/null || { echo "Install xcodegen: brew install xcodegen"; exit 1; }
xcodegen generate

if [ -n "${COPYBARA_CODE_SIGN_IDENTITY:-}" ]; then
  SIGN_ARGS=(CODE_SIGN_IDENTITY="$COPYBARA_CODE_SIGN_IDENTITY" CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= PROVISIONING_PROFILE_SPECIFIER=)
elif [ -n "${DEVELOPMENT_TEAM:-}" ]; then
  SIGN_ARGS=(DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" CODE_SIGN_STYLE=Automatic)
else
  # Ad-hoc, not unsigned: with signing disabled only the linker signs the
  # executable (identifier "Copybara") and the bundle is left unsealed, which
  # breaks the Accessibility grant. Ad-hoc seals it as dev.ustinoff.copybara.
  # Overrides any team from Config/Local.xcconfig.
  echo "No DEVELOPMENT_TEAM set — building an ad-hoc signed app (no certificate)."
  SIGN_ARGS=(CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= PROVISIONING_PROFILE_SPECIFIER=)
fi

if [ "$NOTARIZE" = 1 ]; then
  SIGN_ARGS+=(ENABLE_HARDENED_RUNTIME=YES OTHER_CODE_SIGN_FLAGS=--timestamp)
fi

# Version: explicit override (e.g. from a release tag), else project.yml.
# Always passed explicitly: an empty array trips `set -u` in macOS's bash 3.2.
if [ -n "${COPYBARA_VERSION:-}" ]; then
  VERSION="$COPYBARA_VERSION"
else
  VERSION=$(sed -nE 's/^[[:space:]]*MARKETING_VERSION:[[:space:]]*"?([^"]+)"?[[:space:]]*$/\1/p' project.yml | head -1)
  [ -n "$VERSION" ] || { echo "Could not read MARKETING_VERSION from project.yml"; exit 1; }
fi
VERSION_ARGS=(MARKETING_VERSION="$VERSION")
if [ -n "${COPYBARA_BUILD_NUMBER:-}" ]; then
  VERSION_ARGS+=(CURRENT_PROJECT_VERSION="$COPYBARA_BUILD_NUMBER")
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

if [ "$NOTARIZE" = 1 ]; then
  # Sign inside-out. Sparkle's helpers retain their existing entitlements;
  # --deep is for verification, never for signing nested code.
  SPARKLE="$APP_PATH/Contents/Frameworks/Sparkle.framework"
  for CODE in \
    "$SPARKLE/Versions/B/XPCServices/Downloader.xpc" \
    "$SPARKLE/Versions/B/XPCServices/Installer.xpc" \
    "$SPARKLE/Versions/B/Autoupdate" \
    "$SPARKLE/Versions/B/Updater.app" \
    "$SPARKLE" \
    "$APP_PATH"; do
    [ -e "$CODE" ] || { echo "Missing release code: $CODE"; exit 1; }
    codesign --force --sign "$COPYBARA_CODE_SIGN_IDENTITY" --options runtime --timestamp \
      --preserve-metadata=identifier,entitlements "$CODE"
  done
  python3 scripts/verify_signing.py "$APP_PATH" --identity "$COPYBARA_CODE_SIGN_IDENTITY" --team-id "$COPYBARA_TEAM_ID"
  # Staple the app before packaging so the installed app also works offline.
  ./scripts/notarize.sh "$APP_PATH" "$BUILD_DIR/notarization/app"
elif [ -n "${COPYBARA_CODE_SIGN_IDENTITY:-}" ]; then
  python3 scripts/verify_signing.py "$APP_PATH" --identity "$COPYBARA_CODE_SIGN_IDENTITY"
fi

STAGING="$BUILD_DIR/dmg"
rm -rf "$STAGING"; mkdir -p "$STAGING"
# ditto, not cp -R: keeps the bundle's code signature and extended attributes.
ditto "$APP_PATH" "$STAGING/$APP_NAME.app"
ln -s /Applications "$STAGING/Applications"

DMG="$BUILD_DIR/$APP_NAME-$VERSION.dmg"
rm -f "$DMG"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGING"

if [ "$NOTARIZE" = 1 ]; then
  codesign --force --sign "$COPYBARA_CODE_SIGN_IDENTITY" --timestamp "$DMG"
  codesign --verify --strict "$DMG"
  ./scripts/notarize.sh "$DMG" "$BUILD_DIR/notarization/dmg"
fi

# Check the image itself, not just the staging folder.
MOUNT=$(mktemp -d)
trap 'hdiutil detach "$MOUNT" -quiet >/dev/null 2>&1 || true; rmdir "$MOUNT" 2>/dev/null || true' EXIT
hdiutil attach -nobrowse -readonly -mountpoint "$MOUNT" "$DMG" >/dev/null
[ -d "$MOUNT/$APP_NAME.app" ] || { echo "DMG check failed: $APP_NAME.app missing"; exit 1; }
[ -L "$MOUNT/Applications" ] || { echo "DMG check failed: Applications link missing"; exit 1; }
codesign --verify --deep --strict "$MOUNT/$APP_NAME.app"
if [ "$NOTARIZE" = 1 ]; then
  python3 scripts/verify_signing.py "$MOUNT/$APP_NAME.app" --identity "$COPYBARA_CODE_SIGN_IDENTITY" --team-id "$COPYBARA_TEAM_ID"
  xcrun stapler validate "$MOUNT/$APP_NAME.app"
  spctl --assess --type execute --verbose=2 "$MOUNT/$APP_NAME.app"
fi
echo "Signature verified inside the DMG."

echo "Created $DMG ($(du -h "$DMG" | cut -f1 | tr -d ' '))"
if [ -z "${DEVELOPMENT_TEAM:-}" ] && [ -z "${COPYBARA_CODE_SIGN_IDENTITY:-}" ]; then
  echo "Ad-hoc build: on other Macs, clear quarantine after copying to /Applications:"
  echo "  xattr -dr com.apple.quarantine /Applications/$APP_NAME.app"
fi
