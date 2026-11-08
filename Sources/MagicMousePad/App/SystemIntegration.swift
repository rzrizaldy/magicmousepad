import AppKit
import ApplicationServices
import IOKit
import MagicMousePadCore
import ServiceManagement

enum Permissions {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    static func prompt() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    static func openAccessibilitySettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    static func openMouseSettings() {
        open("x-apple.systempreferences:com.apple.Mouse-Settings.extension")
    }

    private static func open(_ string: String) {
        if let url = URL(string: string) { NSWorkspace.shared.open(url) }
    }
}

enum LaunchAtLogin {
    static func set(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("MagicMousePad: launch-at-login change failed: \(error.localizedDescription)")
        }
    }
}

enum Battery {
    /// Battery level reported by the Magic Mouse's device-management service.
    static func percent(forProductID productID: Int) -> Int? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault,
                                           IOServiceMatching("AppleDeviceManagementHIDEventService"),
                                           &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer { IOObjectRelease(service); service = IOIteratorNext(iterator) }
            let pid = IORegistryEntrySearchCFProperty(service, kIOServicePlane, "ProductID" as CFString, nil,
                                                      IOOptionBits(kIORegistryIterateRecursively | kIORegistryIterateParents)) as? NSNumber
            guard pid?.intValue == productID,
                  let percent = IORegistryEntryCreateCFProperty(service, "BatteryPercent" as CFString, nil, 0)?
                    .takeRetainedValue() as? NSNumber
            else { continue }
            return percent.intValue
        }
        return nil
    }
}

extension TrackpadProfile {
    /// Reads this Mac's trackpad settings (built-in and Magic Trackpad share them).
    static func current() -> TrackpadProfile {
        let domains = ["com.apple.AppleMultitouchTrackpad", "com.apple.driver.AppleBluetoothMultitouch.trackpad"]
        domains.forEach { CFPreferencesAppSynchronize($0 as CFString) }
        func value(_ key: String) -> Int? {
            for domain in domains {
                if let n = CFPreferencesCopyAppValue(key as CFString, domain as CFString) as? NSNumber { return n.intValue }
            }
            return nil
        }
        let swipeNav = (UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?["AppleEnableSwipeNavigateWithScrolls"] as? NSNumber)?.boolValue
        return .from(value: value, swipeNavigateWithScrolls: swipeNav)
    }
}

/// A built-in macOS Magic Mouse gesture that overlaps with one of ours.
struct NativeGestureConflict: Identifiable, Equatable {
    let id: String
    let settingName: String

    private static let domains = ["com.apple.AppleMultitouchMouse", "com.apple.driver.AppleBluetoothMultitouch.mouse"]

    private static func nativeValue(_ key: String) -> Int {
        for domain in domains {
            CFPreferencesAppSynchronize(domain as CFString)
            if let n = CFPreferencesCopyAppValue(key as CFString, domain as CFString) as? NSNumber {
                return n.intValue
            }
        }
        return 0
    }

    static func detect(mapping: [MouseGesture: ActionKind]) -> [NativeGestureConflict] {
        func used(_ gestures: [MouseGesture]) -> Bool { gestures.contains { (mapping[$0] ?? ActionKind.none) != ActionKind.none } }
        var result: [NativeGestureConflict] = []
        if nativeValue("MouseTwoFingerHorizSwipeGesture") != 0, used([.twoFingerSwipeLeft, .twoFingerSwipeRight]) {
            result.append(.init(id: "swipe", settingName: "Swipe between full-screen applications"))
        }
        if nativeValue("MouseTwoFingerDoubleTapGesture") != 0, used([.twoFingerTap]) {
            result.append(.init(id: "doubletap", settingName: "Mission Control"))
        }
        return result
    }
}
