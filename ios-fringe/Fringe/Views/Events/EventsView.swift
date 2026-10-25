import SwiftUI

/// Feed of curated, sourced deformation case studies.
struct EventsView: View {
    @Environment(AppModel.self) private var app
    @State private var category: EventCategory = .climate

    private var events: [DeformationEvent] {
        switch category {
        case .all:
            return EventCatalog.all
        case .climate:
            return EventCatalog.all.filter { event in
                let link = EvidenceRecord.load(eventId: event.id)?.climateLink
                return link == "substantive" || link == "condensed"
            }
        case .cities, .volcanoes, .faults:
            return EventCatalog.all.filter { $0.kind.category == category }
        }
    }

    var body: some View {
        @Bindable var app = app
        NavigationStack(path: $app.eventsPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("VERIFIABLE CLIMATE & CRUSTAL MOTION")
                            .kicker(Theme.accent.opacity(0.85))
                        Text("Every number comes from a published measurement. Climate cases track drought aquifer collapse and coastal subsidence compounding sea-level rise.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.sage)
                    }
                    .padding(.horizontal, 20)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(EventCategory.allCases) { item in
                                CategoryChip(title: item.title, isSelected: item == category) {
                                    withAnimation(.snappy) { category = item }
                                }
                            }
                        }
                    }
                    .contentMargins(.horizontal, 20, for: .scrollContent)

                    LazyVStack(spacing: 14) {
                        ForEach(events) { event in
                            NavigationLink(value: event) {
                                EventRow(event: event, band: app.band)
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                    .padding(.horizontal, 16)

                    CreditsFooter()
                        .padding(.horizontal, 20)
                        .padding(.top, 6)
                }
                .padding(.bottom, 24)
            }
            .background(SignalBackground())
            .navigationTitle("Events")
            .toolbarBackground(Theme.canvas.opacity(0.6), for: .navigationBar)
            .navigationDestination(for: DeformationEvent.self) { event in
                EventDetailView(event: event)
            }
        }
    }
}

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? Theme.canvas : Theme.text)
                .padding(.horizontal, 16)
                .frame(minHeight: 38)
                .background(isSelected ? Theme.accent : Theme.surface, in: Capsule())
                .overlay(Capsule().stroke(isSelected ? .clear : Theme.stroke, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct EventRow: View {
    let event: DeformationEvent
    let band: SARBand

    var body: some View {
        HStack(spacing: 14) {
            FringeImageView(request: event.sceneRequest(band: band, scale: 1, resolution: 140))
                .frame(width: 84, height: 84)
                .clipShape(.rect(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Image(systemName: event.kind.symbol)
                        .foregroundStyle(event.kind.color)
                    Text(event.kind.label.uppercased())
                        .kicker(event.kind.color)

                    if let record = EvidenceRecord.load(eventId: event.id),
                       record.climateLink == "substantive" || record.climateLink == "condensed" {
                        Text("·")
                            .kicker(Theme.sage.opacity(0.6))
                        HStack(spacing: 3) {
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 9))
                            Text(record.climateLink == "substantive" ? "CLIMATE FLAGSHIP" : "CLIMATE CASE")
                                .kicker(Theme.accent)
                        }
                    }
                }
                .font(.caption)
                Text(event.title)
                    .font(.headline)
                    .foregroundStyle(Theme.text)
                Text(event.headline)
                    .font(.footnote)
                    .foregroundStyle(Theme.sage)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(event.facts.first.map { "\($0.value) · \($0.source)" } ?? "")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Theme.text.opacity(0.75))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.sage)
        }
        .padding(12)
        .fringeCard()
        .accessibilityElement(children: .combine)
    }
}

/// Dataset credits required for the submission.
struct CreditsFooter: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DATA & METHOD").kicker()
            Text("Interferograms are synthesized on-device from elastic half-space models (Mogi 1958; Savage & Burford 1973) using NISAR's L-band wavelength (23.8 cm) and radar look geometry, then tuned to the published figures cited on each event. Ground truth: daily GNSS position time series from the Nevada Geodetic Lab (University of Nevada, Reno) are bundled in the app and charted on each event. Reference data: NASA/ISRO NISAR via ASF DAAC, NASA JPL, USGS, Icelandic Met Office, INGV, and the peer-reviewed literature credited on each card.")
                .font(.caption)
                .foregroundStyle(Theme.sage)
        }
    }
}
