import MagicMousePadCore
import SwiftUI

struct MainView: View {
    @EnvironmentObject private var state: AppState
    @State private var pulse = 0

    var body: some View {
        ZStack {
            PearlBackground()
            HStack(alignment: .top, spacing: 22) {
                VStack(spacing: 16) {
                    heroCard
                    if !state.accessibilityGranted { permissionCard }
                    ForEach(state.conflicts) { conflictCard($0) }
                }
                .frame(width: 380)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        gestureCard(title: "Two fingers", subtitle: "Index + middle finger",
                                    gestures: MouseGesture.allCases.filter { $0.fingers == 2 })
                        gestureCard(title: "Three fingers", subtitle: "Spaces, desktop and middle click",
                                    gestures: MouseGesture.allCases.filter { $0.fingers == 3 })
                        feelCard
                        footer
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 2)
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, -16)
            }
            .padding(.horizontal, 26)
            .padding(.top, 40)
            .padding(.bottom, 22)
        }
        .frame(width: 1100, height: 720)
        .foregroundStyle(Theme.ink)
        .onChange(of: state.lastGestureDate) { _ in pulse += 1 }
    }

    // MARK: Hero

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("MagicMousePad").font(.system(size: 26, weight: .bold)).tracking(-0.4)
                    Text("Your Magic Mouse, now a trackpad.")
                        .font(.system(size: 13)).foregroundStyle(Theme.secondary)
                }
                Spacer()
                Toggle(isOn: $state.enabled) { EmptyView() }
                    .toggleStyle(GoldToggleStyle(width: 52, height: 30))
                    .fixedSize()
                    .help(state.enabled ? "Gestures are on" : "Gestures are paused")
            }

            IsoMouseView(touches: state.liveTouches, connected: state.mouse != nil, pulse: pulse)
                .frame(maxWidth: .infinity)

            lastGesturePill
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 8) {
                statusRow(ok: state.mouse != nil,
                          title: state.mouse?.name ?? "No Magic Mouse found",
                          detail: mouseDetail)
                statusRow(ok: state.accessibilityGranted,
                          title: "Accessibility",
                          detail: state.accessibilityGranted ? "Allowed" : "Needed to perform actions")
            }
            .padding(.top, 14)
        }
        .glassCard(radius: 26, padding: 22)
    }

    private var mouseDetail: String {
        guard let mouse = state.mouse else {
            return state.multitouchAvailable ? "Turn it on or connect it" : "Multitouch is unavailable on this Mac"
        }
        var parts = [mouse.transport.isEmpty ? "Connected" : mouse.transport]
        if let battery = state.batteryPercent { parts.append("\(battery)%") }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder private var lastGesturePill: some View {
        HStack(spacing: 8) {
            if let g = state.lastGesture {
                Text(g.title).fontWeight(.semibold)
                Image(systemName: "arrow.right").foregroundStyle(Theme.goldText)
                Text(state.action(for: g).title).fontWeight(.semibold).foregroundStyle(Theme.goldText)
            } else {
                Image(systemName: "hand.point.up.left").foregroundStyle(Theme.goldText)
                Text(state.mouse == nil ? "Waiting for your Magic Mouse" : "Try a two-finger swipe")
                    .foregroundStyle(Theme.secondary)
            }
        }
        .font(.system(size: 13))
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.75), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white, lineWidth: 1))
        .shadow(color: Color(red: 0.47, green: 0.38, blue: 0.16).opacity(0.12), radius: 9, y: 6)
        .animation(.spring(response: 0.3), value: state.lastGestureDate)
    }

    private func statusRow(ok: Bool, title: String, detail: String) -> some View {
        HStack(spacing: 10) {
            StatusDot(color: ok ? Theme.success : Theme.warning)
            Text(title).fontWeight(.semibold)
            Text(detail).foregroundStyle(Theme.secondary)
            Spacer()
        }
        .font(.system(size: 13))
    }

    // MARK: Banners

    private var permissionCard: some View {
        banner(icon: "lock.shield",
               text: Text("**Allow Accessibility** so MagicMousePad can switch Spaces, go back and click for you."),
               button: "Allow…") { state.requestAccessibility() }
    }

    private func conflictCard(_ conflict: NativeGestureConflict) -> some View {
        banner(icon: "exclamationmark.triangle",
               text: Text("**macOS also uses this gesture.** Turn off “\(conflict.settingName)” in Mouse settings so only one thing happens."),
               button: "Open") { Permissions.openMouseSettings() }
    }

    private func banner(icon: String, text: Text, button: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(Theme.goldText)
            text.font(.system(size: 12)).foregroundStyle(Color(red: 0.29, green: 0.23, blue: 0.07))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button(button, action: action).buttonStyle(GoldButtonStyle())
        }
        .padding(16)
        .background(LinearGradient(colors: [Color(red: 1, green: 0.965, blue: 0.87).opacity(0.9),
                                            Color(red: 0.988, green: 0.925, blue: 0.77).opacity(0.8)],
                                   startPoint: .top, endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white, lineWidth: 1))
        .shadow(color: Theme.goldDeep.opacity(0.14), radius: 15, y: 10)
    }

    // MARK: MouseGesture grid

    private func gestureCard(title: String, subtitle: String, gestures: [MouseGesture]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(title).font(.system(size: 15, weight: .bold))
                Text(subtitle).font(.system(size: 12)).foregroundStyle(Theme.secondary)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(gestures) { gesture in
                    GestureTile(gesture: gesture,
                                action: Binding(get: { state.action(for: gesture) },
                                                set: { state.setAction($0, for: gesture) }),
                                isFlashing: state.lastGesture == gesture && pulse > 0,
                                pulse: pulse)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 24, padding: 18)
    }

    // MARK: Feel

    private var feelCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Feel").font(.system(size: 15, weight: .bold))
            HStack(spacing: 12) {
                Text("Swipe distance").font(.system(size: 13, weight: .semibold)).frame(width: 110, alignment: .leading)
                Text("Long").font(.system(size: 12)).foregroundStyle(Theme.secondary)
                Slider(value: $state.sensitivity, in: 0...1)
                    .tint(Theme.goldDeep)
                    .accessibilityLabel(Text("Swipe distance"))
                Text("Short").font(.system(size: 12)).foregroundStyle(Theme.secondary)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 28), GridItem(.flexible(), spacing: 28)], spacing: 12) {
                Toggle("Show gesture HUD", isOn: $state.showHUD)
                Toggle("Pause scrolling while gesturing", isOn: $state.pauseScrollDuringGestures)
                Toggle("Three-finger click is middle click", isOn: $state.threeFingerClickIsMiddleClick)
                Toggle("Open at login", isOn: $state.launchAtLogin)
                Toggle("Invert up and down swipes", isOn: $state.invertVertical)
            }
            .toggleStyle(GoldToggleStyle())
            .font(.system(size: 13))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 24, padding: 18)
    }

    private var footer: some View {
        HStack {
            Button("Restore Defaults") { state.restoreDefaults() }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.goldText)
            Spacer()
            Link("Open source on GitHub", destination: URL(string: "https://github.com/rzrizaldy/magicmousepad")!)
                .foregroundStyle(Theme.goldText)
            Text("·").foregroundStyle(Theme.secondary)
            Text("v\(Bundle.main.shortVersion)").foregroundStyle(Theme.secondary)
        }
        .font(.system(size: 12, weight: .medium))
        .padding(.horizontal, 6)
    }
}

/// One gesture → action tile.
private struct GestureTile: View {
    let gesture: MouseGesture
    @Binding var action: ActionKind
    var isFlashing: Bool
    var pulse: Int
    @State private var highlight = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: gesture.symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.goldText)
                .frame(width: 30, height: 30)
                .background(Theme.goldTile, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(gesture.shortTitle).font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .fixedSize()
            Spacer(minLength: 4)
            Menu {
                Picker("Action", selection: $action) {
                    Label(ActionKind.none.title, systemImage: ActionKind.none.symbol).tag(ActionKind.none)
                    ForEach(ActionKind.Group.allCases, id: \.self) { group in
                        Section(group.rawValue) {
                            ForEach(ActionKind.actions(in: group)) { a in
                                Label(a.title, systemImage: a.symbol).tag(a)
                            }
                        }
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } label: {
                Text(action.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(action == .none ? Theme.secondary : Theme.ink)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.visible)
            .fixedSize()
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.045), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityLabel(Text("\(gesture.title) action"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(highlight ? 0.95 : 0.7), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(highlight ? AnyShapeStyle(Theme.gold) : AnyShapeStyle(Color.white), lineWidth: highlight ? 2 : 1))
        .shadow(color: Theme.goldGlow.opacity(highlight ? 0.45 : 0), radius: 10)
        .onChange(of: pulse) { _ in
            guard isFlashing else { return }
            withAnimation(.easeOut(duration: 0.12)) { highlight = true }
            withAnimation(.easeIn(duration: 0.6).delay(0.5)) { highlight = false }
        }
    }
}

extension Bundle {
    var shortVersion: String { infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev" }
}
