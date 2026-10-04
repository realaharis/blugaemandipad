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

@_silgen_name("DBJIT26CreateDualMapping")
private func DBJIT26CreateDualMapping(
    _ size: Int,
    _ outRX: UnsafeMutablePointer<UnsafeMutableRawPointer?>,
    _ outRW: UnsafeMutablePointer<UnsafeMutableRawPointer?>
) -> Int32

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
                note: "No live debugger is attached. Launch with LiveContainer JIT and the DarwinBridge universal script."
            )
        }

        let size = Int(getpagesize())
        var rx: UnsafeMutableRawPointer?
        var rw: UnsafeMutableRawPointer?
        let status = DBJIT26CreateDualMapping(size, &rx, &rw)

        guard status == 0, let executable = rx, let writable = rw else {
            return JITExecutionResult(
                debuggerAttached: true,
                regionAllocated: false,
                regionPrepared: false,
                executionAttempted: false,
                executed: false,
                returnValue: nil,
                errnoValue: status,
                note: "The debugger did not provide a usable RX region or vm_remap could not create its RW alias."
            )
        }

        // Write through RW alias; execute through debugger-created RX mapping.
        let instructions: [UInt32] = [0x52800540, 0xD65F03C0] // mov w0,#42 ; ret
        _ = instructions.withUnsafeBytes { bytes in
            memcpy(writable, bytes.baseAddress!, bytes.count)
        }

        typealias GuestFunction = @convention(c) () -> Int32
        let function = unsafeBitCast(executable, to: GuestFunction.self)
        let value = function()

        // Do NOT detach the debugger. TXM/SPTM executable permission is tied to
        // the live debug session. The tiny mappings intentionally remain alive.
        return JITExecutionResult(
            debuggerAttached: true,
            regionAllocated: true,
            regionPrepared: true,
            executionAttempted: true,
            executed: true,
            returnValue: value,
            errnoValue: 0,
            note: "Debugger-created RX memory executed through a writable vm_remap alias and returned normally."
        )
    }

    private static func isDebuggerAttached() -> Bool {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]

        let result = mib.withUnsafeMutableBufferPointer { ptr in
            sysctl(ptr.baseAddress, 4, &info, &size, nil, 0)
        }
        guard result == 0 else { return false }
        return (info.kp_proc.p_flag & P_TRACED) != 0
    }
}
