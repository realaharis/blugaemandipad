import Foundation

// Stage 21X-B policy: resolve the whole harvested compatibility surface in one pass.
// This analyzer no longer carries a hand-maintained 20-symbol allowlist.
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
        let items = unresolved.map { item -> LoLShimCoverageItem in
            if LoLRuntimeShimRegistry.pointer(for: item.name) != nil {
                return .init(symbol: item.name,
                             category: item.dependencyPath ?? "batch shim",
                             strategy: "Stage 21X harvested batch compatibility registry",
                             covered: true)
            }
            if LoLRuntimeShimRegistry.isIntraImageWeak(item) {
                return .init(symbol: item.name,
                             category: "self/weak",
                             strategy: "intra-image / weak resolution",
                             covered: true)
            }
            let assessment = plan.assessments.first { $0.dependency.path == item.dependencyPath }
            return .init(symbol: item.name,
                         category: item.dependencyPath ?? "unknown",
                         strategy: assessment?.replacement ?? "unresolved after batch classification",
                         covered: false)
        }

        let covered = items.filter(\.covered).count
        let projectedResolved = scan.resolvedCount + covered
        let projected = scan.imports.isEmpty ? 0 :
            Int((Double(projectedResolved) / Double(scan.imports.count) * 100.0).rounded())

        return LoLShimCoverageReport(items: items,
                                     coveredCount: covered,
                                     totalCount: items.count,
                                     projectedCoveragePercent: projected,
                                     remaining: items.filter { !$0.covered }.map(\.symbol).sorted())
    }
}
