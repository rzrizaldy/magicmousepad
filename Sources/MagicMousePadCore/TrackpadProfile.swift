import Foundation

/// The user's macOS trackpad gesture settings, and how they translate to the Magic Mouse.
///
/// The pointer keeps moving with the mouse itself; only the top surface becomes a trackpad.
/// Four-finger trackpad gestures fold into three-finger ones, because three fingers is
/// the most a Magic Mouse surface comfortably holds.
public struct TrackpadProfile: Equatable, Sendable {
    /// "Tap to click".
    public var tapToClick: Bool
    /// "Secondary click" with two fingers.
    public var twoFingerSecondaryClick: Bool
    /// "Swipe between pages" with two fingers.
    public var twoFingerSwipeBetweenPages: Bool
    /// Raw `TrackpadThreeFingerHorizSwipeGesture` / `TrackpadFourFingerHorizSwipeGesture` (1 = pages, 2 = Spaces/full-screen apps).
    public var threeFingerHorizontal: Int
    public var fourFingerHorizontal: Int
    /// Raw `TrackpadThreeFingerVertSwipeGesture` / `TrackpadFourFingerVertSwipeGesture` (2 = Mission Control / App Exposé).
    public var threeFingerVertical: Int
    public var fourFingerVertical: Int
    /// "Zoom in or out" with a pinch.
    public var pinchToZoom: Bool
    /// "Look up & data detectors" with a three-finger tap (raw value 2).
    public var threeFingerTapLookUp: Bool

    public init(tapToClick: Bool, twoFingerSecondaryClick: Bool, twoFingerSwipeBetweenPages: Bool,
                threeFingerHorizontal: Int, fourFingerHorizontal: Int,
                threeFingerVertical: Int, fourFingerVertical: Int,
                pinchToZoom: Bool, threeFingerTapLookUp: Bool) {
        self.tapToClick = tapToClick
        self.twoFingerSecondaryClick = twoFingerSecondaryClick
        self.twoFingerSwipeBetweenPages = twoFingerSwipeBetweenPages
        self.threeFingerHorizontal = threeFingerHorizontal
        self.fourFingerHorizontal = fourFingerHorizontal
        self.threeFingerVertical = threeFingerVertical
        self.fourFingerVertical = fourFingerVertical
        self.pinchToZoom = pinchToZoom
        self.threeFingerTapLookUp = threeFingerTapLookUp
    }

    /// A Mac trackpad straight out of the box.
    public static let factory = TrackpadProfile(
        tapToClick: false, twoFingerSecondaryClick: true, twoFingerSwipeBetweenPages: true,
        threeFingerHorizontal: 0, fourFingerHorizontal: 2,
        threeFingerVertical: 0, fourFingerVertical: 2,
        pinchToZoom: true, threeFingerTapLookUp: false)

    /// Builds a profile from the trackpad preference values (`com.apple.AppleMultitouchTrackpad`).
    /// `value(key)` returns nil when a key is unset; factory defaults fill the gaps.
    public static func from(value: (String) -> Int?, swipeNavigateWithScrolls: Bool?) -> TrackpadProfile {
        let f = factory
        return TrackpadProfile(
            tapToClick: value("Clicking").map { $0 != 0 } ?? f.tapToClick,
            twoFingerSecondaryClick: value("TrackpadRightClick").map { $0 != 0 } ?? f.twoFingerSecondaryClick,
            twoFingerSwipeBetweenPages: swipeNavigateWithScrolls ?? f.twoFingerSwipeBetweenPages,
            threeFingerHorizontal: value("TrackpadThreeFingerHorizSwipeGesture") ?? f.threeFingerHorizontal,
            fourFingerHorizontal: value("TrackpadFourFingerHorizSwipeGesture") ?? f.fourFingerHorizontal,
            threeFingerVertical: value("TrackpadThreeFingerVertSwipeGesture") ?? f.threeFingerVertical,
            fourFingerVertical: value("TrackpadFourFingerVertSwipeGesture") ?? f.fourFingerVertical,
            pinchToZoom: value("TrackpadPinch").map { $0 != 0 } ?? f.pinchToZoom,
            threeFingerTapLookUp: value("TrackpadThreeFingerTapGesture") == 2)
    }

    /// The Magic Mouse gestures that reproduce this trackpad.
    ///
    /// Two-finger up/down stays free so two fingers scroll, exactly like a trackpad.
    public var mapping: [MouseGesture: ActionKind] {
        var m = Dictionary(uniqueKeysWithValues: MouseGesture.allCases.map { ($0, ActionKind.none) })

        m[.oneFingerTap] = tapToClick ? ActionKind.click : ActionKind.none
        m[.twoFingerTap] = tapToClick && twoFingerSecondaryClick ? ActionKind.secondaryClick : ActionKind.none

        if twoFingerSwipeBetweenPages {
            m[.twoFingerSwipeLeft] = .forward
            m[.twoFingerSwipeRight] = .back
        }
        if pinchToZoom {
            m[.pinchOut] = .zoomIn
            m[.pinchIn] = .zoomOut
        }

        // Horizontal: Spaces wins over pages if either the 3- or 4-finger gesture switches Spaces.
        if threeFingerHorizontal == 2 || fourFingerHorizontal == 2 {
            m[.threeFingerSwipeLeft] = .nextSpace
            m[.threeFingerSwipeRight] = .previousSpace
        } else if threeFingerHorizontal == 1 {
            m[.threeFingerSwipeLeft] = .forward
            m[.threeFingerSwipeRight] = .back
        }
        if threeFingerVertical == 2 || fourFingerVertical == 2 {
            m[.threeFingerSwipeUp] = .missionControl
            m[.threeFingerSwipeDown] = .appExpose
        }
        if threeFingerTapLookUp { m[.threeFingerTap] = .lookUp }
        return m
    }

    /// Plain-language list of what was copied, for the UI.
    public var summary: [String] {
        var s: [String] = []
        if tapToClick { s.append("Tap to click") }
        if tapToClick && twoFingerSecondaryClick { s.append("Two-finger tap to right-click") }
        s.append("Two-finger scroll")
        if twoFingerSwipeBetweenPages { s.append("Swipe between pages") }
        if pinchToZoom { s.append("Pinch to zoom") }
        if threeFingerHorizontal == 2 || fourFingerHorizontal == 2 { s.append("Three-finger Spaces") }
        if threeFingerVertical == 2 || fourFingerVertical == 2 { s.append("Mission Control") }
        if threeFingerTapLookUp { s.append("Look up") }
        return s
    }
}
