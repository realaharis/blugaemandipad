# DarwinBridge

DarwinBridge is an experimental macOS-to-iPadOS compatibility layer prototype. The first milestone focuses on native ARM64 Mach-O inspection and manual mapping rather than CPU emulation.

## Milestone 0.1

Implemented:

- 64-bit little-endian Mach-O parser
- ARM64 detection
- LC_SEGMENT_64 parsing and file-range validation
- LC_LOAD_DYLIB / weak / re-export dependency parsing
- LC_RPATH, LC_MAIN, LC_BUILD_VERSION and LC_ENCRYPTION_INFO_64 parsing
- framework compatibility classification
- AppKit/UIKit shim planning
- anonymous-memory segment mapper for inspection
- SwiftUI iPhone/iPad host app with file import
- unsigned IPA CI build
- parser smoke test

The loader intentionally does not jump to guest code yet. Rebasing, symbol binding, framework shims and JIT-safe executable mappings must be correct first.

## Roadmap

1. LC_DYLD_CHAINED_FIXUPS parsing and rebasing.
2. Export trie/import resolution and controlled symbol broker.
3. AppKit compatibility surface backed by UIKit.
4. Executable MAP_JIT pages under debugger/JIT-enabled conditions.
5. Execute a tiny synthetic ARM64 macOS guest.
6. Expand framework shims from traces.
7. Test a larger macOS application/game launcher.

League of Legends is a long-term compatibility target, not the first-stage test binary.
