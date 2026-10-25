import SwiftUI

enum AppTab: Hashable {
    case map, events, lab, guide
}

enum DetailSheet: Hashable {
    case explain, evidence, integrity, ask
}

/// App-wide navigation and selection state.
@Observable
final class AppModel {
    var tab: AppTab = .map
    var band: SARBand = .nisarL
    var selectedEventID: String = EventCatalog.featured.id
    /// Scrubber position between pass 1 (0) and pass 2 (1).
    var progress: Double = 0
    /// Incremented to ask the map to fly to the selected event.
    var focusRequest: Int = 0

    var activeDetailSheet: DetailSheet? = nil
    var detailScrollTarget: String? = nil
    var isRunningDemoTour: Bool = false
    private var demoTourTask: Task<Void, Never>? = nil

    var mapPath: [DeformationEvent] = []
    var eventsPath: [DeformationEvent] = []
    var guidePath: [DeformationEvent] = []

    let lab = LabViewModel()

    /// Live Ground Station link (ESP32 motion sensor) — one poll loop for the whole app.
    let liveStation = LiveStationService()

    var selectedEvent: DeformationEvent {
        EventCatalog.event(id: selectedEventID)
    }

    func openInLab(_ event: DeformationEvent) {
        lab.apply(event)
        tab = .lab
    }

    func showOnMap(_ event: DeformationEvent) {
        selectedEventID = event.id
        progress = 1
        mapPath = []
        tab = .map
        focusRequest += 1
    }

    func runDemoTour() {
        guard !isRunningDemoTour else { return }
        isRunningDemoTour = true
        demoTourTask?.cancel()
        demoTourTask = Task { @MainActor in
            // Scene 1: Map — Central Valley Drought Flagship + Radar Wavelengths
            tab = .map
            selectedEventID = EventCatalog.centralValley.id
            focusRequest += 1
            progress = 0
            band = .nisarL
            activeDetailSheet = nil
            detailScrollTarget = nil
            try? await Task.sleep(for: .milliseconds(3000))

            withAnimation(.snappy) { band = .sentinelC }
            try? await Task.sleep(for: .milliseconds(1800))

            withAnimation(.snappy) { band = .nisarL }
            try? await Task.sleep(for: .milliseconds(1200))

            // Two-pass scrubber: land sinks 30 cm during drought
            let steps = 30
            for i in 1...steps {
                progress = Double(i) / Double(steps)
                try? await Task.sleep(for: .milliseconds(80))
            }
            try? await Task.sleep(for: .milliseconds(2000))

            // Scene 2: Events Catalog (Climate cases filter active)
            withAnimation(.snappy) {
                tab = .events
                eventsPath = []
            }
            try? await Task.sleep(for: .milliseconds(3500))

            // Scene 3: Open Central Valley Detail (Climate Crisis Flagship)
            withAnimation(.snappy) {
                detailScrollTarget = nil
                eventsPath = [EventCatalog.centralValley]
            }
            try? await Task.sleep(for: .milliseconds(3000))

            // Scroll to 6-section Climate Dossier
            withAnimation(.easeInOut(duration: 1.2)) {
                detailScrollTarget = "dossier"
            }
            try? await Task.sleep(for: .milliseconds(4500))

            // Scroll to Measured Ground Truth (P307 GNSS Station: -38 cm drop)
            withAnimation(.easeInOut(duration: 1.2)) {
                detailScrollTarget = "gnss"
            }
            try? await Task.sleep(for: .milliseconds(4000))

            // Scene 4: Grounded AI Q&A Sheet (Climate mechanism explanation)
            activeDetailSheet = .ask
            try? await Task.sleep(for: .milliseconds(5000))

            // Scene 5: Bitcoin OpenTimestamps Integrity Sheet (Immutable Climate Accounting)
            activeDetailSheet = .integrity
            try? await Task.sleep(for: .milliseconds(5000))

            // Scene 6: Evidence & Provenance Sheet (Open Data & JSON Export)
            activeDetailSheet = .evidence
            try? await Task.sleep(for: .milliseconds(4000))
            activeDetailSheet = nil
            try? await Task.sleep(for: .milliseconds(1200))

            // Scene 7: Norfolk, Virginia (Sea-Level Rise + Coastal Sinking)
            detailScrollTarget = nil
            withAnimation(.snappy) {
                eventsPath = [EventCatalog.norfolk]
            }
            try? await Task.sleep(for: .milliseconds(3500))
            withAnimation(.easeInOut(duration: 1.2)) {
                detailScrollTarget = "dossier"
            }
            try? await Task.sleep(for: .milliseconds(4000))

            // Scene 8: Scientific Honesty (Zero Greenwashing: Kīlauea Volcano Note)
            detailScrollTarget = nil
            withAnimation(.snappy) {
                eventsPath = [EventCatalog.kilauea]
            }
            try? await Task.sleep(for: .milliseconds(3000))

            // Scene 9: Interference Lab (Simulating Aquifer Compaction)
            withAnimation(.snappy) {
                tab = .lab
                lab.apply(EventCatalog.centralValley)
            }
            try? await Task.sleep(for: .milliseconds(2500))
            withAnimation(.snappy) {
                lab.wavelengthCm = SARBand.sentinelC.wavelengthCm
            }
            try? await Task.sleep(for: .milliseconds(2000))
            withAnimation(.snappy) {
                lab.wavelengthCm = SARBand.nisarL.wavelengthCm
            }
            try? await Task.sleep(for: .milliseconds(2000))

            // Scene 10: Guide
            withAnimation(.snappy) {
                tab = .guide
            }
            try? await Task.sleep(for: .milliseconds(3000))

            // Return to Map
            withAnimation(.snappy) {
                showOnMap(EventCatalog.centralValley)
            }
            isRunningDemoTour = false
        }
    }
}
