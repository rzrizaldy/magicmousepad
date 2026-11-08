import MagicMousePadCore
import SwiftUI

/// An isometric, live rendering of the Magic Mouse with the fingers currently on it.
struct IsoMouseView: View {
    var touches: [TouchPoint]
    var connected: Bool
    /// Bumped each time a gesture fires, to flash the surface.
    var pulse: Int

    private let size = CGSize(width: 150, height: 262)
    private let depth: CGFloat = 26
    @State private var glow = false

    var body: some View {
        ZStack {
            // Ground shadow
            Ellipse()
                .fill(Color(red: 0.59, green: 0.47, blue: 0.24).opacity(0.22))
                .frame(width: 230, height: 70)
                .blur(radius: 22)
                .offset(x: 6, y: 62)

            // Body — stacked slices give the extrusion.
            ForEach((1...6).reversed(), id: \.self) { i in
                shell(fill: LinearGradient(colors: [Color(red: 0.86, green: 0.84, blue: 0.80),
                                                    Color(red: 0.70, green: 0.67, blue: 0.62)],
                                           startPoint: .top, endPoint: .bottom))
                    .projectionEffect(iso)
                    .offset(y: depth * CGFloat(i) / 6)
            }

            // Top touch surface
            ZStack {
                shell(fill: LinearGradient(colors: [.white, Color(red: 0.97, green: 0.96, blue: 0.94),
                                                    Color(red: 0.90, green: 0.886, blue: 0.85)],
                                           startPoint: .top, endPoint: .bottom))
                    .overlay(
                        RoundedRectangle(cornerRadius: size.width * 0.48, style: .continuous)
                            .strokeBorder(Theme.goldGlow.opacity(glow ? 0.9 : 0), lineWidth: 3)
                            .blur(radius: 2)
                    )
                // Centre seam hint
                Rectangle()
                    .fill(LinearGradient(colors: [.black.opacity(0.08), .clear], startPoint: .top, endPoint: .bottom))
                    .frame(width: 1.5, height: size.height * 0.45)
                    .offset(y: -size.height * 0.22)

                ForEach(touches, id: \.id) { t in
                    finger
                        .position(x: CGFloat(t.x) * size.width, y: CGFloat(1 - t.y) * size.height)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: size.width, height: size.height)
            .projectionEffect(iso)
            .animation(.easeOut(duration: 0.08), value: touches)
        }
        .frame(width: 340, height: 330)
        .saturation(connected ? 1 : 0)
        .opacity(connected ? 1 : 0.55)
        .onChange(of: pulse) { _ in
            withAnimation(.easeOut(duration: 0.12)) { glow = true }
            withAnimation(.easeIn(duration: 0.5).delay(0.25)) { glow = false }
        }
        .accessibilityElement()
        .accessibilityLabel(Text(connected ? "Magic Mouse with \(touches.count) fingers touching" : "No Magic Mouse connected"))
    }

    private func shell(fill: LinearGradient) -> some View {
        RoundedRectangle(cornerRadius: size.width * 0.48, style: .continuous)
            .fill(fill)
            .frame(width: size.width, height: size.height)
    }

    private var finger: some View {
        Circle()
            .fill(RadialGradient(colors: [Color(red: 1, green: 0.957, blue: 0.84), Theme.goldGlow],
                                 center: UnitPoint(x: 0.35, y: 0.35), startRadius: 0, endRadius: 18))
            .frame(width: 30, height: 30)
            .background(Circle().fill(Theme.goldGlow.opacity(0.22)).frame(width: 44, height: 44))
            .shadow(color: Theme.goldGlow.opacity(0.8), radius: 12)
    }

    /// Classic isometric projection: rotate, then squash vertically — about the shape's centre.
    private var iso: ProjectionTransform {
        let cx = size.width / 2, cy = size.height / 2
        let t = CGAffineTransform(translationX: -cx, y: -cy)
            .concatenating(CGAffineTransform(rotationAngle: -38 * .pi / 180))
            .concatenating(CGAffineTransform(scaleX: 1, y: 0.56))
            .concatenating(CGAffineTransform(translationX: cx, y: cy))
        return ProjectionTransform(t)
    }
}
