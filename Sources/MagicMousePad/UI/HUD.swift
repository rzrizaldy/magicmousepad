import AppKit
import MagicMousePadCore
import SwiftUI

/// A brief glass HUD confirming each gesture — the "haptics" a Magic Mouse doesn't have.
@MainActor
final class HUDController {
    static let shared = HUDController()

    private var panel: NSPanel?
    private var hideWork: DispatchWorkItem?
    private let size = NSSize(width: 210, height: 210)

    func show(gesture: MouseGesture, action: ActionKind) {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        panel.contentView = NSHostingView(rootView: HUDView(gesture: gesture, action: action))

        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        if let frame = screen?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2, y: frame.minY + 120))
        }

        hideWork?.cancel()
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.12; panel.animator().alphaValue = 1 }

        let work = DispatchWorkItem { [weak panel] in
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.35; panel?.animator().alphaValue = 0 },
                                                 completionHandler: { panel?.orderOut(nil) })
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.appearance = NSAppearance(named: .aqua)
        return panel
    }
}

private struct HUDView: View {
    let gesture: MouseGesture
    let action: ActionKind

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: action.symbol)
                .font(.system(size: 38, weight: .medium))
                .foregroundStyle(Color(red: 0.36, green: 0.25, blue: 0.04))
                .frame(width: 84, height: 84)
                .background(LinearGradient(colors: [Color(red: 1, green: 0.953, blue: 0.82), Color(red: 0.93, green: 0.78, blue: 0.47)],
                                           startPoint: .top, endPoint: .bottom),
                            in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.8), lineWidth: 1))
                .shadow(color: Theme.goldDeep.opacity(0.35), radius: 10, y: 6)
            VStack(spacing: 3) {
                Text(action.title).font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.ink)
                Text(gesture.title).font(.system(size: 12)).foregroundStyle(Theme.secondary)
            }
        }
        .frame(width: 186, height: 186)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 36, style: .continuous))
        .background(Color.white.opacity(0.4), in: RoundedRectangle(cornerRadius: 36, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 36, style: .continuous).strokeBorder(.white, lineWidth: 1))
        .shadow(color: Color(red: 0.31, green: 0.24, blue: 0.08).opacity(0.25), radius: 14, y: 8)
        .frame(width: 210, height: 210)
    }
}
