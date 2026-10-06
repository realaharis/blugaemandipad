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
    private static let lcIdDylib: UInt32 = 0x0D
    private static let lcLoadWeakDylib: UInt32 = 0x80000018
    private static let lcReexportDylib: UInt32 = 0x8000001F
    private static let lcLoadUpwardDylib: UInt32 = 0x80000023
    private static let lcBuildVersion: UInt32 = 0x32
    private static let lcVersionMinMacOSX: UInt32 = 0x24
    private static let lcVersionMinIPhoneOS: UInt32 = 0x25

    static func buildMinimalIPA(executable source: Data,
                                displayName: String = "League of Legends") throws -> LoLLiveContainerPackageResult {
        var executable = try MachOParser.preferredArm64Slice(source)
        let redirects = try patchForLiveContainer(&executable)
        try injectBootstrapLoadCommand(&executable,
                                       path: "@executable_path/Frameworks/DBBootstrap.dylib")

        guard let pluginURL = Bundle.main.url(forResource: "DarwinBridgeLCPlugin", withExtension: "dylib") else {
            throw LoLLiveContainerPackageError.pluginMissing
        }
        let plugin = try Data(contentsOf: pluginURL, options: .mappedIfSafe)

        let executableName = "LeagueOfLegends"
        let info = makeInfoPlist(executableName: executableName, displayName: displayName)

        var zip = StoreZipWriter()
        try zip.add(path: "Payload/LeagueOfLegends.app/Info.plist", data: info)
        try zip.add(path: "Payload/LeagueOfLegends.app/\(executableName)", data: executable)
        let bootstrap = try pluginWithInstallName(plugin, "@rpath/DBBootstrap.dylib")
        try zip.add(path: "Payload/LeagueOfLegends.app/Frameworks/DBBootstrap.dylib",
                    data: bootstrap)

        // Keep each redirected dependency at a distinct dylib ordinal. dyld may
        // coalesce duplicate load paths, which would shift the original Mach-O
        // library ordinals and make BIND_OPCODE_DO_BIND fail. Each compatibility
        // alias gets its own LC_ID_DYLIB and filename while exporting the same
        // DarwinBridge compatibility symbols.
        for redirect in redirects {
            guard let fileName = redirect.fileName,
                  let installName = redirect.installName else { continue }
            let aliasedPlugin = try pluginWithInstallName(plugin, installName)
            try zip.add(path: "Payload/LeagueOfLegends.app/Frameworks/\(fileName)",
                        data: aliasedPlugin)
        }

        let out = FileManager.default.temporaryDirectory
            .appendingPathComponent("DarwinBridge-LoL-first-run.ipa")
        try zip.finalize().write(to: out, options: .atomic)

        return LoLLiveContainerPackageResult(ipaURL: out,
                                             patchedDependencies: redirects.map(\.originalPath),
                                             executableBytes: executable.count,
                                             pluginBytes: plugin.count)
    }

    private struct DependencyRedirect {
        let originalPath: String
        let replacementPath: String
        let fileName: String?
        let installName: String?
    }

    private static func patchForLiveContainer(_ data: inout Data) throws -> [DependencyRedirect] {
        guard data.count >= 32, try u32(data, 0) == MachOParser.mhMagic64 else {
            throw LoLLiveContainerPackageError.malformed("not a thin 64-bit Mach-O")
        }

        let ncmds = Int(try u32(data, 16))
        var cursor = 32
        var redirects: [DependencyRedirect] = []

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

                if let redirect = dependencyRedirect(for: current) {
                    let replacement = redirect.replacementPath
                    let capacity = end - start
                    guard replacement.utf8.count + 1 <= capacity else {
                        throw LoLLiveContainerPackageError.unsupportedDependency(current)
                    }
                    for i in start..<end { data[i] = 0 }
                    for (index, byte) in replacement.utf8.enumerated() {
                        data[start + index] = byte
                    }
                    redirects.append(redirect)
                }
            }

            cursor += cmdsize
        }

        return redirects
    }

    private static func injectBootstrapLoadCommand(_ data: inout Data,
                                                   path: String) throws {
        // Add a real LC_LOAD_DYLIB without moving any existing segment bytes.
        // Mach-O executables normally have padding between the load-command table
        // and the first section. We consume only verified zero padding.
        guard data.count >= 32, try u32(data, 0) == MachOParser.mhMagic64 else {
            throw LoLLiveContainerPackageError.malformed("bootstrap injection requires thin Mach-O 64")
        }

        let ncmds = Int(try u32(data, 16))
        let sizeofcmds = Int(try u32(data, 20))
        let commandsEnd = 32 + sizeofcmds
        guard commandsEnd <= data.count else {
            throw LoLLiveContainerPackageError.malformed("load command table exceeds file during bootstrap injection")
        }

        var cursor = 32
        var firstFileData = data.count
        for _ in 0..<ncmds {
            guard cursor + 8 <= commandsEnd else {
                throw LoLLiveContainerPackageError.malformed("truncated load command during bootstrap injection")
            }
            let cmd = try u32(data, cursor)
            let cmdsize = Int(try u32(data, cursor + 4))
            guard cmdsize >= 8, cursor + cmdsize <= commandsEnd else {
                throw LoLLiveContainerPackageError.malformed("invalid load command during bootstrap injection")
            }
            if cmd == 0x19, cmdsize >= 72 { // LC_SEGMENT_64
                let fileoff = try u64(data, cursor + 40)
                let filesize = try u64(data, cursor + 48)
                if filesize > 0, fileoff > 0, fileoff <= UInt64(Int.max) {
                    firstFileData = min(firstFileData, Int(fileoff))
                }
                let nsects = Int(try u32(data, cursor + 64))
                var section = cursor + 72
                for _ in 0..<nsects {
                    guard section + 80 <= cursor + cmdsize else { break }
                    let offset = Int(try u32(data, section + 48))
                    let size = try u64(data, section + 40)
                    if size > 0, offset > 0 {
                        firstFileData = min(firstFileData, offset)
                    }
                    section += 80
                }
            }
            cursor += cmdsize
        }

        let nameBytes = Array(path.utf8) + [0]
        let rawSize = 24 + nameBytes.count
        let cmdsize = (rawSize + 7) & ~7
        guard commandsEnd + cmdsize <= firstFileData,
              commandsEnd + cmdsize <= data.count else {
            throw LoLLiveContainerPackageError.malformed(
                "not enough Mach-O header padding for forced bootstrap LC_LOAD_DYLIB"
            )
        }

        // Never overwrite meaningful bytes in header padding.
        guard data[commandsEnd..<(commandsEnd + cmdsize)].allSatisfy({ $0 == 0 }) else {
            throw LoLLiveContainerPackageError.malformed(
                "bootstrap load-command padding is not empty"
            )
        }

        put32(&data, commandsEnd, lcLoadDylib)
        put32(&data, commandsEnd + 4, UInt32(cmdsize))
        put32(&data, commandsEnd + 8, 24) // dylib.name offset
        put32(&data, commandsEnd + 12, 0) // timestamp
        put32(&data, commandsEnd + 16, 0) // current_version
        put32(&data, commandsEnd + 20, 0) // compatibility_version
        for (index, byte) in nameBytes.enumerated() {
            data[commandsEnd + 24 + index] = byte
        }
        for index in (commandsEnd + rawSize)..<(commandsEnd + cmdsize) {
            data[index] = 0
        }

        put32(&data, 16, UInt32(ncmds + 1))
        put32(&data, 20, UInt32(sizeofcmds + cmdsize))

        // Verify our own mutation before producing the IPA.
        var verifyCursor = 32
        var found = false
        for _ in 0..<(ncmds + 1) {
            let cmd = try u32(data, verifyCursor)
            let size = Int(try u32(data, verifyCursor + 4))
            guard size >= 8, verifyCursor + size <= 32 + sizeofcmds + cmdsize else {
                throw LoLLiveContainerPackageError.malformed("bootstrap verification found invalid load command")
            }
            if cmd == lcLoadDylib, size >= 24 {
                let off = Int(try u32(data, verifyCursor + 8))
                if off >= 8, off < size,
                   cString(data, verifyCursor + off, verifyCursor + size) == path {
                    found = true
                }
            }
            verifyCursor += size
        }
        guard found else {
            throw LoLLiveContainerPackageError.malformed("forced bootstrap LC_LOAD_DYLIB verification failed")
        }
    }

    private static func dependencyRedirect(for path: String) -> DependencyRedirect? {
        let p = path.lowercased()

        func shim(_ fileName: String) -> DependencyRedirect {
            DependencyRedirect(
                originalPath: path,
                replacementPath: "@loader_path/Frameworks/\(fileName)",
                fileName: fileName,
                installName: "@rpath/\(fileName)"
            )
        }

        func native(_ framework: String) -> DependencyRedirect {
            DependencyRedirect(
                originalPath: path,
                replacementPath: "/System/Library/Frameworks/\(framework).framework/\(framework)",
                fileName: nil,
                installName: nil
            )
        }

        // Desktop-only frameworks still route to DarwinBridge shims.
        if p.contains("appkit.framework") { return shim("DBAppKit.dylib") }
        if p.contains("coreservices.framework") { return shim("DBCoreServices.dylib") }
        if p.contains("cocoa.framework") { return shim("DBCocoa.dylib") }
        if p.contains("scriptingbridge.framework") { return shim("DBScriptingBridge.dylib") }
        if p.contains("diskarbitration.framework") { return shim("DBDiskArbitration.dylib") }
        if p.contains("iokit.framework") { return shim("DBIOKit.dylib") }

        // The macOS client can import desktop-only Objective-C classes from
        // otherwise shared frameworks (for example NSAppleEventManager from
        // Foundation). Route those ordinals through distinct compatibility
        // aliases. DarwinBridgeLCPlugin re-exports the corresponding native iOS
        // frameworks, so ordinary symbols flow through while desktop-only
        // additions are supplied by the shim.
        if p.contains("avfoundation.framework") { return shim("DBAVFoundation.dylib") }
        if p.contains("cfnetwork.framework") { return shim("DBCFNetwork.dylib") }
        if p.contains("corefoundation.framework") { return shim("DBCoreFoundation.dylib") }
        if p.contains("coregraphics.framework") { return shim("DBCoreGraphics.dylib") }
        if p.contains("coretext.framework") { return shim("DBCoreText.dylib") }
        if p.contains("foundation.framework") { return shim("DBFoundation.dylib") }
        if p.contains("security.framework") { return shim("DBSecurity.dylib") }
        if p.contains("systemconfiguration.framework") { return shim("DBSystemConfiguration.dylib") }

        return nil
    }

    private static func pluginWithInstallName(_ source: Data,
                                              _ installName: String) throws -> Data {
        var data = source
        guard data.count >= 32, try u32(data, 0) == MachOParser.mhMagic64 else {
            throw LoLLiveContainerPackageError.malformed("compatibility plugin is not a thin 64-bit Mach-O")
        }

        let ncmds = Int(try u32(data, 16))
        var cursor = 32
        var patched = false

        for _ in 0..<ncmds {
            guard cursor + 8 <= data.count else {
                throw LoLLiveContainerPackageError.malformed("truncated plugin load commands")
            }
            let cmd = try u32(data, cursor)
            let cmdsize = Int(try u32(data, cursor + 4))
            guard cmdsize >= 8, cursor + cmdsize <= data.count else {
                throw LoLLiveContainerPackageError.malformed("invalid plugin load command")
            }

            if cmd == lcIdDylib {
                guard cmdsize >= 24 else {
                    throw LoLLiveContainerPackageError.malformed("short plugin LC_ID_DYLIB")
                }
                let nameOffset = Int(try u32(data, cursor + 8))
                let start = cursor + nameOffset
                let end = cursor + cmdsize
                guard start >= cursor + 8, start < end else {
                    throw LoLLiveContainerPackageError.malformed("invalid plugin install-name offset")
                }
                guard installName.utf8.count + 1 <= end - start else {
                    throw LoLLiveContainerPackageError.unsupportedDependency(installName)
                }
                for i in start..<end { data[i] = 0 }
                for (index, byte) in installName.utf8.enumerated() {
                    data[start + index] = byte
                }
                patched = true
                break
            }
            cursor += cmdsize
        }

        guard patched else {
            throw LoLLiveContainerPackageError.malformed("compatibility plugin has no LC_ID_DYLIB")
        }
        return data
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
            "UIFileSharingEnabled": true,
            "LSSupportsOpeningDocumentsInPlace": true,
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

    private static func u64(_ data: Data, _ offset: Int) throws -> UInt64 {
        guard offset + 8 <= data.count else {
            throw LoLLiveContainerPackageError.malformed("read past EOF")
        }
        return data[offset..<offset+8].enumerated().reduce(UInt64(0)) {
            $0 | (UInt64($1.element) << UInt64($1.offset * 8))
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
