import SwiftUI

/// Design tokens for Fringe. Dark mode only.
nonisolated enum Theme {
    static let canvas = Color(hex: 0x05080A)
    static let surface = Color(hex: 0x0C1418)
    static let surfaceRaised = Color(hex: 0x111C21)
    static let stroke = Color(hex: 0x1C2A24)
    static let text = Color(hex: 0xEDF6F0)
    static let sage = Color(hex: 0x7E9691)
    static let accent = Color(hex: 0x39D98A)
    static let coral = Color(hex: 0xFF6B57)
    static let amber = Color(hex: 0xFFC24D)
    static let lateral = Color(hex: 0x8FC8E0)

    /// Interferometric fringe cycle. Reserved for data rendering only.
    static let fringeStops: [UInt32] = [0xFF4D6D, 0xFFC24D, 0x7CFF6B, 0x4CC9FF, 0xB48CFF]
}

extension Color {
    nonisolated init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

extension View {
    /// Small monospaced uppercase label in the mission-console style.
    func kicker(_ color: Color = Theme.sage) -> some View {
        self
            .font(.system(.caption2, design: .monospaced, weight: .medium))
            .tracking(1.6)
            .foregroundStyle(color)
    }

    /// Opaque elevated card used on detail, lab and guide screens.
    func fringeCard(cornerRadius: CGFloat = 22) -> some View {
        self
            .background(Theme.surface, in: .rect(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Theme.stroke, lineWidth: 1)
            )
    }

    /// Liquid Glass on iOS 26, material fallback before that.
    @ViewBuilder
    func fringeGlass<S: Shape>(_ shape: S) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(Theme.surface.opacity(0.45)), in: shape)
        } else {
            self
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
    }
}

/// Number formatting helpers with typographic minus signs.
nonisolated enum Fmt {
    static func n(_ value: Double, _ digits: Int) -> String {
        String(format: "%.\(digits)f", value).replacingOccurrences(of: "-", with: "−")
    }

    static func cm(_ meters: Double, signed: Bool) -> String {
        let v = meters * 100
        let s = signed ? String(format: "%+.1f cm", v) : String(format: "%.1f cm", abs(v))
        return s.replacingOccurrences(of: "-", with: "−")
    }
}
