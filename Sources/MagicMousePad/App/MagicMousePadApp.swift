import AppKit
import SwiftUI

@main
struct MagicMousePadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var state = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContent().environmentObject(state)
        } label: {
            Image(systemName: state.enabled ? "magicmouse.fill" : "magicmouse")
        }
        .menuBarExtraStyle(.menu)
    }
}

private struct MenuContent: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        Text(statusLine)
        Toggle("Gestures On", isOn: $state.enabled)
            .keyboardShortcut("p", modifiers: [.option, .command])
        if let g = state.lastGesture {
            Text("Last: \(g.title) → \(state.action(for: g).title)")
        }
        Divider()
        Button("Open MagicMousePad…") { AppDelegate.shared?.showWindow() }
            .keyboardShortcut(",")
        Divider()
        Button("Quit MagicMousePad") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private var statusLine: String {
        guard let mouse = state.mouse else { return "No Magic Mouse connected" }
        if let battery = state.batteryPercent { return "\(mouse.name) · \(battery)%" }
        return mouse.name
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static private(set) weak var shared: AppDelegate?
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        NSApp.setActivationPolicy(.accessory)

        // `--snapshot <file.png>` renders the main window offscreen (used for README screenshots).
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count {
            renderSnapshot(to: URL(fileURLWithPath: args[i + 1]))
            NSApp.terminate(nil)
            return
        }

        AppState.shared.start()

        let firstLaunchKey = "hasLaunchedBefore"
        if !UserDefaults.standard.bool(forKey: firstLaunchKey) || !AppState.shared.accessibilityGranted {
            UserDefaults.standard.set(true, forKey: firstLaunchKey)
            showWindow()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        TouchEngine.shared.stop()
    }

    func showWindow() {
        if window == nil {
            let hosting = NSHostingController(rootView: MainView().environmentObject(AppState.shared))
            let w = NSWindow(contentViewController: hosting)
            w.title = "MagicMousePad"
            w.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isMovableByWindowBackground = true
            w.appearance = NSAppearance(named: .aqua)
            w.isReleasedWhenClosed = false
            w.delegate = self
            w.center()
            window = w
        }
        AppState.shared.refreshConflicts()
        AppState.shared.refreshBattery()
        AppState.shared.setPreviewActive(true)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func renderSnapshot(to url: URL) {
        AppState.shared.loadDemoState()
        let view = NSHostingView(rootView: MainView().environmentObject(AppState.shared))
        let window = NSWindow(contentRect: NSRect(x: -4000, y: 0, width: 1100, height: 720),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .aqua)
        window.contentView = view
        window.orderFrontRegardless()
        RunLoop.main.run(until: Date().addingTimeInterval(0.6))
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
        window.orderOut(nil)
    }

    func windowDidBecomeKey(_ notification: Notification) {
        AppState.shared.refreshConflicts()
    }

    func windowWillClose(_ notification: Notification) {
        AppState.shared.setPreviewActive(false)
        NSApp.setActivationPolicy(.accessory)
    }
}
