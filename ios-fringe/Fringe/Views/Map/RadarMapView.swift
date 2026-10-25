import SwiftUI
import MapKit

/// Home screen: a dark world map with geo-anchored interferograms and the two-pass scrubber.
struct RadarMapView: View {
    @Environment(AppModel.self) private var app

    @State private var position: MapCameraPosition = .region(EventCatalog.featured.mapRegion())
    @State private var visibleRegion: MKCoordinateRegion = EventCatalog.featured.mapRegion()
    @State private var isPlaying: Bool = false
    @State private var playTask: Task<Void, Never>?
    @State private var didIntro: Bool = false

    var body: some View {
        @Bindable var app = app
        let event = app.selectedEvent

        NavigationStack(path: $app.mapPath) {
            ZStack {
                MapReader { proxy in
                    Map(position: $position, interactionModes: [.pan, .zoom])
                        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
                        .onMapCameraChange(frequency: .continuous) { context in
                            visibleRegion = context.region
                        }
                        .overlay {
                            Theme.canvas.opacity(0.35).allowsHitTesting(false)
                        }
                        .overlay {
                            fringeLayer(proxy: proxy, selected: event)
                        }
                }
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                    GlobalPulseStrip(event: event)
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                    Spacer()
                    bottomControls(event: event)
                }
            }
            .background(Theme.canvas)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: DeformationEvent.self) { event in
                EventDetailView(event: event)
            }
        }
        .onChange(of: app.focusRequest) { _, _ in
            fly(to: app.selectedEvent)
        }
        .onChange(of: app.tab) { _, tab in
            if tab != .map { stop() }
        }
        .task {
            guard !didIntro else { return }
            didIntro = true
            app.progress = 0
            try? await Task.sleep(for: .milliseconds(900))
            play()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Fringe")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Theme.text)
                Text("CLIMATE & CRUSTAL MOTION")
                    .kicker(Theme.accent.opacity(0.85))
            }
            .shadow(color: .black.opacity(0.6), radius: 8)
            Spacer()
            HStack(spacing: 10) {
                bandMenu
                GlassIconButton(systemImage: "location.north.line.fill", label: "Recenter on selected site") {
                    fly(to: app.selectedEvent)
                }
                GlassIconButton(systemImage: "globe.americas.fill", label: "Zoom out to the whole planet") {
                    withAnimation(.smooth(duration: 1.4)) {
                        position = .region(MKCoordinateRegion(
                            center: CLLocationCoordinate2D(latitude: 25, longitude: -40),
                            span: MKCoordinateSpan(latitudeDelta: 120, longitudeDelta: 160)
                        ))
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }

    private var bandMenu: some View {
        @Bindable var app = app
        return Menu {
            Picker("Radar band", selection: $app.band) {
                ForEach(SARBand.allCases) { band in
                    Text("\(band.label) · \(Fmt.n(band.fringeCm, 1)) cm/fringe").tag(band)
                }
            }
        } label: {
            Text(app.band.letter)
                .font(.system(size: 17, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.accent)
                .frame(width: 46, height: 46)
                .contentShape(Circle())
        }
        .fringeGlass(Circle())
        .accessibilityLabel("Radar band, \(app.band.label)")
    }

    // MARK: - Fringe layer

    @ViewBuilder
    private func fringeLayer(proxy: MapProxy, selected: DeformationEvent) -> some View {
        let isWorld = visibleRegion.span.latitudeDelta > 8
        ZStack(alignment: .topLeading) {
            ForEach(EventCatalog.all) { event in
                if let rect = screenRect(for: event, proxy: proxy) {
                    let isSelected = event.id == selected.id
                    let side = max(rect.width, isSelected ? 54 : 40)
                    Group {
                        if isSelected {
                            FringeSequenceView(
                                key: event.sequenceKey(band: app.band, style: .overlay, resolution: 200),
                                scale: event.scale(at: app.progress),
                                makeRequest: { [band = app.band] s in event.overlayRequest(band: band, scale: s, resolution: 200) }
                            )
                        } else {
                            FringeImageView(request: event.overlayRequest(band: app.band, scale: 1, resolution: 96))
                                .opacity(0.85)
                        }
                    }
                    .frame(width: side, height: side)
                    .position(x: rect.midX, y: rect.midY)
                    .allowsHitTesting(false)

                    pin(for: event, isSelected: isSelected, showLabel: isWorld || isSelected)
                        .position(x: rect.midX, y: rect.midY)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func pin(for event: DeformationEvent, isSelected: Bool, showLabel: Bool) -> some View {
        Button {
            select(event)
        } label: {
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.25))
                    .frame(width: isSelected ? 30 : 20, height: isSelected ? 30 : 20)
                    .blur(radius: 3)
                Circle()
                    .fill(Theme.accent)
                    .frame(width: isSelected ? 13 : 10, height: isSelected ? 13 : 10)
                    .overlay(Circle().stroke(Theme.canvas, lineWidth: 2))
                    .shadow(color: Theme.accent, radius: 6)
            }
            .frame(width: 44, height: 44)
            .overlay(alignment: .leading) {
                if showLabel {
                    Text(event.name)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.text)
                        .shadow(color: .black, radius: 4)
                        .fixedSize()
                        .offset(x: 36)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(event.title), \(event.kind.label)")
    }

    private func screenRect(for event: DeformationEvent, proxy: MapProxy) -> CGRect? {
        _ = visibleRegion
        let halfLat = event.extentKm / 2 / 110.574
        let halfLon = event.extentKm / 2 / (111.32 * max(cos(event.latitude * .pi / 180), 0.05))
        let nw = CLLocationCoordinate2D(latitude: event.latitude + halfLat, longitude: event.longitude - halfLon)
        let se = CLLocationCoordinate2D(latitude: event.latitude - halfLat, longitude: event.longitude + halfLon)
        guard let a = proxy.convert(nw, to: .local), let b = proxy.convert(se, to: .local) else { return nil }
        let rect = CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y))
        guard rect.width.isFinite, rect.height.isFinite, rect.width < 20_000 else { return nil }
        return rect
    }

    // MARK: - Bottom controls

    private func bottomControls(event: DeformationEvent) -> some View {
        @Bindable var app = app
        return VStack(spacing: 14) {
            ReadingsPanel(event: event, band: app.band, progress: app.progress) {
                stop()
                app.mapPath.append(event)
            }

            HStack(alignment: .bottom, spacing: 14) {
                PassScrubber(progress: $app.progress, event: event) {
                    stop()
                }
                PlayButton(isPlaying: isPlaying) {
                    isPlaying ? stop() : play()
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    // MARK: - Actions

    private func select(_ event: DeformationEvent) {
        if event.id == app.selectedEventID {
            stop()
            app.mapPath.append(event)
            return
        }
        stop()
        app.selectedEventID = event.id
        app.progress = 0
        fly(to: event)
        playTask = Task {
            try? await Task.sleep(for: .milliseconds(1300))
            if !Task.isCancelled { play() }
        }
    }

    private func fly(to event: DeformationEvent) {
        withAnimation(.smooth(duration: 1.6)) {
            position = .region(event.mapRegion())
        }
    }

    private func play() {
        playTask?.cancel()
        let start = app.progress >= 0.999 ? 0 : app.progress
        isPlaying = true
        playTask = Task {
            await Dance.run(from: start, duration: 3.2) { value in
                app.progress = value
            }
            if !Task.isCancelled { isPlaying = false }
        }
    }

    private func stop() {
        playTask?.cancel()
        playTask = nil
        isPlaying = false
    }
}

/// Floating glass panel with the selected site's live readings.
struct ReadingsPanel: View {
    let event: DeformationEvent
    let band: SARBand
    let progress: Double
    let onOpen: () -> Void

    var body: some View {
        let scale = event.scale(at: progress)
        let stats = event.stats(scale: scale)
        let fringes = stats.fringes(wavelengthCm: band.wavelengthCm)
        let day = event.day(at: progress)

        Button(action: onOpen) {
            HStack(spacing: 16) {
                FringeImageView(request: event.sceneRequest(band: band, scale: 1, resolution: 140))
                    .frame(width: 92, height: 92)
                    .clipShape(.rect(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.1)))

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(event.title)
                            .font(.headline)
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                        if let record = EvidenceRecord.load(eventId: event.id),
                           record.climateLink == "substantive" || record.climateLink == "condensed" {
                            HStack(spacing: 3) {
                                Image(systemName: "leaf.fill")
                                    .font(.system(size: 8))
                                Text("CLIMATE")
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                            }
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.accent.opacity(0.15), in: Capsule())
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.sage)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(event.motionText(scale: scale))
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(event.kind == .faultSlip || event.kind == .flank ? Theme.accent : event.kind.color)
                            .contentTransition(.numericText())
                        Text(event.kind.motionWord)
                            .font(.subheadline)
                            .foregroundStyle(Theme.sage)
                    }
                    Text("day 0 → \(day) · \(event.windowText) pair")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Theme.sage)
                    Text("\(Fmt.n(fringes, 1)) fringes · \(band.label)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Theme.text.opacity(0.8))
                    Divider().overlay(Theme.stroke)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        if let next = MissionClock.nextPass(for: event, after: context.date) {
                            let acquiring = MissionClock.isAcquiring(next, at: context.date)
                            HStack(spacing: 6) {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                    .font(.caption2)
                                    .foregroundStyle(acquiring ? Theme.amber : Theme.accent)
                                Text(acquiring ? "PASSING OVER NOW" : MissionClock.countdown(from: context.date, to: next.date))
                                    .font(.system(.caption, design: .monospaced, weight: .semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(acquiring ? Theme.amber : Theme.accent)
                                Text("until NISAR · \(next.isAscending ? "asc" : "dsc") pass")
                                    .font(.caption)
                                    .foregroundStyle(Theme.sage)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                Spacer(minLength: 0)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Next NISAR pass in \(MissionClock.countdown(from: context.date, to: next.date))")
                        }
                    }
                }
            }
            .padding(14)
            .contentShape(.rect(cornerRadius: 26))
        }
        .buttonStyle(PressableStyle())
        .fringeGlass(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .accessibilityLabel("\(event.title). \(event.motionText(scale: scale)) \(event.kind.motionWord). \(Fmt.n(fringes, 1)) fringes. Opens details.")
    }
}

/// Total bundled GNSS ground stations across the catalog, computed once.
nonisolated enum GroundStationCount {
    static let count: Int = EventCatalog.all.reduce(0) { $0 + GNSSSeries.load(eventId: $1.id).count }
}

/// One-line "planet is alive" strip under the map header: bundled content counts
/// plus a live next-pass countdown from the same mission-clock math as the panel.
struct GlobalPulseStrip: View {
    let event: DeformationEvent

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(spacing: 8) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.accent)
                Text("CLIMATE TELEMETRY")
                    .kicker(Theme.accent)
                separator
                Text("4 CLIMATE FLAGSHIPS")
                    .kicker(Theme.accent)
                separator
                Text("NISAR L-BAND")
                    .kicker(Theme.text.opacity(0.85))
                separator
                Text("BITCOIN ANCHORED")
                    .kicker(Theme.text.opacity(0.85))
                separator
                passText(context.date)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .fringeGlass(Capsule())
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Earth is moving. \(EventCatalog.all.count) events, \(GroundStationCount.count) ground stations.")
    }

    private var separator: some View {
        Text("·").kicker(Theme.sage.opacity(0.7))
    }

    @ViewBuilder
    private func passText(_ now: Date) -> some View {
        if let next = MissionClock.nextPass(for: event, after: now) {
            let acquiring = MissionClock.isAcquiring(next, at: now)
            Text(acquiring ? "NISAR overhead now" : "next pass in \(shortCountdown(from: now, to: next.date))")
                .kicker(acquiring ? Theme.amber : Theme.accent.opacity(0.9))
        }
    }

    /// Compact countdown for the strip: days+hours, or hours+minutes when close.
    private func shortCountdown(from now: Date, to date: Date) -> String {
        let t = max(0, date.timeIntervalSince(now))
        let d = Int(t) / 86_400
        let h = Int(t) % 86_400 / 3_600
        let m = Int(t) % 3_600 / 60
        return d > 0 ? "\(d)d \(String(format: "%02d", h))h" : String(format: "%02dh %02dm", h, m)
    }
}
