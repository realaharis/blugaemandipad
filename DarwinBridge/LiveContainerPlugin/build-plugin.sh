#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build/livecontainer-plugin"
mkdir -p "$OUT"

SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
CLANG="$(xcrun --sdk iphoneos --find clang)"

"$CLANG"   -target arm64-apple-ios17.0   -isysroot "$SDK"   -fobjc-arc   -fblocks   -dynamiclib   "$ROOT/LiveContainerPlugin/DarwinBridgeLCPlugin.m"   -framework Foundation   -framework UIKit   -framework Metal   -install_name @rpath/DarwinBridgeLCPlugin.dylib   -o "$OUT/DarwinBridgeLCPlugin.dylib"

if command -v codesign >/dev/null 2>&1; then
  codesign --force --sign - "$OUT/DarwinBridgeLCPlugin.dylib"
fi

echo "$OUT/DarwinBridgeLCPlugin.dylib"
