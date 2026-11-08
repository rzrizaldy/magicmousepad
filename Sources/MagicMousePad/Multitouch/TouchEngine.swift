import AppKit
import CMultitouch
import Foundation
import IOKit
import MagicMousePadCore

/// Owns the multitouch devices, watches for (dis)connects and turns raw touch
/// frames from the Magic Mouse into gestures.
///
/// Frames arrive on MultitouchSupport's private thread; everything shared with
/// the main thread is guarded by `lock`.
final class TouchEngine {
    static let shared = TouchEngine()

    /// Called on the main thread when a gesture is recognized.
    var onGesture: ((MouseGesture) -> Void)?
    /// Called on the main thread when the list of devices changes.
    var onDevicesChanged: (([DeviceInfo]) -> Void)?
    /// Called on the main thread (throttled) with the live touches, while `previewEnabled`.
    var onTouches: (([TouchPoint]) -> Void)?

    private let lock = NSLock()
    private var devices: [Int32: DeviceInfo] = [:]
    private var recognizers: [Int32: GestureRecognizer] = [:]
    private var config = RecognizerConfig()
    private var enabled = true
    private var _previewEnabled = false
    private var lastPreview: TimeInterval = 0
    private var fingerCounts: [Int32: Int] = [:]

    private var notifyPort: IONotificationPortRef?
    private var restartWork: DispatchWorkItem?

    private init() {}

    // MARK: - Thread-safe settings

    var isAvailable: Bool { MMMultitouchAvailable() }

    func update(config: RecognizerConfig, enabled: Bool) {
        lock.lock()
        self.config = config
        self.enabled = enabled
        for (index, r) in recognizers {
            r.config = adjusted(config, for: devices[index])
            if !enabled { r.reset() }
        }
        lock.unlock()
    }

    var previewEnabled: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _previewEnabled }
        set { lock.lock(); _previewEnabled = newValue; lock.unlock() }
    }

    /// Largest number of fingers currently resting on any Magic Mouse.
    var currentFingerCount: Int {
        lock.lock(); defer { lock.unlock() }
        return fingerCounts.values.max() ?? 0
    }

    /// Lets the recognizers know a physical click happened (cancels taps).
    func noteClick() {
        lock.lock()
        recognizers.values.forEach { $0.noteClick() }
        lock.unlock()
    }

    // MARK: - Lifecycle

    func start() {
        guard isAvailable else {
            onDevicesChanged?([])
            return
        }
        restartDevices()
        watchForDeviceChanges()
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.scheduleRestart(after: 2) }
    }

    func stop() {
        MMStopAllDevices()
    }

    private func scheduleRestart(after delay: TimeInterval = 1) {
        restartWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.restartDevices() }
        restartWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func restartDevices() {
        let count = MMRefreshDevices()
        var found: [Int32: DeviceInfo] = [:]
        for i in 0..<count {
            found[i] = DeviceInfo(index: i, service: MMDeviceService(i))
        }

        lock.lock()
        devices = found
        fingerCounts = [:]
        recognizers = [:]
        for (index, info) in found where info.isMagicMouse {
            let r = GestureRecognizer(config: adjusted(config, for: info))
            r.onGesture = { gesture in
                DispatchQueue.main.async { TouchEngine.shared.onGesture?(gesture) }
            }
            recognizers[index] = r
        }
        lock.unlock()

        for index in found.keys where found[index]?.isMagicMouse == true {
            _ = MMStartDevice(index, touchFrameCallback)
        }

        let list = found.values.sorted { $0.index < $1.index }
        onDevicesChanged?(list)
    }

    private func adjusted(_ config: RecognizerConfig, for info: DeviceInfo?) -> RecognizerConfig {
        var c = config
        if let info, info.widthMM > 0, info.heightMM > 0 {
            c.surfaceWidthMM = info.widthMM
            c.surfaceHeightMM = info.heightMM
        }
        return c
    }

    // MARK: - Frames (MultitouchSupport thread)

    fileprivate func handleFrame(device: Int32, touches: UnsafePointer<MMTouch>?, count: Int32, timestamp: Double) {
        var points: [TouchPoint] = []
        if let touches {
            points.reserveCapacity(Int(count))
            for i in 0..<Int(count) {
                let t = touches[i]
                guard t.state == Int32(MMTouchStateMakeTouch.rawValue)
                    || t.state == Int32(MMTouchStateTouching.rawValue) else { continue }
                points.append(TouchPoint(id: t.identifier, x: Double(t.x), y: Double(t.y)))
            }
        }

        lock.lock()
        guard let recognizer = recognizers[device] else { lock.unlock(); return }
        fingerCounts[device] = points.count
        if enabled { recognizer.process(points, at: timestamp) }

        var sendPreview = false
        if _previewEnabled, timestamp - lastPreview > 1.0 / 60.0 || points.isEmpty {
            lastPreview = timestamp
            sendPreview = true
        }
        lock.unlock()

        if sendPreview {
            DispatchQueue.main.async { TouchEngine.shared.onTouches?(points) }
        }
    }

    // MARK: - Hot-plug

    private func watchForDeviceChanges() {
        guard notifyPort == nil, let port = IONotificationPortCreate(kIOMainPortDefault) else { return }
        notifyPort = port
        CFRunLoopAddSource(CFRunLoopGetMain(), IONotificationPortGetRunLoopSource(port).takeUnretainedValue(), .defaultMode)

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOServiceMatchingCallback = { refcon, iterator in
            // Drain the iterator, then debounce a full restart.
            while case let entry = IOIteratorNext(iterator), entry != 0 { IOObjectRelease(entry) }
            guard let refcon else { return }
            Unmanaged<TouchEngine>.fromOpaque(refcon).takeUnretainedValue().scheduleRestart()
        }

        for type in [kIOFirstMatchNotification, kIOTerminatedNotification] {
            var iterator: io_iterator_t = 0
            let matching = IOServiceMatching("AppleMultitouchDevice")
            if IOServiceAddMatchingNotification(port, type, matching, callback, refcon, &iterator) == KERN_SUCCESS {
                // Arm the notification by draining existing matches.
                while case let entry = IOIteratorNext(iterator), entry != 0 { IOObjectRelease(entry) }
            }
        }
    }
}

/// C-compatible trampoline handed to MultitouchSupport.
private let touchFrameCallback: MMFrameCallback = { device, touches, count, timestamp in
    TouchEngine.shared.handleFrame(device: device, touches: touches, count: count, timestamp: timestamp)
}
