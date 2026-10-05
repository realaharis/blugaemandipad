import Foundation

struct LoLShimCoverageItem: Identifiable {
    let id = UUID()
    let symbol: String
    let category: String
    let strategy: String
    let covered: Bool
}

struct LoLShimCoverageReport {
    let items: [LoLShimCoverageItem]
    let coveredCount: Int
    let totalCount: Int
    let projectedCoveragePercent: Int
    let remaining: [String]
}

struct LoLShimCoverageAnalyzer {
    static func analyze(plan: LoLCompatibilityPlan,
                        scan: DeepSymbolScanReport) -> LoLShimCoverageReport {
        let unresolved = scan.imports.filter { !$0.hostResolved }
        let appKitClassMap: Set<String> = [
            "_OBJC_CLASS_$_NSAlert",
            "_OBJC_CLASS_$_NSApplication",
            "_OBJC_CLASS_$_NSBitmapImageRep",
            "_OBJC_CLASS_$_NSColorSpace",
            "_OBJC_CLASS_$_NSCursor",
            "_OBJC_CLASS_$_NSEvent",
            "_OBJC_CLASS_$_NSFontManager",
            "_OBJC_CLASS_$_NSGraphicsContext",
            "_OBJC_CLASS_$_NSImage",
            "_OBJC_CLASS_$_NSMenu",
            "_OBJC_CLASS_$_NSMenuItem",
            "_OBJC_CLASS_$_NSOpenPanel",
            "_OBJC_CLASS_$_NSScreen",
            "_OBJC_CLASS_$_NSView",
            "_OBJC_CLASS_$_NSWindow",
            "_OBJC_METACLASS_$_NSView",
            "_OBJC_METACLASS_$_NSWindow",
            "_NSApp",
            "_NSCalibratedRGBColorSpace",
            "_NSDeviceRGBColorSpace",
            "_NSEventTrackingRunLoopMode",
            "_NSModalPanelRunLoopMode"
        ]

        let items = unresolved.map { item -> LoLShimCoverageItem in
            let path = (item.dependencyPath ?? "").lowercased()
            if item.libraryOrdinal == 0 || item.dependencyPath == "self" {
                return LoLShimCoverageItem(symbol: item.name,
                                           category: "self/weak",
                                           strategy: "intra-image/weak resolution",
                                           covered: true)
            }
            if appKitClassMap.contains(item.name) {
                return LoLShimCoverageItem(symbol: item.name,
                                           category: "AppKit",
                                           strategy: "UIKit/AppKit facade symbol map",
                                           covered: true)
            }
            if item.name == "_OBJC_CLASS_$_SBApplication" {
                return LoLShimCoverageItem(symbol: item.name,
                                           category: "ScriptingBridge",
                                           strategy: "limited compatibility facade",
                                           covered: true)
            }
            if item.name == "_Gestalt" {
                return LoLShimCoverageItem(symbol: item.name,
                                           category: "CoreServices",
                                           strategy: "compatibility query shim",
                                           covered: true)
            }
            if item.name == "dyld_stub_binder" {
                return LoLShimCoverageItem(symbol: item.name,
                                           category: "dyld",
                                           strategy: "DarwinBridge binder boundary",
                                           covered: true)
            }
            if path.contains("foundation.framework") && item.name == "_OBJC_CLASS_$_NSAppleEventManager" {
                return LoLShimCoverageItem(symbol: item.name,
                                           category: "Foundation",
                                           strategy: "limited/no-op AppleEvent facade",
                                           covered: true)
            }
            return LoLShimCoverageItem(symbol: item.name,
                                       category: item.dependencyPath ?? "unknown",
                                       strategy: "unclassified",
                                       covered: false)
        }

        let covered = items.filter(\.covered).count
        let projectedResolved = scan.resolvedCount + covered
        let projected = scan.imports.isEmpty ? 0 : Int((Double(projectedResolved) / Double(scan.imports.count) * 100.0).rounded())

        return LoLShimCoverageReport(items: items,
                                     coveredCount: covered,
                                     totalCount: items.count,
                                     projectedCoveragePercent: projected,
                                     remaining: items.filter { !$0.covered }.map(\.symbol))
    }
}
