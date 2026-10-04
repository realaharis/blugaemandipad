import Foundation

struct FrameworkShimRegistry {
    static func assess(_ dependency: MachODependency) -> DependencyAssessment {
        let p = dependency.path.lowercased()

        if p.contains("appkit.framework") {
            return DependencyAssessment(dependency: dependency,
                                        disposition: .shim,
                                        replacement: "UIKit + DarwinBridge.AppKitShim",
                                        note: "NSApplication/NSWindow/NSView require explicit UIKit-backed shims.")
        }
        if p.contains("foundation.framework") || p.contains("corefoundation.framework") ||
            p.contains("coregraphics.framework") || p.contains("quartzcore.framework") ||
            p.contains("metal.framework") || p.contains("metalkit.framework") ||
            p.contains("avfoundation.framework") || p.hasSuffix("/libobjc.a.dylib") {
            return DependencyAssessment(dependency: dependency,
                                        disposition: .native,
                                        replacement: nil,
                                        note: "A corresponding iOS framework/runtime exists; ABI and symbol availability still need validation.")
        }
        if p.contains("iokit.framework") {
            return DependencyAssessment(dependency: dependency,
                                        disposition: .partial,
                                        replacement: "IOKit shim / higher-level iOS APIs",
                                        note: "Many desktop IOKit services are unavailable inside the iOS sandbox.")
        }
        if p.contains("security.framework") || p.contains("network.framework") {
            return DependencyAssessment(dependency: dependency,
                                        disposition: .partial,
                                        replacement: nil,
                                        note: "Framework exists on iOS, but desktop-only calls and entitlements may differ.")
        }
        if p.contains("coreservices.framework") || p.contains("carbon.framework") || p.contains("opengl.framework") {
            return DependencyAssessment(dependency: dependency,
                                        disposition: .blocked,
                                        replacement: p.contains("opengl") ? "Metal translation layer" : nil,
                                        note: "Desktop framework is not available as-is on iOS.")
        }
        if p.contains("libsystem") || p.contains("libc++") || p.contains("libswift") {
            return DependencyAssessment(dependency: dependency,
                                        disposition: .partial,
                                        replacement: "iOS system runtime",
                                        note: "Runtime family exists, but symbol/version compatibility must be resolved per import.")
        }

        return DependencyAssessment(dependency: dependency,
                                    disposition: .unknown,
                                    replacement: nil,
                                    note: "No rule yet; symbol-level inspection is required.")
    }
}
