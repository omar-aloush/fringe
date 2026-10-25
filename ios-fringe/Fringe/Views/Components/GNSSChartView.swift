import SwiftUI

/// Three-component measured motion chart (east / north / up) with a drag readout.
/// Plots real bundled GNSS data — no model, no simulation.
struct GNSSChartView: View {
    let series: GNSSSeries

    @State private var dragDay: Double?

    private let components: [(name: String, index: Int, color: Color)] = [
        ("East", 1, Theme.lateral),
        ("North", 2, Theme.sage),
        ("Up", 3, Theme.amber)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(series.station)
                        .font(.system(.headline, design: .monospaced, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text(series.name)
                        .font(.caption)
                        .foregroundStyle(Theme.sage)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(totalText)
                        .font(.system(.headline, design: .monospaced))
                        .foregroundStyle(Theme.accent)
                    Text("3-D motion since \(year)")
                        .font(.caption2)
                        .foregroundStyle(Theme.sage)
                }
            }

            Canvas { context, size in
                let range = yRange
                let x = { (day: Double) in
                    CGFloat(day / max(series.spanDays, 1)) * size.width
                }
                let y = { (mm: Double) in
                    let norm = (mm - range.lowerBound) / (range.upperBound - range.lowerBound)
                    return (1 - norm) * (size.height - 8) + 4
                }

                // Zero baseline
                var baseline = Path()
                baseline.move(to: CGPoint(x: 0, y: y(0)))
                baseline.addLine(to: CGPoint(x: size.width, y: y(0)))
                context.stroke(
                    baseline,
                    with: .color(.white.opacity(0.25)),
                    style: StrokeStyle(lineWidth: 1, dash: [3, 4])
                )

                for component in components {
                    var path = Path()
                    var first = true
                    for sample in series.samples where sample.count >= 4 {
                        let point = CGPoint(x: x(sample[0]), y: y(sample[component.index]))
                        if first { path.move(to: point); first = false }
                        else { path.addLine(to: point) }
                    }
                    context.stroke(path, with: .color(component.color), style: StrokeStyle(lineWidth: 1.8, lineJoin: .round))
                }

                if let day = dragDay {
                    let px = x(day)
                    var crosshair = Path()
                    crosshair.move(to: CGPoint(x: px, y: 0))
                    crosshair.addLine(to: CGPoint(x: px, y: size.height))
                    context.stroke(crosshair, with: .color(.white.opacity(0.45)), lineWidth: 1)
                }
            }
            .frame(height: 168)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        dragDay = min(max(0, value.location.widthRatio * series.spanDays), series.spanDays)
                    }
                    .onEnded { _ in dragDay = nil }
            )
            .overlay(alignment: .topLeading) { readout.padding(6) }
            .clipShape(.rect(cornerRadius: 12, style: .continuous))
            .background(Theme.canvas.opacity(0.55), in: .rect(cornerRadius: 12, style: .continuous))

            HStack(spacing: 14) {
                ForEach(components, id: \.name) { component in
                    HStack(spacing: 5) {
                        Circle().fill(component.color).frame(width: 7, height: 7)
                        Text(component.name)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(Theme.sage)
                    }
                }
                Spacer()
                Text("\(Int(series.spanDays / 365.25)) yr of daily fixes")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Theme.sage)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Measured GNSS motion at \(series.station): \(totalText) over \(Int(series.spanDays / 365.25)) years")
    }

    private var year: String { String(series.t0.prefix(4)) }

    private var totalText: String {
        guard let total = series.total3DCm else { return "—" }
        return total >= 100 ? "\(Fmt.n(total / 100, 2)) m" : "\(Fmt.n(total, 1)) cm"
    }

    private var yRange: ClosedRange<Double> {
        let values = series.samples.flatMap { $0.dropFirst() }
        guard let lo = values.min(), let hi = values.max() else { return -10...10 }
        let pad = max((hi - lo) * 0.12, 5)
        return (lo - pad)...(hi + pad)
    }

    @ViewBuilder
    private var readout: some View {
        if let day = dragDay,
           let sample = series.samples.min(by: { abs($0[0] - day) < abs($1[0] - day) }),
           sample.count >= 4 {
            let d = Int(sample[0])
            VStack(alignment: .leading, spacing: 3) {
                Text("Day \(d) · \(yearOffset(d))")
                    .font(.system(.caption2, design: .monospaced, weight: .semibold))
                    .foregroundStyle(Theme.text)
                ForEach(components, id: \.name) { c in
                    HStack(spacing: 4) {
                        Circle().fill(c.color).frame(width: 5, height: 5)
                        Text("\(c.name) \(signed(sample[c.index])) mm")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(Theme.text.opacity(0.85))
                    }
                }
            }
            .padding(7)
            .background(.black.opacity(0.65), in: .rect(cornerRadius: 8))
            .allowsHitTesting(false)
        }
    }

    private func yearOffset(_ days: Int) -> String {
        let d0 = ISO8601DateFormatter().date(from: series.t0 + "T00:00:00Z") ?? Date()
        return Calendar(identifier: .gregorian)
            .date(byAdding: .day, value: days, to: d0)?
            .formatted(.dateTime.year()) ?? ""
    }

    private func signed(_ v: Double) -> String {
        String(format: "%+.0f", v).replacingOccurrences(of: "-", with: "−")
    }
}

private extension CGPoint {
    var widthRatio: CGFloat { x }
}
