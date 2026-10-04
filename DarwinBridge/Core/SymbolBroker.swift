import Foundation
import Darwin

struct SymbolBroker {
    static func resolve(imports: [ChainedImport],
                        image: MachOImageInfo) -> [SymbolResolution] {
        imports.map { item in
            let dependency = dependencyPath(for: item.libraryOrdinal, image: image)
            let address = lookup(item.name)
            return SymbolResolution(name: item.name,
                                    libraryOrdinal: item.libraryOrdinal,
                                    dependencyPath: dependency,
                                    address: address.map { UInt64(UInt(bitPattern: $0)) },
                                    source: address == nil ? "unresolved" : "RTLD_DEFAULT")
        }
    }

    private static func dependencyPath(for ordinal: Int32,
                                       image: MachOImageInfo) -> String? {
        guard ordinal > 0 else {
            switch ordinal {
            case 0: return "self"
            case -1: return "main executable"
            case -2: return "flat lookup"
            case -3: return "weak lookup"
            default: return nil
            }
        }
        let index = Int(ordinal - 1)
        guard image.dependencies.indices.contains(index) else { return nil }
        return image.dependencies[index].path
    }

    private static func lookup(_ symbol: String) -> UnsafeMutableRawPointer? {
        if let exact = dlsym(RTLD_DEFAULT, symbol) {
            return exact
        }
        if symbol.hasPrefix("_") {
            return dlsym(RTLD_DEFAULT, String(symbol.dropFirst()))
        }
        return dlsym(RTLD_DEFAULT, "_" + symbol)
    }
}
