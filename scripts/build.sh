#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Clean My Keyboard"
EXECUTABLE_NAME="CleanMyKeyboard"
DEPLOYMENT_TARGET="13.0"
SIGNING_KEYCHAIN="$HOME/Library/Keychains/cmk-signing.keychain-db"
SIGNING_IDENTITY="CleanMyKeyboard Local Dev"

BUILD_DIR="$ROOT/build"
BUNDLE_DIR="$BUILD_DIR/$APP_NAME.app"
MACOS_DIR="$BUNDLE_DIR/Contents/MacOS"
RESOURCES_DIR="$BUNDLE_DIR/Contents/Resources"
ICNS_PATH="$ROOT/Resources/AppIcon.icns"
ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"

mkdir -p "$BUILD_DIR/arm64" "$BUILD_DIR/x86_64"

build_arch() {
    local arch="$1"
    swiftc -swift-version 5 -parse-as-library -O \
        -target "$arch-apple-macosx$DEPLOYMENT_TARGET" \
        -o "$BUILD_DIR/$arch/$EXECUTABLE_NAME" \
        "$ROOT"/Sources/CleanMyKeyboard/*.swift
}

echo "[1/4] Building arm64"
build_arch arm64

UNIVERSAL=0
if swiftc -target "x86_64-apple-macosx$DEPLOYMENT_TARGET" -print-target-info >/dev/null 2>&1; then
    echo "[1/4] Building x86_64"
    build_arch x86_64
    UNIVERSAL=1
else
    echo "[1/4] Toolchain has no x86_64 support; building arm64 only"
fi

rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

if [ "$UNIVERSAL" = "1" ]; then
    lipo -create \
        "$BUILD_DIR/arm64/$EXECUTABLE_NAME" \
        "$BUILD_DIR/x86_64/$EXECUTABLE_NAME" \
        -output "$MACOS_DIR/$EXECUTABLE_NAME"
else
    cp "$BUILD_DIR/arm64/$EXECUTABLE_NAME" "$MACOS_DIR/$EXECUTABLE_NAME"
fi

echo "[2/4] Generating app icon"
if [ ! -f "$ICNS_PATH" ] || [ "$ROOT/scripts/make_icon.swift" -nt "$ICNS_PATH" ]; then
    rm -rf "$ICONSET_DIR"
    swift "$ROOT/scripts/make_icon.swift" "$ICONSET_DIR"
    iconutil -c icns "$ICONSET_DIR" -o "$ICNS_PATH"
fi
cp "$ICNS_PATH" "$RESOURCES_DIR/AppIcon.icns"

echo "[3/4] Assembling app bundle"
cp "$ROOT/Resources/Info.plist" "$BUNDLE_DIR/Contents/Info.plist"
printf 'APPL????' > "$BUNDLE_DIR/Contents/PkgInfo"
plutil -lint "$BUNDLE_DIR/Contents/Info.plist" >/dev/null

echo "[4/4] Signing"
if security find-identity -p codesigning "$SIGNING_KEYCHAIN" 2>/dev/null | grep -q "$SIGNING_IDENTITY"; then
    # A stable certificate keeps the app's identity constant across rebuilds, so
    # the Accessibility permission granted once keeps working afterwards.
    security unlock-keychain -p cmk-local-keychain "$SIGNING_KEYCHAIN" >/dev/null 2>&1 || true
    if codesign --force --sign "$SIGNING_IDENTITY" --keychain "$SIGNING_KEYCHAIN" "$BUNDLE_DIR" >/dev/null 2>&1; then
        echo "[4/4] Signed with \"$SIGNING_IDENTITY\""
    else
        echo "[4/4] Stable identity failed; falling back to ad-hoc signing"
        codesign --force --sign - "$BUNDLE_DIR" >/dev/null 2>&1 || echo "Signing failed; the app may still run"
    fi
else
    echo "[4/4] No stable identity found; using ad-hoc signing"
    echo "      Permissions will not persist across rebuilds until you run scripts/setup_signing_identity.sh once."
    codesign --force --sign - "$BUNDLE_DIR" >/dev/null 2>&1 || echo "Signing failed; the app may still run"
fi

echo "Done: $BUNDLE_DIR"
