import CoreGraphics
import Foundation

/// A session-level event tap that
///  • pauses scrolling while a multi-finger gesture is on the mouse,
///  • turns a physical click made with three fingers into a middle click,
///  • tells the recognizer about physical clicks (so a click is never also a tap).
final class EventFilter {
    var shouldPauseScroll: () -> Bool = { false }
    var shouldConvertToMiddleClick: () -> Bool = { false }
    var onPhysicalClick: () -> Void = {}

    /// Stamped on clicks the app posts itself (tap to click), so they're never mistaken for physical ones.
    static let syntheticMarker: Int64 = 0x4D4D_5044 // "MMPD"

    private var tap: CFMachPort?
    private var converting = false

    /// Raw NSEvent types that carry trackpad-style gestures (gesture, magnify, swipe).
    private static let gestureTypes: [UInt32] = [29, 30, 31]

    func start() {
        guard tap == nil else { return }
        var mask: CGEventMask = 0
        for type in [CGEventType.scrollWheel, .leftMouseDown, .leftMouseUp, .leftMouseDragged,
                     .rightMouseDown, .rightMouseUp, .rightMouseDragged] {
            mask |= CGEventMask(1) << CGEventMask(type.rawValue)
        }
        for raw in Self.gestureTypes { mask |= CGEventMask(1) << CGEventMask(raw) }

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let filter = Unmanaged<EventFilter>.fromOpaque(refcon).takeUnretainedValue()
            return filter.handle(type: type, event: event)
        }

        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                           options: .defaultTap, eventsOfInterest: mask,
                                           callback: callback,
                                           userInfo: Unmanaged.passUnretained(self).toOpaque())
        else {
            NSLog("MagicMousePad: could not create event tap (Accessibility permission missing?)")
            return
        }
        tap = port
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)

        case .scrollWheel:
            return shouldPauseScroll() ? nil : Unmanaged.passUnretained(event)

        case .leftMouseDown, .rightMouseDown:
            if event.getIntegerValueField(.eventSourceUserData) == Self.syntheticMarker {
                return Unmanaged.passUnretained(event)
            }
            onPhysicalClick()
            if shouldConvertToMiddleClick() {
                converting = true
                retype(event, to: .otherMouseDown)
            }
            return Unmanaged.passUnretained(event)

        case .leftMouseDragged, .rightMouseDragged:
            if converting { retype(event, to: .otherMouseDragged) }
            return Unmanaged.passUnretained(event)

        case .leftMouseUp, .rightMouseUp:
            if converting {
                converting = false
                retype(event, to: .otherMouseUp)
            }
            return Unmanaged.passUnretained(event)

        default:
            if Self.gestureTypes.contains(type.rawValue), shouldPauseScroll() { return nil }
            return Unmanaged.passUnretained(event)
        }
    }

    private func retype(_ event: CGEvent, to type: CGEventType) {
        event.type = type
        event.setIntegerValueField(.mouseEventButtonNumber, value: Int64(CGMouseButton.center.rawValue))
    }
}
