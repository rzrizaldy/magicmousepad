import Foundation

/// Something the app can do when a gesture is recognized.
public enum ActionKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case none

    // System
    case missionControl
    case appExpose
    case showDesktop
    case showApps
    case nextSpace
    case previousSpace

    // Navigation
    case back
    case forward
    case nextTab
    case previousTab
    case closeTab

    // Pointer & view
    case middleClick
    case zoomIn
    case zoomOut
    case resetZoom

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .none: return "Do nothing"
        case .missionControl: return "Mission Control"
        case .appExpose: return "App Exposé"
        case .showDesktop: return "Show Desktop"
        case .showApps: return "Show Apps"
        case .nextSpace: return "Next Space"
        case .previousSpace: return "Previous Space"
        case .back: return "Back"
        case .forward: return "Forward"
        case .nextTab: return "Next Tab"
        case .previousTab: return "Previous Tab"
        case .closeTab: return "Close Tab"
        case .middleClick: return "Middle Click"
        case .zoomIn: return "Zoom In"
        case .zoomOut: return "Zoom Out"
        case .resetZoom: return "Actual Size"
        }
    }

    public var symbol: String {
        switch self {
        case .none: return "nosign"
        case .missionControl: return "rectangle.3.group"
        case .appExpose: return "rectangle.stack"
        case .showDesktop: return "menubar.dock.rectangle"
        case .showApps: return "square.grid.3x3"
        case .nextSpace: return "rectangle.righthalf.inset.filled.arrow.right"
        case .previousSpace: return "rectangle.lefthalf.inset.filled.arrow.left"
        case .back: return "chevron.backward"
        case .forward: return "chevron.forward"
        case .nextTab: return "arrow.right.to.line"
        case .previousTab: return "arrow.left.to.line"
        case .closeTab: return "xmark.square"
        case .middleClick: return "computermouse"
        case .zoomIn: return "plus.magnifyingglass"
        case .zoomOut: return "minus.magnifyingglass"
        case .resetZoom: return "1.magnifyingglass"
        }
    }

    public enum Group: String, CaseIterable, Sendable {
        case system = "System"
        case navigation = "Navigation"
        case view = "Pointer & View"
    }

    public var group: Group? {
        switch self {
        case .none: return nil
        case .missionControl, .appExpose, .showDesktop, .showApps, .nextSpace, .previousSpace: return .system
        case .back, .forward, .nextTab, .previousTab, .closeTab: return .navigation
        case .middleClick, .zoomIn, .zoomOut, .resetZoom: return .view
        }
    }

    public static func actions(in group: Group) -> [ActionKind] {
        allCases.filter { $0.group == group }
    }
}

/// Default mapping, modelled after the macOS trackpad defaults.
public enum DefaultMapping {
    public static let mapping: [MouseGesture: ActionKind] = [
        // Two fingers — like a trackpad's two-finger swipe between pages.
        .twoFingerSwipeLeft: .forward,
        .twoFingerSwipeRight: .back,
        .twoFingerSwipeUp: .missionControl,
        .twoFingerSwipeDown: .appExpose,
        .twoFingerTap: .none,
        .pinchIn: .none,
        .pinchOut: .none,

        // Three fingers — like a trackpad's three-finger swipe between Spaces.
        .threeFingerSwipeLeft: .nextSpace,
        .threeFingerSwipeRight: .previousSpace,
        .threeFingerSwipeUp: .showDesktop,
        .threeFingerSwipeDown: .showApps,
        .threeFingerTap: .middleClick,
    ]
}
