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
            p.contains("avfoundation.framework") || p.contains("coretext.framework") ||
            p.contains("cfnetwork.framework") || p.contains("security.framework") ||
            p.contains("systemconfiguration.framework") || p.hasSuffix("/libobjc.a.dylib") ||
            p.contains("libresolv") || p.contains("libsm.") {
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
        if p.contains("coreservices.framework") {
            return DependencyAssessment(dependency: dependency,
                                        disposition: .shim,
                                        replacement: "Foundation/UTType/FileManager compatibility shim",
                                        note: "CoreServices umbrella is desktop-only, but common client-facing services can be mapped to iOS equivalents.")
        }
        if p.contains("cocoa.framework") {
            return DependencyAssessment(dependency: dependency,
                                        disposition: .shim,
                                        replacement: "Foundation + DarwinBridge.AppKitShim",
                                        note: "Cocoa umbrella maps to Foundation plus the existing AppKit/UIKit facade.")
        }
        if p.contains("diskarbitration.framework") {
            return DependencyAssessment(dependency: dependency,
                                        disposition: .shim,
                                        replacement: "Sandbox volume compatibility shim",
                                        note: "Expose app-visible volume/path semantics without desktop disk arbitration.")
        }
        if p.contains("scriptingbridge.framework") {
            return DependencyAssessment(dependency: dependency,
                                        disposition: .shim,
                                        replacement: "DarwinBridge no-op/limited scripting shim",
                                        note: "Apple-event automation is unavailable; provide a limited compatibility surface.")
        }
        if p.contains("iokit.framework") {
            return DependencyAssessment(dependency: dependency,
                                        disposition: .partial,
                                        replacement: "IOKit shim / higher-level iOS APIs",
                                        note: "Many desktop IOKit services are unavailable inside the iOS sandbox.")
        }
        if p.contains("carbon.framework") || p.contains("opengl.framework") {
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
