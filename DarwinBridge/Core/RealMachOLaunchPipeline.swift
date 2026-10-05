import Foundation
import Darwin

struct RealMachOPreflight {
    let ready: Bool
    let entryGuestAddress: UInt64?
    let entryHostAddress: UInt64?
    let unresolvedImports: Int
    let executableSegment: String?
    let notes: [String]
}

struct RealMachOLaunchPipeline {
    static func preflight(image: MachOImageInfo,
                          guestSpace: GuestAddressSpace?,
                          fixupPlan: FixupPlan?,
                          appliedFixups: AppliedFixups?) -> RealMachOPreflight {
        var notes: [String] = []

        guard image.isArm64 else {
            return RealMachOPreflight(ready: false,
                                      entryGuestAddress: nil,
                                      entryHostAddress: nil,
                                      unresolvedImports: fixupPlan?.unresolvedBindCount ?? 0,
                                      executableSegment: nil,
                                      notes: ["Target is not ARM64."])
        }

        guard !image.encrypted else {
            return RealMachOPreflight(ready: false,
                                      entryGuestAddress: nil,
                                      entryHostAddress: nil,
                                      unresolvedImports: fixupPlan?.unresolvedBindCount ?? 0,
                                      executableSegment: nil,
                                      notes: ["Encrypted Mach-O execution is not supported."])
        }

        guard let entryOffset = image.entryOffset else {
            return RealMachOPreflight(ready: false,
                                      entryGuestAddress: nil,
                                      entryHostAddress: nil,
                                      unresolvedImports: fixupPlan?.unresolvedBindCount ?? 0,
                                      executableSegment: nil,
                                      notes: ["LC_MAIN entry point is missing."])
        }

        guard let text = image.segments.first(where: {
            $0.name == "__TEXT" && $0.fileSize > 0
        }) else {
            return RealMachOPreflight(ready: false,
                                      entryGuestAddress: nil,
                                      entryHostAddress: nil,
                                      unresolvedImports: fixupPlan?.unresolvedBindCount ?? 0,
                                      executableSegment: nil,
                                      notes: ["__TEXT segment is missing."])
        }

        guard entryOffset < text.fileSize else {
            return RealMachOPreflight(ready: false,
                                      entryGuestAddress: nil,
                                      entryHostAddress: nil,
                                      unresolvedImports: fixupPlan?.unresolvedBindCount ?? 0,
                                      executableSegment: text.name,
                                      notes: ["LC_MAIN entry offset lies outside __TEXT file bytes."])
        }

        let entryGuest = text.vmAddress + entryOffset
        guard let guestSpace,
              let entryHost = guestSpace.hostPointer(for: entryGuest, byteCount: 4) else {
            return RealMachOPreflight(ready: false,
                                      entryGuestAddress: entryGuest,
                                      entryHostAddress: nil,
                                      unresolvedImports: fixupPlan?.unresolvedBindCount ?? 0,
                                      executableSegment: text.name,
                                      notes: ["Load guest + apply fixups before real entry-point bring-up."])
        }

        let unresolved = fixupPlan?.unresolvedBindCount ?? 0
        if unresolved > 0 {
            notes.append("\(unresolved) imported bind(s) remain unresolved.")
        }

        if appliedFixups == nil {
            notes.append("Fixups have not been applied to guest memory.")
        }

        // Do not jump directly into the RW guest mapping yet. iPadOS 27/TXM
        // requires executable pages to be provisioned through the JIT26 path.
        notes.append("Entry point located. Next step is copying executable __TEXT into a debugger-provisioned RX/RW dual mapping before transfer of control.")

        return RealMachOPreflight(ready: unresolved == 0 && appliedFixups != nil,
                                  entryGuestAddress: entryGuest,
                                  entryHostAddress: UInt64(UInt(bitPattern: entryHost)),
                                  unresolvedImports: unresolved,
                                  executableSegment: text.name,
                                  notes: notes)
    }
}
