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
    @Published var mapping: [MouseGesture: ActionKind] { didSet { save(); pushConfig(); refreshConflicts() } }
    @Published var sensitivity: Double { didSet { save(); pushConfig() } }
    @Published var pauseScrollDuringGestures: Bool { didSet { save() } }
    @Published var threeFingerClickIsMiddleClick: Bool { didSet { save() } }
    @Published var showHUD: Bool { didSet { save() } }
    @Published var invertVertical: Bool { didSet { save(); pushConfig() } }

    // MARK: Live status

    @Published private(set) var devices: [DeviceInfo] = []
    @Published private(set) var accessibilityGranted = Permissions.isTrusted
    @Published private(set) var lastGesture: MouseGesture?
    @Published private(set) var lastGestureDate: Date?
    @Published private(set) var liveTouches: [TouchPoint] = []
    @Published private(set) var batteryPercent: Int?
    @Published private(set) var conflicts: [NativeGestureConflict] = []
    @Published var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled {
        didSet { LaunchAtLogin.set(launchAtLogin) }
    }

    var mouse: DeviceInfo? { devices.first(where: \.isMagicMouse) }
    var multitouchAvailable: Bool { TouchEngine.shared.isAvailable }

    private let defaults = UserDefaults.standard
    private let eventFilter = EventFilter()
    private var permissionTimer: Timer?

    private init() {
        let d = UserDefaults.standard
        d.register(defaults: [
            Keys.enabled: true,
            Keys.sensitivity: 0.5,
            Keys.pauseScroll: true,
            Keys.threeFingerClick: true,
            Keys.showHUD: true,
            Keys.invertVertical: false,
        ])
        enabled = d.bool(forKey: Keys.enabled)
        sensitivity = d.double(forKey: Keys.sensitivity)
        pauseScrollDuringGestures = d.bool(forKey: Keys.pauseScroll)
        threeFingerClickIsMiddleClick = d.bool(forKey: Keys.threeFingerClick)
        showHUD = d.bool(forKey: Keys.showHUD)
        invertVertical = d.bool(forKey: Keys.invertVertical)
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
            return self.enabled && self.pauseScrollDuringGestures && fingers >= 2 && self.hasActions(forFingers: fingers)
        }
        eventFilter.shouldConvertToMiddleClick = { [weak self] in
            guard let self else { return false }
            return self.enabled && self.threeFingerClickIsMiddleClick && TouchEngine.shared.currentFingerCount >= 3
        }
        eventFilter.onPhysicalClick = { TouchEngine.shared.noteClick() }

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
        lastGesture = .twoFingerSwipeRight
        lastGestureDate = Date()
        batteryPercent = 100
        accessibilityGranted = true
        TouchEngine.shared.onDevicesChanged = { [weak self] in self?.devices = $0 }
        TouchEngine.shared.start()
    }

    // MARK: Gestures

    private func handle(_ gesture: MouseGesture) {
        guard enabled else { return }
        let action = mapping[gesture] ?? .none
        guard action != .none else { return }
        lastGesture = gesture
        lastGestureDate = Date()
        ActionPerformer.perform(action)
        if showHUD { HUDController.shared.show(gesture: gesture, action: action) }
    }

    func action(for gesture: MouseGesture) -> ActionKind { mapping[gesture] ?? .none }

    func setAction(_ action: ActionKind, for gesture: MouseGesture) { mapping[gesture] = action }

    func hasActions(forFingers fingers: Int) -> Bool {
        mapping.contains { $0.key.fingers == fingers && $0.value != .none }
    }

    func restoreDefaults() {
        mapping = DefaultMapping.mapping
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
    }

    private func pushConfig() {
        var config = RecognizerConfig()
        config.swipeDistanceMM = RecognizerConfig.swipeDistance(forSensitivity: sensitivity)
        config.invertVertical = invertVertical
        TouchEngine.shared.update(config: config, enabled: enabled)
    }
}
