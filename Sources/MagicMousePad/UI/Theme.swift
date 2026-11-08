import AppKit
import SwiftUI

/// Calm, data-first visual language (in the spirit of Flighty):
/// plain surfaces and hairlines, one warm accent, colour only for status,
/// small uppercase labels over large tabular numbers. Light and dark.
enum Theme {
    // Surfaces
    static let canvas = dynamic(light: 0xF5F5F3, dark: 0x141416)
    static let surface = dynamic(light: 0xFFFFFF, dark: 0x1F1F22)
    static let well = dynamic(light: 0xF0F0EE, dark: 0x2A2A2E)
    static let hairline = Color(nsColor: .separatorColor)

    // Text
    static let ink = Color(nsColor: .labelColor)
    static let secondary = Color(nsColor: .secondaryLabelColor)
    static let tertiary = Color(nsColor: .tertiaryLabelColor)

    // Accent: warm amber, used for fingers, links and selection only.
    static let accent = dynamic(light: 0xE89A12, dark: 0xF2A93B)
    static let accentText = dynamic(light: 0x9A5F00, dark: 0xF2B65A)

    // Status
    static let good = dynamic(light: 0x1FA855, dark: 0x34C66A)
    static let goodFill = dynamic(light: 0xE3F6E8, dark: 0x163A22)
    static let goodText = dynamic(light: 0x116B2F, dark: 0x7FDB9C)
    static let warn = dynamic(light: 0xE08A00, dark: 0xF2A93B)
    static let warnFill = dynamic(light: 0xFFF4E0, dark: 0x3A2A10)
    static let warnText = dynamic(light: 0x6B4500, dark: 0xF6CC88)
    static let idleFill = dynamic(light: 0xEDEDEB, dark: 0x2A2A2E)

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                           green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        })
    }
}

/// Type scale. SF Pro throughout (the system picks Display at large sizes, Text below);
/// numbers use tabular figures so live values don't jitter; times use SF Mono.
enum Typo {
    static let hero = Font.system(size: 30, weight: .heavy)
    static let title = Font.system(size: 22, weight: .heavy)
    static let stat = Font.system(size: 26, weight: .bold).monospacedDigit()
    static let row = Font.system(size: 13, weight: .medium)
    static let body = Font.system(size: 13)
    static let caption = Font.system(size: 12)
    static let mono = Font.system(size: 12, weight: .medium, design: .monospaced)
    static let label = Font.system(size: 10, weight: .bold)
}

/// Small uppercase section / data label.
struct DataLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased()).font(Typo.label).tracking(0.8).foregroundStyle(Theme.secondary)
    }
}

/// A white rounded group with hairline separators between rows.
struct RowGroup<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DataLabel(title).padding(.leading, 4)
            VStack(spacing: 0) {
                _VariadicView.Tree(Separated()) { content }
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.hairline.opacity(0.6), lineWidth: 0.5))
        }
    }

    /// Inserts a hairline between children.
    private struct Separated: _VariadicView_MultiViewRoot {
        func body(children: _VariadicView.Children) -> some View {
            ForEach(Array(children.enumerated()), id: \.offset) { index, child in
                if index > 0 { Rectangle().fill(Theme.hairline.opacity(0.6)).frame(height: 0.5).padding(.leading, 54) }
                child
            }
        }
    }
}

/// Status chip ("ACTIVE", "PAUSED", …).
struct StatusBadge: View {
    let text: String
    let dot: Color
    let fill: Color
    let ink: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(dot).frame(width: 6, height: 6)
            Text(text.uppercased()).font(.system(size: 11, weight: .bold)).tracking(0.7)
        }
        .foregroundStyle(ink)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(fill, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

/// 28 pt glyph box showing how many fingers and which way.
struct GestureGlyph: View {
    var fingers: Int = 0
    var symbol: String?

    var body: some View {
        HStack(spacing: 2) {
            if fingers > 0 {
                HStack(spacing: 1.5) {
                    ForEach(0..<fingers, id: \.self) { _ in Circle().fill(Theme.accent).frame(width: 4, height: 4) }
                }
            }
            if let symbol {
                Image(systemName: symbol).font(.system(size: fingers > 0 ? 9 : 12, weight: .semibold))
                    .foregroundStyle(Theme.ink.opacity(0.75))
            }
        }
        .frame(width: 28, height: 28)
        .background(Theme.well, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .accessibilityHidden(true)
    }
}
