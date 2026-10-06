import Foundation
@main
struct PackagerCLI {
    static func main() throws {
        guard CommandLine.arguments.count == 4 else { fatalError("usage: packager INPUT RUNTIME_DIR OUTPUT.ipa") }
        let result = try LoLLiveContainerPackager.buildMinimalIPA(
            executable: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])),
            runtimeDirectory: URL(fileURLWithPath: CommandLine.arguments[2]),
            outputURL: URL(fileURLWithPath: CommandLine.arguments[3]))
        print("packaged ", result.ipaURL.path, result.executableBytes)
    }
}
