# CotEditor macOS ARM64 runtime audit

Target: official CotEditor 7.1.1 release, published by coteditor/CotEditor.
Official DMG: https://github.com/coteditor/CotEditor/releases/download/7.1.1/CotEditor_7.1.1.dmg
GitHub release asset size: 26,594,816 bytes (not an installed bundle size).
GitHub release is public, but no CotEditor binary is committed to this repository.

## Source-based findings
- Current CotEditor is a native Swift macOS application using AppKit, Cocoa document architecture, and NSTextView.
- The release requires macOS 26 or newer.
- Source project: CotEditor.xcodeproj, Swift packages EditorCore, MacUI, Syntax.
- EditorCore and MacUI package manifests target macOS 26 and Swift tools 6.3.
- CotEditor main source is Apache-2.0; bundled image resources have separate CC BY-NC-ND 4.0 restrictions.
- A complete iPad runtime would need actual AppKit document/text semantics, not empty stubs.

## CI audit
Workflow coteditor-runtime-audit.yml runs on GitHub-hosted macOS.
It downloads the official DMG, verifies its size, mounts it read-only, finds the .app,
extracts the ARM64 Mach-O slice, and records architecture, platform, imports, linked dylibs,
rpaths, minimum OS, and bundle identity. No source binary is redistributed as an artifact.
Only text reports are uploaded. The official DMG may change or fail to mount; failures remain visible.

## Gates
1. **Static:** real ARM64 executable and dependency closure evidence.
2. **Compatibility:** classify frameworks and Swift/ObjC/AppKit dependencies against iPadOS.
3. **Execution:** run a separate tiny macOS ARM64 fixture and prove actual entrypoint execution.
4. **UI:** show a real text-editing window, input, save/open lifecycle.
5. **CotEditor:** only then attempt its unmodified macOS app under the runtime.

Do not treat static scans, a converted Mach-O, or a green GitHub workflow as proof of CotEditor running on iPadOS.
