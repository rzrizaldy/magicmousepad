import CoreGraphics
import Foundation
import MagicMousePadCore

/// A session-level event tap that
///  • pauses scrolling while a multi-finger gesture is on the mouse,
///  • applies Magic Mouse–only scroll direction and speed,
///  • turns a physical click made with three fingers into a middle click,
///  • reports physical clicks and pointer motion (so a click or a grip is never also a tap).
final class EventFilter {
    var shouldPauseScroll: () -> Bool = { false }
    var shouldConvertToMiddleClick: () -> Bool = { false }
    var fingersOnMouse: () -> Int = { 0 }
    var scrollAdjustment: () -> ScrollAdjustment = { ScrollAdjustment() }
    var onPhysicalClick: () -> Void = {}
    var onPointerMotion: (Double, Double) -> Void = { _, _ in }

    /// Stamped on clicks the app posts itself (tap to click), so they're never mistaken for physical ones.
    static let syntheticMarker: Int64 = 0x4D4D_5044 // "MMPD"

    private var tap: CFMachPort?
    private var converting = false
    /// True while a scroll (including its momentum tail) started on the Magic Mouse.
    private var mouseScrollActive = false

    /// Raw NSEvent types that carry trackpad-style gestures (gesture, magnify, swipe).
    private static let gestureTypes: [UInt32] = [29, 30, 31]

    func start() {
        guard tap == nil else { return }
        var mask: CGEventMask = 0
        for type in [CGEventType.scrollWheel, .mouseMoved, .leftMouseDown, .leftMouseUp, .leftMouseDragged,
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
        let pass = Unmanaged.passUnretained(event)
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return pass

        case .mouseMoved:
            reportMotion(event)
            return pass

        case .scrollWheel:
            if shouldPauseScroll() { return nil }
            adjustScroll(event)
            return pass

        case .leftMouseDown, .rightMouseDown:
            if event.getIntegerValueField(.eventSourceUserData) == Self.syntheticMarker { return pass }
            onPhysicalClick()
            if shouldConvertToMiddleClick() {
                converting = true
                retype(event, to: .otherMouseDown)
            }
            return pass

        case .leftMouseDragged, .rightMouseDragged:
            reportMotion(event)
            if converting { retype(event, to: .otherMouseDragged) }
            return pass

        case .leftMouseUp, .rightMouseUp:
            if converting {
                converting = false
                retype(event, to: .otherMouseUp)
            }
            return pass

        default:
            if Self.gestureTypes.contains(type.rawValue), shouldPauseScroll() { return nil }
            return pass
        }
    }

    private func reportMotion(_ event: CGEvent) {
        onPointerMotion(Double(event.getIntegerValueField(.mouseEventDeltaX)),
                        Double(event.getIntegerValueField(.mouseEventDeltaY)))
    }

    /// Scrolls that start with a finger on the Magic Mouse (and their momentum) get the
    /// mouse's own direction and speed; trackpad scrolling is left alone.
    private func adjustScroll(_ event: CGEvent) {
        let momentum = event.getIntegerValueField(.scrollWheelEventMomentumPhase) != 0
        if fingersOnMouse() > 0 {
            mouseScrollActive = true
        } else if !momentum {
            mouseScrollActive = false
        }
        guard mouseScrollActive else { return }

        let adjust = scrollAdjustment()
        guard !adjust.isIdentity else { return }
        let f = adjust.factor
        for (line, fixed, point) in [(CGEventField.scrollWheelEventDeltaAxis1, CGEventField.scrollWheelEventFixedPtDeltaAxis1, CGEventField.scrollWheelEventPointDeltaAxis1),
                                     (.scrollWheelEventDeltaAxis2, .scrollWheelEventFixedPtDeltaAxis2, .scrollWheelEventPointDeltaAxis2)] {
            event.setIntegerValueField(line, value: adjust.scaleLines(event.getIntegerValueField(line)))
            event.setDoubleValueField(fixed, value: event.getDoubleValueField(fixed) * f)
            event.setDoubleValueField(point, value: event.getDoubleValueField(point) * f)
        }
    }

    private func retype(_ event: CGEvent, to type: CGEventType) {
        event.type = type
        event.setIntegerValueField(.mouseEventButtonNumber, value: Int64(CGMouseButton.center.rawValue))
    }
}
