import Foundation

@main
struct ParserSmoke {
    static func main() throws {
        try basicMachOSmoke()
        try chainedFixupsSmoke()
        print("all DarwinBridge core smoke tests passed")
    }

    static func basicMachOSmoke() throws {
        var data = Data(repeating: 0, count: 32 + 72 + 24)

        func put32(_ offset: Int, _ value: UInt32) {
            for i in 0..<4 { data[offset + i] = UInt8((value >> UInt32(i * 8)) & 0xff) }
        }
        func put64(_ offset: Int, _ value: UInt64) {
            for i in 0..<8 { data[offset + i] = UInt8((value >> UInt64(i * 8)) & 0xff) }
        }

        put32(0, 0xFEEDFACF)
        put32(4, 0x0100000C)
        put32(12, 2)
        put32(16, 2)
        put32(20, 96)

        let seg = 32
        put32(seg, 0x19)
        put32(seg + 4, 72)
        for (i, b) in Array("__TEXT".utf8).enumerated() { data[seg + 8 + i] = b }
        put64(seg + 24, 0x100000000)
        put64(seg + 32, 0x1000)
        put64(seg + 40, 0)
        put64(seg + 48, UInt64(data.count))
        put32(seg + 56, 7)
        put32(seg + 60, 5)

        let main = seg + 72
        put32(main, 0x80000028)
        put32(main + 4, 24)
        put64(main + 8, 0x40)

        let image = try MachOParser.parse(data)
        precondition(image.isArm64)
        precondition(image.segments.count == 1)
        precondition(image.entryOffset == 0x40)
        precondition(image.chainedFixups == nil)
    }

    static func chainedFixupsSmoke() throws {
        let payloadOffset = 256
        let payloadSize = 80
        var data = Data(repeating: 0, count: payloadOffset + payloadSize)

        func put16(_ offset: Int, _ value: UInt16) {
            data[offset] = UInt8(value & 0xff)
            data[offset + 1] = UInt8((value >> 8) & 0xff)
        }
        func put32(_ offset: Int, _ value: UInt32) {
            for i in 0..<4 { data[offset + i] = UInt8((value >> UInt32(i * 8)) & 0xff) }
        }
        func put64(_ offset: Int, _ value: UInt64) {
            for i in 0..<8 { data[offset + i] = UInt8((value >> UInt64(i * 8)) & 0xff) }
        }

        put32(0, 0xFEEDFACF)
        put32(4, 0x0100000C)
        put32(12, 2)
        put32(16, 2)
        put32(20, 88)

        let seg = 32
        put32(seg, 0x19)
        put32(seg + 4, 72)
        for (i, b) in Array("__DATA".utf8).enumerated() { data[seg + 8 + i] = b }
        put64(seg + 24, 0x100000000)
        put64(seg + 32, 0x1000)
        put64(seg + 40, 0)
        put64(seg + 48, UInt64(data.count))
        put32(seg + 56, 3)
        put32(seg + 60, 3)

        let chained = seg + 72
        put32(chained, 0x80000034)
        put32(chained + 4, 16)
        put32(chained + 8, UInt32(payloadOffset))
        put32(chained + 12, UInt32(payloadSize))

        let p = payloadOffset
        put32(p, 0)
        put32(p + 4, 28)
        put32(p + 8, 60)
        put32(p + 12, 64)
        put32(p + 16, 1)
        put32(p + 20, 1)
        put32(p + 24, 0)

        let starts = p + 28
        put32(starts, 1)
        put32(starts + 4, 8)

        let segmentStarts = starts + 8
        put32(segmentStarts, 24)
        put16(segmentStarts + 4, 4096)
        put16(segmentStarts + 6, 2)
        put64(segmentStarts + 8, 0)
        put32(segmentStarts + 16, 0)
        put16(segmentStarts + 20, 1)
        put16(segmentStarts + 22, 0xFFFF)

        put32(p + 60, 0)
        let symbol = Array("_malloc\0".utf8)
        for (i, b) in symbol.enumerated() { data[p + 64 + i] = b }

        let image = try MachOParser.parse(data)
        precondition(image.chainedFixups != nil)
        let info = try ChainedFixupsParser.parse(data: data, image: image)
        precondition(info.imports.count == 1)
        precondition(info.imports[0].name == "_malloc")
        precondition(info.fixups.isEmpty)
        precondition(info.unsupportedPointerFormats.isEmpty)
    }
}
