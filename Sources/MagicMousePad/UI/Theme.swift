import SwiftUI

/// "Golden-era Mac" visual language: pearl backgrounds, frosted glass, champagne gold.
enum Theme {
    static let ink = Color(red: 0.114, green: 0.114, blue: 0.122)        // #1D1D1F
    static let secondary = Color(red: 0.369, green: 0.369, blue: 0.40)   // #5E5E66
    static let goldText = Color(red: 0.478, green: 0.341, blue: 0.063)   // #7A5710
    static let goldDeep = Color(red: 0.843, green: 0.631, blue: 0.243)   // #D7A13E
    static let goldLight = Color(red: 0.953, green: 0.835, blue: 0.561)  // #F3D58F
    static let goldPale = Color(red: 1.0, green: 0.965, blue: 0.875)     // #FFF6DF
    static let goldGlow = Color(red: 0.906, green: 0.690, blue: 0.290)   // #E7B04A
    static let success = Color(red: 0.204, green: 0.780, blue: 0.349)
    static let warning = Color(red: 1.0, green: 0.62, blue: 0.04)

    static let gold = LinearGradient(colors: [goldLight, goldDeep], startPoint: .top, endPoint: .bottom)
    static let goldTile = LinearGradient(colors: [goldPale, Color(red: 0.953, green: 0.875, blue: 0.682)],
                                         startPoint: .top, endPoint: .bottom)
}

/// Window backdrop: warm champagne glow top-left, cool sky bottom-right, pearl in between.
struct PearlBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 1, green: 0.992, blue: 0.973),
                                    Color(red: 0.961, green: 0.953, blue: 0.933),
                                    Color(red: 0.933, green: 0.949, blue: 0.973)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [Color(red: 0.984, green: 0.922, blue: 0.769), .clear],
                           center: UnitPoint(x: 0.15, y: 0.05), startRadius: 0, endRadius: 560)
            RadialGradient(colors: [Color(red: 0.867, green: 0.910, blue: 0.969), .clear],
                           center: UnitPoint(x: 0.95, y: 1.0), startRadius: 0, endRadius: 520)
        }
        .ignoresSafeArea()
    }
}

/// Frosted glass card with a crisp top highlight and a warm soft shadow.
struct GlassCard: ViewModifier {
    var radius: CGFloat = 24
    var padding: CGFloat = 20

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .padding(padding)
            .background(.ultraThinMaterial, in: shape)
            .background(Color.white.opacity(0.45), in: shape)
            .overlay(shape.strokeBorder(
                LinearGradient(colors: [.white, .white.opacity(0.55)], startPoint: .top, endPoint: .bottom),
                lineWidth: 1))
            .shadow(color: Color(red: 0.47, green: 0.38, blue: 0.16).opacity(0.12), radius: 22, y: 14)
    }
}

extension View {
    func glassCard(radius: CGFloat = 24, padding: CGFloat = 20) -> some View {
        modifier(GlassCard(radius: radius, padding: padding))
    }
}

/// Gold capsule switch.
struct GoldToggleStyle: ToggleStyle {
    var width: CGFloat = 40
    var height: CGFloat = 24

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 10) {
            configuration.label
            Spacer(minLength: 0)
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(configuration.isOn ? AnyShapeStyle(Theme.gold) : AnyShapeStyle(Color.black.opacity(0.10)))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(configuration.isOn ? 0.6 : 0), lineWidth: 1))
                    .shadow(color: Theme.goldDeep.opacity(configuration.isOn ? 0.35 : 0), radius: 5, y: 2)
                Circle()
                    .fill(LinearGradient(colors: [.white, Color(white: 0.95)], startPoint: .top, endPoint: .bottom))
                    .shadow(color: .black.opacity(0.25), radius: 1.5, y: 1)
                    .padding(2)
            }
            .frame(width: width, height: height)
            .contentShape(Capsule())
            .onTapGesture {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) { configuration.isOn.toggle() }
            }
            .accessibilityElement()
            .accessibilityLabel(Text("Toggle"))
            .accessibilityValue(Text(configuration.isOn ? "On" : "Off"))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { configuration.isOn.toggle() }
        }
    }
}

/// Primary gold button.
struct GoldButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color(red: 0.24, green: 0.17, blue: 0.02))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Theme.gold, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.white.opacity(0.55), lineWidth: 1))
            .shadow(color: Theme.goldDeep.opacity(0.35), radius: 4, y: 2)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct StatusDot: View {
    var color: Color
    var body: some View {
        Circle().fill(color).frame(width: 8, height: 8).shadow(color: color.opacity(0.7), radius: 4)
    }
}
