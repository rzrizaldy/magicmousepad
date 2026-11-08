import MagicMousePadCore
import SwiftUI

struct MainView: View {
    @EnvironmentObject private var state: AppState
    @State private var pulse = 0

    var body: some View {
        HStack(spacing: 0) {
            StatusPane(pulse: pulse)
                .frame(width: 360)
            Rectangle().fill(Theme.hairline.opacity(0.6)).frame(width: 0.5)
            ScrollView(showsIndicators: false) {
                SettingsPane(pulse: pulse)
                    .padding(.horizontal, 28)
                    .padding(.top, 6)
                    .padding(.bottom, 28)
            }
        }
        .padding(.top, 34) // traffic lights live in the transparent title bar
        .frame(width: 1120, height: 760)
        .background(Theme.canvas)
        .foregroundStyle(Theme.ink)
        .onChange(of: state.lastGestureDate) { _ in pulse += 1 }
    }
}

// MARK: - Status pane

private struct StatusPane: View {
    @EnvironmentObject private var state: AppState
    let pulse: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                badge
                Spacer()
                Toggle("Gestures", isOn: $state.enabled)
                    .toggleStyle(.switch).labelsHidden().tint(Theme.good)
                    .help("Turn all gestures on or off (⌥⌘P)")
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(state.mouse == nil ? "No Magic Mouse" : "Magic Mouse")
                    .font(Typo.hero).tracking(-0.6)
                Text(subtitle).font(Typo.body).foregroundStyle(Theme.secondary)
            }

            IsoMouseView(touches: state.liveTouches, connected: state.mouse != nil, pulse: pulse)
                .frame(maxWidth: .infinity)
                .frame(height: 236)

            stats

            VStack(alignment: .leading, spacing: 4) {
                DataLabel("Last gesture")
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    HStack(alignment: .center) {
                        if let g = state.lastGesture {
                            Text("\(g.title) → \(state.action(for: g).title)")
                                .font(.system(size: 14, weight: .semibold))
                            Spacer(minLength: 8)
                            Text(ago(state.lastGestureDate, now: context.date))
                                .font(Typo.mono).foregroundStyle(Theme.secondary)
                        } else {
                            Text(state.mouse == nil ? "Turn on or connect your Magic Mouse" : "Try a two-finger swipe")
                                .font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.secondary)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
            notices
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 22)
    }

    private var badge: some View {
        if state.mouse == nil {
            return StatusBadge(text: "No mouse", dot: Theme.tertiary, fill: Theme.idleFill, ink: Theme.secondary)
        }
        if !state.accessibilityGranted {
            return StatusBadge(text: "Needs access", dot: Theme.warn, fill: Theme.warnFill, ink: Theme.warnText)
        }
        if !state.enabled {
            return StatusBadge(text: "Paused", dot: Theme.tertiary, fill: Theme.idleFill, ink: Theme.secondary)
        }
        return StatusBadge(text: "Active", dot: Theme.good, fill: Theme.goodFill, ink: Theme.goodText)
    }

    private var subtitle: String {
        guard let mouse = state.mouse else {
            return state.multitouchAvailable ? "Turn it on or plug it in" : "Multitouch isn’t available on this Mac"
        }
        let model: String
        switch mouse.productID {
        case 0x0323: model = "USB‑C model"
        case 0x0269: model = "Magic Mouse 2"
        case 0x030D: model = "First generation"
        default: model = "Magic Mouse"
        }
        return mouse.transport.isEmpty ? model : "\(model) · \(mouse.transport)"
    }

    private var stats: some View {
        HStack(alignment: .top, spacing: 0) {
            stat("Battery", state.batteryPercent.map { "\($0)%" } ?? "—")
            stat("Fingers", "\(state.liveTouches.count)")
            stat("Today", "\(state.gesturesToday)")
        }
        .padding(.vertical, 14)
        .overlay(alignment: .top) { Rectangle().fill(Theme.hairline.opacity(0.6)).frame(height: 0.5) }
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.hairline.opacity(0.6)).frame(height: 0.5) }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            DataLabel(label)
            Text(value).font(Typo.stat).tracking(-0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var notices: some View {
        VStack(spacing: 8) {
            if !state.accessibilityGranted {
                Notice(text: "Allow Accessibility so gestures can switch Spaces, go back and click.",
                       action: "Allow") { state.requestAccessibility() }
            }
            if !state.conflicts.isEmpty {
                Notice(text: "macOS also uses " + state.conflicts.map { "“\($0.settingName)”" }.joined(separator: " and ")
                       + " on the mouse. Turn it off to avoid double actions.",
                       action: "Fix") { Permissions.openMouseSettings() }
            }
        }
    }

    private func ago(_ date: Date?, now: Date) -> String {
        guard let date else { return "" }
        let s = max(0, Int(now.timeIntervalSince(date)))
        if s < 60 { return "\(s)s ago" }
        if s < 3600 { return "\(s / 60)m ago" }
        return "\(s / 3600)h ago"
    }
}

private struct Notice: View {
    let text: String
    let action: String
    let perform: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Circle().fill(Theme.warn).frame(width: 6, height: 6)
            Text(text).font(Typo.caption).foregroundStyle(Theme.warnText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Button(action, action: perform).buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.accentText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.warnFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Settings pane

private struct SettingsPane: View {
    @EnvironmentObject private var state: AppState
    let pulse: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header
            HStack(alignment: .top, spacing: 22) {
                VStack(spacing: 22) {
                    RowGroup(title: "One finger") {
                        gestureRow(.oneFingerTap)
                    }
                    RowGroup(title: "Two fingers") {
                        ForEach([MouseGesture.twoFingerSwipeRight, .twoFingerSwipeLeft, .twoFingerSwipeUp,
                                 .twoFingerSwipeDown, .twoFingerTap, .pinchOut, .pinchIn]) { gestureRow($0) }
                    }
                    RowGroup(title: "Behavior") {
                        SliderRow(symbol: "ruler", title: "Swipe distance",
                                  value: "\(Int(RecognizerConfig.swipeDistance(forSensitivity: state.sensitivity).rounded())) mm",
                                  binding: Binding(get: { 1 - state.sensitivity }, set: { state.sensitivity = 1 - $0 }))
                        ToggleRow(symbol: "hand.raised", title: "Ignore taps while moving",
                                  detail: state.ignoredTaps > 0 ? "\(state.ignoredTaps) accidental taps blocked" : "Gripping the mouse never clicks",
                                  isOn: $state.ignoreTapsWhileMoving)
                        ToggleRow(symbol: "pause", title: "Pause scroll during gestures", isOn: $state.pauseScrollDuringGestures)
                        ToggleRow(symbol: "arrow.up.arrow.down", title: "Invert up and down swipes", isOn: $state.invertVertical)
                    }
                }
                VStack(spacing: 22) {
                    RowGroup(title: "Scrolling") {
                        if !state.shouldPauseScroll(fingers: 2) {
                            InfoRow(glyph: GestureGlyph(fingers: 2, symbol: "arrow.up.and.down"),
                                    title: "Two-finger up / down", value: "Scroll")
                        }
                        ToggleRow(symbol: "arrow.up.arrow.down.circle", title: "Reverse on mouse only",
                                  detail: "Your trackpad keeps its direction", isOn: $state.reverseMouseScroll)
                        SliderRow(symbol: "gauge.with.dots.needle.50percent", title: "Speed on mouse",
                                  value: String(format: "%.1f×", state.mouseScrollSpeed),
                                  binding: Binding(get: { (state.mouseScrollSpeed - 0.5) / 1.5 },
                                                   set: { state.mouseScrollSpeed = ((0.5 + $0 * 1.5) * 10).rounded() / 10 }))
                    }
                    RowGroup(title: "Three fingers") {
                        ForEach([MouseGesture.threeFingerSwipeLeft, .threeFingerSwipeRight, .threeFingerSwipeUp,
                                 .threeFingerSwipeDown, .threeFingerTap]) { gestureRow($0) }
                        ToggleRow(glyph: GestureGlyph(fingers: 3, symbol: "cursorarrow.click"),
                                  title: "Click is middle click", isOn: $state.threeFingerClickIsMiddleClick)
                    }
                    RowGroup(title: "App") {
                        ToggleRow(symbol: "rectangle.on.rectangle", title: "Floating guide",
                                  detail: "Brief confirmation on screen · ⌥⌘G", isOn: $state.showHUD)
                        ToggleRow(symbol: "menubar.rectangle", title: "Menu bar icon",
                                  detail: state.showMenuBarIcon ? nil : "Open the app again to see this window",
                                  isOn: $state.showMenuBarIcon)
                        ToggleRow(symbol: "battery.25", title: "Low-battery reminder",
                                  detail: "Alerts at 15% and 5%", isOn: $state.lowBatteryReminder)
                        ToggleRow(symbol: "power", title: "Open at login", isOn: $state.launchAtLogin)
                    }
                    footer
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Gestures").font(Typo.title).tracking(-0.4)
                Text(state.matchesTrackpad
                     ? "Matches your trackpad · " + state.trackpadSummary.prefix(3).joined(separator: ", ").lowercased()
                     : "Customized · differs from your trackpad")
                    .font(Typo.body).foregroundStyle(Theme.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button(state.matchesTrackpad ? "Re-sync trackpad" : "Match my trackpad") { state.matchTrackpad() }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.accentText)
                .help("Copy System Settings › Trackpad onto the mouse surface")
        }
    }

    private func gestureRow(_ g: MouseGesture) -> some View {
        GestureRow(gesture: g,
                   action: Binding(get: { state.action(for: g) }, set: { state.setAction($0, for: g) }),
                   flash: state.lastGesture == g, pulse: pulse)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button("Restore defaults") { state.restoreDefaults() }.buttonStyle(.plain).foregroundStyle(Theme.accentText)
            Spacer()
            Link("GitHub", destination: URL(string: "https://github.com/rzrizaldy/magicmousepad")!)
                .foregroundStyle(Theme.accentText)
            Text("v\(Bundle.main.shortVersion)").font(Typo.mono).foregroundStyle(Theme.tertiary)
        }
        .font(.system(size: 12, weight: .medium))
        .padding(.horizontal, 4)
    }
}

// MARK: - Rows

private struct RowShell<Trailing: View>: View {
    let glyph: GestureGlyph
    let title: String
    var detail: String? = nil
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            glyph
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(Typo.row).lineLimit(1).fixedSize()
                if let detail { Text(detail).font(.system(size: 11)).foregroundStyle(Theme.secondary).lineLimit(1) }
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
    }
}

private struct GestureRow: View {
    let gesture: MouseGesture
    @Binding var action: ActionKind
    var flash: Bool
    var pulse: Int
    @State private var lit = false

    var body: some View {
        RowShell(glyph: GestureGlyph(fingers: gesture.fingers, symbol: gesture.isTap ? nil : gesture.symbol),
                 title: gesture.shortTitle) {
            Menu {
                Picker("Action", selection: $action) {
                    Text(ActionKind.none.title).tag(ActionKind.none)
                    ForEach(ActionKind.Group.allCases, id: \.self) { group in
                        Section(group.rawValue) {
                            ForEach(ActionKind.actions(in: group)) { Text($0.title).tag($0) }
                        }
                    }
                }
                .pickerStyle(.inline).labelsHidden()
            } label: {
                Text(action == .none ? "None" : action.title)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.visible)
            .fixedSize()
            .foregroundStyle(action == .none ? Theme.tertiary : Theme.secondary)
            .accessibilityLabel(Text("\(gesture.title) action"))
        }
        .background(Theme.accent.opacity(lit ? 0.12 : 0))
        .onChange(of: pulse) { _ in
            guard flash else { return }
            withAnimation(.easeOut(duration: 0.1)) { lit = true }
            withAnimation(.easeIn(duration: 0.6).delay(0.4)) { lit = false }
        }
    }
}

private struct ToggleRow: View {
    var glyph: GestureGlyph
    let title: String
    var detail: String? = nil
    @Binding var isOn: Bool

    init(symbol: String, title: String, detail: String? = nil, isOn: Binding<Bool>) {
        self.init(glyph: GestureGlyph(symbol: symbol), title: title, detail: detail, isOn: isOn)
    }

    init(glyph: GestureGlyph, title: String, detail: String? = nil, isOn: Binding<Bool>) {
        self.glyph = glyph
        self.title = title
        self.detail = detail
        self._isOn = isOn
    }

    var body: some View {
        RowShell(glyph: glyph, title: title, detail: detail) {
            Toggle(title, isOn: $isOn).toggleStyle(.switch).labelsHidden().controlSize(.small).tint(Theme.good)
        }
    }
}

private struct SliderRow: View {
    let symbol: String
    let title: String
    let value: String
    @Binding var binding: Double

    init(symbol: String, title: String, value: String, binding: Binding<Double>) {
        self.symbol = symbol
        self.title = title
        self.value = value
        self._binding = binding
    }

    var body: some View {
        RowShell(glyph: GestureGlyph(symbol: symbol), title: title) {
            Slider(value: $binding, in: 0...1).frame(minWidth: 70, maxWidth: 110).controlSize(.small).tint(Theme.accent)
                .accessibilityLabel(Text(title))
            Text(value).font(Typo.mono).foregroundStyle(Theme.secondary).frame(width: 44, alignment: .trailing)
        }
    }
}

private struct InfoRow: View {
    let glyph: GestureGlyph
    let title: String
    let value: String

    var body: some View {
        RowShell(glyph: glyph, title: title) {
            Text(value).font(Typo.body).foregroundStyle(Theme.secondary)
        }
    }
}

extension Bundle {
    var shortVersion: String { infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev" }
}
