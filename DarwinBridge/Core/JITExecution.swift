import Foundation
import Darwin

struct JITExecutionResult {
    let debuggerAttached: Bool
    let regionAllocated: Bool
    let regionPrepared: Bool
    let executionAttempted: Bool
    let executed: Bool
    let returnValue: Int32?
    let errnoValue: Int32
    let note: String
}

@_silgen_name("DBJIT26PrepareRegion")
private func DBJIT26PrepareRegion(_ address: UnsafeMutableRawPointer?, _ length: Int) -> UnsafeMutableRawPointer?

@_silgen_name("DBJIT26Detach")
private func DBJIT26Detach()

struct JITExecutionBackend {
    static func runReturn42SelfTest() -> JITExecutionResult {
        guard isDebuggerAttached() else {
            return JITExecutionResult(
                debuggerAttached: false,
                regionAllocated: false,
                regionPrepared: false,
                executionAttempted: false,
                executed: false,
                returnValue: nil,
                errnoValue: 0,
                note: "No live debugger is attached. Launch DarwinBridge with LiveContainer's Launch with JIT option and select the DarwinBridge universal JIT script."
            )
        }

        let size = Int(getpagesize())
        guard let page = mmap(nil,
                              size,
                              PROT_READ | PROT_WRITE,
                              MAP_PRIVATE | MAP_ANON,
                              -1,
                              0),
              page != MAP_FAILED else {
            return JITExecutionResult(
                debuggerAttached: true,
                regionAllocated: false,
                regionPrepared: false,
                executionAttempted: false,
                executed: false,
                returnValue: nil,
                errnoValue: errno,
                note: "RW allocation failed."
            )
        }

        // ARM64: mov w0, #42 ; ret
        var instructions: [UInt32] = [0x52800540, 0xD65F03C0]
        _ = instructions.withUnsafeBytes { bytes in
            memcpy(page, bytes.baseAddress!, bytes.count)
        }

        guard let executablePage = DBJIT26PrepareRegion(page, size) else {
            munmap(page, size)
            return JITExecutionResult(
                debuggerAttached: true,
                regionAllocated: true,
                regionPrepared: false,
                executionAttempted: false,
                executed: false,
                returnValue: nil,
                errnoValue: 0,
                note: "The debugger was attached, but the TXM/SPTM JIT script did not prepare the executable region."
            )
        }

        typealias GuestFunction = @convention(c) () -> Int32
        let function = unsafeBitCast(executablePage, to: GuestFunction.self)
        let value = function()

        // The test is complete; tell the universal script it may detach.
        DBJIT26Detach()
        munmap(page, size)

        return JITExecutionResult(
            debuggerAttached: true,
            regionAllocated: true,
            regionPrepared: true,
            executionAttempted: true,
            executed: true,
            returnValue: value,
            errnoValue: 0,
            note: "The region was prepared through the iOS 26 universal JIT protocol and ARM64 code returned normally."
        )
    }

    private static func isDebuggerAttached() -> Bool {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]

        let result = mib.withUnsafeMutableBufferPointer { mibPtr in
            sysctl(mibPtr.baseAddress, 4, &info, &size, nil, 0)
        }
        guard result == 0 else { return false }
        return (info.kp_proc.p_flag & P_TRACED) != 0
    }
}
