import AppKit
import Combine
import MagicMousePadCore
import ServiceManagement
import SwiftUI

/// Single source of truth for the UI: user preferences + live status.
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    // MARK: Preferences (persisted)

    @Published var enabled: Bool { didSet { save(); pushConfig() } }
    @Published var mapping: [MouseGesture: ActionKind] { didSet { save(); pushConfig(); refreshConflicts(); matchesTrackpad = mapping == TrackpadProfile.current().mapping } }
    @Published var sensitivity: Double { didSet { save(); pushConfig() } }
    @Published var pauseScrollDuringGestures: Bool { didSet { save() } }
    @Published var threeFingerClickIsMiddleClick: Bool { didSet { save() } }
    @Published var showHUD: Bool { didSet { save() } }
    @Published var invertVertical: Bool { didSet { save(); pushConfig() } }
    @Published var showMenuBarIcon: Bool { didSet { save() } }
    @Published var lowBatteryReminder: Bool { didSet { save() } }
    @Published var reverseMouseScroll: Bool { didSet { save() } }
    @Published var mouseScrollSpeed: Double { didSet { save() } }
    @Published var ignoreTapsWhileMoving: Bool { didSet { save() } }

    // MARK: Live status

    @Published private(set) var devices: [DeviceInfo] = []
    @Published private(set) var accessibilityGranted = Permissions.isTrusted
    @Published private(set) var lastGesture: MouseGesture?
    @Published private(set) var lastGestureDate: Date?
    @Published private(set) var liveTouches: [TouchPoint] = []
    @Published private(set) var batteryPercent: Int?
    @Published private(set) var conflicts: [NativeGestureConflict] = []
    /// What "Match my trackpad" copied, shown in the window.
    @Published private(set) var trackpadSummary: [String] = []
    @Published private(set) var matchesTrackpad = false
    /// Taps ignored because the mouse was moving (shown so the guard is visible, not magic).
    @Published private(set) var ignoredTaps = 0
    @Published private(set) var gesturesToday = 0
    @Published var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled {
        didSet { LaunchAtLogin.set(launchAtLogin) }
    }

    var mouse: DeviceInfo? { devices.first(where: \.isMagicMouse) }
    var multitouchAvailable: Bool { TouchEngine.shared.isAvailable }

    private let defaults = UserDefaults.standard
    private let eventFilter = EventFilter()
    private var permissionTimer: Timer?
    private var pointerGuard = PointerMotionGuard()
    private var batteryReminder = BatteryReminder()
    private var askedForNotifications = false

    private init() {
        let d = UserDefaults.standard
        d.register(defaults: [
            Keys.enabled: true,
            Keys.sensitivity: 0.5,
            Keys.pauseScroll: true,
            Keys.threeFingerClick: true,
            Keys.showHUD: true,
            Keys.invertVertical: false,
            Keys.showMenuBarIcon: true,
            Keys.lowBatteryReminder: true,
            Keys.reverseMouseScroll: false,
            Keys.mouseScrollSpeed: 1.0,
            Keys.ignoreTapsWhileMoving: true,
        ])
        enabled = d.bool(forKey: Keys.enabled)
        sensitivity = d.double(forKey: Keys.sensitivity)
        pauseScrollDuringGestures = d.bool(forKey: Keys.pauseScroll)
        threeFingerClickIsMiddleClick = d.bool(forKey: Keys.threeFingerClick)
        showHUD = d.bool(forKey: Keys.showHUD)
        invertVertical = d.bool(forKey: Keys.invertVertical)
        showMenuBarIcon = d.bool(forKey: Keys.showMenuBarIcon)
        lowBatteryReminder = d.bool(forKey: Keys.lowBatteryReminder)
        reverseMouseScroll = d.bool(forKey: Keys.reverseMouseScroll)
        mouseScrollSpeed = d.double(forKey: Keys.mouseScrollSpeed)
        ignoreTapsWhileMoving = d.bool(forKey: Keys.ignoreTapsWhileMoving)
        gesturesToday = d.string(forKey: Keys.gesturesDay) == Self.today ? d.integer(forKey: Keys.gesturesCount) : 0
        mapping = Self.loadMapping(from: d)
    }

    // MARK: Lifecycle

    func start() {
        let engine = TouchEngine.shared
        engine.onDevicesChanged = { [weak self] list in
            self?.devices = list
            self?.refreshBattery()
        }
        engine.onGesture = { [weak self] gesture in self?.handle(gesture) }
        engine.onTouches = { [weak self] touches in self?.liveTouches = touches }
        pushConfig()
        engine.start()

        eventFilter.shouldPauseScroll = { [weak self] in
            guard let self else { return false }
            let fingers = TouchEngine.shared.currentFingerCount
            return self.enabled && self.pauseScrollDuringGestures && self.shouldPauseScroll(fingers: fingers)
        }
        eventFilter.shouldConvertToMiddleClick = { [weak self] in
            guard let self else { return false }
            return self.enabled && self.threeFingerClickIsMiddleClick && TouchEngine.shared.currentFingerCount >= 3
        }
        eventFilter.onPhysicalClick = { TouchEngine.shared.noteClick() }
        eventFilter.fingersOnMouse = { TouchEngine.shared.currentFingerCount }
        eventFilter.scrollAdjustment = { [weak self] in
            guard let self, self.enabled else { return ScrollAdjustment() }
            return ScrollAdjustment(reverse: self.reverseMouseScroll, speed: self.mouseScrollSpeed)
        }
        eventFilter.onPointerMotion = { [weak self] dx, dy in
            self?.pointerGuard.record(dx: dx, dy: dy, at: ProcessInfo.processInfo.systemUptime)
        }

        // First launch: make the mouse surface behave exactly like this Mac's trackpad.
        if !defaults.bool(forKey: Keys.matchedTrackpad) { matchTrackpad() }
        trackpadSummary = TrackpadProfile.current().summary
        matchesTrackpad = mapping == TrackpadProfile.current().mapping

        startEventFilterWhenTrusted()
        refreshConflicts()

        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshBattery() }
        }
    }

    /// Polls until Accessibility is granted, then installs the event filter.
    private func startEventFilterWhenTrusted() {
        accessibilityGranted = Permissions.isTrusted
        if accessibilityGranted {
            eventFilter.start()
            return
        }
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else { return }
                if Permissions.isTrusted {
                    timer.invalidate()
                    self.accessibilityGranted = true
                    self.eventFilter.start()
                }
            }
        }
    }

    func requestAccessibility() {
        Permissions.prompt()
        startEventFilterWhenTrusted()
    }

    func setPreviewActive(_ active: Bool) {
        TouchEngine.shared.previewEnabled = active
        if !active { liveTouches = [] }
    }

    /// Fills live status with sample values for the README screenshot (`--snapshot`).
    func loadDemoState() {
        liveTouches = [TouchPoint(id: 1, x: 0.30, y: 0.66), TouchPoint(id: 2, x: 0.66, y: 0.70)]
        matchTrackpad()
        lastGesture = .twoFingerSwipeRight
        lastGestureDate = Date()
        batteryPercent = 100
        gesturesToday = 37
        accessibilityGranted = true
        devices = [.demo]
    }

    // MARK: Gestures

    private func handle(_ gesture: MouseGesture) {
        guard enabled else { return }
        let action = mapping[gesture] ?? .none
        guard action != .none else { return }
        if gesture.isTap, ignoreTapsWhileMoving, pointerGuard.isMoving(at: ProcessInfo.processInfo.systemUptime) {
            ignoredTaps += 1 // gripping or moving the mouse, not tapping
            return
        }
        lastGesture = gesture
        lastGestureDate = Date()
        countGesture()
        ActionPerformer.perform(action)
        if showHUD { HUDController.shared.show(gesture: gesture, action: action) }
    }

    func action(for gesture: MouseGesture) -> ActionKind { mapping[gesture] ?? .none }

    func setAction(_ action: ActionKind, for gesture: MouseGesture) { mapping[gesture] = action }

    func hasActions(forFingers fingers: Int) -> Bool {
        mapping.contains { $0.key.fingers == fingers && $0.value != .none }
    }

    /// Two fingers keep scrolling (like a trackpad) unless two-finger up/down is assigned.
    /// Three fingers never scroll while a three-finger gesture is assigned.
    func shouldPauseScroll(fingers: Int) -> Bool {
        switch fingers {
        case ..<2: return false
        case 2: return action(for: .twoFingerSwipeUp) != .none || action(for: .twoFingerSwipeDown) != .none
        default: return hasActions(forFingers: 3)
        }
    }

    /// The menu bar icon can also be removed by ⌘-dragging it; pick that up from UserDefaults.
    func syncMenuBarIconSetting() {
        let stored = defaults.bool(forKey: Keys.showMenuBarIcon)
        if stored != showMenuBarIcon { showMenuBarIcon = stored }
    }

    /// Copies the trackpad's gesture settings onto the mouse surface.
    func matchTrackpad() {
        let profile = TrackpadProfile.current()
        mapping = profile.mapping
        invertVertical = false
        pauseScrollDuringGestures = true
        trackpadSummary = profile.summary
        matchesTrackpad = true
        defaults.set(true, forKey: Keys.matchedTrackpad)
    }

    func restoreDefaults() {
        matchTrackpad()
        sensitivity = 0.5
        pauseScrollDuringGestures = true
        threeFingerClickIsMiddleClick = true
        showHUD = true
        invertVertical = false
    }

    // MARK: Native conflicts & battery

    func refreshConflicts() {
        conflicts = NativeGestureConflict.detect(mapping: mapping)
    }

    func refreshBattery() {
        batteryPercent = mouse.flatMap { Battery.percent(forProductID: $0.productID) }
        guard let percent = batteryPercent, lowBatteryReminder else { return }
        if percent < 30, !askedForNotifications {
            askedForNotifications = true
            Notifier.requestAuthorization()
        }
        if let alert = batteryReminder.update(percent: percent) { Notifier.batteryAlert(alert) }
    }

    // MARK: Persistence

    private enum Keys {
        static let enabled = "enabled"
        static let mapping = "mapping"
        static let sensitivity = "sensitivity"
        static let pauseScroll = "pauseScrollDuringGestures"
        static let threeFingerClick = "threeFingerClickIsMiddleClick"
        static let showHUD = "showHUD"
        static let invertVertical = "invertVertical"
        static let showMenuBarIcon = "showMenuBarIcon"
        static let lowBatteryReminder = "lowBatteryReminder"
        static let reverseMouseScroll = "reverseMouseScroll"
        static let mouseScrollSpeed = "mouseScrollSpeed"
        static let ignoreTapsWhileMoving = "ignoreTapsWhileMoving"
        static let gesturesDay = "gesturesDay"
        static let gesturesCount = "gesturesCount"
        static let matchedTrackpad = "matchedTrackpad"
    }

    private static func loadMapping(from d: UserDefaults) -> [MouseGesture: ActionKind] {
        var result = DefaultMapping.mapping
        if let raw = d.dictionary(forKey: Keys.mapping) as? [String: String] {
            for (g, a) in raw {
                if let gesture = MouseGesture(rawValue: g), let action = ActionKind(rawValue: a) {
                    result[gesture] = action
                }
            }
        }
        return result
    }

    private func save() {
        defaults.set(enabled, forKey: Keys.enabled)
        defaults.set(Dictionary(uniqueKeysWithValues: mapping.map { ($0.key.rawValue, $0.value.rawValue) }), forKey: Keys.mapping)
        defaults.set(sensitivity, forKey: Keys.sensitivity)
        defaults.set(pauseScrollDuringGestures, forKey: Keys.pauseScroll)
        defaults.set(threeFingerClickIsMiddleClick, forKey: Keys.threeFingerClick)
        defaults.set(showHUD, forKey: Keys.showHUD)
        defaults.set(invertVertical, forKey: Keys.invertVertical)
        defaults.set(showMenuBarIcon, forKey: Keys.showMenuBarIcon)
        defaults.set(lowBatteryReminder, forKey: Keys.lowBatteryReminder)
        defaults.set(reverseMouseScroll, forKey: Keys.reverseMouseScroll)
        defaults.set(mouseScrollSpeed, forKey: Keys.mouseScrollSpeed)
        defaults.set(ignoreTapsWhileMoving, forKey: Keys.ignoreTapsWhileMoving)
    }

    private static var today: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private func countGesture() {
        let day = Self.today
        if defaults.string(forKey: Keys.gesturesDay) != day {
            defaults.set(day, forKey: Keys.gesturesDay)
            gesturesToday = 0
        }
        gesturesToday += 1
        defaults.set(gesturesToday, forKey: Keys.gesturesCount)
    }

    private func pushConfig() {
        var config = RecognizerConfig()
        config.swipeDistanceMM = RecognizerConfig.swipeDistance(forSensitivity: sensitivity)
        config.invertVertical = invertVertical
        TouchEngine.shared.update(config: config, enabled: enabled)
    }
}
