import SwiftUI

/// Signal-black canvas with a faint radar speckle, used behind every non-map screen.
struct SignalBackground: View {
    var body: some View {
        ZStack {
            Theme.canvas
            if let speckle = FringeRenderer.shared.speckle() {
                Image(decorative: speckle, scale: 2)
                    .resizable(resizingMode: .tile)
                    .opacity(0.07)
                    .blendMode(.plusLighter)
            }
            RadialGradient(
                colors: [Theme.accent.opacity(0.07), .clear],
                center: .top,
                startRadius: 10,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }
}

/// Map-style scale bar with a round kilometer length.
struct ScaleBar: View {
    let extentKm: Double
    let width: CGFloat

    var body: some View {
        let target = extentKm / 4
        let length = [0.5, 1, 2, 5, 10, 20, 25, 50, 100, 200].last { $0 <= target } ?? 0.5
        let barWidth = max(20, width * CGFloat(length / extentKm))
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .leading) {
                Rectangle().fill(Theme.text.opacity(0.85)).frame(width: barWidth, height: 1.5)
                HStack(spacing: 0) {
                    Rectangle().frame(width: 1.5, height: 7)
                    Spacer(minLength: 0)
                    Rectangle().frame(width: 1.5, height: 7)
                }
                .foregroundStyle(Theme.text.opacity(0.85))
                .frame(width: barWidth)
            }
            Text("\(Fmt.n(length, length < 1 ? 1 : 0)) km")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Theme.text.opacity(0.85))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Scale bar, \(Fmt.n(length, 1)) kilometers")
    }
}

/// North arrow for top-down interferograms.
struct NorthArrow: View {
    var body: some View {
        VStack(spacing: 2) {
            Text("N").font(.system(size: 10, weight: .semibold, design: .monospaced))
            Image(systemName: "location.north.fill").font(.system(size: 14))
        }
        .foregroundStyle(Theme.text.opacity(0.85))
        .accessibilityHidden(true)
    }
}

/// Round glass icon button used in floating chrome.
struct GlassIconButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 46, height: 46)
                .contentShape(Circle())
        }
        .buttonStyle(PressableStyle())
        .fringeGlass(Circle())
        .accessibilityLabel(label)
    }
}

/// Primary capsule call to action in phosphor green.
struct AccentButton: View {
    let title: String
    var systemImage: String?
    var trailingChevron: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                Spacer(minLength: 0)
                if trailingChevron {
                    Image(systemName: "chevron.right").font(.subheadline.weight(.bold))
                }
            }
            .font(.headline)
            .foregroundStyle(Theme.canvas)
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(
                LinearGradient(colors: [Theme.accent, Color(hex: 0x52E6A8)], startPoint: .leading, endPoint: .trailing),
                in: Capsule()
            )
            .shadow(color: Theme.accent.opacity(0.35), radius: 16, y: 6)
        }
        .buttonStyle(PressableStyle())
    }
}

/// Outlined capsule action used where the primary button would be too loud.
struct OutlineButton: View {
    let title: String
    var systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.subheadline.weight(.bold))
            }
            .font(.headline)
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Theme.accent.opacity(0.08), in: Capsule())
            .overlay(Capsule().stroke(Theme.accent.opacity(0.7), lineWidth: 1.2))
            .shadow(color: Theme.accent.opacity(0.2), radius: 14)
        }
        .buttonStyle(PressableStyle())
    }
}

/// Subtle scale-down press feedback.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Section header with an optional trailing accessory.
struct SectionHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.text)
            Spacer()
            trailing()
        }
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(title: String) {
        self.title = title
        self.trailing = { EmptyView() }
    }
}

/// Live HUD over the interferogram: acquisition day and line-of-sight motion so far.
struct DanceTicker: View {
    let event: DeformationEvent
    let progress: Double
    var isPulsing: Bool = false

    var body: some View {
        let day = event.day(at: progress)
        let stats = event.stats(scale: event.scale(at: progress))
        HStack(spacing: 7) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .foregroundStyle(day == 0 ? Theme.sage.opacity(0.8) : Theme.accent)
                .symbolEffect(.pulse, options: .repeating, isActive: isPulsing && day > 0)
            Group {
                if day == 0 {
                    Text("DAY 0 · REFERENCE PASS")
                } else {
                    Text("DAY \(day) · \(reading(stats))")
                }
            }
            .font(.system(.caption2, design: .monospaced, weight: .semibold))
            .tracking(0.6)
            .monospacedDigit()
            .foregroundStyle(Theme.text.opacity(0.95))
            .contentTransition(.numericText())
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 7)
        .background(Theme.canvas.opacity(0.72), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.1)))
        .animation(.snappy, value: day)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(day: day, stats: stats))
    }

    /// Signed LOS reading: vertical kinds report toward/away, lateral kinds report magnitude.
    private func reading(_ stats: FringeStats) -> String {
        switch event.kind {
        case .uplift, .subsidence:
            let cm = stats.peakVertical * 100
            let sign = cm >= 0 ? "+" : "−"
            return "\(sign)\(Fmt.n(abs(cm), 1)) cm \(cm >= 0 ? "toward satellite" : "away")"
        case .faultSlip, .flank:
            return "\(Fmt.n(stats.losRange * 100, 1)) cm along LOS"
        }
    }

    private func accessibilityText(day: Int, stats: FringeStats) -> String {
        day == 0 ? "Reference pass, day 0" : "Acquisition day \(day), \(reading(stats))"
    }
}

/// Drives a 0→1 animation at display rate.
enum Dance {
    static func run(from start: Double, duration: Double, update: (Double) -> Void) async {
        let clock = ContinuousClock()
        let t0 = clock.now
        let begin = min(max(start, 0), 1)
        while !Task.isCancelled {
            let elapsed = t0.duration(to: clock.now)
            let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
            let linear = min(1, seconds / max(duration * (1 - begin), 0.01))
            let eased = linear < 1 ? 1 - pow(1 - linear, 2.2) : 1
            update(begin + (1 - begin) * eased)
            if linear >= 1 { break }
            try? await Task.sleep(for: .milliseconds(16))
        }
    }
}
