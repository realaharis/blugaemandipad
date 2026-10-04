import Foundation
import UIKit

@MainActor
final class AppKitUIKitBridge {
    static let shared = AppKitUIKitBridge()

    private var guestWindows: [UIWindow] = []

    struct Snapshot {
        let windowCount: Int
        let lastWindowVisible: Bool
        let lastViewClass: String
    }

    private(set) var snapshot = Snapshot(windowCount: 0,
                                         lastWindowVisible: false,
                                         lastViewClass: "none")

    @discardableResult
    func createDemoWindow() -> Int32 {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }) else {
            return -10
        }

        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds

        let controller = UIViewController()
        controller.view.backgroundColor = .systemBackground

        let guestView = UIView(frame: CGRect(x: 28, y: 120, width: 320, height: 180))
        guestView.backgroundColor = .secondarySystemBackground
        guestView.layer.cornerRadius = 18
        guestView.layer.borderWidth = 1

        let label = UILabel(frame: CGRect(x: 20, y: 20, width: 280, height: 44))
        label.text = "DarwinBridge NSView → UIView"
        label.font = .systemFont(ofSize: 19, weight: .semibold)
        guestView.addSubview(label)

        let detail = UILabel(frame: CGRect(x: 20, y: 70, width: 280, height: 70))
        detail.text = "Created by guest ARM64 through the AppKit compatibility bridge."
        detail.numberOfLines = 3
        detail.font = .systemFont(ofSize: 14)
        guestView.addSubview(detail)

        controller.view.addSubview(guestView)
        window.rootViewController = controller
        window.windowLevel = .alert + 1
        window.isHidden = false
        window.makeKeyAndVisible()

        guestWindows.append(window)
        snapshot = Snapshot(windowCount: guestWindows.count,
                            lastWindowVisible: !window.isHidden,
                            lastViewClass: String(describing: type(of: guestView)))
        return 1
    }

    func dismissAllGuestWindows() {
        for window in guestWindows {
            window.isHidden = true
            window.rootViewController = nil
        }
        guestWindows.removeAll()
        snapshot = Snapshot(windowCount: 0,
                            lastWindowVisible: false,
                            lastViewClass: "none")
    }
}

@_cdecl("DBAppKitCreateDemoWindow")
public func DBAppKitCreateDemoWindow() -> Int32 {
    if Thread.isMainThread {
        return MainActor.assumeIsolated {
            AppKitUIKitBridge.shared.createDemoWindow()
        }
    }

    var result: Int32 = -11
    DispatchQueue.main.sync {
        MainActor.assumeIsolated {
            result = AppKitUIKitBridge.shared.createDemoWindow()
        }
    }
    return result
}

@_cdecl("DBAppKitDismissGuestWindows")
public func DBAppKitDismissGuestWindows() {
    if Thread.isMainThread {
        MainActor.assumeIsolated {
            AppKitUIKitBridge.shared.dismissAllGuestWindows()
        }
        return
    }

    DispatchQueue.main.async {
        AppKitUIKitBridge.shared.dismissAllGuestWindows()
    }
}
