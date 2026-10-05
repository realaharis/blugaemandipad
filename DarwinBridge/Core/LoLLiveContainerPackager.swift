import Foundation

enum LoLLiveContainerPackageError: Error, LocalizedError {
    case malformed(String)
    case pluginMissing
    case unsupportedDependency(String)

    var errorDescription: String? {
        switch self {
        case .malformed(let message): return "LoL package error: \(message)"
        case .pluginMissing: return "DarwinBridgeLCPlugin.dylib is not embedded in this DarwinBridge build."
        case .unsupportedDependency(let path): return "Dependency path is too short to redirect safely: \(path)"
        }
    }
}

struct LoLLiveContainerPackageResult {
    let ipaURL: URL
    let patchedDependencies: [String]
    let executableBytes: Int
    let pluginBytes: Int
}

struct LoLLiveContainerPackager {
    private static let lcLoadDylib: UInt32 = 0x0C
    private static let lcLoadWeakDylib: UInt32 = 0x80000018
    private static let lcReexportDylib: UInt32 = 0x8000001F
    private static let lcLoadUpwardDylib: UInt32 = 0x80000023
    private static let lcBuildVersion: UInt32 = 0x32
    private static let lcVersionMinMacOSX: UInt32 = 0x24
    private static let lcVersionMinIPhoneOS: UInt32 = 0x25

    static func buildMinimalIPA(executable source: Data,
                                displayName: String = "League of Legends") throws -> LoLLiveContainerPackageResult {
        var executable = try MachOParser.preferredArm64Slice(source)
        let patched = try patchForLiveContainer(&executable)

        guard let pluginURL = Bundle.main.url(forResource: "DarwinBridgeLCPlugin", withExtension: "dylib") else {
            throw LoLLiveContainerPackageError.pluginMissing
        }
        let plugin = try Data(contentsOf: pluginURL, options: .mappedIfSafe)

        let executableName = "LeagueOfLegends"
        let info = makeInfoPlist(executableName: executableName, displayName: displayName)

        var zip = StoreZipWriter()
        try zip.add(path: "Payload/LeagueOfLegends.app/Info.plist", data: info)
        try zip.add(path: "Payload/LeagueOfLegends.app/\(executableName)", data: executable)
        try zip.add(path: "Payload/LeagueOfLegends.app/Frameworks/DarwinBridgeLCPlugin.dylib", data: plugin)

        let out = FileManager.default.temporaryDirectory
            .appendingPathComponent("DarwinBridge-LoL-first-run.ipa")
        try zip.finalize().write(to: out, options: .atomic)

        return LoLLiveContainerPackageResult(ipaURL: out,
                                             patchedDependencies: patched,
                                             executableBytes: executable.count,
                                             pluginBytes: plugin.count)
    }

    private static func patchForLiveContainer(_ data: inout Data) throws -> [String] {
        guard data.count >= 32, try u32(data, 0) == MachOParser.mhMagic64 else {
            throw LoLLiveContainerPackageError.malformed("not a thin 64-bit Mach-O")
        }

        let ncmds = Int(try u32(data, 16))
        var cursor = 32
        var patchedDependencies: [String] = []

        for _ in 0..<ncmds {
            guard cursor + 8 <= data.count else {
                throw LoLLiveContainerPackageError.malformed("truncated load commands")
            }

            let cmd = try u32(data, cursor)
            let cmdsize = Int(try u32(data, cursor + 4))
            guard cmdsize >= 8, cursor + cmdsize <= data.count else {
                throw LoLLiveContainerPackageError.malformed("invalid load command")
            }

            if cmd == lcBuildVersion {
                guard cmdsize >= 24 else {
                    throw LoLLiveContainerPackageError.malformed("short LC_BUILD_VERSION")
                }
                put32(&data, cursor + 8, 2) // PLATFORM_IOS
                put32(&data, cursor + 12, version(17, 0, 0))
                put32(&data, cursor + 16, version(17, 0, 0))
            } else if cmd == lcVersionMinMacOSX {
                // version_min_command has the same 16-byte layout on iOS.
                put32(&data, cursor, lcVersionMinIPhoneOS)
                if cmdsize >= 16 {
                    put32(&data, cursor + 8, version(17, 0, 0))
                    put32(&data, cursor + 12, version(17, 0, 0))
                }
            } else if cmd == lcLoadDylib || cmd == lcLoadWeakDylib ||
                        cmd == lcReexportDylib || cmd == lcLoadUpwardDylib {
                guard cmdsize >= 24 else {
                    throw LoLLiveContainerPackageError.malformed("short dylib command")
                }
                let nameOffset = Int(try u32(data, cursor + 8))
                guard nameOffset >= 8, nameOffset < cmdsize else {
                    throw LoLLiveContainerPackageError.malformed("bad dylib name offset")
                }
                let start = cursor + nameOffset
                let end = cursor + cmdsize
                let current = cString(data, start, end)

                if shouldRedirect(current) {
                    let replacement = "@loader_path/Frameworks/DarwinBridgeLCPlugin.dylib"
                    let capacity = end - start
                    guard replacement.utf8.count + 1 <= capacity else {
                        throw LoLLiveContainerPackageError.unsupportedDependency(current)
                    }
                    for i in start..<end { data[i] = 0 }
                    for (index, byte) in replacement.utf8.enumerated() {
                        data[start + index] = byte
                    }
                    patchedDependencies.append(current)
                }
            }

            cursor += cmdsize
        }

        return patchedDependencies
    }

    private static func shouldRedirect(_ path: String) -> Bool {
        let p = path.lowercased()
        return p.contains("appkit.framework") ||
               p.contains("coreservices.framework") ||
               p.contains("cocoa.framework") ||
               p.contains("scriptingbridge.framework") ||
               p.contains("diskarbitration.framework")
    }

    private static func makeInfoPlist(executableName: String, displayName: String) -> Data {
        let object: [String: Any] = [
            "CFBundleDevelopmentRegion": "en",
            "CFBundleDisplayName": displayName,
            "CFBundleExecutable": executableName,
            "CFBundleIdentifier": "com.darwinbridge.lol.firstrun",
            "CFBundleInfoDictionaryVersion": "6.0",
            "CFBundleName": displayName,
            "CFBundlePackageType": "APPL",
            "CFBundleShortVersionString": "1.0",
            "CFBundleVersion": "1",
            "LSRequiresIPhoneOS": true,
            "MinimumOSVersion": "17.0",
            "UIDeviceFamily": [1, 2],
            "UIRequiredDeviceCapabilities": ["arm64"],
            "UISupportedInterfaceOrientations": [
                "UIInterfaceOrientationLandscapeLeft",
                "UIInterfaceOrientationLandscapeRight",
                "UIInterfaceOrientationPortrait"
            ],
            "UILaunchScreen": [:]
        ]
        return try! PropertyListSerialization.data(fromPropertyList: object,
                                                   format: .xml,
                                                   options: 0)
    }

    private static func version(_ major: UInt32, _ minor: UInt32, _ patch: UInt32) -> UInt32 {
        (major << 16) | (minor << 8) | patch
    }

    private static func u32(_ data: Data, _ offset: Int) throws -> UInt32 {
        guard offset + 4 <= data.count else {
            throw LoLLiveContainerPackageError.malformed("read past EOF")
        }
        return data[offset..<offset+4].enumerated().reduce(UInt32(0)) {
            $0 | (UInt32($1.element) << UInt32($1.offset * 8))
        }
    }

    private static func put32(_ data: inout Data, _ offset: Int, _ value: UInt32) {
        for i in 0..<4 {
            data[offset + i] = UInt8((value >> UInt32(i * 8)) & 0xff)
        }
    }

    private static func cString(_ data: Data, _ start: Int, _ end: Int) -> String {
        guard start < end, start < data.count else { return "" }
        let bytes = data[start..<min(end, data.count)]
        return String(bytes: bytes.prefix { $0 != 0 }, encoding: .utf8) ?? ""
    }
}

private struct StoreZipWriter {
    private struct Entry {
        let path: String
        let crc: UInt32
        let size: UInt32
        let offset: UInt32
    }

    private var data = Data()
    private var entries: [Entry] = []

    mutating func add(path: String, data payload: Data) throws {
        let name = Data(path.utf8)
        guard payload.count <= Int(UInt32.max), self.data.count <= Int(UInt32.max) else {
            throw LoLLiveContainerPackageError.malformed("minimal IPA exceeds ZIP32 limits")
        }

        let crc = CRC32.compute(payload)
        let offset = UInt32(self.data.count)
        append32(0x04034b50)
        append16(20)
        append16(0)
        append16(0) // store
        append16(0)
        append16(0)
        append32(crc)
        append32(UInt32(payload.count))
        append32(UInt32(payload.count))
        append16(UInt16(name.count))
        append16(0)
        self.data.append(name)
        self.data.append(payload)

        entries.append(Entry(path: path,
                             crc: crc,
                             size: UInt32(payload.count),
                             offset: offset))
    }

    mutating func finalize() -> Data {
        let centralOffset = UInt32(data.count)

        for entry in entries {
            let name = Data(entry.path.utf8)
            append32(0x02014b50)
            append16(20)
            append16(20)
            append16(0)
            append16(0)
            append16(0)
            append16(0)
            append32(entry.crc)
            append32(entry.size)
            append32(entry.size)
            append16(UInt16(name.count))
            append16(0)
            append16(0)
            append16(0)
            append16(0)
            append32(0)
            append32(entry.offset)
            data.append(name)
        }

        let centralSize = UInt32(data.count) - centralOffset
        append32(0x06054b50)
        append16(0)
        append16(0)
        append16(UInt16(entries.count))
        append16(UInt16(entries.count))
        append32(centralSize)
        append32(centralOffset)
        append16(0)
        return data
    }

    private mutating func append16(_ value: UInt16) {
        data.append(UInt8(value & 0xff))
        data.append(UInt8((value >> 8) & 0xff))
    }

    private mutating func append32(_ value: UInt32) {
        for i in 0..<4 {
            data.append(UInt8((value >> UInt32(i * 8)) & 0xff))
        }
    }
}

private enum CRC32 {
    static let table: [UInt32] = (0..<256).map { index in
        var crc = UInt32(index)
        for _ in 0..<8 {
            crc = (crc & 1) != 0 ? (0xEDB88320 ^ (crc >> 1)) : (crc >> 1)
        }
        return crc
    }

    static func compute(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            let idx = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = table[idx] ^ (crc >> 8)
        }
        return crc ^ 0xFFFFFFFF
    }
}
