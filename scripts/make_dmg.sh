#!/usr/bin/env bash
# Builds the app and packages it into a distributable disk image.
#
# The image contains the app bundle and an /Applications symlink, so users
# mount the dmg, then drag the app onto Applications.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Clean My Keyboard"
APP_PATH="$ROOT/build/$APP_NAME.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Resources/Info.plist")"
DMG_NAME="CleanMyKeyboard-$VERSION.dmg"
DMG_PATH="$ROOT/build/$DMG_NAME"
STAGING_DIR="$ROOT/build/dmg-staging"
VOLUME_NAME="$APP_NAME"

echo "[1/3] Building the app"
bash "$ROOT/scripts/build.sh"

echo "[2/3] Staging the disk image contents"
rm -rf "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

echo "[3/3] Creating $DMG_NAME"
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov -format UDZO \
    -fs HFS+ \
    "$DMG_PATH" >/dev/null

rm -rf "$STAGING_DIR"

echo "Done: $DMG_PATH"
