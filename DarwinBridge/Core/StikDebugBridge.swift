import Foundation
import UIKit

enum StikDebugBridge {
    enum BridgeError: Error, LocalizedError {
        case unavailable
        case missingBundleIdentifier
        case missingScript
        case invalidURL
        case openFailed

        var errorDescription: String? {
            switch self {
            case .unavailable: return "StikDebug is not installed or its URL scheme is unavailable."
            case .missingBundleIdentifier: return "DarwinBridge has no bundle identifier."
            case .missingScript: return "The bundled StikDebug script is missing."
            case .invalidURL: return "Could not construct the StikDebug enable-JIT URL."
            case .openFailed: return "iOS could not open StikDebug."
            }
        }
    }

    static var isAvailable: Bool {
        guard let url = URL(string: "stikdebug://enable-jit") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    static func enableJIT(completion: @escaping (Result<Void, Error>) -> Void) {
        guard isAvailable else {
            completion(.failure(BridgeError.unavailable))
            return
        }
        guard let bundleID = Bundle.main.bundleIdentifier else {
            completion(.failure(BridgeError.missingBundleIdentifier))
            return
        }
        guard let scriptURL = Bundle.main.url(forResource: "darwinbridge-jit", withExtension: "js"),
              let script = try? Data(contentsOf: scriptURL) else {
            completion(.failure(BridgeError.missingScript))
            return
        }

        var components = URLComponents()
        components.scheme = "stikdebug"
        components.host = "enable-jit"
        components.queryItems = [
            URLQueryItem(name: "bundle-id", value: bundleID),
            URLQueryItem(name: "pid", value: String(getpid())),
            URLQueryItem(name: "script-data", value: script.base64EncodedString())
        ]

        guard let url = components.url else {
            completion(.failure(BridgeError.invalidURL))
            return
        }

        UIApplication.shared.open(url, options: [:]) { opened in
            completion(opened ? .success(()) : .failure(BridgeError.openFailed))
        }
    }
}
