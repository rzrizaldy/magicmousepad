import AppKit
import MagicMousePadCore
import SwiftUI

/// The floating guide: a small capsule near the bottom of the screen confirming each gesture —
/// the feedback a Magic Mouse can't give with haptics. Can be hidden (⌥⌘G).
@MainActor
final class HUDController {
    static let shared = HUDController()

    private var panel: NSPanel?
    private var hideWork: DispatchWorkItem?
    private let size = NSSize(width: 320, height: 84)

    func show(gesture: MouseGesture, action: ActionKind) {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        panel.contentView = NSHostingView(rootView: GuideView(gesture: gesture, action: action))

        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        if let frame = screen?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2, y: frame.minY + 72))
        }

        hideWork?.cancel()
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.12; panel.animator().alphaValue = 1 }

        let work = DispatchWorkItem { [weak panel] in
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.3; panel?.animator().alphaValue = 0 },
                                                 completionHandler: { panel?.orderOut(nil) })
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: work)
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
        return panel
    }
}

private struct GuideView: View {
    let gesture: MouseGesture
    let action: ActionKind

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: action.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.accentText)
                .frame(width: 36, height: 36)
                .background(Theme.well, in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(action.title).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.ink)
                Text(gesture.title).font(.system(size: 12)).foregroundStyle(Theme.secondary)
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 22)
        .frame(height: 60)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.hairline.opacity(0.5), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
        .frame(width: 320, height: 84)
    }
}
