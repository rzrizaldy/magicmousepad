import AppKit
import CoreGraphics
import MagicMousePadCore

/// Executes an `ActionKind` by talking to the Dock or posting synthetic input.
enum ActionPerformer {
    static func perform(_ action: ActionKind) {
        switch action {
        case .none: break

        case .missionControl: dock("com.apple.expose.awake", fallbackArgs: [])
        case .appExpose: dock("com.apple.expose.front.awake", fallbackArgs: ["2"])
        case .showDesktop: dock("com.apple.showdesktop.awake", fallbackArgs: ["1"])
        case .showApps: openApps()
        case .nextSpace: key(Key.rightArrow, [.maskControl, .maskSecondaryFn, .maskNumericPad])
        case .previousSpace: key(Key.leftArrow, [.maskControl, .maskSecondaryFn, .maskNumericPad])

        case .back: key(Key.leftBracket, .maskCommand)
        case .forward: key(Key.rightBracket, .maskCommand)
        case .nextTab: key(Key.tab, .maskControl)
        case .previousTab: key(Key.tab, [.maskControl, .maskShift])
        case .closeTab: key(Key.w, .maskCommand)

        case .click: click(.left)
        case .secondaryClick: click(.right)
        case .middleClick: click(.center)
        case .lookUp: key(Key.d, [.maskControl, .maskCommand])
        case .zoomIn: key(Key.equal, .maskCommand)
        case .zoomOut: key(Key.minus, .maskCommand)
        case .resetZoom: key(Key.zero, .maskCommand)
        }
    }

    // MARK: - Keyboard

    private enum Key {
        static let leftArrow: CGKeyCode = 123
        static let rightArrow: CGKeyCode = 124
        static let leftBracket: CGKeyCode = 33
        static let rightBracket: CGKeyCode = 30
        static let tab: CGKeyCode = 48
        static let w: CGKeyCode = 13
        static let equal: CGKeyCode = 24
        static let minus: CGKeyCode = 27
        static let zero: CGKeyCode = 29
        static let d: CGKeyCode = 2
    }

    private static func key(_ code: CGKeyCode, _ flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)
        for down in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down) else { continue }
            event.flags = flags
            event.post(tap: .cghidEventTap)
        }
    }

    // MARK: - Mouse

    private static var lastClick: (time: Date, location: CGPoint, button: CGMouseButton, count: Int64)?

    /// Posts a click at the pointer. Two quick taps in the same place become a real double-click.
    private static func click(_ button: CGMouseButton) {
        let location = CGEvent(source: nil)?.location ?? .zero
        var count: Int64 = 1
        if let last = lastClick, last.button == button,
           Date().timeIntervalSince(last.time) < NSEvent.doubleClickInterval,
           hypot(last.location.x - location.x, last.location.y - location.y) < 6 {
            count = min(last.count + 1, 3)
        }
        lastClick = (Date(), location, button, count)

        let types: (CGEventType, CGEventType) = switch button {
        case .left: (.leftMouseDown, .leftMouseUp)
        case .right: (.rightMouseDown, .rightMouseUp)
        default: (.otherMouseDown, .otherMouseUp)
        }
        let source = CGEventSource(stateID: .hidSystemState)
        for type in [types.0, types.1] {
            guard let event = CGEvent(mouseEventSource: source, mouseType: type,
                                      mouseCursorPosition: location, mouseButton: button) else { continue }
            event.setIntegerValueField(.mouseEventClickState, value: count)
            event.setIntegerValueField(.eventSourceUserData, value: EventFilter.syntheticMarker)
            event.post(tap: .cghidEventTap)
        }
    }

    // MARK: - Dock / Mission Control

    private typealias CoreDockSendNotification = @convention(c) (CFString, UnsafeMutableRawPointer?) -> Void

    private static let coreDockSend: CoreDockSendNotification? = {
        guard let sym = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CoreDockSendNotification") else { return nil }
        return unsafeBitCast(sym, to: CoreDockSendNotification.self)
    }()

    /// Uses the Dock's private notification when present, otherwise launches Mission Control.
    private static func dock(_ notification: String, fallbackArgs: [String]) {
        if let send = coreDockSend {
            send(notification as CFString, nil)
            return
        }
        let url = URL(fileURLWithPath: "/System/Applications/Mission Control.app/Contents/MacOS/Mission Control")
        _ = try? Process.run(url, arguments: fallbackArgs)
    }

    private static func openApps() {
        let candidates = ["/System/Applications/Apps.app", "/System/Applications/Launchpad.app"]
        if let path = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) {
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        }
    }
}
