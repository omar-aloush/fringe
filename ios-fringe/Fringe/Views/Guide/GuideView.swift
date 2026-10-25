import SwiftUI

/// A two-minute visual lesson in reading interferograms.
struct GuideView: View {
    @Environment(AppModel.self) private var app
    @State private var expandedStep: Int?

    private let stories: [DeformationEvent] = [EventCatalog.centralValley, EventCatalog.norfolk, EventCatalog.jakarta, EventCatalog.mexicoCity]

    var body: some View {
        @Bindable var app = app
        NavigationStack(path: $app.guidePath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    GuideHero(fringeCm: SARBand.nisarL.fringeCm)

                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Real places. Real motion.") {
                            Button {
                                app.tab = .events
                            } label: {
                                HStack(spacing: 4) {
                                    Text("See All")
                                    Image(systemName: "chevron.right")
                                }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.accent)
                                .frame(minHeight: 44)
                            }
                        }
                        .padding(.horizontal, 20)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(stories) { event in
                                    NavigationLink(value: event) {
                                        StoryCard(event: event)
                                    }
                                    .buttonStyle(PressableStyle())
                                }
                            }
                        }
                        .contentMargins(.horizontal, 20, for: .scrollContent)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "How to read fringes")
                        steps
                    }
                    .padding(.horizontal, 20)

                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Why wavelength matters")
                        BandComparison()
                    }
                    .padding(.horizontal, 20)

                    OutlineButton(title: "Try it in the Lab", systemImage: "flask") {
                        app.tab = .lab
                    }
                    .padding(.horizontal, 20)

                    CreditsFooter()
                        .padding(.horizontal, 20)
                }
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .background(SignalBackground())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: DeformationEvent.self) { event in
                EventDetailView(event: event)
            }
        }
    }

    private var steps: some View {
        let items: [(String, String, String)] = [
            ("Count the rings",
             "Each full color cycle is one fringe: 11.9 cm of motion for NISAR's L-band.",
             "Pick the center of the pattern and count how many times red comes back on your way out to quiet ground. Tightly packed rings mean steep motion. Wide rings mean gentle motion."),
            ("Watch the color order",
             "Red → yellow → green → blue → violet tells you the direction.",
             "If the colors run in one order going inward, the ground moved toward the satellite (usually uplift). If they run in the reverse order, it moved away (usually sinking). Swap the satellite's look direction and a sideways slide can flip sign entirely."),
            ("Multiply by the fringe size",
             "Total motion = number of fringes × λ/2.",
             "Five L-band fringes is about 5 × 11.9 ≈ 60 cm along the radar's line of sight. The same motion seen in C-band would show about 21 fringes, because each of its rings is only 2.8 cm.")
        ]
        return VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                let isOpen = expandedStep == index
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        expandedStep = isOpen ? nil : index
                    }
                } label: {
                    HStack(alignment: .top, spacing: 14) {
                        Text("\(index + 1)")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(isOpen ? Theme.canvas : Theme.text)
                            .frame(width: 38, height: 38)
                            .background(isOpen ? Theme.accent : Theme.surfaceRaised, in: Circle())
                            .overlay(Circle().stroke(Theme.stroke))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.0)
                                .font(.headline)
                                .foregroundStyle(Theme.text)
                            Text(item.1)
                                .font(.subheadline)
                                .foregroundStyle(Theme.sage)
                            if isOpen {
                                Text(item.2)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.text.opacity(0.85))
                                    .padding(.top, 4)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.sage)
                            .rotationEffect(.degrees(isOpen ? 90 : 0))
                            .padding(.top, 10)
                    }
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: isOpen)
                if index < items.count - 1 {
                    Divider().overlay(Theme.stroke)
                }
            }
        }
        .padding(.horizontal, 16)
        .fringeCard()
    }
}

/// Hero with a breathing, physically rendered interferogram.
private struct GuideHero: View {
    let fringeCm: Double

    private static let model = DeformationModel.mogi(depthKm: 5, volumeKm3: 0.03)

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let scale = 0.62 + 0.38 * (0.5 + 0.5 * sin(t * 0.9))
                    FringeSequenceView(
                        key: "guide-hero",
                        scale: scale,
                        makeRequest: { [model = Self.model] s in
                            FringeRequest(
                                model: model,
                                scale: s,
                                extentKm: 34,
                                wavelengthCm: SARBand.nisarL.wavelengthCm,
                                geometry: .ascending,
                                resolution: 260,
                                style: .scene,
                                atmosphereCm: 0.6,
                                seed: 5
                            )
                        }
                    )
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()

                LinearGradient(
                    colors: [Theme.canvas.opacity(0.7), .clear, Theme.canvas.opacity(0.4), Theme.canvas],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Fringe")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundStyle(Theme.text)
                            Text("FIELD GUIDE")
                                .kicker(Theme.accent.opacity(0.85))
                        }
                        Spacer()
                        Text("A SMALL\nSHIFT\nA BRIGHTER\nPLANET")
                            .font(.system(.caption2, design: .monospaced))
                            .tracking(1.4)
                            .foregroundStyle(Theme.text.opacity(0.7))
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                    Text("One ring,\ntwelve centimeters")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(Theme.text)
                    Text("Each color cycle is the ground moving \(Fmt.n(fringeCm, 1)) cm toward or away from the satellite.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.text.opacity(0.75))
                        .padding(.top, 2)
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 4)
            }
        }
        .frame(height: 440)
        .accessibilityElement(children: .combine)
    }
}

private struct StoryCard: View {
    let event: DeformationEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FringeImageView(request: event.sceneRequest(band: .nisarL, scale: 1, resolution: 160))
                .frame(width: 156, height: 104)
                .clipped()
            VStack(alignment: .leading, spacing: 3) {
                Text(event.name)
                    .font(.headline)
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                HStack {
                    Text(event.facts.first?.value ?? "")
                        .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                        .foregroundStyle(event.kind.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 2)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.sage)
                }
            }
            .padding(12)
        }
        .frame(width: 156)
        .clipShape(.rect(cornerRadius: 18, style: .continuous))
        .fringeCard(cornerRadius: 18)
        .accessibilityElement(children: .combine)
    }
}

/// The same Svartsengi episode seen at three radar wavelengths.
private struct BandComparison: View {
    var body: some View {
        let event = EventCatalog.svartsengi
        let stats = event.stats(scale: 1)
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ForEach(SARBand.allCases.reversed()) { band in
                    VStack(alignment: .leading, spacing: 6) {
                        FringeImageView(request: event.sceneRequest(band: band, scale: 1, resolution: 150))
                            .aspectRatio(1, contentMode: .fit)
                            .clipShape(.rect(cornerRadius: 12, style: .continuous))
                        Text(band.letter + "-band")
                            .font(.system(.caption, design: .monospaced, weight: .semibold))
                            .foregroundStyle(Theme.text)
                        Text("\(Fmt.n(stats.fringes(wavelengthCm: band.wavelengthCm), 0)) fringes")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(Theme.sage)
                    }
                }
            }
            Text("Same swelling at Svartsengi, three rulers. Short C-band waves draw many tight rings that blur out over vegetation and fast motion. NISAR's long L-band waves see through crops and forest canopy and keep big motion readable.")
                .font(.footnote)
                .foregroundStyle(Theme.sage)
        }
        .padding(14)
        .fringeCard()
    }
}
