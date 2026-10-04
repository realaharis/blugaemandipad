import Foundation
import Darwin

struct JITExecutionResult {
    let mapJITSucceeded: Bool
    let writeProtectSupported: Bool
    let executionAttempted: Bool
    let executed: Bool
    let returnValue: Int32?
    let errnoValue: Int32
    let note: String
}

struct ImportedProbeInfo {
    let entryFileOffset: UInt64
    let expectedReturnValue: Int32
    let instruction0: UInt32
    let instruction1: UInt32
}

enum JITExecutionError: Error, LocalizedError {
    case noEntryPoint
    case entryOutsideFile
    case unsupportedProbe

    var errorDescription: String? {
        switch self {
        case .noEntryPoint:
            return "LC_MAIN entry point is missing."
        case .entryOutsideFile:
            return "LC_MAIN entry point is outside the Mach-O file."
        case .unsupportedProbe:
            return "Imported entry is not the supported two-instruction return-immediate probe."
        }
    }
}

struct JITExecutionBackend {
    private static let mapJIT: Int32 = 0x800

    static func runReturn42SelfTest() -> JITExecutionResult {
        return execute(instructions: [0x52800540, 0xD65F03C0])
    }

    static func inspectImportedProbe(data: Data, image: MachOImageInfo) throws -> ImportedProbeInfo {
        guard let entry = image.entryOffset else {
            throw JITExecutionError.noEntryPoint
        }
        guard entry + 8 <= UInt64(data.count) else {
            throw JITExecutionError.entryOutsideFile
        }

        let first = readUInt32LE(data, Int(entry))
        let second = readUInt32LE(data, Int(entry + 4))

        // movz w0, #imm16 ; ret
        let movzW0Mask: UInt32 = 0xFFE0001F
        let movzW0Base: UInt32 = 0x52800000
        guard (first & movzW0Mask) == movzW0Base,
              second == 0xD65F03C0 else {
            throw JITExecutionError.unsupportedProbe
        }

        let immediate = Int32((first >> 5) & 0xFFFF)
        return ImportedProbeInfo(entryFileOffset: entry,
                                 expectedReturnValue: immediate,
                                 instruction0: first,
                                 instruction1: second)
    }

    static func runImportedProbe(data: Data, image: MachOImageInfo) throws -> JITExecutionResult {
        let probe = try inspectImportedProbe(data: data, image: image)
        return execute(instructions: [probe.instruction0, probe.instruction1])
    }

    private static func execute(instructions: [UInt32]) -> JITExecutionResult {
        let size = Int(getpagesize())
        let flags = MAP_PRIVATE | MAP_ANON | mapJIT
        guard let page = mmap(nil,
                              size,
                              PROT_READ | PROT_WRITE | PROT_EXEC,
                              flags,
                              -1,
                              0),
              page != MAP_FAILED else {
            return JITExecutionResult(mapJITSucceeded: false,
                                      writeProtectSupported: false,
                                      executionAttempted: false,
                                      executed: false,
                                      returnValue: nil,
                                      errnoValue: errno,
                                      note: "MAP_JIT allocation failed. The app likely does not currently have a usable JIT entitlement/session.")
        }
        defer { munmap(page, size) }

        guard let processHandle = dlopen(nil, RTLD_NOW) else {
            return JITExecutionResult(mapJITSucceeded: true,
                                      writeProtectSupported: false,
                                      executionAttempted: false,
                                      executed: false,
                                      returnValue: nil,
                                      errnoValue: 0,
                                      note: "MAP_JIT succeeded, but the process symbol table could not be opened.")
        }
        defer { dlclose(processHandle) }

        typealias SupportedFn = @convention(c) () -> Int32
        typealias WriteProtectFn = @convention(c) (Int32) -> Void
        typealias ICacheFn = @convention(c) (UnsafeMutableRawPointer?, Int) -> Void

        guard let supportedSymbol = dlsym(processHandle, "pthread_jit_write_protect_supported_np"),
              let protectSymbol = dlsym(processHandle, "pthread_jit_write_protect_np") else {
            return JITExecutionResult(mapJITSucceeded: true,
                                      writeProtectSupported: false,
                                      executionAttempted: false,
                                      executed: false,
                                      returnValue: nil,
                                      errnoValue: 0,
                                      note: "MAP_JIT succeeded, but pthread JIT write-protection APIs are unavailable.")
        }

        let supported = unsafeBitCast(supportedSymbol, to: SupportedFn.self)
        let writeProtect = unsafeBitCast(protectSymbol, to: WriteProtectFn.self)
        guard supported() != 0 else {
            return JITExecutionResult(mapJITSucceeded: true,
                                      writeProtectSupported: false,
                                      executionAttempted: false,
                                      executed: false,
                                      returnValue: nil,
                                      errnoValue: 0,
                                      note: "MAP_JIT succeeded, but per-thread JIT write protection is reported unsupported.")
        }

        writeProtect(0)
        instructions.withUnsafeBytes { bytes in
            memcpy(page, bytes.baseAddress!, bytes.count)
        }

        if let cacheSymbol = dlsym(processHandle, "sys_icache_invalidate") {
            let invalidate = unsafeBitCast(cacheSymbol, to: ICacheFn.self)
            invalidate(page, instructions.count * MemoryLayout<UInt32>.size)
        }

        writeProtect(1)

        typealias GuestFunction = @convention(c) () -> Int32
        let function = unsafeBitCast(page, to: GuestFunction.self)
        let value = function()

        return JITExecutionResult(mapJITSucceeded: true,
                                  writeProtectSupported: true,
                                  executionAttempted: true,
                                  executed: true,
                                  returnValue: value,
                                  errnoValue: 0,
                                  note: "ARM64 code executed from a MAP_JIT page and returned normally.")
    }

    private static func readUInt32LE(_ data: Data, _ offset: Int) -> UInt32 {
        data[offset..<offset + 4].enumerated().reduce(UInt32(0)) { result, item in
            result | (UInt32(item.element) << UInt32(item.offset * 8))
        }
    }
}
