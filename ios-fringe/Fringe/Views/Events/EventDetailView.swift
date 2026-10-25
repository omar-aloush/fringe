import SwiftUI

/// One deformation event in full: interferogram hero, metrics, acquisition timeline and sources.
struct EventDetailView: View {
    let event: DeformationEvent

    @Environment(AppModel.self) private var app
    @State private var progress: Double = 1
    @State private var playTask: Task<Void, Never>?
    @State private var isPlaying = false
    @State private var showExplain = false
    @State private var showEvidence = false
    @State private var showIntegrity = false
    @State private var showAsk = false

    var body: some View {
        let scale = event.scale(at: progress)
        let stats = event.stats(scale: scale)
        let full = event.stats(scale: 1)

        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 22) {
                    hero(scale: scale)

                    VStack(spacing: 22) {
                        if let record = EvidenceRecord.load(eventId: event.id),
                           record.climateLink == "substantive" || record.climateLink == "condensed" {
                            climateBanner(record: record)
                        }

                        metrics(stats: stats, full: full)

                        chips

                        ClimateDossierSection(record: EvidenceRecord.load(eventId: event.id))
                            .id("dossier")

                        gnss
                            .id("gnss")

                        caption(full: full)
                        story
                        MissionClockCard(event: event)
                        timeline
                        LiveStationCard()
                        sources
                        OutlineButton(title: "Show on the radar map", systemImage: "map") {
                            app.showOnMap(event)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .onChange(of: app.detailScrollTarget) { _, target in
                if let target {
                    withAnimation(.easeInOut(duration: 1.0)) {
                        proxy.scrollTo(target, anchor: .top)
                    }
                }
            }
        }
        .background(SignalBackground())
        .navigationTitle(event.name + " " + event.episode.split(separator: " ").first.map(String.init).orEmpty)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbarBackground(Theme.canvas.opacity(0.7), for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: event.shareText(band: app.band)) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share this event")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Radar band", selection: Binding(get: { app.band }, set: { app.band = $0 })) {
                        ForEach(SARBand.allCases) { band in
                            Text(band.label).tag(band)
                        }
                    }
                    Button("Replay the pass pair", systemImage: "play.fill") { replay() }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("More options")
            }
        }
        .sheet(isPresented: sheetBinding(for: .explain, state: $showExplain)) {
            ExplainSheet(context: ExplainContext(event: event, band: app.band))
        }
        .sheet(isPresented: sheetBinding(for: .evidence, state: $showEvidence)) {
            EvidenceSheet(event: event, onOpenIntegrity: {
                showEvidence = false
                app.activeDetailSheet = .integrity
                showIntegrity = true
            })
        }
        .sheet(isPresented: sheetBinding(for: .integrity, state: $showIntegrity)) {
            IntegritySheet(event: event)
        }
        .sheet(isPresented: sheetBinding(for: .ask, state: $showAsk)) {
            AskEventSheet(event: event)
        }
        .onDisappear {
            playTask?.cancel()
            isPlaying = false
            app.liveStation.disconnect()
        }
    }

    private func sheetBinding(for target: DetailSheet, state: Binding<Bool>) -> Binding<Bool> {
        Binding(
            get: { state.wrappedValue || app.activeDetailSheet == target },
            set: { isPresented in
                if !isPresented {
                    state.wrappedValue = false
                    if app.activeDetailSheet == target {
                        app.activeDetailSheet = nil
                    }
                }
            }
        )
    }

    // MARK: - Hero

    private func hero(scale: Double) -> some View {
        GeometryReader { geo in
            ZStack {
                FringeSequenceView(
                    key: event.sequenceKey(band: app.band, style: .scene, resolution: 260),
                    scale: scale,
                    makeRequest: { [event, band = app.band] s in event.sceneRequest(band: band, scale: s, resolution: 260) }
                )
                .frame(width: geo.size.width, height: geo.size.width)
                .clipped()

                LinearGradient(
                    colors: [Theme.canvas.opacity(0.75), .clear, .clear, Theme.canvas.opacity(0.85)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)

                VStack(alignment: .leading) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.title)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(Theme.text)
                            Text(event.episode)
                                .font(.subheadline)
                                .foregroundStyle(Theme.sage)
                        }
                        Spacer()
                        ExplainChip { showExplain = true }
                    }
                    Spacer()
                    DanceTicker(event: event, progress: progress, isPulsing: isPlaying)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 10)
                    HStack(alignment: .bottom) {
                        ScaleBar(extentKm: event.extentKm, width: geo.size.width)
                        Spacer()
                        Text(event.geometry.label)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(Theme.text.opacity(0.8))
                        NorthArrow().padding(.leading, 10)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Interferogram of \(event.title), \(event.episode)")
    }

    // MARK: - Climate Banner

    private func climateBanner(record: EvidenceRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "leaf.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.climateLink == "substantive" ? "CLIMATE CRISIS FLAGSHIP" : "CLIMATE IMPACT CASE")
                        .font(.system(.caption, design: .monospaced, weight: .bold))
                        .foregroundStyle(Theme.accent)
                    Text(event.id == "central-valley" ? "Severe Megadrought → Aquifer Clay Compaction & Loss" :
                         event.id == "norfolk" ? "Relative Sea-Level Rise Compounded by Coastal Sinking" :
                         event.id == "jakarta" ? "Excessive Groundwater Pumping & Coastal Surge Inundation" :
                         "Groundwater Overdraft & Ancient Lakebed Consolidation")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.text)
                }
                Spacer()
            }
            Text(event.id == "central-valley" ? "Permanent loss of California aquifer storage capacity during historic 2012–2016 drought. Tracked via NISAR InSAR & P307 GNSS." :
                 event.id == "norfolk" ? "Land sinking (−4.4 mm/yr) stacks on sea-level rise (+4.84 mm/yr), creating >9.2 mm/yr relative flood threat." :
                 event.id == "jakarta" ? "Parts of North Jakarta sinking up to 15 cm/yr under climate storm surges, prompting capital relocation to Nusantara." :
                 "Decades of agricultural and municipal drawdown draining compressible volcanic lacustrine clays.")
                .font(.caption)
                .foregroundStyle(Theme.sage)
                .lineSpacing(2)
        }
        .padding(14)
        .background(Theme.accent.opacity(0.12), in: .rect(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.accent.opacity(0.35), lineWidth: 1))
    }

    // MARK: - Metrics

    private func metrics(stats: FringeStats, full: FringeStats) -> some View {
        let fringes = stats.fringes(wavelengthCm: app.band.wavelengthCm)
        return VStack(spacing: 0) {
            MetricRow(symbol: event.kind.symbol, tint: event.kind.color, label: "Displacement") {
                Text(event.motionText(scale: event.scale(at: progress)))
                    .foregroundStyle(Theme.accent)
                    .contentTransition(.numericText())
            }
            Divider().overlay(Theme.stroke)
            MetricRow(symbol: "waveform.path.ecg", tint: Theme.text, label: "Rate") {
                Text(event.rateText)
            }
            Divider().overlay(Theme.stroke)
            MetricRow(symbol: "calendar", tint: Theme.text, label: "Pass pair") {
                Text("day 0 → \(event.day(at: progress))")
            }
            Divider().overlay(Theme.stroke)
            MetricRow(symbol: "circle.circle", tint: Theme.text, label: "Fringes") {
                Text("\(Fmt.n(fringes, 1)) × \(Fmt.n(app.band.fringeCm, 1)) cm")
            }
            Divider().overlay(Theme.stroke)
            MetricRow(symbol: "antenna.radiowaves.left.and.right", tint: Theme.text, label: "Sensor") {
                Text(app.band.label)
            }
        }
        .padding(.horizontal, 16)
        .fringeCard()
    }

    // MARK: - Timeline

    private var timeline: some View {
        let days = event.timelineDays
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Acquisition timeline")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.sage)
                Spacer()
                Text("12-day repeat")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Theme.sage)
            }
            GeometryReader { geo in
                let w = geo.size.width - 24
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1)).frame(height: 2).padding(.horizontal, 12)
                    Capsule().fill(Theme.accent).frame(width: w * CGFloat(progress), height: 2).offset(x: 12)
                    ForEach(days, id: \.self) { day in
                        let f = Double(day) / Double(event.windowDays)
                        let reached = f <= progress + 0.001
                        let isLast = day == days.last
                        Button {
                            animate(to: f)
                        } label: {
                            Circle()
                                .fill(reached ? Theme.accent : Theme.surfaceRaised)
                                .overlay(Circle().stroke(reached ? Theme.accent : Theme.sage.opacity(0.6), lineWidth: 1.5))
                                .frame(width: isLast ? 16 : 12, height: isLast ? 16 : 12)
                                .shadow(color: reached ? Theme.accent.opacity(0.7) : .clear, radius: 6)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .offset(x: 12 + w * CGFloat(f) - 22)
                        .accessibilityLabel("Acquisition day \(day)")
                    }
                }
            }
            .frame(height: 44)
            HStack {
                ForEach(days, id: \.self) { day in
                    Text("d\(day)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Theme.sage)
                    if day != days.last { Spacer() }
                }
            }
            if let quake = event.coseismicDay {
                Text("Earthquake strikes on day \(quake). Fringes appear all at once.")
                    .font(.caption)
                    .foregroundStyle(Theme.amber)
            }
        }
    }

    // MARK: - Evidence & ask chips

    private var chips: some View {
        HStack(spacing: 10) {
            EvidenceChip { showEvidence = true }
            AskChip { showAsk = true }
            Spacer()
        }
    }

    // MARK: - Caption

    private func caption(full: FringeStats) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "square.3.layers.3d")
                    .font(.title3)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 50, height: 50)
                    .background(Theme.accent.opacity(0.1), in: Circle())
                    .overlay(Circle().stroke(Theme.accent.opacity(0.25)))
                VStack(alignment: .leading, spacing: 4) {
                    Text("One fringe = \(Fmt.n(app.band.fringeCm, 1)) cm of motion")
                        .font(.headline)
                        .foregroundStyle(Theme.text)
                    Text(event.headline)
                        .font(.subheadline)
                        .foregroundStyle(Theme.sage)
                }
            }
            AccentButton(title: "Open in Lab") {
                app.openInLab(event)
            }
        }
        .padding(16)
        .fringeCard()
    }

    private var story: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WHAT'S HAPPENING").kicker()
            Text(event.story)
                .font(.body)
                .foregroundStyle(Theme.text.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
            Text("Rendered model: \(event.model.summary)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Theme.sage)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Measured ground truth

    /// Real bundled GNSS time series (Nevada Geodetic Lab IGS20 daily solutions).
    @ViewBuilder
    private var gnss: some View {
        let series = GNSSSeries.load(eventId: event.id)
        if !series.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("MEASURED ON THE GROUND").kicker()
                    Spacer()
                    HStack(spacing: 4) {
                        Circle().fill(Theme.accent).frame(width: 6, height: 6)
                        Text("REAL DATA")
                            .kicker(Theme.accent)
                    }
                }
                ForEach(series) { GNSSChartView(series: $0) }
                Text("Daily GNSS fixes measured by physical receivers on the ground — the same ground truth InSAR is validated against. Drag the chart to read any day. Data: \(series[0].source).")
                    .font(.caption)
                    .foregroundStyle(Theme.sage)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fringeCard()
        }
    }

    private var sources: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PUBLISHED MEASUREMENTS").kicker()
            ForEach(event.facts) { fact in
                HStack(alignment: .top, spacing: 12) {
                    Text(fact.value)
                        .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 112, alignment: .leading)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(fact.label)
                            .font(.subheadline)
                            .foregroundStyle(Theme.text)
                        Text(fact.source)
                            .font(.caption)
                            .foregroundStyle(Theme.sage)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fringeCard()
    }

    // MARK: - Actions

    private func replay() {
        playTask?.cancel()
        progress = 0
        isPlaying = true
        playTask = Task {
            await Dance.run(from: 0, duration: 3) { value in progress = value }
            isPlaying = false
        }
    }

    private func animate(to target: Double) {
        playTask?.cancel()
        let start = progress
        playTask = Task {
            await Dance.run(from: 0, duration: 0.6) { t in
                progress = start + (target - start) * t
            }
        }
    }
}

struct MetricRow<Value: View>: View {
    let symbol: String
    let tint: Color
    let label: String
    @ViewBuilder var value: () -> Value

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.body)
                .foregroundStyle(tint)
                .frame(width: 26)
            Text(label)
                .font(.body)
                .foregroundStyle(Theme.text)
            Spacer()
            value()
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(minHeight: 52)
        .accessibilityElement(children: .combine)
    }
}

private extension Optional where Wrapped == String {
    var orEmpty: String { self ?? "" }
}
