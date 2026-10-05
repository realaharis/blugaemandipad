import Foundation
import UIKit
import ObjectiveC.runtime

final class DBNSApplicationShim: NSObject {}
final class DBNSAlertShim: NSObject {}
final class DBNSBitmapImageRepShim: NSObject {}
final class DBNSColorSpaceShim: NSObject {}
final class DBNSCursorShim: NSObject {}
final class DBNSEventShim: NSObject {}
final class DBNSFontManagerShim: NSObject {}
final class DBNSGraphicsContextShim: NSObject {}
final class DBNSImageShim: NSObject {}
final class DBNSMenuShim: NSObject {}
final class DBNSMenuItemShim: NSObject {}
final class DBNSOpenPanelShim: NSObject {}
final class DBNSScreenShim: NSObject {}
final class DBNSViewShim: NSObject {}
final class DBNSWindowShim: NSObject {}
final class DBSBApplicationShim: NSObject {}
final class DBNSAppleEventManagerShim: NSObject {}

private var dbNSAppStorage: UnsafeMutableRawPointer?
private var dbCalibratedRGBStorage: UnsafeMutableRawPointer?
private var dbDeviceRGBStorage: UnsafeMutableRawPointer?
private var dbEventTrackingStorage: UnsafeMutableRawPointer?
private var dbModalPanelStorage: UnsafeMutableRawPointer?

@_cdecl("DBGestaltShim")
public func DBGestaltShim(_ selector: UInt32, _ response: UnsafeMutablePointer<Int32>?) -> Int32 {
    response?.pointee = 0
    return 0
}

@_cdecl("DBDyldStubBinderShim")
public func DBDyldStubBinderShim() {}

struct LoLRuntimeShimRegistry {
    static func pointer(for symbol: String) -> UnsafeMutableRawPointer? {
        let classMap: [String: AnyClass] = [
            "_OBJC_CLASS_$_NSAlert": DBNSAlertShim.self,
            "_OBJC_CLASS_$_NSApplication": DBNSApplicationShim.self,
            "_OBJC_CLASS_$_NSBitmapImageRep": DBNSBitmapImageRepShim.self,
            "_OBJC_CLASS_$_NSColorSpace": DBNSColorSpaceShim.self,
            "_OBJC_CLASS_$_NSCursor": DBNSCursorShim.self,
            "_OBJC_CLASS_$_NSEvent": DBNSEventShim.self,
            "_OBJC_CLASS_$_NSFontManager": DBNSFontManagerShim.self,
            "_OBJC_CLASS_$_NSGraphicsContext": DBNSGraphicsContextShim.self,
            "_OBJC_CLASS_$_NSImage": DBNSImageShim.self,
            "_OBJC_CLASS_$_NSMenu": DBNSMenuShim.self,
            "_OBJC_CLASS_$_NSMenuItem": DBNSMenuItemShim.self,
            "_OBJC_CLASS_$_NSOpenPanel": DBNSOpenPanelShim.self,
            "_OBJC_CLASS_$_NSScreen": DBNSScreenShim.self,
            "_OBJC_CLASS_$_NSView": DBNSViewShim.self,
            "_OBJC_CLASS_$_NSWindow": DBNSWindowShim.self,
            "_OBJC_CLASS_$_SBApplication": DBSBApplicationShim.self,
            "_OBJC_CLASS_$_NSAppleEventManager": DBNSAppleEventManagerShim.self
        ]

        if let cls = classMap[symbol] {
            return unsafeBitCast(cls, to: UnsafeMutableRawPointer.self)
        }

        if symbol == "_OBJC_METACLASS_$_NSView" {
            return metaclassPointer(DBNSViewShim.self)
        }
        if symbol == "_OBJC_METACLASS_$_NSWindow" {
            return metaclassPointer(DBNSWindowShim.self)
        }

        switch symbol {
        case "_NSApp":
            if dbNSAppStorage == nil {
                dbNSAppStorage = UnsafeMutableRawPointer.allocate(byteCount: MemoryLayout<UInt>.size,
                                                                  alignment: MemoryLayout<UInt>.alignment)
                dbNSAppStorage?.storeBytes(of: UInt(0), as: UInt.self)
            }
            return dbNSAppStorage
        case "_NSCalibratedRGBColorSpace":
            return stringSlot(&dbCalibratedRGBStorage, value: "NSCalibratedRGBColorSpace")
        case "_NSDeviceRGBColorSpace":
            return stringSlot(&dbDeviceRGBStorage, value: "NSDeviceRGBColorSpace")
        case "_NSEventTrackingRunLoopMode":
            return stringSlot(&dbEventTrackingStorage, value: "NSEventTrackingRunLoopMode")
        case "_NSModalPanelRunLoopMode":
            return stringSlot(&dbModalPanelStorage, value: "NSModalPanelRunLoopMode")
        case "_Gestalt":
            return unsafeBitCast(DBGestaltShim as @convention(c) (UInt32, UnsafeMutablePointer<Int32>?) -> Int32,
                                 to: UnsafeMutableRawPointer.self)
        case "dyld_stub_binder":
            return unsafeBitCast(DBDyldStubBinderShim as @convention(c) () -> Void,
                                 to: UnsafeMutableRawPointer.self)
        default:
            return nil
        }
    }

    static func isIntraImageWeak(_ symbol: DeepImportedSymbol) -> Bool {
        symbol.libraryOrdinal == 0 || symbol.dependencyPath == "self"
    }

    private static func metaclassPointer(_ cls: AnyClass) -> UnsafeMutableRawPointer? {
        guard let meta: AnyClass = object_getClass(cls) else { return nil }
        return unsafeBitCast(meta, to: UnsafeMutableRawPointer.self)
    }

    private static func stringSlot(_ storage: inout UnsafeMutableRawPointer?,
                                   value: String) -> UnsafeMutableRawPointer? {
        if storage == nil {
            let object: NSString = value as NSString
            let retained = Unmanaged.passRetained(object).toOpaque()
            storage = UnsafeMutableRawPointer.allocate(byteCount: MemoryLayout<UInt>.size,
                                                       alignment: MemoryLayout<UInt>.alignment)
            storage?.storeBytes(of: UInt(bitPattern: retained), as: UInt.self)
        }
        return storage
    }
}

struct LoLRuntimeShimValidation {
    let runtimeResolved: Int
    let weakIntraImage: Int
    let remaining: [String]

    var totalCovered: Int { runtimeResolved + weakIntraImage }
}

struct LoLRuntimeShimValidator {
    static func validate(scan: DeepSymbolScanReport) -> LoLRuntimeShimValidation {
        var runtime = 0
        var weak = 0
        var remaining: [String] = []

        for item in scan.imports where !item.hostResolved {
            if LoLRuntimeShimRegistry.pointer(for: item.name) != nil {
                runtime += 1
            } else if LoLRuntimeShimRegistry.isIntraImageWeak(item) {
                weak += 1
            } else {
                remaining.append(item.name)
            }
        }

        return LoLRuntimeShimValidation(runtimeResolved: runtime,
                                        weakIntraImage: weak,
                                        remaining: remaining.sorted())
    }
}
