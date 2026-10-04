import Foundation

struct MachOSegment: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let vmAddress: UInt64
    let vmSize: UInt64
    let fileOffset: UInt64
    let fileSize: UInt64
    let maxProtection: Int32
    let initialProtection: Int32
}

struct MachODependency: Identifiable, Hashable {
    let id = UUID()
    let path: String
    let weak: Bool
    let reexported: Bool
}

struct MachOImageInfo {
    let cpuType: Int32
    let cpuSubtype: Int32
    let fileType: UInt32
    let commands: UInt32
    let flags: UInt32
    let entryOffset: UInt64?
    let platform: UInt32?
    let minimumOS: String?
    let sdk: String?
    let encrypted: Bool
    let segments: [MachOSegment]
    let dependencies: [MachODependency]
    let rpaths: [String]

    var isArm64: Bool { cpuType == 0x0100000C }
}

enum ShimDisposition: String {
    case native = "Native iOS framework"
    case shim = "Compatibility shim required"
    case partial = "Partial / risky"
    case blocked = "Currently blocked"
    case unknown = "Unknown"
}

struct DependencyAssessment: Identifiable {
    let id = UUID()
    let dependency: MachODependency
    let disposition: ShimDisposition
    let replacement: String?
    let note: String
}

struct CompatibilityReport {
    let score: Int
    let executableCandidate: Bool
    let blockers: [String]
    let warnings: [String]
    let assessments: [DependencyAssessment]
}
