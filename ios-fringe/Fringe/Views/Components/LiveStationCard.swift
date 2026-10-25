import SwiftUI

/// Live Ground Station card: real motion from the ESP32 station, shown next to
/// the modeled charts. Every state is honest — nothing is displayed until a
/// station actually answers, and a lost connection says so.
struct LiveStationCard: View {
    @Environment(AppModel.self) private var app
    @State private var showConnect = false

    var body: some View {
        card
            .sheet(isPresented: $showConnect) {
                ConnectSheet()
            }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            switch app.liveStation.phase {
            case .idle: idleBody
            case .searching: searchingBody
            case .connected(let hasSensor): connectedBody(hasSensor: hasSensor)
            case .failed(let message): failedBody(message)
            case .lost: lostBody
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fringeGlass(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .animation(.snappy, value: app.liveStation.phase)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Text("LIVE GROUND STATION")
                .kicker(Theme.accent)
            Spacer()
            statusPill
            Button {
                showConnect = true
            } label: {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 38, height: 38)
                    .contentShape(Circle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Live ground station connection settings")
        }
    }

    private var statusPill: some View {
        Text(statusText)
            .font(.system(.caption2, design: .monospaced, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(statusColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(statusColor.opacity(0.14), in: Capsule())
    }

    private var statusText: String {
        switch app.liveStation.phase {
        case .idle: "OFFLINE"
        case .searching: "SEARCHING"
        case .connected(true): "LIVE"
        case .connected(false): "HEARTBEAT"
        case .failed: "NO ANSWER"
        case .lost: "RECONNECTING"
        }
    }

    private var statusColor: Color {
        switch app.liveStation.phase {
        case .idle: Theme.sage
        case .searching, .lost: Theme.amber
        case .connected(true): Theme.accent
        case .connected(false): Theme.amber
        case .failed: Theme.sage
        }
    }

    // MARK: - States

    private var idleBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No station connected.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.text)
            Text("An ESP32 and a $3 motion sensor stream your desk's real ground motion here — orbit from above, sensor on the ground. Optional: the modeled data stands on its own.")
                .font(.caption)
                .foregroundStyle(Theme.sage)
            connectButton("Connect a station")
        }
    }

    private var searchingBody: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(Theme.accent)
            Text("Looking for \(app.liveStation.stationHost ?? LiveStationService.defaultHost) …")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Theme.sage)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }

    @ViewBuilder
    private func connectedBody(hasSensor: Bool) -> some View {
        if hasSensor, let latest = app.liveStation.latest {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    TiltGauge(axis: "X", degrees: latest.tiltX ?? 0)
                    TiltGauge(axis: "Y", degrees: latest.tiltY ?? 0)
                }
                LiveTiltSparkline(samples: app.liveStation.samples)
                HStack(spacing: 14) {
                    Text("LIVE SENSOR · 2 HZ")
                        .kicker(Theme.accent)
                    Spacer()
                    if let temp = latest.temperature {
                        Text("\(Fmt.n(temp, 1))°C")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(Theme.sage)
                    }
                    Text("up \(uptimeText(latest.uptime))")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Theme.sage)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilitySummary(latest))
        } else {
            heartbeatBody
        }
    }

    private var heartbeatBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Station online — sensor not detected.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.text)
            Text("The live link works, but no MPU-6050 is answering on the wire. Attach the GY-521 (Hardware/WIRING.md) and tilt readouts appear here.")
                .font(.caption)
                .foregroundStyle(Theme.sage)
            if let latest = app.liveStation.latest {
                Text("alive for \(uptimeText(latest.uptime))")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Theme.sage)
            }
        }
    }

    private func failedBody(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(message)
                .font(.caption)
                .foregroundStyle(Theme.sage)
            HStack(spacing: 10) {
                smallButton("Retry") { reconnect() }
                smallButton("Change address") { showConnect = true }
            }
        }
    }

    private var lostBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Signal lost — the station stopped answering. Still trying…")
                .font(.caption)
                .foregroundStyle(Theme.amber)
            if app.liveStation.samples.count > 1 {
                LiveTiltSparkline(samples: app.liveStation.samples, dimmed: true)
            }
        }
    }

    // MARK: - Helpers

    private func connectButton(_ title: String) -> some View {
        Button {
            showConnect = true
        } label: {
            Text(title)
                .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Theme.accent.opacity(0.1), in: Capsule())
                .overlay(Capsule().stroke(Theme.accent.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }

    private func smallButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(.caption, design: .monospaced, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 14)
                .frame(minHeight: 38)
                .background(Theme.accent.opacity(0.1), in: Capsule())
                .overlay(Capsule().stroke(Theme.accent.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }

    private func reconnect() {
        app.liveStation.connect(to: app.liveStation.stationHost ?? app.liveStation.lastHost)
    }

    private func uptimeText(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        let h = s / 3_600
        let m = s % 3_600 / 60
        return h > 0 ? "\(h)h \(m)m" : "\(max(1, m))m"
    }

    private func accessibilitySummary(_ sample: LiveSample) -> String {
        guard let x = sample.tiltX, let y = sample.tiltY else {
            return "Live ground station connected, waiting for motion sensor"
        }
        return "Live sensor: tilt \(Fmt.n(x, 1)) degrees across, \(Fmt.n(y, 1)) degrees deep, \(Fmt.n(sample.temperature ?? 0, 1)) degrees Celsius"
    }
}

/// One-axis tilt bar, filling left/right from a center zero mark. Range ±45°.
private struct TiltGauge: View {
    let axis: String
    let degrees: Double

    private let range = 45.0

    var body: some View {
        let fraction = max(-1, min(1, degrees / range))
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(axis)
                    .font(.system(.caption2, design: .monospaced, weight: .bold))
                    .foregroundStyle(Theme.sage)
                Text(signed(degrees) + "°")
                    .font(.system(.caption2, design: .monospaced, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.text)
                    .contentTransition(.numericText())
            }
            GeometryReader { geo in
                let w = geo.size.width
                let fillWidth = max(3, abs(fraction) * (w / 2))
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08)).frame(height: 6)
                    Rectangle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 1.5, height: 12)
                        .offset(x: w / 2 - 0.75)
                    Capsule()
                        .fill(Theme.accent)
                        .frame(width: fillWidth, height: 6)
                        .offset(x: fraction >= 0 ? w / 2 : w / 2 - fillWidth)
                }
            }
            .frame(height: 12)
        }
        .animation(.snappy, value: fraction)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tilt \(axis), \(signed(degrees)) degrees")
    }

    private func signed(_ v: Double) -> String {
        String(format: "%+.1f", v).replacingOccurrences(of: "-", with: "−")
    }
}

/// Scrolling magnitude plot of live tilt over the last minute — Canvas, same
/// language as the GNSS chart. Amber + dimmed when the signal is lost.
private struct LiveTiltSparkline: View {
    let samples: [LiveSample]
    var dimmed = false

    private let windowSeconds: Double = 60

    var body: some View {
        Canvas { context, size in
            let recent = windowed
            guard recent.count > 1, let first = recent.first, let last = recent.last else { return }

            let t0 = first.at.timeIntervalSince1970
            let span = max(last.at.timeIntervalSince1970 - t0, 1)
            let peak = max(recent.compactMap(\.tiltMagnitude).max() ?? 1, 0.3)

            let x: (Double) -> CGFloat = { t in CGFloat((t - t0) / span) * size.width }
            let y: (Double) -> CGFloat = { v in
                let norm = min(v / (peak * 1.15), 1)
                return (1 - norm) * (size.height - 6) + 3
            }

            var baseline = Path()
            baseline.move(to: CGPoint(x: 0, y: size.height - 3))
            baseline.addLine(to: CGPoint(x: size.width, y: size.height - 3))
            context.stroke(baseline, with: .color(.white.opacity(0.18)),
                           style: StrokeStyle(lineWidth: 1, dash: [3, 4]))

            var line = Path()
            var fill = Path()
            var started = false
            for sample in recent {
                guard let v = sample.tiltMagnitude else { continue }
                let point = CGPoint(x: x(sample.at.timeIntervalSince1970), y: y(v))
                if started {
                    line.addLine(to: point)
                } else {
                    line.move(to: point)
                    fill.move(to: CGPoint(x: point.x, y: size.height - 3))
                    started = true
                }
                fill.addLine(to: point)
            }
            guard started else { return }
            fill.addLine(to: CGPoint(x: x(last.at.timeIntervalSince1970), y: size.height - 3))
            fill.closeSubpath()
            context.fill(fill, with: .linearGradient(
                Gradient(colors: [Theme.accent.opacity(dimmed ? 0.1 : 0.26), .clear]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: size.height)
            ))
            context.stroke(line, with: .color(dimmed ? Theme.amber : Theme.accent),
                           style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))
        }
        .frame(height: 76)
        .clipShape(.rect(cornerRadius: 12, style: .continuous))
        .background(Theme.canvas.opacity(0.55), in: .rect(cornerRadius: 12, style: .continuous))
        .accessibilityLabel("Live tilt over the last minute, peak \(peakText) degrees")
    }

    private var windowed: [LiveSample] {
        guard let last = samples.last else { return [] }
        let cutoff = last.at.addingTimeInterval(-windowSeconds)
        return samples.filter { $0.at >= cutoff }
    }

    private var peakText: String {
        Fmt.n(windowed.compactMap(\.tiltMagnitude).max() ?? 0, 2)
    }
}

/// Sheet for finding/addressing the ground station: auto-find via mDNS,
/// manual IP entry, and a live status footer.
private struct ConnectSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var hostText = ""
    @FocusState private var hostFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("LIVE GROUND STATION")
                    .kicker(Theme.accent)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.sage.opacity(0.7))
                }
                .accessibilityLabel("Close")
            }

            Text("Point Fringe at the little server on your ESP32 — the sketch in Hardware/ prints its address. Phone and board must share the same WiFi.")
                .font(.caption)
                .foregroundStyle(Theme.sage)

            autoFindButton
            manualRow
            statusFooter
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .onAppear { hostText = app.liveStation.stationHost ?? app.liveStation.lastHost }
        .onChange(of: app.liveStation.phase) { _, newPhase in
            if case .connected = newPhase {
                Task {
                    try? await Task.sleep(for: .seconds(0.9))
                    dismiss()
                }
            }
        }
    }

    private var autoFindButton: some View {
        Button {
            app.liveStation.connect(to: LiveStationService.defaultHost)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 16, weight: .semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Auto-find")
                        .font(.system(.subheadline, design: .monospaced, weight: .bold))
                    Text("the station announces itself as \(LiveStationService.defaultHost)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Theme.sage)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold))
            }
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(Theme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.accent.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }

    private var manualRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Or type the IP from Serial Monitor")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Theme.sage)
            HStack(spacing: 10) {
                TextField("192.168.1.42", text: $hostText)
                    .font(.system(.subheadline, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.numbersAndPunctuation)
                    .focused($hostFocused)
                    .submitLabel(.go)
                    .onSubmit(connectManual)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 46)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .foregroundStyle(Theme.text)
                Button(action: connectManual) {
                    Text("Connect")
                        .font(.system(.subheadline, design: .monospaced, weight: .bold))
                        .foregroundStyle(Theme.canvas)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 46)
                        .background(Theme.accent, in: Capsule())
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    @ViewBuilder
    private var statusFooter: some View {
        switch app.liveStation.phase {
        case .searching:
            Label("Polling… give it a few seconds.", systemImage: "clock")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Theme.amber)
        case .connected(let hasSensor):
            Label(
                hasSensor ? "Connected — motion streaming." : "Connected in heartbeat mode (no sensor on the wire).",
                systemImage: hasSensor ? "checkmark.circle.fill" : "waveform.path.ecg"
            )
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(Theme.accent)
        case .failed(let message):
            Text(message)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Theme.text.opacity(0.75))
        case .idle, .lost:
            EmptyView()
        }
        if app.liveStation.stationHost != nil {
            Button(role: .destructive) {
                app.liveStation.disconnect()
            } label: {
                Text("Disconnect")
                    .font(.system(.caption, design: .monospaced, weight: .semibold))
                    .foregroundStyle(Theme.text.opacity(0.85))
                    .frame(maxWidth: .infinity, minHeight: 42)
                    .background(Color.white.opacity(0.06), in: Capsule())
            }
            .buttonStyle(PressableStyle())
        }
    }

    private func connectManual() {
        hostFocused = false
        app.liveStation.connect(to: hostText)
    }
}
