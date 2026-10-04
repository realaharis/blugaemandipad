import Foundation

@main
struct ParserSmoke {
    static func main() throws {
        var data = Data(repeating: 0, count: 32 + 72 + 24)

        func put32(_ offset: Int, _ value: UInt32) {
            for i in 0..<4 {
                data[offset + i] = UInt8((value >> UInt32(i * 8)) & 0xff)
            }
        }

        func put64(_ offset: Int, _ value: UInt64) {
            for i in 0..<8 {
                data[offset + i] = UInt8((value >> UInt64(i * 8)) & 0xff)
            }
        }

        put32(0, 0xFEEDFACF)
        put32(4, 0x0100000C)
        put32(8, 0)
        put32(12, 2)
        put32(16, 2)
        put32(20, 96)

        let seg = 32
        put32(seg, 0x19)
        put32(seg + 4, 72)
        for (i, b) in Array("__TEXT".utf8).enumerated() {
            data[seg + 8 + i] = b
        }
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

        let report = CompatibilityAnalyzer.analyze(image)
        precondition(report.score > 0)
        print("parser smoke test passed: score=\(report.score), segments=\(image.segments.count)")
    }
}
