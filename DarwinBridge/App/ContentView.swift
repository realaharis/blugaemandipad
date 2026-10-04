import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var importing = false
    @State private var fileName = "No Mach-O selected"
    @State private var image: MachOImageInfo?
    @State private var report: CompatibilityReport?
    @State private var errorText: String?
    @State private var mappedSummary: String?
    @State private var mappedImage: MappedMachOImage?
    @State private var importedData: Data?
    @State private var fixupPlan: FixupPlan?
    @State private var guestSpace: GuestAddressSpace?
    @State private var appliedFixups: AppliedFixups?
    @State private var jitResult: JITExecutionResult?
    @State private var runtimeReport: RuntimeCompatibilityReport?
    @State private var runtimeCallResult: RuntimeCallResult?
    @State private var runtimeChainResult: RuntimeCallResult?
    @State private var stikDebugStatus = "not requested"

    var body: some View {
        NavigationStack {
            List {
                Section("Target") {
                    Text(fileName).font(.headline)
                    Button("Import macOS Mach-O") { importing = true }
                }

                if let image {
                    Section("Mach-O") {
                        row("CPU", image.isArm64 ? "ARM64" : String(format: "0x%08X", image.cpuType))
                        row("Segments", "\(image.segments.count)")
                        row("Dependencies", "\(image.dependencies.count)")
                        row("Entry offset", image.entryOffset.map { String(format: "0x%llX", $0) } ?? "none")
                        row("Minimum macOS", image.minimumOS ?? "unknown")
                        row("SDK", image.sdk ?? "unknown")
                        row("Encrypted", image.encrypted ? "yes" : "no")
                        row("Chained fixups", image.chainedFixups == nil ? "none" : "present")
                    }

                    Section("Stage-0 loader") {
                        Button("Map segments for inspection") { map(image) }
                            .disabled(!image.isArm64 || image.encrypted)

                        if let mappedSummary {
                            Text(mappedSummary)
                                .font(.caption)
                                .monospaced()
                        }
                    }

                    Section("Stage-1 dyld") {
                        Button("Analyze chained fixups") { analyzeFixups(image) }
                            .disabled(image.chainedFixups == nil)

                        if let fixupPlan {
                            row("Imports", "\(fixupPlan.info.imports.count)")
                            row("Fixup pointers", "\(fixupPlan.supportedFixupCount)")
                            row("Unresolved binds", "\(fixupPlan.unresolvedBindCount)")
                            row("Apply-ready", fixupPlan.canApplyStage1 ? "yes" : "no")

                            if !fixupPlan.info.unsupportedPointerFormats.isEmpty {
                                let values = fixupPlan.info.unsupportedPointerFormats
                                    .sorted()
                                    .map(String.init)
                                    .joined(separator: ", ")
                                Text("Unsupported pointer formats: \(values)")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }

                            ForEach(fixupPlan.notes, id: \.self) {
                                Text($0)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Section("Stage-2 runtime") {
                        Button("Load guest + apply fixups") {
                            loadGuest(image)
                        }
                        .disabled(fixupPlan?.canApplyStage1 != true)

                        if let guestSpace, let appliedFixups {
                            row("Guest base", String(format: "0x%llX", guestSpace.guestBase))
                            row("Guest end", String(format: "0x%llX", guestSpace.guestEnd))
                            row("Mapped bytes", "\(guestSpace.size)")
                            row("Host base", String(describing: guestSpace.base))
                            row("Rebases applied", "\(appliedFixups.rebases)")
                            row("Binds applied", "\(appliedFixups.binds)")

                            if let plan = fixupPlan {
                                let expected = plan.supportedFixupCount
                                let actual = appliedFixups.rebases + appliedFixups.binds
                                row("Fixup verification", actual == expected ? "passed" : "\(actual)/\(expected)")
                            }

                            Text("Guest memory is now allocated as one contiguous address space and supported chained rebases/binds have been written into it.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Analyze chained fixups first, then load the guest to apply them to real mapped memory.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section("Stage-3 execution capability") {
                        Button("Run ARM64 return-42 test") {
                            jitResult = JITExecutionBackend.runReturn42SelfTest()
                        }

                        if let jitResult {
                            row("Debugger attached", jitResult.debuggerAttached ? "yes" : "no")
                            row("RW region", jitResult.regionAllocated ? "yes" : "no")
                            row("JIT26 prepared", jitResult.regionPrepared ? "yes" : "no")
                            row("Execution attempted", jitResult.executionAttempted ? "yes" : "no")
                            row("Guest execution", jitResult.executed ? "PASS" : "not executed")
                            row("Return value", jitResult.returnValue.map(String.init) ?? "—")
                            if jitResult.errnoValue != 0 {
                                row("errno", "\(jitResult.errnoValue)")
                            }
                            Text(jitResult.note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text("On M2/iOS 27, launch through LiveContainer with JIT and use darwinbridge-universal.js as the JIT Launch Script, then run this test.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Section("Stage-4 macOS runtime") {
                        Button("Probe libSystem compatibility") {
                            runtimeReport = RuntimeCompatibility.probeCoreRuntime()
                        }

                        if let runtimeReport {
                            row("Resolved symbols", "\(runtimeReport.resolvedCount)/\(runtimeReport.totalCount)")
                            row("Core libc ready", runtimeReport.coreReady ? "yes" : "no")

                            ForEach(runtimeReport.probes) { probe in
                                HStack {
                                    Text(probe.symbol).monospaced().font(.caption)
                                    Spacer()
                                    Text(probe.resolved ? "resolved" : "missing")
                                        .font(.caption)
                                        .foregroundStyle(probe.resolved ? Color.secondary : Color.orange)
                                }
                            }
                        }

                        Button("Run guest → strlen test") {
                            runtimeCallResult = JITExecutionBackend.runStrlenRuntimeTest()
                        }

                        if let runtimeCallResult {
                            row("Debugger", runtimeCallResult.debuggerAttached ? "yes" : "no")
                            row("JIT region", runtimeCallResult.regionPrepared ? "yes" : "no")
                            row("Guest call", runtimeCallResult.executed ? "executed" : "not executed")
                            row("strlen result", runtimeCallResult.returnValue.map(String.init) ?? "—")
                            row("Expected", "\(runtimeCallResult.expectedValue)")
                            row("Runtime ABI", runtimeCallResult.returnValue == runtimeCallResult.expectedValue ? "PASS" : "not passed")
                            Text(runtimeCallResult.note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Button("Run malloc → memcpy → strlen → free") {
                            runtimeChainResult = JITExecutionBackend.runRuntimeChainTest()
                        }

                        if let runtimeChainResult {
                            row("Runtime chain", runtimeChainResult.executed ? "executed" : "not executed")
                            row("Chain result", runtimeChainResult.returnValue.map(String.init) ?? "—")
                            row("Expected", "\(runtimeChainResult.expectedValue)")
                            row("Chain ABI", runtimeChainResult.returnValue == runtimeChainResult.expectedValue ? "PASS" : "not passed")
                            Text(runtimeChainResult.note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text("This stage verifies that ARM64 guest code can call selected iOS libSystem/libc symbols using the native AArch64 ABI.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Section("Stage-5 AppKit → UIKit") {
                        Button("Guest create NSWindow / NSView") {
                            appKitBridgeResult = JITExecutionBackend.runAppKitWindowBridgeTest()
                        }

                        if let appKitBridgeResult {
                            row("Debugger", appKitBridgeResult.debuggerAttached ? "yes" : "no")
                            row("JIT region", appKitBridgeResult.regionPrepared ? "yes" : "no")
                            row("Guest executed", appKitBridgeResult.guestExecuted ? "yes" : "no")
                            row("Bridge return", appKitBridgeResult.bridgeReturnValue.map(String.init) ?? "—")
                            row("AppKit bridge", appKitBridgeResult.passed ? "PASS" : "not passed")
                            Text(appKitBridgeResult.note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Button("Dismiss guest windows") {
                            Task { @MainActor in
                                AppKitUIKitBridge.shared.dismissAllGuestWindows()
                            }
                        }

                        Text("NSWindow and NSView are represented by UIKit-backed host objects. This is a facade/translation layer, not binary AppKit itself.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let fixupPlan, !fixupPlan.resolutions.isEmpty {
                        Section("Symbol broker") {
                            ForEach(fixupPlan.resolutions) { symbol in
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(symbol.name)
                                        .font(.caption)
                                        .monospaced()
                                    Text(symbol.dependencyPath ?? "unknown library")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(symbol.address.map { String(format: "0x%llX", $0) } ?? "unresolved")
                                        .font(.caption2)
                                        .monospaced()
                                }
                            }
                        }
                    }
                }

                if let report {
                    Section("Compatibility") {
                        row("Score", "\(report.score)/100")
                        row("Execution candidate", report.executableCandidate ? "yes" : "no")
                    }

                    if !report.blockers.isEmpty {
                        Section("Blockers") {
                            ForEach(report.blockers, id: \.self) {
                                Text($0)
                            }
                        }
                    }

                    if !report.warnings.isEmpty {
                        Section("Warnings") {
                            ForEach(report.warnings, id: \.self) {
                                Text($0)
                            }
                        }
                    }

                    Section("Framework map") {
                        ForEach(report.assessments) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.dependency.path)
                                    .font(.caption)
                                    .monospaced()
                                Text(item.disposition.rawValue)
                                    .font(.subheadline)
                                    .bold()
                                if let replacement = item.replacement {
                                    Text("→ \(replacement)")
                                        .font(.caption)
                                }
                                Text(item.note)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                if let errorText {
                    Section("Error") {
                        Text(errorText)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("DarwinBridge")
            .fileImporter(isPresented: $importing,
                          allowedContentTypes: [.item],
                          allowsMultipleSelection: false) { result in
                do {
                    guard let url = try result.get().first else { return }
                    let scoped = url.startAccessingSecurityScopedResource()
                    defer {
                        if scoped { url.stopAccessingSecurityScopedResource() }
                    }

                    let data = try Data(contentsOf: url, options: .mappedIfSafe)
                    let parsed = try MachOParser.parse(data)

                    fileName = url.lastPathComponent
                    image = parsed
                    report = CompatibilityAnalyzer.analyze(parsed)
                    importedData = data
                    errorText = nil
                    mappedSummary = nil
                    mappedImage = nil
                    fixupPlan = nil
                    guestSpace = nil
                    appliedFixups = nil
                } catch {
                    errorText = error.localizedDescription
                    image = nil
                    report = nil
                    importedData = nil
                    mappedImage = nil
                    fixupPlan = nil
                    guestSpace = nil
                    appliedFixups = nil
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ name: String, _ value: String) -> some View {
        HStack {
            Text(name)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .monospaced()
        }
    }

    private func map(_ image: MachOImageInfo) {
        do {
            guard let importedData else { return }
            let mapped = try MachOLoader.mapForInspection(data: importedData, image: image)
            mappedImage = mapped
            mappedSummary = "mapped \(mapped.regions.count) regions; entry=\(mapped.entryAddress.map { String(describing: $0) } ?? "unresolved")"
            errorText = nil
        } catch {
            mappedImage = nil
            errorText = error.localizedDescription
        }
    }

    private func analyzeFixups(_ image: MachOImageInfo) {
        do {
            guard let importedData else { return }
            fixupPlan = try FixupPlanner.make(data: importedData, image: image)
            guestSpace = nil
            appliedFixups = nil
            errorText = nil
        } catch {
            fixupPlan = nil
            guestSpace = nil
            appliedFixups = nil
            errorText = error.localizedDescription
        }
    }

    private func loadGuest(_ image: MachOImageInfo) {
        do {
            guard let importedData, let fixupPlan else { return }
            let space = try GuestAddressSpace(data: importedData, image: image)
            let applied = try FixupApplier.apply(plan: fixupPlan, to: space)
            guestSpace = space
            appliedFixups = applied
            errorText = nil
        } catch {
            guestSpace = nil
            appliedFixups = nil
            errorText = error.localizedDescription
        }
    }
}
