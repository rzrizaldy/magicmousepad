import Foundation

/// A gesture performed on the Magic Mouse surface.
public enum MouseGesture: String, CaseIterable, Codable, Identifiable, Sendable {
    case oneFingerTap

    case twoFingerSwipeLeft
    case twoFingerSwipeRight
    case twoFingerSwipeUp
    case twoFingerSwipeDown
    case twoFingerTap
    case pinchIn
    case pinchOut

    case threeFingerSwipeLeft
    case threeFingerSwipeRight
    case threeFingerSwipeUp
    case threeFingerSwipeDown
    case threeFingerTap

    public var id: String { rawValue }

    public var fingers: Int {
        switch self {
        case .oneFingerTap:
            return 1
        case .twoFingerSwipeLeft, .twoFingerSwipeRight, .twoFingerSwipeUp, .twoFingerSwipeDown,
             .twoFingerTap, .pinchIn, .pinchOut:
            return 2
        case .threeFingerSwipeLeft, .threeFingerSwipeRight, .threeFingerSwipeUp, .threeFingerSwipeDown,
             .threeFingerTap:
            return 3
        }
    }

    /// Short label without the finger count ("Swipe left", "Tap", …).
    public var shortTitle: String {
        switch self {
        case .twoFingerSwipeLeft, .threeFingerSwipeLeft: return "Swipe left"
        case .twoFingerSwipeRight, .threeFingerSwipeRight: return "Swipe right"
        case .twoFingerSwipeUp, .threeFingerSwipeUp: return "Swipe up"
        case .twoFingerSwipeDown, .threeFingerSwipeDown: return "Swipe down"
        case .oneFingerTap, .twoFingerTap, .threeFingerTap: return "Tap"
        case .pinchIn: return "Pinch in"
        case .pinchOut: return "Pinch out"
        }
    }

    public var title: String {
        let count = ["One-finger", "Two-finger", "Three-finger"][min(max(fingers, 1), 3) - 1]
        switch self {
        case .pinchIn, .pinchOut: return shortTitle
        default: return "\(count) \(shortTitle.lowercased())"
        }
    }

    /// SF Symbol shown next to the gesture.
    public var symbol: String {
        switch self {
        case .twoFingerSwipeLeft, .threeFingerSwipeLeft: return "arrow.left"
        case .twoFingerSwipeRight, .threeFingerSwipeRight: return "arrow.right"
        case .twoFingerSwipeUp, .threeFingerSwipeUp: return "arrow.up"
        case .twoFingerSwipeDown, .threeFingerSwipeDown: return "arrow.down"
        case .oneFingerTap, .twoFingerTap, .threeFingerTap: return "hand.tap"
        case .pinchIn: return "arrow.down.right.and.arrow.up.left"
        case .pinchOut: return "arrow.up.left.and.arrow.down.right"
        }
    }

    public var isTap: Bool { self == .oneFingerTap || self == .twoFingerTap || self == .threeFingerTap }

    public enum Direction: Sendable { case left, right, up, down }

    public static func swipe(fingers: Int, direction: Direction) -> MouseGesture? {
        switch (fingers, direction) {
        case (2, .left): return .twoFingerSwipeLeft
        case (2, .right): return .twoFingerSwipeRight
        case (2, .up): return .twoFingerSwipeUp
        case (2, .down): return .twoFingerSwipeDown
        case (3, .left): return .threeFingerSwipeLeft
        case (3, .right): return .threeFingerSwipeRight
        case (3, .up): return .threeFingerSwipeUp
        case (3, .down): return .threeFingerSwipeDown
        default: return nil
        }
    }

    public static func tap(fingers: Int) -> MouseGesture? {
        switch fingers {
        case 1: return .oneFingerTap
        case 2: return .twoFingerTap
        case 3: return .threeFingerTap
        default: return nil
        }
    }
}
