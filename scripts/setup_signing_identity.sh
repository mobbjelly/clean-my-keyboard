#!/usr/bin/env bash
# Creates a stable, local self-signed code-signing identity.
#
# Why this exists: an ad-hoc signature (-) pins the app to a hash of the exact
# executable (its cdhash). Every rebuild produces a new cdhash, so macOS treats
# the new build as a brand-new app and Accessibility permission is lost each time.
# Signing with a stable certificate makes the app's identity depend on the
# certificate instead of the file hash, so permission survives rebuilds.

set -euo pipefail

IDENTITY_NAME="CleanMyKeyboard Local Dev"
KEYCHAIN_NAME="cmk-signing.keychain-db"
KEYCHAIN_PATH="$HOME/Library/Keychains/$KEYCHAIN_NAME"
KEYCHAIN_PASSWORD="cmk-local-keychain"
P12_PASSWORD="cmk-local-p12"

if security find-identity -p codesigning "$KEYCHAIN_PATH" 2>/dev/null | grep -q "$IDENTITY_NAME"; then
    echo "Signing identity already exists: $IDENTITY_NAME"
    exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "Generating a self-signed code-signing certificate..."
openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
    -keyout "$WORK/key.pem" -out "$WORK/cert.pem" \
    -subj "/CN=$IDENTITY_NAME/O=Clean My Keyboard/C=US" \
    -addext "basicConstraints=critical,CA:false" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=critical,codeSigning" 2>/dev/null

openssl pkcs12 -export \
    -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
    -name "$IDENTITY_NAME" -out "$WORK/identity.p12" \
    -passout "pass:$P12_PASSWORD" \
    -certpbe PBE-SHA1-3DES -keypbe PBE-SHA1-3DES -macalg sha1

echo "Importing into a dedicated keychain: $KEYCHAIN_PATH"
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH" 2>/dev/null || true
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security import "$WORK/identity.p12" -k "$KEYCHAIN_PATH" -P "$P12_PASSWORD" \
    -T /usr/bin/codesign -T /usr/bin/security -A
security set-key-partition-list -S apple-tool:,apple:,codesign: -s \
    -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH" >/dev/null 2>&1 || true

echo "Marking the certificate as trusted for code signing..."
security add-trusted-cert -r trustRoot -k "$KEYCHAIN_PATH" "$WORK/cert.pem" 2>/dev/null \
    || echo "  (trust step skipped; the identity still works for local signing)"

echo "Done. Identity: $IDENTITY_NAME"
