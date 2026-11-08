import MagicMousePadCore
import SwiftUI

/// An isometric, live rendering of the Magic Mouse with the fingers currently on it.
struct IsoMouseView: View {
    var touches: [TouchPoint]
    var connected: Bool
    /// Bumped each time a gesture fires, to flash the surface.
    var pulse: Int

    private let size = CGSize(width: 124, height: 216)
    private let depth: CGFloat = 22
    @State private var lit = false

    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color.black.opacity(0.12))
                .frame(width: 200, height: 54)
                .blur(radius: 16)
                .offset(x: 4, y: 56)

            ForEach((1...5).reversed(), id: \.self) { i in
                shell(Color(nsColor: .tertiaryLabelColor).opacity(0.18 + Double(6 - i) * 0.03))
                    .background(shell(Theme.surface))
                    .projectionEffect(iso)
                    .offset(y: depth * CGFloat(i) / 5)
            }

            ZStack {
                shell(Theme.surface)
                    .overlay(RoundedRectangle(cornerRadius: size.width * 0.48, style: .continuous)
                        .strokeBorder(Theme.accent.opacity(lit ? 0.9 : 0), lineWidth: 2.5))
                    .overlay(RoundedRectangle(cornerRadius: size.width * 0.48, style: .continuous)
                        .strokeBorder(Theme.hairline.opacity(0.5), lineWidth: 0.5))
                Rectangle()
                    .fill(Theme.hairline.opacity(0.7))
                    .frame(width: 0.75, height: size.height * 0.44)
                    .offset(y: -size.height * 0.22)
                ForEach(touches, id: \.id) { t in
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Theme.accent.opacity(0.2)).frame(width: 34, height: 34))
                        .position(x: CGFloat(t.x) * size.width, y: CGFloat(1 - t.y) * size.height)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: size.width, height: size.height)
            .projectionEffect(iso)
            .animation(.easeOut(duration: 0.08), value: touches)
        }
        .opacity(connected ? 1 : 0.45)
        .onChange(of: pulse) { _ in
            withAnimation(.easeOut(duration: 0.1)) { lit = true }
            withAnimation(.easeIn(duration: 0.5).delay(0.2)) { lit = false }
        }
        .accessibilityElement()
        .accessibilityLabel(Text(connected ? "Magic Mouse, \(touches.count) fingers touching" : "No Magic Mouse connected"))
    }

    private func shell(_ fill: Color) -> some View {
        RoundedRectangle(cornerRadius: size.width * 0.48, style: .continuous)
            .fill(fill)
            .frame(width: size.width, height: size.height)
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
