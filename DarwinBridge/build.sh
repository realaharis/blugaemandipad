#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/Payload/DarwinBridge.app"
OBJ="$BUILD/obj"

rm -rf "$BUILD"
mkdir -p "$APP" "$OBJ"

SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
SWIFTC="$(xcrun --sdk iphoneos --find swiftc)"
CLANG="$(xcrun --sdk iphoneos --find clang)"

"$CLANG" -target arm64-apple-ios17.0 -isysroot "$SDK"   -c "$ROOT/Core/JIT26Protocol.S" -o "$OBJ/JIT26Protocol.o"

"$CLANG" -target arm64-apple-ios17.0 -isysroot "$SDK"   -c "$ROOT/Core/JIT26Allocator.c" -o "$OBJ/JIT26Allocator.o"

"$CLANG" -target arm64-apple-ios17.0 -isysroot "$SDK"   -c "$ROOT/Core/RuntimeBridge.c" -o "$OBJ/RuntimeBridge.o"

"$SWIFTC"   -sdk "$SDK"   -target arm64-apple-ios17.0   -parse-as-library   -O   "$ROOT"/Core/*.swift   "$ROOT"/App/*.swift   "$OBJ/JIT26Protocol.o"   "$OBJ/JIT26Allocator.o"   "$OBJ/RuntimeBridge.o"   -framework SwiftUI   -framework UniformTypeIdentifiers   -framework Foundation   -framework UIKit   -o "$APP/DarwinBridge"

cp "$ROOT/Info.plist" "$APP/Info.plist"
cp "$ROOT/JIT/darwinbridge-universal.js" "$APP/darwinbridge-universal.js"

if command -v codesign >/dev/null 2>&1; then
  codesign --force --sign -     --entitlements "$ROOT/DarwinBridge.entitlements"     "$APP/DarwinBridge"
fi

(
  cd "$BUILD"
  /usr/bin/zip -qry DarwinBridge-unsigned.ipa Payload
)

echo "$BUILD/DarwinBridge-unsigned.ipa"
