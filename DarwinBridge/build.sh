#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/Payload/DarwinBridge.app"

rm -rf "$BUILD"
mkdir -p "$APP"

SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
SWIFTC="$(xcrun --sdk iphoneos --find swiftc)"

"$SWIFTC"   -sdk "$SDK"   -target arm64-apple-ios17.0   -parse-as-library   -O   "$ROOT"/Core/*.swift "$ROOT"/App/*.swift   -framework SwiftUI   -framework UniformTypeIdentifiers   -framework Foundation   -framework UIKit   -o "$APP/DarwinBridge"

cp "$ROOT/Info.plist" "$APP/Info.plist"\ncp "$ROOT/JIT/darwinbridge-universal.js" "$APP/darwinbridge-universal.js"

if command -v codesign >/dev/null 2>&1; then
  codesign --force --sign -     --entitlements "$ROOT/DarwinBridge.entitlements"     "$APP/DarwinBridge"
fi

(
  cd "$BUILD"
  /usr/bin/zip -qry DarwinBridge-unsigned.ipa Payload
)

echo "$BUILD/DarwinBridge-unsigned.ipa"
