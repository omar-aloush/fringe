import SwiftUI

/// Reading level for the "Explain this" sheet: one picture, three depths of language.
enum AudienceLevel: String, CaseIterable, Identifiable {
    case everyone, student, scientist

    var id: String { rawValue }

    var title: String {
        switch self {
        case .everyone: return "Public"
        case .student: return "Student"
        case .scientist: return "Scientist"
        }
    }

    var symbol: String {
        switch self {
        case .everyone: return "person.fill"
        case .student: return "graduationcap.fill"
        case .scientist: return "scope"
        }
    }
}

/// Everything the explainer says, precomputed from the live model stats so the
/// words can never disagree with the numbers on screen or the cited facts.
struct ExplainContext {
    let subject: String
    let publicText: String
    let studentText: String
    let bandText: String
    let lookText: String
    let losCm: Double
    let fringeCm: Double
    let fringes: Double
    let modelSummary: String
    let windowText: String?
    let rateText: String?

    static let footnote = "Every number is computed on-device by the same physical model that renders this interferogram, tuned to reproduce the published measurements cited in the app. Not a downloaded NISAR product."

    /// Explain a catalogued event at the selected radar band.
    init(event: DeformationEvent, band: SARBand) {
        let stats = event.stats(scale: 1)
        let fringeCm = band.fringeCm
        self.subject = "\(event.title) — \(event.episode)"
        self.bandText = "\(band.label) · λ = \(Fmt.n(band.wavelengthCm, 1)) cm"
        self.lookText = "\(event.geometry.isAscending ? "Ascending" : "Descending") pass · incidence \(Fmt.n(event.geometry.incidenceDeg, 0))° · look azimuth \(Fmt.n(event.geometry.groundToSatelliteAzimuthDeg, 0))°"
        self.losCm = stats.losRange * 100
        self.fringeCm = fringeCm
        self.fringes = stats.fringes(wavelengthCm: band.wavelengthCm)
        self.modelSummary = event.model.summary
        self.windowText = "day 0 → \(event.windowDays) · \(event.windowText)"
        self.rateText = event.rateText

        let step = Fmt.n(fringeCm, 1)
        let student = Self.studentText(
            windowDays: event.windowDays,
            fringes: self.fringes,
            losCm: self.losCm,
            fringeCm: fringeCm
        )
        switch event.kind {
        case .uplift:
            let m = DeformationEvent.length(stats.peakVertical, signed: false)
            self.publicText = "The ground here rose by about \(m) toward the satellite in \(event.windowText). Each colored ring is one step of \(step) cm of motion — tightly packed rings mark where the ground moves fastest. NISAR maps this from orbit, day or night, through cloud."
            self.studentText = student
        case .subsidence:
            let m = DeformationEvent.length(stats.peakVertical, signed: false)
            self.publicText = "The ground here sank by about \(m) in \(event.windowText). Each colored ring is one step of \(step) cm of motion — tightly packed rings mark where the sinking is fastest. NISAR maps this from orbit, day or night, through cloud."
            self.studentText = student
        case .faultSlip:
            self.publicText = "The two sides of this fault slid past each other by about \(event.motionText(scale: 1)) in \(event.windowText). The sharp color step across the fault is the slip itself; every ring is \(step) cm of motion as the radar sees it."
            self.studentText = student
        case .flank:
            self.publicText = "The volcano's flank crept seaward by about \(event.motionText(scale: 1)) in \(event.windowText). Each colored ring is one step of \(step) cm of motion; packed rings mean faster creep."
            self.studentText = student
        }
    }

    /// Explain the live Lab experiment.
    init(lab: LabViewModel) {
        let stats = lab.stats
        let fringeCm = lab.wavelengthCm / 2
        let losCm = stats.losRange * 100
        self.subject = lab.loadedFrom.map { "\(lab.mode.title) · loaded from \($0)" } ?? lab.mode.title
        self.bandText = lab.nearestBand.map { "\($0.label) · λ = \(Fmt.n(lab.wavelengthCm, 1)) cm" }
            ?? "Custom wavelength · λ = \(Fmt.n(lab.wavelengthCm, 1)) cm"
        self.lookText = "\(lab.geometry.isAscending ? "Ascending" : "Descending") pass · incidence \(Fmt.n(lab.geometry.incidenceDeg, 0))° · look azimuth \(Fmt.n(lab.geometry.groundToSatelliteAzimuthDeg, 0))°"
        self.losCm = losCm
        self.fringeCm = fringeCm
        self.fringes = lab.fringes
        self.modelSummary = lab.model.summary
        self.windowText = "two passes, 12 days apart"
        self.rateText = nil

        let step = Fmt.n(fringeCm, 1)
        let student = Self.studentText(windowDays: 12, fringes: lab.fringes, losCm: losCm, fringeCm: fringeCm)
        switch lab.mode {
        case .volcano:
            let m = DeformationEvent.length(abs(stats.peakVertical), signed: false)
            self.publicText = "A blob of magma \(Fmt.n(lab.depthKm, 1)) km underground is being inflated, pushing the surface up by about \(m). That bullseye of rings is the lift. Each ring is \(step) cm toward the satellite — shallower or bigger sources pack the rings tighter."
            self.studentText = student
        case .fault:
            self.publicText = "Two sides of a fault are sliding past each other by \(DeformationEvent.length(lab.slipM, signed: false)). The radar sees the slide as a sharp color step along the fault; each ring is \(step) cm of motion along the line of sight."
            self.studentText = student
        case .bowl:
            self.publicText = "The ground here sinks \(DeformationEvent.length(lab.bowlPeakM, signed: false)) at the center, like an aquifer compacting under a city. Each ring is \(step) cm away from the satellite; packed rings mean faster sinking."
            self.studentText = student
        }
    }

    /// The mechanism, in one paragraph — shared by every source type.
    private static func studentText(windowDays: Int, fringes: Double, losCm: Double, fringeCm: Double) -> String {
        "Radar measures distance, not light. NISAR images the same area twice — day 0 and day \(windowDays) — and compares the phase of the wave that bounces back. Ground motion between the two passes changes the wave's travel distance, and that phase shift paints the rings. One full color cycle equals half a wavelength: \(Fmt.n(fringeCm, 1)) cm along the satellite's line of sight. This scene holds about \(Fmt.n(fringes, 1)) rings, so the two passes differ by roughly \(Fmt.n(losCm, 1)) cm of line-of-sight motion."
    }
}

/// Small glass trigger overlaid on interferograms.
struct ExplainChip: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.caption.weight(.bold))
                Text("Explain")
                    .font(.footnote.weight(.semibold))
            }
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 14)
            .frame(minHeight: 40)
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .fringeGlass(Capsule())
        .accessibilityLabel("Explain this visualization")
    }
}

/// The "Explain this" sheet: one visualization, three depths of language.
struct ExplainSheet: View {
    let context: ExplainContext
    @State private var level: AudienceLevel = .everyone
    @Environment(\.dismiss) private var dismiss
    @Namespace private var ns

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("EXPLAIN THIS").kicker(Theme.accent)
                    Text(context.subject)
                        .font(.headline)
                        .foregroundStyle(Theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Theme.sage)
                        .frame(width: 34, height: 34)
                        .background(Theme.surface, in: Circle())
                        .overlay(Circle().stroke(Theme.stroke))
                        .contentShape(Circle())
                }
                .accessibilityLabel("Close")
            }

            AudiencePicker(level: $level, namespace: ns)

            ScrollView {
                ZStack {
                    switch level {
                    case .everyone:
                        bodyText(context.publicText)
                    case .student:
                        bodyText(context.studentText)
                    case .scientist:
                        ScientistReadout(context: context)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: .infinity)
            .id(level)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .animation(.snappy(duration: 0.25), value: level)

            Text(ExplainContext.footnote)
                .font(.caption2)
                .foregroundStyle(Theme.sage.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .presentationDetents([.medium, .large])
        .presentationContentInteraction(.scrolls)
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.canvas)
        .sensoryFeedback(.selection, trigger: level)
    }

    private func bodyText(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(Theme.text.opacity(0.92))
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Three-way capsule switch for the audience level.
private struct AudiencePicker: View {
    @Binding var level: AudienceLevel
    let namespace: Namespace.ID

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AudienceLevel.allCases) { candidate in
                let isSelected = level == candidate
                Button {
                    level = candidate
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: candidate.symbol).font(.caption)
                        Text(candidate.title)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? Theme.text : Theme.sage)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(Theme.accent.opacity(0.18))
                                .overlay(Capsule().stroke(Theme.accent.opacity(0.45), lineWidth: 1))
                                .matchedGeometryEffect(id: "audience", in: namespace)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(5)
        .background(Theme.surface, in: Capsule())
        .overlay(Capsule().stroke(Theme.stroke))
    }
}

/// Key-value technical readout for the Scientist level.
private struct ScientistReadout: View {
    let context: ExplainContext

    var body: some View {
        VStack(spacing: 0) {
            row("BAND", context.bandText)
            Divider().overlay(Theme.stroke)
            row("LOOK", context.lookText)
            Divider().overlay(Theme.stroke)
            row("ΔLOS", "\(Fmt.n(context.losCm, 1)) cm across the scene")
            Divider().overlay(Theme.stroke)
            row("FRINGES", "N = \(Fmt.n(context.losCm, 1)) ÷ \(Fmt.n(context.fringeCm, 2)) = \(Fmt.n(context.fringes, 1)) cycles")
            Divider().overlay(Theme.stroke)
            row("MODEL", context.modelSummary)
            if let windowText = context.windowText {
                Divider().overlay(Theme.stroke)
                row("WINDOW", windowText)
            }
            if let rateText = context.rateText {
                Divider().overlay(Theme.stroke)
                row("RATE", rateText)
            }
        }
        .padding(.horizontal, 16)
        .fringeCard()
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .kicker(Theme.sage)
                .frame(width: 74, alignment: .leading)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
    }
}
