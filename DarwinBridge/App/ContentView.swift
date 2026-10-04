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
                    }

                    Section("Stage-0 loader") {
                        Button("Map segments for inspection") { map(image) }
                            .disabled(!image.isArm64 || image.encrypted)

                        if let mappedSummary {
                            Text(mappedSummary)
                                .font(.caption)
                                .monospaced()
                        }

                        Text("Guest execution stays disabled until rebasing, symbol binding and executable mappings are implemented.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let report {
                    Section("Compatibility") {
                        row("Score", "\(report.score)/100")
                        row("Execution candidate", report.executableCandidate ? "yes" : "no")
                    }

                    if !report.blockers.isEmpty {
                        Section("Blockers") {
                            ForEach(report.blockers, id: \.self) { Text($0) }
                        }
                    }

                    if !report.warnings.isEmpty {
                        Section("Warnings") {
                            ForEach(report.warnings, id: \.self) { Text($0) }
                        }
                    }

                    Section("Framework map") {
                        ForEach(report.assessments) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.dependency.path).font(.caption).monospaced()
                                Text(item.disposition.rawValue).font(.subheadline).bold()
                                if let replacement = item.replacement {
                                    Text("→ \(replacement)").font(.caption)
                                }
                                Text(item.note).font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                if let errorText {
                    Section("Error") {
                        Text(errorText).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("DarwinBridge")
            .fileImporter(isPresented: $importing, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
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
                } catch {
                    errorText = error.localizedDescription
                    image = nil
                    report = nil
                    importedData = nil
                    mappedImage = nil
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ name: String, _ value: String) -> some View {
        HStack {
            Text(name)
            Spacer()
            Text(value).foregroundStyle(.secondary).monospaced()
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
}
